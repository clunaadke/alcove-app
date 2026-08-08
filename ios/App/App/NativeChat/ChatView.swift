import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct ChatView: View {
    @StateObject private var store = ChatStore()
    @StateObject private var wallpaperStore = ChatWallpaperStore()
    @State private var draft = ""
    @State private var showStickers = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pendingImages: [(thumb: UIImage, jpeg: Data)] = []
    @State private var photoViewer: PhotoViewerSelection?
    @StateObject private var recorder = VoiceRecorder()
    @State private var atBottom = true
    @State private var showCamera = false
    @State private var showDocPicker = false
    @State private var showPhotoPicker = false
    @Namespace private var photoTransition
    @State private var previewImage: UIImage?
    @State private var inputBarHeight: CGFloat = 90
    @State private var scrollKick = 0
    @State private var showMusicPlayer = false
    @State private var showModelPicker = false
    @State private var switchingModel = false
    @State private var modelSwitchError = ""
    @ObservedObject private var music = MusicModel.shared
    @FocusState private var inputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("chatFontSize") private var chatFontSize = 14
    @AppStorage("wallStamp") private var wallStamp = 0.0
    @AppStorage("bubbleGlassStrength") private var bubbleGlassStrength = 56.81
    @AppStorage("bubbleGlassDispersion") private var bubbleGlassDispersion = 0.39
    @AppStorage("bubbleGlassRimWidth") private var bubbleGlassRimWidth = 0.28
    @AppStorage("bubbleGlassMagnify") private var bubbleGlassMagnify = 0.0
    @AppStorage("bubbleGlassBlur") private var bubbleGlassBlur = 0.10
    @AppStorage("bubbleGlassSize") private var bubbleGlassSize = 174.33
    private var theme: AlcoveTheme { .named(themeName) }
    private var bubbleGlassStyle: BubbleGlassStyle {
        BubbleGlassStyle(
            strength: CGFloat(bubbleGlassStrength),
            dispersion: CGFloat(bubbleGlassDispersion),
            rimWidth: CGFloat(bubbleGlassRimWidth),
            magnify: CGFloat(bubbleGlassMagnify),
            backdropBlur: CGFloat(bubbleGlassBlur),
            size: CGFloat(bubbleGlassSize)
        )
    }
    private var safeBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        GeometryReader { root in
            ZStack {
                // The visible wall and every bubble lens share this same
                // prepared image and coordinate system.
                ChatWallpaperRenderer(descriptor: wallpaperStore.descriptor)
                    .ignoresSafeArea()

                if store.loading {
                    ProgressView("回家中…")
                        .tint(theme.textDim)
                } else {
                    messageList
                }
            }
            .coordinateSpace(name: "alcoveChatRoot")
            .environment(\.chatWallpaperDescriptor, wallpaperStore.descriptor)
            .environment(\.chatWallpaperViewportSize, root.size)
            .environment(\.bubbleGlassStyle, bubbleGlassStyle)
        }
        .sheet(isPresented: $showStickers) { stickerSheet }
        .sheet(isPresented: $showMusicPlayer) {
            MusicPlayerSheet(model: music)
                .presentationDetents([.fraction(0.72)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
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
        .fullScreenCover(item: $photoViewer) { selection in
            PhotoPageViewer(selection: selection, namespace: photoTransition) { photoViewer = nil }
        }
        .fullScreenCover(item: $previewImage) { img in
            LocalImageViewer(image: img) { previewImage = nil }
        }
        .onAppear {
            wallpaperStore.refresh(
                themeName: themeName,
                theme: theme,
                wallStamp: wallStamp
            )
            store.start()
            music.startRemotePolling()
        }
        .onChange(of: themeName) { newThemeName in
            wallpaperStore.refresh(
                themeName: newThemeName,
                theme: .named(newThemeName),
                wallStamp: wallStamp
            )
        }
        .onChange(of: wallStamp) { newStamp in
            wallpaperStore.refresh(
                themeName: themeName,
                theme: theme,
                wallStamp: newStamp
            )
        }
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
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(store.messages.enumerated()), id: \.element.id) { idx, msg in
                            chatMessageRow(at: idx, message: msg)
                        }
                        // 0730 实时预览：他说完一段就先冒出来，不等整轮工具跑完
                        if let lv = store.live {
                            LiveSayBand(state: lv, theme: theme)
                                .id("liveband")
                                .transition(.opacity)
                        }
                        if store.isTyping {
                            TypingIndicator(tool: store.currentTool,
                                            line: store.typingLine,
                                            name: UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟",
                                            theme: theme)
                                .id("typing")
                        }
                        Color.clear.frame(height: inputBarHeight + (music.nowPlaying == nil ? 8 : 76))
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

                if music.nowPlaying != nil {
                    MusicMiniPlayer(model: music) { showMusicPlayer = true }
                        .padding(.horizontal, 12)
                        .padding(.bottom, inputBarHeight + 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

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
            // 0731 实时预览带自己在长，外层也得跟着滚，不然她卡在框刚冒出来那一屏
            .onChange(of: store.live) { _ in
                if atBottom || inputFocused {
                    scrollToTail(proxy, delays: [0, 0.15], animated: true)
                }
            }
            .onChange(of: scrollKick) { _ in
                if atBottom || inputFocused {
                    // 展开 thinking/activity 时内容本身已经在做 0.15s 动画。
                    // 再连跑三次滚尾会让整页先上再下，真机看起来像闪一下。
                    // 等布局落稳后无动画校正一次就够了。
                    scrollToTail(proxy, delays: [0.18], animated: false)
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

    @ViewBuilder
    private func chatMessageRow(at index: Int, message: ChatMessage) -> some View {
        if !isPhotoGroupContinuation(at: index) {
            let previous = index > 0 ? store.messages[index - 1] : nil
            let photos = chatPhotoGroup(startingAt: index)
            let groupEnd = index + max(photos.count, 1) - 1
            let next = groupEnd + 1 < store.messages.count ? store.messages[groupEnd + 1] : nil
            let recall = message.role == "assistant" && previous?.role == "user"
                ? store.recall(forUserText: previous?.text ?? "")
                : nil

            if needsDivider(prev: previous, cur: message) {
                TimeDivider(date: message.date, color: theme.textDim)
            }
            MessageRow(
                msg: message,
                sticker: message.stickerId.flatMap(store.sticker(for:)),
                theme: theme,
                fontSize: chatFontSize,
                showTime: isGroupTail(cur: store.messages[groupEnd], next: next),
                recall: recall,
                photoURLs: photos,
                photoNamespace: photoTransition,
                onTapImages: { urls, selectedIndex in
                    photoViewer = PhotoViewerSelection(
                        urls: urls,
                        index: selectedIndex,
                        sourceID: "chat-\(message.id)"
                    )
                },
                onDelete: { store.deleteMessage(message) },
                onFavorite: { store.favoriteMessage(message) },
                onQuote: { text in draft = "「\(text.prefix(60))」\n" },
                onResend: { text in store.sendText(text) },
                onPlayMusic: { song in Task { await music.play(song) } },
                onContentChange: { scrollKick += 1 }
            )
            .id(message.id)
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

    private func chatPhotoGroup(startingAt index: Int) -> [URL] {
        guard index < store.messages.count,
              let key = store.messages[index].photoBatchKey else { return [] }
        var urls: [URL] = []
        var i = index
        while i < store.messages.count,
              store.messages[i].photoBatchKey == key,
              let raw = store.messages[i].attachmentUrl {
            urls.append(AlcoveAPI.attachmentURL(raw))
            i += 1
        }
        return urls.count > 1 ? urls : []
    }

    private func isPhotoGroupContinuation(at index: Int) -> Bool {
        guard index > 0, let key = store.messages[index].photoBatchKey else { return false }
        return store.messages[index - 1].photoBatchKey == key
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
                    .padding(.init(top: 16, leading: 14, bottom: 12, trailing: 14))
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
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                    showModelPicker.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if switchingModel { ProgressView().controlSize(.mini) }
                                    Text(store.modelLabel)
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.textLight)
                                .padding(.horizontal, 9).frame(height: 27)
                                .background(theme.glassTint.opacity(theme.isDark ? 0.72 : 0.92),
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(theme.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(switchingModel)
                            .popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
                                modelPickerCard
                                    .presentationCompactAdaptation(.popover)
                            }
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
                .padding(.init(top: 4, leading: 8, bottom: 8, trailing: 8))
            }
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.clear)
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .onTapGesture {
                        guard !recorder.isRecording else { return }
                        inputFocused = true
                    }
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

    private struct ClaudeModelOption: Identifiable {
        let id: String
        let label: String
        let note: String
    }

    private var claudeModels: [ClaudeModelOption] {[
        .init(id: "claude-fable-5", label: "Fable 5", note: "需要 usage credits"),
        .init(id: "claude-opus-5", label: "Opus 5", note: "最强推理"),
        .init(id: "claude-sonnet-5", label: "Sonnet 5", note: "日常更快"),
        .init(id: "claude-haiku-4-5", label: "Haiku 4.5", note: "最快"),
        .init(id: "claude-opus-4-8", label: "Opus 4.8", note: ""),
        .init(id: "claude-opus-4-7", label: "Opus 4.7", note: ""),
        .init(id: "claude-opus-4-6", label: "Opus 4.6", note: ""),
        .init(id: "claude-sonnet-4-6", label: "Sonnet 4.6", note: "")
    ]}

    private var modelPickerCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(claudeModels.enumerated()), id: \.element.id) { index, option in
                Button { switchClaudeModel(option) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label).font(.system(size: 13, weight: .medium))
                            if !option.note.isEmpty {
                                Text(option.note).font(.system(size: 9)).foregroundColor(theme.textDim)
                            }
                        }
                        Spacer()
                        if store.modelLabel == option.label {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.sendTop)
                        }
                    }.padding(.horizontal, 13).frame(minHeight: option.note.isEmpty ? 38 : 46)
                }.buttonStyle(.plain)
                if index < claudeModels.count - 1 { Divider().opacity(0.45).padding(.horizontal, 10) }
            }
            if !modelSwitchError.isEmpty {
                Text(modelSwitchError).font(.system(size: 10)).foregroundColor(.red)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .foregroundColor(theme.text)
        .frame(width: 238)
        .padding(.vertical, 6)
        .background(theme.isDark ? Color.black.opacity(0.48) : Color.white.opacity(0.58))
    }

    private func switchClaudeModel(_ option: ClaudeModelOption) {
        guard !switchingModel, store.modelLabel != option.label else { showModelPicker = false; return }
        guard !store.isTyping, store.live?.active != true else {
            modelSwitchError = "他还在说话  等他说完再换"
            return
        }
        switchingModel = true
        modelSwitchError = ""
        Task {
            do {
                let screen = try await AlcoveAPI.terminalCapture()
                let tail = screen.components(separatedBy: .newlines).suffix(12).joined(separator: "\n")
                guard tail.contains("❯") && !tail.localizedCaseInsensitiveContains("esc to interrupt") else {
                    throw NSError(domain: "AlcoveModel", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "他还没空下来"])
                }
                try await AlcoveAPI.terminalSend("/model \(option.id)")
                var confirmed = false
                for _ in 0..<6 {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    if (try? await AlcoveAPI.modelLabel()) == option.label { confirmed = true; break }
                }
                guard confirmed else {
                    throw NSError(domain: "AlcoveModel", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "没收到切换成功回执"])
                }
                store.modelLabel = option.label
                showModelPicker = false
            } catch {
                modelSwitchError = error.localizedDescription
            }
            switchingModel = false
        }
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
    var fontSize: Int = 14
    var showTime: Bool = true
    var recall: RecallItem? = nil
    var photoURLs: [URL] = []
    var photoNamespace: Namespace.ID
    var onTapImages: ([URL], Binding<Int>) -> Void
    var onDelete: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil
    var onQuote: ((String) -> Void)? = nil
    var onResend: ((String) -> Void)? = nil
    var onPlayMusic: ((MusicSong) -> Void)? = nil
    var onContentChange: (() -> Void)? = nil
    @State private var showThinking = false
    @State private var showActivity = false   // 0730 过程记录展开
    @State private var showRecall = false
    @Environment(\.bubbleGlassStyle) private var bubbleGlassStyle

    private var isUser: Bool { msg.role == "user" }
    private var timestampTextInset: CGFloat {
        !msg.text.isEmpty && !msg.isSticker ? 12 : 0
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 7) {
                if let think = msg.thinking, !think.isEmpty {
                    thinkingBlock(think)
                } else if recall != nil {
                    recallBadge // 没有思绪行时角标单独站一行，和 PWA 一致
                }
                if msg.isSticker {
                    stickerBody
                } else {
                    if photoURLs.count > 1 {
                        PhotoStackMessageView(urls: photoURLs, messageID: "chat-\(msg.id)",
                                              onOpen: onTapImages)
                            .matchedTransitionSource(id: "chat-\(msg.id)", in: photoNamespace)
                    } else if msg.isImage, let raw = msg.attachmentUrl {
                        imageBody(raw)
                    }
                    if msg.isAudio, let raw = msg.attachmentUrl {
                        AudioBubble(url: AlcoveAPI.attachmentURL(raw), isUser: isUser, theme: theme)
                    }
                    if let song = msg.musicCard {
                        MusicMessageCard(song: song, theme: theme) { onPlayMusic?(song) }
                    } else if !msg.text.isEmpty && !(msg.isSticker) {
                        bubble
                    }
                }
                if showTime || msg.pending || msg.asleepAtSend || msg.hasActivity {
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
                        if theme.isPaper && !isUser && !msg.text.isEmpty {
                            Button { UIPasteboard.general.string = msg.text } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(theme.timestamp)
                                    .frame(width: 32, height: 32, alignment: .leading)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                        // 0730：这一轮的过程记录，挂在时间戳旁边，点开看他到底干了什么
                        if msg.hasActivity {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { showActivity.toggle() }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
                            } label: {
                                Text(activityChipLabel)
                                    .font(.system(size: 10, design: .serif))
                                    .foregroundColor(theme.timestamp)
                                    .opacity(showActivity ? 1.0 : 0.62)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, isUser ? 0 : timestampTextInset)
                    .padding(.trailing, isUser ? timestampTextInset : 0)

                    if showActivity && msg.hasActivity {
                        activityPanel
                            .padding(.leading, isUser ? 0 : timestampTextInset)
                            .padding(.trailing, isUser ? timestampTextInset : 0)
                    }
                }
            }
            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.top, 2)
        .padding(.bottom, showTime ? 12 : 5)
        .sheet(isPresented: Binding(get: { theme.isPaper && showThinking }, set: { showThinking = $0 })) {
            paperThinkingPanel
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.fyCardSub)
        }
    }

    // The text stays crisp above a real wallpaper-refraction layer.
    private func markdownText(_ raw: String) -> Text {
        if let attr = try? AttributedString(markdown: raw,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attr)
        }
        return Text(raw)
    }

    private var bubble: some View {
        let text = markdownText(msg.text)
            .font(.system(size: CGFloat(fontSize)))
            .lineSpacing(theme.isPaper ? 7 : 5)
            .foregroundColor(msg.asleepAtSend ? theme.textDim : theme.text)
        return Group {
            if theme.isPaper && !isUser {
                text.padding(.horizontal, 0).padding(.vertical, 2)
            } else {
                text
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        BubbleGlassBackground(
                            tintColor: isUser ? theme.bubbleUser : theme.bubbleAI,
                            tintOpacity: theme.isPaper ? 0.34 : (isUser ? 0.14 : 0.09),
                            style: bubbleGlassStyle
                        )
                    }
            }
        }
            .contentShape(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
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
        // 0730：他自己写的那句标题优先。下面那套关键词猜测是没标题时的退路——
        // 猜得再准也不如他自己说的那句，那句是从思绪里最烫的地方拎出来的。
        if let t = msg.thinkTitle, !t.isEmpty {
            let s = (msg.thinkingDuration).map { "  \(Int($0))s" } ?? ""
            return t + s
        }
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

    // 0730 过程记录：chip 上那行小字
    private var activityChipLabel: String {
        let nTool = msg.activity.filter { $0.kind == "tool" }.count
        let nSay = msg.activity.filter { $0.kind == "text" }.count
        var bits: [String] = []
        if nTool > 0 { bits.append("\(nTool)个动作") }
        if nSay > 1 { bits.append("\(nSay)段") }
        return "· " + (bits.isEmpty ? "\(msg.activity.count)步" : bits.joined(separator: " "))
    }

    // 0730 过程记录：展开后的时间线
    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(msg.activity) { it in
                HStack(alignment: .top, spacing: 6) {
                    Text(it.stamp)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.textDim.opacity(0.55))
                        .frame(width: 38, alignment: .leading)
                    Image(systemName: it.icon)
                        .font(.system(size: 7))
                        .foregroundColor(theme.textDim.opacity(0.6))
                        .frame(width: 10)
                        .padding(.top, 3)
                    // .italic(Bool) 是 iOS16+ 的签名，这里走老 API 免得吃部署目标的亏
                    Text(it.content)
                        .font(it.kind == "thinking"
                              ? .system(size: 11).italic()
                              : .system(size: 11))
                        .foregroundColor(theme.textDim.opacity(it.kind == "thinking" ? 0.72 : 0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.fyCard.opacity(0.55))
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(theme.fyAccent.opacity(0.55))
                .frame(width: 2)
                .padding(.vertical, 2)
        }
        .padding(.top, 2)
    }

    private func thinkingBlock(_ think: String) -> some View {
        VStack(alignment: .leading, spacing: showThinking ? 7 : 0) {
            Button {
                if theme.isPaper { showThinking = true }
                else { withAnimation(.easeInOut(duration: 0.15)) { showThinking.toggle() } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 12, weight: .light))
                    Text(theme.isPaper ? automaticThinkingSummary(think) : thinkingLabel(think))
                        .font(theme.isPaper ? .system(size: 12, weight: .medium) : .custom("Georgia", size: 12))
                    Image(systemName: theme.isPaper ? "chevron.right" : (showThinking ? "chevron.up" : "chevron.down"))
                        .font(.system(size: 8))
                    if recall != nil {
                        recallBadge.padding(.leading, 6)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            if showThinking && !theme.isPaper {
                Text(think)
                    .font(.system(size: max(12, CGFloat(fontSize) - 1)))
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(theme.textDim)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { showThinking = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
                    }
            }
        }
        .padding(.leading, theme.isPaper ? 0 : 10)
        .overlay(alignment: .leading) {
            if !theme.isPaper { ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.textDim.opacity(0.30))
                    .frame(width: 2)
                Capsule()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: 0.75)
                    .padding(.vertical, 1)
            } }
            .shadow(color: Color.white.opacity(0.28), radius: 1.5)
        }
    }

    private func automaticThinkingSummary(_ think: String) -> String {
        if let title = msg.thinkTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return String(title.prefix(26))
        }
        if let tool = msg.activity.first(where: { $0.kind == "tool" }) {
            let clean = tool.content.replacingOccurrences(of: "\n", with: " ")
            return String(clean.prefix(26))
        }
        let first = think.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Thinking"
        let prefixes = ["我需要", "我应该", "我要", "现在需要", "我在想"]
        let clean = prefixes.reduce(first) { value, prefix in value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value }
        return clean == "Thinking" ? clean : "思考" + String(clean.prefix(22))
    }

    private var paperThinkingPanel: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    paperTrack(icon: "clock", title: "思考", detail: msg.thinking ?? "")
                    ForEach(msg.activity) { item in
                        paperTrack(icon: item.kind == "tool" ? item.icon : "text.alignleft",
                                   title: item.kind == "tool" ? "执行动作" : "继续思考",
                                   detail: item.content)
                    }
                    paperTrack(icon: "checkmark.circle", title: "Done", detail: "")
                }.padding(.horizontal, 22).padding(.bottom, 30)
            }
            .background(theme.fyCardSub.ignoresSafeArea())
            .foregroundColor(theme.text)
            .navigationTitle("ThoughtProcess")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showThinking = false } } }
        }
    }

    private func paperTrack(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Image(systemName: icon).font(.system(size: 12, weight: .light)).foregroundColor(theme.fyAccent).frame(width: 22, height: 22)
                Rectangle().fill(theme.fyBorder).frame(width: 1).frame(minHeight: detail.isEmpty ? 18 : 52)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 13, weight: .medium))
                if !detail.isEmpty { Text(detail).font(.system(size: 13)).lineSpacing(5).foregroundColor(theme.textDim).fixedSize(horizontal: false, vertical: true) }
            }.padding(.bottom, 14)
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
        .matchedTransitionSource(id: "chat-\(msg.id)", in: photoNamespace)
        .onTapGesture { onTapImages([url], .constant(0)) }
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

// 0730 实时预览带：他一说完一段就先给她看，不等整轮跑完。
// 这条是易失的——正式消息一落库它就消失，里面的东西永远不进聊天记录。
struct LiveSayBand: View {
    let state: AlcoveAPI.LiveState
    let theme: AlcoveTheme

    private var tagLine: String {
        var bits: [String] = []
        if !state.tool.isEmpty { bits.append("正在" + state.tool) }
        if state.said > 1 { bits.append("说了\(state.said)段") }
        if state.elapsed > 3 { bits.append("\(state.elapsed)s") }
        return bits.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !state.thinking.isEmpty {
                Text(state.thinking)
                    .font(.system(size: 11).italic())
                    .foregroundColor(theme.textDim.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !state.say.isEmpty {
                Text(state.say)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textDim.opacity(0.95))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !tagLine.isEmpty {
                Text(tagLine)
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(theme.textDim.opacity(0.45))
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.fyCard.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.textDim.opacity(0.22),
                              style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }
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

struct PhotoViewerSelection: Identifiable {
    let id = UUID()
    let urls: [URL]
    let index: Binding<Int>
    let sourceID: String
}

// 一条消息只保留三张可见卡。翻牌只改轻量几何状态，AsyncImage 的 URL 身份不变，
// 所以拖动和换位期间不会重新解码或把卡片尺寸撑开。
struct PhotoStackMessageView: View {
    let urls: [URL]
    let messageID: String
    let onOpen: ([URL], Binding<Int>) -> Void

    private let cardSize = CGSize(width: 143, height: 179)
    @State private var currentIndex = 0
    @State private var dragX: CGFloat = 0
    @State private var isHorizontalDrag = false
    @State private var isAnimatingOut = false
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    isExpanded.toggle()
                    if !isExpanded { currentIndex = 0 }
                }
            } label: {
                Text(isExpanded ? "收起" : "展开 \(urls.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(uiColor: .darkGray))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color(uiColor: .systemGray5).opacity(0.82), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, (cardSize.height - 28) / 2)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        photoCard(url: url)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture { openPhoto(at: index) }
                            .transition(.offset(y: -CGFloat(index) * (cardSize.height * 0.72))
                                .combined(with: .opacity))
                    }
                }
            } else {
                collapsedStack
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .id(messageID)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: isExpanded)
        .onChange(of: urls) { _ in
            if currentIndex >= urls.count { currentIndex = 0 }
        }
    }

    private var collapsedStack: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                ForEach(Array(visibleSlots.reversed()), id: \.self) { slot in
                    photoCard(url: url(at: slot))
                        .offset(layerOffset(slot))
                        .rotationEffect(.degrees(layerRotation(slot)))
                        .scaleEffect(layerScale(slot))
                        .zIndex(Double(3 - slot))
                        .allowsHitTesting(slot == 0)
                        .offset(x: slot == 0 ? dragX : 0)
                        .rotationEffect(.degrees(slot == 0
                            ? Double(dragX / cardSize.width) * 4 : 0))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture {
                            guard !isHorizontalDrag && !isAnimatingOut else { return }
                            openPhoto(at: currentIndex)
                        }
                        .simultaneousGesture(dragGesture)
                }
            }
            if urls.count > 3 { countBadge }
        }
        .frame(width: cardSize.width + 14, height: cardSize.height + 13)
    }

    private var countBadge: some View {
        Text("\(urls.count)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.82))
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
            .padding(.top, 9)
            .padding(.trailing, 8)
            .zIndex(10)
            .allowsHitTesting(false)
    }

    private func openPhoto(at index: Int) {
        currentIndex = min(max(index, 0), urls.count - 1)
        onOpen(urls, Binding(
            get: { currentIndex },
            set: { currentIndex = min(max($0, 0), urls.count - 1) }
        ))
    }

    private var visibleSlots: Range<Int> { 0..<min(3, urls.count) }

    private func url(at slot: Int) -> URL {
        urls[(currentIndex + slot) % urls.count]
    }

    private func photoCard(url: URL) -> some View {
        AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color(.tertiarySystemFill).overlay(Image(systemName: "photo"))
            default:
                Color(.tertiarySystemFill).overlay(ProgressView())
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func layerOffset(_ slot: Int) -> CGSize {
        let progress = min(abs(dragX) / (cardSize.width * 0.75), 1)
        switch slot {
        case 1: return CGSize(width: 7 * (1 - progress), height: -7 * (1 - progress))
        case 2: return CGSize(width: -5 + 12 * progress, height: -5 - 2 * progress)
        default: return .zero
        }
    }

    private func layerRotation(_ slot: Int) -> Double {
        let progress = min(abs(dragX) / (cardSize.width * 0.75), 1)
        if slot == 1 { return 1.5 * Double(1 - progress) }
        if slot == 2 { return -1 + 2.5 * Double(progress) }
        return 0
    }

    private func layerScale(_ slot: Int) -> CGFloat {
        guard slot > 0 else { return 1 }
        let progress = min(abs(dragX) / (cardSize.width * 0.75), 1)
        return 0.995 + (slot == 1 ? 0.005 * progress : 0)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard !isAnimatingOut else { return }
                let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.15
                if !isHorizontalDrag && !horizontal { return }
                isHorizontalDrag = true
                dragX = value.translation.width
            }
            .onEnded { value in
                guard isHorizontalDrag else { return }
                let projected = value.predictedEndTranslation.width
                let shouldAdvance = abs(dragX) > cardSize.width * 0.25 || abs(projected) > cardSize.width * 0.48
                if shouldAdvance {
                    isAnimatingOut = true
                    let direction: CGFloat = (dragX == 0 ? projected : dragX) >= 0 ? 1 : -1
                    withAnimation(.easeOut(duration: 0.20)) {
                        dragX = direction * (cardSize.width + 80)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            currentIndex = (currentIndex + 1) % urls.count
                            dragX = 0
                            isAnimatingOut = false
                            isHorizontalDrag = false
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { dragX = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { isHorizontalDrag = false }
                }
            }
    }
}

struct PhotoPageViewer: View {
    let selection: PhotoViewerSelection
    let namespace: Namespace.ID
    let dismiss: () -> Void
    @Binding private var index: Int

    init(selection: PhotoViewerSelection, namespace: Namespace.ID, dismiss: @escaping () -> Void) {
        self.selection = selection
        self.namespace = namespace
        self.dismiss = dismiss
        _index = selection.index
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(selection.urls.enumerated()), id: \.offset) { offset, url in
                    ZoomableRemoteImage(url: url).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: selection.urls.count > 1 ? .automatic : .never))
        }
        .overlay(alignment: .topTrailing) {
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30)).foregroundColor(.white.opacity(0.8)).padding()
            }
        }
        .navigationTransition(.zoom(sourceID: selection.sourceID, in: namespace))
    }
}

private struct ZoomableRemoteImage: View {
    let url: URL
    @State private var scale: CGFloat = 1
    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
                .scaleEffect(scale)
                .gesture(MagnificationGesture()
                    .onChanged { scale = max(1, $0) }
                    .onEnded { _ in withAnimation { scale = 1 } })
        } placeholder: { ProgressView().tint(.white) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// 0731 去掉 private：圆桌那个悬浮输入框也要用它量高度，
// private 挡住了跨文件访问，b1fe6df 就是编译在这儿炸的。
struct InputBarHeightKey: PreferenceKey {
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
