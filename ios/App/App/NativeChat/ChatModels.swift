import Foundation

// 后端 /api/history 与 /api/poll 返回的消息记录
struct ChatMessage: Identifiable, Equatable {
    let uid = UUID()
    var ts: String
    var role: String          // "user" | "assistant"
    var text: String
    var source: String?
    var thinking: String?
    var thinkingDuration: Double?
    var attachmentUrl: String?
    var attachmentType: String?
    var attachmentFilename: String?
    var asleepAtSend: Bool
    var msgType: String?      // "sticker" 等
    var stickerId: String?
    var pending: Bool = false // 本地乐观渲染，服务器确认前为 true

    var id: UUID { uid }

    var date: Date {
        ISO8601DateFormatter.alcove.date(from: ts)
            ?? ISO8601DateFormatter.alcoveFrac.date(from: ts)
            ?? Date()
    }

    var isSticker: Bool { msgType == "sticker" && stickerId != nil }
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

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool { lhs.uid == rhs.uid }

    // 服务端字段名不固定走 Codable，手动从 JSON 字典解析更宽松
    init?(json: [String: Any]) {
        guard let ts = json["ts"] as? String,
              let role = json["role"] as? String else { return nil }
        self.ts = ts
        self.role = role
        self.text = json["text"] as? String ?? ""
        self.source = json["source"] as? String
        self.thinking = json["thinking"] as? String
        if let d = json["thinking_duration"] as? Double { self.thinkingDuration = d }
        else if let i = json["thinking_duration"] as? Int { self.thinkingDuration = Double(i) }
        self.attachmentUrl = json["attachment_url"] as? String
        self.attachmentType = json["attachment_type"] as? String
        self.attachmentFilename = json["attachment_filename"] as? String
        if let a = json["asleep_at_send"] as? Int { self.asleepAtSend = a != 0 }
        else if let a = json["asleep_at_send"] as? Bool { self.asleepAtSend = a }
        else { self.asleepAtSend = false }
        self.msgType = json["msg_type"] as? String
        self.stickerId = json["sticker_id"] as? String
    }

    // 本地乐观消息
    init(localText: String, role: String = "user") {
        self.ts = ISO8601DateFormatter.alcoveFrac.string(from: Date())
        self.role = role
        self.text = localText
        self.asleepAtSend = false
        self.pending = true
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
