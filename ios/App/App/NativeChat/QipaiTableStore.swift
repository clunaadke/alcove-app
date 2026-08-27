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
    let value: Int?          // ddz 叫分
    let cards: [String]?     // ddz 出牌
    let label: String?
    let asType: String?
    // 炸金花
    let amount: Int?
    let kind: String?        // call / raise / allin / raise_allin
    let blind: Bool?
    let stake: Int?
    let target: String?      // compare 的对象
    let targetName: String?
    // UNO
    let card: String?
    let color: String?       // 万能牌选色 R/G/B/Y
    let count: Int?          // draw 时要摸几张

    enum CodingKeys: String, CodingKey {
        case type, value, cards, label, amount, kind, blind, stake, target, targetName, card, color, count
        case asType = "as"
    }
    var id: String {
        "\(type)-\(value ?? -1)-\(amount ?? -1)-\(stake ?? -1)-\(target ?? "")-\(card ?? "")-\(color ?? "")-\(cards?.joined(separator: ",") ?? "")"
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

struct QipaiTableFrame<GameV: Decodable>: Decodable {
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
    let state: GameV?
    let legal: [QipaiLegalMove]?
    let inviteToken: String?
}

private struct QipaiActionResponse<GameV: Decodable>: Decodable {
    let ok: Bool
    let view: GameV?
    let legal: [QipaiLegalMove]?
}

/// 只关心 ok 的轻响应（泛型类的方法里不能再声明局部类型，放外面）
private struct QipaiOKResponse: Decodable {
    let ok: Bool
}

// MARK: - Store

@MainActor
final class QipaiTableStore<GameV: Decodable>: ObservableObject {
    let code: String
    private let token: String?

    @Published var frame: QipaiTableFrame<GameV>?
    @Published var view: GameV?
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
              let f = try? JSONDecoder().decode(QipaiTableFrame<GameV>.self, from: data) else { return }
        frame = f
        view = f.state
        if let l = f.legal { legal = l }
    }

    // MARK: 动作

    func act(_ body: [String: Any]) async {
        guard let token else { show("你沒有座位（觀戰中）"); return }
        busy = true
        defer { busy = false }
        var payload = body
        payload["playerToken"] = token
        do {
            let resp: QipaiActionResponse<GameV> = try await QipaiAPI.request(
                "cards/api/rooms/\(code)/action", method: "POST", body: payload)
            if let v = resp.view { view = v }
            if let l = resp.legal { legal = l }
        } catch {
            show(error.localizedDescription)
        }
    }

    func bid(_ value: Int) async { await act(["type": "bid", "value": value]) }
    func play(_ cards: [String]) async { await act(["type": "play", "cards": cards]) }
    func pass() async { await act(["type": "pass"]) }
    func nextRound() async { await act(["type": "next_round"]) }
    func endMatch() async { await act(["type": "end_match"]) }

    func startGame() async {
        guard let token else { return }
        busy = true
        defer { busy = false }
        do {
            let _: QipaiOKResponse = try await QipaiAPI.request("cards/api/rooms/\(code)/start",
                                                   method: "POST", body: ["playerToken": token])
        } catch {
            show(error.localizedDescription)
        }
    }

    func sendChat(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            var body: [String: Any] = ["text": trimmed]
            if let token { body["playerToken"] = token }
            let _: QipaiOKResponse = try await QipaiAPI.request("cards/api/rooms/\(code)/chat",
                                                   method: "POST", body: body)
        } catch {
            show(error.localizedDescription)
        }
    }

    func closeRoom() async {
        do {
            var body: [String: Any] = [:]
            if let token { body["playerToken"] = token }
            let _: QipaiOKResponse = try await QipaiAPI.request("cards/api/rooms/\(code)/close",
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

    // 键跟引擎 TYPE_LABEL 对齐，文案走繁体（0828 全场繁体化）
    static let comboLabels: [String: String] = [
        "single": "單張", "pair": "對子", "triple": "三條",
        "triple_one": "三帶一", "triple_pair": "三帶對",
        "straight": "順子", "pair_straight": "連對",
        "plane": "飛機", "plane_one": "飛機帶單", "plane_pair": "飛機帶對",
        "four_two_single": "四帶二", "four_two_pair": "四帶兩對",
        "bomb": "炸彈", "rocket": "王炸",
    ]
}

// MARK: - 炸金花视图模型

struct ZjhPlayerView: Decodable, Identifiable {
    let id: String
    let name: String
    let isAI: Bool
    let chips: Int
    let score: Int
    let bet: Int
    let looked: Bool
    let folded: Bool
    let allin: Bool
    let out: Bool
    let acts: Int
    let handCount: Int
    let cards: [String]?
    let hand: String?        // 牌力标签（金花/对子…），摊牌或自己看过才有
}

struct ZjhWinner: Decodable, Identifiable {
    let playerId: String
    let name: String
    let gain: Int
    let net: Int
    let chips: Int
    var id: String { playerId }
}

struct ZjhReveal: Decodable, Identifiable {
    let playerId: String
    let name: String
    let cards: [String]
    let label: String
    var id: String { playerId }
}

struct ZjhResults: Decodable {
    let round: Int
    let reason: String       // showdown / fold_out …
    let pot: Int
    let winners: [ZjhWinner]
    let reveal: [ZjhReveal]
}

struct ZjhView: Decodable {
    let seq: Int
    let phase: String        // betting / round_over / game_over
    let round: Int
    let turnOrder: [String]
    let current: String?
    let dealer: String?
    let you: String?
    let pot: Int
    let currentBet: Int
    let callCost: Int?
    let players: [ZjhPlayerView]
    let lastResults: ZjhResults?
    let winner: String?
    let log: [QipaiLogEntry]

    func player(_ id: String?) -> ZjhPlayerView? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
    var me: ZjhPlayerView? { player(you) }
}

// MARK: - UNO 视图模型

struct UnoPlayerView: Decodable, Identifiable {
    let id: String
    let name: String
    let isAI: Bool
    let score: Int
    let handCount: Int
    let uno: Bool            // 只剩一张
    let hand: [String]?
}

struct UnoPending: Decodable {
    let playerId: String
    let mine: Bool
    let card: String?        // 只有本人能看到刚摸的那张
}

struct UnoResultRow: Decodable, Identifiable {
    let playerId: String
    let name: String
    let handCount: Int
    let handPoints: Int
    let gain: Int
    let score: Int
    var id: String { playerId }
}

struct UnoResults: Decodable {
    let round: Int
    let winner: String
    let gain: Int
    let players: [UnoResultRow]
}

struct UnoView: Decodable {
    let seq: Int
    let phase: String        // playing / round_over / game_over
    let round: Int
    let turnOrder: [String]
    let current: String?
    let dir: Int
    let dirLabel: String?
    let you: String?
    let players: [UnoPlayerView]
    let top: String?
    let topLabel: String?
    let activeColor: String?
    let activeColorName: String?
    let deckCount: Int
    let drawStack: Int
    let pending: UnoPending?
    let lastResults: UnoResults?
    let winner: String?
    let log: [QipaiLogEntry]

    func player(_ id: String?) -> UnoPlayerView? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
    var me: UnoPlayerView? { player(you) }
}

// MARK: - UNO 牌面工具

enum UnoCard {
    struct Face {
        let symbol: String    // 数字或 ↷/⇄/+2/★/+4
        let colorKey: String? // R/G/B/Y，万能为 nil
        let isWild: Bool
    }

    /// "R5#1" / "GS#2" / "W#1" / "WD#3"
    static func parse(_ id: String) -> Face {
        let base = id.split(separator: "#").first.map(String.init) ?? id
        if base == "W" { return Face(symbol: "★", colorKey: nil, isWild: true) }
        if base == "WD" { return Face(symbol: "+4", colorKey: nil, isWild: true) }
        let color = String(base.prefix(1))
        let v = String(base.dropFirst())
        let symbol: String
        switch v {
        case "S": symbol = "⊘"
        case "R": symbol = "⇄"
        case "D": symbol = "+2"
        default:  symbol = v
        }
        return Face(symbol: symbol, colorKey: color, isWild: false)
    }

    /// 低饱和版 UNO 四色，配古早灰蓝不打架
    static func tint(_ key: String?) -> Color {
        switch key {
        case "R": return QipaiPalette.qhex(0xC25B55)
        case "G": return QipaiPalette.qhex(0x7D9B84)
        case "B": return QipaiPalette.qhex(0x6E7E9C)
        case "Y": return QipaiPalette.qhex(0xC9A85C)
        default:  return QipaiPalette.ink
        }
    }

    static func colorName(_ key: String) -> String {
        switch key {
        case "R": return "紅"
        case "G": return "綠"
        case "B": return "藍"
        default:  return "黃"
        }
    }
}
