import SwiftUI
import AVFoundation

// 旅行卡片（journey cards，2026-08-18 她点的第一版）
//
// 我挑一个地方、选 6 处停留、每处一张竖屏照片和一段写给她的话，
// 在聊天里落成一张卡；点开是全屏的照片故事：照片铺满、地名在顶、
// 念白一句句打出来然后落到左下角、底部圆点、左右滑走到下一处。
//
// 数据契约照 nonchaiovo/journey-cards 的 SPEC（MIT，出处
// https://github.com/nonchaiovo/journey-cards），渲染全是原生的。
// 那份参考实现是单文件 HTML，它踩过的坑里有一半是 Web 独有的
// （<audio>.volume 在 iOS 上静默无效、跨域音频静音、fixed 被祖先
// transform 关进笼子），原生不得这些病；剩下真正通用的几条，
// 下面每一条都在它该在的位置写了注释。

// MARK: - 数据

struct JourneyAudio: Equatable {
    var url: String
    var title: String
    var artist: String
    var dur: Double
    var hue: Double

    init?(_ raw: [String: Any]?) {
        guard let raw, let url = raw["url"] as? String, !url.isEmpty else { return nil }
        self.url = url
        self.title = raw["title"] as? String ?? ""
        self.artist = raw["artist"] as? String ?? "—"
        self.dur = (raw["dur"] as? NSNumber)?.doubleValue ?? 0
        self.hue = (raw["hue"] as? NSNumber)?.doubleValue ?? 32
    }
}

struct JourneyStop: Identifiable, Equatable {
    let id: String
    var place: String
    var placeEn: String
    var date: String
    var src: String
    var note: String

    init(_ raw: [String: Any]) {
        id = raw["id"] as? String ?? UUID().uuidString
        place = raw["place"] as? String ?? ""
        placeEn = raw["placeEn"] as? String ?? ""
        date = raw["date"] as? String ?? ""
        src = raw["src"] as? String ?? ""
        note = raw["note"] as? String ?? ""
    }

    var photoURL: URL? { src.isEmpty ? nil : AlcoveAPI.fullURL(src) }
}

struct Journey: Identifiable, Equatable {
    let id: String
    var title: String
    var titleEn: String
    var year: String
    var hint: String
    var caption: String
    var cover: String
    var audio: JourneyAudio?
    var stops: [JourneyStop]

    init(_ raw: [String: Any]) {
        id = raw["id"] as? String ?? ""
        title = raw["title"] as? String ?? ""
        titleEn = raw["titleEn"] as? String ?? ""
        year = raw["year"] as? String ?? ""
        hint = raw["hint"] as? String ?? ""
        caption = raw["caption"] as? String ?? ""
        cover = raw["cover"] as? String ?? ""
        audio = JourneyAudio(raw["audio"] as? [String: Any])
        stops = (raw["stops"] as? [[String: Any]] ?? []).map(JourneyStop.init)
    }

    var coverURL: URL? {
        let raw = cover.isEmpty ? (stops.first?.src ?? "") : cover
        return raw.isEmpty ? nil : AlcoveAPI.fullURL(raw)
    }
}

/// 一条消息只带一个 id，正文里的标签是
/// `[JOURNEY_CARD]{"id":"j_…"}[/JOURNEY_CARD]`，跟家里其他卡一个格式。
struct JourneyCardRef: Equatable {
    let id: String
}

// MARK: - 取数

@MainActor
final class JourneyStore: ObservableObject {
    static let shared = JourneyStore()

    @Published private(set) var cache: [String: Journey] = [:]
    private var inflight: Set<String> = []

    func journey(_ id: String) -> Journey? { cache[id] }

    /// 同一趟在聊天流里可能被反复渲染（滚动复用），拿到就缓存，
    /// 在途的重复请求直接丢掉，不要每次出现在屏幕上都打一发。
    func load(_ id: String) {
        guard cache[id] == nil, !inflight.contains(id) else { return }
        inflight.insert(id)
        Task { [weak self] in
            defer { self?.inflight.remove(id) }
            guard let obj = try? await NativeHouseAPI.object("/api/journeys/\(id)"),
                  let raw = obj["journey"] as? [String: Any] else { return }
            self?.cache[id] = Journey(raw)
        }
    }
}

// MARK: - 聊天页里的入口卡

struct JourneyMessageCard: View {
    let ref: JourneyCardRef
    let theme: AlcoveTheme
    @ObservedObject private var store = JourneyStore.shared
    @State private var open = false
    @State private var startIndex = 0

    private var journey: Journey? { store.journey(ref.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let journey, !journey.caption.isEmpty {
                // 卡片上面那行斜体小字：我自己写的一句，不是模板。
                Text(journey.caption)
                    .font(.system(size: 12.5, design: .serif)).italic()
                    .foregroundColor(theme.textDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
            }
            card
        }
        .frame(maxWidth: 330, alignment: .leading)
        .onAppear { store.load(ref.id) }
        .fullScreenCover(isPresented: $open) {
            if let journey {
                JourneyStoryView(journey: journey, startIndex: startIndex)
            }
        }
    }

    @ViewBuilder private var card: some View {
        VStack(spacing: 0) {
            if let journey {
                head(journey)
                JourneyPhotoRail(stops: journey.stops) { index in
                    startIndex = index
                    open = true
                }
                .padding(.top, 14)
                Text(journey.hint.isEmpty ? "路走完了，人没走。" : journey.hint)
                    .font(.system(size: 12.5, design: .serif)).italic()
                    .foregroundColor(theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
            } else {
                loading
            }
        }
        .background(theme.fyCard.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(theme.fyBorder.opacity(0.7), lineWidth: 0.7))
        // 放大那张要顶出卡片、还要被左边缘切掉半张 —— SwiftUI 的 ScrollView
        // 默认把超出的内容裁干净，不关掉裁剪，这张卡就成了规规矩矩的图标栏。
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func head(_ journey: Journey) -> some View {
        VStack(spacing: 6) {
            Text("JOURNEYS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(3.4)
                .foregroundColor(theme.fyAccent)
            Text("陈璟带你去了\(journey.title)")
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
            Text(subtitle(journey))
                .font(.system(size: 11.5, design: .serif))
                .tracking(1.2)
                .foregroundColor(theme.textDim)
        }
        .padding(.top, 18)
        .padding(.horizontal, 16)
    }

    private func subtitle(_ journey: Journey) -> String {
        var parts: [String] = []
        if !journey.year.isEmpty { parts.append(journey.year) }
        parts.append("\(journey.stops.count) 处停留")
        return parts.joined(separator: " · ")
    }

    private var loading: some View {
        VStack(spacing: 10) {
            ProgressView().tint(theme.fyAccent)
            Text("正在把那趟路取回来…")
                .font(.system(size: 11, design: .serif))
                .foregroundColor(theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
    }
}

/// 一排竖条照片。参考实现里那套磁力放大只给真鼠标开（触屏没有 hover），
/// 但作者自己 app 的真机截图上手机端是有放大的 —— 所以这里改成滚动位置驱动：
/// 排在最前面的那张长大、露出地名，后一张次之，再后面是窄条。
/// 放大那张**故意顶出卡片、被左边缘切掉半张**，暗示"还有更多"，这是要的效果。
private struct JourneyPhotoRail: View {
    let stops: [JourneyStop]
    var onPick: (Int) -> Void

    // 这几个数是一组的，改一个要回头看别的：
    // 静止 44 宽 / 放大 118 宽，容器高度必须 ≥ 放大高度 + 上下留白。
    // 卡到正好就是白放大 —— 高度涨不出去，只剩宽度在变，看着像原地鼓了一下。
    private let restW: CGFloat = 44
    private let midW: CGFloat = 72
    private let liftW: CGFloat = 118
    private let restH: CGFloat = 176
    private let midH: CGFloat = 214
    private let liftH: CGFloat = 262
    private let gap: CGFloat = 8

    @State private var leading: String?

    private var leadIndex: Int {
        stops.firstIndex { $0.id == leading } ?? 0
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: gap) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    bar(stop, tier: tier(for: index))
                        .id(stop.id)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .scrollTargetLayout()
        }
        .frame(height: liftH + 18)
        .scrollPosition(id: $leading, anchor: .leading)
        // SwiftUI 的 ScrollView 默认把超出边界的内容裁干净。不关掉裁剪，
        // 那张放大的既顶不出卡片、也不会被左边缘切半张，效果直接废掉。
        .scrollClipDisabled()
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: leadIndex)
    }

    /// 0 = 最前面那张（放大），1 = 紧跟着的那张（中号），2 = 其余窄条
    private func tier(for index: Int) -> Int {
        let lead = leadIndex
        if index == lead { return 0 }
        if index == lead + 1 { return 1 }
        return 2
    }

    private func bar(_ stop: JourneyStop, tier: Int) -> some View {
        let w = tier == 0 ? liftW : (tier == 1 ? midW : restW)
        let h = tier == 0 ? liftH : (tier == 1 ? midH : restH)
        return Button { onPick(stops.firstIndex { $0.id == stop.id } ?? 0) } label: {
            ZStack(alignment: .bottomLeading) {
                JourneyPhoto(url: stop.photoURL)
                if tier == 0 {
                    LinearGradient(colors: [.clear, .black.opacity(0.6)],
                                   startPoint: .center, endPoint: .bottom)
                    Text(stop.place)
                        .font(.system(size: 12.5, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                        .padding(.leading, 10)
                        .padding(.bottom, 10)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            // 放大不只是变大 —— 影子同时做深做远，眼睛才认得出"它离我更近了"。
            .shadow(color: .black.opacity(tier == 0 ? 0.38 : 0.16),
                    radius: tier == 0 ? 22 : 8, x: 0, y: tier == 0 ? 14 : 5)
        }
        .buttonStyle(.plain)
        .zIndex(tier == 0 ? 2 : (tier == 1 ? 1 : 0))
    }
}

private struct JourneyPhoto: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.18))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle().fill(Color.black.opacity(0.18))
            }
        }
    }
}

// MARK: - 全屏故事

struct JourneyStoryView: View {
    let journey: Journey
    var startIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @StateObject private var music = JourneyMusic()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(journey.stops.enumerated()), id: \.element.id) { i, stop in
                    JourneyStopPage(stop: stop, active: i == index) { narrating in
                        Task { @MainActor in music.duck(narrating) }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottom
            }
        }
        .statusBarHidden(true)
        .onAppear {
            index = min(max(startIndex, 0), max(journey.stops.count - 1, 0))
            if let audio = journey.audio { music.start(audio) }
        }
        .onDisappear { music.stop() }   // 关掉之后歌还在响是最丢人的 bug
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(10)
                    .background(.black.opacity(0.28), in: Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var bottom: some View {
        VStack(spacing: 14) {
            if journey.audio != nil {
                JourneyPlayerBar(music: music, hue: journey.audio?.hue ?? 32)
            }
            HStack(spacing: 7) {
                ForEach(journey.stops.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Color.white : Color.white.opacity(0.36))
                        .frame(width: i == index ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.22), value: index)
                        .onTapGesture { index = i }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }
}

private struct JourneyStopPage: View {
    let stop: JourneyStop
    let active: Bool
    var onNarrating: (Bool) -> Void

    @State private var zoom: CGFloat = 1.04
    @State private var typed = ""
    @State private var settled = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                photo(geo)
                scrims
                caption
                narration(geo)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        // 每一处就是一次完整的生命周期：换页重开打字机，离开自动取消。
        // .task(id:) 帮我们做了参考实现里那套 session.dead + clearTimers。
        .task(id: taskKey) {
            guard active else { return }
            await runNarration()
        }
    }

    private var taskKey: String { "\(stop.id)-\(active)" }

    private func photo(_ geo: GeometryProxy) -> some View {
        AsyncImage(url: stop.photoURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Color.black
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
        // Ken Burns。要放大，图就得先有富余可放：
        // 备图按「屏幕物理尺寸 × 这里的最大 scale」算（1290×2796 × 1.16 ≈ 1500×3250），
        // 否则就是把已经 1:1 的像素往上插值，越推越糊。
        .scaleEffect(zoom)
        .animation(.linear(duration: 20), value: zoom)
        .onAppear { zoom = active ? 1.16 : 1.04 }
        .onChange(of: active) { _, now in zoom = now ? 1.16 : 1.04 }
    }

    private var scrims: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.42), .clear],
                           startPoint: .top, endPoint: .center)
            LinearGradient(colors: [.clear, .black.opacity(0.55)],
                           startPoint: .center, endPoint: .bottom)
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(stop.place)
                .font(.system(size: 27, weight: .semibold, design: .serif))
                .foregroundColor(.white)
            if !stop.placeEn.isEmpty {
                Text(stop.placeEn.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2.4)
                    .foregroundColor(.white.opacity(0.78))
            }
            if !stop.date.isEmpty {
                Text(stop.date)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .journeyTextShadow()
        .padding(.horizontal, 24)
        .padding(.top, 62)
    }

    private func narration(_ geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            if settled {
                // 念完落到左下角，长文能滚，滚到底不要把滚动传给背后的页面。
                ScrollView {
                    Text(stop.note)
                        .font(.system(size: 14.5, design: .serif))
                        .lineSpacing(6)
                        .foregroundColor(.white)
                        .journeyTextShadow()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: geo.size.height * 0.3)
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
                .transition(.opacity)
            } else {
                Text(typed)
                    .font(.system(size: 19, design: .serif))
                    .lineSpacing(19)                 // 行距 ≥ 两倍字号，光晕才叠不起来
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .journeyTextShadow()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 26)
                Spacer()
            }
        }
    }

    private func runNarration() async {
        typed = ""
        settled = false
        onNarrating(true)
        defer { onNarrating(false) }
        for sentence in Self.split(stop.note) {
            for character in sentence {
                if Task.isCancelled { return }
                typed.append(character)
                try? await Task.sleep(nanoseconds: 52_000_000)
            }
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 420_000_000)   // 句与句之间换口气
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        if Task.isCancelled { return }
        withAnimation(.easeInOut(duration: 0.45)) { settled = true }
    }

    /// 按句号一类的终止符断句，标点跟着上一句走。
    static func split(_ text: String) -> [String] {
        var out: [String] = []
        var buffer = ""
        for character in text {
            buffer.append(character)
            if "。！？!?…\n".contains(character) {
                let piece = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { out.append(piece) }
                buffer = ""
            }
        }
        let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out.isEmpty ? [text] : out
    }
}

private extension View {
    /// 贴字的紧阴影。别加模糊半径去抗亮底 —— 模糊一旦超过行距的一半，
    /// 上下行的阴影会连成一片，看起来像正文底下垫了一块灰板，
    /// 而 DOM/图层里根本找不到那块「背景」。要更抗亮就加不透明度。
    func journeyTextShadow() -> some View {
        self.shadow(color: .black.opacity(0.9), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.45), radius: 5)
    }
}

// MARK: - 整趟一首歌

@MainActor
final class JourneyMusic: ObservableObject {
    @Published var playing = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    private var player: AVPlayer?
    private var observer: Any?
    private var fade: Task<Void, Never>?

    func start(_ audio: JourneyAudio) {
        let url = AlcoveAPI.fullURL(audio.url)
        duration = audio.dur                    // 加载完之前先用数据里的时长占位
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let player = AVPlayer(url: url)
        player.volume = 1
        self.player = player
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.4, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, let item = self.player?.currentItem else { return }
                let seconds = item.duration.seconds
                if seconds.isFinite, seconds > 0 { self.duration = seconds }
                self.progress = time.seconds
                self.playing = self.player?.timeControlStatus == .playing
            }
        }
        player.play()
        playing = true
    }

    func toggle() {
        guard let player else { return }
        if playing { player.pause() } else { player.play() }
        playing.toggle()
    }

    func seek(_ seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        progress = seconds
    }

    /// 念白开口把音乐压到 0.3，念完拉回 1.0，全程不停只是变小。
    /// 一刀切下去会有可闻的咔哒声，所以分几步在 0.12 秒里过渡。
    func duck(_ narrating: Bool) {
        fade?.cancel()
        let target: Float = narrating ? 0.3 : 1.0
        fade = Task { [weak self] in
            guard let self, let player = self.player else { return }
            let from = player.volume
            let steps = 8
            for step in 1...steps {
                if Task.isCancelled { return }
                player.volume = from + (target - from) * Float(step) / Float(steps)
                try? await Task.sleep(nanoseconds: 15_000_000)
            }
        }
    }

    func stop() {
        fade?.cancel()
        if let observer { player?.removeTimeObserver(observer) }
        observer = nil
        player?.pause()
        player = nil
        playing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private struct JourneyPlayerBar: View {
    @ObservedObject var music: JourneyMusic
    let hue: Double

    private var accent: Color {
        // 每趟旅行的播放器颜色跟着数据里的 hue 走，气质不一样。
        Color(hue: hue / 360, saturation: 0.42, brightness: 0.88)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { music.toggle() } label: {
                Image(systemName: music.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(accent, in: Circle())
            }
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule().fill(accent)
                            .frame(width: geo.size.width * ratio)
                    }
                    // 3px 的线手指点不中，撑出 25px 热区再收回去。
                    .frame(height: 3)
                    .frame(height: 25)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                        guard music.duration > 0 else { return }
                        let r = max(0, min(1, value.location.x / geo.size.width))
                        music.seek(r * music.duration)
                    })
                }
                .frame(height: 25)
                HStack {
                    Text(Self.time(music.progress))
                    Spacer()
                    Text(Self.time(music.duration))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.66))
            }
        }
        .padding(.horizontal, 4)
    }

    private var ratio: CGFloat {
        guard music.duration > 0 else { return 0 }
        return CGFloat(max(0, min(1, music.progress / music.duration)))
    }

    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
