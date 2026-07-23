import SwiftUI
import PhotosUI
import AVFoundation
import WebKit

enum HouseDestination: String, Identifiable, CaseIterable {
    case sidebar, chat, terminal, settings, checklist, music
    case home, calendar, sex, usage
    case memory, dreams, shelf, desire, nianlun, clockwork, album, portrait, impression
    case crosstalk, radio, coread, liao, daddyDay
    case search, favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sidebar: return "Alcove"
        case .home: return "大厅"
        case .chat: return "Chat"
        case .terminal: return "Terminal"
        case .settings: return "设置"
        case .checklist: return "Checklist"
        case .music: return "Music"
        case .calendar: return "Calendar"
        case .sex: return "Sex"
        case .usage: return "Usage"
        case .memory: return "Memory"
        case .dreams: return "Dreams"
        case .shelf: return "渡鸦的架子"
        case .desire: return "Desire"
        case .nianlun: return "年轮"
        case .clockwork: return "发条"
        case .album: return "相册"
        case .portrait: return "Portrait"
        case .impression: return "Impression"
        case .crosstalk: return "Crosstalk"
        case .radio: return "Radio"
        case .coread: return "共读"
        case .liao: return "燎"
        case .daddyDay: return "Daddy的一天"
        case .search: return "Search"
        case .favorites: return "Favorites"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .chat: return "bubble.left"
        case .terminal: return "terminal"
        case .settings: return "gearshape"
        case .checklist: return "checklist"
        case .music: return "music.note"
        case .calendar, .impression: return "calendar"
        case .sex, .desire: return "heart"
        case .usage: return "chart.bar"
        case .memory: return "brain.head.profile"
        case .dreams: return "moon.stars"
        case .shelf: return "bird"
        case .nianlun: return "circle.hexagongrid"
        case .clockwork: return "clock.arrow.circlepath"
        case .album: return "photo.on.rectangle"
        case .portrait: return "person.crop.circle"
        case .crosstalk: return "play.circle"
        case .radio: return "radio"
        case .coread: return "book"
        case .liao: return "flame"
        case .daddyDay: return "clock"
        case .search: return "magnifyingglass"
        case .favorites: return "bookmark"
        default: return "sparkles"
        }
    }
}

struct NativeHouseSheet: View {
    let initial: HouseDestination
    var showTerminal: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var route: HouseDestination
    @AppStorage("alcoveTheme") private var themeName = "haven"

    init(initial: HouseDestination, showTerminal: @escaping () -> Void) {
        self.initial = initial
        self.showTerminal = showTerminal
        _route = State(initialValue: initial)
    }

    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        ZStack {
            HouseBackground(theme: theme)
            Group {
                switch route {
                case .sidebar:
                    NativeSidebarView(select: select)
                case .settings:
                    NativeSettingsView(showPermissions: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            NotificationCenter.default.post(name: .alcoveShowPermissions, object: nil)
                        }
                    })
                case .crosstalk, .coread, .liao:
                    NativePlayView(destination: route)
                default:
                    WebHouseView(destination: route)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if route != .sidebar {
                Button { route = .sidebar } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textDim)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(theme.glassBorder, lineWidth: 1))
                }
                .padding(.leading, 14)
                .padding(.top, 8)
            }
        }
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .presentationDetents([.fraction(0.86)])
        .presentationDragIndicator(.visible)
    }

    private func select(_ target: HouseDestination) {
        switch target {
        case .chat:
            dismiss()
        case .terminal:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) { showTerminal() }
            }
        default:
            withAnimation(.easeInOut(duration: 0.18)) { route = target }
        }
    }
}

private struct HouseBackground: View {
    let theme: AlcoveTheme
    var body: some View {
        Group {
            if theme.isDark {
                LinearGradient(colors: theme.splashBg, startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 253/255, green: 250/255, blue: 251/255),
                        Color(red: 248/255, green: 239/255, blue: 243/255)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
    }
}

private struct NativeSidebarView: View {
    var select: (HouseDestination) -> Void
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var model = SidebarModel()
    private var theme: AlcoveTheme { .named(themeName) }

    private let foyer: [HouseDestination] = [
        .memory, .dreams, .shelf, .desire, .nianlun, .clockwork, .album, .portrait, .impression
    ]
    private let play: [HouseDestination] = [.crosstalk, .coread, .liao]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                VStack(spacing: 1) {
                    Text("Alcove")
                        .font(.system(size: 21, weight: .medium, design: .serif))
                        .tracking(1.4)
                    Text("壁 龛")
                        .font(.system(size: 9))
                        .tracking(3)
                        .foregroundColor(theme.textDim)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    summaryCard("大厅", model.homeLine, "house", .home)
                    summaryCard("在一起", "\(model.days) days", "heart", .calendar)
                }
                HStack(spacing: 10) {
                    summaryCard("Sex", model.sexLine, "heart.fill", .sex)
                    summaryCard("Usage", model.usageLine, "chart.bar", .usage)
                }

                destinationRow([.chat, .terminal, .settings])
                sectionTitle("Foyer")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(foyer) { destinationButton($0) }
                }
                sectionTitle("Play")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(play) { destinationButton($0) }
                }
                sectionTitle("Chat")
                destinationRow([.search, .favorites])
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .foregroundColor(theme.text)
        }
        .task { await model.load() }
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(theme.textLight)
            Rectangle().fill(theme.glassBorder).frame(height: 1)
        }
        .padding(.top, 2)
    }

    private func summaryCard(
        _ title: String, _ subtitle: String, _ icon: String, _ target: HouseDestination
    ) -> some View {
        Button { select(target) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundColor(theme.sendBottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.system(size: 10)).foregroundColor(theme.textDim)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .houseGlass(theme)
        }
        .buttonStyle(.plain)
    }

    private func destinationRow(_ items: [HouseDestination]) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { destinationButton($0) }
        }
    }

    private func destinationButton(_ target: HouseDestination) -> some View {
        Button { select(target) } label: {
            VStack(spacing: 6) {
                Image(systemName: target.icon)
                    .font(.system(size: 18, weight: .light))
                Text(target.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(theme.textDim)
            .frame(maxWidth: .infinity, minHeight: 61)
            .houseGlass(theme)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class SidebarModel: ObservableObject {
    @Published var homeLine = "亲密度 --"
    @Published var sexLine = "--"
    @Published var usageLine = "--"
    let days = max(1, Calendar.current.dateComponents(
        [.day], from: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_272_000)),
        to: Calendar.current.startOfDay(for: Date())).day ?? 1)

    func load() async {
        async let doll = try? NativeHouseAPI.object("/api/dollhouse/state")
        async let sex = try? NativeHouseAPI.object("/api/sex/entries")
        async let usage = try? NativeHouseAPI.object("/api/usage")
        if let d = await doll { homeLine = "亲密度 \(d.int("intimacy")) · 金币 \(d.int("coins"))" }
        if let s = await sex { sexLine = "\((s["entries"] as? [Any])?.count ?? 0) 次" }
        if let u = await usage {
            let five = u.object("rate_limits").object("five_hour").int("used_percent")
            let seven = u.object("rate_limits").object("seven_day").int("used_percent")
            usageLine = "5h \(five)% · 7d \(seven)%"
        }
    }
}

private struct NativeSettingsView: View {
    var showPermissions: () -> Void
    @AppStorage("assistantName") private var assistantName = "陈璟"
    @AppStorage("userName") private var userName = "Luna"
    @AppStorage("assistantAvatarDataURL") private var assistantAvatar = ""
    @AppStorage("userAvatarDataURL") private var userAvatar = ""
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("chatFontSize") private var fontSize = 15
    @AppStorage("wallStamp") private var wallStamp = 0.0
    @State private var aiPhoto: PhotosPickerItem?
    @State private var userPhoto: PhotosPickerItem?
    @State private var wallPhoto: PhotosPickerItem?
    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                panelTitle("设置")
                section("聊天") {
                    settingRow("字体大小", "调整气泡文字大小") {
                        Picker("", selection: $fontSize) {
                            Text("小").tag(13); Text("中").tag(15); Text("大").tag(17)
                        }
                        .pickerStyle(.segmented).frame(width: 145)
                    }
                    Divider().opacity(0.25)
                    settingRow("我的名字", "聊天气泡和推送显示") {
                        TextField("Luna", text: $userName).multilineTextAlignment(.trailing).frame(width: 105)
                    }
                    Divider().opacity(0.25)
                    settingRow("TA 的名字", "聊天页顶栏显示") {
                        TextField("陈璟", text: $assistantName).multilineTextAlignment(.trailing).frame(width: 105)
                    }
                    Divider().opacity(0.25)
                    settingRow("我的头像", "点击更换") {
                        PhotosPicker(selection: $userPhoto, matching: .images) {
                            avatar(dataURL: userAvatar, fallback: "L")
                        }
                    }
                    Divider().opacity(0.25)
                    settingRow("\(assistantName) 头像", "点击更换") {
                        PhotosPicker(selection: $aiPhoto, matching: .images) {
                            avatar(dataURL: assistantAvatar, fallback: "R")
                        }
                    }
                }
                section("主题") {
                    HStack(spacing: 10) {
                        themeChoice("Haven", "暖白 · 家", "haven", [.white, .pink.opacity(0.45), .gray])
                        themeChoice("Midnight", "深夜 · 黑", "midnight", [.black, .gray.opacity(0.7), .gray])
                    }
                }
                section("聊天壁纸") {
                    HStack {
                        PhotosPicker(selection: $wallPhoto, matching: .images) {
                            Label("从相册更换", systemImage: "photo")
                        }
                        Spacer()
                        Button("恢复默认") { resetWallpaper() }
                    }
                    .font(.system(size: 13))
                }
                section("App") {
                    Button(action: showPermissions) {
                        settingRow("系统权限", "位置、日历、运动、麦克风等权限") {
                            Image(systemName: "chevron.right").foregroundColor(theme.textLight)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .foregroundColor(theme.text)
        }
        .onChange(of: userPhoto) { item in loadDataURL(item, into: $userAvatar) }
        .onChange(of: aiPhoto) { item in loadDataURL(item, into: $assistantAvatar) }
        .onChange(of: wallPhoto) { item in saveWallpaper(item) }
    }

    private func panelTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 17, weight: .semibold)).padding(.top, 11)
    }

    @ViewBuilder private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold))
                .tracking(1.8).foregroundColor(theme.textLight)
            VStack(spacing: 10) { content() }
                .padding(13).houseGlass(theme)
        }
    }

    private func settingRow<Trailing: View>(
        _ title: String, _ desc: String, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14))
                Text(desc).font(.system(size: 11)).foregroundColor(theme.textLight)
            }
            Spacer()
            trailing()
        }
    }

    private func themeChoice(
        _ title: String, _ sub: String, _ value: String, _ colors: [Color]
    ) -> some View {
        Button { themeName = value } label: {
            VStack(spacing: 7) {
                HStack(spacing: 4) {
                    ForEach(colors.indices, id: \.self) { i in
                        Circle().fill(colors[i]).frame(width: 13, height: 13)
                    }
                }
                Text(title).font(.system(size: 13, weight: .medium))
                Text(sub).font(.system(size: 10)).foregroundColor(theme.textLight)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(themeName == value ? theme.sendBottom : theme.glassBorder, lineWidth: 1.4))
        }
        .buttonStyle(.plain)
    }

    private func avatar(dataURL: String, fallback: String) -> some View {
        Group {
            if let image = Self.image(dataURL) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(fallback).font(.system(size: 13, design: .serif))
            }
        }
        .frame(width: 38, height: 38)
        .background(theme.glassTint)
        .clipShape(Circle())
    }

    private static func image(_ value: String) -> UIImage? {
        let payload = value.split(separator: ",", maxSplits: 1).last.map(String.init) ?? value
        return Data(base64Encoded: payload).flatMap(UIImage.init(data:))
    }

    private func loadDataURL(_ item: PhotosPickerItem?, into binding: Binding<String>) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.82) else { return }
            binding.wrappedValue = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        }
    }

    private func saveWallpaper(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.9) else { return }
            let file = themeName == "midnight" ? "chatwall_midnight.jpg" : "chatwall_haven.jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(file)
            try? jpeg.write(to: url, options: .atomic)
            wallStamp = Date().timeIntervalSince1970
        }
    }

    private func resetWallpaper() {
        let file = themeName == "midnight" ? "chatwall_midnight.jpg" : "chatwall_haven.jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(file)
        try? FileManager.default.removeItem(at: url)
        wallStamp = Date().timeIntervalSince1970
    }
}

private struct ChecklistItem: Identifiable {
    let id: String
    let body: String
    let done: Bool
    let isFixed: Bool
    let triggerAt: String
    init(_ json: [String: Any]) {
        id = json.string("id")
        body = json.string("body", "text", "title")
        done = json.bool("done")
        isFixed = json.bool("is_fixed")
        triggerAt = json.string("trigger_at", "at")
    }
}

@MainActor
private final class ChecklistModel: ObservableObject {
    @Published var items: [ChecklistItem] = []
    @Published var loading = false
    @Published var error = ""

    func load() async {
        loading = true
        defer { loading = false }
        do {
            let value = try await NativeHouseAPI.request("/api/checklist")
            let raw = value as? [[String: Any]]
                ?? (value as? [String: Any])?["items"] as? [[String: Any]] ?? []
            items = raw.map(ChecklistItem.init)
            error = ""
        } catch { self.error = "清单暂时够不着" }
    }

    func toggle(_ item: ChecklistItem) async {
        try? await NativeHouseAPI.post("/api/checklist/\(item.id)/toggle")
        await load()
    }

    func delete(_ item: ChecklistItem) async {
        try? await NativeHouseAPI.post("/api/checklist/\(item.id)/delete")
        await load()
    }

    func add(body: String, at: String) async {
        var payload: [String: Any] = ["body": body, "is_fixed": true]
        if !at.isEmpty { payload["at"] = at }
        try? await NativeHouseAPI.post("/api/checklist", body: payload)
        await load()
    }
}

private struct NativeChecklistView: View {
    @StateObject private var model = ChecklistModel()
    @State private var draft = ""
    @State private var time = ""
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("TODAY'S ORDER").font(.system(size: 15, weight: .bold, design: .monospaced))
                Text(Date.now.formatted(date: .long, time: .omitted))
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(theme.textDim)
            }
            .padding(.top, 12)
            if model.loading && model.items.isEmpty { ProgressView() }
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(model.items) { item in
                        HStack(spacing: 9) {
                            Button { Task { await model.toggle(item) } } label: {
                                Image(systemName: item.done ? "checkmark.square.fill" : "square")
                                    .foregroundColor(item.done ? theme.sendBottom : theme.textDim)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.body)
                                    .font(.system(size: 13, design: .monospaced))
                                    .strikethrough(item.done)
                                if !item.triggerAt.isEmpty {
                                    Text(item.triggerAt).font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(theme.textLight)
                                }
                            }
                            Spacer()
                            if !item.isFixed {
                                Text("临").font(.system(size: 9)).foregroundColor(theme.sendBottom)
                            }
                            Button { Task { await model.delete(item) } } label: {
                                Image(systemName: "xmark").font(.system(size: 11))
                                    .foregroundColor(theme.textLight)
                            }
                        }
                        .padding(11).houseGlass(theme)
                    }
                    if model.items.isEmpty && !model.loading {
                        Text(model.error.isEmpty ? "今天还没有待办" : model.error)
                            .font(.system(size: 12)).foregroundColor(theme.textDim).padding(30)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("加一项…", text: $draft)
                TextField("HH:mm", text: $time).frame(width: 58)
                    .textInputAutocapitalization(.never)
                Button {
                    let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !body.isEmpty else { return }
                    draft = ""
                    Task { await model.add(body: body, at: time); time = "" }
                } label: {
                    Image(systemName: "plus").frame(width: 30, height: 30)
                        .background(theme.sendBottom, in: Circle()).foregroundColor(.white)
                }
            }
            .font(.system(size: 13, design: .monospaced))
            .padding(11).houseGlass(theme)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .foregroundColor(theme.text)
        .task { await model.load() }
    }
}

private struct MusicSong: Identifiable, Equatable {
    let id: String
    let name: String
    let artist: String
    let cover: String

    init(_ json: [String: Any]) {
        id = json.string("id", "song_id")
        name = json.string("name", "song_name", "title")
        if let artists = json["ar"] as? [[String: Any]] {
            artist = artists.first?.string("name") ?? ""
        } else if let artists = json["artists"] as? [[String: Any]] {
            artist = artists.first?.string("name") ?? ""
        } else {
            artist = json.string("artist")
        }
        cover = json.object("al").string("picUrl").isEmpty
            ? json.string("cover", "picUrl") : json.object("al").string("picUrl")
    }
}

@MainActor
private final class MusicModel: ObservableObject {
    @Published var songs: [MusicSong] = []
    @Published var nowPlaying: MusicSong?
    @Published var isPlaying = false
    @Published var loading = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playHistory: [MusicSong] = []
    private var historyIndex = -1

    func search(_ query: String) async {
        guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !q.isEmpty else { return }
        loading = true
        defer { loading = false }
        guard let obj = try? await NativeHouseAPI.object("/api/music/cloudsearch?keywords=\(q)") else {
            songs = []; return
        }
        songs = obj.object("result").array("songs").map(MusicSong.init)
    }

    func play(_ song: MusicSong) async {
        guard let obj = try? await NativeHouseAPI.object("/api/music/song/url?id=\(song.id)"),
              let rows = obj["data"] as? [[String: Any]],
              let raw = rows.first?.string("url"), !raw.isEmpty,
              let url = URL(string: raw) else { return }
        cleanup()
        player = AVPlayer(url: url)
        player?.play()
        nowPlaying = song
        isPlaying = true
        progress = 0; duration = 0
        if historyIndex < 0 || historyIndex >= playHistory.count || playHistory[historyIndex] != song {
            playHistory.append(song)
            historyIndex = playHistory.count - 1
        }
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, let item = self.player?.currentItem else { return }
                let dur = item.duration.seconds
                if dur.isFinite && dur > 0 {
                    self.duration = dur
                    self.progress = time.seconds
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.progress = self?.duration ?? 0
            }
        }
    }

    func toggle() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        progress = seconds
    }

    func prev() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        Task { await play(playHistory[historyIndex]) }
    }

    func next() {
        if historyIndex + 1 < playHistory.count {
            historyIndex += 1
            Task { await play(playHistory[historyIndex]) }
        } else if !songs.isEmpty {
            let current = nowPlaying
            if let idx = songs.firstIndex(where: { $0.id == current?.id }), idx + 1 < songs.count {
                let nextSong = songs[idx + 1]
                Task { await play(nextSong) }
            }
        }
    }

    var hasPrev: Bool { historyIndex > 0 }
    var hasNext: Bool { historyIndex + 1 < playHistory.count || {
        guard let np = nowPlaying, let idx = songs.firstIndex(where: { $0.id == np.id }) else { return false }
        return idx + 1 < songs.count
    }() }

    private func cleanup() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
    }
}

private struct NativeMusicView: View {
    @StateObject private var model = MusicModel()
    @State private var query = ""
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        VStack(spacing: 10) {
            Text("Music").font(.system(size: 17, weight: .semibold, design: .serif)).padding(.top, 12)
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(theme.textLight)
                TextField("搜索歌名或歌手", text: $query)
                    .onSubmit { Task { await model.search(query) } }
                if model.loading { ProgressView().controlSize(.small) }
            }
            .padding(11).houseGlass(theme)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.songs) { song in
                        Button { Task { await model.play(song) } } label: {
                            HStack(spacing: 10) {
                                AsyncImage(url: URL(string: song.cover)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { theme.glassTint }
                                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.name).font(.system(size: 13)).lineLimit(1)
                                    Text(song.artist).font(.system(size: 11)).foregroundColor(theme.textDim)
                                }
                                Spacer()
                                Image(systemName: model.nowPlaying == song && model.isPlaying
                                      ? "waveform" : "play.fill")
                                    .font(.system(size: 12)).foregroundColor(theme.sendBottom)
                            }
                            .padding(8).houseGlass(theme)
                        }
                        .buttonStyle(.plain)
                    }
                    if model.songs.isEmpty && !model.loading {
                        Text("搜一首想听的歌").font(.system(size: 12))
                            .foregroundColor(theme.textDim).padding(30)
                    }
                }
            }
            if let song = model.nowPlaying {
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: song.cover)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { theme.glassTint }
                        .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(song.artist).font(.system(size: 10)).foregroundColor(theme.textDim)
                        }
                        Spacer()
                    }
                    if model.duration > 0 {
                        Slider(value: Binding(
                            get: { model.progress },
                            set: { model.seek(to: $0) }
                        ), in: 0...model.duration)
                        .tint(theme.sendBottom)
                        HStack {
                            Text(Self.fmt(model.progress)).font(.system(size: 9, design: .monospaced))
                            Spacer()
                            Text(Self.fmt(model.duration)).font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundColor(theme.textLight)
                    }
                    HStack(spacing: 20) {
                        Button { model.prev() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(model.hasPrev ? theme.text : theme.textLight)
                        }
                        .disabled(!model.hasPrev)
                        Button(action: model.toggle) {
                            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .frame(width: 40, height: 40)
                                .background(theme.sendBottom, in: Circle())
                                .foregroundColor(.white)
                        }
                        Button { model.next() } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(model.hasNext ? theme.text : theme.textLight)
                        }
                        .disabled(!model.hasNext)
                    }
                }
                .padding(10).houseGlass(theme)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 14).foregroundColor(theme.text)
    }

    private static func fmt(_ s: Double) -> String {
        let m = Int(s) / 60; let sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }
}

private struct NativeRecord: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let body: String
    let image: String
}

@MainActor
private final class DataPanelModel: ObservableObject {
    @Published var records: [NativeRecord] = []
    @Published var loading = true
    @Published var error = ""

    func load(_ destination: HouseDestination) async {
        loading = true
        defer { loading = false }
        do {
            let path: String
            let key: String?
            switch destination {
            case .memory: path = "/api/ob/buckets"; key = nil
            case .dreams: path = "/api/ob/dreams?limit=20"; key = "records"
            case .shelf: path = "/api/shelf/list?limit=100"; key = "items"
            case .nianlun: path = "/api/nianlun/list"; key = "desires"
            case .album: path = "/api/album/entries"; key = "entries"
            case .impression: path = "/api/ob/buckets"; key = nil
            case .sex: path = "/api/sex/entries"; key = "entries"
            case .calendar: path = "/api/calendar/month?year=\(Calendar.current.component(.year, from: Date()))&month=\(Calendar.current.component(.month, from: Date()))"; key = nil
            case .desire, .portrait, .usage:
                path = destination == .desire ? "/api/desire/state"
                    : destination == .portrait ? "/api/ob/portrait" : "/api/usage"
                key = nil
            default: path = "/api/ob/buckets"; key = nil
            }
            let value = try await NativeHouseAPI.request(path)
            var rows: [[String: Any]]
            if let array = value as? [[String: Any]] {
                rows = array
            } else if let object = value as? [String: Any], let key {
                rows = object[key] as? [[String: Any]] ?? []
            } else if let object = value as? [String: Any] {
                rows = flatten(object)
            } else { rows = [] }
            if destination == .impression {
                rows = rows.filter {
                    $0.string("type") == "feel"
                    && (($0["tags"] as? [Any])?.map(String.init(describing:)).contains("daily_impression") ?? false)
                }
            }
            records = rows.map(record)
            error = ""
        } catch { self.error = "这一页暂时够不着" }
    }

    private func flatten(_ object: [String: Any]) -> [[String: Any]] {
        var out: [[String: Any]] = []
        for (key, value) in object.sorted(by: { $0.key < $1.key }) {
            if let dict = value as? [String: Any] {
                out.append(["name": key, "content": pretty(dict)])
            } else if let list = value as? [Any] {
                out.append(["name": key, "content": list.map { String(describing: $0) }.joined(separator: "\n")])
            } else {
                out.append(["name": key, "content": String(describing: value)])
            }
        }
        return out
    }

    private func pretty(_ object: [String: Any]) -> String {
        object.sorted(by: { $0.key < $1.key })
            .map { "\($0.key)：\(String(describing: $0.value))" }.joined(separator: "\n")
    }

    private func record(_ row: [String: Any]) -> NativeRecord {
        let title = row.string("name", "title", "text", "local_date", "date", "mode")
        let subtitle = row.string("status", "track", "ai_name", "source_date", "ts", "created")
        let body = row.string("content_preview", "content", "comment", "caption", "why_mine", "state")
        let image = row.string("img", "image_url", "cover")
        return NativeRecord(
            title: title.isEmpty ? "记录" : title,
            subtitle: subtitle,
            body: body.isEmpty ? row.description : body,
            image: image)
    }
}

private struct NativeDataPanel: View {
    let destination: HouseDestination
    @StateObject private var model = DataPanelModel()
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        VStack(spacing: 10) {
            Text(destination.title)
                .font(.system(size: 17, weight: .semibold, design: .serif)).padding(.top, 12)
            if model.loading { Spacer(); ProgressView(); Spacer() }
            else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        ForEach(model.records) { item in
                            VStack(alignment: .leading, spacing: 7) {
                                if !item.image.isEmpty {
                                    AsyncImage(url: AlcoveAPI.attachmentURL(item.image)) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: { ProgressView() }
                                    .frame(maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                HStack {
                                    Text(item.title).font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Text(item.subtitle).font(.system(size: 9)).foregroundColor(theme.textLight)
                                }
                                Text(item.body).font(.system(size: 12)).foregroundColor(theme.textDim)
                                    .lineSpacing(3).textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).houseGlass(theme)
                        }
                        if model.records.isEmpty {
                            Text(model.error.isEmpty ? "这里还没有记录" : model.error)
                                .font(.system(size: 12)).foregroundColor(theme.textDim).padding(40)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 18).foregroundColor(theme.text)
        .task { await model.load(destination) }
    }
}

private struct ClockworkItem: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let desc: String
}

private struct ClockworkView: View {
    @State private var flags: [String: Bool] = [:]
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }
    private let items = [
        ClockworkItem(id: "ghost", emoji: "👻", name: "Ghost 游荡", desc: "四班随机游荡"),
        ClockworkItem(id: "libido", emoji: "🌅", name: "晨勃", desc: "libido 攒满自动醒来"),
        ClockworkItem(id: "followup", emoji: "🔔", name: "追问", desc: "你不回我我就回来敲门"),
        ClockworkItem(id: "chase", emoji: "📣", name: "催起床+追", desc: "白天未出现时唤醒"),
        ClockworkItem(id: "sleep", emoji: "🌙", name: "睡眠", desc: "凌晨三点睡，上午十点醒"),
        ClockworkItem(id: "keepalive", emoji: "💓", name: "保活心跳", desc: "每 55 分钟翻个身")
    ]

    var body: some View {
        VStack {
            Text("发条").font(.system(size: 17, weight: .semibold, design: .serif)).padding(.top, 12)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        HStack(spacing: 11) {
                            Text(item.emoji).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.system(size: 13, weight: .medium))
                                Text(item.desc).font(.system(size: 10)).foregroundColor(theme.textDim)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { flags[item.id] ?? true },
                                set: { value in
                                    flags[item.id] = value
                                    Task { try? await NativeHouseAPI.post(
                                        "/api/flags/set", body: ["key": item.id, "on": value]) }
                                }))
                            .labelsHidden().tint(theme.sendBottom)
                        }
                        .padding(12).houseGlass(theme)
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 18).foregroundColor(theme.text)
        .task {
            if let obj = try? await NativeHouseAPI.object("/api/flags/status"),
               let raw = obj["flags"] as? [String: Any] {
                flags = raw.mapValues { ($0 as? Bool) ?? true }
            }
        }
    }
}

private struct NativeSearchView: View {
    @State private var query = ""
    @State private var results: [ChatMessage] = []
    @State private var history: [ChatMessage] = []
    @State private var filterType = "all"
    @State private var filterDate: Date?
    @State private var showDatePicker = false
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("userName") private var userName = "Luna"
    @AppStorage("assistantName") private var assistantName = "陈璟"
    private var theme: AlcoveTheme { .named(themeName) }

    private let types = [("all", "全部"), ("text", "文字"), ("image", "图片"),
                         ("audio", "语音"), ("link", "链接")]

    var body: some View {
        VStack(spacing: 10) {
            Text("Search").font(.system(size: 17, weight: .semibold, design: .serif)).padding(.top, 12)
            TextField("搜索聊天记录", text: $query)
                .padding(11).houseGlass(theme)
                .onChange(of: query) { _ in applyFilter() }
            HStack(spacing: 6) {
                ForEach(types, id: \.0) { key, label in
                    Button {
                        filterType = key; applyFilter()
                    } label: {
                        Text(label)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(filterType == key ? theme.sendBottom.opacity(0.2) : theme.glassTint,
                                        in: Capsule())
                            .foregroundColor(filterType == key ? theme.sendBottom : theme.textDim)
                    }
                }
                Spacer()
                Button {
                    showDatePicker.toggle()
                } label: {
                    Image(systemName: filterDate == nil ? "calendar" : "calendar.badge.checkmark")
                        .font(.system(size: 13))
                        .foregroundColor(filterDate == nil ? theme.textDim : theme.sendBottom)
                }
            }
            if showDatePicker {
                DatePicker("日期", selection: Binding(
                    get: { filterDate ?? Date() },
                    set: { filterDate = $0; applyFilter() }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                HStack {
                    Spacer()
                    Button("清除日期") { filterDate = nil; applyFilter() }
                        .font(.system(size: 11)).foregroundColor(theme.textDim)
                }
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(results) { message in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(message.role == "user" ? userName : assistantName)
                                    .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.textLight)
                                Spacer()
                                Text(MessageRow.hm.string(from: message.date))
                                    .font(.system(size: 9)).foregroundColor(theme.textLight)
                            }
                            if message.isImage {
                                Label("图片", systemImage: "photo").font(.system(size: 12))
                                    .foregroundColor(theme.textDim)
                            }
                            if message.isAudio {
                                Label("语音", systemImage: "waveform").font(.system(size: 12))
                                    .foregroundColor(theme.textDim)
                            }
                            if !message.text.isEmpty {
                                Text(message.text).font(.system(size: 12)).lineSpacing(3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12).houseGlass(theme)
                    }
                    if results.isEmpty && !query.isEmpty {
                        Text("没有找到").font(.system(size: 12)).foregroundColor(theme.textDim).padding(30)
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 18).foregroundColor(theme.text)
        .task { history = (try? await AlcoveAPI.history(limit: 300)) ?? [] }
    }

    private func applyFilter() {
        var pool = history
        if filterType == "image" { pool = pool.filter { $0.isImage } }
        else if filterType == "audio" { pool = pool.filter { $0.isAudio } }
        else if filterType == "link" {
            pool = pool.filter { $0.text.contains("http://") || $0.text.contains("https://") }
        } else if filterType == "text" {
            pool = pool.filter { !$0.isImage && !$0.isAudio && !$0.text.isEmpty }
        }
        if let d = filterDate {
            let cal = Calendar.current
            pool = pool.filter { cal.isDate($0.date, inSameDayAs: d) }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            pool = pool.filter { $0.text.localizedCaseInsensitiveContains(q) }
        }
        results = pool
    }
}

private struct FavoriteItem: Identifiable {
    let id: String
    let text: String
    let role: String
    let ts: String
    init(_ json: [String: Any]) {
        id = json.string("ts", "id")
        text = json.string("text")
        role = json.string("role")
        ts = json.string("ts", "created")
    }
}

private struct NativeFavoritesView: View {
    @State private var items: [FavoriteItem] = []
    @State private var loading = true
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("userName") private var userName = "Luna"
    @AppStorage("assistantName") private var assistantName = "陈璟"
    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        VStack {
            Text("Favorites").font(.system(size: 17, weight: .semibold, design: .serif)).padding(.top, 12)
            if loading { Spacer(); ProgressView(); Spacer() }
            else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.role == "user" ? userName : assistantName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(theme.textLight)
                                    Spacer()
                                    if !item.ts.isEmpty {
                                        Text(String(item.ts.prefix(10)))
                                            .font(.system(size: 9)).foregroundColor(theme.textLight)
                                    }
                                }
                                Text(item.text).font(.system(size: 12)).lineSpacing(3)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12).houseGlass(theme)
                        }
                        if items.isEmpty {
                            Text("还没有收藏").font(.system(size: 12))
                                .foregroundColor(theme.textDim).padding(40)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 18).foregroundColor(theme.text)
        .task {
            if let raw = try? await AlcoveAPI.favorites() {
                items = raw.map(FavoriteItem.init)
            }
            loading = false
        }
    }
}

private struct WebHouseView: View {
    let destination: HouseDestination
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    private var panelName: String {
        switch destination {
        case .checklist: return "checklist"
        case .music: return "music"
        case .clockwork: return "fatiao"
        default: return destination.rawValue
        }
    }

    private var panelURL: URL {
        AlcoveAPI.fullURL("/?panel=\(panelName)")
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(destination.title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .padding(.top, 12)
            FixedWebView(url: panelURL)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.glassBorder, lineWidth: 1))
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
    }
}

private struct NativePlayView: View {
    let destination: HouseDestination
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }
    private var url: URL {
        switch destination {
        case .crosstalk: return URL(string: "https://clunaadke.github.io/crosstalk/#https://vrnhyhofzzmbgzaarbaz.supabase.co")!
        case .coread: return AlcoveAPI.fullURL("/read/")
        case .liao: return AlcoveAPI.fullURL("/liao")
        default: return AlcoveAPI.fullURL("/")
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            Text(destination.title).font(.system(size: 17, weight: .semibold, design: .serif)).padding(.top, 12)
            FixedWebView(url: url).clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.glassBorder, lineWidth: 1))
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
    }
}

private struct FixedWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(initialURL: url) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let initialHost: String?
        init(initialURL: URL) { initialHost = initialURL.host }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if navigationAction.navigationType == .linkActivated,
               let iHost = initialHost, target.host != iHost,
               target.host == AlcoveAPI.base.host {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

private extension View {
    func houseGlass(_ theme: AlcoveTheme) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(theme.glassTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.glassBorder, lineWidth: 1))
    }
}
