import Foundation

// 棋牌室网络层。后端是 VPS 上的 bisca cards 服务，走专用隧道 qipai.ob-memory.uk。
// 登录 cookie 由 URLSession 自动存取（90 天），401/403 时自动补一次登录再重试。

enum QipaiAPI {
    static let base = URL(string: "https://qipai.ob-memory.uk")!
    // 家用服务的门锁（/etc/bisca.env 里那把）。她不用记，app 替她开门。
    private static let password = "MoonDen-6qV9-fK2x-N8pR"

    enum APIError: LocalizedError {
        case server(String)
        case badResponse
        var errorDescription: String? {
            switch self {
            case .server(let msg): return msg
            case .badResponse: return "棋牌室没应声，稍后再试"
            }
        }
    }

    // MARK: 模型

    /// ruleMeta 的默认值既有开关也有数字，一个壳装两种
    enum RuleValue: Decodable {
        case flag(Bool)
        case number(Double)

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let b = try? c.decode(Bool.self) { self = .flag(b); return }
            if let d = try? c.decode(Double.self) { self = .number(d); return }
            throw DecodingError.typeMismatch(RuleValue.self, .init(
                codingPath: decoder.codingPath, debugDescription: "既不是布尔也不是数字"))
        }

        var boolValue: Bool { if case .flag(let b) = self { return b }; return false }
        var numberValue: Double { if case .number(let d) = self { return d }; return 0 }
        var isFlag: Bool { if case .flag = self { return true }; return false }
    }

    struct RuleMeta: Decodable, Identifiable {
        let key: String
        let label: String
        let note: String
        let def: RuleValue
        var id: String { key }
    }

    struct GameInfo: Decodable, Identifiable {
        let key: String
        let name: String
        let ready: Bool
        let minPlayers: Int
        let maxPlayers: Int
        let ruleMeta: [RuleMeta]
        var id: String { key }

        var playersLabel: String {
            minPlayers == maxPlayers ? "恰好 \(minPlayers) 人" : "\(minPlayers)~\(maxPlayers) 人"
        }
    }

    struct Seat: Decodable, Identifiable {
        let playerId: String
        let name: String
        let color: String?
        let isHost: Bool
        let isAI: Bool
        let agentId: String?
        var id: String { playerId }
    }

    struct RoomSummary: Decodable, Identifiable {
        let code: String
        let name: String
        let game: String
        let gameName: String
        let updatedAt: Double?   // 大厅聚合两个服务后按它排序
        let started: Bool
        let finished: Bool
        let phase: String?
        let round: Int
        let currentName: String?
        let playerCount: Int
        let maxPlayers: Int
        let players: [Seat]
        var id: String { code }

        var hasAI: Bool { players.contains { $0.isAI } }
        var statusLabel: String { finished ? "已结束" : (started ? "进行中" : "等人中") }
        /// 这台设备在这间房里有没有坐过
        var hasMySeat: Bool { QipaiAPI.storedToken(for: code) != nil }
    }

    struct Lobby: Decodable {
        let games: [GameInfo]
        let rooms: [RoomSummary]
    }

    struct CreatedRoom: Decodable {
        let code: String
        let name: String
        let inviteToken: String
    }

    // MARK: 战绩档案（cards 服务的 /api/history）

    struct HistorySummary: Decodable, Identifiable {
        let id: String
        let code: String
        let game: String
        let gameName: String
        let name: String
        let createdAt: Double
        let closedAt: Double
        let finished: Bool
        let round: Int
        let players: [Seat]
    }

    struct HistoryList: Decodable {
        let history: [HistorySummary]
    }

    /// 终局 state 只解通用字段（事件日志），各游戏的私有字段不碰
    struct HistoryState: Decodable {
        let log: [QipaiLogEntry]?
    }

    struct HistoryRecord: Decodable {
        let id: String
        let code: String
        let gameName: String
        let name: String
        let closedAt: Double
        let finished: Bool
        let round: Int
        let players: [Seat]
        let state: HistoryState?
        let chat: [QipaiChatMessage]?
    }

    struct JoinResult: Decodable {
        let code: String
        let playerId: String
        let playerToken: String
        let name: String
        let isHost: Bool
        let rejoined: Bool
    }

    // MARK: 座位凭证（断线复座靠它）

    static func storedToken(for code: String) -> String? {
        let t = UserDefaults.standard.string(forKey: "qipai.token.\(code)")
        return (t?.isEmpty == false) ? t : nil
    }

    static func rememberToken(_ token: String, for code: String) {
        UserDefaults.standard.set(token, forKey: "qipai.token.\(code)")
    }

    static var nickname: String {
        get { UserDefaults.standard.string(forKey: "qipai.nickname") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "qipai.nickname") }
    }

    // MARK: 请求底座

    private static func rawRequest(_ path: String, method: String,
                                   body: [String: Any]?,
                                   query: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        var url = base.appendingPathComponent(path)
        if let query, !query.isEmpty,
           var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = comps.url ?? url
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.badResponse }
        return (data, http)
    }

    private static func login() async throws {
        let (data, http) = try await rawRequest("cards/api/login", method: "POST",
                                                body: ["password": password])
        guard http.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["ok"] as? Bool == true else {
            throw APIError.server("棋牌室开门失败（登录被拒）")
        }
    }

    static func request<T: Decodable>(_ path: String, method: String = "GET",
                                      body: [String: Any]? = nil,
                                      query: [String: String]? = nil,
                                      canRetry: Bool = true) async throws -> T {
        let (data, http) = try await rawRequest(path, method: method, body: body, query: query)
        if (http.statusCode == 401 || http.statusCode == 403), canRetry {
            try await login()
            return try await request(path, method: method, body: body, query: query, canRetry: false)
        }
        if http.statusCode >= 400 {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw APIError.server(msg)
            }
            throw APIError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: 大厅动作
    // bisca 是多服务架构：ddz/zjh/uno 在 cards 枢纽，大富豪是独立的 daifugo 服务。
    // 三份 config 的 cookie_secret 已在服务端统一，一次 cards 登录全家通用。

    /// game key → 服务前缀
    static func service(for game: String) -> String {
        game == "daifugo" ? "daifugo" : "cards"
    }

    static func lobby(service: String = "cards") async throws -> Lobby {
        try await request("\(service)/api/rooms")
    }

    static func createRoom(game: String, name: String,
                           rules: [String: Any], aiPlayers: [String],
                           aiPrompt: String = "") async throws -> CreatedRoom {
        var body: [String: Any] = ["game": game, "name": name]
        if !rules.isEmpty { body["rules"] = rules }
        if !aiPlayers.isEmpty { body["ai_players"] = aiPlayers }
        if !aiPrompt.isEmpty { body["ai_prompt"] = aiPrompt }
        return try await request("\(service(for: game))/api/rooms", method: "POST", body: body)
    }

    static func join(code: String, name: String, service: String = "cards") async throws -> JoinResult {
        var body: [String: Any] = ["name": name]
        if let old = storedToken(for: code) { body["playerToken"] = old }
        let result: JoinResult = try await request("\(service)/api/rooms/\(code)/join",
                                                   method: "POST", body: body)
        rememberToken(result.playerToken, for: code)
        return result
    }

    /// 邀请链接（发给朋友用浏览器打开的那条）
    static func inviteLink(code: String, inviteToken: String, service: String = "cards") -> String {
        "https://qipai.ob-memory.uk/\(service)/room.html?c=\(code)&invite=\(inviteToken)"
    }

    // MARK: 战绩

    static func history(limit: Int = 50) async throws -> [HistorySummary] {
        // cards 必须活着；daifugo 的档案拿不到就只显示 cards 的
        let main: HistoryList = try await request("cards/api/history",
                                                  query: ["limit": String(limit)])
        let dai: HistoryList? = try? await request("daifugo/api/history",
                                                   query: ["limit": String(limit)])
        return (main.history + (dai?.history ?? [])).sorted { $0.closedAt > $1.closedAt }
    }

    static func historyDetail(id: String, service: String = "cards") async throws -> HistoryRecord {
        struct Wrap: Decodable { let record: HistoryRecord }
        let w: Wrap = try await request("\(service)/api/history/\(id)")
        return w.record
    }
}
