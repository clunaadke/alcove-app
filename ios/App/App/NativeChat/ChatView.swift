import SwiftUI
import WebKit
import PhotosUI
import Photos
import AVFoundation
import UniformTypeIdentifiers
import UIKit

struct ChatView: View {
    @Binding var thinkingEnabled: Bool
    let thinkingKnown: Bool
    let switchingThinking: Bool
    let onToggleThinking: () -> Void

    @StateObject private var store = ChatStore()
    @StateObject private var wallpaperStore = ChatWallpaperStore()
    @State private var draft = ""
    @State private var previousDraft = ""
    @State private var handlingReturn = false
    @State private var selectedQuote: String?
    @State private var showStickers = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pendingImages: [(thumb: UIImage, jpeg: Data)] = []
    // 选表情不立刻飞出去：先进待发区，还能继续打字或者撤掉（教程坑 1）
    @State private var pendingSticker: Sticker?
    // 0818 她要的：链接一贴进打字框就自动抽出来变成待发卡片，她还能接着打字一起发
    @State private var pendingLink: String?
    @State private var photoViewer: PhotoViewerSelection?
    @StateObject private var recorder = VoiceRecorder()
    @State private var atBottom = true
    @State private var followLiveOutput = true
    @State private var olderPagingArmed = false
    @State private var showCamera = false
    @State private var showDocPicker = false
    @State private var showPhotoPicker = false
    @Namespace private var photoTransition
    @State private var previewImage: UIImage?
    @State private var inputBarHeight: CGFloat = 90
    @State private var scrollKick = 0
    @State private var showMusicPlayer = false
    @State private var showModelPicker = false
    @State private var showMoreModels = false
    @State private var switchingModel = false
    @State private var modelSwitchError = ""
    @State private var showMiniTerminal = false
    @State private var showSDKShadow = false
    @State private var showChannelPanel = false
    @State private var activeChatChannel = "cli"
    // 0819 她点名的跳转高亮：从搜索/收藏跳过来的那条闪一下再退
    @State private var flashTS: String?
    @State private var paragraphSelectionMode = false
    @State private var selectedParagraphIDs: Set<UUID> = []
    @State private var showParagraphDeleteConfirmation = false
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
    private var miniTerminalHeight: CGFloat {
        min(310, UIScreen.main.bounds.height * 0.29)
    }
    // 底部所有悬浮层只认这一份高度。输入框会随长文字／图片预览
    // 实测变化；音乐条固定 62pt，再留 10pt 呼吸缝。
    private var musicBarClearance: CGFloat { music.nowPlaying == nil ? 0 : 72 }
    private var bottomChromeHeight: CGFloat { inputBarHeight + musicBarClearance }

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
        .sheet(isPresented: $showModelPicker, onDismiss: { showMoreModels = false }) {
            modelPickerSheet
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showSDKShadow) {
            SDKShadowChatView()
        }
        .sheet(isPresented: $showChannelPanel) {
            ChatChannelPanel(activeChannel: $activeChatChannel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                if let prepared = UploadImage.prepare(image) {
                    pendingImages.append(prepared)
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
                    if let prepared = UploadImage.prepare(img) {
                        pendingImages.append(prepared)
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
            Task {
                if let obj = try? await AlcoveAPI.getRaw("/api/sdk-shadow/status") {
                    activeChatChannel = obj["channel"] as? String ?? "cli"
                }
            }
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
                       let prepared = UploadImage.prepare(img) {
                        pendingImages.append(prepared)
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
                                .background(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(theme.fyAccent.opacity(flashTS == msg.ts ? 0.17 : 0))
                                        .padding(.horizontal, -7)
                                        .padding(.vertical, -3)
                                        .animation(.easeInOut(duration: 0.42), value: flashTS))
                                .onAppear {
                                    guard idx == 0, olderPagingArmed else { return }
                                    olderPagingArmed = false
                                    store.loadOlder()
                                }
                                .onDisappear {
                                    guard idx == 0 else { return }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { olderPagingArmed = true }
                                }
                        }
                        if let live = store.live, (live.active || live.finishing), !live.isEmpty {
                            StreamingAssistantRow(state: live, theme: theme, fontSize: chatFontSize)
                                .id("live-\(live.turnID)")
                        }
                        if store.isTyping {
                            TypingIndicator(tool: store.currentTool,
                                            line: store.typingLine,
                                            name: UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟",
                                            theme: theme)
                                .id("typing")
                        }
                        Color.clear.frame(height: bottomChromeHeight + 12
                                          + (showMiniTerminal ? miniTerminalHeight + 18 : 0))
                        Color.clear.frame(height: 1).id("tail")
                            .onAppear { atBottom = true }
                            .onDisappear { atBottom = false }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 52)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { inputFocused = false }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 4).onChanged { _ in
                        if store.live?.active == true { followLiveOutput = false }
                    }
                )
                .mask(edgeFadeMask)

                if paragraphSelectionMode {
                    paragraphSelectionToolbar
                } else {
                    floatingInput
                }

                if music.nowPlaying != nil && !paragraphSelectionMode {
                    MusicMiniPlayer(model: music) { showMusicPlayer = true }
                        .padding(.horizontal, 12)
                        .padding(.bottom, inputBarHeight + 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if !atBottom {
                    Button {
                        followLiveOutput = true
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
                    .padding(.bottom, bottomChromeHeight + 12)
                    .transition(.opacity)
                }

                if !showMiniTerminal && !paragraphSelectionMode {
                    ClawdPet(store: store) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            showMiniTerminal = true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 12)
                    .padding(.bottom, bottomChromeHeight + 8)
                }
            }
            // 终端画在上层；消息流用等高底部占位做出键盘式避让。
            .overlay(alignment: .bottom) {
                if showMiniTerminal {
                    TerminalView(onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            showMiniTerminal = false
                        }
                    }, mini: true)
                    .frame(height: miniTerminalHeight)
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomChromeHeight + 14)
                    .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
                }
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                scrollToTail(proxy, delays: [0, 0.12, 0.3], animated: true)
            }
            .onChange(of: store.messages.count) { _ in
                guard atBottom || inputFocused else { return }
                scrollToTail(proxy, delays: [0, 0.15, 0.4], animated: true)
            }
            .onChange(of: store.loading) { loading in
                if !loading {
                    olderPagingArmed = false
                    scrollToTail(proxy, delays: [0.05, 0.3, 0.8, 1.5], animated: false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { olderPagingArmed = true }
                }
            }
            .onChange(of: store.isTyping) { t in
                if t { followLiveOutput = atBottom || inputFocused }
                if atBottom || inputFocused {
                    scrollToTail(proxy, delays: [0, 0.2, 0.5], animated: true)
                }
            }
            .onChange(of: liveLayoutKey) { _ in
                guard followLiveOutput || inputFocused else { return }
                scrollToTail(proxy, delays: [0], animated: false)
            }
            .onChange(of: inputBarHeight) { _ in
                if atBottom || inputFocused {
                    scrollToTail(proxy, delays: [0.05, 0.3], animated: true)
                }
            }
            .onChange(of: music.nowPlaying?.id) { _ in
                if atBottom || inputFocused {
                    scrollToTail(proxy, delays: [0.05, 0.3], animated: true)
                }
            }
            .onChange(of: showMiniTerminal) { _ in
                // 像键盘避让：占位变化后把最新消息送到终端正上方。
                scrollToTail(proxy, delays: [0, 0.12, 0.32], animated: true)
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
                guard let ts = note.object as? String else { return }
                Task {
                    if !store.messages.contains(where: { $0.ts == ts }) { await store.loadAround(ts) }
                    if let target = store.messages.first(where: { $0.ts == ts }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation { proxy.scrollTo(target.id, anchor: .top) }
                            flashTS = ts
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                            if flashTS == ts { flashTS = nil }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "删除选中的 \(selectedParagraphIDs.count) 段正文？",
            isPresented: $showParagraphDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { deleteSelectedParagraphs() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后这些段落会从聊天记录中消失。")
        }
    }

    private var liveLayoutKey: String {
        guard let live = store.live else { return "" }
        return "\(live.turnID)\u{1f}\(live.say)\u{1f}\(live.pendingSay)\u{1f}\(live.timeline.count)"
    }

    private var paragraphSelectionToolbar: some View {
        HStack(spacing: 18) {
            Button("取消") { leaveParagraphSelection() }
                .foregroundColor(theme.textDim)
            Text("已选 \(selectedParagraphIDs.count) 段")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.text)
            Spacer()
            Button {
                favoriteSelectedParagraphs()
            } label: {
                Label("收藏", systemImage: "star")
            }
            .disabled(selectedParagraphIDs.isEmpty)
            Button(role: .destructive) {
                showParagraphDeleteConfirmation = true
            } label: {
                Label("删除", systemImage: "trash")
            }
            .disabled(selectedParagraphIDs.isEmpty)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(theme.glassBorder, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, max(safeBottom, 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func selectedParagraphs() -> [ChatMessage] {
        store.messages.filter { selectedParagraphIDs.contains($0.uid) }
    }

    private func leaveParagraphSelection() {
        paragraphSelectionMode = false
        selectedParagraphIDs.removeAll()
    }

    private func favoriteSelectedParagraphs() {
        store.favoriteMessages(selectedParagraphs())
        leaveParagraphSelection()
    }

    private func deleteSelectedParagraphs() {
        store.deleteMessages(selectedParagraphs())
        leaveParagraphSelection()
    }

    /// 0818 她要的：思绪永远在我这一轮最上面，动作轨迹挂在思绪下面。
    /// 「一轮」= 连续的我方消息、中间没有她说话、相邻间隔不超过三分钟
    /// （表情/卡片是我用 CLI 单独发的，没有 turn_id，只能按这个规矩归到一起）。
    /// 轮首拿整轮第一段思绪 + 整轮去重后的动作；那段思绪的原主人自己不再显示。
    private struct Hoist {
        var thought: String? = nil
        var activity: [ActivityItem] = []
        var suppressThought = false
        var suppressActivity = false
    }

    private func hoistFor(index: Int) -> Hoist {
        let msgs = store.messages
        guard index < msgs.count, msgs[index].role == "assistant" else { return Hoist() }
        // 新时间线已经把 think / tool 精确挂回原段落，绝不能再走旧的“提到轮首”。
        if !msgs[index].segments.isEmpty { return Hoist() }
        guard let turnID = msgs[index].turnID, !turnID.isEmpty else { return Hoist() }
        var head = index
        while head > 0, msgs[head - 1].role == "assistant",
              msgs[head - 1].turnID == turnID { head -= 1 }
        var tail = index
        while tail + 1 < msgs.count, msgs[tail + 1].role == "assistant",
              msgs[tail + 1].turnID == turnID { tail += 1 }
        if head == tail { return Hoist() }          // 单条一轮，照旧

        // 整轮第一段手写思绪是谁的
        var thoughtOwner: Int? = nil
        for i in head...tail {
            if let t = msgs[i].thinking?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                thoughtOwner = i; break
            }
        }
        if index == head {
            var seen = Set<String>()
            var merged: [ActivityItem] = []
            // 整条时间线都要：动作、中间说的话、中间的思绪——她说以前合在一起时
            // 不会漏掉我跑任务中间说过的话，分开之后这些不能丢。
            for i in head...tail {
                for item in msgs[i].activity {
                    let key = item.kind + "|" + item.content + "@" + String(format: "%.1f", item.t)
                    if seen.insert(key).inserted { merged.append(item) }
                }
            }
            merged.sort { $0.t < $1.t }
            var h = Hoist()
            if let owner = thoughtOwner, owner != head { h.thought = msgs[owner].thinking }
            h.activity = merged
            return h
        }
        var h = Hoist()
        h.suppressThought = (thoughtOwner == index)
        h.suppressActivity = true
        return h
    }

    @ViewBuilder
    private func chatMessageRow(at index: Int, message: ChatMessage) -> some View {
        if !isPhotoGroupContinuation(at: index) {
            let previous = index > 0 ? store.messages[index - 1] : nil
            let photos = message.inlineImages.isEmpty
                ? chatPhotoGroup(startingAt: index)
                : message.inlineImages.map(AlcoveAPI.attachmentURL)
            let groupEnd = index + max(photos.count, 1) - 1
            let next = groupEnd + 1 < store.messages.count ? store.messages[groupEnd + 1] : nil
            let recall = message.role == "assistant" && previous?.role == "user"
                ? store.recall(forUserText: previous?.text ?? "")
                : nil

            if needsDivider(prev: previous, cur: message) {
                TimeDivider(date: message.date, color: theme.textDim)
            }
            let hoist = hoistFor(index: index)
            MessageRow(
                msg: message,
                sticker: message.stickerId.flatMap(store.sticker(for:)),
                theme: theme,
                fontSize: chatFontSize,
                showTime: isGroupTail(cur: store.messages[groupEnd], next: next),
                recall: recall,
                hoistedThought: hoist.thought,
                hoistedActivity: hoist.activity,
                suppressOwnThought: hoist.suppressThought,
                suppressOwnActivity: hoist.suppressActivity,
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
                wholeTurnText: wholeTurnText(for: message),
                paragraphSelectionMode: paragraphSelectionMode,
                paragraphSelected: selectedParagraphIDs.contains(message.uid),
                onBeginParagraphSelection: {
                    paragraphSelectionMode = true
                    selectedParagraphIDs.insert(message.uid)
                    inputFocused = false
                },
                onToggleParagraphSelection: {
                    if selectedParagraphIDs.contains(message.uid) {
                        selectedParagraphIDs.remove(message.uid)
                    } else {
                        selectedParagraphIDs.insert(message.uid)
                    }
                },
                onQuote: { text in
                    selectedQuote = text
                    inputFocused = true
                },
                onResend: { text in store.sendText(text) },
                onPlayMusic: { song in Task { await music.play(song) } },
                onContentChange: { scrollKick += 1 }
            )
            .id(message.id)
        }
    }

    private func wholeTurnText(for message: ChatMessage) -> String {
        guard message.role == "assistant",
              let turnID = message.turnID, !turnID.isEmpty else {
            return message.displayText
        }
        return store.messages
            .filter { $0.role == "assistant" && $0.turnID == turnID && !$0.displayText.isEmpty }
            .map(\.displayText)
            .joined(separator: "\n\n")
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
        if let turnID = cur.turnID, !turnID.isEmpty {
            return next.turnID != turnID
        }
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
            .frame(height: bottomChromeHeight + 12)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingImages.isEmpty || pendingSticker != nil || pendingLink != nil
    }

    // PWA .chat-input-capsule 同款：大胶囊两行，粉描边，透底毛玻璃
    @ViewBuilder private var floatingInput: some View {
        legacyFloatingInput
    }

    private var legacyFloatingInput: some View {
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
                if let quote = selectedQuote {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textDim)
                        Text(quote)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textDim)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { selectedQuote = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(theme.textDim)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .padding(.top, 9)
                    .padding(.bottom, 5)
                    Divider().opacity(0.35).padding(.horizontal, 12)
                }
                // 待发链接卡：贴进来的链接在这儿预览，✕ 就把链接原样塞回打字框
                if let link = pendingLink {
                    HStack(alignment: .top, spacing: 6) {
                        LinkPreviewCard(url: link, theme: theme, isUser: true)
                        Button {
                            pendingLink = nil
                            draft = draft.isEmpty ? link : draft + " " + link
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22)).foregroundColor(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 2)
                }
                // 待发表情：一张就够，再点一次面板会换掉它
                if let stk = pendingSticker {
                    HStack(spacing: 8) {
                        AsyncImage(url: AlcoveAPI.stickerURL(stk.url)) { img in
                            img.resizable().scaledToFit()
                        } placeholder: { Color(.systemGray6) }
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(stk.name.isEmpty ? "表情" : stk.name)
                            .font(.system(size: 11)).foregroundColor(.secondary)
                        Spacer()
                        Button { pendingSticker = nil } label: {
                            // 图标 22，热区 44：她说叉叉难点到
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22)).foregroundColor(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 2)
                }
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
                                            .frame(width: 40, height: 40)
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
                    TextField("", text: $draft,
                              prompt: Text("ring the chime …")
                                .font(.system(size: 15.5, design: .serif)).italic(),
                              axis: .vertical)
                        .focused($inputFocused)
                        .lineLimit(1...5)
                        .font(.system(size: 15.5))
                        .tint(Color(uiColor: .systemGray3))
                        .padding(.init(top: 16, leading: 14, bottom: 12, trailing: 14))
                        .contentShape(Rectangle())
                        .onChange(of: draft) { value in handleDraftChange(value) }
                }
                HStack(spacing: 2) {
                    if recorder.isRecording {
                        Button { recorder.cancel() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .light))
                                .foregroundColor(theme.textDim)
                                .frame(width: 36, height: 36)
                        }
                        Spacer()
                    } else {
                        Menu {
                            Button { showStickers = true } label: {
                                Label("表情", systemImage: "face.smiling")
                            }
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
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(theme.textDim)
                                .frame(width: 36, height: 36)
                                .background(theme.glassTint.opacity(theme.isDark ? 0.64 : 0.82), in: Circle())
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
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textLight)
                                .padding(.horizontal, 12).frame(height: 36)
                                .background(theme.glassTint.opacity(theme.isDark ? 0.72 : 0.92),
                                            in: Capsule())
                                .overlay(Capsule().stroke(theme.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(switchingModel)
                        }
                        Button { showChannelPanel = true } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(activeChatChannel.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(theme.textLight)
                            .padding(.horizontal, 10)
                            .frame(height: 36)
                            .background(theme.glassTint.opacity(theme.isDark ? 0.72 : 0.92), in: Capsule())
                            .overlay(Capsule().stroke(theme.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("切换 CLI 或 SDK 通道，当前 \(activeChatChannel.uppercased())")
                        Spacer()
                    }
                    Button(action: performDynamicComposerAction) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: (canSend || recorder.isRecording || store.heldCount > 0) ? "arrow.up" : "waveform")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                LinearGradient(
                                    colors: [theme.sendTop, theme.sendBottom],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2),
                                    radius: 4, y: 2)
                            if store.heldCount > 0 {
                                Text("\(store.heldCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(theme.sendTop, in: Capsule())
                                    .offset(x: 3, y: -3)
                            }
                        }
                    }
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

    private func holdCurrentDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        store.sendHold(text)
        inputFocused = true
    }

    private func handleDraftChange(_ value: String) {
        // 贴进来一个链接：抽出去做成待发卡，打字框留给她说话
        if pendingLink == nil, value.contains("http"),
           let range = value.range(of: #"https?://[^\s<>"'）)]+"#, options: .regularExpression) {
            var link = String(value[range])
            while let last = link.last, ".,;:!?，。！？、".contains(last) { link.removeLast() }
            if link.count > 12 {
                pendingLink = link
                LinkCardStore.shared.load(link)
                let rest = value.replacingOccurrences(of: link, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                handlingReturn = true
                draft = rest
                previousDraft = rest
                DispatchQueue.main.async { handlingReturn = false }
                return
            }
        }
        guard !handlingReturn else {
            previousDraft = value
            return
        }
        let before = previousDraft
        previousDraft = value
        guard value == before + "\n" else { return }
        guard !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handlingReturn = true
            draft = before
            previousDraft = before
            DispatchQueue.main.async { handlingReturn = false }
            return
        }
        handlingReturn = true
        draft = before
        holdCurrentDraft()
        previousDraft = ""
        DispatchQueue.main.async {
            handlingReturn = false
            previousDraft = draft
        }
    }

    private func performDynamicComposerAction() {
        if recorder.isRecording {
            if let data = recorder.stopAndTake() { store.sendVoice(data: data) }
            return
        }
        guard canSend else {
            if store.heldCount > 0 {
                store.flushHeld()
                return
            }
            recorder.start()
            return
        }
        var text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        if let link = pendingLink {
            // 她说的话在前、链接另起一行在后：气泡里是话，卡片长在下面
            pendingLink = nil
            text = text.isEmpty ? link : text + "\n" + link
        }
        if let stk = pendingSticker {
            pendingSticker = nil
            store.sendSticker(stk, text: outgoingText(text))
            return
        }
        if !pendingImages.isEmpty {
            let images = pendingImages.map(\.jpeg)
            pendingImages = []
            store.sendImages(images, caption: outgoingText(text))
        } else {
            store.sendText(outgoingText(text))
        }
    }

    private func outgoingText(_ body: String) -> String {
        guard let quote = selectedQuote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !quote.isEmpty else { return body }
        selectedQuote = nil
        return "[QUOTE]\(quote)[/QUOTE]\n\(body)"
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

    private var modelPickerSheet: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    if showMoreModels {
                        withAnimation(.easeInOut(duration: 0.18)) { showMoreModels = false }
                    } else {
                        showModelPicker = false
                    }
                } label: {
                    Image(systemName: showMoreModels ? "chevron.left" : "xmark")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(theme.text)
                        .frame(width: 44, height: 44)
                        .background(theme.glassTint.opacity(0.52), in: Circle())
                        .overlay(Circle().stroke(theme.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
                Text(showMoreModels ? "More models" : "Select model")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.text)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            if showMoreModels {
                modelRows(Array(claudeModels.dropFirst(4)))
            } else {
                modelRows(Array(claudeModels.prefix(4)))

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showMoreModels = true }
                } label: {
                    HStack {
                        Text("More models")
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.textDim)
                    }
                    .foregroundColor(theme.text)
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(theme.fyCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onToggleThinking) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("thinking quietly")
                                .font(.system(size: 16, weight: .medium))
                            Text("让陈璟把思考留在心里")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textDim)
                        }
                        Spacer()
                        if switchingThinking {
                            ProgressView().controlSize(.small)
                                .frame(width: 42)
                        } else {
                            Capsule()
                                .fill(thinkingEnabled ? theme.sendTop : theme.textDim.opacity(0.22))
                                .frame(width: 42, height: 24)
                                .overlay(alignment: thinkingEnabled ? .trailing : .leading) {
                                    Circle().fill(.white).frame(width: 20, height: 20).padding(2)
                                }
                                .opacity(thinkingKnown ? 1 : 0.45)
                                .animation(.spring(response: 0.24, dampingFraction: 0.8), value: thinkingEnabled)
                        }
                    }
                    .foregroundColor(theme.text)
                    .padding(.horizontal, 18)
                    .frame(height: 66)
                    .background(theme.fyCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(switchingThinking || !thinkingKnown)
            }

            if !modelSwitchError.isEmpty {
                Text(modelSwitchError)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .foregroundColor(theme.text)
    }

    private func modelRows(_ options: [ClaudeModelOption]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button { switchClaudeModel(option) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label).font(.system(size: 16, weight: .medium))
                            if !option.note.isEmpty {
                                Text(option.note).font(.system(size: 11)).foregroundColor(theme.textDim)
                            }
                        }
                        Spacer()
                        if store.modelLabel == option.label {
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.sendTop)
                        }
                    }.padding(.horizontal, 18).frame(minHeight: option.note.isEmpty ? 56 : 66)
                }.buttonStyle(.plain)
                if index < options.count - 1 { Divider().opacity(0.45).padding(.horizontal, 18) }
            }
        }
        .background(theme.fyCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            pendingSticker = stk
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct ChatChannelPanel: View {
    @Binding var activeChannel: String
    @Environment(\.dismiss) private var dismiss
    @State private var panel = "cli"
    @State private var handoffTurns = 12
    @State private var toolMode = "disabled"
    @State private var sdkPrompt = ""
    @State private var sdkIdentity = ""
    @State private var sdkStyle = ""
    @State private var cliCapabilities: [String] = []
    @State private var sdkCapabilities: [String] = []
    @State private var cliMCP: [String] = []
    @State private var sdkMCP: [String] = []
    @State private var loading = true
    @State private var working = false
    @State private var message = ""
    @State private var confirmSync = false
    @State private var confirmClearSession = false
    @State private var sdkSessionActive = false
    @State private var cliContextUsed = 0
    @State private var cliContextWindow = 1_000_000
    @State private var sdkContextUsed = 0
    @State private var sdkContextWindow = 1_000_000
    @State private var showSDKForge = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("通道", selection: $panel) {
                        Text("CLI").tag("cli")
                        Text("SDK").tag("sdk")
                    }
                    .pickerStyle(.segmented)

                    channelHeader
                    if panel == "cli" { cliPanel } else { sdkPanel }

                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(message.contains("失败") ? .red : .secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("陈璟的通道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .task { await load() }
            .alert("从 CLI 重新复制锚点？", isPresented: $confirmSync) {
                Button("取消", role: .cancel) {}
                Button("覆盖 SDK", role: .destructive) { Task { await syncAnchors() } }
            } message: { Text("SDK 里自己修改过的两份锚点会被当前 CLI 版本覆盖。") }
            .confirmationDialog("完全新开 SDK 窗口？", isPresented: $confirmClearSession,
                                titleVisibility: .visible) {
                Button("清空最近对话并新开", role: .destructive) {
                    Task { await newSDKSession(keepMessages: false) }
                }
                Button("取消", role: .cancel) {}
            } message: { Text("SDK 锚点和共用 LMC-5 不动，只清空 SDK 最近对话和 session。") }
            .sheet(isPresented: $showSDKForge) {
                SDKForgeSheet {
                    sdkSessionActive = true
                    message = "SDK Forge 已自动切到新 session"
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var channelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(activeChannel == panel ? "当前正在使用" : "当前未使用")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Text(panel.uppercased())
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(contextLine)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if activeChannel != panel {
                Button { Task { await switchChannel() } } label: {
                    if working { ProgressView().controlSize(.small) }
                    else { Text("切到这里") }
                }
                .buttonStyle(.borderedProminent).disabled(working)
            } else {
                Label("已连接", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cliPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("当前能力")
            capabilityWrap(cliCapabilities)
            sectionTitle("MCP")
            capabilityWrap(cliMCP)
            Text("CLI 使用现役锚点、hooks、工具和 MCP。这里不提供修改入口，原来的出厂设置继续管它。")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            handoffControl
        }
    }

    private var contextLine: String {
        let used = panel == "cli" ? cliContextUsed : sdkContextUsed
        let window = panel == "cli" ? cliContextWindow : sdkContextWindow
        let pct = window > 0 ? Double(used) / Double(window) * 100 : 0
        func compact(_ value: Int) -> String {
            value >= 1_000_000 ? String(format: "%.1fM", Double(value) / 1_000_000)
                : String(format: "%.1fK", Double(value) / 1_000)
        }
        return "上下文 \(compact(used)) / \(compact(window)) · \(String(format: "%.1f", pct))%"
    }

    private var sdkPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("当前能力")
            capabilityWrap(sdkCapabilities)
            sectionTitle("MCP")
            if sdkMCP.isEmpty {
                Text("还没有给 SDK 配 MCP").font(.system(size: 13)).foregroundStyle(.secondary)
            } else { capabilityWrap(sdkMCP) }
            Button("从 CLI 复制 MCP 配置") { Task { await syncMCP() } }
                .buttonStyle(.bordered).disabled(working)
            Picker("工具权限", selection: $toolMode) {
                Text("关闭").tag("disabled")
                Text("只读").tag("readonly")
                Text("完整").tag("full")
            }
            .pickerStyle(.segmented)

            handoffControl
            HStack {
                Button("SDK Forge 换窗") { showSDKForge = true }
                    .buttonStyle(.bordered)
                Button("完全新开", role: .destructive) { confirmClearSession = true }
                    .buttonStyle(.bordered)
                Spacer()
                Text(sdkSessionActive ? "session 已建立" : "下一句建立 session")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            editor("SDK 专用 Prompt", text: $sdkPrompt, height: 110)
            editor("SDK · CLAUDE.md", text: $sdkIdentity, height: 220)
            editor("SDK · Output Style", text: $sdkStyle, height: 260)
            HStack {
                Button("从 CLI 重新复制") { confirmSync = true }
                    .buttonStyle(.bordered)
                Spacer()
                Button("保存并应用") { Task { await saveSDK() } }
                    .buttonStyle(.borderedProminent).disabled(working)
            }
            Text("LMC-5 不复制：CLI 和 SDK 始终从同一个脑子召回。SDK 默认只读召回。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var handoffControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("切换时带多少轮纯对话")
            Stepper("\(handoffTurns) 轮", value: $handoffTurns, in: 1...50)
            Text("一轮按你一句＋他一轮正文回复计算，不带 Thought process、工具调用和工具结果。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .semibold))
    }

    private func capabilityWrap(_ items: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(items, id: \.self) { item in
                    Text(item).font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                }
            }
        }
    }

    private func editor(_ title: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle(title)
            TextEditor(text: text)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: height)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @MainActor private func load() async {
        loading = true
        do {
            let obj = try await AlcoveAPI.getRaw("/api/sdk-shadow/status")
            activeChannel = obj["channel"] as? String ?? "cli"
            panel = activeChannel
            let cfg = obj["config"] as? [String: Any] ?? [:]
            handoffTurns = (cfg["handoff_turns"] as? NSNumber)?.intValue ?? 12
            toolMode = cfg["tool_mode"] as? String ?? "disabled"
            sdkPrompt = cfg["sdk_prompt"] as? String ?? ""
            sdkSessionActive = !((cfg["sdk_session_id"] as? String) ?? "").isEmpty
            let anchors = obj["anchors"] as? [String: Any] ?? [:]
            sdkIdentity = anchors["identity"] as? String ?? ""
            sdkStyle = anchors["style"] as? String ?? ""
            cliCapabilities = obj["cli_capabilities"] as? [String] ?? []
            sdkCapabilities = obj["sdk_capabilities"] as? [String] ?? []
            cliMCP = obj["cli_mcp"] as? [String] ?? []
            sdkMCP = obj["sdk_mcp"] as? [String] ?? []
            let cliContext = obj["cli_context"] as? [String: Any] ?? [:]
            cliContextUsed = (cliContext["used"] as? NSNumber)?.intValue ?? 0
            cliContextWindow = (cliContext["window"] as? NSNumber)?.intValue ?? 1_000_000
            let sdkContext = obj["sdk_context"] as? [String: Any] ?? [:]
            sdkContextUsed = (sdkContext["used"] as? NSNumber)?.intValue ?? 0
            sdkContextWindow = (sdkContext["window"] as? NSNumber)?.intValue ?? 1_000_000
            message = ""
        } catch { message = "加载失败：\(error.localizedDescription)" }
        loading = false
    }

    @MainActor private func saveSDK() async {
        working = true
        do {
            _ = try await AlcoveAPI.postRaw("/api/sdk-shadow/config", body: [
                "handoff_turns": handoffTurns, "tool_mode": toolMode,
                "sdk_prompt": sdkPrompt, "identity": sdkIdentity, "style": sdkStyle
            ])
            await load()
            message = "已保存，从下一句话开始生效"
        } catch { message = "保存失败：\(error.localizedDescription)" }
        working = false
    }

    @MainActor private func syncAnchors() async {
        working = true
        do {
            let obj = try await AlcoveAPI.postRaw("/api/sdk-shadow/sync-anchors", body: [:])
            let anchors = obj["anchors"] as? [String: Any] ?? [:]
            sdkIdentity = anchors["identity"] as? String ?? sdkIdentity
            sdkStyle = anchors["style"] as? String ?? sdkStyle
            message = "已从 CLI 重新复制，只改了 SDK 副本"
        } catch { message = "同步失败：\(error.localizedDescription)" }
        working = false
    }

    @MainActor private func syncMCP() async {
        working = true
        do {
            let obj = try await AlcoveAPI.postRaw("/api/sdk-shadow/sync-mcp", body: [:])
            sdkMCP = obj["sdk_mcp"] as? [String] ?? []
            sdkSessionActive = false
            message = "已复制 \(sdkMCP.count) 个 MCP，下一句话建立新 SDK session"
        } catch { message = "MCP 同步失败：\(error.localizedDescription)" }
        working = false
    }

    @MainActor private func switchChannel() async {
        working = true; message = ""
        do {
            let obj = try await AlcoveAPI.postRaw("/api/sdk-shadow/switch", body: [
                "channel": panel, "handoff_turns": handoffTurns
            ])
            guard obj["ok"] as? Bool == true else {
                throw NSError(domain: "Channel", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: obj["error"] as? String ?? "切换失败"])
            }
            activeChannel = obj["channel"] as? String ?? panel
            message = "已切到 \(activeChannel.uppercased())"
        } catch { message = "切换失败：\(error.localizedDescription)" }
        working = false
    }

    @MainActor private func newSDKSession(keepMessages: Bool) async {
        working = true; message = ""
        do {
            _ = try await AlcoveAPI.postRaw("/api/sdk-shadow/new-session", body: [
                "keep_messages": keepMessages, "handoff_turns": handoffTurns
            ])
            sdkSessionActive = false
            message = keepMessages
                ? "SDK 窗口已换，下一句带最近 \(handoffTurns) 轮建立新 session"
                : "SDK 已完全新开，下一句建立空白 session"
        } catch { message = "换窗失败：\(error.localizedDescription)" }
        working = false
    }
}

private struct SDKForgeRound: Identifiable {
    let idx: Int
    let head: String
    let at: String
    var id: Int { idx }
    init(_ raw: [String: Any]) {
        idx = (raw["idx"] as? NSNumber)?.intValue ?? 0
        head = raw["head"] as? String ?? ""
        at = raw["at"] as? String ?? ""
    }
}

private struct SDKForgeSheet: View {
    let onForged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mode = "latest"
    @State private var retain = 20.0
    @State private var preview: [String: Any] = [:]
    @State private var rounds: [SDKForgeRound] = []
    @State private var picked: Set<Int> = []
    @State private var working = false
    @State private var error = ""
    @State private var confirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("只搬完整的 user / assistant 正文。Thought process、工具、结果和图片都不进新窗；SDK 锚点重新加载，LMC-5 继续共用。")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Picker("方式", selection: $mode) {
                        Text("默认保留").tag("latest")
                        Text("挑选轮次").tag("picker")
                    }.pickerStyle(.segmented)

                    if mode == "latest" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("保留轮次"); Spacer(); Text("\(Int(retain)) / \(total)") }
                            Slider(value: $retain, in: 1...Double(max(total, 1)), step: 1)
                                .onChange(of: retain) { _ in Task { await loadPreview() } }
                        }
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(rounds) { round in
                                Button {
                                    if picked.contains(round.idx) { picked.remove(round.idx) }
                                    else { picked.insert(round.idx) }
                                    preview = [:]
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: picked.contains(round.idx)
                                              ? "checkmark.circle.fill" : "circle")
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("#\(round.idx + 1)  \(round.at.prefix(16))")
                                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                            Text(round.head).font(.system(size: 13)).lineLimit(3)
                                        }
                                        Spacer()
                                    }
                                    .padding(11).background(Color(uiColor: .secondarySystemBackground),
                                                            in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                            }
                        }
                        Button("预览所选 \(picked.count) 轮") { Task { await previewPicked() } }
                            .buttonStyle(.bordered).disabled(picked.isEmpty)
                    }

                    if !preview.isEmpty { report }
                    if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(.red) }
                    Button { confirm = true } label: {
                        HStack { if working { ProgressView().tint(.white) }; Text("确认锻造并自动切换") }
                            .frame(maxWidth: .infinity).frame(height: 46)
                    }
                    .buttonStyle(.borderedProminent).disabled(working || !valid)
                }.padding(20)
            }
            .navigationTitle("SDK Forge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task { await loadPreview() }
            .confirmationDialog("确认锻造新 SDK 窗口？", isPresented: $confirm,
                                titleVisibility: .visible) {
                Button("确认锻造") { Task { await forge() } }
                Button("取消", role: .cancel) {}
            } message: { Text("新 session 探针通过后才自动切换；失败继续留在旧 session。") }
        }
    }

    private var total: Int { (preview["total_rounds"] as? NSNumber)?.intValue ?? rounds.count }
    private var valid: Bool { preview["valid"] as? Bool ?? false }
    private var report: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("锻造预览").font(.system(size: 14, weight: .semibold))
            Text("带走 \((preview["retained_rounds"] as? NSNumber)?.intValue ?? 0) / \(total) 轮纯正文")
            Text("新窗开局约 \((preview["estimated_tokens"] as? NSNumber)?.intValue ?? 0) token")
            if let first = preview["first_messages"] as? [String], let value = first.first {
                Text("开头：\(value)").lineLimit(2)
            }
            if let last = preview["last_messages"] as? [String], let value = last.last {
                Text("结尾：\(value)").lineLimit(2)
            }
        }.font(.system(size: 12)).foregroundStyle(.secondary)
            .padding(14).background(Color(uiColor: .secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 14))
    }

    @MainActor private func loadPreview() async {
        do {
            let obj = try await AlcoveAPI.getRaw("/api/sdk-shadow/forge?retain=\(Int(retain))")
            preview = obj
            rounds = (obj["rounds"] as? [[String: Any]] ?? []).map(SDKForgeRound.init)
            if retain > Double(max(rounds.count, 1)) { retain = Double(max(rounds.count, 1)) }
            error = ""
        } catch { self.error = "预览失败：\(error.localizedDescription)" }
    }

    @MainActor private func previewPicked() async {
        do {
            preview = try await AlcoveAPI.postRaw("/api/sdk-shadow/forge-preview",
                                                  body: ["pick": picked.sorted()])
            error = ""
        } catch { self.error = "预览失败：\(error.localizedDescription)" }
    }

    @MainActor private func forge() async {
        working = true; error = ""
        do {
            var body: [String: Any] = ["retain": Int(retain)]
            if mode == "picker" { body = ["pick": picked.sorted()] }
            let obj = try await AlcoveAPI.postRaw("/api/sdk-shadow/forge", body: body)
            guard obj["ok"] as? Bool == true, obj["probe_ok"] as? Bool == true else {
                throw NSError(domain: "SDKForge", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: obj["error"] as? String ?? "探针未通过"])
            }
            onForged(); dismiss()
        } catch { self.error = "锻造失败：\(error.localizedDescription)" }
        working = false
    }
}

private struct SDKShadowMessage: Identifiable {
    let id: String
    let role: String
    let text: String
    let at: String

    init?(_ json: [String: Any], index: Int) {
        guard let role = json["role"] as? String,
              let text = json["text"] as? String else { return nil }
        self.role = role
        self.text = text
        self.at = json["at"] as? String ?? ""
        self.id = "\(at)-\(index)-\(role)"
    }
}

private struct SDKShadowChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [SDKShadowMessage] = []
    @State private var draft = ""
    @State private var loading = true
    @State private var sending = false
    @State private var error = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if loading { ProgressView().padding(.top, 30) }
                            ForEach(messages) { message in
                                HStack {
                                    if message.role == "user" { Spacer(minLength: 42) }
                                    Text(message.text)
                                        .font(.system(size: 15.5))
                                        .foregroundStyle(message.role == "user" ? .white : .primary)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(message.role == "user" ? Color.indigo : Color(uiColor: .secondarySystemBackground),
                                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    if message.role != "user" { Spacer(minLength: 42) }
                                }
                                .id(message.id)
                            }
                            if sending {
                                HStack { ProgressView(); Text("陈璟正在影子里想…").font(.footnote).foregroundStyle(.secondary); Spacer() }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                if !error.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal).padding(.top, 6)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("在影子里和陈璟说话", text: $draft, axis: .vertical)
                        .focused($focused).lineLimit(1...5)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up").fontWeight(.semibold).foregroundStyle(.white)
                            .frame(width: 38, height: 38).background(Color.indigo, in: Circle())
                    }
                    .disabled(sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("SDK 影子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
            .task { await load() }
        }
    }

    @MainActor private func load() async {
        do {
            let obj = try await AlcoveAPI.getRaw("/api/sdk-shadow/history")
            let raw = obj["messages"] as? [[String: Any]] ?? []
            messages = raw.enumerated().compactMap { SDKShadowMessage($0.element, index: $0.offset) }
            error = ""
        } catch { self.error = "影子历史暂时没接上" }
        loading = false
    }

    @MainActor private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        draft = ""; sending = true; error = ""
        do {
            let obj = try await AlcoveAPI.postRaw("/api/sdk-shadow/send", body: ["text": text])
            if obj["ok"] as? Bool != true {
                throw NSError(domain: "SDKShadow", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: obj["error"] as? String ?? "回复失败"])
            }
            await load()
        } catch { self.error = error.localizedDescription }
        sending = false
    }
}

// MARK: - 单条消息

private final class AskSelectableTextView: UITextView {
    var onAsk: ((String) -> Void)?
    var onCopyTurn: (() -> Void)?

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard selectedRange.length > 0 else { return }
        let ask = UIAction(title: "询问", image: UIImage(systemName: "quote.bubble")) { [weak self] _ in
            guard let self,
                  self.selectedRange.location != NSNotFound,
                  self.selectedRange.length > 0 else { return }
            let selected = (self.text as NSString).substring(with: self.selectedRange)
            self.onAsk?(selected)
        }
        let copyTurn = UIAction(title: "复制整轮", image: UIImage(systemName: "doc.on.doc")) {
            [weak self] _ in self?.onCopyTurn?()
        }
        builder.insertChild(UIMenu(options: .displayInline, children: [ask, copyTurn]),
                            atStartOfMenu: .standardEdit)
    }
}

private struct SelectableMessageText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let color: UIColor
    var maximumNumberOfLines: Int = 0
    var onTruncationChange: ((Bool) -> Void)? = nil
    let onAsk: (String) -> Void
    let onCopyTurn: () -> Void

    final class Coordinator {
        var renderedKey: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> AskSelectableTextView {
        let view = AskSelectableTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: AskSelectableTextView, context: Context) {
        view.onAsk = onAsk
        view.onCopyTurn = onCopyTurn
        // 后台每 2.5 秒轮询会让 SwiftUI 重跑 updateUIView。正文其实没变，
        // 但重新赋 attributedText 会强制收掉 iOS 的选区和复制菜单。
        // 同一份渲染直接跳过；用户正在选字时，即使主题恰好变化也先让她选完。
        view.textContainer.maximumNumberOfLines = maximumNumberOfLines
        view.textContainer.lineBreakMode = maximumNumberOfLines > 0 ? .byTruncatingTail : .byWordWrapping
        let renderedKey = "\(text)\u{1f}\(fontSize)\u{1f}\(lineSpacing)\u{1f}\(color.description)\u{1f}\(maximumNumberOfLines)"
        guard context.coordinator.renderedKey != renderedKey else { return }
        guard view.selectedRange.length == 0 else { return }
        let source = alcoveMarkdown(text)
        let rendered = NSMutableAttributedString(attributedString: NSAttributedString(source))
        let all = NSRange(location: 0, length: rendered.length)
        rendered.addAttribute(.foregroundColor, value: color, range: all)
        rendered.enumerateAttribute(.font, in: all) { value, range, _ in
            let old = value as? UIFont
            var traits = old?.fontDescriptor.symbolicTraits ?? []
            let descriptor = UIFont.systemFont(ofSize: fontSize).fontDescriptor.withSymbolicTraits(traits)
            rendered.addAttribute(.font, value: UIFont(descriptor: descriptor ?? UIFont.systemFont(ofSize: fontSize).fontDescriptor,
                                                       size: fontSize), range: range)
        }
        if rendered.length > 0 && rendered.attribute(.font, at: 0, effectiveRange: nil) == nil {
            rendered.addAttribute(.font, value: UIFont.systemFont(ofSize: fontSize), range: all)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        rendered.addAttribute(.paragraphStyle, value: paragraph, range: all)
        view.attributedText = rendered
        context.coordinator.renderedKey = renderedKey
        reportTruncation(view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: AskSelectableTextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        DispatchQueue.main.async { reportTruncation(uiView) }
        return size
    }

    private func reportTruncation(_ view: UITextView) {
        guard maximumNumberOfLines > 0, let onTruncationChange else { return }
        view.layoutManager.ensureLayout(for: view.textContainer)
        let shown = view.layoutManager.glyphRange(for: view.textContainer)
        let truncated = NSMaxRange(shown) < view.layoutManager.numberOfGlyphs
        DispatchQueue.main.async { onTruncationChange(truncated) }
    }
}

struct MessageRow: View {
    let msg: ChatMessage
    let sticker: Sticker?
    var theme: AlcoveTheme = .haven
    var fontSize: Int = 14
    var showTime: Bool = true
    var recall: RecallItem? = nil
    // 0818 她要的：思绪永远在我这一轮的最上面（哪怕这一轮先发了表情/截图），
    // 思绪下面再挂一条独立的可展开「工具轨迹」。列表那头按连续的我方消息算一轮，
    // 把整轮的思绪和动作提到轮首这条消息上，其余消息自己的不再重复显示。
    var hoistedThought: String? = nil
    var hoistedActivity: [ActivityItem] = []
    var suppressOwnThought = false
    var suppressOwnActivity = false
    var photoURLs: [URL] = []
    var photoNamespace: Namespace.ID
    var onTapImages: ([URL], Binding<Int>) -> Void
    var onDelete: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil
    var wholeTurnText: String = ""
    var paragraphSelectionMode = false
    var paragraphSelected = false
    var onBeginParagraphSelection: (() -> Void)? = nil
    var onToggleParagraphSelection: (() -> Void)? = nil
    var onQuote: ((String) -> Void)? = nil
    var onResend: ((String) -> Void)? = nil
    var onPlayMusic: ((MusicSong) -> Void)? = nil
    var onContentChange: (() -> Void)? = nil
    @State private var showThinking = false
    @State private var showActivity = false   // 0730 过程记录展开
    // 0820 按时间线摆之后，点开的是「这一段」，不是整轮那一坨
    @State private var openedThink: String? = nil
    @State private var openedTools: [ActivityItem]? = nil
    @State private var openedToolDetail: ActivityItem? = nil
    @State private var showRecall = false
    @State private var showPulse = false
    @Environment(\.bubbleGlassStyle) private var bubbleGlassStyle

    private var isUser: Bool { msg.role == "user" }
    private var timestampTextInset: CGFloat {
        if theme.isPaper && !isUser { return 0 }
        return !msg.text.isEmpty && !msg.isSticker ? 12 : 0
    }
    private var shouldShowMetaRow: Bool {
        msg.pending || msg.asleepAtSend || showTime
    }

    /// 这条消息头上要挂的轨迹：轮首拿整轮的，其他消息不挂。
    /// 整条时间线（动作 / 中间说的话 / 中间的思绪）按时间排，一个不丢。
    private var trailItems: [ActivityItem] {
        if !hoistedActivity.isEmpty { return hoistedActivity }
        if suppressOwnActivity { return [] }
        return msg.activity
    }
    /// 0820 她定的：跑命令那栏只放命令，思绪归思绪栏，两边彻底分开
    private var trailTools: [ActivityItem] { trailItems.filter { $0.kind == "tool" } }
    private var trailToolCount: Int { trailTools.count }

    private func trailLabel(_ items: [ActivityItem]) -> String {
        enum Kind: Hashable { case command, read, tool }
        func kind(_ item: ActivityItem) -> Kind {
            if item.toolName == "Bash" { return .command }
            if item.toolName == "Read" { return .read }
            return .tool
        }
        var order: [Kind] = []
        var counts: [Kind: Int] = [:]
        for item in items {
            let k = kind(item)
            if counts[k] == nil { order.append(k) }
            counts[k, default: 0] += 1
        }
        let bits = order.enumerated().map { offset, k -> String in
            let n = counts[k, default: 0]
            let phrase: String
            switch k {
            case .command: phrase = n == 1 ? "Ran a command" : "Ran \(n) commands"
            case .read: phrase = n == 1 ? "Read a file" : "Read \(n) files"
            case .tool: phrase = n == 1 ? "Used a tool" : "Used \(n) tools"
            }
            guard offset > 0 else { return phrase }
            return phrase.prefix(1).lowercased() + phrase.dropFirst()
        }
        return bits.isEmpty ? "Used a tool" : bits.joined(separator: ", ")
    }
    private var trailEntryLabel: String { trailLabel(trailTools) }

    /// 0820 她要的：一段思绪一个折叠面板，跟命令行按发生顺序交替排。
    /// 把时间线切成一块块 —— 连着的命令归一行，每段思绪自己一个面板。
    private enum TurnBlock: Identifiable {
        case think(String, Int)
        case tools([ActivityItem], Int)
        var id: String {
            switch self {
            case .think(_, let i): return "t\(i)"
            case .tools(_, let i): return "k\(i)"
            }
        }
    }
    private var turnBlocks: [TurnBlock] {
        var out: [TurnBlock] = []
        var buf: [ActivityItem] = []
        var n = 0
        for it in msg.segments {
            if it.kind == "think" || it.kind == "thinking" {
                if !buf.isEmpty { out.append(.tools(buf, n)); n += 1; buf = [] }
                if !it.content.isEmpty { out.append(.think(it.content, n)); n += 1 }
            } else if it.kind == "tool" {
                buf.append(it)
            }
        }
        if !buf.isEmpty { out.append(.tools(buf, n)) }
        return out
    }
    private var firstThinkBlockID: String? {
        turnBlocks.first {
            if case .think = $0 { return true }
            return false
        }?.id
    }
    /// 只有话没有动作的轮次不挂轨迹行（那些话本来就在气泡里）
    private var trailWorthShowing: Bool { trailToolCount > 0 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: isUser ? .trailing : .leading,
                   spacing: theme.isPaper && !isUser ? 10 : 7) {
                // 0820：有时间线就照发生顺序摆 —— 想一段出一个面板，
                // 中间干的活收成一行。没时间线（老消息）走原来那套。
                if !isUser && !turnBlocks.isEmpty {
                    ForEach(turnBlocks) { blk in
                        switch blk {
                        case .think(let text, let i):
                            thinkPanelRow(text, index: i, showRecall: blk.id == firstThinkBlockID)
                        case .tools(let items, let i):
                            toolRow(items, index: i)
                        }
                    }
                } else {
                    if let think = visibleChatThought {
                        thinkingBlock(think)
                    } else if recall != nil {
                        recallBadge // 没有思绪行时角标单独站一行，和 PWA 一致
                    }
                    if !isUser && trailWorthShowing {
                        trailBlock
                    }
                }
                if let paperDate = msg.morningPaperDate {
                    MorningPaperMessageCard(date: paperDate, theme: theme)
                } else if let inside = msg.insideText {
                    InsideMessageCard(text: inside, date: msg.date, theme: theme)
                } else if let ghost = msg.ghostCard {
                    GhostActivityMessageCard(card: ghost, theme: theme)
                } else if let play = msg.playCard {
                    PlayPageMessageCard(card: play, theme: theme)
                } else if let reading = msg.readingCard {
                    ReadingShareMessageCard(card: reading, theme: theme)
                } else if let work = msg.workCard {
                    WorkDeliveryMessageCard(card: work, theme: theme)
                } else if let journey = msg.journeyCard {
                    JourneyMessageCard(ref: journey, theme: theme)
                        .frame(maxWidth: .infinity)   // 她要卡片在聊天页正中间
                } else if msg.isSticker {
                    stickerBody
                } else {
                    if !photoURLs.isEmpty {
                        OfficialPhotoGridMessageView(urls: photoURLs, messageID: "chat-\(msg.id)",
                                                     onOpen: onTapImages)
                            .matchedTransitionSource(id: "chat-\(msg.id)", in: photoNamespace)
                    } else if msg.isImage, let raw = msg.attachmentUrl {
                        imageBody(raw)
                    }
                    if msg.isAudio, let raw = msg.attachmentUrl {
                        AudioBubble(url: AlcoveAPI.attachmentURL(raw), isUser: isUser, theme: theme)
                    }
                    if msg.isDocument, let raw = msg.attachmentUrl {
                        DocumentAttachmentCard(
                            url: AlcoveAPI.attachmentURL(raw),
                            filename: msg.attachmentFilename ?? "文件",
                            theme: theme
                        )
                    }
                    if let song = msg.musicCard {
                        MusicMessageCard(song: song, theme: theme, isUser: isUser) { onPlayMusic?(song) }
                    } else if !msg.displayText.isEmpty && !(msg.isSticker) && !msg.isBareLink {
                        if paragraphSelectionMode && !isUser {
                            HStack(alignment: .top, spacing: 9) {
                                Button { onToggleParagraphSelection?() } label: {
                                    Image(systemName: paragraphSelected
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19, weight: .regular))
                                        .foregroundColor(paragraphSelected
                                                         ? theme.fyAccent : theme.textDim)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 3)
                                bubble
                                    .allowsHitTesting(false)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { onToggleParagraphSelection?() }
                        } else {
                            bubble
                        }
                    }
                    // 正文里有链接：气泡下面长一张小卡片（只有链接的话就只留卡）
                    if let link = msg.firstLinkURL, msg.musicCard == nil, !msg.isSticker {
                        LinkPreviewCard(url: link, theme: theme, isUser: isUser)
                    }
                }
                // 0819 活动脚印（她把活动卡片换掉了）：气泡外面一行浅灰斜体，
                // 「逛了花园 写了念头」，词之间空格隔开。轻到不特意看就滑过去了。
                if !isUser && !msg.trace.isEmpty {
                    Text(msg.trace.joined(separator: "  "))
                        .font(.system(size: 11.5, design: .serif))
                        .italic()
                        .foregroundColor(theme.textLight.opacity(0.82))
                        .padding(.leading, 3)
                        .padding(.top, 1)
                }
                if shouldShowMetaRow {
                    HStack(spacing: theme.isPaper && !isUser ? 14 : 4) {
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
                        if showTime, !isUser, !msg.displayText.isEmpty {
                            Button { onBeginParagraphSelection?() } label: {
                                Image(systemName: "checklist")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(theme.timestamp.opacity(
                                        paragraphSelectionMode ? 1 : 0.72))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("选择正文段落")
                        }
                        if showTime, !isUser, let bpm = msg.heartRate {
                            Button { showPulse = true } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color(red: 0.78, green: 0.43, blue: 0.50).opacity(0.82))
                                    Text("\(bpm) bpm")
                                        .font(.system(size: 10, design: .serif))
                                        .foregroundColor(theme.timestamp.opacity(0.72))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, isUser ? 0 : timestampTextInset)
                    .padding(.trailing, isUser ? timestampTextInset : 0)
                }
            }
            if !isUser {
                // 晨报和旅行卡片是整行居中的东西，不吃我这边气泡的右侧留白
                Spacer(minLength: (msg.morningPaperDate != nil || msg.journeyCard != nil) ? 0 : (theme.isPaper ? 15 : 48))
            }
        }
        .padding(.leading, theme.isPaper && !isUser && msg.morningPaperDate == nil && msg.journeyCard == nil ? 12 : 0)
        .padding(.top, 2)
        .padding(.bottom, showTime ? 12 : 5)
        .sheet(item: Binding(get: { openedThink.map { OneThought(text: $0) } },
                             set: { openedThink = $0?.text })) { one in
            NavigationStack {
                ScrollView {
                    Text(one.text)
                        .font(.system(size: 15))
                        .lineSpacing(7)
                        .foregroundColor(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 30)
                }
                .background(theme.fyCardSub.ignoresSafeArea())
                .navigationTitle("Thought process")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { openedThink = nil } } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.fyCardSub)
        }
        .sheet(item: Binding(get: { openedTools.map { OneTrail(items: $0) } },
                             set: { openedTools = $0?.items })) { one in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(one.items) { item in
                            Button { openedToolDetail = item } label: {
                            HStack(alignment: .top, spacing: 11) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(theme.fyAccent)
                                    .frame(width: 18).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.toolName == "Bash" ? "Ran" : "Used")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(theme.text)
                                    Text(item.desc.isEmpty ? item.content : item.desc)
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textDim)
                                            .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(theme.textDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 30)
                }
                .background(theme.fyCardSub.ignoresSafeArea())
                .navigationTitle(trailLabel(one.items))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { openedTools = nil } } }
            }
            .sheet(item: $openedToolDetail) { item in
                commandDetailPanel(item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(theme.fyCardSub)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.fyCardSub)
        }
        .sheet(isPresented: $showThinking) {
            paperThinkingPanel
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.fyCardSub)
        }
        .fullScreenCover(isPresented: $showPulse) {
            ZStack(alignment: .topTrailing) {
                NativePulseView()
                Button { showPulse = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.text)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.top, 10).padding(.trailing, 12)
            }
        }
    }

    private var visibleChatThought: String? {
        if let hoisted = hoistedThought?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hoisted.isEmpty { return hoisted }
        if suppressOwnThought { return nil }
        if let handwritten = msg.thinking?.trimmingCharacters(in: .whitespacesAndNewlines),
           !handwritten.isEmpty { return handwritten }
        if theme.isPaper && !isUser,
           let native = msg.nativeThinking?.trimmingCharacters(in: .whitespacesAndNewlines),
           !native.isEmpty { return cuteThinkingPlaceholder }
        return nil
    }

    private var cuteThinkingPlaceholder: String {
        let lines = ["在想一些没说出口的事", "脑袋里悄悄转了几圈", "在想一些色色的事", "把念头藏在袖子里"]
        return lines[abs(msg.ts.hashValue) % lines.count]
    }

    // The text stays crisp above a real wallpaper-refraction layer.
    private func markdownText(_ raw: String) -> Text {
        Text(alcoveMarkdown(raw))
    }

    private var bubble: some View {
        return Group {
            if theme.isPaper && !isUser {
                bubbleContents.padding(.horizontal, 0).padding(.vertical, 2)
            } else {
                bubbleContents
                    .padding(.horizontal, 14)
                    .padding(.vertical, theme.isPaper && isUser ? 11 : 10)
                    .background {
                        if theme.isPaper {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isUser ? theme.bubbleUser : theme.bubbleAI)
                        } else {
                            BubbleGlassBackground(
                                tintColor: isUser ? theme.bubbleUser : theme.bubbleAI,
                                tintOpacity: isUser ? 0.14 : 0.09,
                                style: bubbleGlassStyle
                            )
                        }
                    }
            }
        }
            .contentShape(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
            )

    }

    private var bubbleContents: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if let quote = msg.quotedSelection, !quote.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(quote).lineLimit(2)
                }
                .font(.system(size: 12))
                .foregroundColor(theme.textDim.opacity(0.78))
            }
            SelectableMessageText(
                text: msg.textWithoutLink,
                fontSize: CGFloat(fontSize),
                lineSpacing: theme.isPaper ? 7 : 5,
                color: UIColor(msg.asleepAtSend ? theme.textDim : theme.text),
                maximumNumberOfLines: 0,
                onTruncationChange: { _ in },
                onAsk: { onQuote?($0) },
                onCopyTurn: {
                    UIPasteboard.general.string = wholeTurnText.isEmpty
                        ? msg.displayText : wholeTurnText
                }
            )
        }
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


    /// 思绪下面那条：工具轨迹。纸页主题跟 Thought process 一样点开是面板，
    /// 其他主题原地展开。每条一个动作 + ✓ done。
    private var trailBlock: some View {
        VStack(alignment: .leading, spacing: showActivity ? 7 : 0) {
            Button {
                showActivity = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: theme.isPaper ? 12 : 11, weight: .light))
                    Text(trailEntryLabel)
                        .font(theme.isPaper ? .system(size: 13, weight: .medium) : .custom("Georgia", size: 12))
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
        .padding(.leading, theme.isPaper ? 0 : 10)
        .sheet(isPresented: $showActivity) {
            paperTrailPanel
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.fyCardSub)
        }
    }


    private var paperTrailPanel: some View {
        NavigationStack {
            ScrollView {
                // 0820：只列命令，思绪不进这儿。每条底下是我敲命令时手写的那句说明。
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(trailTools) { item in
                        Button { openedToolDetail = item } label: {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(theme.fyAccent)
                                .frame(width: 18)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.toolName == "Bash" ? "Ran" : "Used")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(theme.text)
                                Text(item.desc.isEmpty ? item.content : item.desc)
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textDim)
                                        .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.textDim)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22).padding(.bottom, 30)
            }
            .background(theme.fyCardSub.ignoresSafeArea())
            .foregroundColor(theme.text)
            .navigationTitle(trailEntryLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showActivity = false } } }
        }
        .sheet(item: $openedToolDetail) { item in
            commandDetailPanel(item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.fyCardSub)
        }
    }

    // 0730 过程记录：展开后的时间线（旧的时间戳旁面板，留着给别处用）
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

    // ── 0820 按时间线摆的两种行 ─────────────────────────────
    // 她要的：一轮里想了三次就出现三个思绪面板，中间干的活收成一行计数。
    // 点开还是各自的面板，样式跟原来那套一模一样，只是数量和顺序变了。

    private func thinkPanelRow(_ text: String, index: Int, showRecall: Bool) -> some View {
        HStack(spacing: 4) {
            Button {
                openedThink = text
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
            } label: {
                HStack(spacing: 4) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: theme.isPaper ? 13 : 12, weight: .light))
                Text("Thought process")
                    .font(theme.isPaper ? .system(size: 13, weight: .medium) : .custom("Georgia", size: 12))
                    .lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            if showRecall, recall != nil {
                recallBadge.padding(.leading, 6)
            }
        }
    }

    private func toolRow(_ items: [ActivityItem], index: Int) -> some View {
        Button {
            openedTools = items
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: theme.isPaper ? 12 : 11, weight: .light))
                Text(trailLabel(items))
                    .font(theme.isPaper ? .system(size: 13, weight: .medium) : .custom("Georgia", size: 12))
                    .lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 8))
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func thinkingBlock(_ think: String) -> some View {
        VStack(alignment: .leading, spacing: showThinking ? 7 : 0) {
            // 0820 她定的：三个主题统一成「点一下开面板」，不再原地展开。
            // 入口的字保留我们自己那套（带秒数），没跟着官方改成 Thought process ——
            // 统一的是布局，不是说法。
            HStack(spacing: 4) {
                Button {
                    showThinking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onContentChange?() }
                } label: {
                    HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: theme.isPaper ? 13 : 12, weight: .light))
                    Text("Thought process")
                        .font(theme.isPaper ? .system(size: 13, weight: .medium) : .custom("Georgia", size: 12))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                if recall != nil {
                    recallBadge.padding(.leading, 6)
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
            }
            .shadow(color: Color.white.opacity(0.28), radius: 1.5)
            }
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
                // 0820 她定的：跟命令栏剥开之后就不需要那条竖线了 ——
                // 这里只剩一段话，跟官方那个面板一样干净。
                VStack(alignment: .leading, spacing: 0) {
                    Text(visibleChatThought ?? cuteThinkingPlaceholder)
                        .font(.system(size: 15))
                        .lineSpacing(7)
                        .foregroundColor(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22).padding(.bottom, 30)
            }
            .background(theme.fyCardSub.ignoresSafeArea())
            .foregroundColor(theme.text)
            .navigationTitle("Thought process")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showThinking = false } } }
        }
    }

    private func commandDetailPanel(_ item: ActivityItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    commandDetailSection("Command", text: item.command.isEmpty
                                         ? "这条旧记录没有保存原始命令"
                                         : item.command, isError: false)
                    if !item.output.isEmpty || item.isError {
                        commandDetailSection(item.isError ? "Error" : "Output",
                                             text: item.output.isEmpty ? "No output" : item.output,
                                             isError: item.isError)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 36)
            }
            .background(theme.fyCardSub.ignoresSafeArea())
            .navigationTitle(item.toolName.isEmpty ? "Tool" : item.toolName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { openedToolDetail = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 38, height: 38)
                            .background(theme.fyCard, in: Circle())
                    }
                }
            }
        }
    }

    private func commandDetailSection(_ title: String, text: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isError ? .red : theme.textDim)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(theme.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.fyCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.textDim.opacity(0.16), lineWidth: 0.7))
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
        let previewURL = AlcoveAPI.attachmentThumbnailURL(raw)
        return AsyncImage(url: previewURL) { img in
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
        .contextMenu {
            Button {
                Task { await PhotoLibrarySaver.save(url) }
            } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }
        }
    }

    static let hm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

/// 陈璟端上来的一页：点一下全屏打开，不跳浏览器。
private struct PlayPageMessageCard: View {
    let card: PlayPageCard
    let theme: AlcoveTheme
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 12) {
                Text(card.emoji ?? "✦")
                    .font(.system(size: 26))
                    .frame(width: 46, height: 46)
                    .background(theme.fyCardSub.opacity(0.62), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    if !card.subtitle.isEmpty {
                        Text(card.subtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(theme.textDim)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textDim.opacity(0.7))
            }
            .padding(13)
            .frame(maxWidth: 300, alignment: .leading)
            .background(theme.fyCard.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.fyBorder.opacity(0.7), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $open) {
            if let u = card.url {
                PlayPageSheet(url: u, title: card.title) { open = false }
            }
        }
    }
}

private struct PlayPageSheet: View {
    let url: URL
    let title: String
    var dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlainWebView(url: url).ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.42, green: 0.40, blue: 0.41))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color(red: 210/255, green: 210/255, blue: 218/255).opacity(0.3), lineWidth: 1))
            }
            .padding(.leading, 14)
            .padding(.top, 6)
        }
    }
}

/// 独立的一块 WebView，不碰 WebHouse 那个常驻 PWA 实例。
private struct PlainWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct ReadingShareMessageCard: View {
    let card: ReadingShareCard
    let theme: AlcoveTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "books.vertical.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.book).font(.system(size: 16, weight: .semibold, design: .serif))
                    if !card.author.isEmpty { Text(card.author).font(.system(size: 9.5)).foregroundColor(theme.textDim) }
                }
                Spacer()
                Text("共读摘记").font(.system(size: 9, weight: .semibold)).foregroundColor(theme.fyAccent)
            }
            ForEach(card.quotes) { quote in
                VStack(alignment: .leading, spacing: 6) {
                    Text("“\(quote.text)”").font(.system(size: 13, design: .serif)).lineSpacing(4)
                    if !quote.note.isEmpty { Text(quote.note).font(.system(size: 11)).foregroundColor(theme.textDim) }
                    HStack { Text("第 \(quote.chapter) 章"); Spacer(); Text(quote.time) }
                        .font(.system(size: 8.5, design: .monospaced)).foregroundColor(theme.textDim.opacity(0.8))
                }.padding(11).background(theme.fyCardSub.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
            }
        }.padding(14).frame(maxWidth: 315, alignment: .leading)
            .background(theme.fyCard.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.fyBorder.opacity(0.7), lineWidth: 0.7))
    }
}

private struct WorkDeliveryMessageCard: View {
    let card: WorkDeliveryCard
    let theme: AlcoveTheme
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 19)).foregroundColor(theme.fyAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title).font(.system(size: 16, weight: .semibold, design: .serif))
                    Text("WORK DELIVERED · #\(card.taskId)").font(.system(size: 8.5, weight: .semibold, design: .monospaced)).tracking(0.7).foregroundColor(theme.textDim)
                }
                Spacer()
                Text(card.status == "done" ? "已完成" : card.status).font(.system(size: 9, weight: .semibold)).foregroundColor(theme.fyAccent)
            }
            if !card.result.isEmpty {
                Text(card.result).font(.system(size: 13, design: .serif)).lineSpacing(4)
                    .lineLimit(expanded ? nil : 5)
                    .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.fyCardSub.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
            }
            if !card.artifacts.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(expanded ? card.artifacts : Array(card.artifacts.prefix(3)), id: \.self) { item in Label(item, systemImage: "doc.badge.gearshape").font(.system(size: 10, design: .monospaced)).foregroundColor(theme.textDim) }
                }
            }
            if card.result.count > 180 || card.artifacts.count > 3 {
                Button(expanded ? "收起交付" : "查看完整交付") { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            }
            Text(card.finishedAt.replacingOccurrences(of: "T", with: " ").prefix(16))
                .font(.system(size: 8.5, design: .monospaced)).foregroundColor(theme.textDim.opacity(0.75))
        }.padding(14).frame(maxWidth: 315, alignment: .leading)
            .background(theme.fyCard.opacity(0.95), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.fyAccent.opacity(0.38), lineWidth: 0.8))
    }
}

private struct InsideMessageCard: View {
    let text: String
    let date: Date
    let theme: AlcoveTheme
    @State private var expanded = false
    private static let time: DateFormatter = {
        let value = DateFormatter(); value.dateFormat = "HH:mm"; return value
    }()

    var body: some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "quote.opening").font(.system(size: 12))
                    Text("Inside").font(.system(size: 12, weight: .semibold, design: .serif)).tracking(1)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 9))
                }
                if expanded {
                    Text(text).font(.system(size: 13, design: .serif)).lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("···· " + Self.time.string(from: date))
                        .font(.system(size: 10, design: .monospaced)).opacity(0.6)
                }
            }
            .foregroundColor(theme.isDark ? theme.text : Color(red: 0.32, green: 0.29, blue: 0.30))
            .padding(14)
            .frame(maxWidth: 290, alignment: .leading)
            .background(theme.isDark ? theme.fyCard : Color(red: 0.91, green: 0.88, blue: 0.86),
                        in: RoundedRectangle(cornerRadius: theme.isPaper ? 7 : 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.isPaper ? 7 : 15)
                .stroke(theme.fyBorder, lineWidth: 0.8))
        }.buttonStyle(.plain)
    }
}

private struct MorningPaperMessageCard: View {
    let date: String
    let theme: AlcoveTheme
    @State private var expanded = false

    private var dateLine: String {
        let input = DateFormatter(); input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let value = input.date(from: date) else { return date }
        let output = DateFormatter(); output.locale = Locale(identifier: "zh_CN")
        output.dateFormat = "M月d日"
        return output.string(from: value)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.24)) { expanded.toggle() } } label: {
                HStack(spacing: 9) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.18, green: 0.34, blue: 0.72))
                    Text("雨霁报")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .tracking(1.5)
                    Text("· \(dateLine)")
                        .font(.system(size: 11, design: .monospaced)).opacity(0.62)
                    Spacer(minLength: 16)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium)).opacity(0.55)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                Rectangle().fill(Color.black.opacity(0.22)).frame(height: 0.7)
                    .padding(.horizontal, 12)
                NativeMorningPaperView(requestedDate: date, embedded: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.24)) { expanded = false }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .foregroundColor(Color(red: 0.22, green: 0.20, blue: 0.18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.968, green: 0.958, blue: 0.932),
                    in: RoundedRectangle(cornerRadius: theme.isPaper ? 5 : 12,
                                         style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.isPaper ? 5 : 12)
            .stroke(Color.black.opacity(0.13), lineWidth: 0.8))
    }
}

private struct GhostActivityMessageCard: View {
    let card: GhostActivityCard
    let theme: AlcoveTheme
    @State private var expanded = true

    private var period: String {
        let hour = Int(card.wake.split(separator: ":").first ?? "") ?? -1
        switch hour { case 0..<6: return "凌晨"; case 6..<12: return "早上"; case 12..<18: return "下午"; default: return "晚上" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold))
                    Text("\(period) \(card.wake)").font(.system(size: 13, weight: .semibold, design: .serif))
                    Text("· 醒了\(card.duration)分钟").font(.system(size: 11)).foregroundColor(theme.textDim)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 9))
                }
            }.buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(card.items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Text(item.time).font(.system(size: 10, design: .monospaced))
                                .foregroundColor(theme.textDim).frame(width: 42, alignment: .leading)
                            Circle().fill(theme.fyAccent).frame(width: 5, height: 5).padding(.top, 5)
                            Text(item.desc).font(.system(size: 12, design: .serif)).lineSpacing(3)
                        }
                    }
                    if let summary = card.insideSummary, !summary.isEmpty {
                        Text("“\(summary)”").font(.system(size: 11, design: .serif)).italic()
                            .foregroundColor(theme.textDim).padding(.top, 3)
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(theme.fyBorder).frame(width: 1).padding(.leading, 47)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
                }
            }
        }
        .foregroundColor(theme.text)
        .padding(14)
        .frame(maxWidth: 310, alignment: .leading)
        .background(theme.fyCard, in: RoundedRectangle(cornerRadius: theme.isPaper ? 8 : 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.isPaper ? 8 : 16).stroke(theme.fyBorder, lineWidth: 0.8))
    }
}

private struct DocumentAttachmentCard: View {
    let url: URL
    let filename: String
    let theme: AlcoveTheme
    private var ext: String { (filename as NSString).pathExtension.uppercased() }

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 22, weight: .light)).foregroundColor(theme.fyAccent)
                    .frame(width: 34, height: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(filename).font(.system(size: 13, weight: .medium)).lineLimit(2)
                    Text(ext.isEmpty ? "文件" : ext + " 文件")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(theme.textDim)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.down.circle").font(.system(size: 17, weight: .light))
                    .foregroundColor(theme.textDim)
            }
            .foregroundColor(theme.text)
            .padding(12)
            .frame(maxWidth: 280, alignment: .leading)
            .background(theme.fyCard, in: RoundedRectangle(cornerRadius: theme.isPaper ? 8 : 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.isPaper ? 8 : 15).stroke(theme.fyBorder, lineWidth: 0.8))
        }.buttonStyle(.plain)
    }
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
                    .font(.system(size: 11))
                    .italic()
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
                    .font(.system(size: 10))
                    .tracking(0.4)
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
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 14, bottomLeadingRadius: 4,
            bottomTrailingRadius: 14, topTrailingRadius: 14,
            style: .continuous
        ))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }
}

// SDK/CLI 正式流式行：占住最终回复的位置，正文在这里直接长出来；
// finish 后 ChatStore 先拉正式消息，再同一拍撤掉这一行，不做预览卡替换动画。
struct StreamingAssistantRow: View {
    let state: AlcoveAPI.LiveState
    let theme: AlcoveTheme
    let fontSize: Int
    @State private var showThought = false

    private var bodyText: String {
        [state.say, state.pendingSay].filter { !$0.isEmpty }.joined(separator: "")
    }
    private var liveTools: [AlcoveAPI.LiveProcessItem] {
        state.timeline.filter { $0.kind == "tool" }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if !state.thinking.isEmpty {
                    Button { showThought = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .font(.system(size: 13, weight: .light))
                            Text("Thought process")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.right").font(.system(size: 8))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Thought process 正在生成")
                }
                if !liveTools.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(liveTools) { tool in
                            HStack(spacing: 6) {
                                Image(systemName: tool.done
                                      ? (tool.ok == false ? "xmark.circle" : "checkmark.circle")
                                      : "gearshape.2")
                                Text(tool.text).lineLimit(1)
                            }
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                if !bodyText.isEmpty {
                    SelectableMessageText(
                        text: bodyText, fontSize: CGFloat(fontSize),
                        lineSpacing: theme.isPaper ? 7 : 5,
                        color: UIColor(theme.text), maximumNumberOfLines: 0,
                        onTruncationChange: { _ in }, onAsk: { _ in }, onCopyTurn: {})
                }
                if state.active && !state.finishing {
                    Capsule().fill(theme.textDim.opacity(0.65))
                        .frame(width: 14, height: 2)
                        .opacity(0.9)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, theme.isPaper ? 12 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: theme.isPaper ? 15 : 48)
        }
        .padding(.top, 2).padding(.bottom, 5)
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $showThought) {
            NavigationStack {
                ScrollView {
                    Text(state.thinking)
                        .font(.system(size: 15))
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                }
                .navigationTitle("Thought process")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { showThought = false }
                }}
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
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

// 主聊天双方共用：少图横排；多图横滑，左侧可展开为两列全览。圆桌仍保留叠牌。
struct OfficialPhotoGridMessageView: View {
    let urls: [URL]
    let messageID: String
    let onOpen: ([URL], Binding<Int>) -> Void

    @State private var currentIndex = 0
    @State private var isExpanded = false
    private let side: CGFloat = 124
    private let gap: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: gap) {
            if urls.count > 2 {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        Text(isExpanded ? "收起" : "展开")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .systemGray5).opacity(0.78), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起全部照片" : "展开全部照片")
            }
            if isExpanded {
                grid
            } else {
                strip
            }
        }
        .id(messageID)
    }

    private var strip: some View {
        Group {
            if urls.count > 2 {
                ScrollView(.horizontal, showsIndicators: false) { lazyPhotoRow }
                    .frame(width: side * 2 + gap)
            } else {
                HStack(spacing: gap) { photos }
            }
        }
    }

    private var lazyPhotoRow: some View {
        LazyHStack(spacing: gap) {
            photos
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.fixed(side), spacing: gap),
                            GridItem(.fixed(side), spacing: gap)],
                  alignment: .leading, spacing: gap) {
            photos
        }
        .frame(width: side * 2 + gap, alignment: .leading)
    }

    @ViewBuilder private var photos: some View {
        ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
            photo(url)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onTapGesture { open(at: index) }
                .accessibilityLabel("照片 \(index + 1)，共 \(urls.count) 张")
                .accessibilityAddTraits(.isButton)
        }
    }

    private func open(at index: Int) {
        currentIndex = min(max(index, 0), urls.count - 1)
        onOpen(urls, Binding(
            get: { currentIndex },
            set: { currentIndex = min(max($0, 0), urls.count - 1) }
        ))
    }

    private func photo(_ url: URL) -> some View {
        let previewURL: URL = {
            guard let range = url.path.range(of: "/attachments/") else { return url }
            return AlcoveAPI.attachmentThumbnailURL(
                "/attachments/" + String(url.path[range.upperBound...]))
        }()
        return AsyncImage(url: previewURL, transaction: Transaction(animation: nil)) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .failure: Color(.tertiarySystemFill).overlay(Image(systemName: "photo"))
            default: Color(.tertiarySystemFill).overlay(ProgressView())
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button {
                Task { await PhotoLibrarySaver.save(url) }
            } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }
        }
    }
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
        let previewURL: URL = {
            let path = url.path
            guard let range = path.range(of: "/attachments/") else { return url }
            return AlcoveAPI.attachmentThumbnailURL("/attachments/" + String(path[range.upperBound...]))
        }()
        return AsyncImage(url: previewURL, transaction: Transaction(animation: nil)) { phase in
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
        .contextMenu {
            Button {
                Task { await PhotoLibrarySaver.save(url) }
            } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }
        }
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

enum PhotoLibrarySaver {
    static func save(_ url: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else { return }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { return }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            // Context-menu saving is intentionally non-blocking; a failed
            // network fetch leaves the existing image bubble untouched.
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
        .contextMenu {
            Button {
                Task { await PhotoLibrarySaver.save(url) }
            } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }
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

// MARK: 上传前的图片处理

/// 0813 查卡顿查出来的病根：三个入口都只调 jpegData(compressionQuality:)，
/// 只压质量不降分辨率。iPhone 直出 4032×3024，一张 2-4MB 原样上行，
/// 相册一次还能选九张。库里 1875 张图有 172 张超过 2MB。
/// 长边压到 2048 之后约掉到十分之一，她屏幕上看不出差别。
/// 缩完的图同时当预览条的缩略图用，省得全尺寸 UIImage 堆在内存里。
enum UploadImage {
    static let maxEdge: CGFloat = 2048
    static let quality: CGFloat = 0.8

    static func prepare(_ image: UIImage) -> (thumb: UIImage, jpeg: Data)? {
        let scaled = downscaled(image)
        guard let data = scaled.jpegData(compressionQuality: quality) else { return nil }
        return (scaled, data)
    }

    static func downscaled(_ image: UIImage) -> UIImage {
        // size 是点数，乘 scale 才是真实像素——相机和相册来的图 scale 不一定是 1
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxEdge, longest > 0 else { return image }
        let ratio = maxEdge / longest
        let target = CGSize(width: (pixelWidth * ratio).rounded(),
                            height: (pixelHeight * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        // target 已经是像素目标，再乘屏幕倍率会画出三倍大的图
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
