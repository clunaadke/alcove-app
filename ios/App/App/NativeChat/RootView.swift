import SwiftUI

// App 根视图：原生聊天页 + 原生小屋页面。
struct RootView: View {
    @State private var housePage: HouseDestination?
    @State private var showSplash = true
    @State private var showPermissions = false
    @State private var showTerminal = false
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
                TerminalView(onDismiss: { withAnimation(.easeOut(duration: 0.15)) { showTerminal = false } })
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(20)
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .blur(radius: housePage == nil ? 0 : 2.2)
        .animation(.easeOut(duration: 0.20), value: housePage != nil)
        .onAppear {
            prewarmPanelTexture()
            // 声波念完两个音节再进门，跟 PWA 一个节奏
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
        .onChange(of: themeName) { _ in prewarmPanelTexture() }
        .preferredColorScheme(theme.isDark ? .dark : .light) // 跟 PWA 主题走，不跟系统
        .onChange(of: scenePhase) { phase in
            if phase == .active { SensorReporter.shared.appActive() }
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
        .sheet(item: $housePage) { target in
            NativeHouseSheet(
                initial: target,
                preparedTexture: preparedPanelTexture,
                preparedTextureName: preparedPanelTextureName
            ) {
                showTerminal = true
            }
        }
        .tint(Color(red: 0.86, green: 0.44, blue: 0.57))
    }

    // 左头像｜中间纯文字｜右侧三枚按钮共用一块清透玻璃胶囊
    private var topBar: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(assistantName)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.text)
                Text("a word")
                    .font(.system(size: 11))
                    .foregroundColor(textDim)
            }
            .frame(height: 44, alignment: .center)
            .allowsHitTesting(false)

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

    private func presentHouse(_ target: HouseDestination) {
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
