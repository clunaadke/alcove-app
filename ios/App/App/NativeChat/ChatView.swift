import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var store = ChatStore()
    @State private var draft = ""
    @State private var showStickers = false
    @State private var photoItem: PhotosPickerItem?
    @State private var viewerURL: URL?
    @FocusState private var inputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if store.loading {
                ProgressView("回家中…")
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
        .onChange(of: photoItem) { item in
            guard let item else { return }
            photoItem = nil
            Task {
                // HEIC 等格式统一转 JPEG，保证 PWA 端也能显示
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: raw),
                   let jpeg = img.jpegData(compressionQuality: 0.85) {
                    let name = "IMG_\(Int(Date().timeIntervalSince1970)).jpg"
                    store.sendImage(data: jpeg, filename: name, caption: draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    draft = ""
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
                        if needsDivider(prev: prev, cur: msg) {
                            TimeDivider(date: msg.date)
                        }
                        MessageRow(msg: msg, store: store) { url in
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
                .padding(.top, 8)
                .padding(.bottom, 96) // 给悬浮输入卡片留出穿透空间
            }
            .scrollDismissesKeyboard(.interactively)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo("tail", anchor: .bottom)
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

    // MARK: 输入栏（悬浮透底，无实心背景）

    private var bottomFade: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground).opacity(0),
                     Color(.systemGroupedBackground).opacity(0.85)],
            startPoint: .top, endPoint: .bottom)
        .frame(height: 110)
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .bottom)
    }

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
            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 5)

                Button { showStickers = true } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 23))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 6)

                TextField("说点什么…", text: $draft, axis: .vertical)
                    .focused($inputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 0.8))

                Button {
                    let t = draft
                    draft = ""
                    store.sendText(t)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? .secondary.opacity(0.4) : .accentColor)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 6)
    }

    // MARK: 表情面板

    private var stickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(store.stickers) { stk in
                        Button {
                            showStickers = false
                            store.sendSticker(stk)
                        } label: {
                            AsyncImage(url: AlcoveAPI.stickerURL(stk.url)) { img in
                                img.resizable().scaledToFit()
                            } placeholder: {
                                Color(.tertiarySystemFill)
                            }
                            .frame(height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(12)
            }
            .navigationTitle("表情")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 单条消息

struct MessageRow: View {
    let msg: ChatMessage
    @ObservedObject var store: ChatStore
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
                    if !msg.text.isEmpty && !(msg.isSticker) {
                        bubble
                    }
                }
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
                    Text(Self.hm.string(from: msg.date))
                        .font(.system(size: 10))
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
            }
            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.vertical, 2)
    }

    private var bubble: some View {
        Text(msg.text)
            .font(.system(size: 16))
            .foregroundColor(msg.asleepAtSend ? .secondary : (isUser ? .white : .primary))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                isUser
                ? AnyShapeStyle(Color.accentColor.opacity(msg.asleepAtSend ? 0.35 : 1.0))
                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = msg.text
                } label: { Label("拷贝", systemImage: "doc.on.doc") }
            }
            .textSelection(.enabled)
    }

    private func thinkingBlock(_ think: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showThinking.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 10))
                    if let d = msg.thinkingDuration, d > 0 {
                        Text("想了 \(Int(d)) 秒")
                    } else {
                        Text("思绪")
                    }
                    Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            if showThinking {
                Text(think)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
    var body: some View {
        Text(Self.fmt.string(from: date))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
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
