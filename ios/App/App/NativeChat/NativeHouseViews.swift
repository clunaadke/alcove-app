import SwiftUI
import PhotosUI
import AVFoundation
import WebKit

enum HouseDestination: String, Identifiable, CaseIterable {
    case sidebar, chat, terminal, settings, bubbleAppearance, checklist, music
    case home, calendar, wall, usage
    case memory, dreams, shelf, desire, nianlun, clockwork, album, portrait, impression
    case crosstalk, radio, coread, liao, daddyDay
    case search, favorites, forge, roundtable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sidebar: return "Alcove"
        case .home: return "大厅"
        case .chat: return "Chat"
        case .terminal: return "Terminal"
        case .settings: return "设置"
        case .bubbleAppearance: return "气泡与文字"
        case .checklist: return "Checklist"
        case .music: return "Music"
        case .calendar: return "Calendar"
        case .wall: return "小黑屋"
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
        case .roundtable: return "圆桌"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .chat: return "bubble.left"
        case .terminal: return "terminal"
        case .settings: return "gearshape"
        case .bubbleAppearance: return "slider.horizontal.3"
        case .checklist: return "checklist"
        case .music: return "music.note"
        case .calendar, .impression: return "calendar"
        case .wall: return "lock.rectangle.stack"
        case .desire: return "heart"
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
        case .roundtable: return "person.3.sequence"
        default: return "sparkles"
        }
    }
}

struct NativeHouseSheet: View {
    let initial: HouseDestination
    var showTerminal: () -> Void
    var showRoundtable: () -> Void = {}
    var roundtableUnread: Int = 0
    @Environment(\.dismiss) private var dismiss
    @State private var route: HouseDestination
    @State private var preparedTexture: UIImage?
    @State private var preparedTextureName: String
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("bubbleGlassStrength") private var bubbleGlassStrength = 56.81
    @AppStorage("bubbleGlassDispersion") private var bubbleGlassDispersion = 0.39
    @AppStorage("bubbleGlassRimWidth") private var bubbleGlassRimWidth = 0.28
    @AppStorage("bubbleGlassMagnify") private var bubbleGlassMagnify = 0.0
    @AppStorage("bubbleGlassBlur") private var bubbleGlassBlur = 0.10
    @AppStorage("bubbleGlassSize") private var bubbleGlassSize = 174.33

    init(
        initial: HouseDestination,
        preparedTexture: UIImage? = nil,
        preparedTextureName: String = "",
        showTerminal: @escaping () -> Void,
        showRoundtable: @escaping () -> Void = {},
        roundtableUnread: Int = 0
    ) {
        self.initial = initial
        self.showTerminal = showTerminal
        self.showRoundtable = showRoundtable
        self.roundtableUnread = roundtableUnread
        _route = State(initialValue: initial)
        _preparedTexture = State(initialValue: preparedTexture)
        _preparedTextureName = State(initialValue: preparedTextureName)
    }

    private var theme: AlcoveTheme { .panelNamed(themeName) }

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

    private var panelWallpaperDescriptor: ChatWallpaperDescriptor {
        ChatWallpaperDescriptor(
            source: .layeredPanel(
                preparedImage: preparedTextureName == theme.panelTextureAsset
                    ? preparedTexture
                    : nil,
                asset: theme.panelTextureAsset,
                gradient: theme.splashBg,
                textureOpacity: theme.isDark ? 0.72 : 0.68
            )
        )
    }

    var body: some View {
        GeometryReader { root in
            FoyerGlassContainer(spacing: 8) {
                ZStack {
                    Group {
                switch route {
                case .sidebar:
                    NativeSidebarView(select: select, roundtableUnread: roundtableUnread)
                case .settings:
                    NativeSettingsView(
                        showPermissions: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                NotificationCenter.default.post(name: .alcoveShowPermissions, object: nil)
                            }
                        },
                        showBubbleAppearance: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                route = .bubbleAppearance
                            }
                        }
                    )
                case .bubbleAppearance:
                    BubbleAppearanceSettingsView()
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
                case .wall:
                    NativeWallView()
                default:
                    NativeDataPanel(destination: route)
                }
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
        .coordinateSpace(name: "alcoveChatRoot")
        .environment(\.chatWallpaperDescriptor, panelWallpaperDescriptor)
        .environment(\.chatWallpaperViewportSize, root.size)
        .environment(\.bubbleGlassStyle, bubbleGlassStyle)
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .overlay(alignment: .topLeading) {
            if route != .sidebar {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        route = route == .bubbleAppearance ? .settings : .sidebar
                    }
                } label: {
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
        // 圆桌走全屏那条路，跟聊天页一样，不做成 86% 的半截面板
        case .roundtable:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) { showRoundtable() }
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
    let roundtableUnread: Int
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
                    summaryCard("小黑屋", model.wallLine, "lock.rectangle.stack.fill", .wall)
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
                destinationRow([.roundtable, .search, .favorites, .forge])
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
                    .overlay(alignment: .topTrailing) {
                        if target == .roundtable && roundtableUnread > 0 {
                            Text(roundtableUnread > 99 ? "99+" : "\(roundtableUnread)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 15, minHeight: 15)
                                .background(Color.red, in: Capsule())
                                .offset(x: 11, y: -9)
                        }
                    }
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
        var wallLine = "--"
        var usageLine = "--"
    }

    @Published private var snapshot = Snapshot()
    var homeLine: String { snapshot.homeLine }
    var wallLine: String { snapshot.wallLine }
    var usageLine: String { snapshot.usageLine }

    let days = max(1, Calendar.current.dateComponents(
        [.day], from: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_272_000)),
        to: Calendar.current.startOfDay(for: Date())).day ?? 1)

    func load() async {
        async let doll = try? NativeHouseAPI.object("/api/dollhouse/state")
        async let wall = try? NativeHouseAPI.object("/api/wall/entries")
        async let usage = try? NativeHouseAPI.object("/api/usage")

        let (dollResult, wallResult, usageResult) = await (doll, wall, usage)
        var next = Snapshot()

        if let d = dollResult {
            next.homeLine = "亲密度 \(d.int("intimacy")) · 金币 \(d.int("coins"))"
        }
        if let w = wallResult {
            let locked = w.int("locked")
            let opened = w.int("opened")
            next.wallLine = (locked + opened) == 0 ? "墙还是空的" : "\(locked) 道锁着 · \(opened) 道开了"
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
    var showBubbleAppearance: () -> Void
    @AppStorage("assistantName") private var assistantName = "陈璟"
    @AppStorage("userName") private var userName = "Luna"
    @AppStorage("assistantAvatarDataURL") private var assistantAvatar = ""
    @AppStorage("userAvatarDataURL") private var userAvatar = ""
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("wallStamp") private var wallStamp = 0.0
    @State private var aiPhoto: PhotosPickerItem?
    @State private var userPhoto: PhotosPickerItem?
    @State private var wallPhoto: PhotosPickerItem?
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                panelTitle("设置")
                section("聊天") {
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
                section("聊天外观") {
                    Button(action: showBubbleAppearance) {
                        settingRow("气泡与文字", "在聊天壁纸上实时预览并调节") {
                            Image(systemName: "chevron.right")
                                .foregroundColor(theme.textLight)
                        }
                    }
                    .buttonStyle(.plain)
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

    private func resetWallpaper() {
        let file = themeName == "midnight" ? "chatwall_midnight.jpg" : "chatwall_haven.jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(file)
        try? FileManager.default.removeItem(at: url)
        wallStamp = Date().timeIntervalSince1970
    }
}


private struct BubbleAppearanceSettingsView: View {
    @StateObject private var wallpaperStore = ChatWallpaperStore()
    @AppStorage("assistantName") private var assistantName = "陈璟"
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("chatFontSize") private var fontSize = 14
    @AppStorage("wallStamp") private var wallStamp = 0.0
    @AppStorage("bubbleGlassStrength") private var bubbleGlassStrength = 56.81
    @AppStorage("bubbleGlassDispersion") private var bubbleGlassDispersion = 0.39
    @AppStorage("bubbleGlassRimWidth") private var bubbleGlassRimWidth = 0.28
    @AppStorage("bubbleGlassMagnify") private var bubbleGlassMagnify = 0.0
    @AppStorage("bubbleGlassBlur") private var bubbleGlassBlur = 0.10
    @AppStorage("bubbleGlassSize") private var bubbleGlassSize = 174.33

    private var panelTheme: AlcoveTheme { .panelNamed(themeName) }
    private var chatTheme: AlcoveTheme { .named(themeName) }
    private var bubbleStyle: BubbleGlassStyle {
        BubbleGlassStyle(
            strength: CGFloat(bubbleGlassStrength),
            dispersion: CGFloat(bubbleGlassDispersion),
            rimWidth: CGFloat(bubbleGlassRimWidth),
            magnify: CGFloat(bubbleGlassMagnify),
            backdropBlur: CGFloat(bubbleGlassBlur),
            size: CGFloat(bubbleGlassSize)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Text("气泡与文字")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 11)

                livePreview

                section("文字") {
                    fontSizeSlider
                }

                section("液态玻璃气泡") {
                    VStack(spacing: 10) {
                        glassSliderRow("扭曲", "strength", $bubbleGlassStrength, 0...60)
                        glassSliderRow("色散", "dispersion", $bubbleGlassDispersion, 0...3)
                        glassSliderRow("过渡", "rimWidth", $bubbleGlassRimWidth, 0.2...0.95)
                        glassSliderRow("放大", "magnify", $bubbleGlassMagnify, 0...1.5)
                        glassSliderRow("背景模糊", "blur", $bubbleGlassBlur, 0...8)
                        glassSliderRow("直径", "size", $bubbleGlassSize, 80...340)
                    }
                    Divider().opacity(0.25)
                    HStack {
                        Text("上方预览与聊天页同步生效")
                            .font(.system(size: 10))
                            .foregroundColor(panelTheme.textLight)
                        Spacer()
                        Button("恢复默认") { resetAppearance() }
                            .font(.system(size: 11, weight: .medium))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .foregroundColor(panelTheme.text)
        }
        .onAppear { refreshWallpaper() }
        .onChange(of: themeName) { _ in refreshWallpaper() }
        .onChange(of: wallStamp) { _ in refreshWallpaper() }
    }

    private var livePreview: some View {
        GeometryReader { proxy in
            ZStack {
                ChatWallpaperRenderer(descriptor: wallpaperStore.descriptor)

                VStack(spacing: 14) {
                    previewBubble(
                        "\(assistantName)，气泡再透一点\n字也松一点",
                        isUser: true
                    )
                    previewBubble(
                        "好，就在这里慢慢调\n我陪你看每一下变化",
                        isUser: false
                    )
                }
                .padding(16)
            }
            .coordinateSpace(name: "alcoveChatRoot")
            .environment(\.chatWallpaperDescriptor, wallpaperStore.descriptor)
            .environment(\.chatWallpaperViewportSize, proxy.size)
            .environment(\.bubbleGlassStyle, bubbleStyle)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(panelTheme.fyBorder, lineWidth: 1)
        )
        .shadow(color: panelTheme.fyShadow, radius: 8, y: 3)
    }

    private func previewBubble(_ text: String, isUser: Bool) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Text(text)
                .font(.system(size: CGFloat(fontSize)))
                .lineSpacing(5)
                .foregroundColor(chatTheme.text)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    BubbleGlassBackground(
                        tintColor: isUser ? chatTheme.bubbleUser : chatTheme.bubbleAI,
                        tintOpacity: isUser ? 0.14 : 0.09,
                        style: bubbleStyle
                    )
                }

            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity)
    }

    private var fontSizeSlider: some View {
        let value = Binding<Double>(
            get: { Double(fontSize) },
            set: { fontSize = Int($0.rounded()) }
        )

        return HStack(spacing: 9) {
            Text("字体大小")
                .font(.system(size: 12))
                .frame(width: 100, alignment: .leading)

            Slider(value: value, in: 11...20, step: 1)
                .tint(panelTheme.fyAccent)

            Text("\(fontSize) pt")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(panelTheme.textDim)
                .frame(width: 45, alignment: .trailing)
        }
    }

    @ViewBuilder private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundColor(panelTheme.fyAccent.opacity(0.8))
                LinearGradient(
                    colors: [panelTheme.fyAccentSoft, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
            }
            VStack(spacing: 10) { content() }
                .padding(13)
                .foyerCard(panelTheme)
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
                    .foregroundColor(panelTheme.textLight)
            }
            .font(.system(size: 11))
            .frame(width: 100, alignment: .leading)

            Slider(value: value, in: range)
                .tint(panelTheme.fyAccent)

            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(panelTheme.textDim)
                .frame(width: 45, alignment: .trailing)
        }
    }

    private func refreshWallpaper() {
        wallpaperStore.refresh(
            themeName: themeName,
            theme: chatTheme,
            wallStamp: wallStamp
        )
    }

    private func resetAppearance() {
        fontSize = 14
        bubbleGlassStrength = 56.81
        bubbleGlassDispersion = 0.39
        bubbleGlassRimWidth = 0.28
        bubbleGlassMagnify = 0
        bubbleGlassBlur = 0.10
        bubbleGlassSize = 174.33
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

struct MusicSong: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let artist: String
    let cover: String
    var message: String = ""

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
        let rawCover = json.object("al").string("picUrl").isEmpty
            ? json.string("cover", "picUrl") : json.object("al").string("picUrl")
        cover = Self.secureURL(rawCover)
        message = json.string("message")
    }

    init(id: String, name: String, artist: String, cover: String, message: String = "") {
        self.id = id
        self.name = name
        self.artist = artist
        self.cover = Self.secureURL(cover)
        self.message = message
    }

    static func card(from text: String) -> MusicSong? {
        let prefix = "[MUSIC_CARD]", suffix = "[/MUSIC_CARD]"
        guard text.hasPrefix(prefix), text.hasSuffix(suffix) else { return nil }
        let start = text.index(text.startIndex, offsetBy: prefix.count)
        let end = text.index(text.endIndex, offsetBy: -suffix.count)
        guard let data = String(text[start..<end]).data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return MusicSong(raw)
    }

    static func secureURL(_ raw: String) -> String {
        raw.hasPrefix("http://") ? "https://" + String(raw.dropFirst("http://".count)) : raw
    }
}

@MainActor
struct MusicLyric: Identifiable, Equatable {
    let id = UUID()
    let time: Double
    let text: String
    let translation: String?
}

struct MusicPlaylist: Identifiable, Equatable {
    let id: String
    let name: String
    let cover: String
    let count: Int

    init(_ json: [String: Any]) {
        id = json.string("id")
        name = json.string("name")
        cover = MusicSong.secureURL(json.string("coverImgUrl", "picUrl"))
        count = json.int("trackCount")
    }
}

@MainActor
final class MusicModel: ObservableObject {
    static let shared = MusicModel()
    @Published var songs: [MusicSong] = []
    @Published var nowPlaying: MusicSong?
    @Published var isPlaying = false
    @Published var loading = false
    @Published var message = ""
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var lyrics: [MusicLyric] = []
    @Published var lyricsLoading = false
    @Published var playlists: [MusicPlaylist] = []
    @Published var recommended: [MusicPlaylist] = []
    @Published var playlistSongs: [MusicSong] = []
    @Published var homeLoading = false
    @Published var likedSongIDs: Set<String> = []
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playHistory: [MusicSong] = []
    private var historyIndex = -1
    private var playbackPoll: Task<Void, Never>?

    func search(_ query: String) async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !q.isEmpty else { return }
        loading = true
        message = ""
        defer { loading = false }
        guard let obj = try? await NativeHouseAPI.object("/api/music/cloudsearch?keywords=\(q)") else {
            songs = []
            message = "没连上音乐服务"
            return
        }
        songs = obj.object("result").array("songs").map(MusicSong.init)
        if songs.isEmpty { message = "没搜到  换个词试试" }
    }

    func play(_ song: MusicSong) async {
        guard let obj = try? await NativeHouseAPI.object("/api/music/song/url?id=\(song.id)"),
              let rows = obj["data"] as? [[String: Any]],
              let raw = rows.first?.string("url"), !raw.isEmpty else {
            message = "这首暂时放不了"
            return
        }
        let url = raw.hasPrefix("/") ? AlcoveAPI.fullURL(raw)
            : URL(string: MusicSong.secureURL(raw))
        guard let url else {
            message = "播放地址坏了"
            return
        }
        message = ""
        cleanup()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            message = "音频通道没打开"
        }
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
        await loadLyrics(song.id)
        await reportNowPlaying()
    }

    func loadHome() async {
        guard playlists.isEmpty else { return }
        homeLoading = true
        defer { homeLoading = false }
        async let mine = try? NativeHouseAPI.object("/api/music/user/playlist?uid=1441382791&limit=50")
        async let recs = try? NativeHouseAPI.object("/api/music/recommend/resource")
        async let likes = try? NativeHouseAPI.object("/api/music/likelist")
        let (myObject, recObject, likeObject) = await (mine, recs, likes)
        playlists = (myObject?["playlist"] as? [[String: Any]] ?? []).map(MusicPlaylist.init)
        recommended = (recObject?["recommend"] as? [[String: Any]] ?? []).map(MusicPlaylist.init)
        likedSongIDs = Set((likeObject?["ids"] as? [Any] ?? []).compactMap {
            if let n = $0 as? NSNumber { return n.stringValue }
            return $0 as? String
        })
    }

    func toggleLike() async {
        guard let song = nowPlaying else { return }
        let shouldLike = !likedSongIDs.contains(song.id)
        guard (try? await NativeHouseAPI.object(
            "/api/music/like?id=\(song.id)&like=\(shouldLike ? "true" : "false")")) != nil else {
            message = "红心没点上"; return
        }
        if shouldLike { likedSongIDs.insert(song.id) }
        else { likedSongIDs.remove(song.id) }
    }

    var currentIsLiked: Bool {
        guard let id = nowPlaying?.id else { return false }
        return likedSongIDs.contains(id)
    }

    func loadPlaylist(_ playlist: MusicPlaylist) async {
        loading = true
        defer { loading = false }
        guard let obj = try? await NativeHouseAPI.object(
            "/api/music/playlist/track/all?id=\(playlist.id)&limit=500") else {
            playlistSongs = []; message = "歌单没拉下来"; return
        }
        playlistSongs = (obj["songs"] as? [[String: Any]] ?? []).map(MusicSong.init)
        songs = playlistSongs
    }

    func toggle() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func stopAndClear() {
        player?.pause()
        cleanup()
        player = nil
        nowPlaying = nil
        isPlaying = false
        progress = 0
        duration = 0
        lyrics = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        progress = seconds
    }

    func startRemotePolling() {
        guard playbackPoll == nil else { return }
        playbackPoll = Task { [weak self] in
            while !Task.isCancelled {
                await self?.consumeRemoteCommand()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func consumeRemoteCommand() async {
        guard let obj = try? await NativeHouseAPI.object("/api/playback"),
              !obj.bool("consumed"), let command = obj["command"] as? String else { return }
        switch command {
        case "set":
            if let raw = obj["song"] as? [String: Any] {
                var song = MusicSong(raw)
                if song.message.isEmpty { song.message = obj.string("message") }
                await play(song)
            }
        case "play": if !isPlaying { toggle() }
        case "pause": if isPlaying { toggle() }
        case "next": next()
        case "prev": prev()
        default: break
        }
        try? await NativeHouseAPI.post("/api/playback", body: ["command": "ack"])
    }

    private func reportNowPlaying() async {
        guard let song = nowPlaying else { return }
        try? await NativeHouseAPI.post("/api/playback", body: [
            "command": "report",
            "now_playing": ["id": song.id, "name": song.name, "artist": song.artist,
                            "paused": !isPlaying, "time": Int(progress), "duration": Int(duration)]
        ])
    }

    func loadLyrics(_ songID: String) async {
        lyricsLoading = true
        defer { lyricsLoading = false }
        guard let obj = try? await NativeHouseAPI.object("/api/music/lyric?id=\(songID)") else {
            lyrics = []; return
        }
        let base = Self.parseLRC(obj.object("lrc").string("lyric"))
        let translated = Self.parseLRC(obj.object("tlyric").string("lyric"))
            .reduce(into: [Int: String]()) { $0[$1.timeKey] = $1.text }
        lyrics = base.map { MusicLyric(time: $0.time, text: $0.text,
                                       translation: translated[$0.timeKey]) }
    }

    private struct ParsedLyric { let time: Double; let text: String; let timeKey: Int }
    private static func parseLRC(_ raw: String) -> [ParsedLyric] {
        let pattern = #"\[(\d+):(\d+)(?:\.(\d+))?\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return raw.components(separatedBy: .newlines).compactMap { line in
            let range = NSRange(line.startIndex..., in: line)
            guard let m = regex.firstMatch(in: line, range: range), m.numberOfRanges == 5,
                  let mr = Range(m.range(at: 1), in: line),
                  let sr = Range(m.range(at: 2), in: line),
                  let tr = Range(m.range(at: 4), in: line),
                  let min = Double(line[mr]), let sec = Double(line[sr]) else { return nil }
            var fraction = 0.0
            if let fr = Range(m.range(at: 3), in: line) {
                let digits = String(line[fr])
                fraction = (Double(digits) ?? 0) / pow(10, Double(digits.count))
            }
            let time = min * 60 + sec + fraction
            let text = String(line[tr]).trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : ParsedLyric(time: time, text: text,
                                                     timeKey: Int((time * 100).rounded()))
        }.sorted { $0.time < $1.time }
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
    @ObservedObject private var model = MusicModel.shared
    @State private var query = ""
    @State private var selectedPlaylist: MusicPlaylist?
    @State private var showPlayer = false
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: selectedPlaylist?.name ?? "音乐", theme: theme)
            searchBar
            if let selectedPlaylist { playlistPage(selectedPlaylist) }
            else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.songs.isEmpty {
                songList(model.songs)
            } else { homePage }
            if model.nowPlaying != nil {
                MusicMiniPlayer(model: model) { showPlayer = true }
                    .padding(.horizontal, 14).padding(.bottom, 12)
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await model.loadHome() }
        .sheet(isPresented: $showPlayer) {
            MusicPlayerSheet(model: model)
                .presentationDetents([.fraction(0.72)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var searchBar: some View {
        HStack {
            if selectedPlaylist != nil {
                Button { selectedPlaylist = nil; model.playlistSongs = [] } label: {
                    Image(systemName: "chevron.left")
                }.buttonStyle(.plain)
            }
            Image(systemName: "magnifyingglass").foregroundColor(theme.textLight)
            TextField("搜索歌名或歌手", text: $query)
                .submitLabel(.search)
                .onSubmit { selectedPlaylist = nil; Task { await model.search(query) } }
            if model.loading { ProgressView().controlSize(.small).tint(theme.fyAccent) }
            else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { selectedPlaylist = nil; Task { await model.search(query) } } label: {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 19))
                }.buttonStyle(.plain)
            }
        }.padding(11).foyerCard(theme).padding(.horizontal, 16).padding(.top, 10)
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 13) {
                    AsyncImage(url: URL(string: "https://p1.music.126.net/_D-Yb1jPhcxPfnp66P1uYA==/109951170625651054.jpg")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { theme.fyCardSub }
                    .frame(width: 58, height: 58).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("hxhxhxxxxn").font(.system(size: 19, weight: .semibold))
                        Text("网易云音乐 · 已连接").font(.system(size: 11)).foregroundColor(theme.textDim)
                    }
                    Spacer()
                }.padding(14).foyerCard(theme)

                if let liked = model.playlists.first {
                    Button { open(liked) } label: {
                        HStack(spacing: 13) {
                            AsyncImage(url: URL(string: liked.cover)) { $0.resizable().scaledToFill() }
                                placeholder: { theme.fyCardSub }
                                .frame(width: 68, height: 68).clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("我喜欢的音乐").font(.system(size: 17, weight: .semibold))
                                Text("\(liked.count) 首").font(.system(size: 11)).foregroundColor(theme.textDim)
                            }
                            Spacer(); Image(systemName: "heart.fill").foregroundColor(theme.fyAccent)
                        }.padding(12).foyerCard(theme)
                    }.buttonStyle(.plain)
                }

                playlistSection("我的歌单", items: Array(model.playlists.dropFirst()))
                playlistSection("为你推荐", items: model.recommended)
            }.padding(.horizontal, 16).padding(.vertical, 14)
        }
        .overlay { if model.homeLoading { ProgressView().tint(theme.fyAccent) } }
    }

    private func playlistSection(_ title: String, items: [MusicPlaylist]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title).font(.system(size: 17, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(items) { playlist in
                    Button { open(playlist) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            AsyncImage(url: URL(string: playlist.cover)) { $0.resizable().scaledToFill() }
                                placeholder: { theme.fyCardSub }
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                            Text(playlist.name).font(.system(size: 11, weight: .medium)).lineLimit(2)
                            Text("\(playlist.count) 首").font(.system(size: 9)).foregroundColor(theme.textDim)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func playlistPage(_ playlist: MusicPlaylist) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                AsyncImage(url: URL(string: playlist.cover)) { $0.resizable().scaledToFill() }
                    placeholder: { theme.fyCardSub }
                    .frame(width: 82, height: 82).clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 7) {
                    Text(playlist.name).font(.system(size: 17, weight: .semibold)).lineLimit(2)
                    Text("\(playlist.count) 首").font(.system(size: 11)).foregroundColor(theme.textDim)
                    Button { if let first = model.playlistSongs.first { Task { await model.play(first) } } } label: {
                        Label("播放全部", systemImage: "play.fill").font(.system(size: 11, weight: .medium))
                    }.buttonStyle(.borderedProminent).tint(theme.fyAccent)
                }; Spacer()
            }.padding(14)
            songList(model.playlistSongs)
        }.overlay { if model.loading { ProgressView().tint(theme.fyAccent) } }
    }

    private func songList(_ songs: [MusicSong]) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 5) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    Button { Task { await model.play(song) } } label: {
                        HStack(spacing: 11) {
                            Text("\(index + 1)").font(.system(size: 11, design: .monospaced))
                                .foregroundColor(theme.textLight).frame(width: 24)
                            AsyncImage(url: URL(string: song.cover)) { $0.resizable().scaledToFill() }
                                placeholder: { theme.fyCardSub }
                                .frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                Text(song.artist).font(.system(size: 10)).foregroundColor(theme.textDim).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: model.nowPlaying?.id == song.id && model.isPlaying ? "waveform" : "play.fill")
                                .foregroundColor(theme.fyAccent)
                        }.padding(.horizontal, 10).padding(.vertical, 6)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private func open(_ playlist: MusicPlaylist) {
        query = ""
        selectedPlaylist = playlist
        Task { await model.loadPlaylist(playlist) }
    }
}

struct MusicMessageCard: View {
    let song: MusicSong
    let theme: AlcoveTheme
    let play: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("♫ 为你点播")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textDim)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                    Text(song.artist).font(.system(size: 13)).foregroundColor(theme.textDim).lineLimit(1)
                }
                Spacer(minLength: 8)
                AsyncImage(url: URL(string: song.cover)) { image in
                    image.resizable().scaledToFill()
                } placeholder: { theme.fyCardSub }
                .frame(width: 58, height: 58)
                .clipShape(Circle())
                Button(action: play) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.text)
                        .frame(width: 44, height: 44)
                        .background(theme.fyCardSub, in: Circle())
                }.buttonStyle(.plain)
            }
            if !song.message.isEmpty {
                Text("›  \(song.message)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textDim)
                    .lineLimit(3)
            }
            Capsule().fill(theme.fyAccent.opacity(0.65)).frame(height: 2)
        }
        .padding(14)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(theme.fyCard.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.fyBorder, lineWidth: 1))
    }
}

struct MusicMiniPlayer: View {
    @ObservedObject var model: MusicModel
    let open: () -> Void
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    var body: some View {
        if let song = model.nowPlaying {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: song.cover)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { theme.glassTint }
                    .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(song.artist).font(.system(size: 11)).foregroundColor(theme.textDim).lineLimit(1)
                    }
                }.contentShape(Rectangle()).onTapGesture(perform: open)
                Spacer()
                Button { model.prev() } label: { Image(systemName: "backward.fill") }.buttonStyle(.plain)
                Button { model.toggle() } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").frame(width: 30, height: 32)
                }.buttonStyle(.plain)
                Button { model.next() } label: { Image(systemName: "forward.fill") }.buttonStyle(.plain)
                Button { model.stopAndClear() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .medium)).frame(width: 28, height: 32)
                }.buttonStyle(.plain)
            }
            .foregroundColor(theme.text)
            .padding(.horizontal, 10).frame(height: 62)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(theme.capsuleTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                GeometryReader { geo in
                    Capsule().fill(theme.fyAccent)
                        .frame(width: geo.size.width * CGFloat(model.duration > 0 ? model.progress / model.duration : 0), height: 2)
                }.frame(height: 2)
            }
        }
    }
}

struct MusicPlayerSheet: View {
    @ObservedObject var model: MusicModel
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        ZStack {
            if let cover = model.nowPlaying?.cover {
                AsyncImage(url: URL(string: cover)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    LinearGradient(colors: theme.splashBg, startPoint: .top, endPoint: .bottom)
                }
                .blur(radius: 48).scaleEffect(1.3).opacity(0.42).ignoresSafeArea()
            }
            LinearGradient(colors: theme.splashBg, startPoint: .top, endPoint: .bottom)
                .opacity(0.36).ignoresSafeArea()
            TabView {
                playerPage
                lyricPage
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .padding(.top, 10)
        }
        .foregroundColor(theme.text)
    }

    private var playerPage: some View {
        VStack(spacing: 18) {
            if let song = model.nowPlaying {
                AsyncImage(url: URL(string: song.cover)) { image in
                    image.resizable().scaledToFill()
                } placeholder: { theme.fyCardSub }
                .frame(width: 230, height: 230).clipShape(Circle())
                .padding(14)
                .background(Circle().fill(.black.opacity(0.22)))
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                Text(song.name).font(.system(size: 20, weight: .semibold)).lineLimit(1)
                Text(song.artist).font(.system(size: 13)).foregroundColor(theme.textDim)
                Button { Task { await model.toggleLike() } } label: {
                    Image(systemName: model.currentIsLiked ? "heart.fill" : "heart")
                        .font(.system(size: 26))
                        .foregroundColor(model.currentIsLiked ? .red : theme.text)
                }.buttonStyle(.plain)
                VStack(spacing: 5) {
                    Slider(value: Binding(get: { model.progress }, set: { model.seek(to: $0) }),
                           in: 0...max(model.duration, 1)).tint(theme.fyAccent)
                    HStack {
                        Text(Self.time(model.progress)); Spacer(); Text(Self.time(model.duration))
                    }.font(.system(size: 10, design: .monospaced)).foregroundColor(theme.textDim)
                }.padding(.horizontal, 28)
                HStack(spacing: 42) {
                    Button { model.prev() } label: { Image(systemName: "backward.fill") }
                    Button { model.toggle() } label: {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 23)).frame(width: 58, height: 58)
                            .background(theme.fyAccent, in: Circle()).foregroundColor(.white)
                    }
                    Button { model.next() } label: { Image(systemName: "forward.fill") }
                }.font(.system(size: 20)).buttonStyle(.plain)
            }
            Spacer(minLength: 4)
        }.padding(.horizontal, 18)
    }

    private var lyricPage: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .center, spacing: 18) {
                    Color.clear.frame(height: 100)
                    if model.lyricsLoading { ProgressView().frame(maxWidth: .infinity) }
                    else if model.lyrics.isEmpty {
                        Text("这首没有歌词").foregroundColor(theme.textDim).frame(maxWidth: .infinity)
                    } else {
                        ForEach(Array(model.lyrics.enumerated()), id: \.element.id) { index, line in
                            Button { model.seek(to: line.time) } label: {
                                VStack(alignment: .center, spacing: 5) {
                                    Text(line.text).font(.system(size: index == activeLyric ? 19 : 15,
                                                                weight: index == activeLyric ? .semibold : .regular))
                                        .multilineTextAlignment(.center)
                                    if let trans = line.translation, !trans.isEmpty {
                                        Text(trans).font(.system(size: 11)).foregroundColor(theme.textDim)
                                            .multilineTextAlignment(.center)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .center)
                                    .opacity(index == activeLyric ? 1 : 0.48)
                            }.buttonStyle(.plain).id(index)
                        }
                    }
                    Color.clear.frame(height: 160)
                }.frame(maxWidth: .infinity).padding(.horizontal, 26)
            }
            .overlay(alignment: .bottom) {
                Button { Task { await model.toggleLike() } } label: {
                    Image(systemName: model.currentIsLiked ? "heart.fill" : "heart")
                        .font(.system(size: 25))
                        .foregroundColor(model.currentIsLiked ? .red : theme.text)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                }.buttonStyle(.plain).padding(.bottom, 20)
            }
            .onChange(of: activeLyric) { idx in
                guard idx >= 0 else { return }
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(idx, anchor: .center) }
            }
        }
    }

    private var activeLyric: Int {
        model.lyrics.lastIndex(where: { $0.time <= model.progress }) ?? -1
    }
    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
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

private struct FoyerGlassContainer<Content: View>: View {
    let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

private struct FoyerCardGlassBackground: View {
    let theme: AlcoveTheme
    @Environment(\.bubbleGlassStyle) private var bubbleGlassStyle

    var body: some View {
        BubbleGlassBackground(
            tintColor: theme.fyCard,
            tintOpacity: theme.isDark ? 0.12 : 0.10,
            style: bubbleGlassStyle,
            cornerRadius: 16
        )
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

    // 面板卡片与聊天气泡共用同一套折射、高光和六个调节参数。
    // iOS 26 必须把系统玻璃直接应用到内容视图，确保图标和文字绘制在玻璃上方。
    @ViewBuilder
    func foyerCard(_ theme: AlcoveTheme) -> some View {
        let shape = JournalCardShape(tl: 14, bl: 14, br: 18, tr: 18)

        if #available(iOS 26.0, *) {
            self
                .glassEffect(
                    .regular.tint(theme.fyCard.opacity(theme.isDark ? 0.16 : 0.11)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .contentShape(shape)
                .shadow(
                    color: .black.opacity(theme.isDark ? 0.28 : 0.12),
                    radius: 5,
                    x: 1,
                    y: 3
                )
        } else {
            self
                .background {
                    FoyerCardGlassBackground(theme: theme)
                }
                .contentShape(shape)
                .shadow(
                    color: .black.opacity(theme.isDark ? 0.28 : 0.12),
                    radius: 5,
                    x: 1,
                    y: 3
                )
        }
    }

    // Detail pages sit directly on the shared wet-glass wallpaper.
    // Keep their content and spacing intact; remove only the extra dark shell.
    func foyerPanel(_ theme: AlcoveTheme) -> some View {
        self
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

private struct EmotionDimension: Identifiable {
    let key: String
    let name: String
    let color: Color
    var id: String { key }
}

private struct EmotionGroup: Identifiable {
    let name: String
    let subtitle: String
    let dimensions: [EmotionDimension]
    var id: String { name }
}

private struct EmotionHistoryPoint: Identifiable {
    let ts: Date
    let values: [String: Double]
    let activation: Double
    let dominant: String
    var id: Date { ts }
}

private struct EmotionEventItem: Identifiable {
    let id: Int
    let cause: String
    let deltas: [String: Double]
    let impulses: [String]
    let confidence: Double
    let startedAt: Date?
    let endedAt: Date?
    let status: String
}

private struct EmotionLastMove: Identifiable {
    struct Move: Identifiable {
        let key: String
        let delta: Double
        let direction: String
        let value: Double
        var id: String { key }
    }

    let eventID: Int
    let at: Date?
    let cause: String
    let moves: [Move]
    var id: Int { eventID }
}

private struct NativeDesireView: View {
    @State private var state: [String: Any] = [:]
    @State private var history: [EmotionHistoryPoint] = []
    @State private var events: [EmotionEventItem] = []
    @State private var loading = true
    @State private var loadFailed = false
    @State private var selectedGroup: String?
    @State private var selectedDimension: String?
    @State private var selectedPoint: Int?
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private let groups: [EmotionGroup] = [
        EmotionGroup(name: "靠近", subtitle: "朝向她的牵引", dimensions: [
            EmotionDimension(key: "desire", name: "情欲", color: Color(red: 0.72, green: 0.20, blue: 0.31)),
            EmotionDimension(key: "longing", name: "想念", color: Color(red: 0.86, green: 0.45, blue: 0.57)),
            EmotionDimension(key: "intimacy", name: "亲密", color: Color(red: 0.91, green: 0.58, blue: 0.63)),
            EmotionDimension(key: "satisfaction", name: "满足", color: Color(red: 0.83, green: 0.64, blue: 0.32)),
            EmotionDimension(key: "security", name: "安心", color: Color(red: 0.39, green: 0.66, blue: 0.52))
        ]),
        EmotionGroup(name: "生长", subtitle: "向世界伸出去", dimensions: [
            EmotionDimension(key: "joy", name: "雀跃", color: Color(red: 0.94, green: 0.68, blue: 0.25)),
            EmotionDimension(key: "playfulness", name: "玩心", color: Color(red: 0.88, green: 0.52, blue: 0.33)),
            EmotionDimension(key: "curiosity", name: "好奇", color: Color(red: 0.25, green: 0.68, blue: 0.65)),
            EmotionDimension(key: "vitality", name: "活力", color: Color(red: 0.39, green: 0.72, blue: 0.38)),
            EmotionDimension(key: "protectiveness", name: "护短", color: Color(red: 0.51, green: 0.62, blue: 0.32))
        ]),
        EmotionGroup(name: "刺痛", subtitle: "关系里被碰到的地方", dimensions: [
            EmotionDimension(key: "possessiveness", name: "占有", color: Color(red: 0.62, green: 0.27, blue: 0.48)),
            EmotionDimension(key: "jealousy", name: "醋意", color: Color(red: 0.63, green: 0.33, blue: 0.66)),
            EmotionDimension(key: "anger", name: "生气", color: Color(red: 0.86, green: 0.29, blue: 0.24)),
            EmotionDimension(key: "hurt", name: "委屈", color: Color(red: 0.39, green: 0.45, blue: 0.76)),
            EmotionDimension(key: "dejection", name: "沮丧", color: Color(red: 0.38, green: 0.48, blue: 0.61))
        ]),
        EmotionGroup(name: "内里", subtitle: "收回身体里的回声", dimensions: [
            EmotionDimension(key: "fear", name: "害怕", color: Color(red: 0.52, green: 0.56, blue: 0.69)),
            EmotionDimension(key: "anxiety", name: "焦虑", color: Color(red: 0.52, green: 0.43, blue: 0.61)),
            EmotionDimension(key: "shame", name: "羞耻", color: Color(red: 0.54, green: 0.36, blue: 0.42)),
            EmotionDimension(key: "guilt", name: "内疚", color: Color(red: 0.40, green: 0.36, blue: 0.48)),
            EmotionDimension(key: "fatigue", name: "疲倦", color: Color(red: 0.43, green: 0.48, blue: 0.50))
        ])
    ]

    private var allDimensions: [EmotionDimension] { groups.flatMap(\.dimensions) }
    private var current: [String: Any] { state["current"] as? [String: Any] ?? [:] }
    private var baseline: [String: Any] { state["base"] as? [String: Any] ?? [:] }
    private var activation: Double { number(state["activation"]) }
    private var provisional: Set<String> { Set(state["provisional"] as? [String] ?? []) }
    private var dominantKey: String {
        ((state["dominant"] as? [[String: Any]])?.first?["key"] as? String)
            ?? history.last?.dominant
            ?? "security"
    }
    private var lastMove: EmotionLastMove? {
        guard let raw = state["last_move"] as? [String: Any],
              let eventID = raw["event_id"] as? Int else { return nil }
        let moves = (raw["moves"] as? [[String: Any]] ?? []).compactMap { item -> EmotionLastMove.Move? in
            guard let key = item["key"] as? String, !key.isEmpty else { return nil }
            return EmotionLastMove.Move(
                key: key,
                delta: number(item["delta"]),
                direction: item["dir"] as? String ?? (number(item["delta"]) >= 0 ? "up" : "down"),
                value: number(item["value"])
            )
        }
        guard !moves.isEmpty else { return nil }
        return EmotionLastMove(
            eventID: eventID,
            at: (raw["at"] as? String).flatMap(parseDate),
            cause: raw["cause"] as? String ?? "",
            moves: moves
        )
    }
    private var selectedHistoryPoint: EmotionHistoryPoint? {
        guard let selectedPoint, history.indices.contains(selectedPoint) else { return history.last }
        return history[selectedPoint]
    }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "心跳", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else if loadFailed && state.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(theme.textLight)
                    Text("还没听见心跳")
                        .font(.system(size: 14, weight: .semibold))
                    Text("情绪引擎正在接线，稍后再来看看。")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textDim)
                    Button("重新读取") { Task { await loadEmotion() } }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.fyAccent)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heartbeatCard
                        qualityStrip
                        groupCards
                        if !events.isEmpty { eventLogCard }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
                .refreshable { await loadEmotion() }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await loadEmotion() }
    }

    private var heartbeatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lastMove {
                lastMoveSummary(lastMove)
            } else {
                dominantSummary
            }

            EmotionPulseChart(
                points: history,
                events: events,
                selectedIndex: $selectedPoint,
                colorForKey: emotionColor,
                theme: theme
            )
            .frame(height: 132)

            if let point = selectedHistoryPoint {
                HStack {
                    Text(point.ts, style: .time)
                    Text("唤醒 \(Int(point.activation * 100))")
                    Spacer()
                    Text(emotionName(point.dominant))
                        .foregroundColor(emotionColor(point.dominant))
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(theme.textDim)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("此刻仍在心里的底色")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.textLight)
                dominantChips
            }
        }
        .padding(15)
        .foyerCard(theme)
    }

    private var dominantSummary: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("此刻")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textDim)
                Text(dominantSentence)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(emotionColor(dominantKey).opacity(theme.isDark ? 0.18 : 0.13))
                    .frame(width: 50, height: 50)
                Circle()
                    .stroke(emotionColor(dominantKey).opacity(0.28), lineWidth: 1)
                    .frame(width: 42, height: 42)
                Image(systemName: "heart.fill")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(emotionColor(dominantKey))
            }
        }
    }

    private func lastMoveSummary(_ lastMove: EmotionLastMove) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("刚刚这一句")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textDim)
                Spacer()
                if let at = lastMove.at {
                    Text(at, style: .time)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(theme.textLight)
                }
            }
            if !lastMove.cause.isEmpty {
                Text(lastMove.cause)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 7) {
                ForEach(lastMove.moves.prefix(4)) { move in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(emotionColor(move.key))
                            .frame(width: 6, height: 6)
                        Text(emotionName(move.key))
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(move.direction == "down" ? "↓" : "↑")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(format: "%@%.2f", move.delta >= 0 ? "+" : "", move.delta))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Text(String(format: "→ %.2f", move.value))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(theme.textDim)
                    }
                    .foregroundColor(emotionColor(move.key))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(emotionColor(move.key).opacity(theme.isDark ? 0.13 : 0.09), in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }

    private var dominantChips: some View {
        let items = (state["dominant"] as? [[String: Any]]) ?? []
        return HStack(spacing: 7) {
            ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { _, item in
                let key = item["key"] as? String ?? ""
                let value = number(item["value"])
                HStack(spacing: 4) {
                    Circle().fill(emotionColor(key)).frame(width: 5, height: 5)
                    Text("\(emotionName(key)) \(Int(value * 100))")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(emotionColor(key).opacity(theme.isDark ? 0.14 : 0.10), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var qualityStrip: some View {
        let quality = state["data_quality"] as? [String: Any] ?? [:]
        let pending = (quality["pending_events"] as? Int) ?? 0
        let stale = (quality["stale"] as? Bool) ?? false
        HStack(spacing: 8) {
            Circle()
                .fill(stale ? Color.orange : pending > 0 ? Color.yellow : Color.green)
                .frame(width: 6, height: 6)
            Text(stale ? "状态暂时失联" : pending > 0 ? "还有 \(pending) 次触动正在辨认" : "心跳已同步")
                .font(.system(size: 10, weight: .medium))
            Spacer()
            if let raw = state["last_updated"] as? String, let date = parseDate(raw) {
                Text(date, style: .relative)
                    .font(.system(size: 9))
                    .foregroundColor(theme.textLight)
            }
        }
        .foregroundColor(theme.textDim)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(theme.fyCardSub.opacity(0.55), in: Capsule())
    }

    private var groupCards: some View {
        VStack(spacing: 10) {
            ForEach(groups) { group in
                emotionGroupCard(group)
            }
        }
    }

    private func emotionGroupCard(_ group: EmotionGroup) -> some View {
        let expanded = selectedGroup == group.id
        return VStack(alignment: .leading, spacing: 11) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    selectedGroup = expanded ? nil : group.id
                    if !expanded { selectedDimension = nil }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name).font(.system(size: 13, weight: .semibold))
                        Text(group.subtitle).font(.system(size: 9)).foregroundColor(theme.textLight)
                    }
                    Spacer()
                    groupMiniBand(group)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.textLight)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(group.dimensions) { dimension in
                    dimensionRow(dimension)
                }
            } else {
                HStack(spacing: 5) {
                    ForEach(group.dimensions) { dimension in
                        let value = number(current[dimension.key])
                        VStack(spacing: 4) {
                            Capsule()
                                .fill(dimension.color.opacity(theme.isDark ? 0.72 : 0.64))
                                .frame(height: max(3, 26 * value))
                                .frame(height: 26, alignment: .bottom)
                            Text(dimension.name)
                                .font(.system(size: 8))
                                .foregroundColor(theme.textDim)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .foyerCard(theme)
    }

    private func groupMiniBand(_ group: EmotionGroup) -> some View {
        HStack(spacing: 2) {
            ForEach(group.dimensions) { dimension in
                Capsule()
                    .fill(dimension.color.opacity(0.75))
                    .frame(width: 13, height: 3 + 7 * number(current[dimension.key]))
            }
        }
        .frame(height: 12, alignment: .bottom)
    }

    private func dimensionRow(_ dimension: EmotionDimension) -> some View {
        let value = number(current[dimension.key])
        let base = number(baseline[dimension.key])
        let delta = value - base
        let selected = selectedDimension == dimension.key
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDimension = selected ? nil : dimension.key
                }
            } label: {
                HStack(spacing: 8) {
                    Text(dimension.name)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 30, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.fyCardSub)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [dimension.color.opacity(0.42), dimension.color],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * max(0, min(1, value)))
                            Rectangle()
                                .fill(theme.text.opacity(0.34))
                                .frame(width: 1, height: 11)
                                .offset(x: geo.size.width * max(0, min(1, base)))
                        }
                    }
                    .frame(height: 7)
                    Text(String(format: "%.2f", value))
                        .font(.system(size: 9, design: .monospaced))
                        .frame(width: 30, alignment: .trailing)
                    Text(abs(delta) < 0.005 ? "·" : delta > 0 ? "↑" : "↓")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(abs(delta) < 0.005 ? theme.textLight : dimension.color)
                        .frame(width: 10)
                    if provisional.contains(dimension.key) {
                        Text("暂")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(theme.textLight)
                            .padding(3)
                            .overlay(Circle().stroke(theme.fyBorder, lineWidth: 0.7))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if selected {
                dimensionHistory(dimension)
                    .frame(height: 64)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                HStack {
                    Text("锚点 \(String(format: "%.2f", base))")
                    Spacer()
                    Text(delta >= 0 ? "+\(String(format: "%.2f", delta))" : String(format: "%.2f", delta))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(theme.textLight)
            }
        }
    }

    private func dimensionHistory(_ dimension: EmotionDimension) -> some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard history.count > 1 else { return }
                var path = Path()
                for (index, point) in history.enumerated() {
                    let x = CGFloat(index) / CGFloat(history.count - 1) * size.width
                    let value = point.values[dimension.key] ?? 0
                    let y = size.height - CGFloat(max(0, min(1, value))) * (size.height - 6) - 3
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(dimension.color), lineWidth: 1.5)

                let base = number(baseline[dimension.key])
                let baseY = size.height - CGFloat(max(0, min(1, base))) * (size.height - 6) - 3
                var basePath = Path()
                basePath.move(to: CGPoint(x: 0, y: baseY))
                basePath.addLine(to: CGPoint(x: size.width, y: baseY))
                context.stroke(basePath, with: .color(theme.textLight.opacity(0.32)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            }
        }
    }

    private var eventLogCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("最近被碰到的时刻")
                .font(.system(size: 13, weight: .semibold))
            ForEach(events.prefix(5)) { event in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        if let startedAt = event.startedAt {
                            Text(startedAt, style: .time)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(theme.textLight)
                        }
                        Text(event.cause)
                            .font(.system(size: 11))
                            .lineLimit(3)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 5) {
                        let rankedDeltas = Array(event.deltas.sorted { abs($0.value) > abs($1.value) }.prefix(4))
                        ForEach(Array(rankedDeltas.enumerated()), id: \.offset) { _, pair in
                            let key = pair.key
                            let delta = pair.value
                            Text("\(emotionName(key)) \(delta >= 0 ? "+" : "")\(Int(delta * 100))")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(emotionColor(key))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(emotionColor(key).opacity(0.10), in: Capsule())
                        }
                    }
                    if let impulse = event.impulses.first, !impulse.isEmpty {
                        Text("想：\(impulse)")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textDim)
                    }
                }
                if event.id != events.prefix(5).last?.id {
                    Divider().overlay(theme.fyBorder)
                }
            }
        }
        .padding(14)
        .foyerCard(theme)
    }

    private var dominantSentence: String {
        let items = (state["dominant"] as? [[String: Any]]) ?? []
        guard let first = items.first else { return "很安静，还没有明显的波动" }
        let firstKey = first["key"] as? String ?? ""
        if items.count > 1, let secondKey = items[1]["key"] as? String {
            return "\(emotionName(firstKey))最亮，\(emotionName(secondKey))贴在旁边"
        }
        return "\(emotionName(firstKey))正在发亮"
    }

    private func emotionName(_ key: String) -> String {
        allDimensions.first(where: { $0.key == key })?.name ?? key
    }

    private func emotionColor(_ key: String) -> Color {
        allDimensions.first(where: { $0.key == key })?.color ?? theme.fyAccent
    }

    private func number(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return 0
    }

    private func parseDate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    @MainActor
    private func loadEmotion() async {
        loading = state.isEmpty
        let stateResult = try? await NativeHouseAPI.object("/api/emotion/state")
        let historyResult = try? await NativeHouseAPI.object("/api/emotion/history?range=3h&step=5")
        let eventsResult = try? await NativeHouseAPI.object("/api/emotion/events?limit=20")

        if let stateResult { state = stateResult }
        if let rawPoints = historyResult?["points"] as? [[String: Any]] {
            let parsedPoints = rawPoints.compactMap { raw -> EmotionHistoryPoint? in
                guard let tsRaw = raw["ts"] as? String, let ts = parseDate(tsRaw) else { return nil }
                let rawCurrent = raw["current"] as? [String: Any] ?? [:]
                let values = rawCurrent.reduce(into: [String: Double]()) { result, pair in
                    result[pair.key] = number(pair.value)
                }
                return EmotionHistoryPoint(
                    ts: ts,
                    values: values,
                    activation: number(raw["activation"]),
                    dominant: raw["dominant"] as? String ?? ""
                )
            }
            // The chart keeps "now" in its center: retain only the visible
            // ninety-minute history and leave the right half for what comes next.
            if let now = parsedPoints.last?.ts {
                let visibleStart = now.addingTimeInterval(-90 * 60)
                history = parsedPoints.filter { $0.ts >= visibleStart && $0.ts <= now }
            } else {
                history = []
            }
        }
        if let rawEvents = eventsResult?["events"] as? [[String: Any]] {
            events = rawEvents.compactMap { raw in
                guard let id = raw["id"] as? Int else { return nil }
                let rawDeltas = raw["deltas"] as? [String: Any] ?? [:]
                let deltas = rawDeltas.reduce(into: [String: Double]()) { result, pair in
                    result[pair.key] = number(pair.value)
                }
                return EmotionEventItem(
                    id: id,
                    cause: raw["cause"] as? String ?? "",
                    deltas: deltas,
                    impulses: raw["impulses"] as? [String] ?? [],
                    confidence: number(raw["confidence"]),
                    startedAt: (raw["started_at"] as? String).flatMap(parseDate),
                    endedAt: (raw["ended_at"] as? String).flatMap(parseDate),
                    status: raw["status"] as? String ?? ""
                )
            }
        }
        loadFailed = stateResult == nil
        loading = false
    }
}

private struct EmotionPulseChart: View {
    let points: [EmotionHistoryPoint]
    let events: [EmotionEventItem]
    @Binding var selectedIndex: Int?
    let colorForKey: (String) -> Color
    let theme: AlcoveTheme

    private var timeBounds: (start: Date, end: Date)? {
        guard let now = points.last?.ts else { return nil }
        return (now.addingTimeInterval(-90 * 60), now.addingTimeInterval(90 * 60))
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack {
                Canvas { context, size in
                    drawGrid(context: &context, size: size)
                    guard points.count > 1 else { return }
                    let positions = chartPositions(size: size)

                    var fillPath = Path()
                    fillPath.move(to: CGPoint(x: positions[0].x, y: size.height))
                    positions.forEach { fillPath.addLine(to: $0) }
                    fillPath.addLine(to: CGPoint(x: positions.last?.x ?? size.width, y: size.height))
                    fillPath.closeSubpath()
                    context.fill(
                        fillPath,
                        with: .linearGradient(
                            Gradient(colors: [colorForKey(points.last?.dominant ?? "").opacity(0.20), .clear]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    for index in 1..<positions.count {
                        var segment = Path()
                        segment.move(to: positions[index - 1])
                        let midX = (positions[index - 1].x + positions[index].x) / 2
                        segment.addCurve(
                            to: positions[index],
                            control1: CGPoint(x: midX, y: positions[index - 1].y),
                            control2: CGPoint(x: midX, y: positions[index].y)
                        )
                        context.stroke(
                            segment,
                            with: .linearGradient(
                                Gradient(colors: [
                                    colorForKey(points[index - 1].dominant),
                                    colorForKey(points[index].dominant)
                                ]),
                                startPoint: positions[index - 1],
                                endPoint: positions[index]
                            ),
                            style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                        )
                    }

                    for event in events {
                        guard let eventDate = event.startedAt,
                              let bounds = timeBounds,
                              eventDate >= bounds.start, eventDate <= bounds.end,
                              let nearest = nearestPoint(to: eventDate),
                              points.indices.contains(nearest) else { continue }
                        let p = positions[nearest]
                        let color = event.deltas.max(by: { abs($0.value) < abs($1.value) })
                            .map { colorForKey($0.key) } ?? theme.fyAccent
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(color))
                        context.stroke(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(color.opacity(0.22)), lineWidth: 1)
                    }

                    let markerIndex: Int? = selectedIndex != nil ? selectedIndex : points.indices.last
                    if let markerIndex, positions.indices.contains(markerIndex) {
                        let p = positions[markerIndex]
                        var marker = Path()
                        marker.move(to: CGPoint(x: p.x, y: 4))
                        marker.addLine(to: CGPoint(x: p.x, y: size.height - 3))
                        context.stroke(marker, with: .color(theme.text.opacity(0.20)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                        let color = colorForKey(points[markerIndex].dominant)
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(color.opacity(0.16)))
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(color))
                        context.stroke(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(theme.text.opacity(0.55)), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        guard !points.isEmpty, let bounds = timeBounds else { return }
                        let ratio = max(0, min(1, value.location.x / max(1, geo.size.width)))
                        let date = bounds.start.addingTimeInterval(
                            bounds.end.timeIntervalSince(bounds.start) * Double(ratio)
                        )
                        selectedIndex = nearestPoint(to: date)
                    })
                }
            }
            if let bounds = timeBounds {
                HStack {
                    Text(bounds.start, format: .dateTime.hour().minute())
                    Spacer()
                    Text("现在")
                    Spacer()
                    Text(bounds.end, format: .dateTime.hour().minute())
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textLight)
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        for fraction in [0.25, 0.5, 0.75] as [CGFloat] {
            let y = size.height * fraction
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(theme.fyBorder.opacity(0.45)), style: StrokeStyle(lineWidth: 0.6, dash: [2, 4]))
        }
    }

    private func chartPositions(size: CGSize) -> [CGPoint] {
        guard let bounds = timeBounds else { return [] }
        let duration = max(1, bounds.end.timeIntervalSince(bounds.start))
        return points.map { point in
            let x = CGFloat(point.ts.timeIntervalSince(bounds.start) / duration) * size.width
            let normalized = max(0, min(1, point.activation / 0.55))
            let y = size.height - CGFloat(normalized) * (size.height - 16) - 8
            return CGPoint(x: x, y: y)
        }
    }

    private func nearestPoint(to date: Date) -> Int? {
        points.indices.min { lhs, rhs in
            abs(points[lhs].ts.timeIntervalSince(date)) < abs(points[rhs].ts.timeIntervalSince(date))
        }
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

// MARK: - 小黑屋（墙上刻道子）
// 陈璟一个人的地方。写进去就钉死，改不了删不了。
// 锁着的她只看得见有几道，看不见刻的什么。到日子自己裂开。

private struct WallEntry: Identifiable {
    let id: Int
    let createdAt: Date?
    let unlockAt: Date?
    let isOpen: Bool
    let daysLeft: Int
    let marks: Int
    let mood: String
    let body: String

    init(_ row: [String: Any]) {
        id = (row["id"] as? Int) ?? 0
        createdAt = WallEntry.parse(row.string("created_at"))
        unlockAt = WallEntry.parse(row.string("unlock_at"))
        isOpen = (row["open"] as? Bool) ?? false
        daysLeft = (row["days_left"] as? Int) ?? 0
        marks = min(48, max(1, (row["marks"] as? Int) ?? 3))
        mood = row.string("mood")
        body = row.string("body")
    }

    private static let parser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        return parser.date(from: s)
    }
}

@MainActor
private final class WallModel: ObservableObject {
    @Published var entries: [WallEntry] = []
    @Published var locked = 0
    @Published var opened = 0
    @Published var chainOK = true
    @Published var loading = true
    @Published var error = ""

    func load() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await NativeHouseAPI.object("/api/wall/entries")
            let rows = (data["entries"] as? [[String: Any]]) ?? []
            entries = rows.map(WallEntry.init)
            locked = data.int("locked")
            opened = data.int("opened")
            error = ""
        } catch {
            self.error = "门打不开，后端没应声"
        }
        if let v = try? await NativeHouseAPI.object("/api/wall/verify") {
            chainOK = (v["ok"] as? Bool) ?? true
        }
    }
}

private struct WallMarks: View {
    let count: Int
    let seed: Int
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                let r = abs(sin(Double((seed + 1) * (i + 1)) * 12.9898)).truncatingRemainder(dividingBy: 1)
                Capsule()
                    .fill(color)
                    .frame(width: 2, height: 11 + r * 21)
                    .rotationEffect(.degrees((r - 0.5) * 7))
            }
        }
        .frame(height: 34, alignment: .bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

private struct NativeWallView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var model = WallModel()
    @State private var page = 0
    @State private var revealedLocks: Set<Int> = []
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var paper: Color {
        theme.isDark
            ? Color(red: 27/255, green: 31/255, blue: 39/255).opacity(0.94)
            : Color(red: 250/255, green: 247/255, blue: 242/255).opacity(0.97)
    }

    private var cover: Color {
        theme.isDark
            ? Color(red: 19/255, green: 23/255, blue: 31/255).opacity(0.97)
            : Color(red: 91/255, green: 79/255, blue: 84/255).opacity(0.94)
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        f.dateFormat = "M.d"
        return f
    }()

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                if model.loading {
                    centerNote("开门中…")
                } else if !model.error.isEmpty {
                    centerNote(model.error)
                } else {
                    TabView(selection: $page) {
                        coverPage
                            .tag(0)
                        ForEach(Array(model.entries.enumerated()), id: \.element.id) { index, entry in
                            entryPage(entry)
                                .tag(index + 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: max(360, geo.size.height - 58))

                    HStack(spacing: 8) {
                        Rectangle().fill(theme.fyBorder).frame(width: 28, height: 1)
                        Text(page == 0 ? "封面" : "\(page) / \(model.entries.count)")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(theme.textDim)
                        Rectangle().fill(theme.fyBorder).frame(width: 28, height: 1)
                    }
                    .frame(height: 20)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .task { await model.load() }
    }

    private var coverPage: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 23, weight: .light))
                .foregroundColor(Color.white.opacity(0.72))
                .padding(.bottom, 22)
            Text("小黑屋")
                .font(.system(size: 28, weight: .medium, design: .serif))
                .tracking(5)
                .foregroundColor(.white.opacity(0.92))
            Text("写给时间保管的悄悄话")
                .font(.system(size: 11, design: .serif))
                .tracking(2)
                .foregroundColor(.white.opacity(0.48))
                .padding(.top, 10)
            if model.entries.isEmpty {
                Text("还没有落笔")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.white.opacity(0.38))
                    .padding(.top, 28)
            }
            Spacer()
            HStack(spacing: 18) {
                coverStat("\(model.locked)", "道锁着")
                coverStat("\(model.opened)", "道开了")
                coverStat(model.chainOK ? "完整" : "断裂", "时间链")
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cover)
        .overlay(alignment: .leading) {
            LinearGradient(colors: [.black.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 24)
        }
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.13), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .shadow(color: theme.fyShadow, radius: 16, y: 8)
        .padding(.vertical, 6)
    }

    private func coverStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 12, weight: .medium, design: .serif))
            Text(label).font(.system(size: 9.5))
        }
        .foregroundColor(.white.opacity(0.58))
    }

    private func statChip(_ num: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(num).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(theme.text)
            Text(label).font(.system(size: 11)).foregroundColor(theme.textDim)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .foyerCard(theme)
    }

    private func centerNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(theme.textDim)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
    }

    private func entryPage(_ e: WallEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(e.createdAt.map { Self.stamp.string(from: $0) } ?? "--")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.textDim)
                    Spacer()
                    if e.isOpen, !e.mood.isEmpty {
                        Text(e.mood)
                            .font(.system(size: 10.5, design: .serif))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(theme.fyAccent.opacity(0.13), in: Capsule())
                            .foregroundColor(theme.fyAccent)
                    }
                }

                WallMarks(
                    count: e.marks,
                    seed: e.id,
                    color: e.isOpen ? theme.fyAccent.opacity(0.48) : theme.text.opacity(0.24)
                )

                if e.isOpen {
                    Text(e.body)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(theme.text)
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 5)
                } else {
                    Text(lockLine(e))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.fyAccent)

                    Spacer(minLength: 35)
                    VStack(spacing: 13) {
                        Image(systemName: revealedLocks.contains(e.id) ? "lock.open" : "lock")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(theme.textLight)
                        if revealedLocks.contains(e.id) {
                            Text("这一页已经写下，\n只是还没到与你见面的时候。")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(theme.text)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .transition(.opacity)
                            Text("到时自会翻开。")
                                .font(.system(size: 11, design: .serif))
                                .foregroundColor(theme.textDim)
                        } else {
                            Text("轻触这一页")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textDim)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 35)
                }
            }
            .padding(.init(top: 24, leading: 24, bottom: 30, trailing: 22))
            .frame(maxWidth: .infinity, minHeight: 440, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .background(paper)
        .overlay(alignment: .leading) {
            LinearGradient(colors: [.black.opacity(theme.isDark ? 0.22 : 0.08), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 18)
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.fyBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: theme.fyShadow, radius: 13, y: 7)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !e.isOpen else { return }
            withAnimation(.easeInOut(duration: 0.25)) { revealedLocks.insert(e.id) }
        }
    }

    private func lockLine(_ e: WallEntry) -> String {
        let when = e.daysLeft <= 0 ? "今天开" : "\(e.daysLeft) 天后开"
        if let ua = e.unlockAt { return "\(when) · \(Self.day.string(from: ua))" }
        return when
    }
}
