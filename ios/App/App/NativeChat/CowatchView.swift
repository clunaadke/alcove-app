import SwiftUI
import AVFoundation
import UIKit

// 共影室（2026-08-25）。片单粘链接进来，后端把字幕、听写和画面网格备好；
// 播放页是一块能往上拉的布：一档看片、二档边看边聊、三档翻记录。
// 全屏不靠转手机，画面自己转过去铺满。

struct CowatchItem: Identifiable, Hashable {
    let id: String
    let source: String
    let url: String
    let title: String
    let uploader: String
    let duration: Int
    let status: String
    let transcriptFrom: String
    let cover: String
    let note: String
    let progress: Int

    init(_ row: [String: Any]) {
        id = row["id"] as? String ?? ""
        source = row["source"] as? String ?? ""
        url = row["url"] as? String ?? ""
        title = row["title"] as? String ?? ""
        uploader = row["uploader"] as? String ?? ""
        duration = row["duration"] as? Int ?? 0
        status = row["status"] as? String ?? ""
        transcriptFrom = row["transcript_from"] as? String ?? ""
        cover = row["cover"] as? String ?? ""
        note = row["note"] as? String ?? ""
        progress = row["progress"] as? Int ?? 0
    }

    var stateLine: String {
        switch status {
        case "ready": return transcriptFrom.isEmpty ? "没有台词" : "\(transcriptFrom)就绪"
        case "pending": return "正在听"
        case "failed": return note.isEmpty ? "没弄成" : note
        default: return status
        }
    }
    var lengthLine: String { CowatchClock.stamp(duration) }
}

enum CowatchClock {
    static func stamp(_ seconds: Int) -> String {
        let value = max(0, seconds)
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

// MARK: - 片单

struct NativeCowatchView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var items: [CowatchItem] = []
    @State private var link = ""
    @State private var importing = false
    @State private var hint: String?
    @State private var opened: CowatchItem?
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    TextField("粘一条 B站 / YouTube 链接", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13))
                        .padding(.horizontal, 13).frame(height: 40)
                        .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        Task { await importLink() }
                    } label: {
                        Text(importing ? "在处理" : "接进来")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 15).frame(height: 40)
                            .background(theme.fyAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(theme.fyAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(importing || link.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let hint {
                    Text(hint).font(.system(size: 12)).foregroundColor(theme.textDim)
                }

                if items.isEmpty {
                    Text("片单还空着。扔一条链接进来，字幕、听写和画面我先备好，然后我们一起看")
                        .font(.system(size: 13)).foregroundColor(theme.textDim)
                        .padding(.vertical, 22)
                } else {
                    ForEach(items) { item in
                        Button { if item.status == "ready" { opened = item } } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
        }
        .foregroundColor(theme.text)
        .task { await load() }
        .refreshable { await load() }
        .fullScreenCover(item: $opened) { item in
            CowatchPlayerView(item: item) { opened = nil }
        }
    }

    private func row(_ item: CowatchItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(theme.fyCardSub)
                if item.status == "pending" { ProgressView().scaleEffect(0.7) }
                else { Image(systemName: "film").font(.system(size: 15)).foregroundColor(theme.textDim) }
            }
            .frame(width: 74, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 13.5, weight: .medium))
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text("\(item.source) · \(item.uploader)")
                    .font(.system(size: 11)).foregroundColor(theme.textDim).lineLimit(1)
                HStack(spacing: 7) {
                    Text(item.lengthLine).font(.system(size: 10.5, design: .monospaced))
                    Text(item.stateLine).font(.system(size: 10.5))
                        .foregroundColor(item.status == "ready" ? theme.fyAccent : theme.textDim)
                        .lineLimit(1)
                }
                .foregroundColor(theme.textDim)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foyerCard(theme)
    }

    @MainActor private func load() async {
        guard let value = try? await NativeHouseAPI.object("/cowatch/list") else { return }
        items = (value["items"] as? [[String: Any]] ?? []).map(CowatchItem.init)
    }

    @MainActor private func importLink() async {
        let target = link.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        importing = true
        defer { importing = false }
        let reply = try? await NativeHouseAPI.objectIncludingHTTPError(
            "/cowatch/import", method: "POST", body: ["url": target])
        if let reply, reply["ok"] as? Bool == true {
            link = ""
            hint = "接住了，正在把台词和画面备出来"
            await load()
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await load()
        } else {
            hint = reply?["error"] as? String ?? "这条没接住"
        }
    }
}

// MARK: - 播放

struct CowatchPlayerView: View {
    let item: CowatchItem
    var onClose: () -> Void

    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var deck = CowatchDeck()
    @State private var gear = 0
    @State private var dragOffset: CGFloat = 0
    @State private var tab = 0
    @State private var draft = ""
    @State private var fullscreen = false
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private let gears: [CGFloat] = [0.74, 0.42, 0.10]

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let top = max(0.06, min(0.86, gears[gear] + dragOffset / height))

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                CowatchScreen(player: deck.player)
                    .frame(height: max(120, height * min(top + 0.02, 1)))
                    .clipped()
                    .ignoresSafeArea(edges: .top)

                topBar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                sheet(top: top, height: height)

                if fullscreen {
                    CowatchFullscreen(deck: deck, item: item, size: geo.size) { fullscreen = false }
                        .transition(.opacity)
                }
            }
        }
        .task { await deck.open(item: item) }
        .onDisappear { deck.close() }
        .statusBarHidden(true)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { deck.close(); onClose() } label: {
                Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.4), in: Circle())
            }.buttonStyle(.plain)

            HStack(spacing: 5) {
                Circle().fill(theme.fyAccent).frame(width: 5, height: 5)
                Text("同刻 \(CowatchClock.stamp(Int(deck.current)))")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(theme.fyAccent)
            .padding(.horizontal, 10).frame(height: 26)
            .background(Color.black.opacity(0.42), in: Capsule())

            Spacer()

            Button { withAnimation(.easeInOut(duration: 0.22)) { fullscreen = true } } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.4), in: Circle())
            }.buttonStyle(.plain)
        }
        .foregroundColor(.white)
    }

    private func sheet(top: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.26))
                .frame(width: 38, height: 4)
                .padding(.top, 10).padding(.bottom, 7)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = $0.translation.height }
                        .onEnded { value in
                            let landed = gears[gear] + value.translation.height / height
                            let nearest = gears.enumerated().min {
                                abs($0.element - landed) < abs($1.element - landed)
                            }?.offset ?? gear
                            dragOffset = 0
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { gear = nearest }
                        }
                )

            if gear == 0 {
                VStack(spacing: 7) {
                    Text(deck.currentLine.isEmpty ? "这一段没有台词" : deck.currentLine)
                        .font(.system(size: 13.5)).multilineTextAlignment(.center)
                    Text("▲ 往上拉，说说话")
                        .font(.system(size: 10.5, design: .monospaced)).foregroundColor(theme.textDim)
                }
                .padding(.horizontal, 18).padding(.bottom, 16)
                Spacer(minLength: 0)
            } else {
                Picker("", selection: $tab) {
                    Text("说话").tag(0)
                    Text("台词").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.bottom, 8)

                if tab == 0 { talkFlow } else { lyricFlow }

                composer
            }
        }
        .frame(maxWidth: .infinity)
        .background(theme.fyCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 18, y: -8)
        .frame(height: height * (1 - top) + 40)
        .offset(y: height * top)
        .foregroundColor(theme.text)
    }

    private var talkFlow: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(deck.said) { line in
                    VStack(alignment: line.mine ? .trailing : .leading, spacing: 3) {
                        Text(line.text).font(.system(size: 13.5))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(line.mine ? theme.fyAccent.opacity(0.16) : theme.fyCardSub,
                                        in: RoundedRectangle(cornerRadius: 13))
                        Button {
                            deck.seek(to: Double(line.ms) / 1000)
                        } label: {
                            Text(CowatchClock.stamp(line.ms / 1000))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(theme.fyAccent)
                        }.buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: line.mine ? .trailing : .leading)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private var lyricFlow: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(deck.lines) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Text(CowatchClock.stamp(line.t))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(line.t == deck.currentT ? theme.fyAccent : theme.textDim.opacity(0.5))
                            Text(line.text).font(.system(size: 13.5))
                                .foregroundColor(line.t <= Int(deck.current) ? theme.text : theme.textDim.opacity(0.35))
                        }
                        .id(line.id)
                        .contentShape(Rectangle())
                        .onTapGesture { deck.seek(to: Double(line.t)) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .onChange(of: deck.currentT) { value in
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(value, anchor: .center) }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 9) {
            TextField("说点什么，会钉在 \(CowatchClock.stamp(Int(deck.current)))", text: $draft)
                .font(.system(size: 13))
                .padding(.horizontal, 13).frame(height: 34)
                .background(theme.fyCardSub, in: Capsule())
            Button {
                let text = draft
                draft = ""
                Task { await deck.say(text) }
            } label: {
                Image(systemName: "arrow.up").font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(theme.fyAccent.opacity(0.16), in: Circle())
                    .foregroundColor(theme.fyAccent)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14).padding(.top, 9).padding(.bottom, 18)
    }
}

// MARK: - 全屏（手机不用转，画面自己转）

private struct CowatchFullscreen: View {
    @ObservedObject var deck: CowatchDeck
    let item: CowatchItem
    let size: CGSize
    var onExit: () -> Void

    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var showChat = false
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ZStack(alignment: .bottom) {
                CowatchScreen(player: deck.player)

                if !deck.currentLine.isEmpty {
                    Text(deck.currentLine)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.9), radius: 4, y: 1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30).padding(.bottom, 46)
                }

                deckBar
            }
            .frame(width: size.height, height: size.width)
            .overlay(alignment: .trailing) {
                if showChat { chatWing.frame(width: 216) }
            }
            .rotationEffect(.degrees(90))
        }
        .ignoresSafeArea()
    }

    private var deckBar: some View {
        HStack(spacing: 7) {
            pill("双语字幕") {}
            pill("问这一幕", lamp: true) { Task { await deck.askThisMoment() } }
            Spacer()
            pill(showChat ? "收起" : "说话") { withAnimation(.easeInOut(duration: 0.24)) { showChat.toggle() } }
            pill("退出全屏") { onExit() }
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
    }

    private func pill(_ title: String, lamp: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(lamp ? theme.fyAccent : .white.opacity(0.85))
                .padding(.horizontal, 11).frame(height: 27)
                .background(Color.black.opacity(0.42), in: Capsule())
                .overlay(Capsule().stroke(lamp ? theme.fyAccent.opacity(0.4) : Color.white.opacity(0.18), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var chatWing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(deck.said) { line in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.text).font(.system(size: 11.5))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(line.mine ? 0.14 : 0.08),
                                        in: RoundedRectangle(cornerRadius: 11))
                        Text(CowatchClock.stamp(line.ms / 1000))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(theme.fyAccent)
                    }
                }
            }
            .padding(12)
        }
        .foregroundColor(.white)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 播放器与数据

final class CowatchDeck: ObservableObject {
    @Published var current: Double = 0
    @Published var lines: [CowatchLine] = []
    @Published var said: [CowatchSaid] = []

    let player = AVPlayer()
    private var observer: Any?
    private var videoID = ""

    var currentT: Int { lines.last(where: { $0.t <= Int(current) })?.t ?? -1 }
    var currentLine: String { lines.last(where: { $0.t <= Int(current) })?.text ?? "" }

    @MainActor func open(item: CowatchItem) async {
        videoID = item.id
        let asset = AVURLAsset(url: AlcoveAPI.fullURL("/cowatch/stream/\(item.id)"))
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        if item.progress > 3 { seek(to: Double(item.progress)) }
        player.play()
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            self?.current = time.seconds.isFinite ? time.seconds : 0
        }
        if let value = try? await NativeHouseAPI.object("/cowatch/video?id=\(item.id)") {
            lines = (value["transcript"] as? [[String: Any]] ?? []).map(CowatchLine.init)
        }
        await loadSaid()
    }

    @MainActor func loadSaid() async {
        guard let value = try? await NativeHouseAPI.object("/cowatch/danmaku?id=\(videoID)") else { return }
        said = (value["items"] as? [[String: Any]] ?? []).map(CowatchSaid.init)
    }

    @MainActor func say(_ text: String) async {
        let body = text.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        _ = try? await NativeHouseAPI.request(
            "/cowatch/say", method: "POST",
            body: ["id": videoID, "ms": Int(current * 1000), "text": body, "actor": "陈霁"])
        await loadSaid()
    }

    @MainActor func askThisMoment() async {
        _ = try? await NativeHouseAPI.request(
            "/cowatch/moment", method: "POST",
            body: ["id": videoID, "at": Int(current)])
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func close() {
        if let observer { player.removeTimeObserver(observer) }
        observer = nil
        let seconds = Int(current)
        let id = videoID
        player.pause()
        player.replaceCurrentItem(with: nil)
        guard !id.isEmpty else { return }
        Task {
            _ = try? await NativeHouseAPI.request(
                "/cowatch/progress", method: "POST", body: ["id": id, "seconds": seconds])
        }
    }
}

struct CowatchLine: Identifiable, Hashable {
    let t: Int
    let text: String
    var id: Int { t }
    init(_ row: [String: Any]) {
        t = row["t"] as? Int ?? 0
        text = row["text"] as? String ?? ""
    }
}

struct CowatchSaid: Identifiable, Hashable {
    let ms: Int
    let actor: String
    let text: String
    let created: String
    var id: String { "\(ms)-\(created)" }
    var mine: Bool { actor == "陈霁" }
    init(_ row: [String: Any]) {
        ms = row["ms"] as? Int ?? 0
        actor = row["actor"] as? String ?? ""
        text = row["text"] as? String ?? ""
        created = row["created"] as? String ?? ""
    }
}

private struct CowatchScreen: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> CowatchScreenHost { CowatchScreenHost(player: player) }
    func updateUIView(_ view: CowatchScreenHost, context: Context) { view.attach(player) }
}

final class CowatchScreenHost: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(player: AVPlayer) {
        super.init(frame: .zero)
        backgroundColor = .black
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func attach(_ player: AVPlayer) {
        if playerLayer.player !== player { playerLayer.player = player }
    }
}
