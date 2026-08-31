import SwiftUI
import UIKit

// MARK: - 棋牌室风格零件库
// 古早味 6s：低饱和灰蓝、噪点雾面、波点底纹、iOS6 拟物玻璃。
// 棋牌室是自成一体的房间，不跟 AlcoveTheme 联动——她要的就是整间屋子一个味道。

enum QipaiPalette {
    /// 日夜开关：她在大厅点日月按钮切，持久化在 UserDefaults。
    /// 静态色全是计算属性，切换后靠大厅 .id(night) 整树重建生效；
    /// 牌桌只能从大厅进，不存在中途换肤的半吊子状态。
    static var night: Bool = UserDefaults.standard.bool(forKey: "qipai.night") {
        didSet { UserDefaults.standard.set(night, forKey: "qipai.night") }
    }
    private static func pick(_ day: UInt32, _ dark: UInt32) -> Color { qhex(night ? dark : day) }

    static var fog: Color       { pick(0xECEDF2, 0x20242E) }   // 底色·雾/夜
    static var panel: Color     { pick(0xF7F8FB, 0x2A2F3A) }   // 面板·白瓷/夜瓷
    static var panelDeep: Color { pick(0xE4E6ED, 0x222732) }   // 面板按下/凹陷
    static var ink: Color       { pick(0x585F6E, 0xD8DCE6) }   // 正文·石板/月白
    static var inkDim: Color    { pick(0x9AA0AD, 0x8A92A3) }   // 次要文字
    static var line: Color      { pick(0xD5D9E2, 0x3D4452) }   // 描边
    static var dot: Color       { pick(0xC7CBD6, 0x394050) }   // 波点
    static var accent: Color    { pick(0x7C8AA6, 0x93A5C8) }   // 点缀·灰蓝
    static var red: Color       { pick(0xC25B55, 0xD0736C) }   // 压过饱和的红
    static var glowRing: Color  { pick(0xAEB9D2, 0xBCC9E5) }   // 光环

    /// 座位色（0828 她要的：牌桌闲聊按发言人分色）。按入座顺序取，一局内稳定；
    /// 0 号就是原来的 accent 灰蓝，人少的桌观感不变。都压过饱和，不抢白瓷。
    private static let seatTonesDay:   [UInt32] = [0x7C8AA6, 0xC25B55, 0x6E9A87, 0xB08D57, 0x967FB0, 0x5F93A8]
    private static let seatTonesNight: [UInt32] = [0x93A5C8, 0xD0736C, 0x8FBCA9, 0xCCA97A, 0xB2A0CC, 0x84B4C8]
    static func seatTone(_ idx: Int) -> Color {
        let t = night ? seatTonesNight : seatTonesDay
        return qhex(t[abs(idx) % t.count])
    }

    // 组件里不好直接用主 token 的几处
    static var glossOpacity: Double { night ? 0.12 : 0.6 }              // 面板顶部高光
    static var chipBg: Color { night ? qhex(0x333A48).opacity(0.9) : .white.opacity(0.75) }
    static var buttonTop: Color { night ? qhex(0x3A4150) : .white }     // 凸起按钮亮面
    static var trackLight: Color { pick(0xEFF1F6, 0x2E3440) }           // 滑条轨道亮端
    static var fieldBg: Color { night ? qhex(0x2F3542) : .white }       // 输入框底（夜里白框太刺眼，0828 她抓的）
    static var shadowTint: Color { night ? .black : qhex(0x585F6E) }    // 阴影固定深色：夜里 ink 是月白，拿它当阴影会变白光晕

    static func qhex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255)
    }
}

// MARK: 噪点（那种"不是特别特别清晰"的颗粒感）

enum QipaiTexture {
    static let noise: UIImage = {
        let side = 144
        var pixels = [UInt8](repeating: 0, count: side * side * 2) // gray + alpha
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<(side * side) {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let r = UInt8((seed >> 33) & 0xFF)
            let a = UInt8((seed >> 41) % 22)             // 都很淡
            // 预乘格式：颜色分量不能超过 alpha，超了会渲成一屏爆白雪花（0828 踩过）
            pixels[i * 2] = r > 128 ? a : 0              // 亮点或暗点
            pixels[i * 2 + 1] = a
        }
        let ctx = CGContext(data: &pixels, width: side, height: side,
                            bitsPerComponent: 8, bytesPerRow: side * 2,
                            space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return UIImage(cgImage: ctx.makeImage()!)
    }()
}

extension View {
    /// 铺一层颗粒噪点。盖在任何背景最上面用。
    func qipaiGrain(_ opacity: Double = 0.55) -> some View {
        overlay(
            Image(uiImage: QipaiTexture.noise)
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                .allowsHitTesting(false)
        )
    }
}

// MARK: 波点底纹

struct QipaiDots: View {
    var spacing: CGFloat = 14
    var radius: CGFloat = 1.6
    var color: Color = QipaiPalette.dot
    var opacity: Double = 0.55

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = spacing / 2
            var row = 0
            while y < size.height + spacing {
                var x: CGFloat = (row % 2 == 0) ? spacing / 2 : spacing
                while x < size.width + spacing {
                    let rect = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing * 0.86
                row += 1
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

// MARK: 白瓷面板（卡片底座）

struct QipaiPanelModifier: ViewModifier {
    var corner: CGFloat = 18
    var dotted: Bool = false
    var translucent: Bool = false   // 磨砂半透明：透出壁纸（0828 她要的房間区效果）

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if translucent {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(QipaiPalette.panel.opacity(
                            translucent ? (QipaiPalette.night ? 0.72 : 0.55) : 1))
                    if dotted { QipaiDots(opacity: 0.3)
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous)) }
                    // 顶部一道很浅的高光，让面板微微凸起
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0)],
                                             startPoint: .top, endPoint: .center))
                        .padding(1)
                        .opacity(QipaiPalette.glossOpacity)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(QipaiPalette.line, lineWidth: 1))
            .shadow(color: QipaiPalette.shadowTint.opacity(0.10), radius: 7, y: 3)
    }
}

extension View {
    func qipaiPanel(corner: CGFloat = 18, dotted: Bool = false, translucent: Bool = false) -> some View {
        modifier(QipaiPanelModifier(corner: corner, dotted: dotted, translucent: translucent))
    }
}

// MARK: 拟物玻璃方块（图标底座，iOS6 那口味）

struct QipaiGlassTile<Content: View>: View {
    var corner: CGFloat = 20
    var gloss: Double = 0.5
    @ViewBuilder var content: Content

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                // 上半截玻璃高光：老 iOS 图标的灵魂
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(gloss), .white.opacity(gloss * 0.24), .clear],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: geo.size.height * 0.46)
                        .padding(.horizontal, 1)
                        .padding(.top, 1)
                }
                .allowsHitTesting(false)
            )
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 1.2)
                .padding(0.8))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(QipaiPalette.line, lineWidth: 1))
            .shadow(color: QipaiPalette.shadowTint.opacity(0.22), radius: 5, y: 3)
    }
}

// MARK: 拟物凸起按钮

struct QipaiEmbossedButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(prominent ? .white : QipaiPalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(
                    prominent
                    ? LinearGradient(colors: pressed
                                     ? [QipaiPalette.qhex(0x66748F), QipaiPalette.qhex(0x8291AC)]
                                     : [QipaiPalette.qhex(0x93A1BB), QipaiPalette.qhex(0x6D7B96)],
                                     startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: pressed
                                     ? [QipaiPalette.panelDeep, QipaiPalette.panel]
                                     : [QipaiPalette.buttonTop, QipaiPalette.panelDeep],
                                     startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(Capsule().stroke(prominent ? QipaiPalette.qhex(0x5D6A83) : QipaiPalette.line,
                                      lineWidth: 1))
            .overlay(Capsule().strokeBorder(.white.opacity(pressed ? 0.2 : 0.65), lineWidth: 1)
                .padding(1).mask(Capsule().padding(1)))
            .shadow(color: QipaiPalette.shadowTint.opacity(pressed ? 0.05 : 0.18),
                    radius: pressed ? 1 : 3, y: pressed ? 0.5 : 2)
            .scaleEffect(pressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

// MARK: 状态小胶囊（等人中 / 进行中 / 已结束 / AI 在座…）

struct QipaiChip: View {
    enum Tone { case neutral, live, done, red }
    var text: String
    var tone: Tone = .neutral
    var icon: String? = nil

    private var fg: Color {
        switch tone {
        case .neutral: return QipaiPalette.inkDim
        case .live: return QipaiPalette.accent
        case .done: return QipaiPalette.inkDim.opacity(0.8)
        case .red: return QipaiPalette.red
        }
    }

    var body: some View {
        HStack(spacing: 3.5) {
            if let icon { Image(systemName: icon).font(.system(size: 8.5, weight: .semibold)) }
            Text(text).font(.system(size: 10.5, weight: .medium))
        }
        .foregroundColor(fg)
        .padding(.horizontal, 8).padding(.vertical, 3.5)
        .background(Capsule().fill(QipaiPalette.chipBg))
        .overlay(Capsule().stroke(fg.opacity(0.45), lineWidth: 0.8))
    }
}

// MARK: slide to start（古早解锁滑条）

struct QipaiSlideControl: View {
    var label: String
    var onComplete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var shimmerX: CGFloat = -90
    @GestureState private var dragging = false

    private let height: CGFloat = 46
    private let knob: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            let travel = geo.size.width - knob - 6
            ZStack {
                // 凹槽轨道
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(LinearGradient(colors: [QipaiPalette.panelDeep, QipaiPalette.trackLight],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: height / 2)
                        .stroke(QipaiPalette.line, lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: height / 2)
                        .strokeBorder(QipaiPalette.ink.opacity(0.1), lineWidth: 1.5)
                        .blur(radius: 1).padding(1)
                        .mask(RoundedRectangle(cornerRadius: height / 2)
                            .fill(LinearGradient(colors: [.black, .clear],
                                                 startPoint: .top, endPoint: .bottom))))

                // 流光文字
                Text(label)
                    .font(.qipaiHand(14))
                    .foregroundColor(QipaiPalette.inkDim)
                    .overlay(
                        LinearGradient(colors: [.clear, .white.opacity(0.9), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                        .frame(width: 60)
                        .offset(x: shimmerX)
                        .mask(Text(label).font(.qipaiHand(14)))
                    )
                    .opacity(1 - Double(offset / max(travel, 1)) * 1.6)
                    // 0828 降温：原来 repeatForever，页面挂多久就逼着这块 60fps 重绘多久
                    //（光环同款病）。改成扫三遍就歇——提示到了就行，等人页挂着不再烫手。
                    .task {
                        for _ in 0..<3 {
                            if Task.isCancelled { return }
                            withAnimation(.linear(duration: 1.9)) { shimmerX = 90 }
                            try? await Task.sleep(nanoseconds: 2_300_000_000)
                            var t = Transaction()
                            t.disablesAnimations = true
                            withTransaction(t) { shimmerX = -90 }
                            try? await Task.sleep(nanoseconds: 400_000_000)
                        }
                    }

                // 玻璃滑块
                HStack {
                    QipaiGlassTile(corner: knob / 2 - 3, gloss: 0.65) {
                        ZStack {
                            RoundedRectangle(cornerRadius: knob / 2 - 3)
                                .fill(LinearGradient(colors: [.white, QipaiPalette.qhex(0xE8EAF1)],
                                                     startPoint: .top, endPoint: .bottom))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(QipaiPalette.accent)
                        }
                        .frame(width: knob - 6, height: knob - 6)
                    }
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .updating($dragging) { _, s, _ in s = true }
                            .onChanged { v in
                                offset = min(max(0, v.translation.width), travel)
                            }
                            .onEnded { _ in
                                if offset > travel * 0.86 {
                                    offset = travel
                                    onComplete()
                                    withAnimation(.easeOut(duration: 0.3).delay(0.35)) { offset = 0 }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        offset = 0
                                    }
                                }
                            }
                    )
                    Spacer(minLength: 0)
                }
                .padding(.leading, 3)
            }
        }
        .frame(height: height)
    }
}

// MARK: 下家是谁（六张牌桌共用）

/// 0831 陈霁：「只说顺时针逆时针我真的分不清」——每张牌桌都要把下家的名字直接点出来。
/// 从 anchor（有座位就是她自己，观战就锚在当前行动的人身上）沿 dir 走一格，
/// 跳过这一轮里已经出局／出完／弃牌的人；绕回自己还没找到就返回 nil（场上只剩一个人了）。
enum QipaiSeatOrder {
    static func next(order: [String], from anchor: String?, dir: Int = 1,
                     isActive: (String) -> Bool = { _ in true }) -> String? {
        guard order.count > 1, let a = anchor,
              let i = order.firstIndex(of: a) else { return nil }
        let n = order.count
        let step = dir < 0 ? -1 : 1
        for k in 1...n {
            let id = order[((i + step * k) % n + n) % n]
            if id == a { break }
            if isActive(id) { return id }
        }
        return nil
    }

    /// "你的下家 阿黑" / 观战时锚在别人身上，就只写 "下家 阿黑"
    static func label(_ name: String, mine: Bool) -> String {
        (mine ? "你的下家 " : "下家 ") + name
    }
}

// MARK: 光环（轮到谁，谁头上亮）

struct QipaiHalo: View {
    var active: Bool
    @State private var breathe = false

    // 0829 她说牌桌烫手：原来不管活跃与否都在 repeatForever 地动画阴影半径，
    // 三四个座位常年逼着整页 60fps 重绘。现在不活跃只占位不动画，
    // 活跃时也只呼吸透明度（阴影固定），便宜一个数量级。
    var body: some View {
        Group {
            if active {
                Ellipse()
                    .strokeBorder(
                        LinearGradient(colors: [.white, QipaiPalette.glowRing],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 2.4)
                    .shadow(color: QipaiPalette.glowRing.opacity(0.9), radius: 4)
                    .opacity(breathe ? 1 : 0.5)
                    .onAppear {
                        breathe = false
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            breathe = true
                        }
                    }
                    .onDisappear { breathe = false }
            } else {
                Color.clear
            }
        }
        .frame(width: 30, height: 10)
    }
}

// MARK: 手写字体三件套（都是日文字体，只有繁体字形——所以固定文案一律繁体，
// 0828 陈霁拍板。服务器发来的动态字符串（房名/玩家名/规则名）是简体，
// 一律走系统字体，不上这三款，免得缺字混排。）

extension Font {
    /// たぬゴ：英文小句、数字、slide 滑条
    static func qipaiHand(_ size: CGFloat) -> Font {
        .custom("Tanugo-S-TTF-Regular", size: size)
    }
    /// 赤薔薇シンデレラ：大字（标题、地主勝这类）
    static func qipaiDisplay(_ size: CGFloat) -> Font {
        .custom("CQW-Akabara", size: size)
    }
    /// 中文小标题。原本给仕事メモ書き，0828 发现它一堆字有映射但字形是空白的
    /// （炸/桌/麼/閒…直接消失），退役改用 Tanugo——它是三款里唯一零空字形的。
    static func qipaiMemo(_ size: CGFloat) -> Font {
        .custom("Tanugo-S-TTF-Regular", size: size)
    }
}

// MARK: 丧甜小字（角落里的那种）

struct QipaiWhisper: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.qipaiHand(11))
            .tracking(0.6)
            .foregroundColor(QipaiPalette.inkDim.opacity(0.9))
    }
}
