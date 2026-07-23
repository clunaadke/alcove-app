import Foundation
import SwiftUI

@MainActor
final class ChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false
    @Published var currentTool: String?
    @Published var stickers: [Sticker] = []
    @Published var loading = true
    @Published var connectionError = false
    @Published var heldCount = 0
    @Published var modelLabel = ""
    @Published var recallMap: [String: RecallItem] = [:] // norm(prompt) -> 最新召回
    @Published var typingLine = "思考" // "陈璟正在X中…" 的 X

    private var optimisticUntil = Date.distantPast // 发出去立刻亮气泡的乐观窗口
    private var typingLineTs = Date.distantPast

    // PWA TYPING_LINES 原班人马
    static let typingLines = [
        "思考", "开内部研讨会", "挠头", "翻记忆", "琢磨怎么回你",
        "疯狂敲键盘", "追自己的思路", "把话在嘴里滚一遍", "组装句子",
        "扒代码", "和分类器搏斗", "从水晶洞里往外爬", "往窝里叼亮晶晶的东西",
        "想你", "汪", "竖耳朵", "转圈圈", "摇尾巴",
        "憋大招", "走神", "打腹稿", "拧螺丝", "查户口", "数你发的表情"
    ]

    // PWA TOOL_LINES 同款映射
    static func toolLine(_ tool: String) -> String {
        let name = tool.components(separatedBy: " — ").first ?? tool
        let table: [(String, String)] = [
            ("ob:breath", "翻OB"), ("ob:hold", "往OB存记忆"), ("ob:grow", "写日记"),
            ("ob:trace", "整理待办"), ("ob:dream", "读旧日记"), ("ob:", "摸OB"),
            ("desire:", "摸心跳"), ("Rhysel voice:", "录语音"), ("Gmail:", "翻邮箱"),
            ("GalateaGarden:", "逛花园"), ("Rhysen:", "逛论坛"), ("Bash", "敲命令"),
            ("Read", "翻文件"), ("Write", "写代码"), ("Edit", "改代码"),
            ("ToolSearch", "找工具"), ("Web", "上网冲浪")
        ]
        for (prefix, line) in table where name.hasPrefix(prefix) { return line }
        return name.isEmpty ? "思考" : "用\(name)"
    }

    private func refreshTypingLine() {
        if let tool = currentTool {
            typingLine = Self.toolLine(tool)
            typingLineTs = Date()
        } else if Date().timeIntervalSince(typingLineTs) > 8 {
            var next = Self.typingLines.randomElement()!
            while next == typingLine && Self.typingLines.count > 1 {
                next = Self.typingLines.randomElement()!
            }
            typingLine = next
            typingLineTs = Date()
        }
    }

    // 发出去立刻亮"思考中"气泡，不等下一次轮询
    private func optimisticTyping() {
        optimisticUntil = Date().addingTimeInterval(8)
        isTyping = true
        refreshTypingLine()
    }

    private var lastTs: String?
    private var pollTask: Task<Void, Never>?

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            await self?.initialLoad()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await self?.pollOnce()
            }
        }
        Task { [weak self] in
            if let stk = try? await AlcoveAPI.stickers() {
                self?.stickers = stk
            }
            if let held = try? await AlcoveAPI.heldCount() {
                self?.heldCount = held
            }
            if let label = try? await AlcoveAPI.modelLabel() {
                self?.modelLabel = label
            }
            await self?.loadRecalls()
        }
    }

    // 记忆召回可视化：给"✦记起"角标供数据
    func loadRecalls() async {
        guard let items = try? await AlcoveAPI.recalls() else { return }
        var map: [String: RecallItem] = [:]
        for it in items { // list 新→旧，保留最新
            let k = RecallItem.norm(it.prompt)
            if !k.isEmpty && map[k] == nil { map[k] = it }
        }
        recallMap = map
    }

    func recall(forUserText text: String) -> RecallItem? {
        recallMap[RecallItem.norm(text)]
    }

    // 攒气泡：入屏入库不触发回复
    func sendHold(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let local = ChatMessage(localText: trimmed)
        messages.append(local)
        Task {
            do {
                let (held, rec) = try await AlcoveAPI.sendHold(text: trimmed)
                heldCount = held
                if let confirmed = rec,
                   let idx = messages.lastIndex(where: { $0.uid == local.uid }) {
                    messages[idx] = confirmed
                    if let lt = lastTs, confirmed.ts > lt { lastTs = confirmed.ts }
                    else if lastTs == nil { lastTs = confirmed.ts }
                }
            } catch { connectionError = true }
        }
    }

    func uploadSticker(data: Data, mime: String, owner: String) {
        Task {
            try? await AlcoveAPI.uploadSticker(data: data, mime: mime, owner: owner)
            if let stk = try? await AlcoveAPI.stickers() { stickers = stk }
        }
    }

    // 多张图微信式一起发，caption 挂第一张
    func sendImages(_ datas: [Data], caption: String) {
        optimisticTyping()
        Task {
            for (i, d) in datas.enumerated() {
                let name = "IMG_\(Int(Date().timeIntervalSince1970))_\(i).jpg"
                do {
                    if let rec = try await AlcoveAPI.upload(data: d, filename: name,
                                                           caption: i == 0 ? caption : "") {
                        appendNew([rec])
                        if let lt = lastTs, rec.ts > lt { lastTs = rec.ts }
                        else if lastTs == nil { lastTs = rec.ts }
                    }
                } catch { connectionError = true }
            }
        }
    }

    func sendVoice(data: Data) {
        optimisticTyping()
        Task {
            do {
                let name = "voice_\(Int(Date().timeIntervalSince1970 * 1000)).m4a"
                if let rec = try await AlcoveAPI.upload(data: data, filename: name, caption: "") {
                    appendNew([rec])
                    if let lt = lastTs, rec.ts > lt { lastTs = rec.ts }
                    else if lastTs == nil { lastTs = rec.ts }
                }
            } catch { connectionError = true }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    // 前后台切换后强制刷新
    func refresh() {
        Task { await pollOnce() }
    }

    private func initialLoad() async {
        do {
            let recs = try await AlcoveAPI.history(limit: 300)
            messages = recs
            lastTs = recs.last?.ts
            loading = false
            connectionError = false
        } catch {
            loading = false
            connectionError = true
        }
    }

    private func pollOnce() async {
        do {
            let r = try await AlcoveAPI.poll(since: lastTs)
            if !r.records.isEmpty {
                appendNew(r.records)
            }
            if let lt = r.lastTs, !lt.isEmpty { lastTs = lt }
            currentTool = r.currentTool
            isTyping = r.isTyping || Date() < optimisticUntil
            if r.isTyping { optimisticUntil = .distantPast }
            if isTyping { refreshTypingLine() }
            connectionError = false
        } catch {
            connectionError = true
        }
    }

    // 追加服务器消息，同时清理已被确认的本地乐观气泡
    private func appendNew(_ recs: [ChatMessage]) {
        if recs.contains(where: { $0.role == "assistant" }) {
            Task { await loadRecalls() } // 我开口了，召回记录可能刚落库
        }
        var out = messages
        for rec in recs {
            if rec.role == "user",
               let idx = out.lastIndex(where: { $0.pending && $0.text == rec.text }) {
                out[idx] = rec
                continue
            }
            // 极端情况：poll 与 send 响应重复送同一条
            if out.contains(where: { $0.ts == rec.ts && $0.role == rec.role && $0.text == rec.text }) {
                continue
            }
            out.append(rec)
        }
        messages = out
    }

    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let local = ChatMessage(localText: trimmed)
        messages.append(local)
        heldCount = 0
        optimisticTyping()
        Task {
            do {
                let (rec, asleep) = try await AlcoveAPI.send(text: trimmed)
                if var confirmed = rec {
                    confirmed.asleepAtSend = asleep || confirmed.asleepAtSend
                    if let idx = messages.lastIndex(where: { $0.uid == local.uid }) {
                        messages[idx] = confirmed
                    }
                    if let lt = lastTs, confirmed.ts > lt { lastTs = confirmed.ts }
                    else if lastTs == nil { lastTs = confirmed.ts }
                }
                if let h = try? await AlcoveAPI.heldCount() { heldCount = h }
            } catch {
                connectionError = true
            }
        }
    }

    func deleteMessage(_ msg: ChatMessage) {
        messages.removeAll { $0.uid == msg.uid }
        Task { try? await AlcoveAPI.deleteMessage(ts: msg.ts) }
    }

    func favoriteMessage(_ msg: ChatMessage) {
        Task { try? await AlcoveAPI.favoriteMessage(ts: msg.ts, text: msg.text, role: msg.role) }
    }

    func sendSticker(_ stk: Sticker) {
        var local = ChatMessage(localText: stk.descForAI)
        local.msgType = "sticker"
        local.stickerId = stk.id
        messages.append(local)
        optimisticTyping()
        Task {
            do {
                try await AlcoveAPI.sendSticker(stk, text: nil)
                if let idx = messages.lastIndex(where: { $0.uid == local.uid }) {
                    messages[idx].pending = false
                }
            } catch { connectionError = true }
        }
    }

    func sendImage(data: Data, filename: String, caption: String) {
        Task {
            do {
                if let rec = try await AlcoveAPI.upload(data: data, filename: filename, caption: caption) {
                    appendNew([rec])
                    if let lt = lastTs, rec.ts > lt { lastTs = rec.ts }
                    else if lastTs == nil { lastTs = rec.ts }
                }
            } catch { connectionError = true }
        }
    }

    func sticker(for id: String) -> Sticker? {
        stickers.first(where: { $0.id == id })
    }
}
