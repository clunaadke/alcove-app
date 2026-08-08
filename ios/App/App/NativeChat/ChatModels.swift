import Foundation

// 后端 /api/history 与 /api/poll 返回的消息记录
struct ChatMessage: Identifiable, Equatable {
    let uid = UUID()
    var ts: String
    var role: String          // "user" | "assistant"
    var text: String
    var source: String?
    var turnID: String?
    var thinking: String?
    var nativeThinking: String?
    var thinkingDuration: Double?
    // 0730：思绪标题（他自己写的一句话总结，替掉"思考了X秒"）
    var thinkTitle: String?
    // 0730：这一轮的过程记录（思绪/中间说的话/调过的工具），挂在时间戳旁边点开看
    var activity: [ActivityItem] = []
    var attachmentUrl: String?
    var attachmentType: String?
    var attachmentFilename: String?
    var attachmentGroup: String?
    var asleepAtSend: Bool
    var msgType: String?      // "sticker" 等
    var stickerId: String?
    var pending: Bool = false // 本地乐观渲染，服务器确认前为 true

    var id: UUID { uid }

    let date: Date

    // 0730：没调过工具的轮次没有过程可看。服务端 16:22 起已经拦了一道，
    // 但那之前落库的旧消息还带着空 activity，翻历史会冒出一个点开只有一行的空 chip。
    var hasActivity: Bool { activity.contains { $0.kind == "tool" } }

    var isSticker: Bool { msgType == "sticker" && stickerId != nil }
    var musicCard: MusicSong? { MusicSong.card(from: text) }
    var isImage: Bool {
        guard let t = attachmentType, let u = attachmentUrl, !u.isEmpty else { return false }
        return t == "image"
    }
    var isAudio: Bool {
        guard let u = attachmentUrl, !u.isEmpty else { return false }
        if let t = attachmentType, t.contains("audio") { return true }
        return ["m4a", "mp3", "wav", "ogg", "webm", "aac"]
            .contains((u as NSString).pathExtension.lowercased())
    }
    var isDocument: Bool {
        guard let u = attachmentUrl, !u.isEmpty else { return false }
        return !isImage && !isAudio
    }

    var insideText: String? {
        Self.taggedBody(text, tag: "INSIDE")
    }

    var ghostCard: GhostActivityCard? {
        guard let raw = Self.taggedBody(text, tag: "GHOST_CARD"),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GhostActivityCard.self, from: data)
    }

    private static func taggedBody(_ text: String, tag: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let open = "[\(tag)]", close = "[/\(tag)]"
        guard trimmed.hasPrefix(open), trimmed.hasSuffix(close) else { return nil }
        return String(trimmed.dropFirst(open.count).dropLast(close.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var photoBatchKey: String? {
        guard isImage, let group = attachmentGroup, !group.isEmpty else { return nil }
        return group
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool { lhs.uid == rhs.uid }

    // 服务端字段名不固定走 Codable，手动从 JSON 字典解析更宽松
    private static func parseDate(_ ts: String) -> Date {
        ISO8601DateFormatter.alcove.date(from: ts)
            ?? ISO8601DateFormatter.alcoveFrac.date(from: ts)
            ?? Date()
    }

    init?(json: [String: Any]) {
        guard let ts = json["ts"] as? String,
              let role = json["role"] as? String else { return nil }
        self.ts = ts
        self.date = Self.parseDate(ts)
        self.role = role
        self.text = json["text"] as? String ?? ""
        self.source = json["source"] as? String
        self.turnID = json["turn_id"] as? String
        self.thinking = json["thinking"] as? String
        self.nativeThinking = json["native_thinking"] as? String
        if let d = json["thinking_duration"] as? Double { self.thinkingDuration = d }
        else if let i = json["thinking_duration"] as? Int { self.thinkingDuration = Double(i) }
        self.attachmentUrl = json["attachment_url"] as? String
        self.attachmentType = json["attachment_type"] as? String
        self.attachmentFilename = json["attachment_filename"] as? String
        self.attachmentGroup = json["att_group"] as? String
        if let a = json["asleep_at_send"] as? Int { self.asleepAtSend = a != 0 }
        else if let a = json["asleep_at_send"] as? Bool { self.asleepAtSend = a }
        else { self.asleepAtSend = false }
        self.msgType = json["msg_type"] as? String
        self.stickerId = json["sticker_id"] as? String
        self.thinkTitle = (json["think_title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let arr = json["activity"] as? [[String: Any]] {
            self.activity = arr.compactMap(ActivityItem.init(json:))
        }
    }

    // 本地乐观消息
    init(localText: String, role: String = "user") {
        let now = Date()
        self.ts = ISO8601DateFormatter.alcoveFrac.string(from: now)
        self.date = now
        self.role = role
        self.text = localText
        self.asleepAtSend = false
        self.pending = true
    }
}

struct GhostActivityCard: Decodable, Equatable {
    struct Item: Decodable, Equatable, Identifiable {
        let time: String
        let desc: String
        var id: String { time + "|" + desc }
    }
    let wake: String
    let duration: Int
    let items: [Item]
    let insideSummary: String?

    enum CodingKeys: String, CodingKey {
        case wake, duration, items
        case insideSummary = "inside_summary"
    }
}

// 0730 过程记录的一条。kind: thinking | text | tool
struct ActivityItem: Identifiable, Equatable {
    let id = UUID()
    let kind: String
    let content: String
    let t: Double

    init?(json: [String: Any]) {
        guard let k = json["kind"] as? String,
              let c = json["content"] as? String, !c.isEmpty else { return nil }
        self.kind = k
        // 这是过程记录不是聊天正文，markdown 标记留着只会变成一串星号
        self.content = c
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if let d = json["t"] as? Double { self.t = d }
        else if let i = json["t"] as? Int { self.t = Double(i) }
        else { self.t = 0 }
    }

    var icon: String {
        switch kind {
        case "thinking": return "circle.dotted"
        case "tool":
            if content.contains("记忆") || content.contains("OB") { return "brain.head.profile" }
            if content.contains("日记") || content.contains("信") { return "book.closed" }
            if content.contains("网页") || content.contains("搜索") || content.contains("上网") { return "globe" }
            if content.contains("文件") || content.contains("代码") { return "doc.text" }
            if content.contains("命令") || content.contains("终端") { return "terminal" }
            if content.contains("图片") || content.contains("照片") { return "photo" }
            return "play.fill"
        default: return "quote.closing"
        }
    }
    var stamp: String {
        t >= 60 ? String(format: "%.0fm%02.0fs", (t / 60).rounded(.down), t.truncatingRemainder(dividingBy: 60))
                : String(format: "%.1fs", t)
    }
}

struct Sticker: Identifiable, Equatable {
    let id: String
    let owner: String
    let name: String
    let description: String
    let emotionTags: [String]
    let url: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String,
              let url = json["url"] as? String else { return nil }
        self.id = id
        self.owner = json["owner"] as? String ?? "user"
        self.name = json["name"] as? String ?? ""
        self.description = json["description"] as? String ?? ""
        self.emotionTags = json["emotion_tags"] as? [String] ?? []
        self.url = url
    }

    // 与 PWA stickerDescForAI 保持一致的注入文本
    var descForAI: String {
        var s = "[表情: \(name.isEmpty ? "未命名" : name)] \(description)"
        if !emotionTags.isEmpty { s += " (\(emotionTags.joined(separator: ", ")))" }
        return s
    }
}

// OB 记忆召回记录：prompt 匹配她的消息，content 是召回的记忆原文
struct RecallItem {
    let prompt: String
    let content: String
    let ts: String

    init?(json: [String: Any]) {
        guard let prompt = json["prompt"] as? String,
              let content = json["content"] as? String else { return nil }
        self.prompt = prompt
        self.content = content
        self.ts = json["ts"] as? String ?? ""
    }

    // 与 PWA formatRecallCards 同款切卡：按 [bucket_id: 分段
    var cards: [(date: String, body: String)] {
        let parts = content.components(separatedBy: "[bucket_id:")
            .enumerated()
            .compactMap { i, p -> String? in
                let s = (i == 0 ? p : "[bucket_id:" + p)
                    .replacingOccurrences(of: #"^===[^\n]*\n?"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }
        var out: [(String, String)] = []
        for p in parts {
            var date = ""
            if let r = p.range(of: #"\[(?:created|date):([0-9.\-]+)\]"#, options: .regularExpression) {
                date = String(p[r]).replacingOccurrences(of: #"[\[\]]|created:|date:"#, with: "", options: .regularExpression)
            }
            let lines = p.components(separatedBy: "\n")
            let body = (lines.first?.hasPrefix("[bucket_id:") == true
                        ? lines.dropFirst().joined(separator: "\n") : p)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty { out.append((date, body)) }
        }
        return out.isEmpty ? [("", content)] : out
    }

    static func norm(_ s: String) -> String {
        s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}

extension ISO8601DateFormatter {
    static let alcove: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static let alcoveFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
