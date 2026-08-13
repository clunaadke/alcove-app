import Foundation
import SwiftUI

@MainActor
final class ChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private var deletedMessageTs: Set<String> = []
    @Published var isTyping = false
    @Published var currentTool: String?
    @Published var stickers: [Sticker] = []
    @Published var loading = true
    @Published var connectionError = false
    @Published var heldCount = 0
    @Published var modelLabel = ""
    @Published var recallMap: [String: RecallItem] = [:] // norm(prompt) -> 最新召回
    @Published var typingLine = "思考" // "陈璟正在X中…" 的 X
    // 0730 实时预览：他说完一段就先给她看，不等整轮工具跑完
    @Published var live: AlcoveAPI.LiveState? {
        didSet {
            let snapshot = live
            Task { await AlcoveLiveActivityController.sync(snapshot) }
        }
    }

    private var heldGen = 0
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
    private var liveTask: Task<Void, Never>?
    private var lastModelPoll = Date.distantPast

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            await self?.initialLoad()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await self?.pollOnce()
            }
        }
        // v1.1 SSE：只维持一条长连接，不再每秒轮询实时预览。
        liveTask = Task { [weak self] in
            await self?.consumeLiveStream()
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
        let gen = heldGen
        Task {
            do {
                let (held, rec) = try await AlcoveAPI.sendHold(text: trimmed)
                guard gen == heldGen else { return }
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
            let batch = Int(Date().timeIntervalSince1970 * 1000)
            let group = datas.count > 1 ? UUID().uuidString : nil
            for (i, d) in datas.enumerated() {
                let name = "IMG_\(batch)_\(i).jpg"
                do {
                    if let rec = try await AlcoveAPI.upload(data: d, filename: name,
                                                           caption: i == 0 ? caption : "", group: group) {
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
        liveTask?.cancel()
        liveTask = nil
        live = nil
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

    private func consumeLiveStream() async {
        var retry: UInt64 = 5_000_000_000
        while !Task.isCancelled {
            do {
                var request = URLRequest(url: AlcoveAPI.fullURL("/stream/live"))
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 60 * 60
                let (bytes, response) = try await AlcoveAPI.session.bytes(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                retry = 5_000_000_000
                var sseEvent = ""
                for try await line in bytes.lines {
                    guard !Task.isCancelled else { return }
                    if line.hasPrefix("event:") {
                        sseEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        continue
                    }
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    guard let data = payload.data(using: .utf8),
                          let event = try? JSONDecoder().decode(AlcoveAPI.ParagraphLiveEvent.self, from: data) else { continue }
                    await applyParagraphLiveEvent(event, sseEvent: sseEvent)
                    sseEvent = ""
                }
            } catch is CancellationError {
                return
            } catch {
                // 流式是增强通道。端点尚未上线或短暂重连时不能冒充主聊天断线。
                try? await Task.sleep(nanoseconds: retry)
                retry = min(retry * 2, 60_000_000_000)
            }
        }
    }

    private func applyParagraphLiveEvent(
        _ event: AlcoveAPI.ParagraphLiveEvent,
        sseEvent: String
    ) async {
        let kind = event.event ?? sseEvent
        if kind == "snapshot" {
            let snapshotActive = event.active == true || event.done == false
            guard snapshotActive, let turnID = event.turnID, !turnID.isEmpty else {
                if live?.turnID.hasPrefix("pending-") != true { live = nil }
                return
            }
            var snapshot = AlcoveAPI.LiveState(active: true, turnID: turnID)
            snapshot.lastSeq = event.seq ?? -1
            snapshot.elapsed = event.elapsed ?? 0
            let items = event.items ?? []
            if items.isEmpty {
                snapshot.thinking = event.thinking ?? ""
                // 聚合快照无法证明这段正文后面还有动作，先按最终段暂扣。
                snapshot.pendingSay = event.say ?? ""
                snapshot.tool = event.tool.map(Self.toolLine) ?? ""
                snapshot.said = 0
            } else {
                for (index, item) in items.enumerated() {
                    let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !content.isEmpty else { continue }
                    switch item.kind {
                    case "thinking":
                        snapshot.thinking += (snapshot.thinking.isEmpty ? "" : "\n\n") + content
                        snapshot.thinkingParagraphs += 1
                        snapshot.timeline.append(.init(id: "snapshot-thinking-\(index)",
                                                       kind: "thinking", text: content, done: true))
                    case "text":
                        if !snapshot.pendingSay.isEmpty {
                            snapshot.pendingSay += "\n\n"
                        }
                        snapshot.pendingSay += content
                        snapshot.timeline.append(.init(id: "snapshot-text-\(index)",
                                                       kind: "text", text: content, done: true))
                    case "tool":
                        let isCurrent = index == items.count - 1
                        let display = Self.toolLine(content)
                        if isCurrent { snapshot.tool = display }
                        snapshot.timeline.append(.init(id: "snapshot-tool-\(index)",
                                                       kind: "tool", text: display,
                                                       done: !isCurrent))
                    default: break
                    }
                }
                let hasTool = snapshot.timeline.contains { $0.kind == "tool" }
                if hasTool || snapshot.thinkingParagraphs > 1 {
                    let textItems = items.enumerated().filter { $0.element.kind == "text" }
                    if textItems.count > 1 {
                        let visible = textItems.dropLast().map { $0.element.content.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        snapshot.say = visible.joined(separator: "\n\n")
                        snapshot.said = visible.count
                        snapshot.pendingSay = textItems.last?.element.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    }
                }
            }
            if snapshot.timeline.isEmpty {
                if !snapshot.thinking.isEmpty {
                    snapshot.timeline.append(.init(id: "snapshot-thinking", kind: "thinking",
                                                   text: snapshot.thinking, done: true))
                }
                if !snapshot.tool.isEmpty {
                    snapshot.timeline.append(.init(id: "snapshot-tool", kind: "tool",
                                                   text: snapshot.tool, done: false))
                }
                if !snapshot.say.isEmpty {
                    snapshot.timeline.append(.init(id: "snapshot-text", kind: "text",
                                                   text: snapshot.say, done: true))
                }
            }
            live = snapshot
            return
        }

        guard let turnID = event.turnID, !turnID.isEmpty,
              let seq = event.seq else { return }
        if live?.turnID != turnID {
            live = AlcoveAPI.LiveState(active: true, turnID: turnID)
        }
        guard var state = live, seq > state.lastSeq else { return }
        state.lastSeq = seq
        let content = event.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch kind {
        case "thinking_para":
            guard !content.isEmpty else { return }
            if !state.pendingSay.isEmpty {
                state.say += (state.say.isEmpty ? "" : "\n\n") + state.pendingSay
                state.said += 1
                state.pendingSay = ""
            }
            state.thinking += (state.thinking.isEmpty ? "" : "\n\n") + content
            state.thinkingParagraphs += 1
            state.timeline.append(.init(id: "thinking-\(seq)", kind: "thinking",
                                        text: content, done: true))
        case "text_para":
            guard !content.isEmpty else { return }
            if state.shouldShowPreview, !state.pendingSay.isEmpty {
                state.say += (state.say.isEmpty ? "" : "\n\n") + state.pendingSay
                state.said += 1
                state.pendingSay = ""
            }
            state.pendingSay += (state.pendingSay.isEmpty ? "" : "\n\n") + content
            state.tool = ""
            state.timeline.append(.init(id: "text-\(seq)", kind: "text",
                                        text: content, done: true))
        case "tool_step":
            guard !content.isEmpty else { return }
            if !state.pendingSay.isEmpty {
                state.say += (state.say.isEmpty ? "" : "\n\n") + state.pendingSay
                state.said += 1
                state.pendingSay = ""
            }
            let display = Self.toolLine(content)
            state.tool = display
            state.timeline.append(.init(id: "tool-\(seq)", kind: "tool",
                                        text: display, done: true))
        case "turn_end":
            // 她定的收口：最后一段结束就整条直播立即死亡，正式气泡随后接替。
            live = nil
            await pollOnce()
            try? await Task.sleep(nanoseconds: 350_000_000)
            await pollOnce()
            return
        default:
            return
        }
        live = state
    }

    private func applyLiveEvent(_ event: AlcoveAPI.LiveEvent) async {
        if event.event == "start" || live?.turnID != event.turnID {
            live = AlcoveAPI.LiveState(active: true, turnID: event.turnID)
        }
        guard var state = live, event.seq > state.lastSeq else { return }
        state.lastSeq = event.seq
        switch event.event {
        case "start":
            state.active = true
            state.error = nil
        case "thinking_delta":
            let delta = event.delta ?? ""
            state.thinking += delta
            if let i = state.timeline.indices.last, state.timeline[i].kind == "thinking" {
                state.timeline[i].text += delta
            } else if !delta.isEmpty {
                state.timeline.append(.init(id: "thinking-\(event.seq)", kind: "thinking", text: delta))
            }
        case "native_thinking_delta":
            state.nativeThinking += event.delta ?? ""
        case "text_delta":
            state.say += event.delta ?? ""
        case "tool_start":
            let id = event.toolCallID ?? "tool-\(event.seq)"
            if !state.tools.contains(where: { $0.id == id }) {
                state.tools.append(.init(id: id, name: event.name ?? "执行动作"))
                state.timeline.append(.init(id: id, kind: "tool", text: event.name ?? "执行动作"))
            }
            state.tool = event.name ?? state.tool
        case "tool_done":
            if let id = event.toolCallID, let i = state.tools.firstIndex(where: { $0.id == id }) {
                state.tools[i].done = true
                state.tools[i].ok = event.ok
            }
            if let id = event.toolCallID, let i = state.timeline.firstIndex(where: { $0.id == id }) {
                state.timeline[i].done = true
                state.timeline[i].ok = event.ok
            }
            state.tool = ""
        case "finish":
            state.active = false
            state.finishing = true
            state.messageID = event.messageID
        case "error":
            state.active = false
            state.error = event.reason ?? "实时连接中断"
        default:
            break
        }
        live = state
        if event.event == "finish" {
            await pollOnce()
            if live?.finishing == true {
                try? await Task.sleep(nanoseconds: 450_000_000)
                await pollOnce()
            }
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
            if Date().timeIntervalSince(lastModelPoll) > 5 {
                lastModelPoll = Date()
                if let label = try? await AlcoveAPI.modelLabel(), !label.isEmpty {
                    modelLabel = label
                }
            }
        } catch {
            connectionError = true
        }
    }

    // 追加服务器消息，同时清理已被确认的本地乐观气泡
    private func appendNew(_ recs: [ChatMessage]) {
        if recs.contains(where: { $0.role == "assistant" }) {
            Task { await loadRecalls() } // 我开口了，召回记录可能刚落库
            if live?.finishing == true { live = nil }
        }
        var out = messages
        for rec in recs {
            // 删除请求与轮询可能交叉：服务器旧快照晚到时不能把已删气泡复活。
            if deletedMessageTs.contains(rec.ts) { continue }
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
        heldGen += 1
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
        deletedMessageTs.insert(msg.ts)
        let keepsAttachment = !(msg.attachmentUrl ?? "").isEmpty
        if keepsAttachment, let index = messages.firstIndex(where: { $0.uid == msg.uid }) {
            messages[index].text = ""
        } else {
            messages.removeAll { $0.uid == msg.uid }
        }
        Task {
            do {
                try await AlcoveAPI.deleteMessage(ts: msg.ts, textOnly: keepsAttachment)
            } catch {
                deletedMessageTs.remove(msg.ts)
                connectionError = true
            }
        }
    }

    func favoriteMessage(_ msg: ChatMessage) {
        Task { try? await AlcoveAPI.favoriteMessage(ts: msg.ts, text: msg.text, role: msg.role) }
    }

    func deleteMessages(_ selected: [ChatMessage]) {
        selected.forEach { deletedMessageTs.insert($0.ts) }
        let removeIDs = Set(selected.compactMap {
            ($0.attachmentUrl ?? "").isEmpty ? $0.uid : nil
        })
        messages.removeAll { removeIDs.contains($0.uid) }
        let clearIDs = Set(selected.compactMap {
            ($0.attachmentUrl ?? "").isEmpty ? nil : $0.uid
        })
        for index in messages.indices where clearIDs.contains(messages[index].uid) {
            messages[index].text = ""
        }
        Task {
            for msg in selected {
                try? await AlcoveAPI.deleteMessage(
                    ts: msg.ts, textOnly: !(msg.attachmentUrl ?? "").isEmpty
                )
            }
        }
    }

    func favoriteMessages(_ selected: [ChatMessage]) {
        Task {
            for msg in selected {
                try? await AlcoveAPI.favoriteMessage(
                    ts: msg.ts, text: msg.displayText, role: msg.role
                )
            }
        }
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
