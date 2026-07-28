import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct ChatView: View {
    @StateObject private var store = ChatStore()
    @State private var draft = ""
    @State private var showStickers = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pendingImages: [(thumb: UIImage, jpeg: Data)] = []
    @State private var viewerURL: URL?
    @StateObject private var recorder = VoiceRecorder()
    @State private var atBottom = true
    @State private var showCamera = false
    @State private var showDocPicker = false
    @State private var showPhotoPicker = false
    @State private var previewImage: UIImage?
    @State private var inputBarHeight: CGFloat = 90
    @State private var scrollKick = 0
    @FocusState private var inputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("chatFontSize") private var chatFontSize = 15
    @AppStorage("wallStamp") private var wallStamp = 0.0
    private var theme: AlcoveTheme { .named(themeName) }
    private var safeBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }

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
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                if let jpeg = image.jpegData(compressionQuality: 0.85) {
                    pendingImages.append((thumb: image, jpeg: jpeg))
                }
            }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPicker { urls in
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        let name = url.lastPathComponent
                        store.sendImage(data: data, filename: name, caption: "")
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoLibraryPicker(maxCount: 9) { images in
                for img in images {
                    if let jpeg = img.jpegData(compressionQuality: 0.85) {
                        pendingImages.append((thumb: img, jpeg: jpeg))
                    }
                }
            }
        }
        .fullScreenCover(item: $viewerURL) { url in
            ImageViewer(url: url) { viewerURL = nil }
        }
        .fullScreenCover(item: $previewImage) { img in
            LocalImageViewer(image: img) { previewImage = nil }
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
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(store.messages.enumerated()), id: \.element.id) { idx, msg in
                            let prev = idx > 0 ? store.messages[idx - 1] : nil
                            let next = idx + 1 < store.messages.count ? store.messages[idx + 1] : nil
                            if needsDivider(prev: prev, cur: msg) {
                                TimeDivider(date: msg.date, color: theme.textDim)
                            }
                            MessageRow(msg: msg,
                                       sticker: msg.stickerId.flatMap(store.sticker(for:)),
                                       theme: theme,
                                       fontSize: chatFontSize,
                                       showTime: isGroupTail(cur: msg, next: next),
                                       recall: (msg.role == "assistant" && prev?.role == "user")
                                           ? store.recall(forUserText: prev?.text ?? "") : nil,
                                       onTapImage: { url in viewerURL = url },
                                       onDelete: { store.deleteMessage(msg) },
                                       onFavorite: { store.favoriteMessage(msg) },
                                       onQuote: { text in draft = "「\(text.prefix(60))」\n" },
                                       onResend: { text in store.sendText(text) },
                                       onContentChange: { scrollKick += 1 })
                            .id(msg.id)
                        }
                        if store.isTyping {
                            TypingIndicator(tool: store.currentTool,
                                            line: store.typingLine,
                                            name: UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟",
                                            theme: theme)
                                .id("typing")
                        }
                        Color.clear.frame(height: inputBarHeight + 8)
                        Color.clear.frame(height: 1).id("tail")
                            .onAppear { atBottom = true }
                            .onDisappear { atBottom = false }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 52)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { inputFocused = false }
                .mask(edgeFadeMask)

                floatingInput

                if !atBottom {
                    Button {
                        withAnimation { proxy.scrollTo("tail", anchor: .bottom) }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textDim)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .background(theme.glassTint, in: Circle())
                            .overlay(Circle().stroke(theme.glassBorder, lineWidth: 1))
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, inputBarHeight + 12)
                    .transition(.opacity)
                }

                ClawdPet(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 12)
                    .padding(.bottom, inputBarHeight + 8)
            }
            .onAppear {
                atBottom = true
                scrollToTail(proxy, delays: [0, 0.08, 0.25, 0.6, 1.1], animated: false)
            }
            .onChange(of: inputFocused) { f in
                if f {
                    scrollToTail(proxy, delays: [0.05, 0.25, 0.5], animated: true)
                } else {
                    scrollToTail(proxy, delays: [0.1, 0.35], animated: true)
                }
            }
            .onChange(of: store.messages.count) { _ in
                guard atBottom || inputFocused else { return }
                scrollToTail(proxy, delays: [0, 0.15, 0.4], animated: true)
            }
            .onChange(of: store.loading) { loading in
                if !loading {
                    scrollToTail(proxy, delays: [0.05, 0.3, 0.8, 1.5], animated: false)
                }
            }
            .onChange(of: store.isTyping) { t in
                if atBottom || inputFocused {
                    scrollToTail(proxy, delays: [0, 0.2, 0.5], animated: true)
                }
            }
            .onChange(of: inputBarHeight) { _ in
                if atBottom || inputFocused {
                    scrollToTail(proxy, delays: [0.05, 0.3], animated: true)
                }
            }
            .onChange(of: scrollKick) { _ in
                if atBottom || inputFocused {
                    scrollToTail(proxy, delays: [0.05, 0.3, 0.6], animated: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .alcoveJumpToMessage)) { note in
                if let ts = note.object as? String,
                   let target = store.messages.first(where: { $0.ts == ts }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation { proxy.scrollTo(target.id, anchor: .center) }
                    }
                }
            }
        }
    }

    private func scrollToTail(
        _ proxy: ScrollViewProxy,
        delays: [Double],
        animated: Bool
    ) {
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if animated {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("tail", anchor: .bottom)
                    }
                } else {
                    proxy.scrollTo("tail", anchor: .bottom)
                }
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

    // MARK: alpha淡出mask（不用背景色渐变，内容本身按alpha淡出）

    private var edgeFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.15),
                    .init(color: .black.opacity(0.3), location: 0.4),
                    .init(color: .black.opacity(0.7), location: 0.65),
                    .init(color: .black, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            Color.black
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.7), location: 0.3),
                    .init(color: .black.opacity(0.3), location: 0.6),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: inputBarHeight + 8)
        }
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
                                        .onTapGesture { previewImage = item.thumb }
                                    Button {
                                        pendingImages.remove(at: idx)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .offset(x: 6, y: -6)
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
                    .padding(.init(top: 16, leading: 14, bottom: 4, trailing: 14))
                } else {
                    TextField(
                        "",
                        text: $draft,
                        prompt: Text("ring the chime …")
                            .font(.system(size: 15.5, design: .serif))
                            .italic(),
                        axis: .vertical
                    )
                    .focused($inputFocused)
                    .lineLimit(1...5)
                    .font(.system(size: 15.5, weight: .regular, design: .default))
                    .tint(Color(uiColor: .systemGray3))
                    .padding(.init(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .contentShape(Rectangle())
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
                        Menu {
                            Button { showPhotoPicker = true } label: {
                                Label("从相册选择", systemImage: "photo.on.rectangle")
                            }
                            Button { showCamera = true } label: {
                                Label("拍照或录像", systemImage: "camera")
                            }
                            Button { showDocPicker = true } label: {
                                Label("选取文件", systemImage: "doc")
                            }
                        } label: {
                            Image(systemName: "paperclip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textDim)
                                .frame(width: 32, height: 32)
                        }
                        Button { showStickers = true } label: {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textDim)
                                .frame(width: 32, height: 32)
                        }
                        Button { recorder.start() } label: {
                            Image(systemName: "mic")
                                .font(.system(size: 16, weight: .medium))
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
                            Image(systemName: "arrow.turn.down.left")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textDim)
                                    .frame(width: 32, height: 32)
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
                                let imgs = pendingImages.map(\.jpeg)
                                pendingImages = []
                                store.sendImages(imgs, caption: t)
                            } else {
                                store.sendText(t)
                            }
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-8))
                            .frame(width: 36, height: 36)
                            .background(
                                LinearGradient(
                                    colors: [theme.sendTop, theme.sendBottom],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2),
                                    radius: 4, y: 2)
                            .opacity(canSend || recorder.isRecording ? 1 : 0.35)
                    }
                    .disabled(!canSend && !recorder.isRecording)
                }
                .padding(.init(top: 4, leading: 8, bottom: 16, trailing: 8))
            }
            .modifier(InteractiveInputGlassModifier(fallbackTint: theme.capsuleTint))
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 2)
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 0)
        .background(GeometryReader { geo in
            Color.clear.preference(key: InputBarHeightKey.self, value: geo.size.height)
        })
        .onPreferenceChange(InputBarHeightKey.self) { inputBarHeight = $0 }
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
    let sticker: Sticker?
    var theme: AlcoveTheme = .haven
    var fontSize: Int = 15
    var showTime: Bool = true
    var recall: RecallItem? = nil
    var onTapImage: (URL) -> Void
    var onDelete: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil
    var onQuote: ((String) -> Void)? = nil
    var onResend: ((String) -> Void)? = nil
    var onContentChange: (() -> Void)? = nil
    @State private var showThinking = false
    @State private var showRecall = false

    private var isUser: Bool { msg.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if let think = msg.thinking, !think.isEmpty {
                    thinkingBlock(think)
                } else if recall != nil {
                    recallBadge // 没有思绪行时角标单独站一行，和 PWA 一致
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
    private func markdownText(_ raw: String) -> Text {
        if let attr = try? AttributedString(markdown: raw,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attr)
        }
        return Text(raw)
    }

    private var bubble: some View {
        markdownText(msg.text)
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
                if let onQuote {
                    Button {
                        onQuote(msg.text)
                    } label: { Label("引用", systemImage: "quote.bubble") }
                }
                if let onFavorite {
                    Button {
                        onFavorite()
                    } label: { Label("收藏", systemImage: "bookmark") }
                }
                if isUser, let onResend {
                    Button {
                        onResend(msg.text)
                    } label: { Label("重发", systemImage: "arrow.clockwise") }
                }
                if let onDelete {
                    Divider()
                    Button(role: .destructive) {
                        onDelete()
                    } label: { Label("删除", systemImage: "trash") }
                }
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 10))
                    Text(thinkingLabel(think))
                        .font(.custom("Georgia", size: 11))
                        .italic()
                    Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                    if recall != nil {
                        recallBadge.padding(.leading, 6)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            if showThinking {
                Text(think)
                    .font(.custom("Georgia", size: max(11, CGFloat(fontSize) - 2)))
                    .italic()
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(theme.textDim)
                    .padding(10)
                    .background(theme.bubbleAI.opacity(0.7),
                                in: RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { showThinking = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
                    }
            }
        }
    }

    private var recallBadge: some View {
        Button {
            showRecall = true
        } label: {
            Text("✦ ··· 记起")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundColor(theme.textDim)
        }
        .sheet(isPresented: $showRecall) {
            if let recall { RecallPop(item: recall) }
        }
    }

    private var stickerBody: some View {
        Group {
            if let stk = sticker {
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
    var line: String = "思考"
    var name: String = "陈璟"
    var theme: AlcoveTheme = .haven
    @State private var animating = false
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
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
                .background(theme.bubbleAI,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("\(name)正在\(line)中…")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textDim)
                Spacer()
            }
            if let tool, !tool.isEmpty {
                // 工具原文她要留着：Bash — 追头像变量aa的赋值来源
                Text(tool)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.textLight)
                    .lineLimit(1)
                    .padding(.leading, 4)
            }
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
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { img in
                img.resizable().scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnificationGesture()
                        .onChanged { scale = max(1, $0) }
                        .onEnded { _ in withAnimation { scale = 1 } })
            } placeholder: { ProgressView().tint(.white) }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 居中铺满
        }
        .overlay(alignment: .topTrailing) {
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

// 记忆召回弹层：✦记起 点开看召回的记忆卡片
struct RecallPop: View {
    let item: RecallItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(item.cards.enumerated()), id: \.offset) { _, card in
                        VStack(alignment: .leading, spacing: 6) {
                            if !card.date.isEmpty {
                                Text(card.date)
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundColor(.secondary)
                            }
                            Text(card.body)
                                .font(.system(size: 13))
                                .foregroundColor(.primary.opacity(0.85))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(14)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("✦ 那一刻我想起的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct InteractiveInputGlassModifier: ViewModifier {
    let fallbackTint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(fallbackTint, in: shape)
        }
    }
}

private struct InputBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 20
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                 tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                 tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

private struct InputBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 90
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

struct LocalImageViewer: View {
    let image: UIImage
    var dismiss: () -> Void
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(MagnificationGesture()
                    .onChanged { scale = max(1, $0) }
                    .onEnded { _ in withAnimation { scale = 1 } })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
        .onTapGesture { dismiss() }
    }
}

struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var maxCount: Int = 9
    var onPick: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxCount
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard !results.isEmpty else { return }
            var images: [UIImage] = []
            let group = DispatchGroup()
            for result in results {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage { images.append(img) }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.parent.onPick(images)
            }
        }
    }
}
