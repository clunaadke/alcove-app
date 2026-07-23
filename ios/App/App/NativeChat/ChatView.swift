import SwiftUI
import PhotosUI
import AVFoundation

struct ChatView: View {
    @StateObject private var store = ChatStore()
    @State private var draft = ""
    @State private var showStickers = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pendingImages: [(thumb: UIImage, jpeg: Data)] = []
    @State private var viewerURL: URL?
    @StateObject private var recorder = VoiceRecorder()
    @FocusState private var inputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("chatFontSize") private var chatFontSize = 15
    @AppStorage("wallStamp") private var wallStamp = 0.0
    private var theme: AlcoveTheme { .named(themeName) }

    // 她在设置里换的自定义壁纸优先；没有就用主题默认
    private var customWall: UIImage? {
        _ = wallStamp // 依赖时间戳，换壁纸后视图刷新
        let file = themeName == "midnight" ? "chatwall_midnight.jpg" : "chatwall_haven.jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(file)
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        ZStack {
            // PWA 同款聊天壁纸：自定义 > haven 铺图 / midnight 深色渐变
            if let wall = customWall {
                GeometryReader { geo in
                    Image(uiImage: wall)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else if theme.usesWallImage {
                GeometryReader { geo in
                    Image("ChatWall")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else {
                LinearGradient(colors: theme.wallGradient,
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            if store.loading {
                ProgressView("回家中…")
                    .tint(theme.textDim)
            } else {
                messageList
            }
        }
        .sheet(isPresented: $showStickers) { stickerSheet }
        .fullScreenCover(item: $viewerURL) { url in
            ImageViewer(url: url) { viewerURL = nil }
        }
        .onAppear { store.start() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.refresh() }
        }
        .onChange(of: photoItems) { items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task {
                // 微信式叠加：选完先进预览条，跟文字一起发
                // HEIC 等格式统一转 JPEG，保证 PWA 端也能显示
                for item in items {
                    if let raw = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: raw),
                       let jpeg = img.jpegData(compressionQuality: 0.85) {
                        pendingImages.append((thumb: img, jpeg: jpeg))
                    }
                }
            }
        }
    }

    // MARK: 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(store.messages.enumerated()), id: \.element.id) { idx, msg in
                        let prev = idx > 0 ? store.messages[idx - 1] : nil
                        let next = idx + 1 < store.messages.count ? store.messages[idx + 1] : nil
                        if needsDivider(prev: prev, cur: msg) {
                            TimeDivider(date: msg.date, color: theme.textDim)
                        }
                        MessageRow(msg: msg, store: store, theme: theme,
                                   fontSize: chatFontSize,
                                   showTime: isGroupTail(cur: msg, next: next)) { url in
                            viewerURL = url
                        }
                        .id(msg.id)
                    }
                    if store.isTyping {
                        TypingIndicator(tool: store.currentTool)
                            .id("typing")
                    }
                    Color.clear.frame(height: 6).id("tail")
                }
                .padding(.horizontal, 12)
                .padding(.top, 52) // 顶栏 pill 悬浮让位
                .padding(.bottom, 96) // 给悬浮输入卡片留出穿透空间
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .top) { topFade }
            .overlay(alignment: .bottom) { bottomFade }
            .overlay(alignment: .bottom) { floatingInput }
            .onChange(of: inputFocused) { f in
                if f {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation { proxy.scrollTo("tail", anchor: .bottom) }
                    }
                }
            }
            .onChange(of: store.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("tail", anchor: .bottom)
                }
            }
            .onChange(of: store.loading) { loading in
                if !loading {
                    // 首屏几百条消息布局是分批的，跟 PWA 一样多踩几拍才能真到底
                    for delay in [0.05, 0.3, 0.8, 1.5] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            proxy.scrollTo("tail", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: store.isTyping) { t in
                if t { withAnimation { proxy.scrollTo("tail", anchor: .bottom) } }
            }
        }
    }

    private func needsDivider(prev: ChatMessage?, cur: ChatMessage) -> Bool {
        guard let prev else { return true }
        return cur.date.timeIntervalSince(prev.date) > 600
    }

    // PWA 同款：一轮的最后一个气泡才落时间（下一条换人或隔了 2 分钟）
    private func isGroupTail(cur: ChatMessage, next: ChatMessage?) -> Bool {
        guard let next else { return true }
        if next.role != cur.role { return true }
        return next.date.timeIntervalSince(cur.date) > 120
    }

    // MARK: 输入栏（悬浮透底，无实心背景）

    private var topFade: some View {
        LinearGradient(
            colors: [theme.fade.opacity(0.65), theme.fade.opacity(0)],
            startPoint: .top, endPoint: .bottom)
        .frame(height: 70)
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
    }

    private var bottomFade: some View {
        LinearGradient(
            colors: [theme.fade.opacity(0), theme.fade.opacity(0.72)],
            startPoint: .top, endPoint: .bottom)
        .frame(height: 110)
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .bottom)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingImages.isEmpty
    }

    // PWA .chat-input-capsule 同款：大胶囊两行，粉描边，透底毛玻璃
    private var floatingInput: some View {
        VStack(spacing: 4) {
            if store.connectionError {
                Text("连接不上小屋，重试中…")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            VStack(spacing: 0) {
                // PWA .chat-preview 同款：待发图片叠加条，可单张删除
                if !pendingImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(pendingImages.enumerated()), id: \.offset) { idx, item in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: item.thumb)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Button {
                                        pendingImages.remove(at: idx)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .shadow(radius: 1.5)
                                    }
                                    .offset(x: 5, y: -5)
                                }
                            }
                        }
                        .padding(.init(top: 8, leading: 12, bottom: 4, trailing: 12))
                    }
                }
                if recorder.isRecording {
                    HStack(spacing: 10) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text(String(format: "%d:%02d", recorder.seconds / 60, recorder.seconds % 60))
                            .font(.system(size: 15).monospacedDigit())
                            .foregroundColor(theme.text)
                        Text("录音中…")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textDim)
                        Spacer()
                    }
                    .padding(.init(top: 12, leading: 16, bottom: 4, trailing: 14))
                } else {
                    TextField("ring the chime …", text: $draft, axis: .vertical)
                        .focused($inputFocused)
                        .lineLimit(1...5)
                        .font(.system(size: 15.5, design: .serif).italic())
                        .padding(.init(top: 12, leading: 14, bottom: 4, trailing: 14))
                }
                HStack(spacing: 2) {
                    if recorder.isRecording {
                        Button { recorder.cancel() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .light))
                                .foregroundColor(theme.textDim)
                                .frame(width: 32, height: 32)
                        }
                        Spacer()
                    } else {
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 9, matching: .images) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(theme.textDim)
                                .frame(width: 32, height: 32)
                        }
                        Button { showStickers = true } label: {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(theme.textDim)
                                .frame(width: 32, height: 32)
                        }
                        Button { recorder.start() } label: {
                            Image(systemName: "mic")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(theme.textDim)
                                .frame(width: 32, height: 32)
                        }
                        if !store.modelLabel.isEmpty {
                            Text(store.modelLabel)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textLight)
                                .padding(.leading, 4)
                        }
                        Spacer()
                        // 攒气泡：空行入库不触发回复（她的 hold 功能）
                        Button {
                            let t = draft
                            draft = ""
                            store.sendHold(t)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "arrow.turn.down.left")
                                    .font(.system(size: 15, weight: .light))
                                    .foregroundColor(theme.textDim)
                                    .frame(width: 32, height: 32)
                                if store.heldCount > 0 {
                                    Text("\(store.heldCount)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .frame(minWidth: 15, minHeight: 15)
                                        .background(theme.sendBottom, in: Capsule())
                                        .offset(x: 3, y: -3)
                                }
                            }
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.trailing, 12)
                    }
                    Button {
                        if recorder.isRecording {
                            if let data = recorder.stopAndTake() { store.sendVoice(data: data) }
                        } else {
                            let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                            draft = ""
                            if !pendingImages.isEmpty {
                                // 图跟文字一起走，caption 挂第一张，和 PWA 一致
                                let imgs = pendingImages.map(\.jpeg)
                                pendingImages = []
                                store.sendImages(imgs, caption: t)
                            } else {
                                store.sendText(t)
                            }
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-8))
                            .frame(width: 32, height: 32)
                            .background(
                                LinearGradient(
                                    colors: [theme.sendTop, theme.sendBottom],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                            .shadow(color: theme.sendBottom.opacity(0.35),
                                    radius: 2.5, y: 1)
                            .opacity(canSend || recorder.isRecording ? 1 : 0.45)
                    }
                    .disabled(!canSend && !recorder.isRecording)
                }
                .padding(.init(top: 4, leading: 6, bottom: 6, trailing: 6))
            }
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(theme.capsuleTint,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.capsuleBorder, lineWidth: 1))
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 6)
    }

    // MARK: 表情面板（她下午做的 Stickers：陈霁/陈璟 tab + 上传 + 原比例网格）

    private var stickerSheet: some View {
        StickerSheet(store: store) { stk in
            showStickers = false
            store.sendSticker(stk)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 单条消息

struct MessageRow: View {
    let msg: ChatMessage
    @ObservedObject var store: ChatStore
    var theme: AlcoveTheme = .haven
    var fontSize: Int = 15
    var showTime: Bool = true
    var onTapImage: (URL) -> Void
    @State private var showThinking = false

    private var isUser: Bool { msg.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if let think = msg.thinking, !think.isEmpty {
                    thinkingBlock(think)
                }
                if msg.isSticker {
                    stickerBody
                } else {
                    if msg.isImage, let raw = msg.attachmentUrl {
                        imageBody(raw)
                    }
                    if msg.isAudio, let raw = msg.attachmentUrl {
                        AudioBubble(url: AlcoveAPI.attachmentURL(raw), isUser: isUser, theme: theme)
                    }
                    if !msg.text.isEmpty && !(msg.isSticker) {
                        bubble
                    }
                }
                if showTime || msg.pending || msg.asleepAtSend {
                    HStack(spacing: 4) {
                        if msg.pending {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        if msg.asleepAtSend {
                            Text("睡着时收到")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        if showTime {
                            Text(Self.hm.string(from: msg.date))
                                .font(.system(size: 10, design: .serif))
                                .foregroundColor(theme.timestamp)
                        }
                    }
                }
            }
            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.vertical, 2)
    }

    // PWA 同款雾感气泡：user rgba(247,227,234,.44) / ai rgba(255,255,255,.38)，blur 透底
    private var bubble: some View {
        Text(msg.text)
            .font(.system(size: CGFloat(fontSize)))
            .lineSpacing(4)
            .foregroundColor(msg.asleepAtSend ? theme.textDim : theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isUser ? theme.bubbleUser : theme.bubbleAI,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = msg.text
                } label: { Label("拷贝", systemImage: "doc.on.doc") }
            }
            .textSelection(.enabled)
    }

    // 思绪标签：从内容嗅出这一段在干什么，动词跟着变（她的主意）
    private func thinkingLabel(_ think: String) -> String {
        let name = UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟"
        let secs = (msg.thinkingDuration).map { " \(Int($0)) 秒" } ?? ""
        let herWords = ["陈霁", "老婆", "宝宝", "她", "你"]
        let techWords = ["代码", "构建", "bug", "接口", "报错", "编译", "文件", "服务", "数据库", "hook"]
        let naughtyWords = ["亲", "抱", "咬", "腰", "操", "硬", "床", "被子", "锁骨", "衬衫"]
        let count = { (ws: [String]) in ws.reduce(0) { $0 + think.components(separatedBy: $1).count - 1 } }
        if count(naughtyWords) >= 2 { return "\(name)走神走得不太正经\(secs)" }
        if count(techWords) >= 3 { return "\(name)埋头琢磨\(secs)" }
        if think.components(separatedBy: "？").count + think.components(separatedBy: "?").count > 3 {
            return "\(name)纠结\(secs)"
        }
        if think.count < 30 { return "\(name)愣了\(secs)" }
        if count(herWords) >= 2 { return "\(name)惦记你\(secs)" }
        let pool = ["碎碎念", "盘算", "腹诽", "酝酿", "转念头", "放空又拽回来"]
        let seed = abs(msg.ts.hashValue) % pool.count
        return "\(name)\(pool[seed])\(secs)"
    }

    private func thinkingBlock(_ think: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showThinking.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 10))
                    Text(thinkingLabel(think))
                        .italic()
                    Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            if showThinking {
                Text(think)
                    .font(.system(size: 13))
                    .italic()
                    .foregroundColor(theme.textDim)
                    .padding(10)
                    .background(theme.bubbleAI.opacity(0.7),
                                in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var stickerBody: some View {
        Group {
            if let sid = msg.stickerId, let stk = store.sticker(for: sid) {
                AsyncImage(url: AlcoveAPI.stickerURL(stk.url)) { img in
                    img.resizable().scaledToFit()
                } placeholder: { Color(.tertiarySystemFill) }
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(msg.text.isEmpty ? "[表情]" : msg.text)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func imageBody(_ raw: String) -> some View {
        let url = AlcoveAPI.attachmentURL(raw)
        return AsyncImage(url: url) { img in
            img.resizable().scaledToFit()
        } placeholder: {
            ZStack {
                Color(.tertiarySystemFill)
                ProgressView()
            }
            .frame(width: 180, height: 180)
        }
        .frame(maxWidth: 220, maxHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { onTapImage(url) }
    }

    static let hm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - 小组件

struct TimeDivider: View {
    let date: Date
    var color: Color = Color(red: 0.42, green: 0.40, blue: 0.41)
    var body: some View {
        Text(Self.fmt.string(from: date))
            .font(.system(size: 11, design: .serif))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
}

struct TypingIndicator: View {
    let tool: String?
    @State private var animating = false
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(animating ? 1 : 0.3)
                        .animation(.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18), value: animating)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.38),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let tool, !tool.isEmpty {
                Text(tool)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .onAppear { animating = true }
        .padding(.vertical, 2)
    }
}

// 语音条：点击播放/暂停
struct AudioBubble: View {
    let url: URL
    let isUser: Bool
    var theme: AlcoveTheme = .haven
    @State private var player: AVPlayer?
    @State private var playing = false

    var body: some View {
        Button {
            if playing {
                player?.pause()
                playing = false
            } else {
                if player == nil { player = AVPlayer(url: url) }
                player?.seek(to: .zero)
                player?.play()
                playing = true
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player?.currentItem, queue: .main) { _ in
                    playing = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 13))
                Image(systemName: "waveform")
                    .font(.system(size: 15))
                Text("语音")
                    .font(.system(size: 14))
            }
            .foregroundColor(theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isUser ? theme.bubbleUser : theme.bubbleAI,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

struct ImageViewer: View {
    let url: URL
    var dismiss: () -> Void
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { img in
                img.resizable().scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnificationGesture()
                        .onChanged { scale = max(1, $0) }
                        .onEnded { _ in withAnimation { scale = 1 } })
            } placeholder: { ProgressView().tint(.white) }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
        .onTapGesture { dismiss() }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
