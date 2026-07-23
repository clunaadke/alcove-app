import SwiftUI

// 顶栏按钮的去向，与 PWA 一一对应
enum HouseTarget: String, Identifiable {
    case sidebar, checklist, music, term
    var id: String { rawValue }
    var js: String {
        switch self {
        case .sidebar: return "toggleSidebar()" // 壁龛抽屉：大厅/Settings/FOYER/PLAY 全在里面
        case .checklist: return "switchPage('chat'); ckToggle();"
        case .music: return "openMusicPanel()"
        case .term: return "switchPage('term')"
        }
    }
}

// App 根视图：原生聊天页 + PWA 同款顶栏，按钮直达原页面功能
struct RootView: View {
    @State private var housePage: HouseTarget?
    @State private var showSplash = true
    @State private var showPermissions = false
    @State private var showTerminal = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("assistantName") private var assistantName = "陈璟"
    @AppStorage("assistantAvatarDataURL") private var avatarDataURL = ""
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }

    private var avatarImage: UIImage? {
        guard !avatarDataURL.isEmpty else { return nil }
        let b64 = avatarDataURL.contains(",")
            ? String(avatarDataURL.split(separator: ",", maxSplits: 1)[1])
            : avatarDataURL
        guard let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    private var glassStroke: Color { theme.glassBorder }
    private var textDim: Color { theme.textDim }

    var body: some View {
        ZStack(alignment: .top) {
            ChatView()
            topBar
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            WebHouse.shared.warmUp() // 后台先把小屋加载好，按钮秒开
            // 声波念完两个音节再进门，跟 PWA 一个节奏
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
        .preferredColorScheme(theme.isDark ? .dark : .light) // 跟 PWA 主题走，不跟系统
        .onChange(of: scenePhase) { phase in
            if phase == .active { SensorReporter.shared.appActive() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alcoveShowPermissions)) { _ in
            housePage = nil // 收起设置 WebView 再弹原生权限页
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showPermissions = true }
        }
        .sheet(isPresented: $showPermissions) {
            PermissionsView()
        }
        .fullScreenCover(isPresented: $showTerminal) {
            TerminalView()
        }
        .fullScreenCover(item: $housePage) { target in
            HousePage(js: target.js) {
                housePage = nil
                WebHouse.shared.syncProfile() // 她可能刚改了名字、头像或主题
            }
            .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .tint(Color(red: 0.86, green: 0.44, blue: 0.57))
    }

    // PWA .chat-topbar 同款：左<钮 + 居中 pill + 清单/音乐圆钮 + 头像
    private var topBar: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(assistantName)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.text)
                Text("a word")
                    .font(.system(size: 11))
                    .foregroundColor(textDim)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .background(theme.glassTint, in: Capsule())
            .overlay(Capsule().stroke(glassStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

            HStack(spacing: 8) {
                Button { housePage = .sidebar } label: {
                    glassCircle(size: 44) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textDim)
                    }
                }
                Spacer()
                Button { housePage = .checklist } label: {
                    glassCircle(size: 36) {
                        Image(systemName: "checklist")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(textDim)
                    }
                }
                Button { housePage = .music } label: {
                    glassCircle(size: 36) {
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(textDim)
                    }
                }
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
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
