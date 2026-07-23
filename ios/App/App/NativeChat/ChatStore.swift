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
            isTyping = r.isTyping
            currentTool = r.currentTool
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
            } catch {
                connectionError = true
            }
        }
    }

    func sendSticker(_ stk: Sticker) {
        var local = ChatMessage(localText: stk.descForAI)
        local.msgType = "sticker"
        local.stickerId = stk.id
        messages.append(local)
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
