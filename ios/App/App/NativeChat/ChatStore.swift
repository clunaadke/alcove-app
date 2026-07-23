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
