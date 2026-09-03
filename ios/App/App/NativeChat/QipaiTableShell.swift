import SwiftUI
import UIKit

// 三张牌桌共用的外壳：背景、顶栏（返回/连接状态/聊天/帮助）、等人开局页、
// 牌桌聊天、toast、SSE 生命周期。游戏各自只画"开局之后"的桌面和自己的帮助页。

// ‼️0828 深夜两次塌房的教训：不要再把这个外壳塞进嵌套 UIHostingController
// （UIViewControllerRepresentable + safeAreaRegions 摘键盘那套）。d629340 和
// 568359c 两个构建实机都卡死在「重连中」——订阅/刷新在罩内不工作，机制没查清
//（这台机器没 Xcode），但结论是硬的：罩子=塌房。键盘豁免走各牌桌 cover 根上的
// .ignoresSafeArea(.keyboard)，这里保持 fc95a5a 验证过能跑的普通 SwiftUI 结构。
struct QipaiTableShell<GameV: Decodable & QipaiGameView, Content: View, Help: View>: View {
    @ObservedObject var store: QipaiTableStore<GameV>
    let fallbackTitle: String
    var round: Int?
    var onExit: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let help: () -> Help

    /// 全屏页自己管安全区（灵动岛会压顶栏，0828 她抓的）
    private var safeTop: CGFloat {
        // 0904：问 app 主窗，不问 key window（按住悬浮唱片时 key window 是那扇小窗，安全区为 0）
        let inset = FloatingOverlay.appWindow()?.safeAreaInsets.top ?? 0
        return max(inset, 8)
    }

    /// 底部同理：容器不给垫，home 条会盖住手牌区最下沿（0829 她抓的）
    private var safeBottom: CGFloat {
        FloatingOverlay.appWindow()?.safeAreaInsets.bottom ?? 0
    }

    @State private var showHelp = false
    @State private var inviteCopied = false

    /// 等人页现喊 AI 的名录（id, 短名），和建房面板那份同源
    static var aiRoster: [(id: String, name: String)] {
        [("chenjing", "陈璟"), ("external", "Fable·工程师"),
         ("opus", "Opus"), ("sonnet", "Sonnet"), ("haiku", "Haiku")]
    }

    var body: some View {
        // 键盘策略（0828 数次往复后照主聊天抄的定案）：
        // · 页面这层挂 .ignoresSafeArea(.keyboard) 对键盘装死——牌桌是钉死的
        //   固定布局，不豁免会被键盘压扁（主聊天页是滚动视图，不需要这层）。
        // · 浮条那层**不豁免**：照抄主聊天 floatingInput，扔给系统键盘避让，
        //   系统自动把它贴在键盘上沿，同步同曲线，不用自己听通知算高度。
        ZStack {
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
                    .padding(.bottom, safeBottom + 6)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
                }
                toast
            }
            .ignoresSafeArea([.container, .keyboard])
            floatingComposer
        }
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
            QipaiFloatingComposerBar(store: store)
        }
    }

    // MARK: 背景与顶栏

    private var background: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            // ‼️壁纸必须锁在 overlay+clipped 笼子里：裸的 scaledToFill 会把超出
            // 屏幕的尺寸上报给布局，把整个 ZStack 画布撑大——内容整体偏移、右缘
            // 裁切，键盘一动 proposal 变化还会再放大一轮（0828 追了一晚的「页面
            // 放大」和大厅「撑宽/右偏」悬案都是它）。笼子里它对布局零贡献。
            Color.clear
                .overlay(Image("QipaiWallPortrait2").resizable().scaledToFill())
                .clipped()
                .opacity(QipaiPalette.night ? 0.18 : 0.45)
                .ignoresSafeArea()
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
        .padding(.top, safeTop + 6)
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

// MARK: - 悬浮输入条本体

/// 真输入框只活在这里，全宽贴着键盘顶（她 0828 定的：中间不留缝、不罩黑影）。
/// 定位照抄主聊天 floatingInput：这层不豁免键盘安全区，底对齐交给系统避让，
/// 键盘升到哪它贴到哪，不听通知不算高度。
private struct QipaiFloatingComposerBar<GameV: Decodable & QipaiGameView>: View {
    @ObservedObject var store: QipaiTableStore<GameV>
    @State private var draft: String
    @FocusState private var focused: Bool

    init(store: QipaiTableStore<GameV>) {
        self.store = store
        _draft = State(initialValue: store.chatDraft)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 点空白处收键盘：完全透明的命中层，只接点按不压亮度。
            // 只豁免容器安全区（盖到状态栏），键盘那边留给系统量
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea(.container)
                .onTapGesture { dismissComposer() }
            bar
        }
        .onAppear {
            // 等浮层进树再拿焦点，立刻拿会抢不到
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        }
        .onDisappear { preserveDraft() }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            TextField("", text: $draft,
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
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
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
        preserveDraft()
        focused = false
        store.composing = false
    }

    private func send() {
        let text = draft
        draft = ""
        store.chatDraft = ""
        focused = false
        store.composing = false
        Task { await store.sendChat(text) }
    }

    private func preserveDraft() {
        if store.chatDraft != draft {
            store.chatDraft = draft
        }
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
                Button { store.composing = true } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
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
                    // 发言人按座位分色（0828 她要的）；对不上座位就回落原来的灰蓝
                    .foregroundColor(store.seatIndex(of: m).map(QipaiPalette.seatTone)
                                     ?? QipaiPalette.accent)
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
