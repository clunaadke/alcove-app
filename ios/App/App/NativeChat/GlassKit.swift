import SwiftUI

// 冷蓝玻璃（2026-08-18 檐下先用上，0819 她要搜索和收藏也照这套做）。
//
// 皮的来源是她给的四张参考图（Sui-IB/InternalBeyond-Mobile）：磨砂玻璃、
// 强噪点、光从下面照上来、衬线正文＋等宽元信息。
// 这套配色不进主题引擎，只给用它的那几页；深浅跟着 alcoveTheme 的 isDark 走。
//
// 用它的页面都自己铺满、自己做头——她0819 明说了不要透壁纸、要全屏。

struct GlassPalette {
    let isDark: Bool
    let ink: Color          // 正文
    let ink2: Color         // 次要
    let ink3: Color         // 三级/元信息
    let acc: Color          // 强调蓝
    let gold: Color         // 收了尾的那个金
    let glass: Color        // 玻璃填充
    let line: Color         // 玻璃描边（内高光）
    let bgTop: Color
    let bgMid: Color
    let bgBottom: Color
    let glow: Color         // 底部那团光

    static func named(_ themeName: String) -> GlassPalette {
        AlcoveTheme.named(themeName).isDark ? .dark : .light
    }

    static let light = GlassPalette(
        isDark: false,
        ink: Color(red: 0x0A/255, green: 0x1E/255, blue: 0x42/255),
        ink2: Color(red: 0x3D/255, green: 0x57/255, blue: 0x88/255),
        ink3: Color(red: 0x7D/255, green: 0x92/255, blue: 0xB5/255),
        acc: Color(red: 0x2A/255, green: 0x6B/255, blue: 0xB0/255),
        gold: Color(red: 0xC9/255, green: 0xA8/255, blue: 0x6A/255),
        glass: Color.white.opacity(0.40),
        line: Color.white.opacity(0.74),
        bgTop: Color(red: 0xFA/255, green: 0xFC/255, blue: 0xFE/255),
        bgMid: Color(red: 0xEC/255, green: 0xF1/255, blue: 0xF7/255),
        bgBottom: Color(red: 0xCF/255, green: 0xDA/255, blue: 0xE8/255),
        glow: Color(red: 0x9E/255, green: 0xC2/255, blue: 0xEC/255).opacity(0.42))

    static let dark = GlassPalette(
        isDark: true,
        ink: Color(red: 0xE0/255, green: 0xE6/255, blue: 0xF2/255),
        ink2: Color(red: 0xAD/255, green: 0xB8/255, blue: 0xD0/255),
        ink3: Color(red: 0x7E/255, green: 0x90/255, blue: 0xB2/255),
        acc: Color(red: 0x72/255, green: 0xA8/255, blue: 0xD8/255),
        gold: Color(red: 0xD0/255, green: 0xA4/255, blue: 0x4E/255),
        glass: Color(red: 20/255, green: 28/255, blue: 52/255).opacity(0.46),
        line: Color(red: 165/255, green: 188/255, blue: 230/255).opacity(0.26),
        bgTop: Color(red: 0x4A/255, green: 0x4E/255, blue: 0x56/255),
        bgMid: Color(red: 0x1A/255, green: 0x1D/255, blue: 0x24/255),
        bgBottom: Color(red: 0x12/255, green: 0x1B/255, blue: 0x33/255),
        glow: Color(red: 0x1E/255, green: 0x5F/255, blue: 0xD0/255).opacity(0.55))
}

// MARK: - 噪点（参考图那层胶片颗粒，把渐变的台阶打碎）

struct GlassGrain: View {
    var opacity: Double = 0.055
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 1000) / 1000.0
            }
            let step: CGFloat = 2
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let v = next()
                    if v > 0.55 {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: step, height: step)),
                            with: .color(.white.opacity(v * 0.5)))
                    } else if v < 0.16 {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: step, height: step)),
                            with: .color(.black.opacity(0.35)))
                    }
                    x += step
                }
                y += step
            }
        }
        .opacity(opacity)
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// MARK: - 整页背景：光从下面照上来

struct GlassBackdrop: View {
    let palette: GlassPalette
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.bgTop, palette.bgMid, palette.bgBottom],
                startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [palette.glow, .clear],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 10, endRadius: 420)
            GlassGrain(opacity: palette.isDark ? 0.05 : 0.075)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 玻璃卡

struct GlassCard: ViewModifier {
    let palette: GlassPalette
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(palette.glass))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(palette.line, lineWidth: 0.7))
                    .shadow(color: palette.isDark
                            ? Color.black.opacity(0.32)
                            : Color(red: 90/255, green: 120/255, blue: 170/255).opacity(0.14),
                            radius: 12, y: 5))
    }
}

extension View {
    func glassCard(_ palette: GlassPalette, radius: CGFloat = 18) -> some View {
        modifier(GlassCard(palette: palette, radius: radius))
    }
}

// MARK: - 玻璃珠头像（参考图里那颗蓝珠子，纯代码画，不吃图片资源）

struct GlassBead: View {
    let isHers: Bool
    var size: CGFloat = 38

    private var core: Color {
        isHers
            ? Color(red: 0xE8/255, green: 0xC6/255, blue: 0xD2/255)   // 她：暖粉珠
            : Color(red: 0x3C/255, green: 0x74/255, blue: 0xC8/255)   // 我：蓝珠
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [core.opacity(0.30), core, core.opacity(0.72)],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: size * 0.04,
                        endRadius: size * 0.72))
            // 底部反光：光从下面照上来，跟整页光源一致
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(isHers ? 0.55 : 0.42), .clear],
                        center: UnitPoint(x: 0.62, y: 0.86),
                        startRadius: 0,
                        endRadius: size * 0.42))
            Ellipse()
                .fill(Color.white.opacity(0.72))
                .frame(width: size * 0.34, height: size * 0.22)
                .offset(x: -size * 0.13, y: -size * 0.26)
                .blur(radius: size * 0.045)
            Circle().strokeBorder(Color.white.opacity(0.42), lineWidth: 0.6)
        }
        .frame(width: size, height: size)
        .shadow(color: core.opacity(0.35), radius: size * 0.16, y: size * 0.08)
    }
}

// MARK: - 全屏页面的顶栏（她0819：不要透壁纸，要全屏）

struct GlassHeader: View {
    let title: String
    let palette: GlassPalette
    var onBack: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .light))
                    .foregroundColor(palette.ink2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            Spacer()
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .tracking(7)
                .foregroundColor(palette.ink)
                .padding(.leading, 7)   // 抵掉字距在右边多出来的那一格
            Spacer()
            if let trailing {
                trailing.frame(width: 44, height: 44)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 54)
    }
}

// MARK: - 筛选胶囊（搜索框下面那排选项）

struct GlassChips<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    let palette: GlassPalette
    var onPick: (T) -> Void = { _ in }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(options, id: \.0) { value, label in
                    let on = selection == value
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) { selection = value }
                        onPick(value)
                    } label: {
                        Text(label)
                            .font(.system(size: 12.5, weight: on ? .semibold : .regular,
                                          design: .serif))
                            .tracking(1.2)
                            .foregroundColor(on ? palette.ink : palette.ink3)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(on ? palette.glass : Color.clear)
                                    .overlay(Capsule().strokeBorder(
                                        on ? palette.line : Color.clear, lineWidth: 0.7)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
