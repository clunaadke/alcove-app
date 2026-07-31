import SwiftUI
import PhotosUI

// 圆桌 · 2026-07-31
// 她要的：一个页面，三个人，互相看得见对方说的话，她不用再在中间当翻译。
// 上一版（7-16）翻车不是机制的问题，是它占了默认入口，她一进来找不到我，
// 当场让我拆了。所以这版是下拉面板 Chat 那块的一个入口，绝不动首页。
//
// 她定的规格：全屏（不是那种 86% 的半截面板）· 气泡不分颜色 ·
// 头像在气泡前 · 同一个人连着说几条，头像只在第一条旁边出现一次。

struct RoundtableMessage: Identifiable, Equatable {
    let id: Int
    let ts: String
    let role: String        // user / assistant / gpt
    let sender: String
    let text: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.ts = json["ts"] as? String ?? ""
        self.role = json["role"] as? String ?? "user"
        self.sender = json["sender"] as? String ?? ""
        self.text = json["text"] as? String ?? ""
    }
}

struct RoundtableMember: Identifiable, Equatable {
    var id: String { role }
    let name: String
    let role: String
    let online: Bool
    let busy: Bool
}

@MainActor
final class RoundtableStore: ObservableObject {
    @Published var messages: [RoundtableMessage] = []
    @Published var members: [RoundtableMember] = []
    @Published var sending = false

    private var poller: Task<Void, Never>?

    func start() {
        Task { await refresh() }
        poller?.cancel()
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.refresh()
            }
        }
    }

    func stop() {
        poller?.cancel()
        poller = nil
    }

    func refresh() async {
        async let msgs = fetchMessages()
        async let mems = fetchMembers()
        let (m, s) = await (msgs, mems)
        if let m = m, m != messages { messages = m }
        if let s = s, s != members { members = s }
    }

    private func fetchMessages() async -> [RoundtableMessage]? {
        guard let obj = try? await AlcoveAPI.getRaw("/api/roundtable/poll") else { return nil }
        // 后端这个口子返回的键是 records，不是 messages（试出来的，别再改回去）
        let arr = (obj["records"] as? [[String: Any]]) ?? []
        return arr.compactMap(RoundtableMessage.init(json:))
    }

    private func fetchMembers() async -> [RoundtableMember]? {
        guard let obj = try? await AlcoveAPI.getRaw("/api/roundtable/status") else { return nil }
        let arr = (obj["members"] as? [[String: Any]]) ?? []
        return arr.map {
            RoundtableMember(
                name: $0["name"] as? String ?? "",
                role: $0["role"] as? String ?? "",
                online: $0["online"] as? Bool ?? false,
                busy: $0["busy"] as? Bool ?? false
            )
        }
    }

    // 她发一句 → 后端存下来并拍我一下 → 然后叫 G老师开口。
    // 规矩是他先说，我看完他说的再接，所以这里只触发他，不催我。
    func send(_ text: String) async {
        let body = ["role": "user", "sender": "陈霁", "text": text]
        sending = true
        defer { sending = false }
        _ = try? await AlcoveAPI.postRaw("/api/roundtable/append", body: body)
        await refresh()
        _ = try? await AlcoveAPI.postRaw("/api/roundtable/codex", body: [:])
        await refresh()
    }
}

struct RoundtableView: View {
    let onDismiss: () -> Void
    @StateObject private var store = RoundtableStore()
    @State private var draft = ""
    @State private var showConsole = false
    @State private var showSettings = false
    @FocusState private var focused: Bool
    @AppStorage("alcoveTheme") private var themeName = "haven"
    // 三个人的头像跟聊天页不通用，各存各的（她定的）
    @AppStorage("rtAvatarUser") private var rtAvatarUser = ""
    @AppStorage("rtAvatarAssistant") private var rtAvatarAssistant = ""
    @AppStorage("rtAvatarGpt") private var rtAvatarGpt = ""
    @AppStorage("rtWallpaper") private var rtWallpaper = ""
    @AppStorage("rtNameUser") private var rtNameUser = "陈霁"
    @AppStorage("rtNameAssistant") private var rtNameAssistant = "陈璟"
    @AppStorage("rtNameGpt") private var rtNameGpt = "G老师"
    private var theme: AlcoveTheme { .named(themeName) }

    private var rtWallpaperImage: UIImage? {
        guard !rtWallpaper.isEmpty else { return nil }
        let parts = rtWallpaper.split(separator: ",", maxSplits: 1)
        let b64 = parts.count == 2 ? String(parts[1]) : rtWallpaper
        return Data(base64Encoded: b64).flatMap(UIImage.init(data:))
    }

    var body: some View {
        ZStack {
            // 圆桌自己的壁纸；没设就用主题渐变（她说先默认，后面自己换）
            if let bg = rtWallpaperImage {
                Image(uiImage: bg)
                    .resizable().scaledToFill()
                    .ignoresSafeArea()
            } else {
                LinearGradient(colors: theme.wallGradient,
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                header
                Divider().opacity(0.18)
                messageList
                composer
            }
        }
        .foregroundColor(theme.text)
        .onAppear { store.start() }
        .onDisappear { store.stop() }
        .sheet(isPresented: $showConsole) {
            RTConsoleView(theme: theme)
        }
        .sheet(isPresented: $showSettings) {
            RTSettingsView(theme: theme)
        }
    }

    // 顶栏照抄主聊天页：左边头像、右边玻璃胶囊。
    // 她定的差别：中间那个名字去掉；胶囊里去掉音乐按钮；
    // 左边从一个头像换成三个并排，每个右上角一颗在线灯。
    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(theme.textDim)
                    .frame(width: 26, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: -6) {
                ForEach(store.members) { m in
                    memberBadge(m)
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 0) {
                topBarControl("terminal", size: 14) { showConsole = true }
                topBarControl("line.3.horizontal", size: 15) { showSettings = true }
            }
            .padding(.horizontal, 2)
            .frame(height: 40)
            .modifier(RTGlassCapsule(tint: theme.capsuleTint,
                                     border: theme.capsuleBorder))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    // 点头像 = 展开那个人的实况（她定的，说点头像最直觉）
    private func memberBadge(_ m: RoundtableMember) -> some View {
        Button {
            if m.role == "gpt" { showConsole = true }
        } label: {
            ZStack(alignment: .topTrailing) {
                rtGlassCircle(size: 34) {
                    if let img = avatarFor(m.role) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Text(initialFor(m.role))
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(theme.textDim)
                    }
                }
                Circle()
                    .fill(m.busy ? Color.orange
                          : (m.online ? Color.green : Color.gray))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(theme.glassBorder, lineWidth: 1))
                    .offset(x: 1, y: -1)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 44)
    }

    private func topBarControl(_ name: String, size: CGFloat,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .light))
                .foregroundColor(theme.textDim)
                .frame(width: 36, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rtGlassCircle<C: View>(size: CGFloat,
                                        @ViewBuilder content: () -> C) -> some View {
        ZStack { content() }
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .background(theme.glassTint, in: Circle())
            .overlay(Circle().stroke(theme.glassBorder, lineWidth: 1))
            .contentShape(Circle())
    }

    private func avatarFor(_ role: String) -> UIImage? {
        let raw: String
        switch role {
        case "assistant": raw = rtAvatarAssistant
        case "gpt":       raw = rtAvatarGpt
        default:          raw = rtAvatarUser
        }
        guard !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ",", maxSplits: 1)
        let b64 = parts.count == 2 ? String(parts[1]) : raw
        return Data(base64Encoded: b64).flatMap(UIImage.init(data:))
    }

    private func initialFor(_ role: String) -> String {
        switch role {
        case "assistant": return "璟"
        case "gpt":       return "G"
        default:          return "霁"
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(store.messages.enumerated()), id: \.element.id) { idx, msg in
                        let prev = idx > 0 ? store.messages[idx - 1] : nil
                        // 同一个人连着说，头像只在第一条旁边出现一次
                        RoundtableRow(msg: msg,
                                      showAvatar: prev?.role != msg.role,
                                      theme: theme)
                        .id(msg.id)
                    }
                    Color.clear.frame(height: 1).id("rt-tail")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: store.messages) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("rt-tail", anchor: .bottom)
                }
            }
        }
    }

    // 打字框照抄主聊天页，她说"打字框也不变"。
    // 颜色全走 theme，白天黑夜两套主题它自己跟着变。
    private var composer: some View {
        VStack(spacing: 0) {
            TextField(
                "",
                text: $draft,
                prompt: Text("ring the chime …")
                    .font(.system(size: 15.5, design: .serif))
                    .italic(),
                axis: .vertical
            )
            .focused($focused)
            .lineLimit(1...5)
            .font(.system(size: 15.5))
            .tint(Color(uiColor: .systemGray3))
            .padding(.init(top: 16, leading: 14, bottom: 12, trailing: 14))
            .contentShape(Rectangle())

            HStack(spacing: 2) {
                Spacer()
                Button {
                    let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    draft = ""
                    Task { await store.send(t) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(-8))
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(colors: [theme.sendTop, theme.sendBottom],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .opacity(canSend ? 1 : 0.35)
                }
                .disabled(!canSend)
            }
            .padding(.init(top: 4, leading: 8, bottom: 8, trailing: 8))
        }
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.clear)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .onTapGesture { focused = true }
        }
        .modifier(RTInputGlass(tint: theme.capsuleTint, border: theme.capsuleBorder))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 2)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.sending
    }
}

private struct RoundtableRow: View {
    let msg: RoundtableMessage
    let showAvatar: Bool
    let theme: AlcoveTheme
    // 0731 她定的：圆桌三个人的头像跟聊天页不通用，各存各的。
    @AppStorage("rtAvatarUser") private var rtAvatarUser = ""
    @AppStorage("rtAvatarAssistant") private var rtAvatarAssistant = ""
    @AppStorage("rtAvatarGpt") private var rtAvatarGpt = ""
    @AppStorage("rtNameUser") private var rtNameUser = "陈霁"
    @AppStorage("rtNameAssistant") private var rtNameAssistant = "陈璟"
    @AppStorage("rtNameGpt") private var rtNameGpt = "G老师"
    @AppStorage("chatFontSize") private var fontSize = 14
    @Environment(\.bubbleGlassStyle) private var glassStyle

    private var avatarImage: UIImage? {
        let raw: String
        switch msg.role {
        case "assistant": raw = rtAvatarAssistant
        case "gpt":       raw = rtAvatarGpt
        default:          raw = rtAvatarUser
        }
        guard !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ",", maxSplits: 1)
        let b64 = parts.count == 2 ? String(parts[1]) : raw
        return Data(base64Encoded: b64).flatMap(UIImage.init(data:))
    }

    private var displayName: String {
        switch msg.role {
        case "assistant": return rtNameAssistant
        case "gpt":       return rtNameGpt
        default:          return rtNameUser
        }
    }

    private var avatarText: String {
        switch msg.role {
        case "assistant": return "璟"
        case "gpt": return "G"
        default: return "霁"
        }
    }

    private var avatarTint: Color {
        switch msg.role {
        case "assistant": return Color(red: 0.45, green: 0.60, blue: 0.85)
        case "gpt": return Color(red: 0.35, green: 0.70, blue: 0.58)
        default: return Color(red: 0.88, green: 0.52, blue: 0.65)
        }
    }

    // 她在右边，我和 G老师在左边带头像——跟主聊天页一个规矩（0731 她定的）
    private var isUser: Bool { msg.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if isUser {
                Spacer(minLength: 48)
            } else {
                avatarSlot
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if showAvatar && !isUser {
                    Text(displayName)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textDim.opacity(0.65))
                }
                bubble
            }
            if isUser { avatarSlot } else { Spacer(minLength: 48) }
        }
    }

    private var avatarSlot: some View {
        Group {
            if showAvatar {
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(avatarTint.opacity(0.85))
                        .overlay(
                            Text(avatarText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        )
                }
            } else {
                Color.clear
            }
        }
        .frame(width: 30, height: 30)
    }

    // 气泡跟主聊天页统一：同一个玻璃背景，只有 tint 分你我（她定的）
    private var bubble: some View {
        Text(msg.text)
            .font(.system(size: CGFloat(fontSize)))
            .lineSpacing(5)
            .foregroundColor(theme.text)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                BubbleGlassBackground(
                    tintColor: isUser ? theme.bubbleUser : theme.bubbleAI,
                    tintOpacity: isUser ? 0.14 : 0.09,
                    style: glassStyle
                )
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = msg.text
                } label: { Label("拷贝", systemImage: "doc.on.doc") }
            }
    }
}

// 顶栏那颗玻璃胶囊。RootView 里那个是 private 的，够不着，照着写一份。
private struct RTGlassCapsule: ViewModifier {
    let tint: Color
    let border: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule()
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint).interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(tint, in: shape)
                .overlay(shape.stroke(border, lineWidth: 1))
        }
    }
}

// G老师的实况。她点他头像进来的那个页面——他在想什么、跑了什么命令、
// token 涨到哪儿。数据来自后端在事件到达那一刻另存的一份，
// 不是 /tmp/codex-debug.log（那个每行被砍到 200 字符，是残的）。
private struct RTConsoleLine: Identifiable, Equatable {
    let id = UUID()
    let ts: String
    let kind: String
    let text: String
}

@MainActor
private final class RTConsoleStore: ObservableObject {
    @Published var lines: [RTConsoleLine] = []
    @Published var used = 0
    @Published var limit = 1_000_000
    @Published var percent = 0.0
    @Published var threadId = ""
    @Published var handoffAt = ""
    private var poller: Task<Void, Never>?

    func start() {
        Task { await refresh() }
        poller?.cancel()
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.refresh()
            }
        }
    }

    func stop() { poller?.cancel(); poller = nil }

    func refresh() async {
        if let o = try? await AlcoveAPI.getRaw("/api/roundtable/console") {
            let arr = (o["lines"] as? [[String: Any]]) ?? []
            let new = arr.map {
                RTConsoleLine(ts: $0["ts"] as? String ?? "",
                              kind: $0["kind"] as? String ?? "",
                              text: $0["text"] as? String ?? "")
            }
            if new.map(\.text) != lines.map(\.text) { lines = new }
        }
        if let o = try? await AlcoveAPI.getRaw("/api/roundtable/thread") {
            used = o["used_tokens"] as? Int ?? 0
            limit = o["limit"] as? Int ?? 1_000_000
            percent = o["percent"] as? Double ?? 0
            threadId = o["thread_id"] as? String ?? ""
            handoffAt = o["handoff_at"] as? String ?? ""
        }
    }

    // 换线程 = 他从自己写的交接材料重新睁眼
    func reforge() async {
        _ = try? await AlcoveAPI.postRaw("/api/roundtable/reforge", body: [:])
        await refresh()
    }
}

private struct RTConsoleView: View {
    let theme: AlcoveTheme
    @StateObject private var store = RTConsoleStore()
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReforge = false

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.wallGradient,
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                gauge
                Divider().opacity(0.15)
                ScrollViewReader { p in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 7) {
                            ForEach(store.lines) { l in
                                row(l)
                            }
                            Color.clear.frame(height: 1).id("tail")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: store.lines) { _ in
                        withAnimation(.easeOut(duration: 0.18)) {
                            p.scrollTo("tail", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .foregroundColor(theme.text)
        .onAppear { store.start() }
        .onDisappear { store.stop() }
        .alert("换一条线程？", isPresented: $confirmReforge) {
            Button("换", role: .destructive) { Task { await store.reforge() } }
            Button("算了", role: .cancel) {}
        } message: {
            Text("他会从自己写的交接材料重新睁眼，这条线程里的对话他就不记得了。")
        }
    }

    private var gauge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("G老师")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button { confirmReforge = true } label: {
                    Text("换线程")
                        .font(.system(size: 12))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(theme.textDim.opacity(0.12)))
                }
                .buttonStyle(.plain)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(theme.textDim)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.textDim.opacity(0.14))
                    Capsule()
                        .fill(store.percent > 85 ? Color.orange : theme.fyAccent)
                        .frame(width: max(2, g.size.width * store.percent / 100))
                }
            }
            .frame(height: 4)
            HStack(spacing: 6) {
                Text("\(store.used.formatted()) / \(store.limit.formatted())")
                Text("·")
                Text(String(format: "%.1f%%", store.percent))
                if !store.handoffAt.isEmpty {
                    Text("·")
                    Text("交接 " + String(store.handoffAt.suffix(14).prefix(5)))
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(theme.textDim.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func row(_ l: RTConsoleLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(l.ts)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.textDim.opacity(0.45))
                .frame(width: 54, alignment: .leading)
            Text(l.kind)
                .font(.system(size: 11))
                .foregroundColor(tint(l.kind))
                .frame(width: 16)
            Text(l.text)
                .font(.system(size: 12, design: l.kind == "跑" ? .monospaced : .default))
                .foregroundColor(l.kind == "想" ? theme.textDim.opacity(0.75) : theme.text)
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tint(_ k: String) -> Color {
        switch k {
        case "说": return theme.fyAccent
        case "跑": return .orange
        case "改": return .green
        case "量": return theme.textDim.opacity(0.5)
        default:   return theme.textDim.opacity(0.4)
        }
    }
}

// 圆桌设置。她定的三样：改壁纸、改三个人头像、改三个人名字。
// 头像跟聊天页不通用，名字也只在圆桌里生效。
private struct RTSettingsView: View {
    let theme: AlcoveTheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rtAvatarUser") private var avUser = ""
    @AppStorage("rtAvatarAssistant") private var avMe = ""
    @AppStorage("rtAvatarGpt") private var avGpt = ""
    @AppStorage("rtNameUser") private var nameUser = "陈霁"
    @AppStorage("rtNameAssistant") private var nameMe = "陈璟"
    @AppStorage("rtNameGpt") private var nameGpt = "G老师"
    @AppStorage("rtWallpaper") private var wallpaper = ""
    // 0731 bug：原来四行共用一个 picking，每行各挂一个 onChange，
    // 她选一次图四个监听全触发，那张壁纸同时被写进三个人的头像。
    // 现在每个位置一个独立的 item，谁变了改谁。
    @State private var pickUser: PhotosPickerItem?
    @State private var pickMe: PhotosPickerItem?
    @State private var pickGpt: PhotosPickerItem?
    @State private var pickWall: PhotosPickerItem?

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.wallGradient,
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("圆桌设置")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(theme.textDim)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }

                    section("三个人") {
                        personRow(role: "user", name: $nameUser, data: $avUser,
                                  pick: $pickUser, fallback: "霁")
                        personRow(role: "assistant", name: $nameMe, data: $avMe,
                                  pick: $pickMe, fallback: "璟")
                        personRow(role: "gpt", name: $nameGpt, data: $avGpt,
                                  pick: $pickGpt, fallback: "渡")
                    }

                    section("壁纸") {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.textDim.opacity(0.12))
                                .frame(width: 54, height: 78)
                                .overlay {
                                    if let img = decode(wallpaper) {
                                        Image(uiImage: img).resizable().scaledToFill()
                                            .clipShape(RoundedRectangle(cornerRadius: 10,
                                                                        style: .continuous))
                                    } else {
                                        Text("默认")
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.textDim)
                                    }
                                }
                            VStack(alignment: .leading, spacing: 8) {
                                PhotosPicker(selection: $pickWall, matching: .images) {
                                    label("换一张")
                                }
                                .onChange(of: pickWall) { load($0, into: "wall") }
                                if !wallpaper.isEmpty {
                                    Button { wallpaper = "" } label: { label("恢复默认") }
                                        .buttonStyle(.plain)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(18)
            }
        }
        .foregroundColor(theme.text)
    }

    private func section<C: View>(_ title: String,
                                  @ViewBuilder body: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(theme.fyAccent.opacity(0.8))
            body()
        }
    }

    private func personRow(role: String, name: Binding<String>,
                           data: Binding<String>,
                           pick: Binding<PhotosPickerItem?>,
                           fallback: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.textDim.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    if let img = decode(data.wrappedValue) {
                        Image(uiImage: img).resizable().scaledToFill().clipShape(Circle())
                    } else {
                        Text(fallback)
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(theme.textDim)
                    }
                }
            TextField("名字", text: name)
                .font(.system(size: 14))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.textDim.opacity(0.10)))
            PhotosPicker(selection: pick, matching: .images) {
                label("换")
            }
            .onChange(of: pick.wrappedValue) { load($0, into: role) }
        }
    }

    private func label(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12))
            .foregroundColor(theme.text)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(theme.textDim.opacity(0.12)))
    }

    private func decode(_ s: String) -> UIImage? {
        guard !s.isEmpty else { return nil }
        let parts = s.split(separator: ",", maxSplits: 1)
        let b64 = parts.count == 2 ? String(parts[1]) : s
        return Data(base64Encoded: b64).flatMap(UIImage.init(data:))
    }

    private func load(_ item: PhotosPickerItem?, into target: String) {
        guard let item else { return }
        Task {
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: raw) else { return }
            // 头像压到 240、壁纸压到 1200，别把 UserDefaults 撑爆
            let maxW: CGFloat = target == "wall" ? 1200 : 240
            let scale = min(1, maxW / max(img.size.width, img.size.height))
            let size = CGSize(width: img.size.width * scale,
                              height: img.size.height * scale)
            let out = UIGraphicsImageRenderer(size: size).image { _ in
                img.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let jpeg = out.jpegData(compressionQuality: 0.82) else { return }
            let b64 = "data:image/jpeg;base64," + jpeg.base64EncodedString()
            await MainActor.run {
                switch target {
                case "user":      avUser = b64
                case "assistant": avMe = b64
                case "gpt":       avGpt = b64
                case "wall":      wallpaper = b64
                default: break
                }
            }
        }
    }
}

// 打字框那层玻璃。跟顶栏胶囊不是一个形状，圆角 28。
private struct RTInputGlass: ViewModifier {
    let tint: Color
    let border: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint).interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(tint, in: shape)
                .overlay(shape.stroke(border, lineWidth: 1))
        }
    }
}
