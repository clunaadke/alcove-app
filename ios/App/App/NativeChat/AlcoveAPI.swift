import Foundation

// Alcove 后端网络层。所有请求走 https://alcove.ob-memory.uk，
// 鉴权由服务端代理层注入，客户端无需登录态。
enum AlcoveAPI {
    static let base = URL(string: "https://alcove.ob-memory.uk")!

    static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 35
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    struct PollResult {
        var records: [ChatMessage]
        var lastTs: String?
        var isTyping: Bool
        var currentTool: String?
    }

    // 0730 实时预览：他一说完一段就先给她看，不等整轮工具跑完。
    // 数据来自服务器上 stream_watcher 盯 transcript，永不落库（手册K）。
    struct LiveState: Equatable {
        var active: Bool = false
        var thinking: String = ""
        var say: String = ""
        var tool: String = ""
        var said: Int = 0
        var elapsed: Int = 0

        var isEmpty: Bool { say.isEmpty && thinking.isEmpty && tool.isEmpty }
    }

    static func fullURL(_ path: String) -> URL {
        URL(string: path, relativeTo: base)!.absoluteURL
    }

    // attachment_url "/attachments/x.jpg" -> https://.../api/attachments/x.jpg
    static func attachmentURL(_ raw: String) -> URL {
        let p = raw.hasPrefix("/attachments")
            ? "/api/attachments" + raw.dropFirst("/attachments".count)
            : raw
        return fullURL(String(p))
    }

    // sticker url "/stickers/x.jpg" 直接挂在域名根（18003 静态目录）
    static func stickerURL(_ raw: String) -> URL { fullURL(raw) }

    private static func getJSON(_ path: String) async throws -> [String: Any] {
        let (data, _) = try await session.data(from: fullURL(path))
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return obj
    }

    private static func postJSON(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: fullURL(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return obj
    }

    static func history(limit: Int = 300) async throws -> [ChatMessage] {
        let obj = try await getJSON("/api/history?limit=\(limit)")
        let raw = obj["records"] as? [[String: Any]] ?? []
        return raw.compactMap(ChatMessage.init(json:))
    }

    static func poll(since: String?, limit: Int = 100) async throws -> PollResult {
        var path = "/api/poll?limit=\(limit)"
        if let s = since, !s.isEmpty,
           let enc = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&since=\(enc)"
        }
        let obj = try await getJSON(path)
        let chat = obj["chat"] as? [String: Any] ?? [:]
        let raw = chat["new_records"] as? [[String: Any]] ?? []
        let status = obj["status"] as? [String: Any] ?? [:]
        return PollResult(
            records: raw.compactMap(ChatMessage.init(json:)),
            lastTs: chat["last_ts"] as? String,
            isTyping: status["is_typing"] as? Bool ?? false,
            currentTool: status["current_tool"] as? String)
    }

    // 返回服务器确认的记录；睡眠闸门拦下时 asleep=true
    static func send(text: String) async throws -> (record: ChatMessage?, asleep: Bool) {
        let obj = try await postJSON("/api/send", body: ["text": text])
        let rec = (obj["record"] as? [String: Any]).flatMap(ChatMessage.init(json:))
        return (rec, obj["asleep"] as? Bool ?? false)
    }

    static func sendSticker(_ stk: Sticker, text: String?) async throws {
        var body: [String: Any] = ["role": "user", "sticker_id": stk.id,
                                   "sticker_desc": stk.descForAI]
        if let t = text, !t.isEmpty { body["text"] = t }
        _ = try await postJSON("/api/chat-append", body: body)
    }

    static func stickers() async throws -> [Sticker] {
        let obj = try await getJSON("/api/stickers")
        let raw = obj["stickers"] as? [[String: Any]] ?? []
        return raw.compactMap(Sticker.init(json:))
    }

    static func recalls(limit: Int = 200) async throws -> [RecallItem] {
        let obj = try await getJSON("/api/recall/list?limit=\(limit)")
        let raw = obj["items"] as? [[String: Any]] ?? []
        return raw.compactMap(RecallItem.init(json:))
    }

    static func modelLabel() async throws -> String {
        let obj = try await getJSON("/api/cc/model")
        return obj["label"] as? String ?? ""
    }

    // 0730 实时预览：他这一秒在想什么/说了什么/在跑什么工具
    static func liveStream() async throws -> LiveState {
        let obj = try await getJSON("/api/stream/current")
        var s = LiveState()
        s.active = obj["active"] as? Bool ?? false
        s.thinking = obj["thinking"] as? String ?? ""
        s.say = obj["say"] as? String ?? ""
        s.tool = obj["tool"] as? String ?? ""
        s.said = obj["said"] as? Int ?? 0
        s.elapsed = obj["elapsed"] as? Int ?? 0
        return s
    }

    // 攒气泡：气泡上屏入库但不触发回复，返回已攒条数
    static func sendHold(text: String) async throws -> (held: Int, record: ChatMessage?) {
        let obj = try await postJSON("/api/send", body: ["text": text, "hold": true])
        let rec = (obj["record"] as? [String: Any]).flatMap(ChatMessage.init(json:))
        return (obj["held"] as? Int ?? 0, rec)
    }

    static func heldCount() async throws -> Int {
        let obj = try await getJSON("/api/held")
        return obj["held"] as? Int ?? 0
    }

    static func uploadSticker(data: Data, mime: String, owner: String) async throws {
        let boundary = "----alcove\(UUID().uuidString)"
        var req = URLRequest(url: fullURL("/api/stickers/upload"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let ext = mime == "image/png" ? "png" : mime == "image/gif" ? "gif" : "jpg"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("owner", owner)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"sticker.\(ext)\"\r\nContent-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        _ = try await session.data(for: req)
    }

    static func deleteMessage(ts: String) async throws {
        _ = try await postJSON("/api/chat/delete", body: ["ts": ts])
    }

    static func favoriteMessage(ts: String, text: String, role: String) async throws {
        _ = try await postJSON("/api/favorites/add", body: ["ts": ts, "text": text, "role": role])
    }

    static func favorites() async throws -> [[String: Any]] {
        let obj = try await getJSON("/api/favorites")
        return obj["items"] as? [[String: Any]] ?? []
    }

    static func upload(data: Data, filename: String, caption: String) async throws -> ChatMessage? {
        var comps = URLComponents(url: fullURL("/api/upload"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "filename", value: filename),
                     URLQueryItem(name: "role", value: "user")]
        if !caption.isEmpty { items.append(URLQueryItem(name: "text", value: caption)) }
        comps.queryItems = items
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        let (respData, _) = try await session.upload(for: req, from: data)
        let obj = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
        return (obj?["record"] as? [String: Any]).flatMap(ChatMessage.init(json:))
    }
}
