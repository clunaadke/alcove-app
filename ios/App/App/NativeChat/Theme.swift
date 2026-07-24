import SwiftUI

// PWA 主题引擎的原生对照表：haven（粉白）/ midnight（黑夜）
// 主题名同步自 PWA localStorage 'alcove-theme'，她在设置里切，这边跟着变
struct AlcoveTheme {
    let isDark: Bool
    let usesWallImage: Bool      // haven 铺 chat-bg.png；midnight 用深色渐变
    let wallGradient: [Color]
    let bubbleUser: Color
    let bubbleAI: Color
    let text: Color
    let textDim: Color
    let textLight: Color
    let timestamp: Color
    let glassTint: Color
    let glassBorder: Color
    let capsuleTint: Color
    let capsuleBorder: Color
    let sendTop: Color
    let sendBottom: Color
    let fade: Color              // 上下渐隐的底色
    // 开屏
    let splashBg: [Color]
    let splashBarTop: Color
    let splashBarBottom: Color
    let splashGlowA: Color
    let splashGlowB: Color
    let splashPetal: Color
    let splashTitle: Color
    // Foyer 暖纸系 — 同步 PWA --fy-* 变量
    let fyAccent: Color
    let fyAccentSoft: Color
    let fyCard: Color
    let fyCardSub: Color
    let fyBorder: Color
    let fyShadow: Color
    let fyFold: Color
    let fyDash: Color

    static let haven = AlcoveTheme(
        isDark: false,
        usesWallImage: true,
        wallGradient: [],
        bubbleUser: Color(red: 247/255, green: 227/255, blue: 234/255).opacity(0.44),
        bubbleAI: Color.white.opacity(0.38),
        text: Color(red: 0.22, green: 0.20, blue: 0.21),
        textDim: Color(red: 0.42, green: 0.40, blue: 0.41),
        textLight: Color(red: 0.62, green: 0.58, blue: 0.60),
        timestamp: Color(red: 0.2, green: 0.2, blue: 0.2),
        glassTint: Color.white.opacity(0.45),
        glassBorder: Color(red: 210/255, green: 210/255, blue: 218/255).opacity(0.22),
        capsuleTint: Color.white.opacity(0.92),
        capsuleBorder: Color.clear,
        sendTop: Color(red: 200/255, green: 120/255, blue: 148/255),
        sendBottom: Color(red: 175/255, green: 95/255, blue: 125/255),
        fade: Color.white,
        splashBg: [Color(red: 253/255, green: 250/255, blue: 251/255),
                   Color(red: 251/255, green: 243/255, blue: 246/255),
                   Color(red: 248/255, green: 237/255, blue: 241/255)],
        splashBarTop: Color(red: 228/255, green: 170/255, blue: 187/255),
        splashBarBottom: Color(red: 207/255, green: 148/255, blue: 166/255),
        splashGlowA: Color(red: 238/255, green: 190/255, blue: 205/255).opacity(0.40),
        splashGlowB: Color(red: 244/255, green: 214/255, blue: 224/255).opacity(0.34),
        splashPetal: Color(red: 238/255, green: 198/255, blue: 210/255),
        splashTitle: Color(red: 207/255, green: 148/255, blue: 166/255),
        fyAccent: Color(red: 207/255, green: 148/255, blue: 166/255),
        fyAccentSoft: Color(red: 223/255, green: 178/255, blue: 192/255).opacity(0.5),
        fyCard: Color.white.opacity(0.94),
        fyCardSub: Color.white.opacity(0.9),
        fyBorder: Color(red: 198/255, green: 198/255, blue: 210/255).opacity(0.40),
        fyShadow: Color(red: 140/255, green: 140/255, blue: 160/255).opacity(0.10),
        fyFold: Color(red: 233/255, green: 201/255, blue: 212/255).opacity(0.65),
        fyDash: Color(red: 210/255, green: 190/255, blue: 197/255).opacity(0.45))

    static let midnight = AlcoveTheme(
        isDark: true,
        usesWallImage: false,
        wallGradient: [Color(red: 28/255, green: 28/255, blue: 32/255),
                       Color(red: 23/255, green: 23/255, blue: 27/255),
                       Color(red: 19/255, green: 19/255, blue: 21/255),
                       Color(red: 16/255, green: 16/255, blue: 18/255)],
        bubbleUser: Color(red: 52/255, green: 52/255, blue: 62/255).opacity(0.82),
        bubbleAI: Color(red: 36/255, green: 36/255, blue: 44/255).opacity(0.82),
        text: Color(red: 216/255, green: 216/255, blue: 222/255),
        textDim: Color(red: 190/255, green: 190/255, blue: 200/255),
        textLight: Color(red: 150/255, green: 150/255, blue: 164/255),
        timestamp: Color(red: 200/255, green: 200/255, blue: 210/255),
        glassTint: Color(red: 26/255, green: 26/255, blue: 32/255).opacity(0.68),
        glassBorder: Color(red: 80/255, green: 80/255, blue: 95/255).opacity(0.22),
        capsuleTint: Color(red: 32/255, green: 32/255, blue: 40/255).opacity(0.5),
        capsuleBorder: Color(red: 80/255, green: 80/255, blue: 95/255).opacity(0.28),
        sendTop: Color(red: 136/255, green: 136/255, blue: 154/255),
        sendBottom: Color(red: 136/255, green: 136/255, blue: 154/255),
        fade: Color(red: 20/255, green: 20/255, blue: 24/255),
        splashBg: [Color(red: 29/255, green: 29/255, blue: 33/255),
                   Color(red: 25/255, green: 25/255, blue: 29/255),
                   Color(red: 22/255, green: 22/255, blue: 26/255)],
        splashBarTop: Color(red: 151/255, green: 113/255, blue: 127/255),
        splashBarBottom: Color(red: 125/255, green: 95/255, blue: 107/255),
        splashGlowA: Color(red: 160/255, green: 125/255, blue: 138/255).opacity(0.16),
        splashGlowB: Color(red: 140/255, green: 110/255, blue: 122/255).opacity(0.13),
        splashPetal: Color(red: 74/255, green: 62/255, blue: 68/255),
        splashTitle: Color(red: 151/255, green: 113/255, blue: 127/255),
        fyAccent: Color(red: 160/255, green: 125/255, blue: 138/255),
        fyAccentSoft: Color(red: 140/255, green: 105/255, blue: 118/255).opacity(0.45),
        fyCard: Color(red: 36/255, green: 36/255, blue: 44/255).opacity(0.88),
        fyCardSub: Color(red: 42/255, green: 42/255, blue: 52/255).opacity(0.85),
        fyBorder: Color(red: 105/255, green: 105/255, blue: 122/255).opacity(0.30),
        fyShadow: Color.black.opacity(0.35),
        fyFold: Color(red: 120/255, green: 90/255, blue: 102/255).opacity(0.45),
        fyDash: Color(red: 120/255, green: 105/255, blue: 112/255).opacity(0.4))

    static func named(_ name: String) -> AlcoveTheme {
        name == "midnight" ? .midnight : .haven
    }
}
