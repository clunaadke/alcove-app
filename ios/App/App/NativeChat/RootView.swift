import SwiftUI
import UIKit

private struct DrawerBackdropBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialLight))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// App 根视图：原生聊天页 + 原生小屋页面。
struct RootView: View {
    @State private var housePage: HouseDestination?
    @State private var showHouseDrawer = false
    @State private var showSplash = true
    @State private var showPermissions = false
    @State private var showTerminal = false
    @State private var showRoundtable = false   // 0731 圆桌：她要全屏，所以不走面板那条 sheet
    @State private var roundtableUnread = 0
    @State private var latestRoundtableID = 0
    @State private var thinkingEnabled = false
    @State private var thinkingKnown = false
    @State private var switchingThinking = false
    @AppStorage("roundtableLastReadID") private var roundtableLastReadID = 0
    @AppStorage("roundtableReadInitialized") private var roundtableReadInitialized = false
    @State private var preparedPanelTexture: UIImage?
    @State private var preparedPanelTextureName = ""
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("assistantName") private var assistantName = "陈璟"
    @AppStorage("assistantAvatarDataURL") private var avatarDataURL = ""
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    private var avatarImage: UIImage? {
        guard !avatarDataURL.isEmpty else { return nil }
        let parts = avatarDataURL.split(separator: ",", maxSplits: 1)
        let b64 = parts.count == 2 ? String(parts[1]) : avatarDataURL
        guard let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    private var glassStroke: Color { theme.glassBorder }
    private var textDim: Color { theme.textDim }

    var body: some View {
        ZStack(alignment: .top) {
            ChatView()
            topBar
            if showTerminal {
                ZStack {
                    Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea()
                    TerminalView(onDismiss: {
                        withAnimation(.easeOut(duration: 0.15)) { showTerminal = false }
                    })
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(20)
            }
            if showRoundtable {
                RoundtableView(onDismiss: {
                    markRoundtableRead()
                    withAnimation(.easeOut(duration: 0.15)) { showRoundtable = false }
                })
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(21)
            }
            if showHouseDrawer {
                ZStack {
                    DrawerBackdropBlur()
                        .opacity(0.92)
                }
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.22)) { showHouseDrawer = false } }
                    .transition(.opacity)
                    .zIndex(18)
                GeometryReader { drawerGeo in
                    let drawerWidth = drawerGeo.size.width * 0.80
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: drawerGeo.size.width - drawerWidth)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.22)) { showHouseDrawer = false }
                            }
                        NativeHouseDrawer(
                            drawerWidth: drawerWidth,
                            onClose: { withAnimation(.easeOut(duration: 0.22)) { showHouseDrawer = false } },
                            select: openFromDrawer,
                            roundtableUnread: roundtableUnread
                        )
                        .frame(width: drawerWidth, height: drawerGeo.size.height)
                    }
                }
                .ignoresSafeArea(.container, edges: .all)
                .transition(.move(edge: .trailing))
                .zIndex(19)
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .blur(radius: housePage == nil || theme.isPaper ? 0 : 2.2)
        .animation(.easeOut(duration: 0.20), value: housePage != nil)
        .onAppear {
            prewarmPanelTexture()
            Task { await refreshThinkingState() }
            // 声波念完两个音节再进门，跟 PWA 一个节奏
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
        .task {
            while !Task.isCancelled {
                await refreshRoundtableUnread()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        .onChange(of: themeName) { _ in prewarmPanelTexture() }
        .preferredColorScheme(theme.isDark ? .dark : .light) // 跟 PWA 主题走，不跟系统
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                SensorReporter.shared.appActive()
                Task { await refreshThinkingState() }
            }
            else { SensorReporter.shared.appBackground() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alcoveShowPermissions)) { _ in
            housePage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showPermissions = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alcoveJumpToMessage)) { _ in
            housePage = nil
        }
        .sheet(isPresented: $showPermissions) {
            PermissionsView()
        }
        .fullScreenCover(item: $housePage) { target in
            NativeHouseSheet(
                initial: target,
                preparedTexture: preparedPanelTexture,
                preparedTextureName: preparedPanelTextureName,
                showTerminal: { showTerminal = true },
                showRoundtable: { markRoundtableRead(); showRoundtable = true },
                roundtableUnread: roundtableUnread
            )
        }
        .tint(Color(red: 0.86, green: 0.44, blue: 0.57))
    }

    private func refreshRoundtableUnread() async {
        guard let obj = try? await AlcoveAPI.getRaw("/api/roundtable/poll") else { return }
        let records = obj["records"] as? [[String: Any]] ?? []
        let newest = records.compactMap { $0["id"] as? Int }.max() ?? 0
        latestRoundtableID = newest
        if !roundtableReadInitialized {
            roundtableLastReadID = newest
            roundtableReadInitialized = true
            roundtableUnread = 0
            return
        }
        if showRoundtable {
            roundtableLastReadID = newest
            roundtableUnread = 0
        } else {
            roundtableUnread = records.reduce(into: 0) { count, record in
                guard let id = record["id"] as? Int, id > roundtableLastReadID else { return }
                count += 1
            }
        }
    }

    private func markRoundtableRead() {
        roundtableLastReadID = max(roundtableLastReadID, latestRoundtableID)
        roundtableUnread = 0
    }

    // 左头像｜中间纯文字｜右侧三枚按钮共用一块清透玻璃胶囊
    private var topBar: some View {
        ZStack {
            VStack(spacing: -1) {
                Text(assistantName)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.text)
                Button { toggleThinking() } label: {
                    HStack(spacing: 4) {
                        Text("thinking quietly")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textDim)
                        if switchingThinking {
                            ProgressView().controlSize(.mini).scaleEffect(0.72)
                                .frame(width: 24, height: 18)
                        } else {
                            Capsule()
                                .fill(thinkingEnabled ? theme.text.opacity(theme.isDark ? 0.78 : 0.58)
                                                      : textDim.opacity(0.22))
                                .frame(width: 24, height: 14)
                                .overlay(alignment: thinkingEnabled ? .trailing : .leading) {
                                    Circle().fill(.white).frame(width: 10, height: 10).padding(2)
                                }
                                .opacity(thinkingKnown ? 1 : 0.45)
                                .animation(.spring(response: 0.24, dampingFraction: 0.8),
                                           value: thinkingEnabled)
                        }
                    }
                    .frame(minHeight: 25)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(switchingThinking || !thinkingKnown)
            }
            .frame(height: 44, alignment: .center)
            // The full-width left/right control row is drawn after this view.
            // Keep the center button above its transparent Spacer so taps
            // reach the thinking switch instead of being swallowed.
            .zIndex(2)

            HStack(alignment: .center, spacing: 0) {
                Button { showTerminal = true } label: {
                    glassCircle(size: 40) {
                        if let img = avatarImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Text("R")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(textDim)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 0) {
                    topBarControl("music.note", size: 14) {
                        presentHouse(.music)
                    }
                    topBarControl("checklist", size: 13) {
                        presentHouse(.checklist)
                    }
                    topBarControl("line.3.horizontal", size: 15) {
                        presentHouse(.sidebar)
                    }
                }
                .padding(.horizontal, 2)
                .frame(height: 40)
                .modifier(InteractiveTopBarGlassModifier(
                    fallbackTint: theme.capsuleTint,
                    fallbackBorder: glassStroke
                ))
                .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 2)
                .frame(height: 44)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
    }

    private func refreshThinkingState() async {
        if let screen = try? await AlcoveAPI.terminalCapture(lines: 12),
           let enabled = thinkingState(in: screen) {
            thinkingEnabled = enabled
            thinkingKnown = true
        }
    }

    private func thinkingState(in screen: String) -> Bool? {
        if screen.contains("thinking:on") { return true }
        if screen.contains("thinking:off") { return false }
        return nil
    }

    private func toggleThinking() {
        guard thinkingKnown, !switchingThinking else { return }
        switchingThinking = true
        let oldValue = thinkingEnabled
        Task {
            defer { switchingThinking = false }
            guard let live = try? await AlcoveAPI.liveStream(), !live.active,
                  let screen = try? await AlcoveAPI.terminalCapture() else { return }
            let tail = screen.components(separatedBy: .newlines).suffix(12).joined(separator: "\n")
            guard tail.contains("❯") && !tail.localizedCaseInsensitiveContains("esc to interrupt") else { return }
            do {
                try await AlcoveAPI.terminalSendKey("M-t")
                try? await Task.sleep(nanoseconds: 350_000_000)
                // The picker focuses the current value: Enabled is row one,
                // Disabled row two. Move once toward the requested value.
                try await AlcoveAPI.terminalSendKey(oldValue ? "Down" : "Up")
                try await AlcoveAPI.terminalSendKey("Enter")
                // Mid-conversation changes add a second confirmation screen.
                // Wait for it instead of assuming the terminal renders instantly.
                for _ in 0..<6 {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    if let confirm = try? await AlcoveAPI.terminalCapture(lines: 20),
                       confirm.contains("Do you want to proceed?") {
                        try await AlcoveAPI.terminalSendKey("Enter")
                        break
                    }
                }
            } catch { return }
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 600_000_000)
                if let screen = try? await AlcoveAPI.terminalCapture(lines: 12),
                   let current = thinkingState(in: screen), current != oldValue {
                    thinkingEnabled = current
                    return
                }
            }
        }
    }

    private func topBarControl(
        _ systemName: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .light))
                .foregroundColor(textDim)
                .frame(width: 36, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openFromDrawer(_ target: HouseDestination) {
        switch target {
        case .chat:
            withAnimation(.easeOut(duration: 0.2)) { showHouseDrawer = false }
        case .terminal: showTerminal = true
        case .roundtable: markRoundtableRead(); showRoundtable = true
        default:
            presentHouse(target)
        }
    }

    private func presentHouse(_ target: HouseDestination) {
        if target == .sidebar {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) { showHouseDrawer = true }
            return
        }
        let asset = AlcoveTheme.panelNamed(themeName).panelTextureAsset

        if preparedPanelTextureName == asset, preparedPanelTexture != nil {
            housePage = target
            return
        }

        preparePanelTexture(named: asset) { image in
            guard AlcoveTheme.panelNamed(themeName).panelTextureAsset == asset else { return }
            preparedPanelTexture = image
            preparedPanelTextureName = asset
            housePage = target
        }
    }

    private func prewarmPanelTexture() {
        let asset = AlcoveTheme.panelNamed(themeName).panelTextureAsset
        guard preparedPanelTextureName != asset || preparedPanelTexture == nil else { return }

        preparePanelTexture(named: asset) { image in
            guard AlcoveTheme.panelNamed(themeName).panelTextureAsset == asset else { return }
            preparedPanelTexture = image
            preparedPanelTextureName = asset
        }
    }

    private func preparePanelTexture(
        named asset: String,
        completion: @escaping (UIImage?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = UIImage(named: asset)?.preparingForDisplay()
            DispatchQueue.main.async {
                completion(prepared)
            }
        }
    }

    private func glassCircle<Content: View>(size: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack { content() }
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .background(theme.glassTint, in: Circle())
            .overlay(Circle().stroke(glassStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .contentShape(Circle())
    }
}

private struct InteractiveTopBarGlassModifier: ViewModifier {
    let fallbackTint: Color
    let fallbackBorder: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule()
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(fallbackTint).interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(fallbackTint, in: shape)
                .overlay(shape.stroke(fallbackBorder, lineWidth: 1))
        }
    }
}
