import SwiftUI

// 麻将牌桌：推倒胡底座（四组面子 + 一对将），2~4 人。
//
// 跟前四张牌桌最大的不同是**抢牌窗口**：谁打出一张牌，有权要的人可能不止一个，
// 引擎的 currentActors 这时会同时点好几个人的名，每个人各自表态（要/过），
// 全表完才按 胡＞碰/杠＞吃 结算。所以这张桌的操作条有两套：
//   · 轮到我打牌   —— 抬起一张 + 常驻「打出」键（照她 0828 定的防手滑两段出牌）
//                    ＋ 自摸/暗杠/补杠 按合法招现给
//   · 轮到我表态   —— 胡/碰/杠/吃/过；吃有多种搭法时按出「吃」再选（第二段，同防手滑）
//
// 牌面按传统画：筒是圈、条是竖棍、万是汉字数字＋万、字牌单字（白板画成空框）。
// 牌面字色**定死**不吃调色盘——夜里 ink 是月白，白牌面上会隐形（0828 王牌卡面踩过）。

// MARK: - 牌面工具

enum MahjongTile {
    /// "m3#2" -> "m3"
    static func kind(_ id: String) -> String {
        id.split(separator: "#").first.map(String.init) ?? id
    }
    static func suit(_ id: String) -> String { String(kind(id).prefix(1)) }
    static func num(_ id: String) -> Int { Int(kind(id).dropFirst()) ?? 0 }

    static let numerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
    static let honors = ["东", "南", "西", "北", "中", "发", "白"]
    static let suitNames = ["m": "万", "s": "条", "p": "筒"]

    /// "三万" / "五条" / "中"
    static func label(_ id: String) -> String {
        let n = num(id)
        guard n >= 1 else { return id }
        if suit(id) == "z" { return n <= 7 ? honors[n - 1] : id }
        guard n <= 9, let s = suitNames[suit(id)] else { return id }
        return numerals[n - 1] + s
    }

    static func labels(_ ids: [String]) -> String {
        ids.map(label).joined()
    }

    /// 牌面字色（定死，不吃日夜）。压过饱和，跟灰蓝底不打架
    static func tint(_ id: String) -> Color {
        switch suit(id) {
        case "s": return QipaiPalette.qhex(0x4A7A58)      // 条·竹绿
        case "p": return QipaiPalette.qhex(0x36697F)      // 筒·青蓝
        case "z":
            switch num(id) {
            case 5: return QipaiPalette.qhex(0xB0453D)    // 中·红
            case 6: return QipaiPalette.qhex(0x3E7A54)    // 发·绿
            case 7: return QipaiPalette.qhex(0x5C6577)    // 白·灰
            default: return QipaiPalette.qhex(0x3C4763)   // 东南西北·靛
            }
        default: return QipaiPalette.qhex(0x3C4763)       // 万·靛
        }
    }

    /// 筒/条的点位（单位坐标，0~1）。照传统摆法：三是斜的，七是上一下六。
    /// ‼️一句话塞四十五个 CGPoint 字面量是「expression too complex」的经典形状
    ///（CGPoint 三个重载 × 每个坐标都要挑字面量类型），拆成一句一行让类型检查器一口一口吃。
    static let pips: [Int: [CGPoint]] = {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        var m: [Int: [CGPoint]] = [:]
        m[1] = [p(0.5, 0.5)]
        m[2] = [p(0.5, 0.26), p(0.5, 0.74)]
        m[3] = [p(0.24, 0.2), p(0.5, 0.5), p(0.76, 0.8)]
        m[4] = [p(0.28, 0.28), p(0.72, 0.28), p(0.28, 0.72), p(0.72, 0.72)]
        m[5] = [p(0.24, 0.22), p(0.76, 0.22), p(0.5, 0.5), p(0.24, 0.78), p(0.76, 0.78)]
        m[6] = [p(0.28, 0.18), p(0.72, 0.18), p(0.28, 0.5),
                p(0.72, 0.5), p(0.28, 0.82), p(0.72, 0.82)]
        m[7] = [p(0.5, 0.12), p(0.28, 0.38), p(0.72, 0.38),
                p(0.28, 0.62), p(0.72, 0.62), p(0.28, 0.87), p(0.72, 0.87)]
        m[8] = [p(0.28, 0.14), p(0.72, 0.14), p(0.28, 0.38), p(0.72, 0.38),
                p(0.28, 0.62), p(0.72, 0.62), p(0.28, 0.86), p(0.72, 0.86)]
        m[9] = [p(0.2, 0.2), p(0.5, 0.2), p(0.8, 0.2),
                p(0.2, 0.5), p(0.5, 0.5), p(0.8, 0.5),
                p(0.2, 0.8), p(0.5, 0.8), p(0.8, 0.8)]
        return m
    }()

    /// 一根竹节：位置（单位坐标）+ 倾角。0901 陈霁：**八条是「WM」那个样子**，
    /// 上面四根斜成 W、下面四根斜成 M —— 不是竖着排八根。她发了实物照片。
    /// 所以条不能跟筒共用一张点位表（筒是圆点摆网格，条有自己的传统画法）。
    struct Stick {
        let x: CGFloat
        let y: CGFloat
        let a: Double      // 度，正数=上端往右偏
    }

    /// 条的传统排法。‼️改之前先想清楚：这些不是随手摆的，是麻将牌本来的样子。
    static let sticks: [Int: [Stick]] = {
        func s(_ x: CGFloat, _ y: CGFloat, _ a: Double = 0) -> Stick { Stick(x: x, y: y, a: a) }
        var m: [Int: [Stick]] = [:]
        m[1] = [s(0.5, 0.5)]
        m[2] = [s(0.5, 0.28), s(0.5, 0.72)]
        m[3] = [s(0.5, 0.24), s(0.31, 0.72), s(0.69, 0.72)]
        m[4] = [s(0.30, 0.28), s(0.70, 0.28), s(0.30, 0.72), s(0.70, 0.72)]
        m[5] = [s(0.26, 0.24), s(0.74, 0.24), s(0.5, 0.5),
                s(0.26, 0.76), s(0.74, 0.76)]
        m[6] = [s(0.22, 0.28), s(0.5, 0.28), s(0.78, 0.28),
                s(0.22, 0.72), s(0.5, 0.72), s(0.78, 0.72)]
        m[7] = [s(0.5, 0.14),
                s(0.22, 0.48), s(0.5, 0.48), s(0.78, 0.48),
                s(0.22, 0.82), s(0.5, 0.82), s(0.78, 0.82)]
        // 八条：上 W 下 M。斜角一正一反交替，四根连起来眼睛自己会补成 W／M
        m[8] = [s(0.20, 0.28,  26), s(0.40, 0.28, -26), s(0.60, 0.28,  26), s(0.80, 0.28, -26),
                s(0.20, 0.72, -26), s(0.40, 0.72,  26), s(0.60, 0.72, -26), s(0.80, 0.72,  26)]
        m[9] = [s(0.22, 0.18), s(0.5, 0.18), s(0.78, 0.18),
                s(0.22, 0.5),  s(0.5, 0.5),  s(0.78, 0.5),
                s(0.22, 0.82), s(0.5, 0.82), s(0.78, 0.82)]
        return m
    }()

    /// 副露名（碰 三万 / 吃 一万二万三万）
    static func meldLabel(_ m: MahjongMeld) -> String {
        if !m.label.isEmpty { return m.label }
        guard let t = m.tiles, let head = t.first else { return "暗杠" }
        return m.kind == "chi" ? "吃 " + labels(t) : "碰 " + label(head)
    }
}

// MARK: - 一张牌

/// 牌面朝向：弃牌要**面对打牌的人**（0901 她对着腾讯参考图点名的）。
/// 对家的弃牌在我看来是倒的（.down），左右两家的横过来（.left/.right）。
/// ‼️只转牌面和牌形，**不转挤出方向**——厚度永远朝屏幕右下，
/// 全桌一个透视方向，这是「统一 3/4 空间」的根。
enum MahjongTileOrient {
    case up, down, left, right

    var degrees: Double {
        switch self {
        case .up: return 0
        case .down: return 180
        case .left: return -90
        case .right: return 90
        }
    }
    var sideways: Bool { self == .left || self == .right }
}

struct MahjongTileFace: View {
    let id: String
    var width: CGFloat = 34
    var dimmed: Bool = false
    var orient: MahjongTileOrient = .up

    /// 竖放时的牌高。‼️1.34 别改——牌河、副露、手牌的排版全按它算。
    private var faceH: CGFloat { width * 1.34 }
    /// 横过来的牌占位跟着转（宽高互换），排版才不会叠
    private var bodyW: CGFloat { orient.sideways ? faceH : width }
    private var bodyH: CGFloat { orient.sideways ? width : faceH }
    private var tint: Color { MahjongTile.tint(id) }
    private var suit: String { MahjongTile.suit(id) }
    private var n: Int { MahjongTile.num(id) }

    /// 挤出量：右侧面窄、前立面宽——3/4 俯视里近边永远露得多。
    /// 0901 四稿：二三稿只有底边一条厚度，她打回「有厚度但还是平面」；
    /// 现在牌身整块往右下错开，右+下两个立面一起露出来才立体。
    private var sideX: CGFloat { max(width * 0.09, 1.4) }
    private var sideY: CGFloat { max(width * 0.16, 2.2) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: width * 0.15, style: .continuous)
        return ZStack(alignment: .topLeading) {
            // 牌身＝同形状往右下错开：露出的右条是侧面、下条是前立面。
            // 渐变斜着走——右上受光、左下贴桌，两个立面一道渐变全兜住
            shape
                .fill(LinearGradient(stops: [
                    .init(color: QipaiPalette.qhex(0xE8DFCB), location: 0),
                    .init(color: QipaiPalette.qhex(0xCBBFA6), location: 0.72),
                    .init(color: QipaiPalette.qhex(0xA2967C), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: bodyW, height: bodyH)
                .offset(x: sideX, y: sideY)
            face
                .frame(width: width, height: faceH)
                .rotationEffect(.degrees(orient.degrees))
                .frame(width: bodyW, height: bodyH)
        }
        .frame(width: bodyW, height: bodyH)
        .opacity(dimmed ? 0.5 : 1)
        // 近影贴着挤出方向落（这道影同时是压在右邻牌上的遮挡影），远影泛开
        .shadow(color: QipaiPalette.shadowTint.opacity(0.32), radius: width * 0.05,
                x: width * 0.05, y: width * 0.07)
        .shadow(color: QipaiPalette.shadowTint.opacity(0.16), radius: width * 0.15,
                x: width * 0.08, y: width * 0.12)
    }

    /// 牌的正面（象牙底 + 凹槽 + 图案）
    private var face: some View {
        ZStack {
            // 象牙底（定死，日夜同色——夜里也是牌，不是纸）
            RoundedRectangle(cornerRadius: width * 0.15, style: .continuous)
                .fill(LinearGradient(colors: [QipaiPalette.qhex(0xFDFBF5), QipaiPalette.qhex(0xEDE7D8)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            // 牌面那道浅凹槽
            RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                .fill(QipaiPalette.qhex(0xFCFAF4))
                .padding(width * 0.06)
                .shadow(color: QipaiPalette.qhex(0x9A9280).opacity(0.35), radius: 0.6, y: 0.6)
            art
        }
        .overlay(RoundedRectangle(cornerRadius: width * 0.15, style: .continuous)
            .stroke(QipaiPalette.qhex(0xB6AE9A).opacity(0.85), lineWidth: 1))
        // 顶边一道白高光：跟阴影同一个光源，牌才"鼓"得起来
        .overlay(RoundedRectangle(cornerRadius: width * 0.15, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.06), .clear],
                                 startPoint: .topLeading, endPoint: .center))
            .allowsHitTesting(false))
    }

    // MARK: 牌面内容

    /// ‼️0901 陈霁：牌河/副露里的牌**一律画图**，不许缩小就退化成「二筒」「二条」这种文字。
    /// 原来 width<26 会走一个 compactArt 画汉字（我当初怕小尺寸看不清），她明确不要，已删。
    /// 筒的圈、条的棍在小尺寸下会糊成一团点——那也是对的，真麻将远看就是这样，
    /// 认不出具体几个不影响，认得出是哪一门就够。pipSize 里给了最小值兜底。
    /// 万和字牌本来就是汉字，wanArt / honorArt 就是它们真正的"画法"，不算退化。
    @ViewBuilder private var art: some View {
        if suit == "z" {
            honorArt
        } else if suit == "m" {
            wanArt
        } else {
            pipArt
        }
    }

    /// 万：汉字数字压着一个「万」
    private var wanArt: some View {
        VStack(spacing: -width * 0.05) {
            Text(n >= 1 && n <= 9 ? MahjongTile.numerals[n - 1] : "?")
                .font(.system(size: width * 0.46, weight: .bold, design: .serif))
            Text("万")
                .font(.system(size: width * 0.4, weight: .semibold, design: .serif))
        }
        .foregroundColor(tint)
    }

    /// 字牌：单字。白板照传统画成一个空框
    @ViewBuilder private var honorArt: some View {
        if n == 7 {
            RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
                .stroke(tint, lineWidth: max(1.4, width * 0.05))
                .padding(.horizontal, width * 0.22)
                .padding(.vertical, width * 0.3)
        } else {
            Text(n >= 1 && n <= 7 ? MahjongTile.honors[n - 1] : "?")
                .font(.system(size: width * 0.58, weight: .heavy, design: .serif))
                .foregroundColor(tint)
        }
    }

    /// 筒画圈，条画棍——两套排法，别再共用一张表
    @ViewBuilder private var pipArt: some View {
        if suit == "p" { dotArt } else { stickArt }
    }

    /// 筒：一圈一圈的钱串
    private var dotArt: some View {
        let pts = MahjongTile.pips[n] ?? []
        let aw = width * 0.64
        let ah = faceH * 0.68
        let d = pipSize
        return ZStack {
            ForEach(Array(pts.enumerated()), id: \.offset) { item in
                ZStack {
                    Circle().fill(tint.opacity(0.2))
                    Circle().strokeBorder(tint, lineWidth: max(1, d * 0.24))
                }
                .frame(width: d, height: d)
                .offset(x: (item.element.x - 0.5) * aw, y: (item.element.y - 0.5) * ah)
            }
        }
    }

    /// 条：竹节。‼️棍长按**最小行距**算出来，不写死——
    /// 0901 她抓的「八条糊成一团」就是写死尺寸害的（棍子比行距还高，必然叠）。
    /// 这样以后不管点位表怎么改，都不会再叠。
    private var stickArt: some View {
        let arr = MahjongTile.sticks[n] ?? []
        let aw = width * 0.62
        let ah = faceH * 0.70
        let ys = Array(Set(arr.map { $0.y })).sorted()
        var gap: CGFloat = 1
        if ys.count > 1 {
            var g = CGFloat.greatestFiniteMagnitude
            for i in 1..<ys.count { g = min(g, ys[i] - ys[i - 1]) }
            gap = g
        }
        let len = min(max(gap * ah * 0.82, 3), ah * 0.5)
        let thick = max(len * 0.26, 1.5)
        return ZStack {
            ForEach(Array(arr.enumerated()), id: \.offset) { item in
                Capsule()
                    .fill(tint)
                    .frame(width: thick, height: len)
                    .rotationEffect(.degrees(item.element.a))
                    .offset(x: (item.element.x - 0.5) * aw, y: (item.element.y - 0.5) * ah)
            }
        }
    }

    /// 小牌上圈/棍不能小到看不见：给个 2.2pt 的地板（0901 拆掉文字退化之后加的）
    private var pipSize: CGFloat {
        let base = width * 0.64
        let ratio: CGFloat
        switch n {
        case 1, 2: ratio = 0.44
        case 3, 4, 5: ratio = 0.36
        case 6, 7, 8: ratio = 0.32
        default: ratio = 0.28
        }
        return max(base * ratio, 2.2)
    }
}

/// 扣着的牌（对手手牌 / 暗杠）。
/// 普通状态是躺在桌上的完整牌背；standing 专供横屏对家，不能拿同一个圆角矩形
/// 加一条亮边冒充立牌。立牌明确拆成正面、顶面和右侧面，关掉投影也看得出厚度。
struct MahjongTileBack: View {
    var width: CGFloat = 24
    var standing: Bool = false

    private var corner: CGFloat { width * 0.15 }

    @ViewBuilder
    var body: some View {
        if standing { standingBody } else { flatBody }
    }

    /// 竖着的牌。frontW 给右侧面让位；三个 Path 共用同一组边，不能再拆成互不相干
    /// 的圆角矩形。牌背图只铺正面，顶面和侧面永远是牌身材质。
    private var standingBody: some View {
        let side = max(width * 0.12, 2.4)
        let top = max(width * 0.20, 3.5)
        let frontW = width - side
        let frontH = width * 1.24
        let totalH = top + frontH
        let faceShape = RoundedRectangle(cornerRadius: width * 0.10, style: .continuous)

        return ZStack(alignment: .topLeading) {
            // 顶面：向右上方退，和正面上沿共边。
            Path { p in
                p.move(to: CGPoint(x: 0, y: top))
                p.addLine(to: CGPoint(x: frontW, y: top))
                p.addLine(to: CGPoint(x: width, y: 0))
                p.addLine(to: CGPoint(x: side, y: 0))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [QipaiPalette.qhex(0xFFFCF6),
                                          QipaiPalette.qhex(0xDDD2BE)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))

            // 正面：新的牌背素材包含完整奶白牌壳，按立牌比例铺满这一面。
            Image("MahjongTileBackArt")
                .resizable()
                .scaledToFill()
                .frame(width: frontW, height: frontH)
                .clipShape(faceShape)
                .overlay(
                    LinearGradient(colors: [.clear,
                                            QipaiPalette.qhex(0x7A685F).opacity(0.24)],
                                   startPoint: .center, endPoint: .bottom)
                        .clipShape(faceShape)
                )
                .overlay(faceShape.stroke(QipaiPalette.qhex(0xB7AA96).opacity(0.65),
                                          lineWidth: 0.65))
                .offset(y: top)

            // 右侧面：背光，比顶面深；下端与正面底边共点。
            Path { p in
                p.move(to: CGPoint(x: frontW, y: top))
                p.addLine(to: CGPoint(x: width, y: 0))
                p.addLine(to: CGPoint(x: width, y: frontH))
                p.addLine(to: CGPoint(x: frontW, y: totalH))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [QipaiPalette.qhex(0xE9DFCC),
                                          QipaiPalette.qhex(0xB7AA92)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                Path { p in
                    p.move(to: CGPoint(x: frontW, y: top))
                    p.addLine(to: CGPoint(x: frontW, y: totalH))
                }
                .stroke(.white.opacity(0.32), lineWidth: 0.55)
            )

            // 接地暗线只贴在底边，不再围着整张牌发光。
            Capsule()
                .fill(QipaiPalette.qhex(0x675B50).opacity(0.48))
                .frame(width: frontW * 0.88, height: max(width * 0.045, 0.8))
                .offset(x: frontW * 0.06, y: totalH - max(width * 0.045, 0.8))
        }
        .frame(width: width, height: totalH)
        .shadow(color: QipaiPalette.shadowTint.opacity(0.28),
                radius: width * 0.10, x: width * 0.10, y: width * 0.14)
    }

    private var flatBody: some View {
        let h = width * 1.34
        let thickness = max(width * 0.14, 2)
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return ZStack(alignment: .top) {
            shape.fill(LinearGradient(colors: [QipaiPalette.qhex(0xFBF6EB), QipaiPalette.qhex(0xE2D9C5)],
                                      startPoint: .top, endPoint: .bottom))
            Color.clear
                .overlay(Image("MahjongTileBackArt").resizable().scaledToFill())
                .clipShape(RoundedRectangle(cornerRadius: corner * 0.9, style: .continuous))
                .padding(.top, thickness)
        }
        .frame(width: width, height: h)
        .overlay(shape.stroke(QipaiPalette.qhex(0xB9AE97).opacity(0.7), lineWidth: 0.7))
        .shadow(color: QipaiPalette.shadowTint.opacity(0.25),
                radius: width * 0.09, x: width * 0.03, y: width * 0.08)
    }
}

/// 左右牌墙的一片。完整牌背图不能 scaledToFill 进这种横片：那会把中央花章裁出来，
/// 每张重复一次，整排就成了「粉色梯子」。侧墙只显示连续的粉色背面立面和奶白厚度。
struct MahjongTileSide: View {
    var width: CGFloat = 24
    var mirrored = false

    private var h: CGFloat { width * 0.43 }
    private var edgeW: CGFloat { width * 0.28 }

    var body: some View {
        ZStack {
            // 外侧奶白厚度面。左右牌墙必须镜像，不能把同一排直接旋转。
            Path { p in
                if mirrored {
                    p.move(to: CGPoint(x: width - edgeW, y: 1))
                    p.addLine(to: CGPoint(x: width, y: 0))
                    p.addLine(to: CGPoint(x: width, y: h))
                    p.addLine(to: CGPoint(x: width - edgeW, y: h - 1))
                } else {
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: edgeW, y: 1))
                    p.addLine(to: CGPoint(x: edgeW, y: h - 1))
                    p.addLine(to: CGPoint(x: 0, y: h))
                }
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [QipaiPalette.qhex(0xFFFDF7),
                                          QipaiPalette.qhex(0xD8CEBA)],
                                 startPoint: .top, endPoint: .bottom))

            // 朝桌心的粉色背面立面；这里故意不用图片，避免花章被重复裁切。
            Path { p in
                if mirrored {
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: width - edgeW, y: 1))
                    p.addLine(to: CGPoint(x: width - edgeW, y: h - 1))
                    p.addLine(to: CGPoint(x: 0, y: h))
                } else {
                    p.move(to: CGPoint(x: edgeW, y: 1))
                    p.addLine(to: CGPoint(x: width, y: 0))
                    p.addLine(to: CGPoint(x: width, y: h))
                    p.addLine(to: CGPoint(x: edgeW, y: h - 1))
                }
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [QipaiPalette.qhex(0xF3CBD5),
                                          QipaiPalette.qhex(0xD98FA4)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))

            Rectangle()
                .fill(QipaiPalette.qhex(0xA96E7F).opacity(0.46))
                .frame(height: 0.65)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: width, height: h)
    }
}

/// 侧墙最南端的收口：最后一张牌的端面。左右镜像时光线仍从左上来，不能镜像阴影。
struct MahjongTileSideCap: View {
    var width: CGFloat = 24
    var mirrored = false

    private var h: CGFloat { width * 0.82 }
    private var corner: CGFloat { width * 0.12 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        shape
            .fill(LinearGradient(colors: [QipaiPalette.qhex(0xFCF8EF), QipaiPalette.qhex(0xD9CFB9)],
                                 startPoint: mirrored ? .topTrailing : .topLeading,
                                 endPoint: mirrored ? .bottomLeading : .bottomTrailing))
            .overlay(shape.stroke(QipaiPalette.qhex(0xB9AE97).opacity(0.7), lineWidth: 0.7))
            .frame(width: width, height: h)
    }
}

// MARK: - 牌桌

struct QipaiMahjongTableView: View {
    let code: String
    var onExit: () -> Void

    @StateObject private var store: QipaiTableStore<MahjongView>
    /// 抬起待打的那张（两段出牌，防手滑）
    @State private var selected: String?
    /// 按了「吃」之后才展开的搭法选择（一张牌最多三种吃法）
    @State private var chiPicking = false
    /// 横屏那张桌（0831 她要的，只有麻将做）。共用同一个 store，不重连
    @State private var landscape = false

    init(code: String, onExit: @escaping () -> Void) {
        self.code = code
        self.onExit = onExit
        _store = StateObject(wrappedValue: QipaiTableStore(code: code))
    }

    var body: some View {
        ZStack {
            QipaiTableShell(store: store, fallbackTitle: "麻将",
                            round: store.view?.round, onExit: onExit) {
                if let view = store.view {
                    table(view)
                }
            } help: {
                helpContent
            }
            overlays
            // ‼️0901 她第一次构建就抓到：横屏**不能**用 fullScreenCover。
            // 盖板一弹，iOS 去问「最上面那个被弹出的控制器支持什么方向」，
            // SwiftUI 的盖板宿主不会因为 requestGeometryUpdate 重新评估一次 ——
            // 结果是布局换成横屏的了、屏幕却还是竖的（她截图为证）。
            // 共读室 0826 验过的那条路是**在同一棵树里直接换**
            //（CowatchView 的 `if fullscreen { CowatchFullscreen(...) }`），照抄它。
            // 白捡的好处：外壳没被移出层级，它那句 .onDisappear { store.stop() }
            // 不会触发，连接也就不会被掐（原来那两刀补救因此变成空操作，留着当保险）。
            if landscape {
                QipaiMahjongLandscapeView(store: store) { landscape = false }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: landscape)
        // 局面翻页：抬起的牌可能已经打掉了，清掉免得打出一张不在手里的
        .onChange(of: (store.view?.seq ?? 0)) { _ in
            let hand = store.view?.me?.hand ?? []
            if let s = selected, !hand.contains(s) { selected = nil }
            // 只要这一刻不是「等我表态」，选搭法的那层就收掉——
            // 表完态到下一个窗口打开之间未必回落到 claim==nil，只判 nil 会残留
            if store.view?.claim?.mine != true { chiPicking = false }
        }
    }

    // MARK: 整桌

    private func table(_ view: MahjongView) -> some View {
        VStack(spacing: 7) {
            opponentsRow(view)
            centerBoard(view)
            riverPanel(view)
            QipaiFeedStrip(store: store).frame(minHeight: 56)
            myArea(view)
        }
        .padding(.horizontal, 12)
    }

    /// 对手按座次从我的下家开始排
    private func opponents(_ view: MahjongView) -> [MahjongPlayerView] {
        guard let you = view.you,
              let idx = view.turnOrder.firstIndex(of: you) else {
            return view.players.filter { $0.id != view.you }
        }
        let order = view.turnOrder
        var out: [MahjongPlayerView] = []
        for step in 1..<max(order.count, 1) {
            if let p = view.player(order[(idx + step) % order.count]) { out.append(p) }
        }
        return out
    }

    private func seatTone(_ id: String) -> Color? {
        store.seatIndex(ofPlayer: id).map(QipaiPalette.seatTone)
    }

    // MARK: 对手条

    private func opponentsRow(_ view: MahjongView) -> some View {
        HStack(spacing: 7) {
            ForEach(opponents(view)) { p in seatCard(p, view: view) }
        }
    }

    private func seatCard(_ p: MahjongPlayerView, view: MahjongView) -> some View {
        let owed = view.owed.contains(p.id)
        return VStack(spacing: 3) {
            QipaiHalo(active: owed)
            HStack(spacing: 3) {
                if p.isAI {
                    Image(systemName: "sparkles").font(.system(size: 8.5))
                        .foregroundColor(QipaiPalette.accent)
                }
                Text(p.name).font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(seatTone(p.id) ?? QipaiPalette.ink).lineLimit(1)
                if view.leader == p.id { QipaiChip(text: "庄", tone: .live) }
            }
            if p.out {
                QipaiChip(text: p.won?.zimo == true ? "自摸" : "已胡", tone: .red)
            } else {
                HStack(spacing: 4) {
                    Text("\(p.handCount)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(QipaiPalette.ink)
                    Text("张").font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
                    if !p.melds.isEmpty {
                        Text("+\(p.melds.count) 副")
                            .font(.system(size: 9)).foregroundColor(QipaiPalette.accent)
                    }
                }
            }
            if !p.melds.isEmpty { meldStrip(p.melds, width: 15) }
            Text("累计 \(p.score) 分")
                .font(.system(size: 8.5)).foregroundColor(QipaiPalette.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6).padding(.horizontal, 3)
        .qipaiPanel(corner: 14)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(seatTone(p.id) ?? QipaiPalette.glowRing, lineWidth: owed ? 1.6 : 0))
    }

    /// 副露一小排（暗杠对别人是四张背面）
    private func meldStrip(_ melds: [MahjongMeld], width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(melds) { m in
                    HStack(spacing: -width * 0.18) {
                        if let tiles = m.tiles {
                            ForEach(Array(tiles.enumerated()), id: \.offset) { item in
                                MahjongTileFace(id: item.element, width: width)
                            }
                        } else {
                            ForEach(0..<m.count, id: \.self) { _ in
                                MahjongTileBack(width: width)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: width * 1.34 + 2)
    }

    // MARK: 场中央

    private func centerBoard(_ view: MahjongView) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(view.wallCount)")
                        .font(.system(size: 19, weight: .bold, design: .monospaced))
                        .foregroundColor(QipaiPalette.ink)
                    Text("牌墙").font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
                }
                if let last = view.lastDiscard {
                    VStack(spacing: 2) {
                        MahjongTileFace(id: last.tile, width: 34)
                        Text("\(view.player(last.from)?.name ?? "") 打")
                            .font(.system(size: 8.5)).foregroundColor(QipaiPalette.inkDim)
                            .lineLimit(1)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let next = nextSeatLabel(view) {
                        Text(next)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(QipaiPalette.accent)
                            .lineLimit(1)
                    }
                    ForEach(activeRuleLabels(view), id: \.self) { r in
                        QipaiChip(text: r, tone: .neutral)
                    }
                }
                Spacer(minLength: 0)
                landscapeButton
            }
            statusLine(view)
        }
        .frame(maxWidth: .infinity)
        .padding(9)
        .qipaiPanel(corner: 16, dotted: true)
    }

    /// 转横屏。只有麻将有这个按钮（她定的：别的桌不做横屏）
    private var landscapeButton: some View {
        Button { landscape = true } label: {
            VStack(spacing: 2) {
                Image(systemName: "rectangle.landscape.rotate")
                    .font(.system(size: 15, weight: .semibold))
                Text("横屏").font(.system(size: 8.5, weight: .medium))
            }
            .foregroundColor(QipaiPalette.accent)
            .frame(width: 42, height: 40)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(QipaiPalette.fieldBg))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(QipaiPalette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 下家是谁（血战里已经胡牌离场的人要跳过）
    private func nextSeatLabel(_ view: MahjongView) -> String? {
        let anchor = view.you ?? view.current
        let next = QipaiSeatOrder.next(order: view.turnOrder, from: anchor,
                                       isActive: { view.player($0)?.out == false })
        guard let next, let name = view.player(next)?.name else { return nil }
        return QipaiSeatOrder.label(name, mine: view.you != nil)
    }

    /// 开着的变体开关（默认全关，只列开了的；吃牌默认开，关了才提）
    private func activeRuleLabels(_ view: MahjongView) -> [String] {
        var out: [String] = []
        if view.rules["xue_zhan"] == true { out.append("血战到底") }
        if view.rules["qi_dui"] == true { out.append("七对子") }
        if view.rules["que_yi_men"] == true { out.append("缺一门") }
        if view.rules["gang_bonus"] == true { out.append("杠上开花") }
        if view.rules["honors"] == true { out.append("带字牌") }
        if view.rules["allow_chi"] == false { out.append("不许吃") }
        return out
    }

    /// 场中央那一行字。三元套插值套三元最能拖垮类型检查器，先算成 String 再喂 Text
    private func claimLine(_ claim: MahjongClaim, view: MahjongView) -> String {
        if !claim.mine {
            let who = claim.pending.compactMap { view.player($0)?.name }.joined(separator: "、")
            return "等 " + who + " 表态…"
        }
        if claim.kind == "rob" { return "有人补杠 " + claim.label + " —— 抢不抢？" }
        return claim.label + " 摆着，你要不要？"
    }

    private func turnLine(_ view: MahjongView) -> String {
        let name = view.player(view.current)?.name ?? "…"
        return "轮到 " + name + (view.current == view.you ? "（你）" : "")
    }

    @ViewBuilder private func statusLine(_ view: MahjongView) -> some View {
        if view.phase == "playing" {
            if let claim = view.claim {
                Text(claimLine(claim, view: view))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(claim.mine ? QipaiPalette.red : QipaiPalette.ink)
            } else {
                Text(turnLine(view))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(view.current == view.you ? QipaiPalette.red : QipaiPalette.ink)
            }
        }
    }

    // MARK: 牌河

    private func riverPanel(_ view: MahjongView) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(view.turnOrder, id: \.self) { pid in
                    if let p = view.player(pid) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(p.name)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(seatTone(p.id) ?? QipaiPalette.inkDim)
                                .frame(width: 42, alignment: .leading)
                                .lineLimit(1)
                            if p.discards.isEmpty {
                                Text("—").font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 1.5) {
                                        ForEach(Array(p.discards.enumerated()), id: \.offset) { item in
                                            MahjongTileFace(
                                                id: item.element, width: 18,
                                                dimmed: !(view.lastDiscard?.from == p.id
                                                          && item.offset == p.discards.count - 1))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(7)
        }
        .frame(height: 104)
        .qipaiPanel(corner: 14)
    }

    // MARK: 我这边

    private func myArea(_ view: MahjongView) -> some View {
        VStack(spacing: 6) {
            if let me = view.me {
                HStack(spacing: 6) {
                    QipaiHalo(active: view.owed.contains(me.id))
                    Text(myLine(me))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(QipaiPalette.inkDim)
                    Spacer()
                    if me.gain != 0 {
                        Text(me.gain > 0 ? "本局 +\(me.gain)" : "本局 \(me.gain)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundColor(me.gain > 0 ? QipaiPalette.accent : QipaiPalette.red)
                    }
                }
                if !me.melds.isEmpty { meldStrip(me.melds, width: 22) }
                handFan(me, view: view)
                actionBar(view)
            } else {
                Text("观战中 · 谁的手牌都看不见")
                    .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                    .padding(.bottom, 18)
            }
        }
        .padding(.bottom, 8)
    }

    /// "你 13 张 · 2 副 · 累计 4 分"（拆出来算，别在插值里套插值）
    private func myLine(_ me: MahjongPlayerView) -> String {
        var s = "你 \(me.handCount) 张"
        if !me.melds.isEmpty { s += " · \(me.melds.count) 副" }
        return s + " · 累计 \(me.score) 分"
    }

    /// 手牌一排。刚摸进来的那张单独摆到右边（麻将的老规矩，一眼看得出是哪张）
    private func handFan(_ me: MahjongPlayerView, view: MahjongView) -> some View {
        let drawn = view.drawn
        let rest = (me.hand ?? []).filter { $0 != drawn }
        let mine = view.claim == nil && view.current == view.you && view.phase == "playing"
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(rest, id: \.self) { id in tileButton(id, enabled: mine) }
                if let drawn, (me.hand ?? []).contains(drawn) {
                    Spacer().frame(width: 11)
                    tileButton(drawn, enabled: mine)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 15)
            .padding(.bottom, 3)
        }
    }

    private func tileButton(_ id: String, enabled: Bool) -> some View {
        MahjongTileFace(id: id, width: 31)
            .offset(y: selected == id ? -13 : 0)
            .onTapGesture {
                guard enabled else { return }
                selected = (selected == id) ? nil : id     // 再点一下放回去
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.75), value: selected == id)
    }

    // MARK: 操作条

    private var claimMoves: [QipaiLegalMove] { store.legal.filter { $0.type == "claim" } }
    private func claims(_ kind: String) -> [QipaiLegalMove] { claimMoves.filter { $0.kind == kind } }

    @ViewBuilder private func actionBar(_ view: MahjongView) -> some View {
        if view.phase != "playing" {
            EmptyView()
        } else if let claim = view.claim {
            if claim.mine {
                if chiPicking { chiPicker(claim) } else { claimBar(claim) }
            } else {
                Text("等别人表态…")
                    .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
            }
        } else if view.current == view.you {
            turnBar(view)
        } else {
            Text("等 \(view.player(view.current)?.name ?? "…") 出牌…")
                .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
        }
    }

    /// 抢牌窗口：胡 ＞ 碰/杠 ＞ 吃，最后永远有个「过」
    private func claimBar(_ claim: MahjongClaim) -> some View {
        HStack(spacing: 8) {
            if let hu = claims("hu").first {
                Button("胡！") { send(hu) }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(store.busy)
            }
            if let gang = claims("gang").first {
                Button("杠") { send(gang) }
                    .buttonStyle(QipaiEmbossedButtonStyle())
                    .disabled(store.busy)
            }
            if let peng = claims("peng").first {
                Button("碰") { send(peng) }
                    .buttonStyle(QipaiEmbossedButtonStyle())
                    .disabled(store.busy)
            }
            if !claims("chi").isEmpty {
                Button("吃") {
                    // 只有一种搭法就直接吃，多种才展开选（第二段，防手滑）
                    let opts = claims("chi")
                    if opts.count == 1 { send(opts[0]) } else { chiPicking = true }
                }
                .buttonStyle(QipaiEmbossedButtonStyle())
                .disabled(store.busy)
            }
            Button("过") { Task { await store.act(["type": "pass"]) } }
                .buttonStyle(QipaiEmbossedButtonStyle())
                .disabled(store.busy)
        }
    }

    /// 吃的第二段：把每种搭法连同被吃那张摆成一组，点哪组吃哪组
    private func chiPicker(_ claim: MahjongClaim) -> some View {
        VStack(spacing: 6) {
            Text("怎么吃 \(claim.label)？")
                .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(claims("chi")) { mv in
                        Button {
                            send(mv)
                        } label: {
                            HStack(spacing: 1.5) {
                                ForEach(chiRun(mv, claim: claim), id: \.self) { t in
                                    MahjongTileFace(id: t, width: 24)
                                }
                            }
                            .padding(5)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(QipaiPalette.fieldBg))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(QipaiPalette.line, lineWidth: 1))
                        }
                        .disabled(store.busy)
                    }
                    Button("算了") { chiPicking = false }
                        .buttonStyle(QipaiEmbossedButtonStyle())
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// 一种吃法的三张牌（自己两张 + 被吃那张），按点数排好
    private func chiRun(_ mv: QipaiLegalMove, claim: MahjongClaim) -> [String] {
        var out: [String] = mv.tiles ?? []
        out.append(mv.tile ?? claim.tile)
        out.sort { MahjongTile.num($0) < MahjongTile.num($1) }
        return out
    }

    /// 轮到我打牌：自摸/暗杠/补杠 按合法招现给，加上常驻的「打出」
    private func turnBar(_ view: MahjongView) -> some View {
        let zimo = store.legal.first { $0.type == "zimo" }
        let gangs = store.legal.filter { $0.type == "angang" || $0.type == "bugang" }
        return VStack(spacing: 6) {
            if zimo != nil || !gangs.isEmpty {
                HStack(spacing: 8) {
                    if let zimo {
                        Button("自摸胡") { send(zimo) }
                            .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                            .disabled(store.busy)
                    }
                    ForEach(gangs) { mv in
                        Button(mv.label ?? "杠") { send(mv) }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                            .disabled(store.busy)
                    }
                }
            }
            HStack(spacing: 8) {
                Text(selected.map { "打 " + MahjongTile.label($0) } ?? "先点一张牌抬起来")
                    .font(.system(size: 11))
                    .foregroundColor(selected == nil ? QipaiPalette.inkDim : QipaiPalette.ink)
                Button("打出") {
                    guard let sel = selected else { return }
                    selected = nil
                    Task { await store.act(["type": "discard", "tile": sel]) }
                }
                .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                .disabled(selected == nil || store.busy)
            }
        }
    }

    /// 把一条合法招原样发回去（服务端认的就是它给的那几个字段）
    private func send(_ mv: QipaiLegalMove) {
        chiPicking = false
        selected = nil
        var body: [String: Any] = ["type": mv.type]
        if let k = mv.kind { body["kind"] = k }
        if let t = mv.tile { body["tile"] = t }
        if let ts = mv.tiles { body["tiles"] = ts }
        Task { await store.act(body) }
    }

    // MARK: 结算盖板

    @ViewBuilder private var overlays: some View {
        if let view = store.view, view.phase == "round_over" || view.phase == "game_over" {
            resultOverlay(view)
        }
    }

    private func resultOverlay(_ view: MahjongView) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 11) {
                if view.phase == "round_over", let r = view.lastResults {
                    if r.draw {
                        Text("流局")
                            .font(.qipaiDisplay(28)).foregroundColor(QipaiPalette.ink)
                        Text("牌摸完了，谁也没胡")
                            .font(.system(size: 11.5)).foregroundColor(QipaiPalette.inkDim)
                    } else {
                        Text(r.winners.count > 1 ? "一炮多响" : "胡了")
                            .font(.qipaiDisplay(26)).foregroundColor(QipaiPalette.ink)
                        ForEach(r.winners, id: \.self) { id in
                            if let p = view.player(id), let w = p.won { winnerLine(p, w, view: view) }
                        }
                    }
                    scoreRows(r)
                } else {
                    Text("收盤").font(.qipaiDisplay(28)).foregroundColor(QipaiPalette.ink)
                    if let w = view.player(view.winner) {
                        Text("\(w.name) 是最后的大赢家")
                            .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
                    }
                    VStack(spacing: 6) {
                        ForEach(view.players.sorted { $0.score > $1.score }) { p in
                            HStack {
                                Text(p.name).font(.system(size: 13, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink)
                                Spacer()
                                Text("\(p.score) 分")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(QipaiPalette.ink)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                buttons(view)
                QipaiWhisper(text: "the tiles remember every discard.")
            }
            .padding(18)
            .frame(maxWidth: 330)
            .qipaiPanel(corner: 22, dotted: true)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.32).ignoresSafeArea())
    }

    private func winnerLine(_ p: MahjongPlayerView, _ w: MahjongWon, view: MahjongView) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                MahjongTileFace(id: w.tile, width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(seatTone(p.id) ?? QipaiPalette.ink)
                    Text(howLine(w, view: view))
                        .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                }
                Spacer()
                Text("+\(w.gain)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(QipaiPalette.accent)
            }
        }
    }

    private func howLine(_ w: MahjongWon, view: MahjongView) -> String {
        var bits: [String] = []
        if w.zimo { bits.append(w.gang ? "杠上开花自摸" : "自摸") }
        else if w.rob { bits.append("抢 \(view.player(w.from)?.name ?? "") 的杠") }
        else { bits.append("\(view.player(w.from)?.name ?? "") 点炮") }
        if w.qidui { bits.append("七对") }
        bits.append("\(w.fan) 番")
        return bits.joined(separator: " · ")
    }

    private func scoreRows(_ r: MahjongResults) -> some View {
        VStack(spacing: 5) {
            ForEach(r.players) { row in
                HStack {
                    Text(row.name).font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(QipaiPalette.ink)
                    Spacer()
                    Text(row.gain > 0 ? "+\(row.gain)" : "\(row.gain)")
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundColor(row.gain > 0 ? QipaiPalette.accent
                                         : row.gain < 0 ? QipaiPalette.red : QipaiPalette.inkDim)
                    Text("累计 \(row.score)")
                        .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                        .frame(width: 58, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private func buttons(_ view: MahjongView) -> some View {
        if view.phase == "round_over" {
            HStack(spacing: 10) {
                if store.mySeat != nil {
                    Button("再来一局") { Task { await store.nextRound() } }
                        .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                        .disabled(store.busy)
                }
                if store.isHost {
                    Button("收盘") { Task { await store.endMatch() } }
                        .buttonStyle(QipaiEmbossedButtonStyle())
                        .disabled(store.busy)
                }
            }
        } else {
            HStack(spacing: 10) {
                Button("回大厅") { onExit() }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                if store.isHost {
                    Button("关房") { Task { await store.closeRoom(); onExit() } }
                        .buttonStyle(QipaiEmbossedButtonStyle())
                }
            }
        }
    }

    // MARK: 玩法说明

    @ViewBuilder private var helpContent: some View {
        Text("麻将 · 玩法")
            .font(.qipaiMemo(18))
            .foregroundColor(QipaiPalette.ink)
        Group {
            Text("每人 13 张，庄家先摸一张。轮流摸一张、打一张，凑成「四组 + 一对」就胡（推倒胡，不要求番种）。")
            Text("一组 = 三张连着的同门牌（三四五万）或者三张一样的（中中中）。一对 = 两张一样的。")
            Text("别人打出来的牌你能要：三张一样的能碰、四张能杠、只有下家能吃顺子。要就报，不要就过——胡最大，其次碰杠，最后吃。")
            Text("自己摸到胡的那张叫自摸，其他人一起赔；别人打出来让你胡叫点炮，只有打牌那个人赔。")
            Text("变体开关在建房时勾：血战到底（胡了的人离场，剩下的接着打）、七对子、缺一门、杠上开花、带字牌、吃牌。默认只开吃牌。")
        }
        .font(.system(size: 12.5))
        .foregroundColor(QipaiPalette.ink.opacity(0.85))
        .lineSpacing(4)
    }
}
