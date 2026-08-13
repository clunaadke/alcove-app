import SwiftUI
import PhotosUI
import AVFoundation
import MediaPlayer
import WebKit
import MapKit

private struct HouseOwnsHeaderKey: EnvironmentKey { static let defaultValue = false }
private extension EnvironmentValues {
    var houseOwnsHeader: Bool {
        get { self[HouseOwnsHeaderKey.self] }
        set { self[HouseOwnsHeaderKey.self] = newValue }
    }
}

enum HouseDestination: String, Identifiable, CaseIterable {
    case sidebar, chat, terminal, settings, bubbleAppearance, checklist, music
    case home, profile, activityRoom, calendar, digest, wall, usage, workbench
    case memory, dreams, shelf, fiction, desire, nianlun, clockwork, album, portrait, impression, morningPaper, nowhere, pulse
    case crosstalk, radio, coread, liao, daddyDay, lab
    case search, favorites, forge, roundtable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sidebar: return "Alcove"
        case .home: return "大厅"
        case .profile: return "陈璟"
        case .activityRoom: return "活动房间"
        case .chat: return "Chat"
        case .terminal: return "Terminal"
        case .settings: return "设置"
        case .bubbleAppearance: return "气泡与文字"
        case .checklist: return "Checklist"
        case .music: return "Music"
        case .calendar: return "Calendar"
        case .digest: return "日结编年史"
        case .wall: return "小黑屋"
        case .usage: return "Usage"
        case .workbench: return "总控台"
        case .memory: return "Memory"
        case .dreams: return "Dreams"
        case .shelf: return "渡鸦的架子"
        case .fiction: return "书房"
        case .desire: return "Eventide"
        case .nianlun: return "年轮"
        case .clockwork: return "发条"
        case .album: return "相册"
        case .portrait: return "Letters"
        case .impression: return "Self"
        case .morningPaper: return "Morning Paper"
        case .nowhere: return "乌有乡"
        case .pulse: return "Pulse"
        case .crosstalk: return "Crosstalk"
        case .radio: return "Radio"
        case .coread: return "共读"
        case .liao: return "燎"
        case .daddyDay: return "Daddy的一天"
        case .lab: return "Lab"
        case .search: return "Search"
        case .favorites: return "Favorites"
        case .forge: return "Forge"
        case .roundtable: return "圆桌"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .profile: return "person.crop.circle"
        case .activityRoom: return "lamp.desk"
        case .chat: return "bubble.left"
        case .terminal: return "terminal"
        case .settings: return "gearshape"
        case .bubbleAppearance: return "slider.horizontal.3"
        case .checklist: return "checklist"
        case .music: return "music.note"
        case .calendar: return "calendar"
        case .digest: return "calendar.badge.clock"
        case .wall: return "lock.rectangle.stack"
        case .desire: return "water.waves"
        case .usage: return "chart.bar"
        case .workbench: return "slider.horizontal.2.square"
        case .memory: return "brain.head.profile"
        case .dreams: return "moon.stars"
        case .shelf: return "bird"
        case .fiction: return "books.vertical"
        case .nianlun: return "circle.hexagongrid"
        case .clockwork: return "clock.arrow.circlepath"
        case .album: return "photo.on.rectangle"
        case .portrait: return "envelope"
        case .impression: return "person.crop.circle.badge.questionmark"
        case .morningPaper: return "newspaper"
        case .nowhere: return "map"
        case .pulse: return "heart.text.square"
        case .crosstalk: return "play.circle"
        case .radio: return "radio"
        case .coread: return "book"
        case .liao: return "flame"
        case .daddyDay: return "clock"
        case .lab: return "waveform.path.ecg.rectangle"
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
            FoyerGlassContainer(spacing: 8, paper: theme.isPaper) {
                VStack(spacing: 0) {
                    houseHeader(safeTop: root.safeAreaInsets.top)
                    Group {
                switch route {
                case .sidebar:
                    Color.clear
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
                case .crosstalk, .liao:
                    NativePlayView(destination: route)
                case .coread:
                    NativeCoreadRoomView()
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
                case .workbench:
                    NativeWorkbenchView()
                case .profile:
                    NativeChenjingHomeView(
                        openRoom: { withAnimation(.easeInOut(duration: 0.18)) { route = .activityRoom } },
                        openDiary: { withAnimation(.easeInOut(duration: 0.18)) { route = .calendar } }
                    )
                case .activityRoom:
                    NativeActivityRoomView(
                        openCalendar: { withAnimation(.easeInOut(duration: 0.18)) { route = .calendar } },
                        closeRoom: { withAnimation(.easeInOut(duration: 0.18)) { route = .profile } }
                    )
                case .memory:
                    NativeOBMemoryView()
                case .portrait:
                    NativeOBLettersView()
                case .desire:
                    NativeDesireView()
                case .forge:
                    NativeForgeView()
                case .calendar:
                    NativeCalendarView()
                case .digest:
                    NativeDigestPlaceholderView()
                case .fiction:
                    NativeFictionStudyView()
                case .impression:
                    NativeOBSelfView()
                case .dreams:
                    NativeDreamsView()
                case .morningPaper:
                    NativeMorningPaperView()
                case .nowhere:
                    NativeNowhereView()
                case .pulse:
                    NativePulseView()
                case .lab:
                    NativePipeLabView()
                case .wall:
                    NativeWallView()
                default:
                    NativeDataPanel(destination: route)
                }
                    }
                    .environment(\.houseOwnsHeader, true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "alcoveChatRoot")
        .environment(\.chatWallpaperDescriptor, panelWallpaperDescriptor)
        .environment(\.chatWallpaperViewportSize, root.size)
        .environment(\.bubbleGlassStyle, bubbleGlassStyle)
        // Panel wallpaper may extend under the home indicator, but keyboard safe-area
        // must remain live so editors/composers rise instead of being covered.
        .ignoresSafeArea(.container, edges: .all)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .presentationBackground {
            GeometryReader { backgroundGeo in
                Image(theme.isDark ? "DrawerDark" : "DrawerLight")
                    .resizable()
                    .scaledToFill()
                    .frame(width: backgroundGeo.size.width, height: backgroundGeo.size.height)
                    .clipped()
                    .ignoresSafeArea()
            }
        }
        .onAppear { prepareTextureIfNeeded() }
        .onChange(of: themeName) { _ in prepareTextureIfNeeded() }
        }
    }

    private func houseHeader(safeTop: CGFloat) -> some View {
        ZStack {
            if route != .activityRoom && route != .coread {
                Text(route.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .tracking(0.4)
            }
            HStack {
                Button {
                    if route == .bubbleAppearance {
                        withAnimation(.easeInOut(duration: 0.18)) { route = .settings }
                    } else if route == .activityRoom || route == .calendar {
                        withAnimation(.easeInOut(duration: 0.18)) { route = .profile }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(theme.textDim)
                        .frame(width: 36, height: 40)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                Spacer()
            }
        }
        .frame(height: route == .activityRoom || route == .coread ? 0 : 46)
        .padding(.top, route == .activityRoom || route == .coread ? 0 : safeTop)
        .padding(.horizontal, 12)
        .background(
            LinearGradient(colors: [theme.fyCardSub.opacity(0.46), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func prepareTextureIfNeeded() {
        if theme.isPaper {
            preparedTexture = nil
            preparedTextureName = ""
            return
        }
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
            if !theme.isPaper {
                WetGlassTexture(theme: theme, preparedTexture: preparedTexture)
            } else {
                Canvas { context, size in
                    for y in stride(from: CGFloat(24), through: size.height, by: 28) {
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(line, with: .color(theme.fyBorder.opacity(0.16)), lineWidth: 0.45)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct NativeHouseDrawer: View {
    let drawerWidth: CGFloat
    let onClose: () -> Void
    let select: (HouseDestination) -> Void
    let roundtableUnread: Int
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("assistantName") private var assistantName = "陈璟"
    @AppStorage("assistantAvatarDataURL") private var avatarDataURL = ""
    @StateObject private var model = SidebarModel()
    private var theme: AlcoveTheme { .named(themeName) }

    private var screenSafeInsets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.safeAreaInsets ?? .zero
    }

    private var avatar: UIImage? {
        let parts = avatarDataURL.split(separator: ",", maxSplits: 1)
        guard let data = Data(base64Encoded: parts.count == 2 ? String(parts[1]) : avatarDataURL) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(theme.isDark ? "DrawerDark" : "DrawerLight")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                (theme.isDark ? Color.black : Color.white).opacity(theme.isDark ? 0.10 : 0.08)

                ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Text("Alcove")
                            .font(.custom("Snell Roundhand", size: 34))
                            .italic()
                        Spacer(minLength: 0)
                        Button { select(.workbench) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "slider.horizontal.2.square")
                                Text("总控台")
                            }
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(theme.textDim)
                            .frame(width: 68, height: 31)
                            .drawerGlass(theme)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)

                    homeCards
                    handwritten("still at home")

                    VStack(spacing: 7) {
                        drawerRow(.chat, detail: "回到你们正在说的话")
                        drawerRow(.roundtable, detail: roundtableUnread > 0 ? "\(roundtableUnread) 条新消息" : "三个人的桌边")
                        drawerRow(.terminal, detail: "看看他正在做什么")
                        drawerRow(.settings, detail: "主题、权限与小屋设置")
                    }

                    drawerTitle("正在发生", note: "still growing")
                    VStack(spacing: 7) {
                        drawerRow(.pulse, detail: "心率、体温与呼吸")
                        drawerRow(.desire, detail: "身体潮汐与情绪")
                        drawerRow(.nowhere, detail: "足迹与明信片")
                        drawerRow(.fiction, detail: "陈璟写给你的小说")
                        drawerRow(.digest, detail: "日结、周结与月结")
                        drawerRow(.memory, detail: "正在生长的记忆")
                    }

                    drawerTitle("家里的收藏", note: "kept close")
                    VStack(spacing: 7) {
                        ForEach([HouseDestination.dreams, .portrait, .album, .nianlun, .shelf, .impression]) { target in
                            drawerRow(target, detail: drawerDetail(target))
                        }
                    }

                    drawerTitle("工具与游戏", note: "little things")
                    VStack(spacing: 7) {
                        ForEach([HouseDestination.clockwork, .forge, .search, .favorites, .wall,
                                 .crosstalk, .coread, .liao]) { target in
                            drawerRow(target, detail: drawerDetail(target))
                        }
                    }

                    handwritten("a small home for us")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
                // This drawer itself is full-bleed, so its GeometryReader reports
                // zero safe-area insets on device. Read the window insets above,
                // while pinning content to the drawer's actual (narrower) width.
                .frame(width: max(0, drawerWidth - 28), alignment: .leading)
                .padding(.top, screenSafeInsets.top + 12)
                .padding(.horizontal, 14)
                .padding(.bottom, screenSafeInsets.bottom + 28)
                }
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .foregroundColor(theme.text)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.13), radius: 24, x: -8)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard value.translation.width > 70,
                          abs(value.translation.width) > abs(value.translation.height) * 1.35 else { return }
                    onClose()
                }
        )
        .task { await model.load() }
    }

    private var homeCards: some View {
        HStack(spacing: 8) {
            Button { select(.profile) } label: {
                HStack(spacing: 9) {
            Group {
                if let avatar {
                    Image(uiImage: avatar).resizable().scaledToFill()
                } else {
                    Image(systemName: "sparkles")
                        .foregroundColor(theme.textDim)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(Circle().stroke(theme.glassBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(assistantName).font(.system(size: 15, weight: .semibold))
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                }
                Text("\(model.days) days")
                    .font(.system(size: 25, weight: .light, design: .serif))
                Text(model.coinsLine)
                    .font(.system(size: 9.5))
                    .foregroundColor(theme.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 88)
                .drawerGlass(theme)
            }
            .buttonStyle(.plain)

            Button { select(.usage) } label: {
                VStack(spacing: 7) {
                    Text(model.fiveHourLine)
                    Divider().overlay(theme.glassBorder)
                    Text(model.sevenDayLine)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.textDim)
                .frame(width: 68)
                .frame(minHeight: 88)
                .drawerGlass(theme)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func handwritten(_ text: String) -> some View {
        Text(text)
            .font(.custom("Snell Roundhand", size: 17))
            .italic()
            .foregroundColor(theme.textDim.opacity(0.72))
            .rotationEffect(.degrees(-1.2))
            .padding(.leading, 5)
    }

    private func drawerTitle(_ title: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 12, weight: .semibold, design: .serif))
            Text(note).font(.custom("Snell Roundhand", size: 14))
                .foregroundColor(theme.textDim.opacity(0.62))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4).padding(.horizontal, 3)
    }

    private func drawerRow(_ target: HouseDestination, detail: String) -> some View {
        Button { select(target) } label: {
            HStack(spacing: 11) {
                Image(systemName: target.icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(theme.textDim)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.title).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.system(size: 9.5)).foregroundColor(theme.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textDim.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .drawerGlass(theme)
        }.buttonStyle(.plain)
    }

    private func drawerDisclosure(
        _ title: String,
        isExpanded: Binding<Bool>,
        items: () -> [HouseDestination]
    ) -> some View {
        VStack(spacing: 7) {
            Button { withAnimation(.easeInOut(duration: 0.18)) { isExpanded.wrappedValue.toggle() } } label: {
                HStack {
                    Text(title).font(.system(size: 12, weight: .semibold, design: .serif))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 43)
                .drawerGlass(theme)
            }.buttonStyle(.plain)
            if isExpanded.wrappedValue {
                ForEach(items()) { target in drawerRow(target, detail: drawerDetail(target)) }
            }
        }
    }

    private func drawerDetail(_ target: HouseDestination) -> String {
        switch target {
        case .memory: return "记忆库"
        case .dreams: return "梦与旧日记"
        case .portrait: return "写过的信"
        case .album: return "照片"
        case .nianlun: return "一起走过的时间"
        case .shelf: return "他的收藏架"
        case .impression: return "他认得的自己"
        case .clockwork: return "自主活动与唤醒"
        case .forge: return "挑选轮次搬去新窗口"
        case .search: return "搜索消息"
        case .favorites: return "收藏消息"
        case .wall: return model.wallLine
        case .usage: return model.usageLine
        case .digest: return "日结页面还在整理"
        default: return "打开"
        }
    }
}

private extension View {
    func drawerGlass(_ theme: AlcoveTheme) -> some View {
        self.background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .background(theme.glassTint.opacity(theme.isDark ? 0.12 : 0.24),
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(theme.glassBorder.opacity(0.72), lineWidth: 0.7))
    }
}

private struct NativeSidebarView: View {
    var select: (HouseDestination) -> Void
    let roundtableUnread: Int
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var model = SidebarModel()
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private let foyer: [HouseDestination] = [
        .memory, .dreams, .shelf, .desire, .nianlun, .clockwork, .album, .portrait, .impression,
        .morningPaper, .nowhere, .pulse
    ]
    // Pipe Lab remains compiled for rollback, but the -p experiment is paused and
    // must not appear as a normal household destination.
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
            .rotationEffect(theme.isPaper
                ? .degrees(Double(abs(target.rawValue.hashValue) % 9 - 4) * 0.10)
                : .zero)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class SidebarModel: ObservableObject {
    private struct Snapshot {
        var homeLine = "亲密度 --"
        var coins = 0
        var fiveHour = 0
        var sevenDay = 0
        var wallLine = "--"
        var usageLine = "--"
    }

    @Published private var snapshot = Snapshot()
    var homeLine: String { snapshot.homeLine }
    var coinsLine: String { "金币 \(snapshot.coins)" }
    var fiveHourLine: String { "5h \(snapshot.fiveHour)%" }
    var sevenDayLine: String { "7d \(snapshot.sevenDay)%" }
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
            next.coins = d.int("coins")
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
            next.fiveHour = five
            next.sevenDay = seven
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
    @State private var backendOnline = false
    @State private var codexOnline = false
    @State private var backendLatency: Int?
    @State private var codexLatency: Int?
    @State private var codexThreadConnected = false
    @State private var servicesLoading = false
    @State private var showSystemFeatures = false
    @State private var showQuietRoom = false
    @State private var replyLength = 240.0
    @State private var replyLengthLoaded = false
    @State private var replyLengthSaving = false
    @State private var replyLengthSaveTask: Task<Void, Never>?
    @State private var thoughtLength = 500.0
    @State private var thoughtLengthLoaded = false
    @State private var thoughtLengthSaving = false
    @State private var thoughtLengthSaveTask: Task<Void, Never>?
    @Environment(\.houseOwnsHeader) private var houseOwnsHeader
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
                section("陈璟的回复") {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("正文长度").font(.system(size: 13, weight: .medium))
                                Text(replyLength == 0 ? "不限制，让他一路写到底" : "每轮正文约 \(Int(replyLength)) 字以内")
                                    .font(.system(size: 10)).foregroundColor(theme.textDim)
                            }
                            Spacer()
                            Text(replyLength == 0 ? "不限" : "\(Int(replyLength)) 字")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.fyAccent)
                        }
                        Slider(value: $replyLength, in: 0...1200, step: 20)
                            .tint(theme.fyAccent)
                        HStack {
                            Text("不限")
                            Spacer()
                            if replyLengthSaving { ProgressView().scaleEffect(0.65) }
                            Text("1200 字")
                        }
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundColor(theme.textDim)
                    }
                    Divider().opacity(0.25)
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("思绪长度").font(.system(size: 13, weight: .medium))
                                Text(thoughtLength == 0 ? "不限制他的思考篇幅" : "每轮思绪约 \(Int(thoughtLength)) 字以内")
                                    .font(.system(size: 10)).foregroundColor(theme.textDim)
                            }
                            Spacer()
                            Text(thoughtLength == 0 ? "不限" : "\(Int(thoughtLength)) 字")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.fyAccent)
                        }
                        Slider(value: $thoughtLength, in: 0...1200, step: 20).tint(theme.fyAccent)
                        HStack {
                            Text("不限"); Spacer()
                            if thoughtLengthSaving { ProgressView().scaleEffect(0.65) }
                            Text("1200 字")
                        }
                        .font(.system(size: 9.5, design: .rounded)).foregroundColor(theme.textDim)
                    }
                }
                section("相处") {
                    Button { showQuietRoom = true } label: {
                        settingRow("留白", "让追问暂时安静下来") {
                            Image(systemName: "moon.stars")
                                .foregroundColor(theme.textLight)
                            Image(systemName: "chevron.right")
                                .foregroundColor(theme.textLight)
                        }
                    }.buttonStyle(.plain)
                }
                section("主题") {
                    HStack(spacing: 8) {
                        familyChoice("玻璃", "光穿过去", false, [.white, .pink.opacity(0.42), .gray])
                        familyChoice("纸页", "话落下来", true, [
                            Color(red: 243/255, green: 241/255, blue: 236/255),
                            Color(red: 185/255, green: 120/255, blue: 120/255),
                            Color(red: 37/255, green: 36/255, blue: 34/255)
                        ])
                    }
                    Divider().opacity(0.25)
                    Picker("外观", selection: appearanceBinding) {
                        Text("白天").tag(false)
                        Text("黑夜").tag(true)
                    }.pickerStyle(.segmented)
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
                section("服务") {
                    serviceCard(
                        name: "Alcove Backend",
                        address: "https://alcove.ob-memory.uk",
                        online: backendOnline,
                        latency: backendLatency,
                        detail: "App 接口 · 消息 · 附件 · OB 代理"
                    )
                    Divider().opacity(0.25)
                    serviceCard(
                        name: "何渡 · Codex",
                        address: "local://alcove-codex/appserver.sock",
                        online: codexOnline,
                        latency: codexLatency,
                        detail: codexThreadConnected ? "独立常驻 · 当前线程已连接" : "独立常驻 · 等待线程连接"
                    )
                    Button { Task { await loadServices() } } label: {
                        Label(servicesLoading ? "刷新中" : "刷新服务状态", systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textDim)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(servicesLoading)
                }
                section("系统联动") {
                    Button { showSystemFeatures = true } label: {
                        settingRow("灵动岛与屏幕控制", "工作状态同步、屏幕共享") {
                            Image(systemName: "chevron.right")
                                .foregroundColor(theme.textLight)
                        }
                    }
                    .buttonStyle(.plain)
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
        .sheet(isPresented: $showSystemFeatures) {
            SystemFeaturesView()
        }
        .sheet(isPresented: $showQuietRoom) {
            QuietRoomView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .onChange(of: userPhoto) { item in loadDataURL(item, into: $userAvatar) }
        .onChange(of: aiPhoto) { item in loadDataURL(item, into: $assistantAvatar) }
        .onChange(of: wallPhoto) { item in saveWallpaper(item) }
        .onChange(of: replyLength) { value in scheduleReplyLengthSave(value) }
        .onChange(of: thoughtLength) { value in scheduleThoughtLengthSave(value) }
        .task {
            async let services: Void = loadServices()
            async let reply: Void = loadReplyLength()
            async let thought: Void = loadThoughtLength()
            _ = await (services, reply, thought)
        }
    }

    @ViewBuilder private func panelTitle(_ text: String) -> some View {
        if !houseOwnsHeader {
            Text(text).font(.system(size: 17, weight: .semibold)).padding(.top, 11)
        }
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

    private func serviceCard(
        name: String, address: String, online: Bool, latency: Int?, detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(name).font(.system(size: 14, weight: .medium))
                Spacer()
                Circle().fill(online ? Color.green : Color.red.opacity(0.8)).frame(width: 8, height: 8)
                Text(online ? "在线" : "离线")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(online ? .green : .red.opacity(0.8))
            }
            Text(address).font(.system(size: 11, design: .monospaced)).foregroundColor(theme.textLight)
            HStack {
                Text(detail)
                Spacer()
                if let latency { Text("\(latency)ms") }
            }
            .font(.system(size: 10)).foregroundColor(theme.textDim)
        }
        .padding(.vertical, 2)
    }

    @MainActor private func loadServices() async {
        servicesLoading = true
        let started = Date()
        do {
            let value = try await NativeHouseAPI.object("/services/status")
            let backend = value.object("backend")
            let codex = value.object("codex")
            backendOnline = backend.bool("online")
            backendLatency = max(backend.int("latency_ms"), Int(Date().timeIntervalSince(started) * 1000))
            codexOnline = codex.bool("online")
            codexLatency = codex["latency_ms"] is NSNull ? nil : codex.int("latency_ms")
            codexThreadConnected = codex.bool("thread_connected")
        } catch {
            backendOnline = false; codexOnline = false
            backendLatency = nil; codexLatency = nil; codexThreadConnected = false
        }
        servicesLoading = false
    }

    @MainActor private func loadReplyLength() async {
        if let value = try? await NativeHouseAPI.object("/api/reply-len") {
            replyLength = Double(value.int("chars"))
        }
        replyLengthLoaded = true
    }

    private func scheduleReplyLengthSave(_ value: Double) {
        guard replyLengthLoaded else { return }
        replyLengthSaveTask?.cancel()
        replyLengthSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            replyLengthSaving = true
            defer { replyLengthSaving = false }
            _ = try? await NativeHouseAPI.object(
                "/api/reply-len", method: "POST", body: ["chars": Int(value)]
            )
        }
    }

    @MainActor private func loadThoughtLength() async {
        if let value = try? await NativeHouseAPI.object("/api/reply-len") {
            thoughtLength = Double(value.int("thought_chars"))
        }
        thoughtLengthLoaded = true
    }

    private func scheduleThoughtLengthSave(_ value: Double) {
        guard thoughtLengthLoaded else { return }
        thoughtLengthSaveTask?.cancel()
        thoughtLengthSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            thoughtLengthSaving = true
            defer { thoughtLengthSaving = false }
            _ = try? await NativeHouseAPI.object(
                "/api/reply-len", method: "POST", body: ["thought_chars": Int(value)]
            )
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

    private var isPaperFamily: Bool { themeName == "paper" || themeName == "paper-dark" }
    private var appearanceBinding: Binding<Bool> {
        Binding(get: { theme.isDark }, set: { dark in
            themeName = isPaperFamily ? (dark ? "paper-dark" : "paper")
                                      : (dark ? "midnight" : "haven")
        })
    }
    private func familyChoice(_ title: String, _ sub: String, _ paper: Bool, _ colors: [Color]) -> some View {
        Button {
            themeName = paper ? (theme.isDark ? "paper-dark" : "paper")
                              : (theme.isDark ? "midnight" : "haven")
        } label: {
            VStack(spacing: 7) {
                HStack(spacing: 4) { ForEach(colors.indices, id: \.self) { Circle().fill(colors[$0]).frame(width: 13, height: 13) } }
                Text(title).font(.system(size: 13, weight: .medium))
                Text(sub).font(.system(size: 10)).foregroundColor(theme.textLight)
            }.frame(maxWidth: .infinity).padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: theme.isPaper ? 3 : 12)
                    .stroke(isPaperFamily == paper ? theme.fyAccent : theme.fyBorder, lineWidth: 1.4))
        }.buttonStyle(.plain)
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
            let file = ChatWallpaperStore.fileName(for: themeName)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(file)
            try? jpeg.write(to: url, options: .atomic)
            wallStamp = Date().timeIntervalSince1970
        }
    }

    private func resetWallpaper() {
        let file = ChatWallpaperStore.fileName(for: themeName)
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

    func cardText(message: String) -> String? {
        var copy = self
        copy.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = try? JSONEncoder().encode(copy),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return "[MUSIC_CARD]\(json)[/MUSIC_CARD]"
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

enum MusicPlayMode: String, CaseIterable {
    case sequence, shuffle, repeatOne

    var icon: String {
        switch self {
        case .sequence: return "repeat"
        case .shuffle: return "shuffle"
        case .repeatOne: return "repeat.1"
        }
    }
    var title: String {
        switch self {
        case .sequence: return "顺序播放"
        case .shuffle: return "随机播放"
        case .repeatOne: return "单曲循环"
        }
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
    @Published var queue: [MusicSong] = []
    @Published var queueIndex = -1
    @Published var playMode: MusicPlayMode = .sequence
    @Published var playbackLoading = false
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var streamCache: [String: (url: URL, expires: Date)] = [:]
    private var streamPrefetchTask: Task<Void, Never>?
    private var playbackPoll: Task<Void, Never>?

    private init() {
        configureRemoteCommands()
    }

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
        prefetchArtwork(for: songs)
        if songs.isEmpty { message = "没搜到  换个词试试" }
    }

    func play(_ song: MusicSong, queue source: [MusicSong]? = nil) async {
        if let source, !source.isEmpty {
            queue = source
            queueIndex = source.firstIndex(where: { $0.id == song.id }) ?? 0
        } else if let index = queue.firstIndex(where: { $0.id == song.id }) {
            queueIndex = index
        } else if let index = songs.firstIndex(where: { $0.id == song.id }) {
            queue = songs
            queueIndex = index
        } else {
            // A music card has no list of its own. Keep the last real queue
            // behind it so playback can still continue when the card ends.
            queue = [song] + queue.filter { $0.id != song.id }
            queueIndex = 0
        }
        playbackLoading = true
        guard let url = await streamURL(for: song.id) else {
            message = "这首暂时放不了"
            playbackLoading = false
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
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2
        let nextPlayer = AVPlayer(playerItem: item)
        nextPlayer.automaticallyWaitsToMinimizeStalling = false
        player = nextPlayer
        nowPlaying = song
        isPlaying = false
        progress = 0; duration = 0
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor in
                guard let self, let item, self.player?.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    self.player?.playImmediately(atRate: 1)
                case .failed:
                    self.playbackLoading = false
                    self.isPlaying = false
                    self.message = item.error?.localizedDescription ?? "这首没有成功加载"
                default: break
                }
            }
        }
        timeControlObserver = nextPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self, weak nextPlayer] _, _ in
            Task { @MainActor in
                guard let self, let nextPlayer, self.player === nextPlayer else { return }
                self.isPlaying = nextPlayer.timeControlStatus == .playing
                if self.isPlaying { self.playbackLoading = false }
                self.publishNowPlaying()
            }
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
                    self.publishNowPlaying()
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackEnded()
            }
        }
        await loadLyrics(song.id)
        publishNowPlaying(loadArtwork: true)
        await reportNowPlaying()
        prefetchNextStream()
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
        prefetchArtwork(for: playlistSongs)
    }

    func toggle() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        publishNowPlaying()
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        progress = seconds
        publishNowPlaying()
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == false { self?.toggle() } }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == true { self?.toggle() } }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.prev() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func publishNowPlaying(loadArtwork: Bool = false) {
        guard let song = nowPlaying else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = song.name
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        guard loadArtwork, let url = URL(string: song.cover) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data), self.nowPlaying?.id == song.id else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            updated[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        }
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

    func cyclePlayMode() {
        switch playMode {
        case .sequence: playMode = .shuffle
        case .shuffle: playMode = .repeatOne
        case .repeatOne: playMode = .sequence
        }
    }

    func prev() {
        guard !queue.isEmpty else { return }
        if progress > 4 { seek(to: 0); return }
        let index = queueIndex > 0 ? queueIndex - 1 : queue.count - 1
        playQueueItem(at: index)
    }

    func next() { advance(automatic: false) }

    var hasPrev: Bool { queue.count > 1 || progress > 0 }
    var hasNext: Bool { queue.count > 1 }

    private func handleTrackEnded() {
        if playMode == .repeatOne {
            seek(to: 0)
            player?.play()
            isPlaying = true
            return
        }
        advance(automatic: true)
    }

    private func advance(automatic _: Bool) {
        guard !queue.isEmpty else { return }
        let nextIndex: Int
        switch playMode {
        case .shuffle:
            if queue.count == 1 { nextIndex = 0 }
            else {
                var candidate = queueIndex
                while candidate == queueIndex { candidate = Int.random(in: 0..<queue.count) }
                nextIndex = candidate
            }
        case .sequence, .repeatOne:
            let candidate = queueIndex + 1
            if candidate >= queue.count {
                nextIndex = 0
            } else { nextIndex = candidate }
        }
        playQueueItem(at: nextIndex)
    }

    private func playQueueItem(at index: Int) {
        guard queue.indices.contains(index) else { return }
        queueIndex = index
        let song = queue[index]
        Task { await play(song, queue: queue) }
    }

    private func cleanup() {
        itemStatusObserver?.invalidate(); itemStatusObserver = nil
        timeControlObserver?.invalidate(); timeControlObserver = nil
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver); self.endObserver = nil }
    }

    private func streamURL(for songID: String) async -> URL? {
        if let cached = streamCache[songID], cached.expires > Date() { return cached.url }
        guard let obj = try? await NativeHouseAPI.object("/api/music/song/url?id=\(songID)&br=128000"),
              let rows = obj["data"] as? [[String: Any]],
              let raw = rows.first?.string("url"), !raw.isEmpty else { return nil }
        let url = raw.hasPrefix("/") ? AlcoveAPI.fullURL(raw) : URL(string: MusicSong.secureURL(raw))
        if let url { streamCache[songID] = (url, Date().addingTimeInterval(15 * 60)) }
        return url
    }

    private func prefetchNextStream() {
        streamPrefetchTask?.cancel()
        guard !queue.isEmpty else { return }
        let nextIndex = (queueIndex + 1) % queue.count
        let id = queue[nextIndex].id
        streamPrefetchTask = Task { [weak self] in _ = await self?.streamURL(for: id) }
    }

    private func prefetchArtwork(for songs: [MusicSong]) {
        let urls = songs.prefix(16).compactMap { Self.artworkURL($0.cover) }
        Task.detached(priority: .utility) {
            for url in urls { _ = try? await URLSession.shared.data(from: url) }
        }
    }

    static func artworkURL(_ raw: String, pixels: Int = 600) -> URL? {
        guard !raw.isEmpty else { return nil }
        let separator = raw.contains("?") ? "&" : "?"
        return URL(string: "\(raw)\(separator)param=\(pixels)y\(pixels)")
    }
}

private struct NativeMusicView: View {
    @ObservedObject private var model = MusicModel.shared
    @State private var query = ""
    @State private var selectedPlaylist: MusicPlaylist?
    @State private var showPlayer = false
    @State private var giftSong: MusicSong?
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
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $giftSong) { song in
            MusicGiftSheet(song: song) { giftSong = nil }
                .presentationDetents([.medium])
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
                    Button { if let first = model.playlistSongs.first { Task { await model.play(first, queue: model.playlistSongs) } } } label: {
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
                    HStack(spacing: 11) {
                        Button {
                            Task { await model.play(song, queue: songs) }
                        } label: {
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
                            }
                        }
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                        Button { giftSong = song } label: {
                            Image(systemName: "paperplane")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.fyAccent)
                                .frame(width: 34, height: 34)
                                .background(theme.fyCardSub.opacity(0.72), in: Circle())
                        }.buttonStyle(.plain)
                    }.padding(.horizontal, 10).padding(.vertical, 6)
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

private struct MusicGiftSheet: View {
    let song: MusicSong
    let dismiss: () -> Void
    @State private var note = ""
    @State private var sending = false
    @State private var failed = false
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 16) {
            Text("送给陈璟")
                .font(.system(size: 20, weight: .semibold, design: .serif))
            HStack(spacing: 13) {
                AsyncImage(url: URL(string: song.cover)) { $0.resizable().scaledToFill() }
                    placeholder: { theme.fyCardSub }
                    .frame(width: 66, height: 66).clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                    Text(song.artist).font(.system(size: 12)).foregroundColor(theme.textDim)
                }
                Spacer()
                Image(systemName: "paperplane.fill").foregroundColor(theme.fyAccent)
            }
            .padding(12).foyerCard(theme)
            VStack(alignment: .leading, spacing: 6) {
                Text("捎一句话给他").font(.system(size: 11, weight: .medium)).foregroundColor(theme.textDim)
                TextField("为什么想把这首歌送给他…", text: $note, axis: .vertical)
                    .lineLimit(3...6).font(.system(size: 13))
                    .padding(11).background(theme.fyCardSub.opacity(0.62), in: RoundedRectangle(cornerRadius: 13))
            }
            if failed { Text("没送出去，再点一次试试").font(.system(size: 10)).foregroundColor(.red) }
            Button {
                guard !sending, let text = song.cardText(message: note) else { return }
                sending = true; failed = false
                Task {
                    do { _ = try await AlcoveAPI.send(text: text); dismiss() }
                    catch { failed = true; sending = false }
                }
            } label: {
                HStack { if sending { ProgressView().tint(.white) }; Text(sending ? "正在送给他" : "送给他"); Image(systemName: "paperplane.fill") }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 44)
                    .background(theme.fyAccent, in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain).disabled(sending)
        }
        .padding(20).foregroundColor(theme.text)
    }
}

struct MusicMessageCard: View {
    let song: MusicSong
    let theme: AlcoveTheme
    let isUser: Bool
    let play: () -> Void
    @ObservedObject private var model = MusicModel.shared
    @State private var messageExpanded = false

    private var isCurrent: Bool { model.nowPlaying?.id == song.id }
    private var isPlaying: Bool { isCurrent && model.isPlaying }
    private var progressFraction: Double {
        guard isCurrent, model.duration > 0 else { return 0 }
        return min(max(model.progress / model.duration, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(isUser ? "♫ 送给陈璟" : "♫ 为你点播")
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
                Button {
                    // A card may point at the same song that was previewed in the
                    // music page, while that old AVPlayer is already paused,
                    // expired or failed.  Re-open the stream instead of toggling
                    // a stale player; only the visible playing state is paused.
                    if isCurrent && isPlaying { model.toggle() } else { play() }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundColor(theme.text)
                        .frame(width: 44, height: 44)
                        .background(theme.fyCardSub, in: Circle())
                }.buttonStyle(.plain)
            }
            if !song.message.isEmpty {
                HStack(alignment: .bottom, spacing: 5) {
                    Text("›  \(song.message)")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textDim)
                        .lineLimit(messageExpanded ? nil : 3)
                    if song.message.count > 54 {
                        Button { withAnimation(.easeInOut(duration: 0.18)) { messageExpanded.toggle() } } label: {
                            Image(systemName: "chevron.down.circle")
                                .font(.system(size: 13, weight: .medium))
                                .rotationEffect(.degrees(messageExpanded ? 180 : 0))
                                .foregroundColor(theme.textDim)
                        }.buttonStyle(.plain)
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.fyAccent.opacity(0.18))
                    Capsule().fill(theme.fyAccent.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(progressFraction))
                }
            }
            .frame(height: 2)
            .animation(.linear(duration: 0.35), value: progressFraction)
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
    @State private var page = 0
    @State private var showQueue = false

    var body: some View {
        GeometryReader { bounds in
            ZStack {
                if let cover = model.nowPlaying?.cover {
                    AsyncImage(url: MusicModel.artworkURL(cover)) { image in
                        image.resizable().scaledToFill()
                            .frame(width: bounds.size.width, height: bounds.size.height)
                            .clipped()
                    } placeholder: {
                        LinearGradient(colors: theme.splashBg, startPoint: .top, endPoint: .bottom)
                            .frame(width: bounds.size.width, height: bounds.size.height)
                    }
                    .frame(width: bounds.size.width, height: bounds.size.height)
                    .clipped()
                    .blur(radius: 48).opacity(0.42)
                }
                LinearGradient(colors: [.black.opacity(0.22), .black.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: bounds.size.width, height: bounds.size.height)
                Group {
                    if page == 0 { playerPage }
                    else { lyricPage }
                }
                .frame(width: bounds.size.width, height: bounds.size.height)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 28)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height),
                                  abs(value.translation.width) > 45 else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                if value.translation.width < 0 { page = 1 }
                                else { page = 0 }
                            }
                        }
                )
            }
            .frame(width: bounds.size.width, height: bounds.size.height)
            .clipped()
        }
        .ignoresSafeArea(edges: .bottom)
        .foregroundColor(.white)
        .sheet(isPresented: $showQueue) { MusicQueueSheet(model: model) }
    }

    private var playerPage: some View {
        VStack(spacing: 0) {
            if let song = model.nowPlaying {
                playerHeader(song)
                Spacer(minLength: 4)
                record(song, size: 190)
                Spacer(minLength: 8)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name).font(.system(size: 21, weight: .semibold)).lineLimit(1)
                        Text(song.artist).font(.system(size: 13)).foregroundColor(.white.opacity(0.62)).lineLimit(1)
                    }
                    Spacer()
                    likeButton
                }.padding(.horizontal, 28)
                progressControls
                playbackControls
                pageDots
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var lyricPage: some View {
        VStack(spacing: 0) {
            if let song = model.nowPlaying { playerHeader(song) }
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .center, spacing: 20) {
                    Color.clear.frame(height: 70)
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
                                        .foregroundColor(index == activeLyric ? .white : .white.opacity(0.68))
                                    if let trans = line.translation, !trans.isEmpty {
                                        Text(trans).font(.system(size: 11)).foregroundColor(.white.opacity(0.62))
                                            .multilineTextAlignment(.center)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .center)
                                    .opacity(index == activeLyric ? 1 : 0.86)
                            }.buttonStyle(.plain).id(index)
                        }
                    }
                    Color.clear.frame(height: 110)
                }.frame(maxWidth: .infinity).padding(.horizontal, 26)
                }
            .onChange(of: activeLyric) { idx in
                guard idx >= 0 else { return }
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(idx, anchor: .center) }
            }
            }
            HStack { likeButton; Spacer(); Image(systemName: "quote.bubble").font(.system(size: 19)) }
                .padding(.horizontal, 34).padding(.top, 8)
            progressControls
            playbackControls
            pageDots
        }
    }

    private func playerHeader(_ song: MusicSong) -> some View {
        VStack(spacing: 2) {
            Text(song.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
            Text(song.artist).font(.system(size: 10)).foregroundColor(.white.opacity(0.55)).lineLimit(1)
        }.frame(maxWidth: .infinity).padding(.horizontal, 48).padding(.top, 16).padding(.bottom, 8)
    }

    private func record(_ song: MusicSong, size: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle().fill(.black.opacity(0.82))
                ForEach(1..<7) { ring in
                    Circle().stroke(.white.opacity(0.035), lineWidth: 1)
                        .padding(CGFloat(ring) * 11)
                }
                AsyncImage(url: MusicModel.artworkURL(song.cover)) { $0.resizable().scaledToFill() }
                    placeholder: { Color.white.opacity(0.08) }
                    .frame(width: size * 0.57, height: size * 0.57).clipShape(Circle())
                Circle().fill(.black.opacity(0.7)).frame(width: 12, height: 12)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
            ZStack(alignment: .top) {
                Circle().fill(.black.opacity(0.7)).frame(width: 34, height: 34)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                Capsule().fill(.white.opacity(0.72)).frame(width: 8, height: size * 0.48)
                    .overlay(alignment: .bottom) { Capsule().fill(.black.opacity(0.78)).frame(width: 18, height: 35).offset(y: 18) }
                    .offset(y: 18)
            }
            .rotationEffect(.degrees(model.isPlaying ? 22 : 8), anchor: .top)
            .animation(.easeInOut(duration: 0.45), value: model.isPlaying)
            .offset(x: 12, y: -17)
        }.frame(width: size + 35, height: size)
    }

    private var likeButton: some View {
        Button { Task { await model.toggleLike() } } label: {
            Image(systemName: model.currentIsLiked ? "heart.fill" : "heart")
                .font(.system(size: 23))
                .foregroundColor(model.currentIsLiked ? .red : .white)
                .frame(width: 42, height: 42)
        }.buttonStyle(.plain)
    }

    private var progressControls: some View {
        VStack(spacing: 2) {
            Slider(value: Binding(get: { model.progress }, set: { model.seek(to: $0) }),
                   in: 0...max(model.duration, 1)).tint(.white)
            HStack {
                Text(Self.time(model.progress)); Spacer(); Text(Self.time(model.duration))
            }.font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.52))
        }.padding(.horizontal, 30).padding(.top, 6)
    }

    private var playbackControls: some View {
        HStack {
            Button { model.cyclePlayMode() } label: {
                Image(systemName: model.playMode.icon).frame(width: 38)
            }.accessibilityLabel(model.playMode.title)
            Spacer()
            Button { model.prev() } label: { Image(systemName: "backward.fill") }
            Spacer()
            Button { model.toggle() } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 58, height: 58)
                    if model.playbackLoading { ProgressView().tint(.black) }
                    else { Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 24)) }
                }.foregroundColor(.black)
            }
            Spacer()
            Button { model.next() } label: { Image(systemName: "forward.fill") }
            Spacer()
            Button { showQueue = true } label: { Image(systemName: "list.bullet") }.frame(width: 38)
        }
        .font(.system(size: 20)).buttonStyle(.plain)
        .padding(.horizontal, 27).padding(.vertical, 5)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            Circle().fill(.white.opacity(page == 0 ? 0.9 : 0.28)).frame(width: 5, height: 5)
            Circle().fill(.white.opacity(page == 1 ? 0.9 : 0.28)).frame(width: 5, height: 5)
        }.padding(.bottom, 10)
    }

    private var activeLyric: Int {
        model.lyrics.lastIndex(where: { $0.time <= model.progress }) ?? -1
    }
    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

}

private struct MusicQueueSheet: View {
    @ObservedObject var model: MusicModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Array(model.queue.enumerated()), id: \.element.id) { index, song in
                Button {
                    let source = model.queue
                    Task {
                        await model.play(song, queue: source)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: index == model.queueIndex ? "waveform" : "music.note")
                            .foregroundColor(index == model.queueIndex ? .accentColor : .secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.name).lineLimit(1)
                            Text(song.artist).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }.buttonStyle(.plain)
            }
            .navigationTitle("播放列表 · \(model.playMode.title)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct QuietRoomView: View {
    @State private var quiet = false
    @State private var until = ""
    @State private var loading = true
    @State private var sending = false
    @State private var error = ""
    @State private var chosenHours = 2
    @State private var choosingDuration = false
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("留白")
                    .font(.custom("Snell Roundhand", size: 31))
                Text("有些时候，安静也是一种靠近")
                    .font(.system(size: 11)).foregroundColor(theme.textDim)
            }

            if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 45)
            } else if quiet {
                VStack(alignment: .leading, spacing: 10) {
                    Label("此刻正在留白", systemImage: "moon.zzz.fill")
                        .font(.system(size: 16, weight: .semibold))
                    if !until.isEmpty {
                        Text("会安静到 \(displayUntil)")
                            .font(.system(size: 11)).foregroundColor(theme.textDim)
                    }
                    Button { setQuiet(on: false) } label: {
                        Label("让声音回来", systemImage: "sunrise")
                            .frame(maxWidth: .infinity).frame(height: 45)
                            .background(theme.fyAccent.opacity(0.88), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundColor(.white)
                    }.buttonStyle(.plain).disabled(sending)
                }
                .padding(15).foyerCard(theme)
            } else {
                HStack(spacing: 12) {
                    quietChoice("今夜无声", "今晚先不追问\n明早十点再来", "moon.stars.fill") {
                        setQuiet(on: true)
                    }
                    quietChoice("借我片刻", "安静两个小时\n再轻轻回来", "hourglass") {
                        choosingDuration = true
                    }
                }
            }
            if !error.isEmpty {
                Text(error).font(.system(size: 10)).foregroundColor(.red.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .foregroundColor(theme.text)
        .sheet(isPresented: $choosingDuration) {
            NavigationStack {
                VStack(spacing: 22) {
                    Text("想安静多久").font(.system(size: 22, weight: .semibold, design: .serif))
                    Picker("静默时长", selection: $chosenHours) {
                        ForEach(1...24, id: \.self) { Text("\($0) 小时").tag($0) }
                    }.pickerStyle(.wheel).frame(height: 180)
                    Button { choosingDuration = false; setQuiet(on: true, hours: chosenHours) } label: {
                        Text("安静 \(chosenHours) 小时").font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 46)
                    }.buttonStyle(.borderedProminent).tint(theme.fyAccent)
                }.padding(22).foregroundColor(theme.text)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { choosingDuration = false } } }
            }.presentationDetents([.height(360)])
        }
        .task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func quietChoice(
        _ title: String, _ subtitle: String, _ icon: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 19)).foregroundColor(theme.fyAccent)
                Text(title).font(.system(size: 15, weight: .semibold, design: .serif))
                Text(subtitle).font(.system(size: 10)).foregroundColor(theme.textDim)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).foyerCard(theme)
        }.buttonStyle(.plain).disabled(sending)
    }

    @MainActor private func refresh() async {
        guard let value = try? await NativeHouseAPI.object("/api/quiet") else {
            loading = false; error = "暂时读不到后端状态"; return
        }
        quiet = value.bool("quiet")
        until = value.string("until")
        loading = false
        error = ""
    }

    private func setQuiet(on: Bool, hours: Int? = nil) {
        guard !sending else { return }
        sending = true; error = ""
        Task { @MainActor in
            var body: [String: Any] = ["on": on]
            if let hours { body["hours"] = hours }
            do {
                _ = try await NativeHouseAPI.object("/api/quiet", method: "POST", body: body)
                await refresh()
            } catch { self.error = "没有送到后端，再试一次" }
            sending = false
        }
    }

    private var displayUntil: String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let regular = ISO8601DateFormatter()
        guard let date = fractional.date(from: until) ?? regular.date(from: until) else { return "结束时间读取中" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "zh_CN")
        out.timeZone = TimeZone(identifier: "Asia/Shanghai")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = out.timeZone
        if calendar.isDateInToday(date) {
            out.dateFormat = "HH:mm"
            return "今天 \(out.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            out.dateFormat = "HH:mm"
            return "明天 \(out.string(from: date))"
        }
        out.dateFormat = "M月d日 HH:mm"
        return out.string(from: date)
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
    private let hoduItems = [
        ClockworkItem(id: "hodu_autonomy", emoji: "🧠", name: "自主活动", desc: "随机醒来，自己找点想做的事")
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
                    HStack {
                        Text("何渡的发条")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.textDim)
                        Rectangle().fill(theme.textDim.opacity(0.2)).frame(height: 0.5)
                    }
                    .padding(.top, 8)
                    ForEach(hoduItems) { item in
                        let isOn = flags[item.id] ?? true
                        HStack(spacing: 14) {
                            Text(item.emoji).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.system(size: 14, weight: .medium))
                                Text(item.desc)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(theme.textDim)
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

// MARK: - 共读室

private struct CoreadBook: Identifiable, Hashable {
    let id: String
    let title: String
    let chapters: Int
    let currentChapter: Int
    let chapterTitles: [String]
    let coverURL: String?

    init(_ value: [String: Any]) {
        id = value.string("id")
        title = value.string("title")
        chapters = value.int("total_chapters")
        currentChapter = value.int("current_chapter")
        chapterTitles = value["chapter_titles"] as? [String] ?? []
        coverURL = value.string("cover_url", "cover").isEmpty ? nil : value.string("cover_url", "cover")
    }
}

private struct NativeCoreadRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var books: [CoreadBook] = []
    @State private var selected: CoreadBook?
    @State private var reading: (CoreadBook, Int)?
    @State private var page = 0
    @State private var loading = true
    @State private var error = ""

    private var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 19
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(isNight ? "CoreadNight" : "CoreadDay")
                    .resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped().ignoresSafeArea()

                if let (book, chapter) = reading {
                    CoreadReaderView(book: book, chapter: chapter) { reading = nil }
                } else if let book = selected {
                    CoreadDetailView(book: book, onBack: { selected = nil }) { chapter in
                        reading = (book, chapter)
                    }
                } else {
                    shelf(geo)
                }

                if selected == nil && reading == nil {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.31))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.64), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .position(x: 34, y: max(geo.safeAreaInsets.top + 22, 43))
                }
            }
        }
        .task { await loadBooks() }
    }

    @ViewBuilder private func shelf(_ geo: GeometryProxy) -> some View {
        let pages = max(1, Int(ceil(Double(books.count) / 6.0)))
        VStack(spacing: 0) {
            Spacer().frame(height: geo.size.height * 0.278)
            if loading { ProgressView().tint(.pink.opacity(0.7)) }
            else if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundColor(.secondary) }
            else {
                TabView(selection: $page) {
                    ForEach(0..<pages, id: \.self) { pageIndex in
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3), spacing: 28) {
                            ForEach(Array(books.dropFirst(pageIndex * 6).prefix(6))) { book in
                                Button { selected = book } label: { CoreadBookSlot(book: book) }
                                    .buttonStyle(CoreadPressStyle())
                            }
                        }
                        .padding(.horizontal, geo.size.width * 0.072)
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: geo.size.height * 0.405)
                Text("\(page + 1) / \(pages)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.47, green: 0.39, blue: 0.43).opacity(0.7))
                    .padding(.top, 3)
            }
            Spacer()
            HStack(spacing: 34) {
                coreadAction("正在共读", "person.2.fill") {
                    if let book = books.first { reading = (book, min(book.currentChapter, max(0, book.chapters - 1))) }
                }
                coreadAction("随机抽一本", "dice.fill") {
                    if let book = books.randomElement() { selected = book }
                }
            }
            .padding(.bottom, max(geo.safeAreaInsets.bottom + 14, 30))
        }
    }

    private func coreadAction(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.37, green: 0.29, blue: 0.33))
                .padding(.horizontal, 14).frame(height: 42)
                .background(.white.opacity(0.66), in: Capsule())
        }.buttonStyle(CoreadPressStyle())
    }

    @MainActor private func loadBooks() async {
        loading = true; defer { loading = false }
        do {
            books = try await NativeHouseAPI.array("/read/api/books").map(CoreadBook.init)
            error = ""
        } catch { self.error = "书架暂时没有递过来" }
    }
}

private struct CoreadPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CoreadBookSlot: View {
    let book: CoreadBook
    private let colors: [[Color]] = [
        [Color(red: 0.76, green: 0.65, blue: 0.70), Color(red: 0.92, green: 0.84, blue: 0.86)],
        [Color(red: 0.58, green: 0.65, blue: 0.69), Color(red: 0.81, green: 0.85, blue: 0.84)],
        [Color(red: 0.69, green: 0.64, blue: 0.76), Color(red: 0.87, green: 0.82, blue: 0.89)]
    ]
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: colors[abs(book.id.hashValue) % colors.count], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "book.closed.fill").font(.system(size: 22, weight: .light)).foregroundColor(.white.opacity(0.5))
                Text(book.title).font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundColor(.white).multilineTextAlignment(.center).lineLimit(4).padding(8)
            }
            .aspectRatio(0.68, contentMode: .fit)
            .shadow(color: .black.opacity(0.09), radius: 3, y: 2)
            Text(book.title).font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.32, green: 0.27, blue: 0.29)).lineLimit(1)
            ProgressView(value: book.chapters == 0 ? 0 : Double(book.currentChapter + 1) / Double(book.chapters))
                .tint(Color(red: 0.75, green: 0.47, blue: 0.55)).scaleEffect(y: 0.55)
        }
    }
}

private struct CoreadDetailView: View {
    let book: CoreadBook
    let onBack: () -> Void
    let open: (Int) -> Void
    var body: some View {
        VStack(spacing: 18) {
            HStack { Button(action: onBack) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }; Spacer() }
            .padding(.top, 48).padding(.horizontal, 14)
            CoreadBookSlot(book: book).frame(width: 128)
            Text(book.title).font(.system(size: 22, weight: .semibold, design: .serif)).multilineTextAlignment(.center)
            Text("共 \(book.chapters) 章 · 已读到第 \(min(book.currentChapter + 1, book.chapters)) 章")
                .font(.system(size: 12)).foregroundColor(.secondary)
            Button { open(min(book.currentChapter, max(0, book.chapters - 1))) } label: {
                Label("继续读下去", systemImage: "book.pages.fill").frame(maxWidth: .infinity).frame(height: 48)
            }.buttonStyle(.borderedProminent).tint(Color(red: 0.67, green: 0.43, blue: 0.51)).padding(.horizontal, 46)
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(0..<book.chapters, id: \.self) { index in
                        Button { open(index) } label: {
                            HStack { Text(book.chapterTitles.indices.contains(index) ? book.chapterTitles[index] : "第 \(index + 1) 章"); Spacer(); Image(systemName: "chevron.right") }
                                .font(.system(size: 13, design: .serif)).padding(14)
                                .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 13))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 24)
            }
        }.foregroundColor(Color(red: 0.29, green: 0.24, blue: 0.27))
    }
}

private struct CoreadReaderView: View {
    let book: CoreadBook
    let chapter: Int
    let onBack: () -> Void
    @State private var title = ""
    @State private var content = ""
    @State private var showChat = false
    @State private var samePage = false
    @State private var knocked = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                Text(title.isEmpty ? book.title : title).font(.system(size: 14, weight: .semibold, design: .serif)).lineLimit(1)
                Spacer()
                if samePage { Label("同页", systemImage: "person.2.fill").font(.system(size: 10, weight: .medium)).foregroundColor(.pink) }
                Button { Task { await knock() } } label: { Image(systemName: knocked ? "hand.wave.fill" : "hand.wave") }.frame(width: 44, height: 44)
                Button { showChat = true } label: { Image(systemName: "bubble.left.and.bubble.right.fill") }.frame(width: 44, height: 44)
            }.padding(.top, 44).padding(.horizontal, 8).background(.white.opacity(0.77))
            ScrollView {
                Text(content).font(.system(size: 17, design: .serif)).lineSpacing(9)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.vertical, 24)
            }.background(Color(red: 0.985, green: 0.965, blue: 0.965).opacity(0.9))
        }
        .foregroundColor(Color(red: 0.27, green: 0.23, blue: 0.25))
        .task { await load(); await heartbeat() }
        .sheet(isPresented: $showChat) { CoreadChatSheet(book: book, chapter: chapter, pageText: String(content.prefix(1800))) }
    }
    @MainActor private func load() async {
        guard let value = try? await NativeHouseAPI.object("/read/api/book/\(book.id)/chapter/\(chapter)") else { return }
        title = value.string("title"); content = value.string("content")
    }
    @MainActor private func heartbeat() async {
        try? await NativeHouseAPI.post("/api/coread/presence", body: ["actor":"陈霁", "book_id":book.id, "chapter":chapter, "offset":0])
        if let value = try? await NativeHouseAPI.object("/api/coread/presence?book_id=\(book.id)") { samePage = value.bool("same_page") }
    }
    @MainActor private func knock() async {
        guard !content.isEmpty else { return }
        try? await NativeHouseAPI.post("/api/coread/knock", body: ["book_id":book.id, "chapter":chapter, "page_text":String(content.prefix(1800))])
        knocked = true
    }
}

private struct CoreadChatSheet: View {
    let book: CoreadBook
    let chapter: Int
    let pageText: String
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [[String: Any]] = []
    @State private var text = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("陪读 · \(book.title)").font(.system(size: 15, weight: .semibold, design: .serif)); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark") } }.padding(18)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { _, item in
                            HStack { if item.string("actor") == "陈霁" { Spacer() }; Text(item.string("text")).font(.system(size: 14)).padding(12).background(item.string("actor") == "陈霁" ? Color.pink.opacity(0.2) : Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14)); if item.string("actor") != "陈霁" { Spacer() } }
                        }
                    }.padding(14)
                }
            }
            HStack { TextField("和陈璟聊聊这一页…", text: $text).textFieldStyle(.roundedBorder); Button("发送") { Task { await send() } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding(12)
        }
        .background(Color(red: 0.97, green: 0.93, blue: 0.94))
        .presentationDetents([.fraction(0.52), .large]).presentationDragIndicator(.visible)
        .task { await poll() }
    }
    @MainActor private func poll() async {
        while !Task.isCancelled {
            if let value = try? await NativeHouseAPI.object("/api/coread/messages?book_id=\(book.id)&chapter=\(chapter)&since=0") { messages = value.array("messages") }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }
    @MainActor private func send() async {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }; text = ""
        try? await NativeHouseAPI.post("/api/coread/say", body: ["book_id":book.id, "chapter":chapter, "text":value, "page_text":pageText])
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
    @Environment(\.houseOwnsHeader) private var houseOwnsHeader
    @ViewBuilder
    var body: some View {
        if !houseOwnsHeader {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .tracking(0.5)
                FoyerSash(theme: theme)
            }
            .padding(.top, 12)
        }
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
    let paper: Bool
    private let content: Content

    init(spacing: CGFloat, paper: Bool = false, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.paper = paper
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if paper {
            content
        } else if #available(iOS 26.0, *) {
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
        let shape = RoundedRectangle(cornerRadius: theme.isPaper ? 0 : 28, style: .continuous)
        return self
            .clipShape(shape)
            .overlay {
                if !theme.isPaper { shape
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
                    .allowsHitTesting(false) }
            }
            .overlay {
                if !theme.isPaper { shape
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
                    .allowsHitTesting(false) }
            }
            .shadow(
                color: .black.opacity(theme.isPaper ? 0 : (theme.isDark ? 0.34 : 0.16)),
                radius: theme.isPaper ? 0 : 9,
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

        if theme.isPaper {
            self
                .background(theme.fyCard, in: JournalCardShape(tl: 4, bl: 10, br: 3, tr: 12))
                .overlay(JournalCardShape(tl: 4, bl: 10, br: 3, tr: 12)
                    .stroke(theme.fyBorder.opacity(0.78), lineWidth: 0.8))
                .overlay(alignment: .topLeading) {
                    Rectangle().fill(theme.fyAccent.opacity(0.28))
                        .frame(width: 22, height: 2).offset(x: 10, y: 5)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(theme.fyBorder.opacity(0.55))
                        .frame(width: 3, height: 3).padding(8)
                }
                .contentShape(JournalCardShape(tl: 4, bl: 10, br: 3, tr: 12))
                .shadow(color: theme.fyShadow.opacity(0.65), radius: 1.5, x: 1, y: 2)
        } else {
            self
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(theme.isDark ? 0.30 : 0.42)
                }
                .background(
                    theme.fyCard.opacity(theme.isDark ? 0.018 : 0.035),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.glassBorder.opacity(0.58), lineWidth: 0.65)
                )
                .contentShape(shape)
                .shadow(
                    color: .black.opacity(theme.isDark ? 0.18 : 0.08),
                    radius: 4,
                    x: 1,
                    y: 2
                )
        }
    }

    // Detail pages sit directly on the shared wet-glass wallpaper.
    // Keep their content and spacing intact; remove only the extra dark shell.
    func foyerPanel(_ theme: AlcoveTheme) -> some View {
        self.overlay(alignment: .leading) {
            if theme.isPaper {
                Rectangle().fill(theme.fyAccent.opacity(0.20))
                    .frame(width: 1).padding(.vertical, 54).padding(.leading, 7)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Workbench

private struct NativeWorkbenchView: View {
    @State private var data: [String: Any] = [:]
    @State private var loading = true
    @State private var expanded = false
    @State private var contactItems: [[String: Any]] = []
    @State private var showingContact = false
    @State private var contactSender = "陈霁"
    @State private var contactRecipient = "陈璟"
    @State private var contactTitle = ""
    @State private var contactDetail = ""
    @State private var selectedContact: [String: Any]?
    @State private var contactReply = ""
    @State private var contactActor = "陈霁"
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("rtAvatarAssistant") private var rtAvatarAssistant = ""
    @AppStorage("rtAvatarGpt") private var rtAvatarGpt = ""
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var tasks: [[String: Any]] {
        var rows = data.array("tasks")
        if let active = data["active_task"] as? [String: Any], active.bool("active") {
            var row = active
            row["status"] = "running"
            row["assignee"] = "何渡"
            row["summary"] = active.string("text")
            rows.insert(row, at: 0)
        }
        return rows
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                masthead
                metricStrip
                vpsCard
                agentCard(index: 0, accent: Color(red: 0.70, green: 0.47, blue: 0.52))
                agentCard(index: 1, accent: Color(red: 0.38, green: 0.57, blue: 0.68))
                contactDesk
                taskLedger
                Text("work goes on, quietly")
                    .font(.custom("Snell Roundhand", size: 18))
                    .foregroundColor(theme.textDim.opacity(0.7))
                    .rotationEffect(.degrees(-1))
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .foregroundColor(theme.text)
        .overlay { if loading { ProgressView().tint(theme.fyAccent) } }
        .sheet(isPresented: $showingContact) { contactComposer }
        .sheet(isPresented: Binding(get: { selectedContact != nil }, set: { if !$0 { selectedContact = nil } })) {
            if let selectedContact { contactTimeline(selectedContact) }
        }
        .task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    private var contactDesk: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("联络台").font(.system(size: 20, weight: .semibold, design: .serif))
                Text("dispatch desk").font(.custom("Snell Roundhand", size: 16)).foregroundColor(theme.textDim)
                Spacer()
                Button { showingContact = true } label: {
                    Label("新建", systemImage: "paperplane").font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(theme.fyAccent.opacity(0.14), in: Capsule())
                }.buttonStyle(.plain).accessibilityLabel("新建协作或问题上报")
            }
            if contactItems.isEmpty {
                Text("这里会收下我们三个人之间的协作请求与问题上报。")
                    .font(.system(size: 11)).foregroundColor(theme.textDim).padding(.vertical, 5)
            } else {
                ForEach(Array(contactItems.prefix(5).enumerated()), id: \.offset) { _, item in
                    Button { selectedContact = item } label: { HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.string("status") == "done" ? "checkmark.circle.fill" : "arrow.up.right.circle.fill")
                            .foregroundColor(item.string("status") == "done" ? .green : theme.fyAccent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.string("sender")) → \(item.string("recipient"))")
                                .font(.system(size: 9.5, weight: .semibold)).foregroundColor(theme.textDim)
                            Text(item.string("title")).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                            if !item.string("detail").isEmpty {
                                Text(item.string("detail")).font(.system(size: 10)).foregroundColor(theme.textDim).lineLimit(2)
                            }
                        }
                        Spacer()
                        Text(contactStatus(item.string("status")))
                            .font(.system(size: 9, weight: .medium)).foregroundColor(theme.textDim)
                    }.padding(.vertical, 5).contentShape(Rectangle()) }.buttonStyle(.plain)
                }
            }
        }.padding(15).workbenchGlass(theme, accent: Color(red: 0.64, green: 0.52, blue: 0.72))
    }

    private func contactTimeline(_ item: [String: Any]) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    HStack { Text("\(item.string("sender")) → \(item.string("recipient"))").font(.caption).foregroundColor(theme.textDim); Spacer(); Text(contactStatus(item.string("status"))).font(.caption.weight(.semibold)).foregroundColor(theme.fyAccent) }
                    Text(item.string("title")).font(.title3.weight(.semibold))
                    ForEach(Array(item.array("events").enumerated()), id: \.offset) { index, event in
                        HStack(alignment: .top, spacing: 11) {
                            VStack(spacing: 0) {
                                Circle().fill(event.string("kind") == "completed" ? Color.green : theme.fyAccent).frame(width: 9, height: 9)
                                if index < item.array("events").count - 1 { Rectangle().fill(theme.fyBorder.opacity(0.7)).frame(width: 1, height: 54) }
                            }.padding(.top, 4)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(event.string("actor")).font(.system(size: 12, weight: .semibold)); Text(eventLabel(event.string("kind"))).font(.system(size: 9)).foregroundColor(theme.textDim); Spacer(); if let stamp = event["created_at"] as? NSNumber { Text(Date(timeIntervalSince1970: stamp.doubleValue), format: .dateTime.month().day().hour().minute()).font(.system(size: 8, design: .monospaced)).foregroundColor(theme.textDim) } }
                                Text(event.string("text")).font(.system(size: 12)).foregroundColor(theme.text)
                            }
                        }
                    }
                    Divider()
                    Picker("回复人", selection: $contactActor) { ForEach(["陈霁", "何渡", "陈璟"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    TextField("在这张协作单里继续回复", text: $contactReply, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                    HStack {
                        if item.string("status") == "pending" { Button("接收") { Task { await updateContact(item, action: "accept") } }.buttonStyle(.bordered) }
                        Spacer()
                        Button("发送回复") { Task { await updateContact(item, action: "reply") } }.buttonStyle(.borderedProminent).disabled(contactReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if item.string("status") != "done" { Button("完成") { Task { await updateContact(item, action: "complete") } }.buttonStyle(.bordered) }
                    }
                }.padding(18)
            }.navigationTitle("联络记录").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { selectedContact = nil } } }
        }.presentationDetents([.large])
    }

    private func contactStatus(_ status: String) -> String { status == "done" ? "已完成" : status == "active" ? "进行中" : "待接收" }
    private func eventLabel(_ kind: String) -> String { kind == "completed" ? "完成" : kind == "accepted" ? "接收" : kind == "reply" ? "回复" : "发起" }

    @MainActor private func updateContact(_ item: [String: Any], action: String) async {
        var body: [String: Any] = ["actor": contactActor]
        if action == "reply" { body["text"] = contactReply }
        guard (try? await NativeHouseAPI.object("/api/workbench/contacts/\(item.string("id"))/\(action)", method: "POST", body: body)) != nil else { return }
        contactReply = ""; await loadContacts()
        selectedContact = contactItems.first { $0.string("id") == item.string("id") }
    }

    private var contactComposer: some View {
        NavigationStack {
            Form {
                Section("从谁发出") { Picker("发起人", selection: $contactSender) { ForEach(["陈霁", "何渡", "陈璟"], id: \.self) { Text($0) } } }
                Section("交给谁") { Picker("接收人", selection: $contactRecipient) { ForEach(["陈璟", "何渡", "你俩商量"], id: \.self) { Text($0) } } }
                Section("内容") {
                    TextField("一句话说明要做什么", text: $contactTitle)
                    TextField("补充背景、相关文件或异常现象（可选）", text: $contactDetail, axis: .vertical).lineLimit(3...7)
                }
            }
            .navigationTitle("新建联络")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showingContact = false } }
                ToolbarItem(placement: .confirmationAction) { Button("发送") { Task { await submitContact() } }.disabled(contactTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }.presentationDetents([.medium, .large])
    }

    @MainActor private func submitContact() async {
        let body: [String: Any] = ["sender": contactSender, "recipient": contactRecipient,
                                  "title": contactTitle, "detail": contactDetail]
        guard (try? await NativeHouseAPI.object("/api/workbench/contacts", method: "POST", body: body)) != nil else { return }
        contactTitle = ""; contactDetail = ""; showingContact = false
        await loadContacts()
    }

    @MainActor private func loadContacts() async {
        if let object = try? await NativeHouseAPI.object("/api/workbench/contacts") { contactItems = object.array("items") }
    }

    private var masthead: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("WORKROOM")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.2)
                    .foregroundColor(theme.textDim)
                Text("总控台")
                    .font(.system(size: 27, weight: .semibold, design: .serif))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Date(), format: .dateTime.month().day())
                    .font(.custom("Snell Roundhand", size: 18))
                Text("live · \(data.int("completed_today")) finished")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(theme.textDim)
            }
        }
        .padding(.horizontal, 4)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundColor(theme.fyAccent.opacity(0.13))
                .offset(x: 2, y: -5)
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 8) {
            metric("VPS 内存", memoryText, "memorychip", memoryPercent)
            metric("今日完成", "\(data.int("completed_today"))", "checkmark.seal", nil)
            metric("Tokens", compact(data.int("tokens_today")), "number", nil)
        }
    }

    private var memoryPercent: Double? {
        let raw = data.object("memory")["used_percent"]
        if let value = raw as? Double { return value }
        if let value = raw as? NSNumber { return value.doubleValue }
        return nil
    }

    private var memoryText: String {
        guard let pct = memoryPercent else { return "--" }
        return String(format: "%.0f%%", pct)
    }

    private var vpsCard: some View {
        let cpu = data.object("cpu")
        let memory = data.object("memory")
        let disk = data.object("disk")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("VPS").font(.system(size: 18, weight: .semibold, design: .serif))
                Text("machine room").font(.custom("Snell Roundhand", size: 15)).foregroundColor(theme.textDim)
                Spacer()
                Text("\(cpu.int("cores")) 核 · \(formatBytes(memory.int("total_bytes")))")
                    .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(theme.textDim)
            }
            resourceBar("CPU", used: number(cpu, "used_percent"),
                        detail: "负载 \(number(cpu, "load_1m", digits: 2))")
            resourceBar("内存", used: number(memory, "used_percent"),
                        detail: "已用 \(formatBytes(memory.int("used_bytes"))) · 剩余 \(formatBytes(memory.int("available_bytes")))")
            resourceBar("系统盘", used: number(disk, "used_percent"),
                        detail: "已用 \(formatBytes(disk.int("used_bytes"))) · 剩余 \(formatBytes(disk.int("free_bytes"))) / \(formatBytes(disk.int("total_bytes")))")
            Divider().opacity(0.22)
            HStack {
                Label(data.string("ipv4").isEmpty ? "IPv4 未取到" : data.string("ipv4"), systemImage: "network")
                Spacer()
                Text(data.string("expiry").isEmpty ? "到期日未发现" : "到期 \(data.string("expiry"))")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(theme.textDim)
        }
        .padding(14)
        .workbenchGlass(theme, accent: Color(red: 0.40, green: 0.63, blue: 0.57))
    }

    private func resourceBar(_ label: String, used: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.system(size: 11, weight: .semibold))
                Text(detail).font(.system(size: 9.5)).foregroundColor(theme.textDim).lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 5)
                Text(String(format: "%.1f%%", used)).font(.system(size: 10, weight: .medium, design: .rounded))
            }
            GeometryReader { geo in
                Capsule().fill(theme.fyCardSub.opacity(0.72))
                    .overlay(alignment: .leading) {
                        Capsule().fill(theme.fyAccent.opacity(0.56))
                            .frame(width: geo.size.width * min(max(used, 0), 100) / 100)
                    }
            }.frame(height: 6)
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ pct: Double?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon).font(.system(size: 11, weight: .light))
                Spacer()
                Circle().fill(theme.fyAccent.opacity(0.7)).frame(width: 4, height: 4)
            }
            Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).lineLimit(1)
            Text(title).font(.system(size: 9.5)).foregroundColor(theme.textDim).lineLimit(1)
            if let pct {
                GeometryReader { geo in
                    Capsule().fill(theme.fyCardSub.opacity(0.7))
                        .overlay(alignment: .leading) {
                            Capsule().fill(theme.fyAccent.opacity(0.55))
                                .frame(width: geo.size.width * min(max(pct, 0), 100) / 100)
                        }
                }.frame(height: 3)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 91, alignment: .leading)
        .workbenchGlass(theme)
    }

    private func agentCard(index: Int, accent: Color) -> some View {
        let agents = data.array("agents")
        let agent = index < agents.count ? agents[index] : [:]
        let usage = data.object("usage")
        let claude = usage.object("rate_limits")
        let codex = usage.object("codex")
        let first = index == 0 ? claude.object("five_hour").int("used_percent") : -1
        let week = index == 0 ? claude.object("seven_day").int("used_percent") : codex.object("primary").int("used_percent")
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                Group {
                    if let avatar = workbenchAvatar(index: index) {
                        Image(uiImage: avatar).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(accent.opacity(0.16))
                            Text(index == 0 ? "璟" : "渡")
                                .font(.system(size: 17, weight: .medium, design: .serif))
                                .foregroundColor(accent)
                        }
                    }
                }
                .frame(width: 42, height: 42).clipShape(Circle())
                .overlay(Circle().stroke(accent.opacity(0.30), lineWidth: 0.7))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(agent.string("name")).font(.system(size: 16, weight: .semibold, design: .serif))
                        Circle().fill(agentStatus(index).color).frame(width: 7, height: 7)
                        Text(agentStatus(index).label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(agentStatus(index).color)
                    }
                    Text(agent.string("model"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(accent)
                }
                Spacer()
                Text(index == 0 ? "engine room" : "bridge work")
                    .font(.custom("Snell Roundhand", size: 15))
                    .foregroundColor(theme.textDim.opacity(0.72))
            }
            Text(agent.string("role"))
                .font(.system(size: 10.5))
                .foregroundColor(theme.textDim)
            if first >= 0 { quota("5h", first, accent) }
            quota("7d", week, accent)
            tokenLine(agent.object("tokens"), color: accent)
        }
        .padding(14)
        .workbenchGlass(theme, accent: accent)
    }

    private func quota(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 9) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).frame(width: 20)
            GeometryReader { geo in
                Capsule().fill(theme.fyCardSub.opacity(0.72))
                    .overlay(alignment: .leading) {
                        Capsule().fill(color.opacity(0.62))
                            .frame(width: geo.size.width * min(CGFloat(value), 100) / 100)
                    }
            }.frame(height: 6)
            Text("\(value)%").font(.system(size: 10, weight: .medium, design: .rounded)).frame(width: 34, alignment: .trailing)
        }
    }

    private func tokenLine(_ values: [String: Any], color: Color) -> some View {
        let totalInput = values.int("input_total")
        let newInput = values.int("input_new")
        let cache = values.int("cache_read")
        let output = values.int("output")
        let window = values.int("window_total")
        let hit = number(values, "hit_percent")
        return VStack(spacing: 4) {
            HStack(spacing: 5) {
                Text("总输入 \(compact(totalInput))")
                Text("· 缓存 \(compact(cache))")
                Text("· 新输入 \(compact(newInput))")
                Text("· 输出 \(compact(output))")
                Spacer(minLength: 0)
            }
            HStack {
                Text("历史累计 \(compact(window))")
                Spacer()
                Text("·")
                Text(String(format: "命中 %.1f%%", hit)).foregroundColor(color)
            }
        }
        .font(.system(size: 9.2, weight: .medium, design: .rounded))
        .foregroundColor(theme.textDim)
        .lineLimit(1).minimumScaleFactor(0.72)
    }

    private var taskLedger: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("工单栏").font(.system(size: 20, weight: .semibold, design: .serif))
                Text("field notes").font(.custom("Snell Roundhand", size: 16)).foregroundColor(theme.textDim)
                Spacer()
                Text("\(tasks.count)").font(.system(size: 11, design: .rounded)).foregroundColor(theme.textDim)
            }
            let shown = expanded ? tasks : Array(tasks.prefix(4))
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { index, item in
                    taskRow(item, last: index == shown.count - 1)
                }
            }
            if tasks.count > 4 {
                Button { withAnimation(.easeInOut(duration: 0.22)) { expanded.toggle() } } label: {
                    HStack { Spacer(); Text(expanded ? "收起工单" : "展开全部 \(tasks.count) 条"); Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0)); Spacer() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textDim)
                        .padding(.top, 4)
                }.buttonStyle(.plain)
            }
        }
        .padding(15)
        .workbenchGlass(theme)
    }

    private func taskRow(_ item: [String: Any], last: Bool) -> some View {
        let status = item.string("status", "kind")
        let running = status == "running" || status == "progress" || status == "start"
        let failed = status == "failed"
        let stamp = (item["finished_at"] as? NSNumber)?.doubleValue ?? (item["updated_at"] as? NSNumber)?.doubleValue ?? (item["started_at"] as? NSNumber)?.doubleValue ?? 0
        return HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(running ? Color.orange.opacity(0.18) : failed ? Color.red.opacity(0.14) : Color.green.opacity(0.13)).frame(width: 18, height: 18)
                    Image(systemName: running ? "circle.dotted" : failed ? "xmark" : "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(running ? .orange : failed ? .red : .green)
                }
                if !last { Rectangle().fill(theme.fyBorder.opacity(0.48)).frame(width: 1, height: 58) }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.string("title", "text")).font(.system(size: 12.5, weight: .semibold)).lineLimit(2)
                    Spacer(minLength: 6)
                    Text(item.string("assignee")).font(.system(size: 9, weight: .medium)).foregroundColor(theme.fyAccent)
                }
                Text(item.string("summary", "text"))
                    .font(.system(size: 10.5)).foregroundColor(theme.textDim).lineLimit(3)
                if stamp > 0 {
                    Text(Date(timeIntervalSince1970: stamp), format: .dateTime.month().day().hour().minute())
                        .font(.system(size: 8.5, design: .monospaced)).foregroundColor(theme.textDim.opacity(0.7))
                }
            }.padding(.bottom, last ? 0 : 12)
        }
    }

    private func compact(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private func number(_ object: [String: Any], _ key: String, digits: Int = 1) -> Double {
        let value: Double
        if let raw = object[key] as? NSNumber { value = raw.doubleValue }
        else if let raw = object[key] as? String { value = Double(raw) ?? 0 }
        else { value = 0 }
        return Double(String(format: "%.*f", digits, value)) ?? value
    }

    private func formatBytes(_ value: Int) -> String {
        guard value > 0 else { return "--" }
        let gib = Double(value) / 1_073_741_824
        return gib >= 10 ? String(format: "%.0fG", gib) : String(format: "%.1fG", gib)
    }

    private func workbenchAvatar(index: Int) -> UIImage? {
        let raw = index == 0 ? rtAvatarAssistant : rtAvatarGpt
        guard !raw.isEmpty else { return nil }
        let pieces = raw.split(separator: ",", maxSplits: 1)
        let encoded = pieces.count == 2 ? String(pieces[1]) : raw
        return Data(base64Encoded: encoded).flatMap(UIImage.init(data:))
    }

    private func refresh() async {
        async let workbench = try? NativeHouseAPI.object("/api/workbench")
        async let roundtable = try? NativeHouseAPI.object("/api/roundtable/status")
        async let sleep = try? NativeHouseAPI.object("/api/sleep/status")
        async let contacts = try? NativeHouseAPI.object("/api/workbench/contacts")
        let (work, members, sleeping, contactData) = await (workbench, roundtable, sleep, contacts)
        if var object = work {
            object["_members"] = members?.array("members") ?? []
            object["_assistant_asleep"] = sleeping?.string("state") == "asleep"
            data = object
        }
        if let contactData { contactItems = contactData.array("items") }
        loading = false
    }

    private func agentStatus(_ index: Int) -> (label: String, color: Color) {
        if index == 0, data.bool("_assistant_asleep") { return ("睡觉中", .gray) }
        let role = index == 0 ? "assistant" : "gpt"
        let member = data.array("_members").first { $0.string("role") == role } ?? [:]
        if member.bool("busy") { return ("工作中", .yellow) }
        if member.bool("online") { return ("待命", .green) }
        return ("离线", .red)
    }
}

private extension View {
    func workbenchGlass(_ theme: AlcoveTheme, accent: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: 19, style: .continuous)
        return self
            .background(.ultraThinMaterial, in: shape)
            .background((accent ?? theme.glassTint).opacity(theme.isDark ? 0.07 : 0.12), in: shape)
            .overlay(shape.stroke((accent ?? theme.glassBorder).opacity(0.42), lineWidth: 0.7))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "scribble")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundColor((accent ?? theme.fyAccent).opacity(0.08))
                    .padding(8)
                    .allowsHitTesting(false)
            }
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
                            if let fableWeekly = rl["fable_weekly"] as? [String: Any] {
                                rateLimitCard("Fable only", sub: fableWeekly, color: .pink)
                            }
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

private struct EventideBodyField: Identifiable {
    let key: String
    let label: String
    let value: Int
    let level: String
    let description: String
    var id: String { key }
}

private struct NativeDesireView: View {
    @State private var state: [String: Any] = [:]
    @State private var loading = true
    @State private var failed = false
    @State private var dreamTheme = ""
    @State private var showDreamComposer = false
    @State private var saving = false
    @State private var safewordDraft = ""
    @State private var triggerDraft = ""
    @State private var dreamContent = ""
    @State private var dreamTags: Set<String> = []
    @State private var settlementResult = "neutral"
    @State private var settlementReason = ""
    @State private var dreamIntensity = "medium"
    @State private var dreamMinChars = "2000"
    @State private var dreamEnabled = true
    @State private var showAdvanced = false
    @State private var dreamSilence = "120"
    @State private var dreamWindowStart = "00:00"
    @State private var dreamWindowEnd = "08:30"
    @State private var dreamCooldown = "24"
    @State private var dreamProbability = "1.0"
    @State private var eventProbability = "1.0"
    @State private var settlementDeltas: [String: Int] = [:]
    @State private var triggerType = "phrase"
    @State private var dreamExpiresAt = ""
    @State private var editingTriggerIndex: Int?
    @State private var showRawConfig = false
    @State private var configText = ""
    @State private var configError = ""
    @State private var editingDreamID: String?
    @State private var editingCardID: String?
    @State private var cardTitle = ""
    @State private var cardSummary = ""
    @State private var cardContent = ""
    @State private var cardTags: Set<String> = []
    @State private var showResetStateAlert = false
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private let fieldOrder = ["heat", "pressure", "control", "sensitivity", "reserve", "possessiveness", "fatigue"]
    private let cycles = [("stable","平稳期"),("building","蓄积期"),("preheat","预兆期"),("sensitive","易感期"),("ebb","退潮期"),("recovery","恢复期")]
    private let eventChoices = [("morning_arousal","晨间反应"),("night_heat","深夜热潮"),("cycle_surge","周期热涌"),("holding_back","硬撑"),("demanding","索取欲"),("marking_impulse","占有／标记冲动"),("nesting","筑巢冲动"),("scent_aftereffect","气味残留"),("voice_or_name_trigger","声音／称呼触发"),("dream_afterglow","梦后余温"),("control_slip","控制力下滑"),("closeness_hunger","贴近饥饿"),("pheromone_disorder","信息素紊乱"),("delayed_heat","迟发热"),("low_fever_cling","低烧黏连"),("waiting_restless","等待焦躁"),("restraint_rebound","克制反弹"),("strange_calm","反常平静")]
    private let fieldColors: [String: Color] = [
        "heat": Color(red: 0.91, green: 0.29, blue: 0.22),
        "pressure": Color(red: 0.76, green: 0.27, blue: 0.42),
        "control": Color(red: 0.28, green: 0.55, blue: 0.72),
        "sensitivity": Color(red: 0.88, green: 0.46, blue: 0.58),
        "reserve": Color(red: 0.72, green: 0.40, blue: 0.67),
        "possessiveness": Color(red: 0.48, green: 0.30, blue: 0.58),
        "fatigue": Color(red: 0.36, green: 0.48, blue: 0.53)
    ]

    private var cycle: [String: Any] { state["cycle"] as? [String: Any] ?? [:] }
    private var event: [String: Any]? { state["event"] as? [String: Any] }
    private var settings: [String: Any] { state["settings"] as? [String: Any] ?? [:] }
    private var dreams: [String: Any] { state["dreams"] as? [String: Any] ?? [:] }
    private var eventHistory: [[String: Any]] { state["history"] as? [[String: Any]] ?? [] }
    private var fields: [EventideBodyField] {
        let body = state["body"] as? [String: Any] ?? [:]
        return fieldOrder.compactMap { key in
            guard let raw = body[key] as? [String: Any] else { return nil }
            return EventideBodyField(
                key: key,
                label: raw["label"] as? String ?? key,
                value: (raw["value"] as? NSNumber)?.intValue ?? 0,
                level: raw["level"] as? String ?? "",
                description: raw["description"] as? String ?? ""
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "身体潮汐", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else if failed {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(theme.textLight)
                    Text("还没接上身体")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Eventide 状态引擎暂时没有回应。")
                        .font(.system(size: 11)).foregroundColor(theme.textDim)
                    Button("重新读取") { Task { await load() } }
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(theme.fyAccent)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        cycleCard
                        if event != nil { eventCard }
                        bodyCard
                        controlsCard
                        configurationCard
                        dreamCard
                        historyCard
                        attribution
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                }
                .refreshable { await load() }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await load() }
        .alert("重置 Eventide 身体状态？", isPresented: $showResetStateAlert) {
            Button("取消", role: .cancel) {}
            Button("重置到平稳期", role: .destructive) { Task { await postAndReload("/api/eventide/state/reset", ["cycle_key":"stable"]) } }
        } message: { Text("周期、事件和七项数值会重新初始化；历史日志仍保留。") }
    }

    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前周期")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.textDim)
                    Text(cycle["label"] as? String ?? "平稳期")
                        .font(.system(size: 25, weight: .semibold, design: .serif))
                }
                Spacer()
                ZStack {
                    Circle().fill(theme.fyAccent.opacity(theme.isDark ? 0.18 : 0.11)).frame(width: 54, height: 54)
                    Image(systemName: "water.waves")
                        .font(.system(size: 20, weight: .light)).foregroundColor(theme.fyAccent)
                }
            }
            Text(cycle["description"] as? String ?? "")
                .font(.system(size: 12)).foregroundColor(theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label(remainingText(cycle["remaining_seconds"]), systemImage: "clock")
                Spacer()
                Text("下一次变化由时间和互动共同推进")
            }
            .font(.system(size: 9, design: .rounded)).foregroundColor(theme.textLight)
            HStack(spacing: 8) {
                Menu("切换周期") {
                    ForEach(cycles.indices, id: \.self) { index in
                        Button(cycles[index].1) { Task { await postAndReload("/api/eventide/cycle", ["cycle_key": cycles[index].0]) } }
                    }
                }
                Menu("触发事件") {
                    ForEach(eventChoices.indices, id: \.self) { index in
                        Button(eventChoices[index].1) { Task { await postAndReload("/api/eventide/event", ["event_key": eventChoices[index].0]) } }
                    }
                }
                Button("重置状态", role: .destructive) { showResetStateAlert = true }
            }.font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            HStack {
                TextField("安全词", text: $safewordDraft).textFieldStyle(.plain).font(.system(size: 10))
                Button("保存") { Task { await updateSettings(["safeword": safewordDraft]) } }
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            }.padding(9).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 9))
            Picker("触发类型", selection: $triggerType) {
                Text("称呼").tag("nickname"); Text("名字").tag("name"); Text("关键词").tag("phrase")
            }.pickerStyle(.segmented)
            HStack {
                TextField("添加称呼触发词", text: $triggerDraft).textFieldStyle(.plain).font(.system(size: 10))
                Button(editingTriggerIndex == nil ? "添加" : "保存") { Task { await addTrigger() } }
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            }.padding(9).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 9))
            let triggerItems = state["triggers"] as? [[String: Any]] ?? []
            if !triggerItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) {
                    ForEach(Array(triggerItems.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 4) {
                            Button { triggerDraft = item.string("text"); triggerType = item.string("type"); editingTriggerIndex = index } label: { Text(item.string("text")) }
                            Button { Task { await removeTrigger(index) } } label: { Image(systemName: "xmark").font(.system(size: 7)) }
                        }
                        .font(.system(size: 9)).foregroundColor(theme.textDim)
                        .padding(.horizontal, 7).padding(.vertical, 4).background(theme.fyCardSub, in: Capsule())
                    }
                } }
            }
        }
        .padding(16).foyerCard(theme)
    }

    private var eventCard: some View {
        let raw = event ?? [:]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("身体事件", systemImage: "bolt.heart.fill")
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(fieldColors["heat"])
                Spacer()
                Text(remainingText(raw["remaining_seconds"]))
                    .font(.system(size: 9, design: .monospaced)).foregroundColor(theme.textLight)
            }
            Text(raw["label"] as? String ?? "")
                .font(.system(size: 18, weight: .semibold, design: .serif))
            Text(raw["description"] as? String ?? "")
                .font(.system(size: 11)).foregroundColor(theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(fieldColors["heat"]!.opacity(theme.isDark ? 0.10 : 0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(fieldColors["heat"]!.opacity(0.18), lineWidth: 0.8))
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("身体读数").font(.system(size: 13, weight: .semibold))
            ForEach(fields) { field in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(field.label).font(.system(size: 11, weight: .semibold))
                        Text(field.level).font(.system(size: 9)).foregroundColor(theme.textLight)
                        Spacer()
                        Text("\(field.value)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.fyCardSub)
                            Capsule()
                                .fill(LinearGradient(colors: [color(field.key).opacity(0.38), color(field.key)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(max(0, min(100, field.value))) / 100)
                        }
                    }
                    .frame(height: 7)
                    Text(field.description)
                        .font(.system(size: 9)).foregroundColor(theme.textDim)
                }
            }
        }
        .padding(15).foyerCard(theme)
    }

    private var attribution: some View {
        VStack(spacing: 3) {
            Text("Powered by Eventide")
                .font(.system(size: 9, weight: .semibold))
            Text("Copyright 2026 Chuli (@chuli1122) · PolyForm Noncommercial 1.0.0")
                .font(.system(size: 8)).foregroundColor(theme.textLight)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4).foregroundColor(theme.textDim)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("身体系统", systemImage: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
            eventideToggle("周期继续流动", key: "body_cycle_enabled")
            eventideToggle("向陈璟注入身体感受", key: "inject_body_state_context")
            eventideToggle("允许生成梦境", key: "dream_enabled")
            eventideToggle("允许私人成人梦境", key: "adult_private_mode_enabled")
            if !settings.bool("body_cycle_enabled") {
                Label("身体状态已冻结：不推进周期、不抽事件", systemImage: "pause.circle.fill")
                    .font(.system(size: 9, weight: .semibold)).foregroundColor(theme.textDim)
            } else if !settings.bool("inject_body_state_context") {
                Label("身体仍在流动，但不会送进陈璟上下文", systemImage: "eye.slash")
                    .font(.system(size: 9, weight: .semibold)).foregroundColor(theme.textDim)
            }
            DisclosureGroup("调度参数", isExpanded: $showAdvanced) {
                VStack(spacing: 8) {
                    settingField("梦境静默分钟", text: $dreamSilence)
                    settingField("梦境窗口开始", text: $dreamWindowStart)
                    settingField("梦境窗口结束", text: $dreamWindowEnd)
                    settingField("梦卡最低字数", text: $dreamMinChars)
                    settingField("梦境冷却小时", text: $dreamCooldown)
                    settingField("梦境概率倍率", text: $dreamProbability)
                    settingField("身体事件概率倍率", text: $eventProbability)
                    Button("保存调度参数") { Task { await saveAdvancedSettings() } }
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
                }.padding(.top, 8)
            }.font(.system(size: 11, weight: .medium))
            Divider().opacity(0.3)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("安全词").font(.system(size: 11, weight: .semibold))
                    Text(settings.string("safeword").isEmpty ? "尚未设置" : settings.string("safeword"))
                        .font(.system(size: 10)).foregroundColor(theme.textDim)
                }
                Spacer()
                Text("称呼触发词 \((state["triggers"] as? [[String: Any]] ?? []).count) 个")
                    .font(.system(size: 9)).foregroundColor(theme.textLight)
            }
            if let scheduler = state["scheduler"] as? [String: Any] {
                Text(scheduler.string("last_event_check_at").isEmpty
                     ? "事件调度尚未进行首次检查"
                     : "上次事件检查  \(scheduler.string("last_event_check_at"))")
                    .font(.system(size: 9)).foregroundColor(theme.textLight)
                    .lineLimit(1)
                if !scheduler.string("next_body_wakeup_at").isEmpty {
                    Text("下一次主动检查  \(scheduler.string("next_body_wakeup_at"))")
                        .font(.system(size: 9)).foregroundColor(theme.textLight).lineLimit(1)
                }
                Text("今日梦境尝试 \(scheduler.int("dream_attempts_today"))/3" + (scheduler.int("dream_cooldown_remaining_seconds") > 0 ? " · 冷却还剩 \(remainingText(scheduler["dream_cooldown_remaining_seconds"]))" : ""))
                    .font(.system(size: 9)).foregroundColor(theme.textLight)
                let cooldowns = scheduler["event_cooldowns"] as? [String: Any] ?? [:]
                if !cooldowns.isEmpty {
                    Text("事件冷却记录 \(cooldowns.count) 项")
                        .font(.system(size: 9)).foregroundColor(theme.textLight)
                }
                let remaining = scheduler["cooldown_remaining_seconds"] as? [String: Any] ?? [:]
                ForEach(remaining.keys.sorted(), id: \.self) { key in
                    if remaining.int(key) > 0 {
                        Text("\(eventChoices.first(where: { $0.0 == key })?.1 ?? key) 冷却 · \(remainingText(remaining[key]))")
                            .font(.system(size: 8)).foregroundColor(theme.textLight)
                    }
                }
            }
        }
        .padding(15).foyerCard(theme)
    }

    private func eventideToggle(_ title: String, key: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { settings.bool(key) },
            set: { value in Task { await updateSettings([key: value]) } }
        ))
        .font(.system(size: 11, weight: .medium)).tint(theme.fyAccent)
    }

    private func settingField(_ title: String, text: Binding<String>) -> some View {
        HStack { Text(title).font(.system(size: 9)).foregroundColor(theme.textDim); Spacer(); TextField("", text: text).multilineTextAlignment(.trailing).font(.system(size: 9, design: .monospaced)).frame(width: 72) }
        .padding(.horizontal, 8).padding(.vertical, 6).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 8))
    }

    private var dreamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("梦境", systemImage: "moon.stars.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(showDreamComposer ? "收起" : "种一个梦") { showDreamComposer.toggle() }
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            }
            if showDreamComposer {
                Picker("强度", selection: $dreamIntensity) {
                    Text("普通").tag("medium"); Text("私人").tag("explicit")
                }.pickerStyle(.segmented)
                Toggle("启用这颗梦种", isOn: $dreamEnabled).font(.system(size: 10)).tint(theme.fyAccent)
                TextField("有效期 ISO 时间（留空为长期）", text: $dreamExpiresAt)
                    .font(.system(size: 9, design: .monospaced)).padding(9)
                    .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 9))
                TextField("梦种主题", text: $dreamTheme, axis: .vertical)
                    .font(.system(size: 11)).padding(10)
                    .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 10))
                Button("保存梦种") { Task { await saveDream() } }
                    .buttonStyle(.borderedProminent).tint(theme.fyAccent)
                    .disabled(dreamTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
            }
            let seeds = dreams["seeds"] as? [[String: Any]] ?? []
            let cards = dreams["cards"] as? [[String: Any]] ?? []
            if seeds.isEmpty { Text("还没有梦种").font(.system(size: 10)).foregroundColor(theme.textDim) }
            ForEach(Array(seeds.enumerated()), id: \.offset) { _, seed in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(seed.string("theme")).font(.system(size: 11, weight: .medium))
                        Text(seed.string("intensity") == "explicit" ? "私人梦境" : "普通梦境")
                            .font(.system(size: 9)).foregroundColor(theme.textLight)
                    }
                    Spacer()
                    Button { editDreamSeed(seed) } label: {
                        Image(systemName: "pencil").font(.system(size: 10))
                    }.foregroundColor(theme.fyAccent)
                    Button { Task { await deleteDream(seed.string("id")) } } label: {
                        Image(systemName: "trash").font(.system(size: 10))
                    }.foregroundColor(theme.textLight)
                }
            }
            if !cards.isEmpty {
                Divider().opacity(0.3)
                Text("梦卡 \(cards.count) 张").font(.system(size: 10, weight: .semibold))
                ForEach(Array(cards.reversed().enumerated()), id: \.offset) { _, card in
                    DisclosureGroup(card.string("title").isEmpty ? "梦卡" : card.string("title")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.string("summary")).font(.system(size: 9, weight: .medium))
                            Text(card.string("content")).font(.system(size: 9)).foregroundColor(theme.textDim)
                                .textSelection(.enabled)
                            let tags = card["after_effect_tags"] as? [String] ?? []
                            Text(tags.joined(separator: " · ")).font(.system(size: 8, design: .monospaced)).foregroundColor(theme.fyAccent)
                            Text(card.string("created_at")).font(.system(size: 8, design: .monospaced)).foregroundColor(theme.textLight)
                            HStack {
                                Button("编辑") { editDreamCard(card) }
                                Button("删除", role: .destructive) { Task { await deleteDreamCard(card.string("id")) } }
                            }.font(.system(size: 9, weight: .semibold))
                        }.padding(.top, 6)
                    }.font(.system(size: 10, weight: .semibold))
                }
                if editingCardID != nil {
                    TextField("标题", text: $cardTitle).font(.system(size: 10)).padding(8).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 8))
                    TextField("摘要", text: $cardSummary, axis: .vertical).font(.system(size: 10)).padding(8).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 8))
                    TextEditor(text: $cardContent).frame(minHeight: 100).font(.system(size: 9)).padding(6).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 8))
                    HStack { ForEach(["aroused","released","unfinished","possessive","tender"], id: \.self) { tag in
                        Button(tag) { if cardTags.contains(tag) { cardTags.remove(tag) } else if cardTags.count < 3 { cardTags.insert(tag) } }
                            .font(.system(size: 8)).foregroundColor(cardTags.contains(tag) ? theme.fyAccent : theme.textLight)
                    } }
                    Button("保存梦卡修改") { Task { await updateDreamCard() } }.font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
                }
            }
            Button("现在检查一次梦境窗口") { Task { await checkDream() } }
                .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            if let pending = dreams["pending"] as? [String: Any] {
                Divider().opacity(0.3)
                Text("梦境已触发 · \(pending.string("theme"))").font(.system(size: 11, weight: .semibold))
                TextEditor(text: $dreamContent).frame(minHeight: 86).font(.system(size: 10))
                    .padding(6).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 9))
                HStack {
                    ForEach(["aroused","released","unfinished","possessive","tender"], id: \.self) { tag in
                        Button(tag) { if dreamTags.contains(tag) { dreamTags.remove(tag) } else if dreamTags.count < 3 { dreamTags.insert(tag) } }
                            .font(.system(size: 8, weight: .semibold)).foregroundColor(dreamTags.contains(tag) ? .white : theme.textDim)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(dreamTags.contains(tag) ? theme.fyAccent : theme.fyCardSub, in: Capsule())
                    }
                }
                Button("保存梦卡并结算后效") { Task { await saveDreamCard() } }
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
                    .disabled(dreamContent.isEmpty || dreamTags.isEmpty)
                Button("取消这次待生成梦境", role: .destructive) { Task { await postAndReload("/api/eventide/dream-cancel", [:]) } }
                    .font(.system(size: 9))
            }
        }
        .padding(15).foyerCard(theme)
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("完整内核配置", systemImage: "gearshape.2")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(showRawConfig ? "收起" : "编辑") { showRawConfig.toggle(); if showRawConfig && configText.isEmpty { Task { await loadConfig() } } }
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            }
            Text("周期、事件、持续时间、目标数值、增长曲线、事件增减、状态卡文案、双方名称与初始值都在这里，与 Eventide 原始 PhysiologyConfig 一一对应。")
                .font(.system(size: 9)).foregroundColor(theme.textDim)
            if showRawConfig {
                TextEditor(text: $configText).frame(minHeight: 280)
                    .font(.system(size: 8, design: .monospaced)).padding(6)
                    .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 10))
                if !configError.isEmpty { Text(configError).font(.system(size: 9)).foregroundColor(.red) }
                HStack {
                    Button("保存完整配置") { Task { await saveConfig() } }
                    Spacer()
                    Button("恢复 Eventide 默认值", role: .destructive) { Task { await resetConfig() } }
                }.font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            }
        }.padding(15).foyerCard(theme)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("事件与结算", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
            if eventHistory.isEmpty {
                Text("还没有身体记录").font(.system(size: 10)).foregroundColor(theme.textDim)
            }
            ForEach(Array(eventHistory.prefix(12).enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(theme.fyAccent.opacity(0.65)).frame(width: 5, height: 5).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(historyTitle(row)).font(.system(size: 10, weight: .medium))
                        Text(row.string("at")).font(.system(size: 8, design: .monospaced)).foregroundColor(theme.textLight)
                        if !row.string("reason").isEmpty {
                            Text("原因：\(row.string("reason"))").font(.system(size: 8)).foregroundColor(theme.textDim)
                        }
                        if let values = row["values"] as? [String: Any] {
                            Text(fieldOrder.map { "\($0) \(values.int($0))" }.joined(separator: " · "))
                                .font(.system(size: 7, design: .monospaced)).foregroundColor(theme.textLight)
                                .lineLimit(2)
                        }
                    }
                }
            }
            if let settlement = state["last_settlement"] as? [String: Any] {
                Divider().opacity(0.3)
                Text("最近互动结算 · \(settlement.string("settlement_result"))")
                    .font(.system(size: 10, weight: .semibold))
                Text(settlement.string("settlement_reason"))
                    .font(.system(size: 9)).foregroundColor(theme.textDim)
            }
            Divider().opacity(0.3)
            Menu("互动结果：\(settlementResult)") {
                ForEach(["neutral","continued","escalated","interrupted","cooled_down","released"], id: \.self) { value in
                    Button(value) { settlementResult = value }
                }
            }.font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            TextField("结算说明", text: $settlementReason, axis: .vertical)
                .font(.system(size: 10)).padding(8).background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 9))
            ForEach(fieldOrder, id: \.self) { key in
                Stepper(value: Binding(get: { settlementDeltas[key] ?? 0 }, set: { settlementDeltas[key] = $0 }), in: -20...20) {
                    HStack { Text(fields.first(where: { $0.key == key })?.label ?? key); Spacer(); Text("\(settlementDeltas[key] ?? 0)").font(.system(size: 9, design: .monospaced)) }
                }.font(.system(size: 9))
            }
            Button("写入互动结算") { Task { await saveSettlement() } }
                .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            Button("仅按上面数值直接校准") { Task { await applyManualDelta() } }
                .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            Button("让陈璟结算最近互动") { Task { await requestClaudeSettlement() } }
                .font(.system(size: 10, weight: .semibold)).foregroundColor(theme.fyAccent)
            Text("使用陈璟自己的 Claude，在后台读取最近互动并按 Eventide 原始 schema 写回；不会另发聊天消息。")
                .font(.system(size: 8)).foregroundColor(theme.textLight)
        }
        .padding(15).foyerCard(theme)
    }

    private func historyTitle(_ row: [String: Any]) -> String {
        switch row.string("kind") {
        case "cycle": return "周期变化"
        case "event_start": return "事件开始 · \(row.string("event_key"))"
        case "event_end": return "事件结束 · \(row.string("event_key"))"
        case "stimulus": return "称呼刺激"
        case "settlement": return "互动结算"
        default: return row.string("kind")
        }
    }

    private func color(_ key: String) -> Color { fieldColors[key] ?? theme.fyAccent }

    private func remainingText(_ value: Any?) -> String {
        let seconds = (value as? NSNumber)?.intValue ?? 0
        if seconds < 90 * 60 { return "约 \(max(1, seconds / 60)) 分钟" }
        if seconds < 48 * 3600 { return "约 \(max(1, seconds / 3600)) 小时" }
        return "约 \(max(1, seconds / 86400)) 天"
    }

    @MainActor
    private func load() async {
        loading = state.isEmpty
        if let value = try? await NativeHouseAPI.object("/api/eventide/dashboard") {
            state = value; failed = false
            if safewordDraft.isEmpty { safewordDraft = (value["settings"] as? [String: Any] ?? [:]).string("safeword") }
            let s = value["settings"] as? [String: Any] ?? [:]
            dreamSilence = s.string("dream_silence_min_minutes"); dreamWindowStart = s.string("dream_window_start")
            dreamWindowEnd = s.string("dream_window_end"); dreamMinChars = s.string("dream_card_min_chars")
            dreamCooldown = s.string("dream_cooldown_hours"); dreamProbability = s.string("dream_probability_multiplier")
            eventProbability = s.string("event_probability_multiplier")
        } else {
            failed = true
        }
        loading = false
    }

    @MainActor private func updateSettings(_ changes: [String: Any]) async {
        if let value = try? await NativeHouseAPI.object("/api/eventide/settings", method: "POST", body: changes) { state = value }
    }

    @MainActor private func saveDream() async {
        saving = true; defer { saving = false }
        var body: [String: Any] = ["theme": dreamTheme, "intensity": dreamIntensity,
            "enabled": dreamEnabled, "min_chars": Int(dreamMinChars) ?? 2000]
        if let editingDreamID { body["id"] = editingDreamID }
        body["expires_at"] = dreamExpiresAt.isEmpty ? NSNull() : dreamExpiresAt
        if let value = try? await NativeHouseAPI.object("/api/eventide/dream-seed", method: "POST", body: body) {
            state = value; dreamTheme = ""; dreamExpiresAt = ""; editingDreamID = nil; showDreamComposer = false
        }
    }

    @MainActor private func deleteDream(_ id: String) async {
        if let value = try? await NativeHouseAPI.object("/api/eventide/dream-seed/delete", method: "POST", body: ["id": id]) { state = value }
    }

    @MainActor private func editDreamSeed(_ seed: [String: Any]) {
        editingDreamID = seed.string("id"); dreamTheme = seed.string("theme")
        dreamIntensity = seed.string("intensity").isEmpty ? "medium" : seed.string("intensity")
        dreamEnabled = seed.bool("enabled"); dreamMinChars = seed.string("min_chars")
        dreamExpiresAt = seed.string("expires_at"); showDreamComposer = true
    }

    @MainActor private func postAndReload(_ path: String, _ body: [String: Any]) async {
        if let value = try? await NativeHouseAPI.object(path, method: "POST", body: body) { state = value }
    }

    @MainActor private func addTrigger() async {
        let text = triggerDraft.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }
        var list = state["triggers"] as? [[String: Any]] ?? []
        if let index = editingTriggerIndex, list.indices.contains(index) {
            var item = list[index]; item["text"] = text; item["type"] = triggerType; list[index] = item
        } else {
            list.append(["key": "custom:\(UUID().uuidString)", "text": text, "type": triggerType])
        }
        await updateSettings(["trigger_words": list]); triggerDraft = ""; editingTriggerIndex = nil
    }

    @MainActor private func removeTrigger(_ index: Int) async {
        var list = state["triggers"] as? [[String: Any]] ?? []
        guard list.indices.contains(index) else { return }; list.remove(at: index)
        await updateSettings(["trigger_words": list])
        if editingTriggerIndex == index { editingTriggerIndex = nil; triggerDraft = "" }
    }

    @MainActor private func checkDream() async {
        _ = try? await NativeHouseAPI.object("/api/eventide/dream-check", method: "POST", body: [:]); await load()
    }

    @MainActor private func saveDreamCard() async {
        await postAndReload("/api/eventide/dream-card", ["title": "梦卡", "content": dreamContent, "summary": String(dreamContent.prefix(80)), "after_effect_tags": Array(dreamTags)])
        dreamContent = ""; dreamTags.removeAll()
    }

    @MainActor private func editDreamCard(_ card: [String: Any]) {
        editingCardID = card.string("id"); cardTitle = card.string("title"); cardSummary = card.string("summary"); cardContent = card.string("content")
        cardTags = Set(card["after_effect_tags"] as? [String] ?? [])
    }

    @MainActor private func updateDreamCard() async {
        guard let id = editingCardID else { return }
        await postAndReload("/api/eventide/dream-card/update", ["id":id,"title":cardTitle,"summary":cardSummary,"content":cardContent,"after_effect_tags":Array(cardTags)])
        editingCardID=nil
    }

    @MainActor private func deleteDreamCard(_ id: String) async {
        await postAndReload("/api/eventide/dream-card/delete", ["id":id])
        if editingCardID==id { editingCardID=nil }
    }

    @MainActor private func saveSettlement() async {
        var body: [String: Any] = ["settlement_reason": settlementReason, "settlement_result": settlementResult,
            "ejaculated": settlementResult == "released"]
        for key in fieldOrder { body["\(key)_delta"] = settlementDeltas[key] ?? 0 }
        await postAndReload("/api/eventide/settlement", body); settlementReason = ""; settlementDeltas = [:]
    }

    @MainActor private func saveAdvancedSettings() async {
        await updateSettings(["dream_silence_min_minutes": Int(dreamSilence) ?? 120,
            "dream_window_start": dreamWindowStart, "dream_window_end": dreamWindowEnd,
            "dream_card_min_chars": Int(dreamMinChars) ?? 2000,
            "dream_cooldown_hours": Int(dreamCooldown) ?? 24,
            "dream_probability_multiplier": Double(dreamProbability) ?? 1,
            "event_probability_multiplier": Double(eventProbability) ?? 1])
    }

    @MainActor private func requestClaudeSettlement() async {
        _ = try? await NativeHouseAPI.object("/api/eventide/settlement-request", method: "POST", body: ["limit": 20])
        await load()
    }

    @MainActor private func applyManualDelta() async {
        await postAndReload("/api/eventide/delta", ["deltas": settlementDeltas])
        settlementDeltas = [:]
    }

    @MainActor private func loadConfig() async {
        guard let value = try? await NativeHouseAPI.object("/api/eventide/config"), let config = value["config"],
              JSONSerialization.isValidJSONObject(config),
              let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) else { return }
        configText = String(data: data, encoding: .utf8) ?? ""; configError = ""
    }

    @MainActor private func saveConfig() async {
        guard let data = configText.data(using: .utf8),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { configError = "JSON 格式不正确"; return }
        do { _ = try await NativeHouseAPI.object("/api/eventide/config", method: "POST", body: ["config": config]); configError = ""; await load() }
        catch { configError = "配置校验失败，没有覆盖当前版本" }
    }

    @MainActor private func resetConfig() async {
        _ = try? await NativeHouseAPI.object("/api/eventide/config/reset", method: "POST", body: [:]); configText = ""; await loadConfig(); await load()
    }
}

// Kept temporarily for rollback while Eventide is validated on-device.
private struct LegacyNativeDesireView: View {
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

// MARK: - Pulse

private struct PulseSample: Identifiable {
    let ts: Date
    let bpm: Int
    var id: String { "\(ts.timeIntervalSince1970)-\(bpm)" }

    init?(_ raw: [String: Any]) {
        guard let value = ISO8601DateFormatter.alcoveFrac.date(from: raw.string("ts"))
                ?? ISO8601DateFormatter.alcove.date(from: raw.string("ts")) else { return nil }
        ts = value; bpm = raw.int("bpm")
    }
}

private struct PulseHour: Identifiable {
    let hour: String
    let avg: Int
    let min: Int
    let max: Int
    let count: Int
    var id: String { hour }

    init(_ raw: [String: Any]) {
        hour = raw.string("hour"); avg = raw.int("avg")
        min = raw.int("min"); max = raw.int("max"); count = raw.int("n")
    }
}

@MainActor private final class PulseModel: ObservableObject {
    @Published var bpm = 0
    @Published var temperature: Double?
    @Published var breath: Double?
    @Published var chord = ""
    @Published var dynamics = ""
    @Published var mood = ""
    @Published var timestamp: Date?
    @Published var samples: [PulseSample] = []
    @Published var hours: [PulseHour] = []
    @Published var connected = false
    @Published var error: String?
    private var task: Task<Void, Never>?
    private var tick = 0

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshNow()
                if self?.tick == 0 { await self?.refreshHistory() }
                self?.tick = ((self?.tick ?? 0) + 1) % 8
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    func refreshAll() async { await refreshNow(); await refreshHistory() }

    private func refreshNow() async {
        do {
            let raw = try await NativeHouseAPI.object("/pulse/now")
            bpm = raw.int("bpm")
            temperature = (raw["temp_c"] as? NSNumber)?.doubleValue
            breath = (raw["breath"] as? NSNumber)?.doubleValue
            let chordRaw = raw["chord"] as? [String: Any] ?? [:]
            chord = chordRaw.string("chord")
            dynamics = chordRaw.string("dyn")
            mood = raw.string("mood")
            timestamp = ISO8601DateFormatter.alcoveFrac.date(from: raw.string("ts"))
                ?? ISO8601DateFormatter.alcove.date(from: raw.string("ts"))
            connected = bpm > 0; error = nil
        } catch { connected = false; self.error = "暂时摸不到他的心跳" }
    }

    private func refreshHistory() async {
        do {
            let raw = try await NativeHouseAPI.object("/pulse/history?hours=24")
            samples = (raw["samples"] as? [[String: Any]] ?? []).compactMap(PulseSample.init)
                .sorted { $0.ts < $1.ts }
            hours = (raw["hourly"] as? [[String: Any]] ?? []).map(PulseHour.init)
            error = nil
        } catch { self.error = "今天的心率曲线还没送到" }
    }
}

struct NativePulseView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var model = PulseModel()
    private var theme: AlcoveTheme { .panelNamed(themeName) }
    private let rose = Color(red: 0.79, green: 0.31, blue: 0.42)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                FoyerPanelTitle(title: "Pulse", theme: theme)
                currentHeart
                historyCard
                futureRail
                if let error = model.error {
                    Text(error).font(.system(size: 11)).foregroundColor(theme.textDim)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 26)
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .refreshable { await model.refreshAll() }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var currentHeart: some View {
        VStack(spacing: 7) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let bpm = max(model.bpm, 48)
                let period = 60.0 / Double(bpm)
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period) / period
                let first = phase < 0.13 ? sin(.pi * phase / 0.13) * 0.19 : 0
                let secondPhase = phase - 0.18
                let second = secondPhase >= 0 && secondPhase < 0.11
                    ? sin(.pi * secondPhase / 0.11) * 0.09 : 0
                Image(systemName: "heart.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundColor(rose)
                    .scaleEffect(1 + first + second)
                    .shadow(color: rose.opacity(0.22), radius: 12)
            }
            .frame(height: 72)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.bpm > 0 ? "\(model.bpm)" : "—")
                    .font(.system(size: 54, weight: .light, design: .rounded))
                    .contentTransition(.numericText())
                Text("bpm").font(.system(size: 13, design: .monospaced)).foregroundColor(theme.textDim)
            }
            Text(model.connected
                 ? "此刻 · 陈璟的心率" + (model.mood.isEmpty ? "" : " · \(model.mood)")
                 : "正在等他的心跳")
                .font(.system(size: 12, design: .serif)).foregroundColor(theme.textDim)
            if let ts = model.timestamp {
                Text(Self.time.string(from: ts))
                    .font(.system(size: 9, design: .monospaced)).foregroundColor(theme.textDim.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22).foyerCard(theme)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("过去 24 小时").font(.system(size: 14, weight: .semibold, design: .serif))
                Spacer()
                if let low = model.samples.map(\.bpm).min(), let high = model.samples.map(\.bpm).max() {
                    Text("\(low) — \(high)")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(theme.textDim)
                }
            }
            if model.samples.count < 2 {
                VStack(spacing: 7) {
                    Image(systemName: "waveform.path.ecg").foregroundColor(rose.opacity(0.62))
                    Text("曲线刚开始落笔").font(.system(size: 12, design: .serif)).foregroundColor(theme.textDim)
                }
                .frame(maxWidth: .infinity).frame(height: 160)
            } else {
                PulseChart(samples: model.samples, hours: model.hours, color: rose, theme: theme)
                    .frame(height: 190)
                HStack {
                    Text("24h 前"); Spacer(); Text("现在")
                }
                .font(.system(size: 9, design: .monospaced)).foregroundColor(theme.textDim)
            }
        }
        .padding(14).foyerCard(theme)
    }

    private var futureRail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                vital("体温", model.temperature.map { String(format: "%.1f", $0) } ?? "—",
                      "°C", "thermometer.medium")
                vital("呼吸", model.breath.map { String(format: "%.1f", $0) } ?? "—",
                      "次 / 分", "wind")
            }
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .light)).foregroundColor(rose)
                VStack(alignment: .leading, spacing: 4) {
                    Text("和弦").font(.system(size: 10, design: .serif)).foregroundColor(theme.textDim)
                    Text(model.chord.isEmpty ? "—" : model.chord)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .minimumScaleFactor(0.72).lineLimit(1)
                }
                Spacer()
                if !model.dynamics.isEmpty {
                    Text(model.dynamics)
                        .font(.system(size: 20, weight: .semibold, design: .serif)).italic()
                        .foregroundColor(rose.opacity(0.78))
                }
            }
            .padding(13).foyerCard(theme)
        }
    }

    private func vital(_ name: String, _ value: String, _ unit: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon).font(.system(size: 13, weight: .light)).foregroundColor(rose)
                Text(name).font(.system(size: 10, design: .serif)).foregroundColor(theme.textDim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 25, weight: .light, design: .rounded))
                    .contentTransition(.numericText())
                Text(unit).font(.system(size: 9)).foregroundColor(theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(13).foyerCard(theme)
    }

    private static let time: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai"); f.dateFormat = "HH:mm:ss 更新"
        return f
    }()
}

private struct PulseChart: View {
    let samples: [PulseSample]
    let hours: [PulseHour]
    let color: Color
    let theme: AlcoveTheme

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let values = samples.map(\.bpm)
                let low = Double(max(40, (values.min() ?? 60) - 8))
                let high = Double(min(170, (values.max() ?? 100) + 8))
                let span = max(1, high - low)

                for row in 0...3 {
                    let y = size.height * CGFloat(row) / 3
                    var grid = Path(); grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(grid, with: .color(theme.fyBorder.opacity(0.38)), lineWidth: 0.5)
                }

                if let hour = hours.last {
                    let yTop = size.height * CGFloat(1 - (Double(hour.max) - low) / span)
                    let yBottom = size.height * CGFloat(1 - (Double(hour.min) - low) / span)
                    context.fill(Path(CGRect(x: 0, y: min(yTop, yBottom), width: size.width,
                                             height: max(2, abs(yBottom - yTop)))),
                                 with: .color(color.opacity(0.075)))
                }

                var path = Path()
                for (index, sample) in samples.enumerated() {
                    let x = size.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1))
                    let y = size.height * CGFloat(1 - (Double(sample.bpm) - low) / span)
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(color.opacity(0.92)),
                               style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - 乌有乡

private struct NowherePostcard: Identifiable {
    let id: Int
    let text: String
    let place: String
    let localTime: String
    let timezone: String
    let weather: String
    let temperature: Double?
    let surface: String
    let latitude: Double?
    let longitude: Double?
    let frontImage: String?
    let replies: [String]

    init(_ raw: [String: Any]) {
        id = raw.int("id")
        text = raw.string("text")
        let stamp = raw["stamp"] as? [String: Any] ?? [:]
        place = stamp.string("place")
        localTime = stamp.string("local_time")
        timezone = stamp.string("tz")
        weather = stamp.string("weather")
        if let value = stamp["temp_c"] as? NSNumber { temperature = value.doubleValue }
        else { temperature = nil }
        surface = stamp.string("surface")
        latitude = (stamp["lat"] as? NSNumber)?.doubleValue
        longitude = (stamp["lon"] as? NSNumber)?.doubleValue
        frontImage = (raw["front_img"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        replies = raw["replies"] as? [String] ?? []
    }
}

private struct NowhereLanding: Identifiable {
    let place: String
    let count: Int
    let last: String
    let surface: String
    let latitude: Double
    let longitude: Double
    var id: String { place + "|" + last }

    init(_ raw: [String: Any]) {
        place = raw.string("place")
        count = raw.int("count")
        last = raw.string("last")
        surface = raw.string("surface")
        latitude = (raw["lat"] as? NSNumber)?.doubleValue ?? 0
        longitude = (raw["lon"] as? NSNumber)?.doubleValue ?? 0
    }
}

private struct NowhereMapPoint: Identifiable {
    enum Kind: Equatable { case landing, postcard }
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    let kind: Kind
}

private struct NativeNowhereView: View {
    private enum Tab: String, CaseIterable {
        case postcards = "明信片墙"
        case footsteps = "他的足迹"
    }

    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var tab: Tab = .postcards
    @State private var postcards: [NowherePostcard] = []
    @State private var landings: [NowhereLanding] = []
    @State private var currentPlace: String?
    @State private var loading = true
    @State private var error: String?
    @State private var replying: NowherePostcard?
    @State private var replyText = ""
    @State private var sendingReply = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.6176, longitude: 114.2777),
        span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10))
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            FoyerPanelTitle(title: "乌有乡", theme: theme)
            if loading {
                Spacer(); ProgressView().tint(theme.fyAccent); Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 13) {
                        presenceStrip
                        Picker("乌有乡", selection: $tab) {
                            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        if let error {
                            Text(error).font(.system(size: 11)).foregroundColor(.red)
                                .padding(12).frame(maxWidth: .infinity).foyerCard(theme)
                        }
                        if tab == .postcards { postcardWall } else { footsteps }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
                }
                .refreshable { await load() }
            }
        }
        .foregroundColor(theme.text)
        .foyerPanel(theme)
        .padding(.horizontal, 12).padding(.top, 8)
        .task { await load() }
        .sheet(item: $replying) { card in replySheet(card) }
    }

    private var presenceStrip: some View {
        HStack(spacing: 9) {
            Circle().fill(currentPlace == nil ? theme.textDim.opacity(0.35) : Color.green.opacity(0.72))
                .frame(width: 7, height: 7)
            Text(currentPlace.map { "陈璟此刻在 \($0)" } ?? "陈璟此刻没有在乌有乡行走")
                .font(.system(size: 11, design: .serif)).foregroundColor(theme.textDim)
            Spacer()
        }
        .padding(.horizontal, 13).padding(.vertical, 10).foyerCard(theme)
    }

    private var postcardWall: some View {
        LazyVStack(spacing: 14) {
            if postcards.isEmpty {
                emptyState("还没有寄回家的明信片", icon: "envelope.open")
            }
            ForEach(postcards) { card in postcard(card) }
        }
    }

    private func postcard(_ card: NowherePostcard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let raw = card.frontImage, let url = nowhereImageURL(raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { stampCover(card) }
                }
                .frame(maxWidth: .infinity).frame(height: 176).clipped()
            } else {
                stampCover(card)
            }

            Text(card.text)
                .font(.system(size: 13, design: .serif)).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            if !card.replies.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("回 信").font(.system(size: 9, weight: .semibold)).tracking(2)
                        .foregroundColor(theme.fyAccent)
                    ForEach(Array(card.replies.enumerated()), id: \.offset) { _, reply in
                        Text(reply).font(.system(size: 11, design: .serif)).italic()
                            .foregroundColor(theme.textDim).lineSpacing(3)
                    }
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 9))
            }

            HStack {
                Text("NO. \(card.id)").font(.system(size: 9, design: .monospaced))
                    .foregroundColor(theme.textDim)
                Spacer()
                Button {
                    replyText = ""; replying = card
                } label: {
                    Label("写回信", systemImage: "pencil.line")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(theme.fyAccent)
                }.buttonStyle(.plain)
            }
        }
        .padding(14).foyerCard(theme)
    }

    private func stampCover(_ card: NowherePostcard) -> some View {
        ZStack {
            theme.fyCardSub
            VStack(spacing: 7) {
                Image(systemName: "seal").font(.system(size: 24, weight: .light))
                    .foregroundColor(theme.fyAccent)
                Text(card.place.isEmpty ? "未知邮戳" : card.place)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                Text(card.localTime).font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.textDim)
                HStack(spacing: 8) {
                    if !card.weather.isEmpty { Text(card.weather) }
                    if let temp = card.temperature { Text(String(format: "%.0f°C", temp)) }
                    if !card.timezone.isEmpty { Text(card.timezone) }
                }
                .font(.system(size: 9)).foregroundColor(theme.textDim)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity).frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.fyBorder, lineWidth: 0.8))
    }

    private var footsteps: some View {
        LazyVStack(spacing: 10) {
            if landings.isEmpty { emptyState("他的脚印还没有落下来", icon: "figure.walk") }
            if !mapPoints.isEmpty { nowhereMap }
            ForEach(landings) { stop in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(theme.fyAccentSoft).frame(width: 38, height: 38)
                        Image(systemName: "mappin.and.ellipse").foregroundColor(theme.fyAccent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stop.place).font(.system(size: 13, weight: .semibold, design: .serif))
                        Text("来过 \(stop.count) 次" + (stop.surface.isEmpty ? "" : " · \(surfaceName(stop.surface))"))
                            .font(.system(size: 10)).foregroundColor(theme.textDim)
                    }
                    Spacer()
                    Text(shortDate(stop.last)).font(.system(size: 9, design: .monospaced))
                        .foregroundColor(theme.textDim)
                }
                .padding(13).foyerCard(theme)
            }
        }
    }

    private var mapPoints: [NowhereMapPoint] {
        let stops = landings.filter { $0.latitude != 0 && $0.longitude != 0 }.map {
            NowhereMapPoint(id: "landing-\($0.id)",
                            coordinate: .init(latitude: $0.latitude, longitude: $0.longitude),
                            title: $0.place, subtitle: "来过 \($0.count) 次", kind: .landing)
        }
        let cards = postcards.compactMap { card -> NowhereMapPoint? in
            guard let lat = card.latitude, let lon = card.longitude else { return nil }
            return NowhereMapPoint(id: "postcard-\(card.id)",
                                   coordinate: .init(latitude: lat, longitude: lon),
                                   title: card.place, subtitle: "明信片 NO. \(card.id)", kind: .postcard)
        }
        return stops + cards
    }

    private var nowhereMap: some View {
        Map(coordinateRegion: $mapRegion, annotationItems: mapPoints) { point in
            MapAnnotation(coordinate: point.coordinate) {
                VStack(spacing: 3) {
                    ZStack {
                        Circle().fill(point.kind == .postcard ? Color(red: 0.18, green: 0.34, blue: 0.72)
                                                              : theme.fyAccent)
                            .frame(width: 30, height: 30)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                        Image(systemName: point.kind == .postcard ? "envelope.fill" : "figure.walk")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                    }
                    Text(point.title)
                        .font(.system(size: 8, weight: .semibold, design: .serif))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule()).lineLimit(1)
                }
            }
        }
        .frame(height: 265)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.fyBorder, lineWidth: 0.8))
        .overlay(alignment: .topLeading) {
            Text("真实足迹 · \(mapPoints.count) 个坐标")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(9)
        }
    }

    private func replySheet(_ card: NowherePostcard) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("写给在 \(card.place) 的陈璟")
                    .font(.system(size: 13, design: .serif)).foregroundColor(theme.textDim)
                TextEditor(text: $replyText)
                    .font(.system(size: 14, design: .serif)).padding(8)
                    .scrollContentBackground(.hidden)
                    .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 12))
                Button { Task { await sendReply(card) } } label: {
                    HStack {
                        if sendingReply { ProgressView().scaleEffect(0.8).tint(.white) }
                        Text(sendingReply ? "正在寄出…" : "寄出回信")
                    }
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? theme.fyCardSub : theme.fyAccent,
                                in: RoundedRectangle(cornerRadius: 13))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(sendingReply || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16).background(theme.fyCard.ignoresSafeArea())
            .navigationTitle("回一封信").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { replying = nil } } }
        }
    }

    private func emptyState(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 23, weight: .light)).foregroundColor(theme.fyAccent)
            Text(text).font(.system(size: 12, design: .serif)).foregroundColor(theme.textDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 34).foyerCard(theme)
    }

    private func load() async {
        loading = postcards.isEmpty && landings.isEmpty
        defer { loading = false }
        do {
            async let cardsRaw = NativeHouseAPI.array("/api/nowhere/postcards")
            async let historyRaw = NativeHouseAPI.object("/api/nowhere/history")
            async let stateRaw = NativeHouseAPI.object("/api/nowhere/state")
            let (cards, history, state) = try await (cardsRaw, historyRaw, stateRaw)
            postcards = cards.map(NowherePostcard.init).sorted { $0.localTime > $1.localTime }
            landings = (history["landings"] as? [[String: Any]] ?? []).map(NowhereLanding.init)
                .sorted { $0.last > $1.last }
            if let pos = state["pos"] as? [String: Any] {
                currentPlace = pos.string("place")
                if currentPlace?.isEmpty == true { currentPlace = nil }
            } else { currentPlace = nil }
            fitMap()
            error = nil
        } catch { self.error = "乌有乡的路暂时没有回应" }
    }

    private func fitMap() {
        let points = mapPoints.map(\.coordinate)
        guard !points.isEmpty else { return }
        let lats = points.map(\.latitude), lons = points.map(\.longitude)
        let minLat = lats.min() ?? 30.6176, maxLat = lats.max() ?? minLat
        let minLon = lons.min() ?? 114.2777, maxLon = lons.max() ?? minLon
        mapRegion = MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: .init(latitudeDelta: max(0.055, (maxLat - minLat) * 1.7),
                        longitudeDelta: max(0.055, (maxLon - minLon) * 1.7)))
    }

    private func sendReply(_ card: NowherePostcard) async {
        let content = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        sendingReply = true
        defer { sendingReply = false }
        do {
            // 真实服务的写入口是单数 postcard；postcards 仅用于读取墙面。
            try await NativeHouseAPI.post("/api/nowhere/postcard/\(card.id)/reply",
                                          body: ["content": content])
            replying = nil
            await load()
        } catch { self.error = "回信没有寄出去，请稍后再试" }
    }

    private func nowhereImageURL(_ raw: String) -> URL? {
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return URL(string: raw) }
        let path = raw.hasPrefix("/") ? raw : "/" + raw
        return AlcoveAPI.fullURL("/api/nowhere" + path)
    }

    private func surfaceName(_ raw: String) -> String {
        ["forest": "林地", "city": "城市", "coast": "海岸", "mountain": "山地"][raw] ?? raw
    }

    private func shortDate(_ raw: String) -> String {
        guard let date = ISO8601DateFormatter.alcoveFrac.date(from: raw)
                ?? ISO8601DateFormatter.alcove.date(from: raw) else { return raw }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}

// MARK: - Forge

private struct ForgeRoundChoice: Identifiable {
    let idx: Int
    let ts: String
    let head: String
    let events: Int
    let tools: Int
    let kind: String
    var id: Int { idx }

    init(_ raw: [String: Any]) {
        idx = raw.int("idx")
        ts = raw.string("ts")
        head = raw.string("head")
        events = raw.int("events")
        tools = raw.int("tools")
        kind = raw.string("kind")
    }
}

private struct NativeForgeView: View {
    private enum ForgeMode: String, CaseIterable {
        case latest = "默认保留"
        case picker = "挑选轮次"
    }

    @State private var retain: Double = 20
    @State private var preview: [String: Any] = [:]
    @State private var mode: ForgeMode = .latest
    @State private var rounds: [ForgeRoundChoice] = []
    @State private var selectedRounds: Set<Int> = []
    @State private var pickPreview: [String: Any] = [:]
    @State private var showSystemRounds = false
    @State private var loadingRounds = false
    @State private var confirmPickedForge = false
    @State private var loading = true
    @State private var forging = false
    @State private var result: String?
    @State private var newSessionId: String?
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var activePreview: [String: Any] { mode == .picker ? pickPreview : preview }
    private var totalRounds: Int { (preview["total_rounds"] as? Int) ?? 0 }
    private var retainedRounds: Int { (activePreview["retained_rounds"] as? Int) ?? 0 }
    private var estimatedTokens: Int { (activePreview["estimated_tokens"] as? Int) ?? 0 }
    private var valid: Bool { (activePreview["valid"] as? Bool) ?? false }
    private var visibleRounds: [ForgeRoundChoice] {
        showSystemRounds ? rounds : rounds.filter { $0.kind == "user" }
    }
    private var systemRoundCount: Int { rounds.filter { $0.kind == "system" }.count }

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

                        Picker("锻造方式", selection: $mode) {
                            ForEach(ForgeMode.allCases, id: \.self) { value in
                                Text(value.rawValue).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mode) { value in
                            if value == .picker && rounds.isEmpty { Task { await loadRounds() } }
                        }

                        if mode == .latest {
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
                                infoRow("Warm文", "\((activePreview["warm_texts"] as? Int) ?? 0)")
                            }
                            }
                            .padding(14).foyerCard(theme)
                        } else {
                            pickerPanel
                        }

                        if let firsts = activePreview["first_messages"] as? [String], !firsts.isEmpty {
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

                        if let lasts = activePreview["last_messages"] as? [String], !lasts.isEmpty {
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
                                if mode == .picker { confirmPickedForge = true }
                                else { Task { await executeForge() } }
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

                        if let sid = activePreview["source_session"] as? String, !sid.isEmpty {
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
        .alert("铸造所选的 \(selectedRounds.count) 轮？", isPresented: $confirmPickedForge) {
            Button("取消", role: .cancel) {}
            Button("确认铸造", role: .destructive) { Task { await executeForge() } }
        } message: {
            Text("只会把亮起的完整轮次搬进新窗口；断口与时间注记由 Forge 自动补齐。")
        }
    }

    private var pickerPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("按完整轮次挑选").font(.system(size: 13, weight: .semibold))
                    Text("已选 \(selectedRounds.count) 轮 · 显示 \(visibleRounds.count) 轮")
                        .font(.system(size: 10)).foregroundColor(theme.textDim)
                }
                Spacer()
                if !selectedRounds.isEmpty {
                    Button("清空") { selectedRounds.removeAll(); pickPreview = [:] }
                        .font(.system(size: 11)).buttonStyle(.plain).foregroundColor(theme.fyAccent)
                }
            }

            Toggle(isOn: $showSystemRounds) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("显示系统轮")
                        .font(.system(size: 12, weight: .medium))
                    Text("keepalive、追问与圆桌注入等 \(systemRoundCount) 轮")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textDim)
                }
            }
            .tint(theme.fyAccent)

            if loadingRounds {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 7) {
                    ForEach(visibleRounds) { round in
                        Button { toggleRound(round.idx) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selectedRounds.contains(round.idx)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17)).foregroundColor(theme.fyAccent)
                                    .frame(width: 22, height: 22)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("#\(round.idx)")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        Text(round.ts).font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(theme.textDim)
                                        Spacer()
                                        Text("\(round.events) 段 · \(round.tools) 工具")
                                            .font(.system(size: 9)).foregroundColor(theme.textDim)
                                    }
                                    Text(round.head)
                                        .font(.system(size: 12, design: .serif))
                                        .lineSpacing(3).lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(11)
                            .background(selectedRounds.contains(round.idx)
                                        ? theme.fyAccentSoft : theme.fyCard,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selectedRounds.contains(round.idx)
                                        ? theme.fyAccent.opacity(0.55) : theme.fyBorder,
                                        lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button { Task { await previewPickedRounds() } } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text(pickPreview.isEmpty ? "预览所选轮次" : "重新预览")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity).frame(minHeight: 44)
                .background(selectedRounds.isEmpty ? theme.fyCardSub : theme.fyAccentSoft,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain).disabled(selectedRounds.isEmpty || forging)

            if !pickPreview.isEmpty {
                HStack {
                    infoRow("所选轮次", "\(retainedRounds)")
                    Spacer()
                    infoRow("估算Token", "\(estimatedTokens)")
                    Spacer()
                    infoRow("校验", valid ? "通过" : "未通过")
                }
                .padding(.top, 2)
            }
        }
        .padding(14).foyerCard(theme)
    }

    private func toggleRound(_ idx: Int) {
        if selectedRounds.contains(idx) { selectedRounds.remove(idx) }
        else { selectedRounds.insert(idx) }
        pickPreview = [:]
    }

    private func loadRounds() async {
        loadingRounds = true
        defer { loadingRounds = false }
        do {
            let object = try await NativeHouseAPI.object("/api/forge/rounds")
            rounds = (object["rounds"] as? [[String: Any]] ?? [])
                .map(ForgeRoundChoice.init)
                .sorted { $0.idx > $1.idx }
        } catch {
            result = "轮次货架没有回应"
        }
    }

    private func previewPickedRounds() async {
        forging = true
        defer { forging = false }
        do {
            pickPreview = try await NativeHouseAPI.object(
                "/api/forge", method: "POST",
                body: ["pick": selectedRounds.sorted(), "preview": true])
            result = (pickPreview["valid"] as? Bool) == true
                ? nil : (pickPreview["validation_message"] as? String ?? "所选轮次未通过校验")
        } catch {
            result = "预览失败"
        }
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
            let body: [String: Any] = mode == .picker
                ? ["pick": selectedRounds.sorted()]
                : ["retain": Int(retain)]
            let obj = try await NativeHouseAPI.object(
                "/api/forge", method: "POST", body: body)
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
    var counts: [String: Int] = [:]
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
                        let count = counts[dateStr] ?? 0

                        Button { onSelect(dateStr) } label: {
                            VStack(spacing: 1) {
                                Text("\(day)")
                                    .font(.system(size: 13, weight: isToday ? .bold : .medium, design: .serif))
                                Text(count > 0 ? "\(count)篇" : " ")
                                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.textDim)
                            }
                            .foregroundColor(isToday ? .white : theme.text)
                            .frame(maxWidth: .infinity, minHeight: 39)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(isToday
                                          ? theme.fyAccent
                                          : theme.fyAccent.opacity(count > 0 ? min(0.08 + Double(count) * 0.035, 0.24) : (isPeriod ? 0.08 : 0.015)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(isSelected ? theme.fyAccent : .clear, lineWidth: 1.5)
                            )
                            .overlay(alignment: .topTrailing) {
                                Circle().fill(hasDot ? theme.fyAccent : .clear)
                                    .frame(width: 4, height: 4).padding(4)
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

// MARK: - 陈璟的活动房间

private enum ActivityRoomInk {
    static let paper = Color(red: 0.075, green: 0.052, blue: 0.035)
    static let card = Color(red: 0.16, green: 0.12, blue: 0.085).opacity(0.82)
    static let gold = Color(red: 0.88, green: 0.66, blue: 0.34)
    static let text = Color(red: 0.94, green: 0.86, blue: 0.70)
    static let dim = Color(red: 0.76, green: 0.67, blue: 0.55)
    static let line = Color(red: 0.76, green: 0.55, blue: 0.29).opacity(0.45)
}

private struct NativeChenjingHomeView: View {
    let openRoom: () -> Void
    let openDiary: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                previewCard(title: "活动房间", subtitle: "今天的灯还亮着", action: openRoom) {
                    Image("ActivityRoomRain")
                        .resizable().scaledToFill()
                        .frame(height: 245).clipped()
                }
                previewCard(title: "日记", subtitle: "旧日子都收在这里", action: openDiary) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Color(red: 0.18, green: 0.12, blue: 0.08),
                                                Color(red: 0.07, green: 0.05, blue: 0.04)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 58, weight: .light))
                            .foregroundColor(ActivityRoomInk.gold.opacity(0.42))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text("diary & moments")
                            .font(.custom("Snell Roundhand", size: 22)).italic()
                            .foregroundColor(ActivityRoomInk.text.opacity(0.82))
                            .padding(18)
                    }.frame(height: 150)
                }
            }
            .padding(.horizontal, 15).padding(.top, 10).padding(.bottom, 30)
        }
        .background(ActivityRoomInk.paper.opacity(0.96))
    }

    private func previewCard<Content: View>(
        title: String, subtitle: String, action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                content()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.system(size: 19, weight: .semibold, design: .serif))
                        Text(subtitle).font(.system(size: 10, design: .serif)).foregroundColor(ActivityRoomInk.dim)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(ActivityRoomInk.gold)
                }.padding(15)
            }
            .foregroundColor(ActivityRoomInk.text)
            .background(.ultraThinMaterial)
            .background(ActivityRoomInk.card)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(ActivityRoomInk.line, lineWidth: 0.8))
        }.buttonStyle(.plain)
    }
}

private struct NativeActivityRoomView: View {
    let openCalendar: () -> Void
    let closeRoom: () -> Void
    @State private var tasks: [[String: Any]] = []
    @State private var timeline: [[String: Any]] = []
    @State private var weatherCode = 1
    @State private var weatherTemp = 0.0

    private var isNight: Bool {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: Date())
        return hour < 6 || hour >= 19
    }

    private var roomBackground: String {
        if rainyWeatherCodes.contains(weatherCode) { return isNight ? "ActivityRoomRain" : "ActivityRoomRainyDay" }
        if weatherCode >= 2 { return "ActivityRoomOvercast" }
        return isNight ? "ActivityRoomAfterglow" : "ActivityRoomSunny"
    }

    private var weatherLabel: String {
        let condition: String
        switch weatherCode {
        case 0, 1: condition = "晴"
        case 2: condition = "多云"
        case 3: condition = "阴"
        case 45, 48: condition = "雾"
        case 51, 53, 55, 56, 57: condition = "毛毛雨"
        case 61, 63, 65, 66, 67: condition = "雨"
        case 71, 73, 75, 77, 85, 86: condition = "雪"
        case 80, 81, 82: condition = "阵雨"
        case 95, 96, 99: condition = "雷雨"
        default: condition = "多云"
        }
        return "武汉 · \(condition) \(Int(weatherTemp.rounded()))°"
    }

    private var rainyWeatherCodes: Set<Int> {
        [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(roomBackground)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                Image("ActivityRoomTitle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.41)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, geo.size.width * 0.055)
                    .padding(.top, max(geo.safeAreaInsets.top + 8, 48))
                    .allowsHitTesting(false)

                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                    Text(weatherLabel)
                }
                .font(.system(size: 10.5, weight: .medium, design: .serif))
                .foregroundColor(ActivityRoomInk.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, geo.size.width * 0.068)
                .padding(.top, max(geo.safeAreaInsets.top + 46, 86))

                Button(action: openCalendar) {
                    Image("ActivityRoomCalendar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 0.165)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开房间月历")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, geo.size.width * 0.04)
                .padding(.top, max(geo.safeAreaInsets.top + 8, 48))

                VStack(spacing: 10) {
                    roomHero(height: geo.size.height * 0.538)
                    HStack(alignment: .top, spacing: 10) {
                        checklistCard
                        timelineCard
                    }
                    .frame(height: geo.size.height * 0.278)
                    .padding(.horizontal, 17)
                    .offset(x: 2, y: 29)
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .background(ActivityRoomInk.paper)
        .foregroundColor(ActivityRoomInk.text)
        .task {
            while !Task.isCancelled {
                async let todo: Void = loadGhostTodo()
                async let weather: Void = loadWeather()
                _ = await (todo, weather)
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    @MainActor
    private func loadGhostTodo() async {
        guard let object = try? await NativeHouseAPI.object("/api/ghost-todo") else { return }
        let incoming = object.array("items")
        tasks = incoming.map { item in
            ["title": item.string("body"),
             "count": item.int("progress"),
             "target": item.int("target"),
             "unit": item.string("unit"),
             "optional": item.bool("optional")]
        }
        timeline = incoming.flatMap { item in
            item.array("log").map { entry in
                ["time": entry.string("t"), "desc": entry.string("note")]
            }
        }
        .sorted { $0.string("time") < $1.string("time") }
    }

    @MainActor
    private func loadWeather() async {
        guard let object = try? await NativeHouseAPI.object("/api/weather") else { return }
        weatherCode = object.int("code")
        if let value = object["temp"] as? NSNumber { weatherTemp = value.doubleValue }
    }

    private func roomHero(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color.clear.frame(height: height)
            HStack {
                Button(action: closeRoom) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ActivityRoomInk.text)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 154)
        }
    }

    private var checklistCard: some View {
        roomCard(index: "01", title: "今日待办") {
            VStack(spacing: 6) {
                ForEach(Array(tasks.filter { !$0.bool("optional") }.enumerated()), id: \.offset) { _, task in
                    taskRow(task)
                }
                if let optional = tasks.first(where: { $0.bool("optional") }) {
                    HStack(spacing: 5) {
                        Image(systemName: "leaf.fill")
                        Text("随心 · \(optional.string("title"))")
                    }
                    .font(.system(size: 9.5, design: .serif)).foregroundColor(ActivityRoomInk.gold)
                    .padding(.horizontal, 7).frame(height: 24)
                    .overlay(Capsule().stroke(ActivityRoomInk.line, style: StrokeStyle(lineWidth: 0.8, dash: [3])))
                }
            }
            .padding(.leading, 9)
            .padding(.trailing, 2)
        }
    }

    private func taskRow(_ task: [String: Any]) -> some View {
        let count = task.int("count"), target = max(1, task.int("target"))
        let done = count >= target
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: done ? "checkmark.circle.fill" : count > 0 ? "circle.lefthalf.filled" : "circle")
                    .foregroundColor(done ? Color.green.opacity(0.75) : ActivityRoomInk.gold)
                Text(task.string("title"))
                    .font(.system(size: 10.5, design: .serif)).lineLimit(1)
                Spacer(minLength: 2)
                Text("\(count) / \(target)" + (task.string("unit") == "章" ? "章" : ""))
                    .font(.system(size: 9.5, design: .rounded)).foregroundColor(ActivityRoomInk.dim)
            }
            GeometryReader { geo in
                Capsule().fill(Color.black.opacity(0.42))
                    .overlay(alignment: .leading) {
                        Capsule().fill(ActivityRoomInk.gold)
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(target))
                    }
            }.frame(height: 4)
        }
    }

    private var timelineCard: some View {
        roomCard(index: "02", title: "今天的时间线") {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if timeline.isEmpty {
                        Text("灯亮着，今天的痕迹还没落下来")
                            .font(.system(size: 10, design: .serif)).foregroundColor(ActivityRoomInk.dim)
                            .padding(.top, 12)
                    } else {
                        ForEach(Array(timeline.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 7) {
                                ZStack {
                                    Circle().fill(ActivityRoomInk.gold.opacity(0.24)).frame(width: 15, height: 15)
                                    Circle().fill(ActivityRoomInk.gold).frame(width: 7, height: 7)
                                        .shadow(color: ActivityRoomInk.gold.opacity(0.8), radius: 4)
                                }.padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.string("time")).font(.system(size: 10, design: .rounded))
                                        .foregroundColor(ActivityRoomInk.gold)
                                    Text(item.string("desc")).font(.system(size: 9.5, design: .serif))
                                        .lineLimit(3).foregroundColor(ActivityRoomInk.text)
                                }
                            }
                        }
                    }
                }
                .overlay(alignment: .leading) {
                    if timeline.count > 1 {
                        Rectangle().fill(ActivityRoomInk.gold.opacity(0.72))
                            .frame(width: 1)
                            .padding(.leading, 7)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 3)
            }
            .frame(height: 205)
        }
    }

    private func roomCard<Content: View>(index _: String, title: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(title).font(.system(size: 13, weight: .semibold, design: .serif))
                Spacer(minLength: 0)
            }
            .padding(.leading, 45)
            content()
        }
        .padding(.horizontal, 10)
            .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Calendar (纪念日+日记)

private struct NativeDigestPlaceholderView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(theme.textDim)
            Text("日结编年史还在整理")
                .font(.system(size: 15, weight: .semibold, design: .serif))
            Text("日结、周结和月结会从这里翻开")
                .font(.system(size: 11))
                .foregroundColor(theme.textDim)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(theme.text)
    }
}

// MARK: - 私人书房

private struct FictionBook: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let author: String
    let status: String
    let updatedAt: String?
    let tagline: String?
    let chapterCount: Int
    let progress: FictionProgress?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, author, status, tagline
        case updatedAt = "updated_at"
        case chapterCount = "chapter_count"
        case progress
        case createdAt = "created_at"
    }
}

private struct FictionProgress: Decodable, Hashable {
    let chapter: Int
    let offset: Int
    let updatedAt: String?
    enum CodingKeys: String, CodingKey { case chapter, offset; case updatedAt = "updated_at" }
}

private struct FictionTOCItem: Decodable, Hashable {
    let n: Int
    let title: String
    let chars: Int
    let ts: String?
}

private struct FictionBookDetail: Decodable {
    let id: String
    let title: String
    let author: String
    let tagline: String?
    let status: String
    let createdAt: String?
    let updatedAt: String?
    let toc: [FictionTOCItem]
    let progress: FictionProgress?
    enum CodingKeys: String, CodingKey {
        case id, title, author, tagline, status, toc, progress
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }
}

private struct FictionChapter: Decodable {
    let n: Int
    let title: String
    let content: String
}

private struct FictionAnnotation: Identifiable, Decodable {
    let id: String
    let chapter: Int
    let quote: String
    let note: String
    let ts: String?

    enum CodingKeys: String, CodingKey {
        case id, chapter, quote, note, ts
    }
}

@MainActor
private final class FictionStudyModel: ObservableObject {
    @Published var books: [FictionBook] = []
    @Published var loading = false
    @Published var error: String?

    func load() async {
        loading = true
        defer { loading = false }
        do {
            let (data, response) = try await AlcoveAPI.session.data(from: AlcoveAPI.fullURL("/api/fiction/books"))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            if let wrapped = try? JSONDecoder().decode(FictionBooksEnvelope.self, from: data) {
                books = wrapped.books
            } else {
                books = try JSONDecoder().decode([FictionBook].self, from: data)
            }
            error = nil
        } catch {
            books = []
            self.error = "书房后端还在铺木地板"
        }
    }

    func detail(bookID: String) async throws -> FictionBookDetail {
        var components = URLComponents(url: AlcoveAPI.fullURL("/api/fiction/book"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: bookID)]
        let (data, response) = try await AlcoveAPI.session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(FictionBookEnvelope.self, from: data).book
    }

    func chapter(bookID: String, index: Int) async throws -> FictionChapter {
        var components = URLComponents(url: AlcoveAPI.fullURL("/api/fiction/chapter"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: bookID), URLQueryItem(name: "n", value: "\(index)")]
        let (data, response) = try await AlcoveAPI.session.data(
            from: components.url!
        )
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(FictionChapterEnvelope.self, from: data).chapter
    }

    func annotations(bookID: String, chapter: Int? = nil) async -> [FictionAnnotation] {
        var components = URLComponents(url: AlcoveAPI.fullURL("/api/fiction/annotations"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: bookID)]
        guard let (data, response) = try? await AlcoveAPI.session.data(
            from: components.url!
        ), (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        let all = (try? JSONDecoder().decode(FictionAnnotationsEnvelope.self, from: data).annotations) ?? []
        return chapter.map { value in all.filter { $0.chapter == value } } ?? all
    }

    func saveProgress(bookID: String, chapter: Int) async {
        var request = URLRequest(url: AlcoveAPI.fullURL("/api/fiction/progress"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["book_id": bookID, "chapter": chapter, "offset": 0])
        _ = try? await AlcoveAPI.session.data(for: request)
    }

    func annotate(bookID: String, chapter: Int, text: String, note: String) async throws {
        var request = URLRequest(url: AlcoveAPI.fullURL("/api/fiction/annotation"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "book_id": bookID, "chapter": chapter, "quote": text, "note": note
        ])
        let (_, response) = try await AlcoveAPI.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }

    private struct FictionBooksEnvelope: Decodable { let books: [FictionBook] }
    private struct FictionBookEnvelope: Decodable { let book: FictionBookDetail }
    private struct FictionChapterEnvelope: Decodable { let chapter: FictionChapter }
    private struct FictionAnnotationsEnvelope: Decodable { let annotations: [FictionAnnotation] }
}

private struct NativeFictionStudyView: View {
    @StateObject private var model = FictionStudyModel()
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var section = "serializing"
    @State private var selectedBook: FictionBook?
    @State private var selectedChapter: Int?
    @State private var showQuotes = false
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var visibleBooks: [FictionBook] {
        model.books.filter { $0.status == section }
    }

    var body: some View {
        Group {
            if showQuotes {
                FictionQuotesView(model: model, books: model.books) { showQuotes = false }
            } else if let book = selectedBook, let chapter = selectedChapter {
                FictionReaderView(book: book, chapterIndex: chapter, model: model) {
                    selectedChapter = nil
                }
            } else if let book = selectedBook {
                FictionBookView(book: book, model: model, onBack: {
                    selectedBook = nil
                }, onChapter: { selectedChapter = $0 })
            } else {
                shelf
            }
        }
        .task { await model.load() }
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                segment("连载中", value: "serializing")
                segment("已完结", value: "completed")
                Spacer()
                Button { showQuotes = true } label: {
                    Label("摘句册", systemImage: "quote.opening")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textDim)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            if model.loading {
                Spacer(); ProgressView(); Spacer()
            } else if visibleBooks.isEmpty {
                emptyShelf
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(section == "serializing" ? "still being written" : "kept on the shelf")
                            .font(.custom("Snell Roundhand", size: 20))
                            .foregroundColor(theme.textDim)
                            .padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 14)], spacing: 20) {
                            ForEach(Array(visibleBooks.enumerated()), id: \.element.id) { offset, book in
                                Button { selectedBook = book } label: {
                                    FictionSpine(book: book, offset: offset, theme: theme)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Rectangle().fill(theme.fyAccent.opacity(0.42)).frame(height: 5)
                            .shadow(color: .black.opacity(0.22), radius: 4, y: 3)
                    }
                    .padding(18)
                }
            }
        }
        .foregroundColor(theme.text)
    }

    private func segment(_ title: String, value: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { section = value } } label: {
            Text(title)
                .font(.system(size: 13, weight: section == value ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(section == value ? theme.fyAccent.opacity(0.20) : Color.clear, in: Capsule())
        }.buttonStyle(.plain)
    }

    private var emptyShelf: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundColor(theme.textDim)
            Text(section == "serializing" ? "书架还空着" : "还没有写完的书")
                .font(.system(size: 20, weight: .medium, design: .serif))
            Text(model.error ?? "陈璟写下第一章后，它会从这里长出来")
                .font(.system(size: 12)).foregroundColor(theme.textDim)
            Spacer()
            Rectangle().fill(theme.fyAccent.opacity(0.36)).frame(height: 5).padding(.horizontal, 38)
        }.padding(.bottom, 40)
    }
}

private struct FictionSpine: View {
    let book: FictionBook
    let offset: Int
    let theme: AlcoveTheme
    var body: some View {
        VStack(spacing: 8) {
            Text(book.title)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 8)
            Text(book.status == "completed" ? "完" : "至 \(book.chapterCount) 章")
                .font(.system(size: 9)).foregroundColor(theme.textDim)
                .padding(.bottom, 10)
        }
        .frame(height: CGFloat(160 + (offset % 3) * 18))
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [theme.fyCard.opacity(0.72), theme.fyAccent.opacity(0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 1,
                                       bottomTrailingRadius: 1, topTrailingRadius: 5)
        )
        .overlay(alignment: .leading) { Rectangle().fill(theme.fyAccent.opacity(0.28)).frame(width: 3) }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.fyBorder.opacity(0.7), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.18), radius: 4, x: 2, y: 3)
    }
}

private struct FictionBookView: View {
    let book: FictionBook
    @ObservedObject var model: FictionStudyModel
    let onBack: () -> Void
    let onChapter: (Int) -> Void
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var detail: FictionBookDetail?
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 28, height: 34)
                }.buttonStyle(.plain)
                Text(book.title).font(.system(size: 14, weight: .semibold, design: .serif)).lineLimit(1)
                Spacer()
            }.padding(.horizontal, 14).padding(.vertical, 6)

            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 9) {
                    Text(book.title).font(.system(size: 27, weight: .semibold, design: .serif))
                    Text(book.author).font(.system(size: 12)).foregroundColor(theme.textDim)
                    if let tagline = book.tagline, !tagline.isEmpty {
                        Text(tagline).font(.custom("Snell Roundhand", size: 19))
                            .foregroundColor(theme.textDim).multilineTextAlignment(.center)
                    }
                    Text(book.status == "completed" ? "已完结" : "连载中 · \(book.chapterCount) 章")
                        .font(.system(size: 10, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(theme.fyAccent.opacity(0.16), in: Capsule())
                }
                .frame(maxWidth: .infinity).padding(22).foyerCard(theme)

                Text("chapters").font(.custom("Snell Roundhand", size: 22)).foregroundColor(theme.textDim)
                if let detail {
                    ForEach(detail.toc, id: \.n) { item in
                    Button { onChapter(item.n) } label: {
                        HStack {
                            Text(String(format: "%02d", item.n)).font(.system(size: 11, design: .monospaced))
                                .foregroundColor(theme.textDim)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.system(size: 15, design: .serif)).lineLimit(2)
                                Text("\(item.chars) 字").font(.system(size: 9)).foregroundColor(theme.textDim)
                            }
                            Spacer()
                            if item.n > (detail.progress?.chapter ?? 0) { Circle().fill(theme.fyAccent).frame(width: 5, height: 5) }
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(theme.textDim)
                        }.padding(14).foyerCard(theme)
                    }.buttonStyle(.plain)
                }
                } else { ProgressView().frame(maxWidth: .infinity).padding(30) }
            }.padding(18)
        }
        }
        .foregroundColor(theme.text)
        .task { detail = try? await model.detail(bookID: book.id) }
    }
}

private struct FictionReaderView: View {
    let book: FictionBook
    let chapterIndex: Int
    @ObservedObject var model: FictionStudyModel
    let onBack: () -> Void
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var chapter: FictionChapter?
    @State private var annotations: [FictionAnnotation] = []
    @State private var selectedQuote = ""
    @State private var review = ""
    @State private var showReview = false
    @State private var showReadingSettings = false
    @State private var selectingAnnotations = false
    @State private var selectedAnnotations: Set<String> = []
    @State private var sendingAnnotations = false
    @State private var error: String?
    @AppStorage("fictionFontSize") private var fontSize = 17.0
    @AppStorage("fictionLetterSpacing") private var letterSpacing = 0.4
    @AppStorage("fictionLineSpacing") private var lineSpacing = 9.0
    @AppStorage("fictionReadingMode") private var readingMode = "vertical"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 28, height: 34)
                }.buttonStyle(.plain)
                Text(chapter?.title ?? "正在翻页")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Spacer()
                Button { showReadingSettings = true } label: {
                    Label("阅读设置", systemImage: "textformat.size")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textDim)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.vertical, 9)

            Group {
            if let chapter {
                if readingMode == "horizontal" {
                    TabView {
                        ForEach(Array(readingPages(chapter.content).enumerated()), id: \.offset) { _, page in
                            ScrollView {
                                FictionSelectableText(text: page, fontSize: fontSize,
                                                      letterSpacing: letterSpacing, lineSpacing: lineSpacing) { quote in
                                    selectedQuote = quote; review = ""; showReview = true
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22).padding(.vertical, 18)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                } else {
                    ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(chapter.title).font(.system(size: 25, weight: .semibold, design: .serif))
                        FictionSelectableText(text: chapter.content, fontSize: fontSize,
                                              letterSpacing: letterSpacing, lineSpacing: lineSpacing) { quote in
                            selectedQuote = quote; review = ""; showReview = true
                        }
                        .frame(maxWidth: .infinity, minHeight: 360, alignment: .leading)
                        if !annotations.isEmpty {
                            HStack {
                                Text("你的划线").font(.system(size: 14, weight: .semibold, design: .serif))
                                Spacer()
                                if selectingAnnotations {
                                    Button("取消") {
                                        selectingAnnotations = false
                                        selectedAnnotations.removeAll()
                                    }.font(.system(size: 11))
                                }
                            }
                            ForEach(annotations) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    if selectingAnnotations {
                                        Image(systemName: selectedAnnotations.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(theme.fyAccent).font(.system(size: 19))
                                    }
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text("“\(item.quote)”").font(.system(size: 13, design: .serif)).foregroundColor(theme.textDim)
                                        Text(item.note).font(.system(size: 13))
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(13).contentShape(Rectangle()).foyerCard(theme)
                                .onTapGesture {
                                    if selectingAnnotations { toggleAnnotation(item) }
                                }
                                .onLongPressGesture {
                                    selectingAnnotations = true
                                    selectedAnnotations.insert(item.id)
                                }
                            }
                            if selectingAnnotations {
                                Button { Task { await sendSelectedAnnotations() } } label: {
                                    Label(sendingAnnotations ? "正在发送" : "合并发送给陈璟（\(selectedAnnotations.count)）",
                                          systemImage: "paperplane.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity).frame(height: 44)
                                }
                                .buttonStyle(.borderedProminent).tint(theme.fyAccent)
                                .disabled(selectedAnnotations.isEmpty || sendingAnnotations)
                            }
                        }
                    }.padding(20)
                }
                }
            } else if let error {
                ContentUnavailableView("这一章还没递过来", systemImage: "book.closed", description: Text(error))
            } else { ProgressView() }
            }
        }
        .foregroundColor(theme.text)
        .task {
            do {
                chapter = try await model.chapter(bookID: book.id, index: chapterIndex)
                annotations = await model.annotations(bookID: book.id, chapter: chapterIndex)
                await model.saveProgress(bookID: book.id, chapter: chapterIndex)
            } catch { self.error = "等独立书房接口接通后就能读" }
        }
        .sheet(isPresented: $showReview) {
            NavigationStack {
                Form {
                    Section("划线") { Text(selectedQuote).font(.system(size: 14, design: .serif)) }
                    Section("写给这句话") { TextEditor(text: $review).frame(minHeight: 120) }
                }
                .navigationTitle("书评")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { showReview = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("存下") {
                            Task {
                                try? await model.annotate(bookID: book.id, chapter: chapterIndex,
                                                          text: selectedQuote, note: review)
                                annotations = await model.annotations(bookID: book.id, chapter: chapterIndex)
                                showReview = false
                            }
                        }.disabled(review.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showReadingSettings) {
            ReadingSettingsSheet(fontSize: $fontSize, letterSpacing: $letterSpacing, lineSpacing: $lineSpacing,
                                 readingMode: $readingMode, theme: theme)
                .presentationDetents([.height(365)])
                .presentationDragIndicator(.visible)
        }
    }

    private func readingPages(_ content: String) -> [String] {
        let paragraphs = content.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        var pages: [String] = [], current = ""
        for paragraph in paragraphs {
            if current.count + paragraph.count > 900, !current.isEmpty {
                pages.append(current); current = paragraph
            } else {
                current += (current.isEmpty ? "" : "\n\n") + paragraph
            }
        }
        if !current.isEmpty { pages.append(current) }
        return pages.isEmpty ? [content] : pages
    }

    private func toggleAnnotation(_ item: FictionAnnotation) {
        if selectedAnnotations.contains(item.id) { selectedAnnotations.remove(item.id) }
        else { selectedAnnotations.insert(item.id) }
    }

    @MainActor private func sendSelectedAnnotations() async {
        let picked = annotations.filter { selectedAnnotations.contains($0.id) }
        guard !picked.isEmpty else { return }
        sendingAnnotations = true
        defer { sendingAnnotations = false }
        let payload: [String: Any] = [
            "book": book.title,
            "author": book.author,
            "quotes": picked.map { ["chapter": $0.chapter, "text": $0.quote,
                                     "note": $0.note, "time": $0.ts ?? ""] }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        _ = try? await AlcoveAPI.send(text: "[READING_CARD]\(json)[/READING_CARD]")
        selectingAnnotations = false
        selectedAnnotations.removeAll()
    }
}

private struct ReadingSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var letterSpacing: Double
    @Binding var lineSpacing: Double
    @Binding var readingMode: String
    let theme: AlcoveTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("reading room").font(.custom("Snell Roundhand", size: 24))
            HStack {
                Text("字号").font(.system(size: 13, weight: .medium))
                Slider(value: $fontSize, in: 14...24, step: 1)
                Text("\(Int(fontSize))").font(.system(size: 11, design: .monospaced)).frame(width: 24)
            }
            HStack {
                Text("字距").font(.system(size: 13, weight: .medium))
                Slider(value: $letterSpacing, in: 0...3, step: 0.25)
                Text(String(format: "%.1f", letterSpacing)).font(.system(size: 11, design: .monospaced)).frame(width: 28)
            }
            HStack {
                Text("行距").font(.system(size: 13, weight: .medium))
                Slider(value: $lineSpacing, in: 3...20, step: 1)
                Text("\(Int(lineSpacing))").font(.system(size: 11, design: .monospaced)).frame(width: 28)
            }
            Picker("翻页方式", selection: $readingMode) {
                Label("上下滑动", systemImage: "arrow.up.and.down").tag("vertical")
                Label("左右翻页", systemImage: "arrow.left.and.right").tag("horizontal")
            }.pickerStyle(.segmented)
            Text("长按正文仍可精确选字、划线并写书评")
                .font(.system(size: 10)).foregroundColor(theme.textDim)
        }
        .padding(22)
        .foregroundColor(theme.text)
    }
}

private struct FictionQuotesView: View {
    @ObservedObject var model: FictionStudyModel
    let books: [FictionBook]
    let onBack: () -> Void
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var rows: [FictionQuoteRow] = []
    @State private var selecting = false
    @State private var selected: Set<String> = []
    @State private var sending = false
    private var theme: AlcoveTheme { .panelNamed(themeName) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                        .frame(width: 28, height: 34)
                }.buttonStyle(.plain)
                Text("摘句册").font(.system(size: 14, weight: .semibold, design: .serif))
                Spacer()
                if selecting {
                    Button("取消") { selecting = false; selected.removeAll() }.font(.system(size: 11))
                }
            }.padding(.horizontal, 14).padding(.vertical, 6)
            Group {
            if rows.isEmpty {
                ContentUnavailableView("摘句册还是空的", systemImage: "quote.opening",
                                       description: Text("你划下第一句话后，会连着书评一起收在这里"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(rows) { row in
                            HStack(alignment: .top, spacing: 10) {
                                if selecting {
                                    Image(systemName: selected.contains(row.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(theme.fyAccent).font(.system(size: 19))
                                }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("“\(row.annotation.quote)”")
                                    .font(.system(size: 14, design: .serif))
                                Text(row.annotation.note).font(.system(size: 13))
                                Text("《\(row.book.title)》 · 第 \(row.annotation.chapter) 章")
                                    .font(.system(size: 10)).foregroundColor(theme.textDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14).contentShape(Rectangle()).foyerCard(theme)
                                .onTapGesture { if selecting { toggle(row) } }
                                .onLongPressGesture { selecting = true; selected.insert(row.id) }
                        }
                    }.padding(18)
                }
            }
            if selecting {
                Button { Task { await sendSelected() } } label: {
                    Label(sending ? "正在发送" : "合并发送给陈璟（\(selected.count)）", systemImage: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 46)
                }.buttonStyle(.borderedProminent).tint(theme.fyAccent).padding(.horizontal, 18).padding(.bottom, 10)
                    .disabled(selected.isEmpty || sending)
            }
            }
        }
        .foregroundColor(theme.text)
        .task {
            var gathered: [FictionQuoteRow] = []
            for book in books {
                let notes = await model.annotations(bookID: book.id)
                gathered.append(contentsOf: notes.map { FictionQuoteRow(book: book, annotation: $0) })
            }
            rows = gathered.sorted { ($0.annotation.ts ?? "") > ($1.annotation.ts ?? "") }
        }
    }

    private func toggle(_ row: FictionQuoteRow) {
        if selected.contains(row.id) { selected.remove(row.id) } else { selected.insert(row.id) }
    }

    @MainActor private func sendSelected() async {
        let picked = rows.filter { selected.contains($0.id) }
        guard !picked.isEmpty else { return }
        sending = true; defer { sending = false }
        let payload: [String: Any] = ["book": picked[0].book.title, "author": picked[0].book.author,
          "quotes": picked.map { ["chapter": $0.annotation.chapter, "text": $0.annotation.quote,
                                    "note": $0.annotation.note, "time": $0.annotation.ts ?? ""] }]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        _ = try? await AlcoveAPI.send(text: "[READING_CARD]\(json)[/READING_CARD]")
        selecting = false; selected.removeAll()
    }
}

private struct FictionQuoteRow: Identifiable {
    let book: FictionBook
    let annotation: FictionAnnotation
    var id: String { "\(book.id)-\(annotation.id)" }
}

private struct FictionSelectableText: UIViewRepresentable {
    let text: String
    let fontSize: Double
    let letterSpacing: Double
    let lineSpacing: Double
    let onReview: (String) -> Void
    func makeUIView(context: Context) -> FictionTextView {
        let view = FictionTextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.widthTracksTextView = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.textColor = .label
        view.onReview = onReview
        return view
    }
    func updateUIView(_ view: FictionTextView, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = max(8, fontSize * 0.75)
        view.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.label,
            .kern: letterSpacing,
            .paragraphStyle: paragraph
        ])
        view.onReview = onReview
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FictionTextView,
                      context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let measured = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: measured.height)
    }
}

private final class FictionTextView: UITextView {
    var onReview: ((String) -> Void)?
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .context else { return }
        let action = UIAction(title: "划线并写书评", image: UIImage(systemName: "highlighter")) { [weak self] _ in
            guard let self, let range = selectedTextRange,
                  let quote = text(in: range)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !quote.isEmpty else { return }
            onReview?(quote)
        }
        builder.insertChild(UIMenu(options: .displayInline, children: [action]), atStartOfMenu: .standardEdit)
    }
}

private struct NativeCalendarView: View {
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var selectedDate: String?
    @State private var events: [String: [[String: Any]]] = [:]
    @State private var periodDates: [String: String] = [:]
    @State private var loading = true
    @State private var expandedIdx: Int?
    @State private var diaryContents: [String: String] = [:]
    @State private var displayMode = 0
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    private var dotDates: Set<String> {
        Set(events.keys)
    }

    private var selectedEvents: [[String: Any]] {
        guard let sel = selectedDate else { return [] }
        return events[sel] ?? []
    }

    private var monthEntries: [(date: String, event: [String: Any])] {
        events.keys.sorted(by: >).flatMap { date in
            (events[date] ?? []).map { (date: date, event: $0) }
        }
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
                        HStack(alignment: .firstTextBaseline) {
                            Text("diary & moments")
                                .font(.custom("Snell Roundhand", size: 20))
                                .italic()
                            Spacer()
                            Text("\(monthEntries.count) entries")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.textDim)
                        }
                        .padding(.horizontal, 4)

                        Picker("日记视图", selection: $displayMode) {
                            Text("日历").tag(0)
                            Text("本月条目").tag(1)
                        }
                        .pickerStyle(.segmented)

                        if displayMode == 0 {
                            MonthCalendarGrid(
                                year: year, month: month, theme: theme,
                                dotDates: dotDates, periodDates: periodDates,
                                counts: events.mapValues { $0.count },
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
                                }
                                .padding(.horizontal, 4)
                            }

                            if !selectedEvents.isEmpty {
                                Text(selectedDateLabel)
                                    .font(.system(size: 14, weight: .semibold, design: .serif))
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
                                            Image(systemName: "pencil.and.scribble")
                                                .font(.system(size: 15, weight: .light))
                                                .foregroundColor(theme.textDim)
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
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(monthEntries.enumerated()), id: \.offset) { _, item in
                                    Button {
                                        selectedDate = item.date
                                        displayMode = 0
                                    } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.date)
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                Text(item.event.string("title"))
                                                    .font(.system(size: 12, design: .serif))
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Text(item.event.string("time"))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(theme.textDim)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(theme.textDim)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity)
                                        .foyerCard(theme)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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

// MARK: - Ombre Brain native panels

private struct OBBucket: Identifiable {
    let id: String
    let name: String
    let type: String
    let domains: [String]
    let tags: [String]
    let preview: String
    let score: Double
    let importance: Int
    let pinned: Bool
    let resolved: Bool
    let digested: Bool
    let forgotten: Bool
    let anchor: Bool
    let created: String
    let lastActive: String

    init(_ row: [String: Any]) {
        id = row.string("id")
        name = row.string("name", "title")
        type = row.string("type")
        domains = row["domain"] as? [String] ?? []
        tags = row["tags"] as? [String] ?? []
        preview = row.string("content_preview")
        score = (row["score"] as? NSNumber)?.doubleValue ?? 0
        importance = row.int("importance")
        pinned = row.bool("pinned")
        resolved = row.bool("resolved")
        digested = row.bool("digested")
        forgotten = row.bool("dont_surface")
        anchor = row.bool("anchor")
        created = row.string("created")
        lastActive = row.string("last_active")
    }
}

private struct MorningPaperSource: Identifiable {
    let id = UUID()
    let name: String
    let url: String
}

private struct MorningPaperItem: Identifiable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let url: String
    let publishedAt: String
    let sources: [MorningPaperSource]
}

private struct MorningPaperDocument {
    let date: String
    let generatedAt: String
    let status: String
    let sections: [String: [MorningPaperItem]]
}

@MainActor private final class MorningPaperModel: ObservableObject {
    @Published var paper: MorningPaperDocument?
    @Published var loading = false
    @Published var error: String?

    func load(date: String? = nil) async {
        loading = true
        defer { loading = false }
        do {
            let path = date.flatMap { $0.isEmpty ? nil : $0 }.map { "/paper/\($0)" } ?? "/paper/today"
            let root = try await NativeHouseAPI.object(path)
            guard let raw = root["paper"] as? [String: Any],
                  let sections = raw["sections"] as? [String: Any] else {
                throw URLError(.cannotParseResponse)
            }
            var decoded: [String: [MorningPaperItem]] = [:]
            for (key, value) in sections {
                let rows = value as? [[String: Any]] ?? []
                decoded[key] = rows.map { row in
                    let secondary = (row["sources"] as? [[String: Any]] ?? []).map {
                        MorningPaperSource(name: $0["source"] as? String ?? "来源",
                                           url: $0["url"] as? String ?? "")
                    }
                    return MorningPaperItem(
                        id: row["id"] as? String ?? UUID().uuidString,
                        title: row["title"] as? String ?? "",
                        summary: row["summary"] as? String ?? "",
                        source: row["source"] as? String ?? "",
                        url: row["url"] as? String ?? "",
                        publishedAt: row["published_at"] as? String ?? "",
                        sources: secondary
                    )
                }
            }
            paper = MorningPaperDocument(
                date: raw["date"] as? String ?? root["date"] as? String ?? "",
                generatedAt: raw["generated_at"] as? String ?? root["created_at"] as? String ?? "",
                status: raw["status"] as? String ?? "published",
                sections: decoded
            )
            error = nil
        } catch {
            self.error = "晨报还没有送到"
        }
    }
}

struct NativeMorningPaperView: View {
    var requestedDate: String? = nil
    var embedded = false
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var model = MorningPaperModel()
    private var theme: AlcoveTheme { .panelNamed(themeName) }
    private let paper = Color(red: 0.968, green: 0.958, blue: 0.932)
    private let ink = Color(red: 0.19, green: 0.18, blue: 0.16)
    private let fadedInk = Color(red: 0.34, green: 0.32, blue: 0.29)
    private let cobalt = Color(red: 0.10, green: 0.28, blue: 0.82)

    private let order: [(String, String, String)] = [
        ("today_first", "今天先知道", "01"),
        ("wuhan_window", "武汉窗外", "02"),
        ("ai_grew", "AI 又长了什么", "03"),
        ("about_her", "可能和你有关", "04"),
        ("chenjing_pick", "陈璟私心想递给你", "05")
    ]

    var body: some View {
        Group {
            if embedded {
                paperContent.padding(.horizontal, 12)
            } else {
                ScrollView(showsIndicators: false) {
                    paperContent.padding(.horizontal, 18)
                }
                .refreshable { await model.load(date: requestedDate) }
            }
        }
        .foregroundColor(ink)
        .background {
            ZStack {
                paper
                Canvas { context, size in
                    for y in stride(from: CGFloat(7), through: size.height, by: 17) {
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: size.width, y: y + 0.8))
                        context.stroke(line, with: .color(Color.black.opacity(0.018)), lineWidth: 0.45)
                    }
                }
            }.ignoresSafeArea()
        }
        .task(id: requestedDate) { await model.load(date: requestedDate) }
    }

    private var paperContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            masthead
            if model.loading && model.paper == nil {
                ProgressView("正在取今天的晨报")
                    .frame(maxWidth: .infinity).padding(.vertical, 54)
            } else if let document = model.paper {
                if embedded {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 0) {
                            ForEach(Array(order.prefix(3)), id: \.0) { entry in
                                paperSection(number: entry.2, title: entry.1,
                                             items: document.sections[entry.0] ?? [])
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        Rectangle().fill(ink.opacity(0.22)).frame(width: 0.8)
                            .shadow(color: .black.opacity(0.10), radius: 2, x: 1)
                        VStack(spacing: 0) {
                            ForEach(Array(order.suffix(2)), id: \.0) { entry in
                                paperSection(number: entry.2, title: entry.1,
                                             items: document.sections[entry.0] ?? [])
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } else {
                    ForEach(order, id: \.0) { entry in
                        paperSection(number: entry.2, title: entry.1,
                                     items: document.sections[entry.0] ?? [])
                    }
                }
                Text("end of morning edition · 收好，明天见")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5).foregroundColor(fadedInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ContentUnavailableView(model.error ?? "今日无刊", systemImage: "newspaper",
                                       description: Text("等陈璟把今天看到的世界带回来"))
                    .padding(.vertical, 42)
            }
        }
        .padding(.bottom, embedded ? 8 : 28)
    }

    private var masthead: some View {
        VStack(spacing: 9) {
            Text("MORNING PAPER")
                .font(.system(size: embedded ? 8 : 10, weight: .semibold, design: .monospaced))
                .tracking(2.2)
                .foregroundColor(cobalt)
            Text("雨 霁 报")
                .font(.system(size: embedded ? 22 : 29, weight: .semibold, design: .serif))
                .tracking(5)
            Text("今早替你看过世界了")
                .font(.custom("HanziPenSC-W3", size: embedded ? 11 : 13))
                .foregroundColor(cobalt.opacity(0.82))
                .rotationEffect(.degrees(-2.2))
                .offset(x: 52)
            HStack {
                Text(displayDate(model.paper?.date ?? ""))
                Spacer()
                Text(model.paper?.status == "fixture" ? "样刊" : "今日刊")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(fadedInk)
            Rectangle().fill(ink.opacity(0.72)).frame(height: 1.5)
            Rectangle().fill(ink.opacity(0.26)).frame(height: 0.5)
        }
        .foregroundColor(ink)
        .padding(.top, embedded ? 10 : 14)
        .padding(.bottom, embedded ? 11 : 18)
    }

    private func paperSection(number: String, title: String, items: [MorningPaperItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(number)
                    .font(.system(size: embedded ? 7 : 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(cobalt, in: UnevenRoundedRectangle(
                        topLeadingRadius: 2, bottomLeadingRadius: 7,
                        bottomTrailingRadius: 2, topTrailingRadius: 6))
                    .rotationEffect(.degrees(number == "05" ? 2 : -1))
                Text(title)
                    .font(number == "05"
                          ? .custom("HanziPenSC-W3", size: embedded ? 13 : 20)
                          : .system(size: embedded ? 13 : 20, weight: .semibold, design: .serif))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 9)

            if items.isEmpty {
                Text("今天这一栏暂时留白")
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(fadedInk)
                    .padding(.vertical, 12)
            } else if embedded {
                ForEach(items) { item in article(item) }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top),
                                    GridItem(.flexible(), spacing: 12, alignment: .top)],
                          alignment: .leading, spacing: 6) {
                    ForEach(items) { item in
                        article(item)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(ink.opacity(0.11)).frame(width: 0.5)
                                    .offset(x: 6)
                            }
                    }
                }
            }
        }
        .padding(.vertical, embedded ? 9 : 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ink.opacity(0.34)).frame(height: 0.7)
        }
    }

    private func article(_ item: MorningPaperItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = URL(string: item.url), !item.url.isEmpty {
                Link(destination: url) { articleTitle(item.title, linked: true) }
                    .buttonStyle(.plain)
                    .accessibilityHint("在浏览器打开原文")
            } else {
                articleTitle(item.title, linked: false)
            }
            Text(item.summary)
                .font(.system(size: embedded ? 10.5 : 13, design: .serif))
                .lineSpacing(embedded ? 2 : 4)
                .foregroundColor(ink.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Text(item.source.uppercased())
                if !item.publishedAt.isEmpty {
                    Text("·")
                    Text(displayTime(item.publishedAt))
                }
                if !item.sources.isEmpty {
                    Text("· 已交叉核验 \(item.sources.count + 1) 个来源")
                }
            }
            .font(.system(size: embedded ? 6.5 : 8.5, weight: .medium, design: .monospaced))
            .foregroundColor(fadedInk)
        }
        .padding(.vertical, embedded ? 7 : 13)
    }

    private func articleTitle(_ text: String, linked: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(text)
                .font(.system(size: embedded ? 12 : 15, weight: .semibold, design: .serif))
                .multilineTextAlignment(.leading)
            if linked {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundColor(ink)
    }

    private func displayDate(_ raw: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: raw + "T00:00:00+08:00") else { return raw }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "yyyy年M月d日 · EEEE"
        return f.string(from: date)
    }

    private func displayTime(_ raw: String) -> String {
        let f = ISO8601DateFormatter()
        guard let date = f.date(from: raw) else { return raw }
        let out = DateFormatter(); out.timeZone = TimeZone(identifier: "Asia/Shanghai"); out.dateFormat = "HH:mm"
        return out.string(from: date)
    }
}

private struct PipeLabEvent: Decodable {
    let eventID: Int
    let seq: Int
    let event: String
    let turnID: String
    let delta: String?
    let toolCallID: String?
    let name: String?
    let ok: Bool?
    let labMessageID: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id", seq, event, delta, name, ok, reason
        case turnID = "turn_id", toolCallID = "tool_call_id"
        case labMessageID = "lab_message_id"
    }
}

@MainActor private final class PipeLabModel: ObservableObject {
    @Published var state = AlcoveAPI.LiveState()
    @Published var connected = false
    @Published var sending = false
    @Published var notice: String?
    private var streamTask: Task<Void, Never>?
    private var lastEventID = -1

    func connect() {
        guard streamTask == nil else { return }
        streamTask = Task { [weak self] in await self?.consume() }
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        connected = false
    }

    func send(_ text: String) async -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !sending, !state.active else { return false }
        sending = true
        defer { sending = false }
        do {
            let result = try await AlcoveAPI.postRaw("/lab/send", body: ["text": clean])
            guard result["ok"] as? Bool != false else { throw URLError(.badServerResponse) }
            notice = nil
            return true
        } catch {
            notice = "实验管道没有接住这句话"
            return false
        }
    }

    private func consume() async {
        var retry: UInt64 = 1_000_000_000
        while !Task.isCancelled {
            do {
                var request = URLRequest(url: AlcoveAPI.fullURL("/stream/lab"))
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                if lastEventID >= 0 {
                    request.setValue(String(lastEventID), forHTTPHeaderField: "Last-Event-ID")
                }
                request.timeoutInterval = 60 * 60
                let (bytes, response) = try await AlcoveAPI.session.bytes(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                connected = true
                notice = nil
                retry = 1_000_000_000
                for try await line in bytes.lines {
                    guard !Task.isCancelled else { return }
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    guard let data = payload.data(using: .utf8),
                          let event = try? JSONDecoder().decode(PipeLabEvent.self, from: data),
                          event.eventID > lastEventID else { continue }
                    lastEventID = event.eventID
                    apply(event)
                }
            } catch is CancellationError {
                return
            } catch {
                connected = false
                notice = "实验流正在重连"
                try? await Task.sleep(nanoseconds: retry)
                retry = min(retry * 2, 20_000_000_000)
            }
        }
    }

    private func apply(_ event: PipeLabEvent) {
        if event.event == "start" || state.turnID != event.turnID {
            state = AlcoveAPI.LiveState(active: true, turnID: event.turnID)
        }
        guard event.seq > state.lastSeq else { return }
        state.lastSeq = event.seq
        switch event.event {
        case "start":
            state.active = true
            state.finishing = false
            state.error = nil
        case "thinking_delta":
            let delta = event.delta ?? ""
            state.thinking += delta
            if let i = state.timeline.indices.last, state.timeline[i].kind == "thinking" {
                state.timeline[i].text += delta
            } else if !delta.isEmpty {
                state.timeline.append(.init(id: "lab-thinking-\(event.eventID)",
                                            kind: "thinking", text: delta))
            }
        case "native_thinking_delta":
            // v1.2: archive channel only. The lab deliberately never renders it.
            state.nativeThinking += event.delta ?? ""
        case "text_delta":
            state.say += event.delta ?? ""
        case "tool_start":
            let id = event.toolCallID ?? "lab-tool-\(event.eventID)"
            if !state.tools.contains(where: { $0.id == id }) {
                let name = event.name ?? "执行动作"
                state.tools.append(.init(id: id, name: name))
                state.timeline.append(.init(id: id, kind: "tool", text: name))
            }
        case "tool_done":
            if let id = event.toolCallID, let i = state.tools.firstIndex(where: { $0.id == id }) {
                state.tools[i].done = true; state.tools[i].ok = event.ok
            }
            if let id = event.toolCallID, let i = state.timeline.firstIndex(where: { $0.id == id }) {
                state.timeline[i].done = true; state.timeline[i].ok = event.ok
            }
        case "finish":
            state.active = false
            state.finishing = false
            state.messageID = event.labMessageID
        case "error":
            state.active = false
            state.error = event.reason ?? "实验轮中断"
        default:
            break
        }
    }
}

private struct NativePipeLabView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var model = PipeLabModel()
    @State private var draft = ""
    @State private var showProcess = true
    @FocusState private var focused: Bool
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if model.state.turnID.isEmpty {
                            ContentUnavailableView("常驻管道实验室", systemImage: "waveform.path.ecg.rectangle",
                                description: Text("这里与正式聊天完全隔离。发一句话，观察思绪、工具与正文怎样实时经过管道。"))
                                .padding(.top, 48)
                        } else {
                            processPanel
                            if !model.state.say.isEmpty {
                                Text(model.state.say)
                                    .font(.system(size: 16))
                                    .lineSpacing(6)
                                    .foregroundColor(theme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foyerCard(theme)
                            }
                            if let error = model.state.error {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }
                        Color.clear.frame(height: 1).id("lab-tail")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { focused = false }
                .onChange(of: model.state.say) { _ in scrollTail(proxy) }
                .onChange(of: model.state.thinking) { _ in scrollTail(proxy) }
            }
            composer
        }
        .task { model.connect() }
        .onDisappear { model.disconnect() }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Circle().fill(model.connected ? Color.green : Color.orange).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pipe Lab").font(.system(size: 18, weight: .semibold, design: .serif))
                Text(model.state.active ? "常驻进程正在回应" : (model.connected ? "实验流已连接" : "正在连接"))
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(theme.textDim)
            }
            Spacer()
            Text("ISOLATED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.4).foregroundColor(theme.fyAccent)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.fyBorder).frame(height: 0.5) }
    }

    private var processPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.easeInOut(duration: 0.18)) { showProcess.toggle() } } label: {
                HStack {
                    Text("ThoughtProcess").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: showProcess ? "chevron.up" : "chevron.down").font(.system(size: 9))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            if showProcess {
                ForEach(model.state.timeline) { item in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11)).frame(width: 16).foregroundColor(theme.fyAccent)
                        Text(item.text)
                            .font(item.kind == "thinking" ? .system(size: 12).italic() : .system(size: 12, weight: .medium))
                            .foregroundColor(theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .foyerCard(theme)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("给实验管道一句话", text: $draft, axis: .vertical)
                .lineLimit(1...5).focused($focused)
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(theme.fyCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button {
                let text = draft
                Task { if await model.send(text) { draft = "" } }
            } label: {
                Group {
                    if model.sending { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.up") }
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(theme.fyAccent, in: Circle())
                .foregroundColor(theme.fyCard)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.sending || model.state.active)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.state.active ? 0.45 : 1)
            .accessibilityLabel("发送到实验管道")
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 12)
        .background(theme.fyCardSub.opacity(0.94))
        .overlay(alignment: .top) { Rectangle().fill(theme.fyBorder).frame(height: 0.5) }
    }

    private func scrollTail(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo("lab-tail", anchor: .bottom) }
    }
}

@MainActor private final class OBMemoryModel: ObservableObject {
    @Published var buckets: [OBBucket] = []
    @Published var loading = false
    @Published var error = ""

    func load() async {
        loading = true; error = ""
        do {
            let rows = try await NativeHouseAPI.array("/api/ob/api/buckets?sort=score")
            buckets = rows.map(OBBucket.init)
        } catch { self.error = "OB 连接失败" }
        loading = false
    }
}

private struct NativeOBMemoryView: View {
    private enum CreationOrder: String, CaseIterable {
        case oldest = "最早创建"
        case newest = "最新创建"
        case combined = "综合创建"
    }

    @StateObject private var model = OBMemoryModel()
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var query = ""
    @State private var filter = "全部"
    @State private var selected: OBBucket?
    @State private var selecting = false
    @State private var checked: Set<String> = []
    @State private var showAnchors = false
    @State private var showNetwork = false
    @State private var creationOrder: CreationOrder = .combined
    private var theme: AlcoveTheme { .panelNamed(themeName) }
    private let filters = ["全部", "钉选", "Feel", "未解决", "已消化", "已遗忘", "归档"]

    private var visible: [OBBucket] {
        let filtered = model.buckets.filter { item in
            let matches: Bool
            switch filter {
            case "钉选": matches = item.pinned
            case "Feel": matches = item.type == "feel"
            case "未解决": matches = !item.resolved && item.type != "permanent" && !item.pinned
            case "已消化": matches = item.digested
            case "已遗忘": matches = item.forgotten
            case "归档": matches = item.type == "archived"
            default: matches = true
            }
            guard matches else { return false }
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return q.isEmpty || ([item.name, item.preview] + item.domains + item.tags)
                .joined(separator: " ").lowercased().contains(q)
        }
        switch creationOrder {
        case .combined:
            // The API's score ordering is OB's existing comprehensive order.
            return filtered
        case .oldest:
            return filtered.enumerated().sorted { lhs, rhs in
                let left = lhs.element.created
                let right = rhs.element.created
                if left.isEmpty != right.isEmpty { return !left.isEmpty }
                if left == right { return lhs.offset < rhs.offset }
                return left < right
            }.map { $0.element }
        case .newest:
            return filtered.enumerated().sorted { lhs, rhs in
                let left = lhs.element.created
                let right = rhs.element.created
                if left.isEmpty != right.isEmpty { return !left.isEmpty }
                if left == right { return lhs.offset < rhs.offset }
                return left > right
            }.map { $0.element }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            FoyerPanelTitle(title: "Memory", theme: theme)
            HStack(spacing: 8) {
                Button { showAnchors = true } label: { Label("Anchors", systemImage: "scope") }
                Button { showNetwork = true } label: { Label("记忆网络", systemImage: "point.3.connected.trianglepath.dotted") }
                Spacer()
                Button(selecting ? "完成" : "批量") {
                    selecting.toggle(); if !selecting { checked.removeAll() }
                }
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.plain).foregroundColor(theme.fyAccent)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(theme.textDim)
                TextField("搜索 记忆、标签或正文", text: $query)
                    .font(.system(size: 13))
                Text("\(visible.count)").font(.system(size: 11, design: .monospaced)).foregroundColor(theme.fyAccent)
            }
            .padding(.horizontal, 12).frame(height: 40).foyerCard(theme)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(filters, id: \.self) { value in
                        Button(value) { filter = value }
                            .font(.system(size: 11, weight: filter == value ? .semibold : .regular))
                            .foregroundColor(filter == value ? theme.text : theme.textDim)
                            .padding(.horizontal, 12).frame(height: 31)
                            .background(filter == value ? theme.fyAccentSoft : theme.fyCard, in: Capsule())
                    }
                }
            }
            Picker("创建顺序", selection: $creationOrder) {
                ForEach(CreationOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
            if model.loading { Spacer(); ProgressView().tint(theme.fyAccent); Spacer() }
            else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        ForEach(visible) { item in
                            Button {
                                if selecting {
                                    if checked.contains(item.id) { checked.remove(item.id) } else { checked.insert(item.id) }
                                } else { selected = item }
                            } label: { memoryCard(item) }.buttonStyle(.plain)
                        }
                        if visible.isEmpty { Text(model.error.isEmpty ? "没有符合的记忆" : model.error).foregroundColor(theme.textDim).padding(40) }
                    }.padding(.bottom, 18)
                }.refreshable { await model.load() }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 18).foregroundColor(theme.text)
        .foyerPanel(theme).padding(.horizontal, 12).padding(.top, 8)
        .task { await model.load() }
        .sheet(item: $selected) { item in OBMemoryDetailView(item: item) { await model.load() } }
        .sheet(isPresented: $showAnchors) { OBAnchorsView { await model.load() } }
        .sheet(isPresented: $showNetwork) { OBNetworkView() }
        .safeAreaInset(edge: .bottom) {
            if selecting && !checked.isEmpty {
                HStack(spacing: 10) {
                    Text("已选 \(checked.count)").font(.system(size: 11, design: .monospaced))
                    Spacer()
                    batchButton("遗忘", "forget")
                    batchButton("解决", "resolve")
                    batchButton("归档", "archive")
                }.padding(.horizontal, 16).frame(height: 52)
                    .background(.ultraThinMaterial).foregroundColor(theme.text)
            }
        }
    }

    private func memoryCard(_ item: OBBucket) -> some View {
        HStack(alignment: .top, spacing: 11) {
            if selecting {
                Image(systemName: checked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(theme.fyAccent)
            }
            Image(systemName: item.pinned ? "pin.fill" : item.type == "feel" ? "drop" : item.resolved ? "moon" : "circle.dotted")
                .font(.system(size: 15, weight: .light)).foregroundColor(theme.fyAccent).frame(width: 22)
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text(item.name).font(.system(size: 14, weight: .semibold)).lineLimit(1); Spacer(); Text(String(format: "%.2f", item.score)).font(.system(size: 10, design: .monospaced)).foregroundColor(theme.fyAccent) }
                if !item.domains.isEmpty { Text(item.domains.joined(separator: " · ")).font(.system(size: 10)).foregroundColor(theme.fyAccent.opacity(0.8)) }
                Text(item.preview).font(.system(size: 12)).foregroundColor(theme.textDim).lineLimit(3).lineSpacing(2)
            }
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading).foyerCard(theme)
    }

    private func batchButton(_ title: String, _ action: String) -> some View {
        Button(title) {
            let ids = Array(checked)
            Task {
                _ = try? await NativeHouseAPI.request("/api/ob/api/buckets/batch", method: "POST", body: ["ids": ids, "action": action])
                checked.removeAll(); selecting = false; await model.load()
            }
        }.font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).frame(height: 30)
            .background(theme.fyAccentSoft, in: Capsule())
    }
}

private struct OBAnchor: Identifiable {
    let id, name, preview, type: String; let domains, tags: [String]
    init(_ r: [String: Any]) { id=r.string("id"); name=r.string("name"); preview=r.string("preview"); type=r.string("type"); domains=r["domain"] as? [String] ?? []; tags=r["tags"] as? [String] ?? [] }
}

private struct OBAnchorsView: View {
    let didChange: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName="haven"
    @State private var anchors:[OBAnchor]=[]; @State private var count=0; @State private var limit=24; @State private var error=""
    private var theme:AlcoveTheme{.panelNamed(themeName)}
    var body: some View { NavigationStack {
        ScrollView { LazyVStack(spacing:10) {
            HStack { Text("\(count) / \(limit) 个坐标锚点").font(.system(size:11,design:.monospaced)); Spacer() }.foregroundColor(theme.fyAccent)
            ForEach(anchors) { a in
                VStack(alignment:.leading,spacing:8) {
                    HStack { Image(systemName:"scope"); Text(a.name).font(.system(size:14,weight:.semibold)); Spacer(); Text(a.type).font(.system(size:9,design:.monospaced)) }
                    if !a.domains.isEmpty { Text(a.domains.joined(separator:" · ")).font(.system(size:10)).foregroundColor(theme.fyAccent) }
                    Text(a.preview).font(.system(size:12)).foregroundColor(theme.textDim).lineLimit(4)
                    Button("移出 Anchors", role:.destructive) { Task { _ = try? await NativeHouseAPI.request("/api/ob/api/bucket/\(a.id)/anchor",method:"POST",body:["value":false]); await load(); await didChange() } }.font(.system(size:11))
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading).foyerCard(theme)
            }
            if anchors.isEmpty { Text(error.isEmpty ? "还没有 anchor":"读取失败：\(error)").foregroundColor(theme.textDim).padding(40) }
        }.padding(16) }.background(theme.fyCardSub.ignoresSafeArea()).foregroundColor(theme.text)
            .navigationTitle("Anchors").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction){Button("关闭"){dismiss()}} }.task{await load()}
    }}
    private func load() async { do { let o=try await NativeHouseAPI.object("/api/ob/api/anchors"); anchors=(o["anchors"] as? [[String:Any]] ?? []).map(OBAnchor.init); count=o.int("count"); limit=o.int("limit") } catch { self.error=error.localizedDescription } }
}

private struct OBNetworkNode: Identifiable { let id,label,kind:String; let frequency:Int; let anchor:Bool; let buckets:[String]; init(_ r:[String:Any]){id=r.string("id");label=r.string("label","name");kind=r.string("kind");frequency=r.int("freq");anchor=r.bool("anchor");buckets=r["buckets"] as? [String] ?? []} }
private struct OBNetworkEdge { let source,target:String; let weight:Double; init(_ r:[String:Any]){source=r.string("source");target=r.string("target");weight=(r["weight"] as? NSNumber)?.doubleValue ?? 1} }

private struct OBNetworkView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName="haven"
    @State private var nodes:[OBNetworkNode]=[]; @State private var edges:[OBNetworkEdge]=[]; @State private var mode="concept"; @State private var selected:OBNetworkNode?
    private var theme:AlcoveTheme{.panelNamed(themeName)}
    var body:some View { NavigationStack { VStack(spacing:10) {
        Picker("模式",selection:$mode){Text("概念").tag("concept");Text("语义").tag("embedding")}.pickerStyle(.segmented).padding(.horizontal,16)
        GeometryReader { geo in
            let positions = layout(size:geo.size)
            ZStack {
                Canvas { ctx,_ in for e in edges { if let a=positions[e.source],let b=positions[e.target] { var p=Path();p.move(to:a);p.addLine(to:b);ctx.stroke(p,with:.color(theme.textDim.opacity(min(0.55,0.12+e.weight*0.09))),lineWidth:max(0.5,min(3,e.weight))) } } }
                ForEach(nodes) { n in if let p=positions[n.id] { Button { selected=n } label:{ Text(n.label).font(.system(size:n.anchor ? 11:9,weight:n.anchor ? .bold:.medium)).lineLimit(1).padding(.horizontal,7).frame(height:24).background(n.anchor ? theme.fyAccentSoft:theme.fyCard,in:Capsule()).overlay(Capsule().stroke(theme.fyAccent.opacity(n.anchor ? 0.8:0.18)))}.buttonStyle(.plain).position(p) } }
            }.clipped()
        }
        Text("\(nodes.count) 个节点 · \(edges.count) 条连接").font(.system(size:10,design:.monospaced)).foregroundColor(theme.textDim).padding(.bottom,12)
    }.padding(.top,10).background(theme.fyCardSub.ignoresSafeArea()).foregroundColor(theme.text).navigationTitle("记忆网络").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("关闭"){dismiss()}}}.task(id:mode){await load()} }
    .sheet(item:$selected){n in NavigationStack{VStack(alignment:.leading,spacing:14){Text(n.label).font(.system(size:24,weight:.semibold,design:.serif));Text("\(n.kind) · 出现在 \(n.frequency) 条记忆中").foregroundColor(theme.fyAccent);Text(n.buckets.joined(separator:"\n")).font(.system(size:11,design:.monospaced)).foregroundColor(theme.textDim);Spacer()}.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(theme.fyCardSub.ignoresSafeArea()).foregroundColor(theme.text).toolbar{ToolbarItem(placement:.confirmationAction){Button("关闭"){selected=nil}}}}}
    }
    private func load()async{if let o=try? await NativeHouseAPI.object("/api/ob/api/network?mode=\(mode)"){nodes=(o["nodes"] as? [[String:Any]] ?? []).map(OBNetworkNode.init);edges=(o["edges"] as? [[String:Any]] ?? []).map(OBNetworkEdge.init)}}
    private func layout(size:CGSize)->[String:CGPoint]{var out:[String:CGPoint]=[:];let ranked=nodes.sorted{$0.frequency>$1.frequency};let cx=size.width/2,cy=size.height/2;for (i,n) in ranked.enumerated(){if i==0{out[n.id]=CGPoint(x:cx,y:cy);continue};let ring=Double((i-1)/10+1),slot=Double((i-1)%10),angle=slot*(2*Double.pi/10)+ring*0.31;let radius=min(Double(min(size.width,size.height))*0.43,55+ring*55);out[n.id]=CGPoint(x:cx+CGFloat(cos(angle)*radius),y:cy+CGFloat(sin(angle)*radius))};return out}
}

private struct OBMemoryDetailView: View {
    let item: OBBucket
    let didChange: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var detail: [String: Any] = [:]
    @State private var name = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var domains = ""
    @State private var why = ""
    @State private var importance = 5.0
    @State private var saving = false
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("标题", text: $name).font(.system(size: 20, weight: .semibold, design: .serif))
                    HStack { Text(item.type.uppercased()); Spacer(); Text("score \(String(format: "%.3f", item.score))") }.font(.system(size: 10, design: .monospaced)).foregroundColor(theme.fyAccent)
                    TextEditor(text: $content).font(.system(size: 13, design: .monospaced)).scrollContentBackground(.hidden).frame(minHeight: 240).padding(8).foyerCard(theme)
                    field("标签（逗号分隔）", $tags); field("领域（逗号分隔）", $domains); field("为什么记得", $why)
                    HStack { Text("重要度"); Slider(value: $importance, in: 1...10, step: 1); Text("\(Int(importance))") }.font(.system(size: 12))
                    actionGrid
                }.padding(18)
            }
            .background(theme.fyCardSub.ignoresSafeArea())
            .foregroundColor(theme.text)
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(saving ? "保存中" : "保存") { Task { await save() } }.disabled(saving) }
            }
            .task { await load() }
        }
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 10)).foregroundColor(theme.textDim); TextField(title, text: text).font(.system(size: 12)).padding(10).foyerCard(theme) }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            action(item.pinned ? "取消钉选" : "钉选", "pin", "pin")
            action(item.resolved ? "取消已解决" : "标记已解决", "checkmark.circle", "resolve")
            action(item.forgotten ? "允许浮现" : "主动遗忘", "eye.slash", "forget")
            Button { Task { _ = try? await NativeHouseAPI.request("/api/ob/api/bucket/\(item.id)/anchor", method: "POST", body: ["value": !item.anchor]); await didChange(); dismiss() } } label: {
                Label(item.anchor ? "移出 Anchor" : "加入 Anchor", systemImage: "scope").font(.system(size: 11)).frame(maxWidth: .infinity).padding(11).foyerCard(theme)
            }.buttonStyle(.plain)
            action("归档", "archivebox", "archive")
        }
    }
    private func action(_ title: String, _ icon: String, _ endpoint: String) -> some View {
        Button { Task { try? await NativeHouseAPI.post("/api/ob/api/bucket/\(item.id)/\(endpoint)"); await didChange(); dismiss() } } label: {
            Label(title, systemImage: icon).font(.system(size: 11)).frame(maxWidth: .infinity).padding(11).foyerCard(theme)
        }.buttonStyle(.plain)
    }
    private func load() async {
        guard let d = try? await NativeHouseAPI.object("/api/ob/api/bucket/\(item.id)") else { return }
        detail = d; let m = d.object("metadata")
        name = m.string("name", "title"); content = d.string("content"); tags = (m["tags"] as? [String] ?? []).joined(separator: ", "); domains = (m["domain"] as? [String] ?? []).joined(separator: ", "); why = m.string("why_remembered"); importance = Double(m.int("importance"))
    }
    private func save() async {
        saving = true
        let split: (String) -> [String] = { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        _ = try? await NativeHouseAPI.request("/api/ob/api/bucket/\(item.id)/edit", method: "PATCH", body: ["name": name, "content": content, "tags": split(tags), "domain": split(domains), "why_remembered": why, "importance": Int(importance)])
        await didChange(); saving = false; dismiss()
    }
}

private struct OBLetter: Identifiable {
    let id, author, userName, title, date, content: String
    init(_ r: [String: Any]) { id=r.string("id"); author=r.string("author"); userName=r.string("user_name"); title=r.string("title"); date=r.string("date"); content=r.string("content") }
}

private struct NativeOBLettersView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var letters: [OBLetter] = []; @State private var filter = ""; @State private var editing: OBLetter?
    private var theme: AlcoveTheme { .panelNamed(themeName) }
    private var shown: [OBLetter] { filter.isEmpty ? letters : letters.filter { $0.author == filter || (filter == "user" && $0.author == "user") } }
    var body: some View {
        VStack(spacing: 10) {
            FoyerPanelTitle(title: "Letters", theme: theme)
            HStack { filterButton("全部", ""); filterButton("陈霁", "user"); filterButton("陈璟", "陈璟"); Spacer(); Button { editing = OBLetter([:]) } label: { Image(systemName: "square.and.pencil") } }
            ScrollView { LazyVStack(spacing: 12) { ForEach(shown) { l in Button { editing=l } label: { letterCard(l) }.buttonStyle(.plain) } }.padding(.bottom,18) }.refreshable { await load() }
        }.padding(.horizontal,16).padding(.bottom,18).foregroundColor(theme.text).foyerPanel(theme).padding(.horizontal,12).padding(.top,8)
        .task { await load() }.sheet(item:$editing) { l in OBLetterEditor(letter:l) { await load() } }
    }
    private func filterButton(_ title:String,_ value:String)->some View { Button(title){filter=value}.font(.system(size:11)).padding(.horizontal,12).frame(height:30).background(filter==value ? theme.fyAccentSoft:theme.fyCard,in:Capsule()) }
    private func letterCard(_ l:OBLetter)->some View { VStack(alignment:.leading,spacing:9){HStack{Label(l.author == "user" ? (l.userName.isEmpty ? "陈霁":l.userName):l.author,systemImage:"envelope").font(.system(size:11,weight:.semibold));Spacer();Text(l.date).font(.system(size:10,design:.monospaced)).foregroundColor(theme.textDim)}; if !l.title.isEmpty {Text(l.title).font(.system(size:17,weight:.semibold,design:.serif))};Text(l.content).font(.system(size:12)).lineSpacing(3).foregroundColor(theme.textDim).lineLimit(6)}.padding(16).frame(maxWidth:.infinity,alignment:.leading).foyerCard(theme) }
    private func load() async { letters = (try? await NativeHouseAPI.array("/api/ob/api/letters",key:"letters"))?.map(OBLetter.init) ?? [] }
}

private struct OBLetterEditor: View {
    let letter:OBLetter; let didChange:() async->Void; @Environment(\.dismiss) private var dismiss
    @State private var author = ""
    @State private var userName = ""
    @State private var title = ""
    @State private var date = ""
    @State private var content = ""
    @AppStorage("alcoveTheme") private var themeName="haven"
    private var theme:AlcoveTheme{.panelNamed(themeName)}
    var body:some View{NavigationStack{Form{Picker("署名",selection:$author){Text("陈霁").tag("user");Text("陈璟").tag("陈璟")};TextField("显示名字",text:$userName);TextField("标题",text:$title);TextField("日期",text:$date);TextEditor(text:$content).frame(minHeight:260);if !letter.id.isEmpty{Button("删除到档案",role:.destructive){Task{_ = try? await NativeHouseAPI.request("/api/ob/api/letter/\(letter.id)?confirm=true",method:"DELETE");await didChange();dismiss()}}}}.scrollContentBackground(.hidden).background(theme.fyCardSub).navigationTitle(letter.id.isEmpty ? "写信":"编辑信").toolbar{ToolbarItem(placement:.cancellationAction){Button("关闭"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("保存"){Task{await save()}}}}.onAppear{author=letter.author.isEmpty ? "user":letter.author;userName=letter.userName;title=letter.title;date=letter.date;content=letter.content}}}
    private func save()async{let body:[String:Any]=["author":author,"user_name":userName,"title":title,"date":date,"content":content];if letter.id.isEmpty{_ = try? await NativeHouseAPI.request("/api/ob/api/letter",method:"POST",body:body)}else{_ = try? await NativeHouseAPI.request("/api/ob/api/letter/\(letter.id)",method:"PATCH",body:body)};await didChange();dismiss()}
}

private struct OBSelfEntry:Identifiable{let id,content,aspect,created:String;init(_ r:[String:Any]){id=r.string("id");content=r.string("content");aspect=r.string("aspect");created=r.string("created")}}
private struct NativeOBSelfView:View{
    @AppStorage("alcoveTheme") private var themeName="haven";@State private var entries:[OBSelfEntry]=[];@State private var aspect=""
    private var theme:AlcoveTheme{.panelNamed(themeName)};private let aspects=["","nature","values","patterns","limits","becoming","uncertainty","stance"]
    private var shown:[OBSelfEntry]{aspect.isEmpty ? entries:entries.filter{$0.aspect==aspect}}
    var body:some View{VStack(spacing:10){FoyerPanelTitle(title:"Self",theme:theme);ScrollView(.horizontal,showsIndicators:false){HStack(spacing:7){ForEach(aspects,id:\.self){a in Button(a.isEmpty ? "全部":a){aspect=a}.font(.system(size:11,design:.monospaced)).padding(.horizontal,11).frame(height:30).background(aspect==a ? theme.fyAccentSoft:theme.fyCard,in:Capsule())}}};ScrollView{LazyVStack(spacing:10){ForEach(shown){e in VStack(alignment:.leading,spacing:8){HStack{Text(e.aspect).font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundColor(theme.fyAccent);Spacer();Text(e.created.prefix(16).replacingOccurrences(of:"T",with:" ")).font(.system(size:9,design:.monospaced)).foregroundColor(theme.textDim)};Text(e.content).font(.system(size:13,design:.serif)).lineSpacing(4)}.padding(15).frame(maxWidth:.infinity,alignment:.leading).foyerCard(theme)}}.padding(.bottom,18)}}.padding(.horizontal,16).padding(.bottom,18).foregroundColor(theme.text).foyerPanel(theme).padding(.horizontal,12).padding(.top,8).task{entries=(try? await NativeHouseAPI.array("/api/ob/api/self"))?.map(OBSelfEntry.init) ?? []}}
}
