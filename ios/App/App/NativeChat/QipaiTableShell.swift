import SwiftUI
import UIKit

// 三张牌桌共用的外壳：背景、顶栏（返回/连接状态/聊天/帮助）、等人开局页、
// 牌桌聊天、toast、SSE 生命周期。游戏各自只画"开局之后"的桌面和自己的帮助页。

struct QipaiTableShell<GameV: Decodable & QipaiGameView, Content: View, Help: View>: View {
    @ObservedObject var store: QipaiTableStore<GameV>
    let fallbackTitle: String
    var round: Int?
    var onExit: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let help: () -> Help

    /// 全屏页自己管安全区（灵动岛会压顶栏，0828 她抓的）
    private var safeTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let inset = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 0
        return max(inset, 8)
    }

    /// 底部同理：容器不给垫，home 条会盖住手牌区最下沿（0829 她抓的）
    private var safeBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
    }

    @State private var showHelp = false
    @State private var inviteCopied = false
    @StateObject private var keyboard = QipaiKeyboardWatcher()

    /// 等人页现喊 AI 的名录（id, 短名），和建房面板那份同源
    static var aiRoster: [(id: String, name: String)] {
        [("chenjing", "陈璟"), ("external", "Fable·工程师"),
         ("opus", "Opus"), ("sonnet", "Sonnet"), ("haiku", "Haiku")]
    }

    var body: some View {
        // 0828 四连修的终版：键盘来了**整页纹丝不动**，只有悬浮输入条贴在键盘上方。
        // 前三版病史——垫高整树（放大+掉帧）→ 只在 shell 的 ZStack 上挂
        // .ignoresSafeArea(.keyboard)（fullScreenCover 里不可靠，页面照样被顶得
        // 放大裁切）。终版从 UIKit 层根治：整页装进 QipaiKeyboardImmune（子
        // UIHostingController 的 safeAreaRegions 摘掉 .keyboard），系统从此
        // 不再为键盘调这棵树的安全区，页面物理上动不了。
        QipaiKeyboardImmune {
            ZStack {
                background
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        topBar
                        if let frame = store.frame {
                            if !frame.started {
                                waitingRoom(frame)
                            } else if store.view != nil {
                                content()
                            } else {
                                ProgressView().frame(maxHeight: .infinity)
                            }
                        } else {
                            ProgressView().frame(maxHeight: .infinity)
                        }
                    }
                    .padding(.bottom, safeBottom)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
                }
                toast
                floatingComposer
            }
            // 免疫罩内的安全区一律不认，顶底都由 safeTop/safeBottom 自己管（老规矩）
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear { store.start() }
        .onDisappear { store.stop() }
        .onChange(of: store.frame?.closed ?? false) { closed in
            if closed { onExit() }
        }
        .sheet(isPresented: $showHelp) { helpSheet }
    }

    // MARK: 悬浮输入条（信息流里的假框点一下召出来，真输入框只活在这里）

    @ViewBuilder private var floatingComposer: some View {
        if store.composing {
            QipaiFloatingComposerBar(store: store, keyboard: keyboard,
                                     safeBottom: safeBottom)
        }
    }

    // MARK: 背景与顶栏

    private var background: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            Image("QipaiWallPortrait2")
                .resizable().scaledToFill().ignoresSafeArea()
                .opacity(QipaiPalette.night ? 0.18 : 0.45)
            QipaiPalette.fog.opacity(QipaiPalette.night ? 0.72 : 0.55).ignoresSafeArea()
            QipaiDots(spacing: 18, radius: 1.2, opacity: 0.16).ignoresSafeArea()
        }
        .contentShape(Rectangle())
        // 0829 她抓的「键盘下不去」：点牌桌空白处收键盘。挂在背景层——
        // 面板、牌、输入框都盖在上面，只有真空白才落到这里，不会跟聚焦打架
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { onExit() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())

            VStack(alignment: .leading, spacing: 1) {
                Text(store.frame.map { $0.name.isEmpty ? $0.gameName : $0.name } ?? fallbackTitle)
                    .font(.system(size: 14.5, weight: .bold, design: .serif))
                    .foregroundColor(QipaiPalette.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(store.code).font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(QipaiPalette.inkDim)
                    if let round {
                        Text("第 \(round) 局").font(.system(size: 9.5))
                            .foregroundColor(QipaiPalette.inkDim)
                    }
                }
            }
            Spacer()
            Circle()
                .fill(store.connected ? QipaiPalette.accent : QipaiPalette.red)
                .frame(width: 7, height: 7)
            Text(store.connected ? "已连接" : "重连中")
                .font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
            Button { showHelp = true } label: {
                Image(systemName: "questionmark").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, safeTop)
        .padding(.bottom, 6)
    }

    // MARK: 等人开局

    private func waitingRoom(_ frame: QipaiTableFrame<GameV>) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("等人齊")
                .font(.qipaiDisplay(24))
                .foregroundColor(QipaiPalette.ink)
            Text("\(frame.seats.count)/\(frame.maxPlayers) 人 · 房号 \(frame.code)")
                .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
            VStack(spacing: 8) {
                ForEach(frame.seats) { seat in
                    HStack(spacing: 8) {
                        Image(systemName: seat.isAI ? "sparkles" : "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(QipaiPalette.accent)
                        Text(seat.name).font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(QipaiPalette.ink)
                        if seat.isHost { QipaiChip(text: "房主", tone: .live) }
                        Spacer()
                    }
                    .padding(11)
                    .qipaiPanel(corner: 13)
                }
            }
            .padding(.horizontal, 30)

            // 座位没满时房主可以现喊 AI（0829 她要的「中途加分身」）
            if store.isHost, frame.seats.count < frame.maxPlayers {
                VStack(spacing: 7) {
                    QipaiWhisper(text: "seats open — call in the machines")
                    HStack(spacing: 6) {
                        ForEach(Self.aiRoster, id: \.id) { ai in
                            Button(ai.name) { Task { await store.inviteAI(ai.id) } }
                                .buttonStyle(QipaiEmbossedButtonStyle())
                                .disabled(store.busy ||
                                          frame.seats.contains { $0.agentId == ai.id })
                        }
                    }
                }
            }

            if let invite = frame.inviteToken {
                Button {
                    UIPasteboard.general.string = QipaiAPI.inviteLink(
                        code: frame.code, inviteToken: invite,
                        service: QipaiAPI.service(for: frame.game))
                    inviteCopied = true
                } label: {
                    Label(inviteCopied ? "邀请链接已复制" : "复制邀请链接",
                          systemImage: inviteCopied ? "checkmark" : "link")
                }
                .buttonStyle(QipaiEmbossedButtonStyle())
            }

            Spacer()
            if store.isHost {
                if frame.seats.count >= frame.minPlayers {
                    QipaiSlideControl(label: "slide to 開局") { Task { await store.startGame() } }
                        .padding(.horizontal, 34)
                } else {
                    QipaiWhisper(text: "人齊了才能開。喊人，或者回大廳拉 AI。")
                }
            } else {
                QipaiWhisper(text: "等房主開局…")
            }
            Spacer().frame(height: 30)
        }
    }

    // MARK: toast / 聊天 / 帮助

    @ViewBuilder private var toast: some View {
        if let text = store.toast {
            VStack {
                Spacer()
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    // 固定深底白字，日夜都成立（夜里 ink 是月白，不能当底色）
                    .background(Capsule().fill(QipaiPalette.qhex(0x2A2F38).opacity(0.94)))
                    .padding(.bottom, 130)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: store.toast)
            .allowsHitTesting(false)
        }
    }

    private var helpSheet: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    help()
                    QipaiWhisper(text: "no real money. only face.")
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 键盘免疫罩

/// 把整页装进自己的 UIHostingController，从 safeAreaRegions 里摘掉 .keyboard。
/// SwiftUI 的键盘避让在 fullScreenCover 里对 .ignoresSafeArea(.keyboard) 阳奉阴违
/// （0828 两版实测：页面被顶得放大裁切），UIKit 这个开关是硬的：关了之后系统
/// 根本不往这棵树里塞键盘安全区，页面想动都没有入口。
private struct QipaiKeyboardImmune<Content: View>: UIViewControllerRepresentable {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = .container   // 只留容器安全区，键盘不算数
        host.view.backgroundColor = .clear
        return host
    }

    func updateUIViewController(_ host: UIHostingController<Content>, context: Context) {
        host.rootView = content
    }
}

// MARK: - 悬浮输入条本体

/// 真输入框只活在这里，全宽贴着键盘顶（她 0828 定的：中间不留缝、不罩黑影）。
/// FocusState 必须住在免疫罩里面这个子树里，跟外壳隔着 hosting controller 边界
/// 的焦点绑定靠不住。
private struct QipaiFloatingComposerBar<GameV: Decodable & QipaiGameView>: View {
    @ObservedObject var store: QipaiTableStore<GameV>
    @ObservedObject var keyboard: QipaiKeyboardWatcher
    let safeBottom: CGFloat
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // 点空白处收键盘：完全透明的命中层，只接点按不压亮度
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { dismissComposer() }
            bar
                // 底边直接坐在键盘上沿；键盘还没升起来的一瞬先垫 home 条，随它滑上去
                .padding(.bottom, keyboard.height > 0 ? keyboard.height : safeBottom)
                .animation(.easeOut(duration: 0.25), value: keyboard.height)
        }
        .onAppear {
            // 等浮层进树再拿焦点，立刻拿会抢不到
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            TextField("", text: Binding(get: { store.chatDraft },
                                        set: { store.chatDraft = $0 }),
                      prompt: Text("说点什么…")
                        .foregroundColor(QipaiPalette.inkDim.opacity(0.7)))
                .font(.system(size: 14))
                .foregroundColor(QipaiPalette.ink)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { send() }
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(Capsule().fill(QipaiPalette.fieldBg))
                .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 1))
            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill").font(.system(size: 13))
            }
            .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
            .disabled(store.chatDraft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14,
                                   style: .continuous)
                .fill(QipaiPalette.panel)
                .shadow(color: QipaiPalette.shadowTint.opacity(0.25), radius: 8, y: -2))
    }

    private func dismissComposer() {
        focused = false
        store.composing = false
    }

    private func send() {
        let text = store.chatDraft
        store.chatDraft = ""
        focused = false
        store.composing = false
        Task { await store.sendChat(text) }
    }
}

// MARK: - 键盘观察器（容器豁免安全区后系统避让失效，只能自己听通知）

final class QipaiKeyboardWatcher: ObservableObject {
    @Published var height: CGFloat = 0
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { return }
            self.height = max(0, UIScreen.main.bounds.height - frame.origin.y)
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.height = 0
        })
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }
}

// MARK: - 牌桌信息流（事件 + 聊天混排 + 打字框，三张牌桌共用）

struct QipaiFeedStrip<GameV: Decodable & QipaiGameView>: View {
    @ObservedObject var store: QipaiTableStore<GameV>

    var body: some View {
        VStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(store.feed) { item in row(item) }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
                .qipaiPanel(corner: 13)
                .onChange(of: store.feed.count) { _ in
                    if let last = store.feed.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let last = store.feed.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            // 0828 她的方案：这里只是个「假框」占位，点一下召出外壳层的悬浮输入条
            //（真输入框只活在那儿，贴着键盘）。整页因此在打字时纹丝不动。
            HStack(spacing: 8) {
                Text(store.chatDraft.isEmpty ? "说点什么…" : store.chatDraft)
                    .font(.system(size: 12.5))
                    .foregroundColor(store.chatDraft.isEmpty
                                     ? QipaiPalette.inkDim.opacity(0.7) : QipaiPalette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(Capsule().fill(QipaiPalette.fieldBg))
                    .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 1))
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12))
                    .foregroundColor(QipaiPalette.inkDim)
                    .padding(.horizontal, 10)
            }
            .contentShape(Rectangle())
            .onTapGesture { store.composing = true }
        }
    }

    /// 事件一条淡淡的横条，聊天是名字 + 白瓷气泡，一眼分得开
    @ViewBuilder private func row(_ item: QipaiFeedItem) -> some View {
        switch item {
        case .log(let e):
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("›").font(.system(size: 10, weight: .bold))
                    .foregroundColor(QipaiPalette.inkDim.opacity(0.6))
                Text(e.text)
                    .font(.system(size: 10.5))
                    .foregroundColor(["bomb", "finish", "showdown", "uno", "compare"].contains(e.type)
                                     ? QipaiPalette.red : QipaiPalette.inkDim)
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule().fill(QipaiPalette.panelDeep.opacity(0.45)))
        case .chat(let m):
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(QipaiPalette.accent)
                Text(m.text)
                    .font(.system(size: 12))
                    .foregroundColor(QipaiPalette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(QipaiPalette.fieldBg))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(QipaiPalette.line, lineWidth: 0.8))
            }
            .padding(.vertical, 1)
        }
    }
}
