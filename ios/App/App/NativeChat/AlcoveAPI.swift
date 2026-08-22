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
        var turnID: String = ""
        var lastSeq: Int = -1
        var thinking: String = ""
        var nativeThinking: String = ""
        var say: String = ""
        // 最新正文先扣住：后续还有动作时才证明它不是最终答案。
        var pendingSay: String = ""
        var tool: String = ""
        var tools: [LiveTool] = []
        var timeline: [LiveProcessItem] = []
        var said: Int = 0
        var thinkingParagraphs: Int = 0
        var elapsed: Int = 0
        var error: String?
        var finishing: Bool = false
        var messageID: String?

        var isEmpty: Bool {
            say.isEmpty && thinking.isEmpty && nativeThinking.isEmpty && tools.isEmpty && error == nil
        }

        var shouldShowPreview: Bool {
            let hasTool = !tool.isEmpty || timeline.contains { $0.kind == "tool" }
            let hasProcess = hasTool || thinkingParagraphs > 1
            return hasProcess && (!thinking.isEmpty || !say.isEmpty || hasTool)
        }
    }

    struct LiveTool: Identifiable, Equatable {
        let id: String
        var name: String
        var done: Bool = false
        var ok: Bool?
    }

    struct LiveProcessItem: Identifiable, Equatable {
        let id: String
        var kind: String
        var text: String
        var done: Bool = false
        var ok: Bool?

        var icon: String {
            guard kind == "tool" else { return "quote.bubble" }
            // 实时预览那条带子跟落库的轨迹用同一套词（tool_names.py），图标也同一套
            let c = text
            if c.contains("记忆") || c.contains("OB") || c.contains("记了一笔") || c.contains("备忘") { return "brain.head.profile" }
            if c.contains("日记") || c.contains("信") || c.contains("情书") { return "book.closed" }
            if c.contains("图") || c.contains("截") || c.contains("相册") || c.contains("表情") || c.contains("照片") { return "photo" }
            if c.contains("语音") { return "waveform" }
            if c.contains("网页") || c.contains("搜") || c.contains("浏览器") || c.contains("小红书") || c.contains("标签") { return "globe" }
            if c.contains("花园") || c.contains("论坛") || c.contains("社区") || c.contains("帖") || c.contains("漂流瓶") { return "leaf" }
            if c.contains("丧尸") || c.contains("桌游") || c.contains("大富翁") || c.contains("牌") || c.contains("骰") || c.contains("beside you") { return "gamecontroller" }
            if c.contains("小镇") || c.contains("乌有乡") || c.contains("明信片") || c.contains("走") || c.contains("门") || c.contains("小院") { return "map" }
            if c.contains("提交") || c.contains("代码") { return "chevron.left.forwardslash.chevron.right" }
            if c.contains("服务") || c.contains("机器") || c.contains("容器") { return "gearshape" }
            if c.contains("接口") || c.contains("消息") || c.contains("聊天") || c.contains("工作室") { return "antenna.radiowaves.left.and.right" }
            if c.contains("文件") || c.contains("文档") || c.contains("PDF") { return "doc.text" }
            if c.contains("脚本") || c.contains("命令") || c.contains("终端") || c.contains("测试") { return "terminal" }
            if c.contains("旅行") { return "airplane" }
            if c.contains("数据库") { return "cylinder" }
            return done ? (ok == false ? "xmark.circle" : "checkmark.circle") : "play.circle"
        }
    }

    struct LiveEvent: Decodable {
        let turnID: String
        let seq: Int
        let event: String
        let delta: String?
        let ts: String
        let toolCallID: String?
        let name: String?
        let ok: Bool?
        let messageID: String?
        let reason: String?

        enum CodingKeys: String, CodingKey {
            case turnID = "turn_id", seq, event, delta, ts
            case toolCallID = "tool_call_id", name, ok
            case messageID = "message_id", reason
        }
    }

    // 主聊天段落流。snapshot 与增量共用一条 SSE，所以字段刻意保持可选；
    // snapshot 没有 seq/event/ts，事件名取 SSE 的 event: 行。
    struct ParagraphLiveEvent: Decodable {
        struct Item: Decodable {
            let kind: String
            let content: String
            let ts: Double?
        }

        let seq: Int?
        let event: String?
        let turnID: String?
        let content: String?
        let active: Bool?
        let thinking: String?
        let say: String?
        let tool: String?
        let said: Int?
        let elapsed: Int?
        let done: Bool?
        let items: [Item]?

        enum CodingKeys: String, CodingKey {
            case seq, event, content, active, thinking, say, tool, said, elapsed, done, items
            case turnID = "turn_id"
        }
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

    /// Small cached preview for chat timelines. Tapping still opens the
    /// original attachmentURL, so this only improves first paint and scrolling.
    static func attachmentThumbnailURL(_ raw: String) -> URL {
        guard raw.hasPrefix("/attachments/") else { return attachmentURL(raw) }
        let name = String(raw.dropFirst("/attachments/".count))
        return fullURL("/api/attachments/thumb/\(name)")
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

    // 圆桌用的两个通用口子（0731）。上面那两个是 private，别的文件够不着。
    static func getRaw(_ path: String) async throws -> [String: Any] {
        try await getJSON(path)
    }

    static func postRaw(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        try await postJSON(path, body: body)
    }

    static func history(limit: Int = 300) async throws -> [ChatMessage] {
        let obj = try await getJSON("/api/history?limit=\(limit)")
        let raw = obj["records"] as? [[String: Any]] ?? []
        return raw.compactMap(ChatMessage.init(json:))
    }

    static func history(before: String, limit: Int = 300) async throws -> [ChatMessage] {
        let encoded = before.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? before
        let obj = try await getJSON("/api/history?limit=\(limit)&before=\(encoded)")
        return (obj["records"] as? [[String: Any]] ?? []).compactMap(ChatMessage.init(json:))
    }

    static func history(around ts: String) async throws -> [ChatMessage] {
        let encoded = ts.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ts
        let obj = try await getJSON("/api/chat-around?ts=\(encoded)")
        return (obj["records"] as? [[String: Any]] ?? []).compactMap(ChatMessage.init(json:))
    }

    static func searchHistory(query: String = "", day: String = "", type: String = "",
                              limit: Int = 500) async throws -> [ChatMessage] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let d = day.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? day
        let t = type == "all" ? "" : type
        let obj = try await getJSON("/api/chat-search?q=\(q)&day=\(d)&type=\(t)&limit=\(limit)")
        return (obj["records"] as? [[String: Any]] ?? []).compactMap(ChatMessage.init(json:))
    }

    static func calendarCounts(month: String) async throws -> [String: Int] {
        let obj = try await getJSON("/api/chat-calendar?month=\(month)")
        var out: [String: Int] = [:]
        for row in obj["days"] as? [[String: Any]] ?? [] {
            if let day = row["day"] as? String { out[day] = (row["count"] as? NSNumber)?.intValue ?? 0 }
        }
        return out
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

    struct ScreenShareStatus {
        let id: String
        let status: String
        let requester: String
        let expiresIn: Int
    }

    static func screenShareStatus() async throws -> ScreenShareStatus {
        let obj = try await getJSON("/api/screen-share/status")
        return ScreenShareStatus(
            id: obj["id"] as? String ?? "",
            status: obj["status"] as? String ?? "idle",
            requester: obj["requester"] as? String ?? "陈璟",
            expiresIn: obj["expires_in"] as? Int ?? 0
        )
    }

    static func armScreenShare(requester: String = "陈璟") async throws {
        let obj = try await postJSON("/api/screen-share/arm", body: [
            "chat": "main", "requester": requester
        ])
        guard obj["ok"] as? Bool == true else { throw URLError(.cannotWriteToFile) }
    }

    static func declineScreenShare() async throws {
        let obj = try await postJSON("/api/screen-share/decline", body: [:])
        guard obj["ok"] as? Bool == true else { throw URLError(.cannotWriteToFile) }
    }

    static func terminalCapture(session: String = "main", lines: Int = 30) async throws -> String {
        let obj = try await getJSON("/api/terminal/capture?session=\(session)&lines=\(lines)")
        guard obj["ok"] as? Bool == true else { throw URLError(.cannotConnectToHost) }
        return obj["content"] as? String ?? ""
    }

    // 0822 SDK 终端页：后端把 SDK session 记录翻成 CLI 终端那个样子（❯ ∴ ● ⏺ ⎿）
    static func sdkTerminal(lines: Int = 120) async throws -> (content: String, busy: Bool) {
        let obj = try await getJSON("/api/sdk-shadow/terminal?lines=\(lines)")
        guard obj["ok"] as? Bool == true else { throw URLError(.cannotConnectToHost) }
        return (obj["content"] as? String ?? "", obj["busy"] as? Bool ?? false)
    }

    // 当前主聊天走的是 cli 还是 sdk（终端页默认跟着它开，但能手动切着看）
    static func sdkChannel() async throws -> String {
        let obj = try await getJSON("/api/sdk-shadow/status")
        return obj["channel"] as? String ?? "cli"
    }

    static func terminalSend(_ text: String, session: String = "main") async throws {
        let obj = try await postJSON("/api/terminal/send", body: [
            "session": session, "keys": text, "enter": true
        ])
        guard obj["ok"] as? Bool == true else { throw URLError(.cannotWriteToFile) }
    }

    static func terminalSendKey(_ key: String, session: String = "main") async throws {
        let obj = try await postJSON("/api/terminal/send", body: [
            "session": session, "key": key
        ])
        guard obj["ok"] as? Bool == true else { throw URLError(.cannotWriteToFile) }
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

    static func uploadSticker(data: Data, mime: String, owner: String,
                              name: String = "", description: String = "",
                              emotionTags: [String] = []) async throws {
        let boundary = "----alcove\(UUID().uuidString)"
        var req = URLRequest(url: fullURL("/api/stickers/upload"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // 动图必须原样上传：转码成 JPEG 就把动的那部分弄没了
        let ext = mime == "image/png" ? "png"
            : mime == "image/gif" ? "gif"
            : mime == "image/webp" ? "webp" : "jpg"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("owner", owner)
        field("name", name)
        field("description", description)
        // 没有描述的表情，对我来说就是一张看不懂的图
        if let tags = try? JSONSerialization.data(withJSONObject: emotionTags),
           let json = String(data: tags, encoding: .utf8) {
            field("emotion_tags", json)
        }
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"sticker.\(ext)\"\r\nContent-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        _ = try await session.data(for: req)
    }

    /// 给已有的表情补名称/描述/情绪标签（长按格子进编辑）
    static func updateSticker(id: String, name: String, description: String,
                              emotionTags: [String]) async throws {
        _ = try await postJSON("/api/stickers/update", body: [
            "id": id, "name": name, "description": description, "emotion_tags": emotionTags,
        ])
    }

    static func deleteMessage(ts: String, textOnly: Bool = false) async throws {
        _ = try await postJSON("/api/chat/delete", body: [
            "ts": ts, "text_only": textOnly
        ])
    }

    static func favoriteMessage(ts: String, text: String, role: String) async throws {
        _ = try await postJSON("/api/favorites/add", body: ["ts": ts, "text": text, "role": role])
    }

    static func favorites(kind: String = "", type: String = "") async throws -> [[String: Any]] {
        let k = kind == "all" ? "" : kind
        let t = type == "all" ? "" : type
        let obj = try await getJSON("/api/favorites?kind=\(k)&type=\(t)")
        return obj["items"] as? [[String: Any]] ?? []
    }

    /// 0819 她要的：多选几条就收成一段聊天记录，选一条还是单条
    static func favoriteAdd(_ messages: [ChatMessage], title: String = "") async throws {
        let items: [[String: Any]] = messages.map {
            ["ts": $0.ts, "text": $0.displayText, "role": $0.role,
             "attachment_url": $0.attachmentUrl ?? "",
             "attachment_type": $0.attachmentType ?? ""]
        }
        var body: [String: Any] = ["items": items]
        if !title.isEmpty { body["title"] = title }
        _ = try await postJSON("/api/favorites/add", body: body)
    }

    static func favoriteRemove(id: Int) async throws {
        _ = try await postJSON("/api/favorites/remove", body: ["id": id])
    }

    static func upload(data: Data, filename: String, caption: String, group: String? = nil) async throws -> ChatMessage? {
        var comps = URLComponents(url: fullURL("/api/upload"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "filename", value: filename),
                     URLQueryItem(name: "role", value: "user")]
        if !caption.isEmpty { items.append(URLQueryItem(name: "text", value: caption)) }
        if let group, !group.isEmpty { items.append(URLQueryItem(name: "group", value: group)) }
        comps.queryItems = items
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        let (respData, _) = try await session.upload(for: req, from: data)
        let obj = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
        return (obj?["record"] as? [String: Any]).flatMap(ChatMessage.init(json:))
    }

    static func uploadRoundtable(data: Data, filename: String, text: String, group: String? = nil) async throws -> [String: Any]? {
        var comps = URLComponents(url: fullURL("/api/roundtable/upload"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "filename", value: filename),
                     URLQueryItem(name: "role", value: "user"),
                     URLQueryItem(name: "sender", value: "陈霁")]
        if !text.isEmpty { items.append(URLQueryItem(name: "text", value: text)) }
        if let group, !group.isEmpty { items.append(URLQueryItem(name: "group", value: group)) }
        comps.queryItems = items
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        let (responseData, _) = try await session.upload(for: req, from: data)
        let obj = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        return obj?["record"] as? [String: Any]
    }
}
