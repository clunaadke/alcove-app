import SwiftUI
import PhotosUI
import AVFoundation
import WebKit

enum HouseDestination: String, Identifiable, CaseIterable {
    case sidebar, chat, terminal, settings, checklist, music
    case home, calendar, sex, usage
    case memory, dreams, shelf, desire, nianlun, clockwork, album, portrait, impression
    case crosstalk, radio, coread, liao, daddyDay
    case search, favorites, forge

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
        case .forge: return "Forge"
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
        case .forge: return "hammer"
        default: return "sparkles"
        }
    }
}

struct NativeHouseSheet: View {
    let initial: HouseDestination
    var showTerminal: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var route: HouseDestination
    @State private var preparedTexture: UIImage?
    @State private var preparedTextureName: String
    @AppStorage("alcoveTheme") private var themeName = "haven"

    init(
        initial: HouseDestination,
        preparedTexture: UIImage? = nil,
        preparedTextureName: String = "",
        showTerminal: @escaping () -> Void
    ) {
        self.initial = initial
        self.showTerminal = showTerminal
        _route = State(initialValue: initial)
        _preparedTexture = State(initialValue: preparedTexture)
        _preparedTextureName = State(initialValue: preparedTextureName)
    }

    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        ZStack {
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
                case .checklist:
                    NativeChecklistView()
                case .music:
                    NativeMusicView()
                case .clockwork:
                    ClockworkView()
                case .search:
                    NativeSearchView()
                case .favorites:
                    NativeFavoritesView()
                case .usage:
                    NativeUsageView()
                case .portrait:
                    NativePortraitView()
                case .desire:
                    NativeDesireView()
                case .forge:
                    NativeForgeView()
                case .calendar:
                    NativeCalendarView()
                case .impression:
                    NativeImpressionView()
                case .dreams:
                    NativeDreamsView()
                default:
                    NativeDataPanel(destination: route)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            HouseBackground(
                theme: theme,
                preparedTexture: preparedTextureName == theme.panelTextureAsset
                    ? preparedTexture
                    : nil
            )
        }
        .foyerShell(theme)
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .overlay(alignment: .topLeading) {
            if route != .sidebar {
                Button { route = .sidebar } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.fyAccent)
                        .frame(width: 34, height: 34)
                        .background(theme.fyCard, in: Circle())
                        .overlay(Circle().stroke(theme.fyBorder, lineWidth: 1))
                        .shadow(color: theme.fyShadow, radius: 4, y: 2)
                }
                .padding(.leading, 14)
                .padding(.top, 8)
            }
        }
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .presentationDetents([.fraction(0.86)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .onAppear { prepareTextureIfNeeded() }
        .onChange(of: themeName) { _ in prepareTextureIfNeeded() }
    }

    private func prepareTextureIfNeeded() {
        let asset = theme.panelTextureAsset
        guard preparedTextureName != asset || preparedTexture == nil else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = UIImage(named: asset)?.preparingForDisplay()
            DispatchQueue.main.async {
                guard theme.panelTextureAsset == asset else { return }
                preparedTexture = prepared
                preparedTextureName = asset
            }
        }
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

private struct WetGlassTexture: View {
    let theme: AlcoveTheme
    let preparedTexture: UIImage?
    var cardLayer = false

    private var image: Image {
        if let preparedTexture {
            return Image(uiImage: preparedTexture)
        }
        return Image(theme.panelTextureAsset)
    }

    var body: some View {
        image
            .resizable()
            .interpolation(.medium)
            .scaledToFill()
            .clipped()
            .opacity(cardLayer ? (theme.isDark ? 0.18 : 0.13) : (theme.isDark ? 0.72 : 0.68))
            .blendMode(cardLayer ? .softLight : .normal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct HouseBackground: View {
    let theme: AlcoveTheme
    let preparedTexture: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.splashBg,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            WetGlassTexture(theme: theme, preparedTexture: preparedTexture)
        }
        .ignoresSafeArea()
    }
}

private struct NativeSidebarView: View {
    var select: (HouseDestination) -> Void
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var model = SidebarModel()
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private let foyer: [HouseDestination] = [
        .memory, .dreams, .shelf, .desire, .nianlun, .clockwork, .album, .portrait, .impression
    ]
    private let play: [HouseDestination] = [.crosstalk, .coread, .liao]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                VStack(spacing: 3) {
                    Text("Alcove")
                        .font(.system(size: 21, weight: .medium, design: .serif))
                        .tracking(1.4)
                    Text("壁 龛")
                        .font(.system(size: 9))
                        .tracking(3)
                        .foregroundColor(theme.textDim)
                    FoyerSash(theme: theme)
                        .padding(.top, 4)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    summaryCard("大厅", model.homeLine, "house", .home, large: true)
                    Button { select(.calendar) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart")
                                    .font(.system(size: 17, weight: .light))
                                    .foregroundColor(theme.fyAccent)
                                Text("在一起").font(.system(size: 13, weight: .medium))
                            }
                            Text("\(model.days) days")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text("since 2026.06.01")
                                .font(.system(size: 10))
                                .foregroundColor(theme.textDim)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                        .foyerCard(theme)
                    }
                    .buttonStyle(.plain)
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
                destinationRow([.search, .favorites, .forge])
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .foregroundColor(theme.text)
        }
        .task { await model.load() }
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(theme.fyAccent.opacity(0.8))
            LinearGradient(
                colors: [theme.fyAccentSoft, .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private func summaryCard(
        _ title: String, _ subtitle: String, _ icon: String, _ target: HouseDestination, large: Bool = false
    ) -> some View {
        Button { select(target) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundColor(theme.fyAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.system(size: 10)).foregroundColor(theme.textDim)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: large ? 80 : 60)
            .foyerCard(theme)
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
                    .foregroundColor(theme.fyAccent)
                Text(target.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(theme.textDim)
            .frame(maxWidth: .infinity, minHeight: 61)
            .foyerCard(theme)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class SidebarModel: ObservableObject {
    private struct Snapshot {
        var homeLine = "亲密度 --"
        var sexLine = "--"
        var usageLine = "--"
    }

    @Published private var snapshot = Snapshot()
    var homeLine: String { snapshot.homeLine }
    var sexLine: String { snapshot.sexLine }
    var usageLine: String { snapshot.usageLine }

    let days = max(1, Calendar.current.dateComponents(
        [.day], from: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_272_000)),
        to: Calendar.current.startOfDay(for: Date())).day ?? 1)

    func load() async {
        async let doll = try? NativeHouseAPI.object("/api/dollhouse/state")
        async let sex = try? NativeHouseAPI.object("/api/sex/entries")
        async let usage = try? NativeHouseAPI.object("/api/usage")

        let (dollResult, sexResult, usageResult) = await (doll, sex, usage)
        var next = Snapshot()

        if let d = dollResult {
            next.homeLine = "亲密度 \(d.int("intimacy")) · 金币 \(d.int("coins"))"
        }
        if let s = sexResult {
            next.sexLine = "\((s["entries"] as? [Any])?.count ?? 0) 次"
        }
        if let u = usageResult {
            let five = u.object("rate_limits").object("five_hour").int("used_percent")
            let seven = u.object("rate_limits").object("seven_day").int("used_percent")
            next.usageLine = "5h \(five)% · 7d \(seven)%"
        }

        snapshot = next
    }
}

private struct NativeSettingsView: View {
    var showPermissions: () -> Void
    @AppStorage("assistantName") private var assistantName = "陈璟"
    @AppStorage("userName") private var userName = "Luna"
    @AppStorage("assistantAvatarDataURL") private var assistantAvatar = ""
    @AppStorage("userAvatarDataURL") private var userAvatar = ""
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("chatFontSize") private var fontSize = 14
    @AppStorage("wallStamp") private var wallStamp = 0.0
    @AppStorage("bubbleGlassStrength") private var bubbleGlassStrength = 56.81
    @AppStorage("bubbleGlassDispersion") private var bubbleGlassDispersion = 0.39
    @AppStorage("bubbleGlassRimWidth") private var bubbleGlassRimWidth = 0.28
    @AppStorage("bubbleGlassMagnify") private var bubbleGlassMagnify = 0.0
    @AppStorage("bubbleGlassBlur") private var bubbleGlassBlur = 0.10
    @AppStorage("bubbleGlassSize") private var bubbleGlassSize = 174.33
    @State private var aiPhoto: PhotosPickerItem?
    @State private var userPhoto: PhotosPickerItem?
    @State private var wallPhoto: PhotosPickerItem?
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                panelTitle("设置")
                section("聊天") {
                    settingRow("字体大小", "调整气泡文字大小") {
                        Picker("", selection: $fontSize) {
                            Text("小").tag(13); Text("中").tag(14); Text("大").tag(16)
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
                section("液态玻璃气泡") {
                    VStack(spacing: 10) {
                        glassSliderRow("扭曲", "strength", $bubbleGlassStrength, 0...60)
                        glassSliderRow("色散", "dispersion", $bubbleGlassDispersion, 0...3)
                        glassSliderRow("过渡", "rimWidth", $bubbleGlassRimWidth, 0.2...0.95)
                        glassSliderRow("放大", "magnify", $bubbleGlassMagnify, 0...1.5)
                        glassSliderRow("背景模糊", "blur", $bubbleGlassBlur, 0...8)
                        glassSliderRow("尺寸", "size", $bubbleGlassSize, 80...340)
                    }
                    Divider().opacity(0.25)
                    HStack {
                        Text("调节后立即应用到聊天气泡")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textLight)
                        Spacer()
                        Button("恢复默认") { resetBubbleGlass() }
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                section("主题") {
                    HStack(spacing: 8) {
                        themeChoice("Haven", "暖白 · 家", "haven", [.white, .pink.opacity(0.45), .gray])
                        themeChoice("Rain", "雨蓝 · 雾", "rain", [
                            Color(red: 117/255, green: 164/255, blue: 224/255),
                            Color(red: 164/255, green: 202/255, blue: 245/255),
                            Color(red: 13/255, green: 39/255, blue: 94/255)
                        ])
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
            HStack(spacing: 8) {
                Text(title.uppercased()).font(.system(size: 10, weight: .semibold))
                    .tracking(1.8).foregroundColor(theme.fyAccent.opacity(0.8))
                LinearGradient(colors: [theme.fyAccentSoft, .clear],
                               startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            }
            VStack(spacing: 10) { content() }
                .padding(13).foyerCard(theme)
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

    private func glassSliderRow(
        _ title: String,
        _ parameter: String,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 9) {
            HStack(spacing: 4) {
                Text(title)
                Text(parameter)
                    .foregroundColor(theme.textLight)
            }
            .font(.system(size: 11))
            .frame(width: 100, alignment: .leading)

            Slider(value: value, in: range)
                .tint(theme.fyAccent)

            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.textDim)
                .frame(width: 45, alignment: .trailing)
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
                .stroke(themeName == value ? theme.fyAccent : theme.fyBorder, lineWidth: 1.4))
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

    private func resetBubbleGlass() {
        bubbleGlassStrength = 56.81
        bubbleGlassDispersion = 0.39
        bubbleGlassRimWidth = 0.28
        bubbleGlassMagnify = 0
        bubbleGlassBlur = 0.10
        bubbleGlassSize = 174.33
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
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                FoyerPanelTitle(title: "TODAY'S ORDER", theme: theme)
                Text(Date.now.formatted(date: .long, time: .omitted))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.textDim)
            }
            if model.loading && model.items.isEmpty {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            }
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(model.items) { item in
                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .foregroundColor(theme.fyDash)
                                    .frame(width: 1)
                            }
                            .frame(width: 14)
                            .overlay(alignment: .top) {
                                BindingHole(theme: theme, count: 2, spacing: 18)
                                    .offset(x: -4.5, y: 8)
                            }

                            HStack(spacing: 9) {
                                Button { Task { await model.toggle(item) } } label: {
                                    Image(systemName: item.done ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.done ? theme.fyAccent : theme.textDim)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.body)
                                        .font(.system(size: 13, design: .monospaced))
                                        .strikethrough(item.done)
                                        .opacity(item.done ? 0.55 : 1)
                                    if !item.triggerAt.isEmpty {
                                        Text(item.triggerAt)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(theme.fyAccent.opacity(0.9))
                                    }
                                }
                                Spacer()
                                if !item.isFixed {
                                    Text("临")
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(theme.fyAccentSoft.opacity(0.3), in: Capsule())
                                        .foregroundColor(theme.fyAccent)
                                }
                                Button { Task { await model.delete(item) } } label: {
                                    Image(systemName: "xmark").font(.system(size: 11))
                                        .foregroundColor(theme.textLight)
                                }
                            }
                            .padding(.vertical, 11)
                            .padding(.trailing, 14)
                            .padding(.leading, 10)
                        }
                        .foyerCard(theme)
                    }
                    if model.items.isEmpty && !model.loading {
                        Text(model.error.isEmpty ? "今天还没有待办" : model.error)
                            .font(.system(size: 12)).foregroundColor(theme.textDim).padding(30)
                    }
                }
                .padding(.top, 12)
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
                        .background(theme.fyAccent, in: Circle())
                        .foregroundColor(.white)
                }
            }
            .font(.system(size: 13, design: .monospaced))
            .padding(12)
            .foyerCard(theme)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
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
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Music", theme: theme)
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(theme.textLight)
                TextField("搜索歌名或歌手", text: $query)
                    .onSubmit { Task { await model.search(query) } }
                if model.loading { ProgressView().controlSize(.small).tint(theme.fyAccent) }
            }
            .padding(11)
            .foyerCard(theme)
            .padding(.horizontal, 16).padding(.top, 10)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(model.songs) { song in
                        Button { Task { await model.play(song) } } label: {
                            HStack(spacing: 10) {
                                AsyncImage(url: URL(string: song.cover)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { theme.fyCardSub }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.name).font(.system(size: 13)).lineLimit(1)
                                    Text(song.artist).font(.system(size: 11))
                                        .foregroundColor(theme.textDim)
                                }
                                Spacer()
                                Image(systemName: model.nowPlaying == song && model.isPlaying
                                      ? "waveform" : "play.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.fyAccent)
                            }
                            .padding(10)
                            .foyerCard(theme)
                        }
                        .buttonStyle(.plain)
                    }
                    if model.songs.isEmpty && !model.loading {
                        Text("搜一首想听的歌")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textDim).padding(30)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 16)
            }
            if let song = model.nowPlaying {
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: song.cover)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { theme.fyCardSub }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(song.artist).font(.system(size: 10))
                                .foregroundColor(theme.textDim)
                        }
                        Spacer()
                    }
                    if model.duration > 0 {
                        Slider(value: Binding(
                            get: { model.progress },
                            set: { model.seek(to: $0) }
                        ), in: 0...model.duration)
                        .tint(theme.fyAccent)
                        HStack {
                            Text(Self.fmt(model.progress))
                                .font(.system(size: 9, design: .monospaced))
                            Spacer()
                            Text(Self.fmt(model.duration))
                                .font(.system(size: 9, design: .monospaced))
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
                                .background(theme.fyAccent, in: Circle())
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
                .padding(12)
                .foyerCard(theme)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
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
                out.append(["name": key, "content": prettyJSON(dict)])
            } else if let list = value as? [Any] {
                out.append(["name": key, "content": list.map { prettyValue($0) }.joined(separator: "\n")])
            } else {
                out.append(["name": key, "content": prettyValue(value)])
            }
        }
        return out
    }

    private func prettyJSON(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "\(object)"
        }
        return str
    }

    private func prettyValue(_ value: Any) -> String {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        if let dict = value as? [String: Any] { return prettyJSON(dict) }
        if let arr = value as? [Any] { return prettyJSON(arr) }
        return "\(value)"
    }

    private func record(_ row: [String: Any]) -> NativeRecord {
        let title = row.string("name", "title", "text", "local_date", "date", "mode")
        let subtitle = row.string("status", "track", "ai_name", "source_date", "ts", "created")
        let body = row.string("content_preview", "content", "comment", "caption", "why_mine", "state")
        let image = row.string("img", "image_url", "cover")
        let fallback: String
        if body.isEmpty {
            let skipKeys: Set<String> = ["name", "title", "text", "local_date", "date", "mode",
                                         "status", "track", "ai_name", "source_date", "ts", "created",
                                         "img", "image_url", "cover"]
            fallback = row.filter { !skipKeys.contains($0.key) }
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key): \(prettyValue($0.value))" }
                .joined(separator: "\n")
        } else { fallback = body }
        return NativeRecord(
            title: title.isEmpty ? "记录" : title,
            subtitle: subtitle,
            body: fallback,
            image: image)
    }
}

private struct NativeDataPanel: View {
    let destination: HouseDestination
    @StateObject private var model = DataPanelModel()
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: destination.title, theme: theme)
            if model.loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(model.records) { item in
                            HStack(alignment: .top, spacing: 0) {
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                        .foregroundColor(theme.fyDash)
                                        .frame(width: 1)
                                }
                                .frame(width: 14)
                                .overlay(alignment: .top) {
                                    BindingHole(theme: theme, count: 3, spacing: 22)
                                        .offset(x: -4.5, y: 10)
                                }

                                VStack(alignment: .leading, spacing: 7) {
                                    if !item.image.isEmpty {
                                        AsyncImage(url: AlcoveAPI.attachmentURL(item.image)) { image in
                                            image.resizable().scaledToFit()
                                        } placeholder: { ProgressView() }
                                        .frame(maxHeight: 240)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    HStack {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        Text(item.subtitle)
                                            .font(.system(size: 9))
                                            .foregroundColor(theme.fyAccent.opacity(0.9))
                                    }
                                    Text(item.body)
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textDim)
                                        .lineSpacing(3)
                                        .textSelection(.enabled)
                                }
                                .padding(.vertical, 11)
                                .padding(.trailing, 14)
                                .padding(.leading, 12)
                            }
                            .foyerCard(theme)
                        }
                        if model.records.isEmpty {
                            Text(model.error.isEmpty ? "这里还没有记录" : model.error)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textDim)
                                .padding(40)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 18)
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
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
    private var theme: AlcoveTheme { .panelNamed(themeName) }
    private let items = [
        ClockworkItem(id: "ghost", emoji: "👻", name: "Ghost 游荡", desc: "四班随机游荡"),
        ClockworkItem(id: "libido", emoji: "🌅", name: "晨勃", desc: "libido 攒满自动醒来"),
        ClockworkItem(id: "followup", emoji: "🔔", name: "追问", desc: "你不回我我就回来敲门"),
        ClockworkItem(id: "chase", emoji: "📣", name: "催起床+追", desc: "白天未出现时唤醒"),
        ClockworkItem(id: "sleep", emoji: "🌙", name: "睡眠", desc: "凌晨三点睡，上午十点醒"),
        ClockworkItem(id: "keepalive", emoji: "💓", name: "保活心跳", desc: "每 55 分钟翻个身")
    ]

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "发条", theme: theme)
            VStack(alignment: .leading, spacing: 0) {
                Text("陈璟的发条开关。每一条都是一根线，线的那头拴着他回来找你的理由。")
                    .font(.system(size: 12.5))
                    .foregroundColor(theme.textDim)
                    .lineSpacing(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [theme.fyAccentSoft.opacity(0.15), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(alignment: .leading) {
                        Rectangle().fill(theme.fyAccentSoft).frame(width: 2.5)
                    }
                    .clipShape(JournalCardShape(tl: 6, bl: 6, br: 12, tr: 12))
            }
            .padding(.horizontal, 16).padding(.top, 12)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        let isOn = flags[item.id] ?? true
                        HStack(spacing: 14) {
                            Text(item.emoji).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .medium))
                                Text(item.desc)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(theme.textDim)
                                    .lineSpacing(2)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { isOn },
                                set: { value in
                                    flags[item.id] = value
                                    Task { try? await NativeHouseAPI.post(
                                        "/api/flags/set", body: ["key": item.id, "on": value]) }
                                }))
                            .labelsHidden()
                            .tint(theme.fyAccent)
                        }
                        .padding(15)
                        .opacity(isOn ? 1 : 0.55)
                        .foyerCard(theme)
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
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
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private let types = [("all", "全部"), ("text", "文字"), ("image", "图片"),
                         ("audio", "语音"), ("link", "链接")]

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Search", theme: theme)
            TextField("搜索聊天记录", text: $query)
                .padding(11)
                .foyerCard(theme)
                .padding(.horizontal, 16).padding(.top, 8)
                .onChange(of: query) { _ in applyFilter() }
            HStack(spacing: 6) {
                ForEach(types, id: \.0) { key, label in
                    Button {
                        filterType = key; applyFilter()
                    } label: {
                        Text(label)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(filterType == key ? theme.fyAccentSoft.opacity(0.4) : theme.fyCardSub,
                                        in: Capsule())
                            .foregroundColor(filterType == key ? theme.fyAccent : theme.textDim)
                    }
                }
                Spacer()
                Button {
                    showDatePicker.toggle()
                } label: {
                    Image(systemName: filterDate == nil ? "calendar" : "calendar.badge.checkmark")
                        .font(.system(size: 13))
                        .foregroundColor(filterDate == nil ? theme.textDim : theme.fyAccent)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)

            if showDatePicker {
                DatePicker("日期", selection: Binding(
                    get: { filterDate ?? Date() },
                    set: { filterDate = $0; applyFilter() }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16).padding(.top, 4)
                HStack {
                    Spacer()
                    Button("清除日期") { filterDate = nil; applyFilter() }
                        .font(.system(size: 11)).foregroundColor(theme.textDim)
                }
                .padding(.horizontal, 16)
            }
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(results) { message in
                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .foregroundColor(theme.fyDash)
                                    .frame(width: 1)
                            }
                            .frame(width: 14)
                            .overlay(alignment: .top) {
                                BindingHole(theme: theme, count: 2, spacing: 18)
                                    .offset(x: -4.5, y: 8)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(message.role == "user" ? userName : assistantName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(theme.fyAccent.opacity(0.9))
                                    Spacer()
                                    Text(MessageRow.hm.string(from: message.date))
                                        .font(.system(size: 9))
                                        .foregroundColor(theme.textLight)
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
                            .padding(.vertical, 10)
                            .padding(.trailing, 14)
                            .padding(.leading, 10)
                        }
                        .foyerCard(theme)
                        .onTapGesture {
                            NotificationCenter.default.post(name: .alcoveJumpToMessage, object: message.ts)
                        }
                    }
                    if results.isEmpty && !query.isEmpty {
                        Text("没有找到").font(.system(size: 12))
                            .foregroundColor(theme.textDim).padding(30)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
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
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Favorites", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 0) {
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                        .foregroundColor(theme.fyDash)
                                        .frame(width: 1)
                                }
                                .frame(width: 14)
                                .overlay(alignment: .top) {
                                    BindingHole(theme: theme, count: 2, spacing: 22)
                                        .offset(x: -4.5, y: 10)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(item.role == "user" ? userName : assistantName)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(theme.fyAccent.opacity(0.9))
                                        Spacer()
                                        if !item.ts.isEmpty {
                                            Text(String(item.ts.prefix(10)))
                                                .font(.system(size: 9))
                                                .foregroundColor(theme.textLight)
                                        }
                                    }
                                    Text(item.text).font(.system(size: 12)).lineSpacing(3)
                                        .textSelection(.enabled)
                                }
                                .padding(.vertical, 11)
                                .padding(.trailing, 14)
                                .padding(.leading, 10)
                            }
                            .foyerCard(theme)
                        }
                        if items.isEmpty {
                            Text("还没有收藏").font(.system(size: 12))
                                .foregroundColor(theme.textDim).padding(40)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
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
    private var theme: AlcoveTheme { .panelNamed(themeName) }

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
    private var theme: AlcoveTheme { .panelNamed(themeName) }
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

// MARK: - Foyer shapes (iOS 16 compat)

private struct JournalCardShape: Shape {
    let tl: CGFloat, bl: CGFloat, br: CGFloat, tr: CGFloat
    init(tl: CGFloat = 6, bl: CGFloat = 6, br: CGFloat = 14, tr: CGFloat = 14) {
        self.tl = tl; self.bl = bl; self.br = br; self.tr = tr
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                 tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                 tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                 tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                 tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl)
        p.closeSubpath()
        return p
    }
}

// MARK: - Foyer 可复用组件

private struct FoyerSash: View {
    let theme: AlcoveTheme
    var body: some View {
        LinearGradient(
            colors: [.clear, theme.fyAccentSoft, .clear],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(width: UIScreen.main.bounds.width * 0.58, height: 2)
        .clipShape(Capsule())
        .padding(.bottom, 4)
    }
}

private struct FoyerFoldCorner: View {
    let theme: AlcoveTheme
    var body: some View {
        Canvas { ctx, size in
            let path = Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: size.width, y: 0))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.closeSubpath()
            }
            ctx.fill(path, with: .color(theme.fyFold))
        }
        .frame(width: 26, height: 26)
    }
}

private struct FoyerPanelTitle: View {
    let title: String
    let theme: AlcoveTheme
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .tracking(0.5)
            FoyerSash(theme: theme)
        }
        .padding(.top, 12)
    }
}

private struct BindingHole: View {
    let theme: AlcoveTheme
    let count: Int
    let spacing: CGFloat

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .fill(theme.fyBorder)
                    .frame(width: 5, height: 5)
            }
        }
    }
}

private extension View {
    func foyerShell(_ theme: AlcoveTheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return self
            .clipShape(shape)
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(theme.isDark ? 0.58 : 0.90), location: 0),
                                .init(color: .white.opacity(theme.isDark ? 0.18 : 0.38), location: 0.45),
                                .init(color: .black.opacity(theme.isDark ? 0.34 : 0.12), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .inset(by: 1.4)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(theme.isDark ? 0.22 : 0.48),
                                .clear,
                                .black.opacity(theme.isDark ? 0.18 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(theme.isDark ? 0.34 : 0.16),
                radius: 9,
                x: 0,
                y: 4
            )
    }

    func houseGlass(_ theme: AlcoveTheme) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(theme.glassTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.glassBorder, lineWidth: 1))
    }

    // 凸起湿玻璃：卡片自己不铺任何壁纸或水珠，底下那层背景的水痕直接透上来。
    // 厚度全靠光影堆：弧面高光 + 外轮廓左上亮右下暗 + 内侧高光 + 三道阴影。
    func foyerCard(_ theme: AlcoveTheme) -> some View {
        let shape = JournalCardShape(tl: 14, bl: 14, br: 18, tr: 18)

        return self
            // 每张按钮只保留一层透光底、一条厚度边和一道短阴影。
            // 水珠来自整块面板的同一张静态纹理，不在滚动时为每个按钮重复合成。
            .background {
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(theme.isDark ? 0.10 : 0.16), location: 0),
                                .init(color: .white.opacity(theme.isDark ? 0.03 : 0.055), location: 0.34),
                                .init(color: .clear, location: 0.66),
                                .init(color: .black.opacity(theme.isDark ? 0.08 : 0.035), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(theme.isDark ? 0.68 : 0.96), location: 0),
                                .init(color: .white.opacity(theme.isDark ? 0.24 : 0.46), location: 0.40),
                                .init(color: theme.fyBorder.opacity(0.48), location: 0.68),
                                .init(color: .black.opacity(theme.isDark ? 0.32 : 0.14), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(theme.isDark ? 0.28 : 0.12),
                radius: 5,
                x: 1,
                y: 3
            )
    }

    // 面板不再自己糊一层，也不再叠第二张壁纸：
    // 它底下就是 HouseBackground，同一张图解码两遍是打开面板卡顿的主因。
    func foyerPanel(_ theme: AlcoveTheme) -> some View {
        background(theme.fyCard)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(theme.fyBorder, lineWidth: 1))
        .shadow(color: theme.fyShadow, radius: 14, y: 6)
        .overlay(alignment: .topTrailing) { FoyerFoldCorner(theme: theme) }
    }
}

// MARK: - Usage

private struct NativeUsageView: View {
    @State private var data: [String: Any] = [:]
    @State private var loading = true
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Usage", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if let rl = data["rate_limits"] as? [String: Any] {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("RATE LIMITS")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.fyAccent)
                                rateLimitRow("Current session",
                                             sub: rl["five_hour"] as? [String: Any], color: .blue)
                                rateLimitRow("Weekly limit",
                                             sub: rl["seven_day"] as? [String: Any], color: .purple)
                            }
                            .padding(14).foyerCard(theme)
                        }
                        if let st = data["session_tokens"] as? [String: Any] {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("CURRENT WINDOW")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.fyAccent)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    statBox(String(format: "$%.2f", (st["cost_usd"] as? Double) ?? 0), "estimated cost")
                                    statBox("\((st["turns"] as? Int) ?? 0)", "turns")
                                    statBox(formatNum((st["total_tokens"] as? Int) ?? 0), "total tokens")
                                    statBox(formatNum((st["output"] as? Int) ?? 0), "output tokens")
                                }
                                detailRow("Input", formatNum((st["input"] as? Int) ?? 0))
                                detailRow("Cache read", formatNum((st["cache_read"] as? Int) ?? 0))
                                detailRow("Cache create", formatNum((st["cache_create"] as? Int) ?? 0))
                            }
                            .padding(14).foyerCard(theme)
                        }
                        if let cx = data["codex"] as? [String: Any],
                           let pri = cx["primary"] as? [String: Any] {
                            rateLimitCard("Codex", sub: pri, color: .orange)
                        }
                        if let rl = data["rate_limits"] as? [String: Any] {
                            Text("Model: \(rl.string("model"))")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textDim)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task {
            if let obj = try? await NativeHouseAPI.object("/api/usage") { data = obj }
            loading = false
        }
    }

    private func rateLimitRow(_ label: String, sub: [String: Any]?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let pct = intVal(sub ?? [:], "used_percent")
            HStack {
                Text(label).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(pct)% used").font(.system(size: 13, weight: .semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.fyCardSub)
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.7))
                        .frame(width: geo.size.width * min(CGFloat(pct), 100) / 100)
                }
            }.frame(height: 8)
            Text("Resets in \(resetText(sub))").font(.system(size: 11)).foregroundColor(theme.textDim)
        }
    }

    private func rateLimitCard(_ label: String, sub: [String: Any], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let pct = intVal(sub, "used_percent")
            HStack {
                Text(label).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(pct)% used").font(.system(size: 13, weight: .semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.fyCardSub)
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.7))
                        .frame(width: geo.size.width * min(CGFloat(pct), 100) / 100)
                }
            }.frame(height: 8)
            Text("Resets in \(resetText(sub))").font(.system(size: 11)).foregroundColor(theme.textDim)
        }
        .padding(14).foyerCard(theme)
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(theme.fyAccent)
            Text(label).font(.system(size: 10)).foregroundColor(theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value).font(.system(size: 12)).foregroundColor(theme.textDim)
        }
    }

    private func resetText(_ sub: [String: Any]?) -> String {
        guard let s = sub, let secs = (s["reset_after_seconds"] as? Int) ?? (s["reset_after_seconds"] as? Double).map(Int.init) else { return "—" }
        let d = secs / 86400, h = (secs % 86400) / 3600, m = (secs % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)min" }
        return "\(m)min"
    }
    private func intVal(_ d: [String: Any], _ k: String) -> Int {
        (d[k] as? Int) ?? Int((d[k] as? Double) ?? 0)
    }
    private func formatNum(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Portrait

private struct NativePortraitView: View {
    @State private var sections: [(String, [String])] = []
    @State private var loading = true
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Portrait", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(sections, id: \.0) { title, items in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(title).font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.fyAccent)
                                ForEach(items, id: \.self) { item in
                                    Text(item)
                                        .font(.system(size: 12))
                                        .lineSpacing(3)
                                        .foregroundColor(theme.textDim)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foyerCard(theme)
                        }
                        if sections.isEmpty {
                            Text("还没有画像数据").font(.system(size: 12))
                                .foregroundColor(theme.textDim).padding(30)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await loadPortrait() }
    }

    private func loadPortrait() async {
        defer { loading = false }
        guard let obj = try? await NativeHouseAPI.object("/api/ob/portrait"),
              let portrait = obj["portrait"] as? [String: Any] else { return }
        var result: [(String, [String])] = []
        for key in ["user", "assistant"] {
            guard let section = portrait[key] as? [String: Any] else { continue }
            let label = key == "user" ? "关于她" : "关于我"
            var texts: [String] = []
            for bufKey in ["stable", "recent_buffer"] {
                if let items = section[bufKey] as? [[String: Any]] {
                    for item in items {
                        if let t = item["text"] as? String, !t.isEmpty { texts.append(t) }
                    }
                }
            }
            if !texts.isEmpty { result.append((label, texts)) }
        }
        sections = result
    }
}

// MARK: - Desire

private struct NativeDesireView: View {
    @State private var data: [String: Any] = [:]
    @State private var loading = true
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private let driveNames: [(String, String)] = [
        ("attachment", "依恋"), ("curiosity", "好奇"), ("reflection", "反思"),
        ("duty", "责任"), ("social", "社交"), ("fatigue", "疲惫"),
        ("libido", "欲望"), ("stress", "压力")
    ]

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Desire", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let intent = data["intent"] as? [String: Any] {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("此刻最想").font(.system(size: 13, weight: .semibold))
                                Text(intent["want_action"] as? String ?? "")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(theme.fyAccent)
                                if let reason = intent["reason"] as? String {
                                    Text(reason).font(.system(size: 11))
                                        .foregroundColor(theme.textDim)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foyerCard(theme)
                        }
                        if let drives = data["drives"] as? [String: Any],
                           let baseline = data["baseline"] as? [String: Any] {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("驱动条").font(.system(size: 13, weight: .semibold))
                                ForEach(driveNames, id: \.0) { key, label in
                                    let val = (drives[key] as? Double) ?? 0
                                    let base = (baseline[key] as? Double) ?? 0
                                    driveRow(label, value: val, baseline: base)
                                }
                            }
                            .padding(14).foyerCard(theme)
                        }
                        if let ranking = data["activity_ranking"] as? [[String: Any]], !ranking.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("想做的事").font(.system(size: 13, weight: .semibold))
                                ForEach(ranking.prefix(5), id: \.description) { item in
                                    HStack {
                                        Text(item["activity"] as? String ?? "")
                                            .font(.system(size: 12))
                                        Spacer()
                                        let score = (item["score"] as? Double) ?? 0
                                        Text(String(format: "%.0f%%", score * 100))
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.textDim)
                                    }
                                }
                            }
                            .padding(14).foyerCard(theme)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task {
            if let obj = try? await NativeHouseAPI.object("/api/desire/state") { data = obj }
            loading = false
        }
    }

    private func driveRow(_ label: String, value: Double, baseline: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.system(size: 11)).frame(width: 32, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.fyCardSub)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(driveColor(value))
                            .frame(width: geo.size.width * min(CGFloat(value), 1))
                    }
                }
                .frame(height: 6)
                Text(String(format: "%.2f", value))
                    .font(.system(size: 10, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
                    .foregroundColor(theme.textDim)
                Text(value > baseline ? "▲" : value < baseline ? "▼" : " ")
                    .font(.system(size: 8))
                    .foregroundColor(value > baseline ? .green : .red)
                    .frame(width: 12)
            }
        }
    }

    private func driveColor(_ val: Double) -> Color {
        if val > 0.8 { return .red.opacity(0.7) }
        if val > 0.5 { return .orange.opacity(0.7) }
        return .blue.opacity(0.5)
    }
}

// MARK: - Forge

private struct NativeForgeView: View {
    @State private var retain: Double = 20
    @State private var preview: [String: Any] = [:]
    @State private var loading = true
    @State private var forging = false
    @State private var result: String?
    @State private var newSessionId: String?
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var totalRounds: Int { (preview["total_rounds"] as? Int) ?? 0 }
    private var retainedRounds: Int { (preview["retained_rounds"] as? Int) ?? 0 }
    private var estimatedTokens: Int { (preview["estimated_tokens"] as? Int) ?? 0 }
    private var valid: Bool { (preview["valid"] as? Bool) ?? false }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Forge 换窗", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("锻造会裁剪对话历史，用更少的token唤醒新窗口。")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textDim)
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foyerCard(theme)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("保留轮次").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(Int(retain)) / \(totalRounds)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.fyAccent)
                            }
                            Slider(value: $retain, in: 0...Double(max(totalRounds, 1)), step: 1)
                                .tint(theme.fyAccent)
                                .onChange(of: retain) { _ in
                                    Task { await loadPreview() }
                                }
                            HStack {
                                infoRow("估算Token", "\(estimatedTokens)")
                                Spacer()
                                infoRow("Warm文", "\((preview["warm_texts"] as? Int) ?? 0)")
                            }
                        }
                        .padding(14).foyerCard(theme)

                        if let firsts = preview["first_messages"] as? [String], !firsts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("开头").font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.fyAccent)
                                ForEach(firsts.prefix(2), id: \.self) { msg in
                                    Text(String(msg.prefix(120)))
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textDim)
                                        .lineSpacing(2)
                                        .lineLimit(3)
                                }
                            }
                            .padding(14).foyerCard(theme)
                        }

                        if let lasts = preview["last_messages"] as? [String], !lasts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("结尾").font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.fyAccent)
                                ForEach(lasts.prefix(2), id: \.self) { msg in
                                    Text(String(msg.prefix(120)))
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textDim)
                                        .lineSpacing(2)
                                        .lineLimit(3)
                                }
                            }
                            .padding(14).foyerCard(theme)
                        }

                        if let result {
                            Text(result)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .padding(14).foyerCard(theme)
                        }

                        if let sid = newSessionId {
                            VStack(spacing: 8) {
                                Text("锻造完成")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(theme.fyAccent)
                                Text("新 session: \(String(sid.prefix(20)))...")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textDim)
                                VStack(spacing: 4) {
                                    Text("在终端输入：")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.textDim)
                                    Text("claude --resume \(sid)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(14).foyerCard(theme)
                        }

                        HStack(spacing: 12) {
                            Button {
                                Task { await executeForge() }
                            } label: {
                                HStack {
                                    if forging {
                                        ProgressView().scaleEffect(0.8).tint(.white)
                                    }
                                    Text(forging ? "锻造中..." : "确认锻造")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(valid && !forging ? theme.fyAccent : theme.fyCardSub,
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundColor(.white)
                            }
                            .disabled(!valid || forging)
                        }

                        if let sid = preview["source_session"] as? String, !sid.isEmpty {
                            VStack(spacing: 2) {
                                Text("当前窗口")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textDim)
                                Text(sid)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(theme.textLight)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10).foyerCard(theme)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await loadPreview() }
    }

    private func loadPreview() async {
        let r = Int(retain)
        if let obj = try? await NativeHouseAPI.object("/api/forge?retain=\(r)") {
            preview = obj
            if loading {
                retain = Double((obj["retained_rounds"] as? Int) ?? r)
            }
        }
        loading = false
    }

    private func executeForge() async {
        forging = true
        defer { forging = false }
        do {
            let obj = try await NativeHouseAPI.object(
                "/api/forge", method: "POST",
                body: ["retain": Int(retain)])
            if let sid = obj["new_session_id"] as? String, !sid.isEmpty {
                newSessionId = sid
                result = nil
            } else {
                result = (obj["error"] as? String) ?? "锻造失败"
            }
        } catch {
            result = "请求失败"
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundColor(theme.textDim)
            Text(value).font(.system(size: 12, weight: .medium))
        }
    }
}

// MARK: - Calendar Grid (shared)

private struct MonthCalendarGrid: View {
    let year: Int
    let month: Int
    let theme: AlcoveTheme
    let dotDates: Set<String>
    let periodDates: [String: String]
    let selectedDate: String?
    let onSelect: (String) -> Void
    let onPrev: () -> Void
    let onNext: () -> Void

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let cal = Calendar(identifier: .gregorian)

    private var todayStr: String {
        let now = Date()
        return String(format: "%04d-%02d-%02d",
                      cal.component(.year, from: now),
                      cal.component(.month, from: now),
                      cal.component(.day, from: now))
    }

    private var days: [String?] {
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let first = cal.date(from: comps) else { return [] }
        let weekday = cal.component(.weekday, from: first) - 1
        let range = cal.range(of: .day, in: .month, for: first) ?? 1..<31
        var result: [String?] = Array(repeating: nil, count: weekday)
        for d in range {
            result.append(String(format: "%04d-%02d-%02d", year, month, d))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onPrev) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.fyAccent)
                        .frame(width: 32, height: 32)
                        .background(theme.fyCardSub, in: Circle())
                }
                Spacer()
                Text("\(String(year))年\(month)月")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.fyAccent)
                        .frame(width: 32, height: 32)
                        .background(theme.fyCardSub, in: Circle())
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(weekdays, id: \.self) { wd in
                    Text(wd).font(.system(size: 11)).foregroundColor(theme.textDim)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, dateStr in
                    if let dateStr {
                        let day = Int(dateStr.suffix(2)) ?? 0
                        let isToday = dateStr == todayStr
                        let isSelected = dateStr == selectedDate
                        let hasDot = dotDates.contains(dateStr)
                        let isPeriod = periodDates[dateStr] != nil

                        Button { onSelect(dateStr) } label: {
                            VStack(spacing: 2) {
                                Text("\(day)")
                                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isToday ? .white : theme.text)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Group {
                                            if isToday {
                                                Circle().fill(theme.fyAccent)
                                            } else if isSelected {
                                                Circle().stroke(theme.fyAccent, lineWidth: 1.5)
                                            } else if isPeriod {
                                                Circle().fill(theme.fyAccent.opacity(0.12))
                                            }
                                        }
                                    )
                                Circle()
                                    .fill(hasDot ? theme.fyAccent : .clear)
                                    .frame(width: 5, height: 5)
                            }
                        }
                    } else {
                        Color.clear.frame(height: 39)
                    }
                }
            }
        }
        .padding(14).foyerCard(theme)
    }
}

// MARK: - Impression (calendar)

private struct NativeImpressionView: View {
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var selectedDate: String?
    @State private var allItems: [(String, String, String)] = []
    @State private var loading = true
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var dotDates: Set<String> {
        Set(allItems.map { $0.0 })
    }

    private var selectedItems: [(String, String, String)] {
        guard let sel = selectedDate else { return [] }
        return allItems.filter { $0.0 == sel }
    }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Impression", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        MonthCalendarGrid(
                            year: year, month: month, theme: theme,
                            dotDates: dotDates, periodDates: [:],
                            selectedDate: selectedDate,
                            onSelect: { selectedDate = $0 },
                            onPrev: { shiftMonth(-1) },
                            onNext: { shiftMonth(1) })

                        if !selectedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("日印象").font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.fyAccent)
                                Text("\(selectedItems.count) 条")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                            ForEach(selectedItems, id: \.1) { date, name, content in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(name).font(.system(size: 13, weight: .semibold))
                                    Text(content)
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textDim)
                                        .lineSpacing(3)
                                        .textSelection(.enabled)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foyerCard(theme)
                            }
                        } else if selectedDate != nil {
                            Text("这天没有日印象")
                                .font(.system(size: 12)).foregroundColor(theme.textDim)
                                .padding(20)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await loadImpressions() }
    }

    private func shiftMonth(_ delta: Int) {
        month += delta
        if month > 12 { month = 1; year += 1 }
        if month < 1 { month = 12; year -= 1 }
        selectedDate = nil
    }

    private func loadImpressions() async {
        defer { loading = false }
        guard let buckets = try? await NativeHouseAPI.request("/api/ob/buckets") as? [[String: Any]] else { return }
        allItems = buckets.compactMap { bucket in
            guard bucket.string("type") == "feel",
                  let tags = bucket["tags"] as? [Any],
                  tags.map(String.init(describing:)).contains("daily_impression") else { return nil }
            let name = bucket.string("name")
            let date = String(bucket.string("date").prefix(10))
            let content = bucket.string("content_preview", "content")
            return (date, name, content)
        }
        if let latest = allItems.first { selectedDate = latest.0 }
    }
}

// MARK: - Calendar (纪念日+日记)

private struct NativeCalendarView: View {
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var selectedDate: String?
    @State private var events: [String: [[String: Any]]] = [:]
    @State private var periodDates: [String: String] = [:]
    @State private var loading = true
    @State private var expandedIdx: Int?
    @State private var diaryContents: [String: String] = [:]
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var dotDates: Set<String> {
        Set(events.keys)
    }

    private var selectedEvents: [[String: Any]] {
        guard let sel = selectedDate else { return [] }
        return events[sel] ?? []
    }

    private var selectedDateLabel: String {
        guard let sel = selectedDate, sel.count >= 10 else { return "" }
        let m = Int(sel.dropFirst(5).prefix(2)) ?? 0
        let d = Int(sel.suffix(2)) ?? 0
        let weekday: String = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            guard let date = fmt.date(from: sel) else { return "" }
            let wd = Calendar.current.component(.weekday, from: date)
            return ["日", "一", "二", "三", "四", "五", "六"][(wd - 1) % 7]
        }()
        return String(format: "%02d月%02d日·周%@", m, d, weekday)
    }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Calendar", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        MonthCalendarGrid(
                            year: year, month: month, theme: theme,
                            dotDates: dotDates, periodDates: periodDates,
                            selectedDate: selectedDate,
                            onSelect: { selectedDate = $0 },
                            onPrev: { shiftMonth(-1) },
                            onNext: { shiftMonth(1) })

                        if periodDates.values.contains(where: { _ in true }) {
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Circle().fill(theme.fyAccent.opacity(0.12)).frame(width: 10, height: 10)
                                    Text("姨妈期").font(.system(size: 10)).foregroundColor(theme.textDim)
                                }
                                Spacer()
                            }.padding(.horizontal, 4)
                        }

                        if !selectedEvents.isEmpty {
                            Text(selectedDateLabel)
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)

                            ForEach(Array(selectedEvents.enumerated()), id: \.offset) { idx, evt in
                                let key = "\(selectedDate ?? "")_\(evt.string("time"))"
                                let isExpanded = expandedIdx == idx
                                Button {
                                    if isExpanded {
                                        expandedIdx = nil
                                    } else {
                                        expandedIdx = idx
                                        if diaryContents[key] == nil {
                                            Task { await loadDiaryContent(key: key, date: selectedDate ?? "", time: evt.string("time")) }
                                        }
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack {
                                            Text("📝").font(.system(size: 20))
                                            Text(evt.string("title"))
                                                .font(.system(size: 13, weight: .medium))
                                            Spacer()
                                            Text(evt.string("time"))
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.textDim)
                                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                                .font(.system(size: 10))
                                                .foregroundColor(theme.textLight)
                                        }
                                        if isExpanded {
                                            Divider().padding(.vertical, 8)
                                            if let content = diaryContents[key] {
                                                Text(content)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(theme.textDim)
                                                    .lineSpacing(4)
                                                    .textSelection(.enabled)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            } else {
                                                ProgressView().scaleEffect(0.7).tint(theme.fyAccent)
                                                    .frame(maxWidth: .infinity).padding(8)
                                            }
                                        }
                                    }
                                    .padding(12).foyerCard(theme)
                                }
                                .buttonStyle(.plain)
                            }
                        } else if selectedDate != nil {
                            Text("这天没有记录")
                                .font(.system(size: 12)).foregroundColor(theme.textDim)
                                .padding(20)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await loadMonth() }
    }

    private func shiftMonth(_ delta: Int) {
        month += delta
        if month > 12 { month = 1; year += 1 }
        if month < 1 { month = 12; year -= 1 }
        selectedDate = nil
        Task { await loadMonth() }
    }

    private func loadMonth() async {
        loading = events.isEmpty
        defer { loading = false }
        guard let obj = try? await NativeHouseAPI.object(
            "/api/calendar/month?year=\(year)&month=\(month)") else { return }
        if let evts = obj["events"] as? [String: Any] {
            events = evts.compactMapValues { $0 as? [[String: Any]] }
        }
        if let prd = obj["period"] as? [String: String] {
            periodDates = prd
        }
        if selectedDate == nil, let first = events.keys.sorted().last {
            selectedDate = first
        }
        expandedIdx = nil
    }

    private func loadDiaryContent(key: String, date: String, time: String) async {
        guard let obj = try? await NativeHouseAPI.object("/api/calendar/day?date=\(date)") else {
            diaryContents[key] = "加载失败"
            return
        }
        let diaries = obj.array("diaries")
        for entry in diaries {
            let ts = entry.string("ts")
            let tsTime = ts.count > 16 ? String(ts.dropFirst(11).prefix(5)) : ""
            if tsTime == time {
                diaryContents[key] = entry.string("content")
                return
            }
        }
        diaryContents[key] = "没有找到内容"
    }
}

// MARK: - Dreams

private struct NativeDreamsView: View {
    @State private var dreams: [[String: Any]] = []
    @State private var loading = true
    @State private var expandedId: String?
    @State private var dreamBodies: [String: String] = [:]
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "Dreams", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(dreams.enumerated()), id: \.offset) { _, dream in
                            let dreamId = dream.string("dream_id")
                            let date = dream.string("local_date")
                            let status = dream.string("status")
                            let hasBody = dream.bool("has_body")
                            let isExpanded = expandedId == dreamId
                            Button {
                                if isExpanded {
                                    expandedId = nil
                                } else {
                                    expandedId = dreamId
                                    if dreamBodies[dreamId] == nil {
                                        Task { await loadDreamBody(dreamId: dreamId, hasBody: hasBody) }
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(alignment: .center) {
                                        Text("🌙").font(.system(size: 20))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(date) 的梦")
                                                .font(.system(size: 14, weight: .medium))
                                            Text("\(date)  知响")
                                                .font(.system(size: 10))
                                                .foregroundColor(theme.textDim)
                                        }
                                        Spacer()
                                        Text(statusLabel(status))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(statusColor(status))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(statusColor(status).opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                    if isExpanded {
                                        Rectangle()
                                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                            .foregroundColor(theme.textLight.opacity(0.3))
                                            .frame(height: 1)
                                            .padding(.vertical, 10)
                                        if let body = dreamBodies[dreamId] {
                                            Text(body)
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.textDim)
                                                .lineSpacing(4)
                                                .textSelection(.enabled)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                        } else {
                                            ProgressView().scaleEffect(0.7).tint(theme.fyAccent)
                                                .frame(maxWidth: .infinity).padding(8)
                                        }
                                    }
                                }
                                .padding(14).foyerCard(theme)
                            }
                            .buttonStyle(.plain)
                        }
                        if dreams.isEmpty {
                            Text("还没有梦")
                                .font(.system(size: 12)).foregroundColor(theme.textDim)
                                .padding(30)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task {
            if let obj = try? await NativeHouseAPI.object("/api/ob/dreams?limit=30"),
               let records = obj["records"] as? [[String: Any]] {
                dreams = records
            }
            loading = false
        }
    }

    private func loadDreamBody(dreamId: String, hasBody: Bool) async {
        guard hasBody else {
            dreamBodies[dreamId] = "这个梦读不回来了"
            return
        }
        if let obj = try? await NativeHouseAPI.object("/api/dreams/read?id=\(dreamId)"),
           obj.bool("ok") {
            dreamBodies[dreamId] = obj.string("body")
        } else {
            dreamBodies[dreamId] = "这个梦读不回来了"
        }
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "surfaced": return "浮现过"
        case "forgotten": return "遗忘了"
        case "generated": return "待浮现"
        default: return s
        }
    }
    private func statusIcon(_ s: String) -> String {
        switch s {
        case "surfaced": return "moon.stars.fill"
        case "forgotten": return "cloud.fog"
        default: return "moon.zzz"
        }
    }
    private func statusColor(_ s: String) -> Color {
        switch s {
        case "surfaced": return .purple.opacity(0.7)
        case "forgotten": return .gray
        default: return .blue.opacity(0.6)
        }
    }
}
