import SwiftUI

// App 根视图：原生聊天页 + PWA 同款顶栏，其余页面 WebView 兜底
struct RootView: View {
    @State private var showHouse = false
    @State private var showSplash = true
    @AppStorage("assistantName") private var assistantName = "陈璟"

    private let glassStroke = Color(red: 210/255, green: 210/255, blue: 218/255).opacity(0.22)
    private let textDim = Color(red: 0.42, green: 0.40, blue: 0.41)

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
            // 声波念完两个音节再进门，跟 PWA 一个节奏
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
        .preferredColorScheme(.light) // PWA 是固定浅色主题，材质不许跟系统变黑
        .fullScreenCover(isPresented: $showHouse) {
            NavigationStack {
                WebViewPage(url: AlcoveAPI.base)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("小屋")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("返回聊天") { showHouse = false }
                        }
                    }
            }
            .preferredColorScheme(.light)
        }
        .tint(Color(red: 0.86, green: 0.44, blue: 0.57))
    }

    // PWA .chat-topbar 同款：居中 pill + 右侧圆钮和头像
    private var topBar: some View {
        HStack(spacing: 0) {
            glassCircle(size: 32) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textDim)
            }
            .onTapGesture { showHouse = true }

            Spacer()

            VStack(spacing: 0) {
                Text(assistantName)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(Color(red: 0.22, green: 0.20, blue: 0.21))
                Text("a word")
                    .font(.system(size: 11))
                    .foregroundColor(textDim)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.45), in: Capsule())
            .overlay(Capsule().stroke(glassStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

            Spacer()

            HStack(spacing: 8) {
                glassCircle(size: 32) {
                    Image(systemName: "checklist")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(textDim)
                }
                .onTapGesture { showHouse = true }
                glassCircle(size: 32) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(textDim)
                }
                .onTapGesture { showHouse = true }
                glassCircle(size: 36) {
                    Text("R")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(textDim)
                }
                .onTapGesture { showHouse = true }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func glassCircle<Content: View>(size: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack { content() }
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .background(Color.white.opacity(0.4), in: Circle())
            .overlay(Circle().stroke(glassStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .contentShape(Circle())
    }
}
