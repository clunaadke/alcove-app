import SwiftUI

// PWA 主题引擎的原生对照表：haven（粉白）/ rain（暂沿用 haven 聊天）/ midnight（黑夜）
// 主题名同步自 PWA localStorage 'alcove-theme'，她在设置里切，这边跟着变
struct AlcoveTheme {
    let isDark: Bool
    let isPaper: Bool
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
    let panelTextureAsset: String

    static let haven = AlcoveTheme(
        isDark: false,
        isPaper: false,
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
        sendTop: Color(red: 58/255, green: 56/255, blue: 60/255),
        sendBottom: Color(red: 42/255, green: 40/255, blue: 44/255),
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
        fyDash: Color(red: 210/255, green: 190/255, blue: 197/255).opacity(0.45),
        panelTextureAsset: "WetGlassHaven")

    static let midnight = AlcoveTheme(
        isDark: true,
        isPaper: false,
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
        fyDash: Color(red: 120/255, green: 105/255, blue: 112/255).opacity(0.4),
        panelTextureAsset: "WetGlassMidnight")

    static let ice = haven.iceCopy(dark: false)
    static let iceDark = midnight.iceCopy(dark: true)
    static let paper = haven.paperCopy(dark: false)
    static let paperDark = midnight.paperCopy(dark: true)

    static func named(_ name: String) -> AlcoveTheme {
        switch name {
        case "ice": return .ice
        case "ice-dark": return .iceDark
        case "paper": return .paper
        case "paper-dark": return .paperDark
        case "midnight": return .midnight
        default: return .haven
        }
    }

    // 下拉面板拥有独立的湿玻璃配色。rain 的聊天页仍由 named(_:) 返回 haven，
    // 因而新增蓝色选项不会改动聊天气泡、输入框、顶栏或聊天壁纸。
    static func panelNamed(_ name: String) -> AlcoveTheme {
        switch name {
        case "ice": return ice
        case "ice-dark": return iceDark
        case "paper": return paper
        case "paper-dark": return paperDark
        case "midnight":
            return midnight.panelCopy(
                splashBg: [
                    Color(red: 13/255, green: 22/255, blue: 35/255).opacity(0.90),
                    Color(red: 20/255, green: 31/255, blue: 47/255).opacity(0.88),
                    Color(red: 9/255, green: 15/255, blue: 25/255).opacity(0.92)
                ],
                text: Color(red: 232/255, green: 237/255, blue: 244/255),
                textDim: Color(red: 205/255, green: 215/255, blue: 228/255),
                textLight: Color(red: 160/255, green: 174/255, blue: 191/255),
                accent: Color(red: 218/255, green: 227/255, blue: 239/255),
                accentSoft: Color.white.opacity(0.24),
                card: Color(red: 25/255, green: 37/255, blue: 54/255).opacity(0.48),
                cardSub: Color.white.opacity(0.075),
                border: Color.white.opacity(0.30),
                shadow: Color.black.opacity(0.42),
                textureAsset: "WetGlassMidnight"
            )
        case "rain":
            return haven.panelCopy(
                splashBg: [
                    Color(red: 117/255, green: 164/255, blue: 224/255).opacity(0.78),
                    Color(red: 145/255, green: 187/255, blue: 239/255).opacity(0.72),
                    Color(red: 104/255, green: 151/255, blue: 213/255).opacity(0.78)
                ],
                text: Color(red: 10/255, green: 25/255, blue: 67/255),
                textDim: Color(red: 19/255, green: 43/255, blue: 92/255),
                textLight: Color(red: 48/255, green: 76/255, blue: 124/255),
                accent: Color(red: 13/255, green: 39/255, blue: 94/255),
                accentSoft: Color(red: 28/255, green: 73/255, blue: 143/255).opacity(0.42),
                card: Color.white.opacity(0.20),
                cardSub: Color.white.opacity(0.18),
                border: Color.white.opacity(0.53),
                shadow: Color(red: 18/255, green: 54/255, blue: 112/255).opacity(0.20),
                textureAsset: "WetGlassRain"
            )
        default:
            return haven.panelCopy(
                splashBg: [
                    Color.white.opacity(0.78),
                    Color(red: 235/255, green: 237/255, blue: 244/255).opacity(0.72),
                    Color(red: 247/255, green: 244/255, blue: 248/255).opacity(0.76)
                ],
                text: Color(red: 26/255, green: 25/255, blue: 29/255),
                textDim: Color(red: 47/255, green: 48/255, blue: 55/255),
                textLight: Color(red: 91/255, green: 92/255, blue: 101/255),
                accent: Color(red: 159/255, green: 31/255, blue: 82/255),
                accentSoft: Color(red: 159/255, green: 31/255, blue: 82/255).opacity(0.28),
                card: Color.white.opacity(0.34),
                cardSub: Color.white.opacity(0.30),
                border: Color.white.opacity(0.70),
                shadow: Color(red: 70/255, green: 78/255, blue: 96/255).opacity(0.16),
                textureAsset: "WetGlassHaven"
            )
        }
    }

    private func panelCopy(
        splashBg: [Color],
        text: Color,
        textDim: Color,
        textLight: Color,
        accent: Color,
        accentSoft: Color,
        card: Color,
        cardSub: Color,
        border: Color,
        shadow: Color,
        textureAsset: String
    ) -> AlcoveTheme {
        AlcoveTheme(
            isDark: isDark,
            isPaper: isPaper,
            usesWallImage: usesWallImage,
            wallGradient: wallGradient,
            bubbleUser: bubbleUser,
            bubbleAI: bubbleAI,
            text: text,
            textDim: textDim,
            textLight: textLight,
            timestamp: timestamp,
            glassTint: card,
            glassBorder: border,
            capsuleTint: capsuleTint,
            capsuleBorder: capsuleBorder,
            sendTop: sendTop,
            sendBottom: sendBottom,
            fade: fade,
            splashBg: splashBg,
            splashBarTop: splashBarTop,
            splashBarBottom: splashBarBottom,
            splashGlowA: splashGlowA,
            splashGlowB: splashGlowB,
            splashPetal: splashPetal,
            splashTitle: splashTitle,
            fyAccent: accent,
            fyAccentSoft: accentSoft,
            fyCard: card,
            fyCardSub: cardSub,
            fyBorder: border,
            fyShadow: shadow,
            fyFold: Color.white.opacity(isDark ? 0.08 : 0.22),
            fyDash: border.opacity(0.72),
            panelTextureAsset: textureAsset
        )
    }

    private func iceCopy(dark: Bool) -> AlcoveTheme {
        let ink = dark ? Color(red: 0.90, green: 0.95, blue: 1.0) : Color(red: 0.10, green: 0.20, blue: 0.34)
        let dim = dark ? Color(red: 0.66, green: 0.78, blue: 0.93) : Color(red: 0.30, green: 0.45, blue: 0.63)
        let card = dark ? Color(red: 0.06, green: 0.18, blue: 0.36).opacity(0.48) : Color.white.opacity(0.34)
        let border = dark ? Color(red: 0.48, green: 0.76, blue: 1.0).opacity(0.26) : Color.white.opacity(0.70)
        return AlcoveTheme(
            isDark: dark, isPaper: false, usesWallImage: true, wallGradient: [],
            bubbleUser: dark ? Color(red: 0.08, green: 0.32, blue: 0.62).opacity(0.52) : Color(red: 0.63, green: 0.82, blue: 1.0).opacity(0.42),
            bubbleAI: dark ? Color(red: 0.08, green: 0.20, blue: 0.39).opacity(0.50) : Color.white.opacity(0.40),
            text: ink, textDim: dim, textLight: dim.opacity(0.72), timestamp: dim,
            glassTint: card, glassBorder: border, capsuleTint: card, capsuleBorder: border,
            sendTop: dark ? Color(red: 0.22, green: 0.57, blue: 0.96) : Color(red: 0.31, green: 0.55, blue: 0.82),
            sendBottom: dark ? Color(red: 0.10, green: 0.34, blue: 0.72) : Color(red: 0.18, green: 0.39, blue: 0.69),
            fade: dark ? Color(red: 0.01, green: 0.06, blue: 0.15) : Color(red: 0.94, green: 0.98, blue: 1.0),
            splashBg: dark ? [Color(red: 0.01, green: 0.08, blue: 0.20), Color(red: 0.03, green: 0.16, blue: 0.38)] : [Color.white, Color(red: 0.88, green: 0.95, blue: 1.0)],
            splashBarTop: dim, splashBarBottom: dim.opacity(0.8), splashGlowA: border, splashGlowB: card,
            splashPetal: dim.opacity(0.4), splashTitle: dim,
            fyAccent: dim, fyAccentSoft: dim.opacity(0.22), fyCard: card, fyCardSub: card.opacity(0.78),
            fyBorder: border, fyShadow: Color.black.opacity(dark ? 0.28 : 0.08), fyFold: border.opacity(0.35), fyDash: border,
            panelTextureAsset: dark ? "ChatWallIceDark" : "ChatWallIce"
        )
    }

    private func paperCopy(dark: Bool) -> AlcoveTheme {
        let paper = dark ? Color(red: 24/255, green: 24/255, blue: 25/255)
                         : Color(red: 248/255, green: 248/255, blue: 246/255)
        let card = dark ? Color(red: 36/255, green: 35/255, blue: 33/255)
                        : Color.white
        let ink = dark ? Color(red: 231/255, green: 227/255, blue: 218/255)
                       : Color(red: 37/255, green: 36/255, blue: 34/255)
        let pencil = dark ? Color(red: 166/255, green: 160/255, blue: 151/255)
                          : Color(red: 139/255, green: 136/255, blue: 130/255)
        let rose = dark ? Color(red: 148/255, green: 91/255, blue: 91/255)
                        : Color(red: 185/255, green: 120/255, blue: 120/255)
        return AlcoveTheme(
            isDark: dark, isPaper: true, usesWallImage: false,
            wallGradient: [paper, paper],
            bubbleUser: dark ? Color(red: 54/255, green: 52/255, blue: 57/255) : Color(red: 233/255, green: 232/255, blue: 236/255),
            bubbleAI: .clear, text: ink, textDim: pencil,
            textLight: pencil.opacity(0.72), timestamp: pencil,
            glassTint: card, glassBorder: pencil.opacity(0.16),
            capsuleTint: card, capsuleBorder: pencil.opacity(0.14),
            sendTop: dark ? Color(red: 231/255, green: 227/255, blue: 218/255) : Color(red: 37/255, green: 36/255, blue: 34/255),
            sendBottom: dark ? Color(red: 205/255, green: 200/255, blue: 191/255) : Color(red: 24/255, green: 24/255, blue: 23/255),
            fade: paper, splashBg: [paper, paper], splashBarTop: rose,
            splashBarBottom: rose.opacity(0.8), splashGlowA: .clear, splashGlowB: .clear,
            splashPetal: rose.opacity(0.35), splashTitle: rose,
            fyAccent: rose, fyAccentSoft: rose.opacity(0.16), fyCard: card,
            fyCardSub: paper, fyBorder: pencil.opacity(0.17),
            fyShadow: Color.black.opacity(dark ? 0.22 : 0.05),
            fyFold: pencil.opacity(0.10), fyDash: pencil.opacity(0.24),
            panelTextureAsset: dark ? "PaperDark" : "PaperLight"
        )
    }
}
