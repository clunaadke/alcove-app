import Foundation

/// One renderer for ordinary chat text in every Alcove room. The stored text
/// stays untouched; only its presentation receives inline Markdown styling.
func alcoveMarkdown(_ raw: String) -> AttributedString {
    (try? AttributedString(
        markdown: raw,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(raw)
}

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
    var heartRate: Int?
    // 0730：思绪标题（他自己写的一句话总结，替掉"思考了X秒"）
    var thinkTitle: String?
    // 0730：这一轮的过程记录（思绪/中间说的话/调过的工具），挂在时间戳旁边点开看
    var activity: [ActivityItem] = []
    // 0819 活动脚印：我干活时掉下来的短语，挂在气泡外面排一行浅灰斜体
    var trace: [String] = []
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

    var readingCard: ReadingShareCard? {
        guard let raw = Self.taggedBody(text, tag: "READING_CARD"),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ReadingShareCard.self, from: data)
    }

    // 0819 她要的：我做个网页给她玩，聊天页直接长出一张卡，点开就在 app 里开，
    // 不跳浏览器（今天那个 http 链接整行被吞的坑也一起绕过去了）。
    var playCard: PlayPageCard? {
        guard let raw = Self.taggedBody(text, tag: "PLAY_CARD"),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PlayPageCard.self, from: data)
    }

    var workCard: WorkDeliveryCard? {
        guard let raw = Self.taggedBody(text, tag: "WORK_CARD"),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WorkDeliveryCard.self, from: data)
    }

    // 旅行卡片：正文里只有一个 id，整趟数据走 /api/journeys/<id> 现取。
    var journeyCard: JourneyCardRef? {
        guard let raw = Self.taggedBody(text, tag: "JOURNEY_CARD"),
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["id"] as? String, !id.isEmpty else { return nil }
        return JourneyCardRef(id: id)
    }

    // 陈璟每天只需投递这一枚日期标记；正文由归档接口按日期读取。
    var morningPaperDate: String? {
        Self.taggedBody(text, tag: "MORNING_PAPER")
    }

    // 选字询问：原文跟着消息送给陈璟，App 只把协议壳藏起来。
    var quotedSelection: String? {
        guard text.hasPrefix("[QUOTE]"),
              let end = text.range(of: "[/QUOTE]") else { return nil }
        return String(text[text.index(text.startIndex, offsetBy: 7)..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayText: String {
        guard text.hasPrefix("[QUOTE]"),
              let end = text.range(of: "[/QUOTE]") else { return text }
        return String(text[end.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        if let bpm = json["heart_rate"] as? Int { self.heartRate = bpm }
        else if let bpm = json["heart_rate"] as? Double { self.heartRate = Int(bpm) }
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
        if let steps = json["trace"] as? [String] {
            self.trace = steps.filter { !$0.isEmpty }
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

/// 陈璟现做的一页，她点一下在 app 里全屏打开。
/// page 是 alcove.ob-memory.uk 下的文件名（qixi.html 这种），不写全 URL。
struct PlayPageCard: Decodable, Equatable {
    let title: String
    let subtitle: String
    let page: String
    let emoji: String?

    var url: URL? {
        if page.hasPrefix("http") { return URL(string: page) }
        return URL(string: "https://alcove.ob-memory.uk/" + page)
    }
}

struct ReadingShareCard: Decodable, Equatable {
    struct Quote: Decodable, Equatable, Identifiable {
        let chapter: Int
        let text: String
        let note: String
        let time: String
        var id: String { "\(chapter)|\(time)|\(text)" }
    }
    let book: String
    let author: String
    let quotes: [Quote]
}

struct WorkDeliveryCard: Codable, Equatable {
    let taskId: Int
    let title: String
    let status: String
    let result: String
    let artifacts: [String]
    let finishedAt: String

    enum CodingKeys: String, CodingKey {
        case title, status, result, artifacts
        case taskId = "task_id"
        case finishedAt = "finished_at"
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
            // 0818 名字改成人话之后（tool_names.py），图标按新词认
            let c = content
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
