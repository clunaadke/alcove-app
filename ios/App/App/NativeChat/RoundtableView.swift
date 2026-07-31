import SwiftUI

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
    @FocusState private var focused: Bool
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.wallGradient,
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
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
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textDim)
            }
            Text("圆桌")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            HStack(spacing: 10) {
                ForEach(store.members) { m in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(m.busy ? Color.orange : (m.online ? Color.green : Color.gray))
                            .frame(width: 6, height: 6)
                        Text(m.name)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textDim)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("桌上说点什么…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.textDim.opacity(0.10))
                )
                .focused($focused)
            Button {
                let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                draft = ""
                Task { await store.send(t) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(draft.isEmpty ? theme.textDim.opacity(0.35) : theme.fyAccent)
            }
            .disabled(draft.isEmpty || store.sending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct RoundtableRow: View {
    let msg: RoundtableMessage
    let showAvatar: Bool
    let theme: AlcoveTheme
    // 我的头像走设置里那个通道，跟聊天页同一张。G老师先默认那个 G。（她定的）
    @AppStorage("assistantAvatarDataURL") private var avatarDataURL = ""

    private var myAvatar: UIImage? {
        guard msg.role == "assistant", !avatarDataURL.isEmpty else { return nil }
        let parts = avatarDataURL.split(separator: ",", maxSplits: 1)
        let b64 = parts.count == 2 ? String(parts[1]) : avatarDataURL
        return Data(base64Encoded: b64).flatMap(UIImage.init(data:))
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

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Group {
                if showAvatar {
                    if let img = myAvatar {
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

            VStack(alignment: .leading, spacing: 3) {
                if showAvatar {
                    Text(msg.sender)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textDim.opacity(0.65))
                }
                // 气泡暂时不分颜色，她说的
                Text(msg.text)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.bubbleAI)
                    )
            }
            Spacer(minLength: 20)
        }
    }
}
