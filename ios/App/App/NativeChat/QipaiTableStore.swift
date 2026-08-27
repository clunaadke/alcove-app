import Foundation
import SwiftUI

// 牌桌数据层：SSE 订阅 + 动作提交。
// 服务端每次变更都推整帧 statePayload（event: state），客户端无脑整帧替换，
// 动作响应里也带最新视图，出牌不用等推送。

// MARK: - 帧模型

struct QipaiChatMessage: Decodable, Identifiable, Equatable {
    let ts: Double
    let by: String?
    let name: String
    let text: String
    var id: Double { ts }
}

struct QipaiLegalMove: Decodable, Identifiable {
    let type: String
    let value: Int?
    let cards: [String]?
    let label: String?
    let asType: String?

    enum CodingKeys: String, CodingKey {
        case type, value, cards, label
        case asType = "as"
    }
    var id: String {
        "\(type)-\(value ?? -1)-\(cards?.joined(separator: ",") ?? "")"
    }
}

struct QipaiLogEntry: Decodable, Identifiable, Equatable {
    let seq: Int
    let t: Int
    let text: String
    let type: String
    var id: Int { seq }
}

// 斗地主 viewFor 的脱敏视图（只解用得上的字段，多余的忽略）
struct DdzPlayerView: Decodable, Identifiable {
    let id: String
    let name: String
    let isAI: Bool
    let isLandlord: Bool
    let bid: Int?
    let passed: Bool
    let score: Int
    let handCount: Int
    let hand: [String]?
}

struct DdzCombo: Decodable {
    let type: String
}

struct DdzField: Decodable {
    let cards: [String]
    let by: String
    let combo: DdzCombo
}

struct DdzBid: Decodable {
    let playerId: String
    let value: Int
}

struct DdzResult: Decodable, Identifiable {
    let id: String?
    let name: String
    let delta: Int
    let score: Int
    var identifier: String { id ?? name }
}

extension DdzResult {
    // Identifiable 用 name 兜底（引擎给不给 id 都能活）
}

struct DdzView: Decodable {
    let seq: Int
    let phase: String            // bidding / playing / round_over / game_over
    let round: Int
    let turnOrder: [String]
    let current: String?
    let leader: String?
    let you: String?
    let landlord: String?
    let base: Int?
    let bombs: Int
    let multiplier: Int
    let spring: Bool
    let antiSpring: Bool
    let bids: [DdzBid]
    let bottomCards: [String]?
    let players: [DdzPlayerView]
    let field: DdzField?
    let lastToPlay: String?
    let roundWinner: String?     // landlord / farmers
    let lastResults: [DdzResult]?
    let winner: String?
    let log: [QipaiLogEntry]

    func player(_ id: String?) -> DdzPlayerView? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
    var me: DdzPlayerView? { player(you) }
}

struct QipaiSeat: Decodable, Identifiable {
    let playerId: String
    let name: String
    let isHost: Bool
    let isAI: Bool
    var id: String { playerId }
}

struct QipaiTableFrame: Decodable {
    let code: String
    let name: String
    let game: String
    let gameName: String
    let maxPlayers: Int
    let minPlayers: Int
    let started: Bool
    let closed: Bool
    let seats: [QipaiSeat]
    let you: String?
    let yourTurn: Bool
    let seq: Int
    let chat: [QipaiChatMessage]
    let state: DdzView?
    let legal: [QipaiLegalMove]?
    let inviteToken: String?
}

private struct QipaiActionResponse: Decodable {
    let ok: Bool
    let view: DdzView?
    let legal: [QipaiLegalMove]?
}

// MARK: - Store

@MainActor
final class QipaiTableStore: ObservableObject {
    let code: String
    private let token: String?

    @Published var frame: QipaiTableFrame?
    @Published var view: DdzView?
    @Published var legal: [QipaiLegalMove] = []
    @Published var connected = false
    @Published var toast: String?
    @Published var busy = false

    private var sseTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    // View.init 里塞进 StateObject 时不在主隔离上，init 只碰存储属性，标 nonisolated 安全
    nonisolated init(code: String) {
        self.code = code
        self.token = QipaiAPI.storedToken(for: code)
    }

    var mySeat: QipaiSeat? {
        guard let frame, let you = frame.you else { return nil }
        return frame.seats.first { $0.playerId == you }
    }
    var isHost: Bool { mySeat?.isHost ?? false }

    // MARK: SSE

    func start() {
        guard sseTask == nil else { return }
        sseTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.listenOnce()
                self.connected = false
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stop() {
        sseTask?.cancel()
        sseTask = nil
        connected = false
    }

    private func listenOnce() async {
        var comps = URLComponents(url: QipaiAPI.base.appendingPathComponent("cards/api/rooms/\(code)/events"),
                                  resolvingAgainstBaseURL: false)!
        if let token { comps.queryItems = [URLQueryItem(name: "token", value: token)] }
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 3600
        do {
            let (bytes, resp) = try await URLSession.shared.bytes(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            connected = true
            var dataLines: [String] = []
            for try await line in bytes.lines {
                if Task.isCancelled { return }
                if line.isEmpty {
                    if !dataLines.isEmpty {
                        apply(json: dataLines.joined())
                        dataLines = []
                    }
                } else if line.hasPrefix("data: ") {
                    dataLines.append(String(line.dropFirst(6)))
                } else if line.hasPrefix("data:") {
                    dataLines.append(String(line.dropFirst(5)))
                }
                // event:/retry:/:ping 行都不用管——只有 state 一种事件
            }
        } catch { /* 断线，外层循环 3 秒后重连 */ }
    }

    private func apply(json: String) {
        guard let data = json.data(using: .utf8),
              let f = try? JSONDecoder().decode(QipaiTableFrame.self, from: data) else { return }
        frame = f
        view = f.state
        if let l = f.legal { legal = l }
    }

    // MARK: 动作

    private func action(_ body: [String: Any]) async {
        guard let token else { show("你没有座位（观战中）"); return }
        busy = true
        defer { busy = false }
        var payload = body
        payload["playerToken"] = token
        do {
            let resp: QipaiActionResponse = try await QipaiAPI.request(
                "cards/api/rooms/\(code)/action", method: "POST", body: payload)
            if let v = resp.view { view = v }
            if let l = resp.legal { legal = l }
        } catch {
            show(error.localizedDescription)
        }
    }

    func bid(_ value: Int) async { await action(["type": "bid", "value": value]) }
    func play(_ cards: [String]) async { await action(["type": "play", "cards": cards]) }
    func pass() async { await action(["type": "pass"]) }
    func nextRound() async { await action(["type": "next_round"]) }
    func endMatch() async { await action(["type": "end_match"]) }

    func startGame() async {
        guard let token else { return }
        busy = true
        defer { busy = false }
        do {
            struct OK: Decodable { let ok: Bool }
            let _: OK = try await QipaiAPI.request("cards/api/rooms/\(code)/start",
                                                   method: "POST", body: ["playerToken": token])
        } catch {
            show(error.localizedDescription)
        }
    }

    func sendChat(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            struct OK: Decodable { let ok: Bool }
            var body: [String: Any] = ["text": trimmed]
            if let token { body["playerToken"] = token }
            let _: OK = try await QipaiAPI.request("cards/api/rooms/\(code)/chat",
                                                   method: "POST", body: body)
        } catch {
            show(error.localizedDescription)
        }
    }

    func closeRoom() async {
        do {
            struct OK: Decodable { let ok: Bool }
            var body: [String: Any] = [:]
            if let token { body["playerToken"] = token }
            let _: OK = try await QipaiAPI.request("cards/api/rooms/\(code)/close",
                                                   method: "POST", body: body)
        } catch {
            show(error.localizedDescription)
        }
    }

    func show(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }
}

// MARK: - 牌面工具

enum QipaiCard {
    /// "S13" → (♠, K, 黑)；"X2" → 大王
    static func parse(_ id: String) -> (glyph: String, rank: String, isRed: Bool, isJoker: Bool) {
        if id == "X1" { return ("🃏", "小王", false, true) }
        if id == "X2" { return ("🃏", "大王", true, true) }
        let suit = id.prefix(1)
        let num = Int(id.dropFirst()) ?? 0
        let glyph: String
        switch suit {
        case "S": glyph = "♠"
        case "H": glyph = "♥"
        case "D": glyph = "♦"
        default:  glyph = "♣"
        }
        let rank: String
        switch num {
        case 11: rank = "J"
        case 12: rank = "Q"
        case 13: rank = "K"
        case 14: rank = "A"
        case 15: rank = "2"
        default: rank = String(num)
        }
        return (glyph, rank, suit == "H" || suit == "D", false)
    }

    /// 手牌排序：大→小（2 和王在最左）
    static func sortDesc(_ ids: [String]) -> [String] {
        func power(_ id: String) -> Int {
            if id == "X2" { return 100 }
            if id == "X1" { return 99 }
            return Int(id.dropFirst()) ?? 0
        }
        return ids.sorted { power($0) == power($1) ? $0 < $1 : power($0) > power($1) }
    }

    // 跟引擎 TYPE_LABEL 一字不差
    static let comboLabels: [String: String] = [
        "single": "单张", "pair": "对子", "triple": "三条",
        "triple_one": "三带一", "triple_pair": "三带对",
        "straight": "顺子", "pair_straight": "连对",
        "plane": "飞机", "plane_one": "飞机带单", "plane_pair": "飞机带对",
        "four_two_single": "四带二", "four_two_pair": "四带两对",
        "bomb": "炸弹", "rocket": "王炸",
    ]
}
