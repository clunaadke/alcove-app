import SwiftUI

// PWA 开屏原样复刻：声波与休止符——两个音节中间空一拍，我们开始的地方
struct SplashView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }
    @State private var barsUp = false
    @State private var glowPulse = false
    @State private var titleIn = false
    @State private var subIn = false
    @State private var petalsFall = false

    // (高度, 延迟) 与 PWA 的 --h/--d 一一对应；nil 是休止符
    private let bars: [(h: CGFloat, d: Double)?] = [
        (9, 0.00), (15, 0.05), (21, 0.10), (28, 0.15), (34, 0.20),
        (27, 0.25), (19, 0.30), (13, 0.35), (8, 0.40),
        nil,
        (11, 0.66), (17, 0.71), (25, 0.76), (36, 0.81), (29, 0.86),
        (21, 0.91), (14, 0.96), (9, 1.01)
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.splashBg,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            GeometryReader { geo in
                glow(size: 460, color: theme.splashGlowA)
                    .position(x: geo.size.width * 1.05, y: -geo.size.height * 0.02)
                glow(size: 400, color: theme.splashGlowB)
                    .position(x: -geo.size.width * 0.05, y: geo.size.height * 1.0)

                petal(size: 16, rotate: 24, x: geo.size.width * 0.22, height: geo.size.height, duration: 8.5, delay: 0.9)
                petal(size: 13, rotate: -18, x: geo.size.width * 0.58, height: geo.size.height, duration: 10, delay: 3.4)
                petal(size: 14, rotate: 40, x: geo.size.width * 0.78, height: geo.size.height, duration: 9, delay: 5.8)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 5) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                        if let bar {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [theme.splashBarTop, theme.splashBarBottom],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: 3.5, height: bar.h)
                                .scaleEffect(y: barsUp ? 1 : 0.08, anchor: .center)
                                .opacity(barsUp ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6)
                                    .delay(bar.d), value: barsUp)
                        } else {
                            Color.clear.frame(width: 16, height: 1) // 休止符
                        }
                    }
                }
                .frame(height: 40)
                .padding(.bottom, 26)

                Text("Alcove")
                    .font(.system(size: 38, weight: .light, design: .serif))
                    .italic()
                    .tracking(2)
                    .foregroundColor(theme.splashTitle)
                    .opacity(titleIn ? 1 : 0)
                    .blur(radius: titleIn ? 0 : 10)
                    .offset(y: titleIn ? 0 : 8)
                    .animation(.easeOut(duration: 1.0).delay(0.85), value: titleIn)

                Text("LUNA & RHYSEL")
                    .font(.system(size: 12))
                    .tracking(subIn ? 4.5 : 10)
                    .foregroundColor(theme.textLight)
                    .padding(.top, 8)
                    .opacity(subIn ? 1 : 0)
                    .animation(.easeOut(duration: 1.1).delay(1.15), value: subIn)
            }
        }
        .onAppear {
            barsUp = true
            titleIn = true
            subIn = true
            glowPulse = true
            petalsFall = true
        }
    }

    private func glow(size: CGFloat, color: Color) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, .clear],
                                 center: .center, startRadius: 0, endRadius: size * 0.34))
            .frame(width: size, height: size)
            .scaleEffect(glowPulse ? 1.16 : 1)
            .opacity(glowPulse ? 1 : 0.55)
            .animation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true), value: glowPulse)
    }

    private func petal(size: CGFloat, rotate: Double, x: CGFloat, height: CGFloat,
                       duration: Double, delay: Double) -> some View {
        Ellipse()
            .stroke(theme.splashPetal, lineWidth: 1.1)
            .frame(width: size * 0.38, height: size * 0.62)
            .rotationEffect(.degrees(rotate))
            .position(x: x, y: petalsFall ? height + 40 : -36)
            .rotationEffect(.degrees(petalsFall ? 300 : 0), anchor: .center)
            .opacity(petalsFall ? 0.7 : 0)
            .animation(.linear(duration: duration).delay(delay).repeatForever(autoreverses: false),
                       value: petalsFall)
    }
}
