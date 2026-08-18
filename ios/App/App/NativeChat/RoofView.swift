import SwiftUI
import UIKit
import CoreHaptics

// 檐上（2026-08-18 她拍的板）——陈檐住的那一层。
//
// 名字是从同一句话里长出来的：霁是雨停，璟是玉生光，檐是下雨时猫蹲着等雨停
// 的地方。雨还在下的时候猫在檐下躲雨，雨停了猫爬上去晒太阳 —— 所以檐下是
// 念头池，檐上是猫，一上一下同一个屋檐。抽屉里两格并排，檐上在檐下上面。
//
// 她 08-13 深夜拍的三条，这一版落第一期：两个人都能喂、都能撸（每一下记
// 名字）、单开一页、活动慢慢加。
//
// 撸的手感是这次从 PWA 重做真正赚到的东西：网页里撸猫只是点一下数字加一，
// 这里手指划过去有 Core Haptics 跟着，撸够了转成连续的呼噜震动。皮等何渡，
// 这版先自己画一只能睡能醒能摆尾巴的。

// MARK: - 配色（跟檐下的冷蓝成对：那边是雨里，这边是雨停后的黄昏）

private struct RoofPalette {
    let isDark: Bool
    let ink: Color
    let ink2: Color
    let ink3: Color
    let acc: Color          // 屋瓦的红褐
    let warm: Color         // 太阳
    let glass: Color
    let line: Color
    let skyTop: Color
    let skyMid: Color
    let skyBottom: Color
    let tile: Color         // 瓦
    let deep: Color         // 瓦底下那片，UI 坐在上面
    let onDeep: Color       // 坐在 deep 上的字
    let onDeepDim: Color
    let deepGlass: Color
    let deepLine: Color
    let cat: Color
    let catDark: Color

    static func named(_ themeName: String) -> RoofPalette {
        AlcoveTheme.named(themeName).isDark ? .dusk : .day
    }

    static let day = RoofPalette(
        isDark: false,
        ink: Color(red: 0x3A/255, green: 0x2C/255, blue: 0x24/255),
        ink2: Color(red: 0x6B/255, green: 0x56/255, blue: 0x48/255),
        ink3: Color(red: 0x9C/255, green: 0x87/255, blue: 0x77/255),
        acc: Color(red: 0xB5/255, green: 0x6B/255, blue: 0x45/255),
        warm: Color(red: 0xE8/255, green: 0xA9/255, blue: 0x5C/255),
        glass: Color.white.opacity(0.46),
        line: Color.white.opacity(0.70),
        skyTop: Color(red: 0xFD/255, green: 0xF6/255, blue: 0xEC/255),
        skyMid: Color(red: 0xF8/255, green: 0xE7/255, blue: 0xD2/255),
        skyBottom: Color(red: 0xEE/255, green: 0xCF/255, blue: 0xB0/255),
        tile: Color(red: 0x6E/255, green: 0x72/255, blue: 0x78/255),
        deep: Color(red: 0x2B/255, green: 0x28/255, blue: 0x2A/255),
        onDeep: Color(red: 0xF2/255, green: 0xEB/255, blue: 0xE3/255),
        onDeepDim: Color(red: 0xA8/255, green: 0x9E/255, blue: 0x96/255),
        deepGlass: Color.white.opacity(0.09),
        deepLine: Color.white.opacity(0.15),
        cat: Color(red: 0x8C/255, green: 0x6B/255, blue: 0x56/255),
        catDark: Color(red: 0x5E/255, green: 0x45/255, blue: 0x36/255))

    static let dusk = RoofPalette(
        isDark: true,
        ink: Color(red: 0xF0/255, green: 0xE6/255, blue: 0xDA/255),
        ink2: Color(red: 0xC4/255, green: 0xB2/255, blue: 0xA0/255),
        ink3: Color(red: 0x93/255, green: 0x83/255, blue: 0x74/255),
        acc: Color(red: 0xD8/255, green: 0x8E/255, blue: 0x5E/255),
        warm: Color(red: 0xF2/255, green: 0xB8/255, blue: 0x6A/255),
        glass: Color(red: 42/255, green: 32/255, blue: 28/255).opacity(0.52),
        line: Color(red: 235/255, green: 200/255, blue: 170/255).opacity(0.22),
        skyTop: Color(red: 0x2A/255, green: 0x22/255, blue: 0x2E/255),
        skyMid: Color(red: 0x3E/255, green: 0x2C/255, blue: 0x30/255),
        skyBottom: Color(red: 0x5A/255, green: 0x38/255, blue: 0x30/255),
        tile: Color(red: 0x39/255, green: 0x3F/255, blue: 0x52/255),
        deep: Color(red: 0x15/255, green: 0x17/255, blue: 0x22/255),
        onDeep: Color(red: 0xE9/255, green: 0xE3/255, blue: 0xD9/255),
        onDeepDim: Color(red: 0x8E/255, green: 0x8A/255, blue: 0x84/255),
        deepGlass: Color.white.opacity(0.07),
        deepLine: Color.white.opacity(0.12),
        cat: Color(red: 0xB4/255, green: 0x8E/255, blue: 0x72/255),
        catDark: Color(red: 0x7A/255, green: 0x5C/255, blue: 0x48/255))
}

// MARK: - 数据

private struct RoofLogEntry: Identifiable {
    let id: String
    let whoName: String
    let action: String
    let detail: String
    let createdAt: String
}

private struct RoofLoot: Identifiable {
    let id = UUID()
    let item: String
    let rarity: String

    var isSpecial: Bool { rarity == "once" || rarity == "rare" }
    var mark: String {
        switch rarity {
        case "once": return "只此一件"
        case "rare": return "少见"
        case "uncommon": return "不常有"
        default: return ""
        }
    }
}

private struct RoofTrip {
    let id: String
    let place: String
    let dueText: String
    let away: Bool
    let art: String
    let seen: Bool
    let loot: [RoofLoot]

    init(_ raw: [String: Any]) {
        id = raw.string("id")
        place = raw.string("place")
        dueText = raw.string("dueText")
        away = raw.bool("away")
        art = raw.string("art")
        seen = raw.bool("seen")
        loot = raw.array("loot").map {
            RoofLoot(item: $0.string("item"), rarity: $0.string("rarity"))
        }
    }
}

private struct StashItem: Identifiable {
    let id: String
    let item: String
    let rarity: String
    let place: String
    let count: Int
}

private struct RoofCat {
    var name = "陈檐"
    var hunger = 70
    var coat = 80
    var energy = 70
    var intimacy = 0
    var asleep = false
    var spot = "roof"
    var spotText = ""
    var mood = ""
    var says = "喵～"
    var fedCount = 0
    var petCount = 0
    var lastFedByName = ""
    var lastPetByName = ""
    var log: [RoofLogEntry] = []
    var away = false
    var trip: RoofTrip?
    var lastTrip: RoofTrip?

    init() {}

    init(_ raw: [String: Any]) {
        name = raw.string("name")
        hunger = raw.int("hunger")
        coat = raw.int("coat")
        energy = raw.int("energy")
        intimacy = raw.int("intimacy")
        asleep = raw.bool("asleep")
        spot = raw.string("spot")
        spotText = raw.string("spotText")
        mood = raw.string("mood")
        says = raw.string("says")
        fedCount = raw.int("fedCount")
        petCount = raw.int("petCount")
        lastFedByName = raw.string("lastFedByName")
        lastPetByName = raw.string("lastPetByName")
        away = raw.bool("away")
        if let t = raw["trip"] as? [String: Any] { trip = RoofTrip(t) }
        if let t = raw["lastTrip"] as? [String: Any] { lastTrip = RoofTrip(t) }
        log = raw.array("log").map {
            RoofLogEntry(id: $0.string("id"), whoName: $0.string("whoName"),
                         action: $0.string("action"), detail: $0.string("detail"),
                         createdAt: $0.string("createdAt"))
        }
    }
}

// MARK: - 手感

/// 撸猫的震动。一下一下的是毛被顺过去，连起来的是呼噜。
private final class RoofHaptics {
    static let shared = RoofHaptics()

    private var engine: CHHapticEngine?
    private var purring: CHHapticAdvancedPatternPlayer?
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.playsHapticsOnly = true
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            guard let self else { return }
            try? self.engine?.start()
        }
        try? engine?.start()
        light.prepare()
        soft.prepare()
    }

    /// 手指划过一段毛。intensity 跟着猫舒不舒服走。
    func stroke(_ intensity: Float) {
        guard let engine else {
            soft.impactOccurred(intensity: CGFloat(intensity))
            return
        }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: intensity),
            .init(parameterID: .hapticSharpness, value: 0.28),
        ], relativeTime: 0)
        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        } else {
            soft.impactOccurred(intensity: CGFloat(intensity))
        }
    }

    /// 呼噜：低频连续，一直响到手拿开。
    func startPurr() {
        guard let engine, purring == nil else { return }
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: 0.42),
            .init(parameterID: .hapticSharpness, value: 0.06),
        ], relativeTime: 0, duration: 8)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player = try? engine.makeAdvancedPlayer(with: pattern) else { return }
        player.loopEnabled = true
        try? player.start(atTime: 0)
        purring = player
    }

    func stopPurr() {
        try? purring?.stop(atTime: 0)
        purring = nil
    }

    func tap() { light.impactOccurred() }
}

// MARK: - 猫

/// 自己画的。何渡出皮之前先用这只：会蜷、会坐、会摆尾巴、被撸会陷下去。
private struct CatShape: View {
    let palette: RoofPalette
    let asleep: Bool
    let squish: CGFloat       // 被按下去的程度 0…1
    let tailPhase: CGFloat    // 尾巴摆动相位
    let turnedAway: Bool      // 闹别扭时背对着

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                if asleep {
                    curled(w: w, h: h)
                } else {
                    sitting(w: w, h: h)
                }
            }
            .scaleEffect(x: 1 + squish * 0.06, y: 1 - squish * 0.09, anchor: .bottom)
            .scaleEffect(x: turnedAway ? -1 : 1, y: 1)
        }
    }

    // 蜷成一团睡
    private func curled(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(palette.cat)
                .frame(width: w * 0.86, height: h * 0.52)
                .offset(y: h * 0.16)
            // 盖住鼻子的尾巴
            Capsule()
                .fill(palette.catDark)
                .frame(width: w * 0.62, height: h * 0.10)
                .rotationEffect(.degrees(-8))
                .offset(x: -w * 0.04, y: h * 0.30)
            // 头埋着
            Circle()
                .fill(palette.cat)
                .frame(width: w * 0.34)
                .offset(x: -w * 0.24, y: h * 0.14)
            ear(w: w * 0.11).offset(x: -w * 0.33, y: h * 0.01)
            ear(w: w * 0.11).offset(x: -w * 0.15, y: -h * 0.01)
            // 闭着的眼
            closedEye.offset(x: -w * 0.30, y: h * 0.15)
            closedEye.offset(x: -w * 0.17, y: h * 0.15)
        }
    }

    // 坐着
    private func sitting(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // 尾巴，一晃一晃
            TailPath(phase: tailPhase)
                .stroke(palette.catDark, style: StrokeStyle(lineWidth: w * 0.075, lineCap: .round))
                .frame(width: w * 0.55, height: h * 0.42)
                .offset(x: w * 0.34, y: h * 0.20)
            // 身体
            Ellipse()
                .fill(palette.cat)
                .frame(width: w * 0.56, height: h * 0.56)
                .offset(y: h * 0.20)
            // 前爪
            Capsule().fill(palette.catDark.opacity(0.75))
                .frame(width: w * 0.10, height: h * 0.09)
                .offset(x: -w * 0.10, y: h * 0.44)
            Capsule().fill(palette.catDark.opacity(0.75))
                .frame(width: w * 0.10, height: h * 0.09)
                .offset(x: w * 0.06, y: h * 0.44)
            // 头
            Circle()
                .fill(palette.cat)
                .frame(width: w * 0.44)
                .offset(y: -h * 0.14)
            ear(w: w * 0.15).offset(x: -w * 0.15, y: -h * 0.31)
            ear(w: w * 0.15).offset(x: w * 0.15, y: -h * 0.31)
            // 眼睛：被撸的时候眯起来
            if squish > 0.25 {
                closedEye.offset(x: -w * 0.09, y: -h * 0.16)
                closedEye.offset(x: w * 0.09, y: -h * 0.16)
            } else {
                eye.offset(x: -w * 0.09, y: -h * 0.16)
                eye.offset(x: w * 0.09, y: -h * 0.16)
            }
            // 鼻子
            Triangle()
                .fill(palette.acc.opacity(0.85))
                .frame(width: w * 0.05, height: w * 0.04)
                .rotationEffect(.degrees(180))
                .offset(y: -h * 0.09)
        }
    }

    private func ear(w: CGFloat) -> some View {
        Triangle()
            .fill(palette.cat)
            .frame(width: w, height: w * 1.05)
            .overlay(
                Triangle()
                    .fill(palette.acc.opacity(0.30))
                    .frame(width: w * 0.5, height: w * 0.52)
                    .offset(y: w * 0.22)
            )
    }

    private var eye: some View {
        Capsule()
            .fill(palette.catDark)
            .frame(width: 5.5, height: 8)
    }

    private var closedEye: some View {
        Capsule()
            .fill(palette.catDark)
            .frame(width: 9, height: 2.2)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct TailPath: Shape {
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let sway = sin(phase) * rect.width * 0.30
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.maxX * 0.72 + sway, y: rect.minY),
            control1: CGPoint(x: rect.midX, y: rect.maxY),
            control2: CGPoint(x: rect.maxX + sway, y: rect.midY))
        return p
    }
}

// MARK: - 屋顶

private struct RoofTiles: View {
    let palette: RoofPalette

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [palette.tile, palette.deep],
                    startPoint: .top, endPoint: .bottom)
                // 瓦垄
                ForEach(1..<11, id: \.self) { i in
                    Rectangle()
                        .fill(Color.black.opacity(palette.isDark ? 0.26 : 0.17))
                        .frame(width: 1.6, height: geo.size.height)
                        .offset(x: w * CGFloat(i) / 11 - w / 2)
                }
                // 横向搭接，一行错开半格
                ForEach(0..<7, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<11, id: \.self) { _ in
                            TileArc()
                                .stroke(Color.black.opacity(palette.isDark ? 0.22 : 0.14),
                                        lineWidth: 1.4)
                                .frame(width: w / 11, height: 13)
                        }
                    }
                    .offset(x: row % 2 == 0 ? 0 : w / 22, y: 22 + CGFloat(row) * 26)
                }
            }
            .overlay(alignment: .top) {
                // 檐口那道被夕阳照亮的边
                Rectangle()
                    .fill(palette.warm.opacity(palette.isDark ? 0.42 : 0.80))
                    .frame(height: 3)
            }
            .clipped()
        }
    }
}

private struct TileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        return p
    }
}

// MARK: - 页面

struct NativeRoofView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName = "haven"

    @State private var cat = RoofCat()
    @State private var loading = true
    @State private var failed = false
    @State private var note = ""              // 猫拒绝你的时候那句
    @State private var squish: CGFloat = 0
    @State private var tailPhase: CGFloat = 0
    @State private var strokes = 0
    @State private var lastStrokePoint: CGPoint = .zero
    @State private var purring = false
    @State private var showLog = false
    @State private var showStash = false

    private let haptics = RoofHaptics.shared
    private var palette: RoofPalette { .named(themeName) }
    /// 她是 ji。这一页从 app 上按下去的每一下都记在她名下
    private let me = "ji"

    private enum Layout {
        static let sky: CGFloat = 0.545     // 天空到这儿
        static let tile: CGFloat = 0.245    // 瓦这么厚
        static let foot: CGFloat = 0.705    // 猫的脚踩在这个高度
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                backdrop(geo.size)
                if !loading && !failed {
                    if cat.away {
                        emptyNest(geo.size)
                    } else {
                        catLayer(geo.size)
                    }
                }
                content
                if let trip = homecoming {
                    homecomingCard(trip)
                }
            }
        }
        .ignoresSafeArea()
        .task { await load() }
        .onAppear { swingTail() }
        .sheet(isPresented: $showStash) { StashSheet(palette: palette) }
    }

    // 天空是画的，瓦是代码画的，下面那片留给 UI
    private func backdrop(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            AsyncImage(url: AlcoveAPI.fullURL(
                "/api/roof/art/" + (palette.isDark ? "sky_night" : "sky_day") + ".jpg")
            ) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(colors: [palette.skyTop, palette.skyMid, palette.skyBottom],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(width: size.width, height: size.height * Layout.sky)
            .clipped()
            RoofTiles(palette: palette)
                .frame(height: size.height * Layout.tile)
            palette.deep
        }
    }

    // 它不在的时候，这儿就该是空的
    private func emptyNest(_ size: CGSize) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(palette.isDark ? 0.30 : 0.20))
                    .frame(width: 96, height: 34)
                    .blur(radius: 3)
                Ellipse()
                    .stroke(palette.warm.opacity(0.22), lineWidth: 1)
                    .frame(width: 84, height: 27)
            }
            Text("不在家")
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(palette.onDeep.opacity(0.85))
            Text(cat.trip.map { $0.dueText } ?? "")
                .font(.system(size: 11))
                .foregroundColor(palette.onDeepDim)
            if let place = cat.trip?.place, !place.isEmpty {
                Text("去了" + place)
                    .font(.system(size: 10.5))
                    .foregroundColor(palette.onDeepDim.opacity(0.75))
                    .padding(.top, 2)
            }
        }
        .position(x: size.width * 0.5, y: size.height * Layout.foot - 26)
    }

    // 猫。图挂了就退回自己画的那只，页面不会空
    private func catLayer(_ size: CGSize) -> some View {
        let w = size.width * catWidth
        let h = w * catAspect
        return ZStack {
            if cat.hunger < 30 {
                bowl.position(x: size.width * (catX > 0.5 ? 0.26 : 0.74),
                              y: size.height * Layout.foot - 8)
            }
            AsyncImage(url: AlcoveAPI.fullURL("/api/roof/art/" + catArt + ".png")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    CatShape(palette: palette, asleep: cat.asleep, squish: squish,
                             tailPhase: tailPhase, turnedAway: cat.spot == "ridge")
                }
            }
            .frame(width: w, height: h)
            .scaleEffect(x: 1 + squish * 0.05, y: 1 - squish * 0.08, anchor: .bottom)
            .shadow(color: .black.opacity(palette.isDark ? 0.45 : 0.30), radius: 12, y: 8)
            .position(x: size.width * catX, y: size.height * Layout.foot - h / 2)
            .gesture(petGesture)
            speech.position(x: size.width * catX,
                            y: size.height * Layout.foot - h - 18)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: cat.spot)
        .animation(.easeInOut(duration: 0.3), value: cat.asleep)
    }

    /// 它回来了、东西还没被看过 —— 这张卡压在页面上等她点
    private var homecoming: RoofTrip? {
        guard !cat.away, let t = cat.lastTrip, !t.seen, !t.loot.isEmpty else { return nil }
        return t
    }

    private func homecomingCard(_ trip: RoofTrip) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { Task { await closeHomecoming(trip) } }
            VStack(spacing: 0) {
                if !trip.art.isEmpty {
                    AsyncImage(url: AlcoveAPI.fullURL("/api/roof/art/trips/" + trip.art)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            palette.tile.opacity(0.5)
                        }
                    }
                    .frame(height: 168)
                    .clipped()
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("檐檐回来了")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundColor(palette.onDeep)
                    Text("去了" + trip.place)
                        .font(.system(size: 11))
                        .foregroundColor(palette.onDeepDim)
                    Divider().background(palette.deepLine).padding(.vertical, 2)
                    ForEach(trip.loot) { loot in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(loot.isSpecial ? palette.warm : palette.onDeepDim)
                                .frame(width: 5, height: 5)
                            Text(loot.item)
                                .font(.system(size: 13,
                                              weight: loot.isSpecial ? .medium : .regular))
                                .foregroundColor(palette.onDeep)
                            if !loot.mark.isEmpty {
                                Text(loot.mark)
                                    .font(.system(size: 9))
                                    .foregroundColor(palette.warm)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(palette.warm.opacity(0.14)))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    Button {
                        Task { await closeHomecoming(trip) }
                    } label: {
                        Text("收进百宝箱")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(palette.onDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.deepGlass))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(palette.deepLine, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(15)
            }
            .background(palette.deep)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.deepLine, lineWidth: 0.8))
            .padding(.horizontal, 26)
            .shadow(color: .black.opacity(0.5), radius: 26, y: 12)
        }
        .transition(.opacity)
    }

    private var catArt: String {
        if cat.asleep { return "cat_curled" }
        switch cat.spot {
        case "ridge": return "cat_back"
        case "bowl": return "cat_sit"
        default: return "cat_lying"
        }
    }

    private var catAspect: CGFloat {
        switch catArt {
        case "cat_curled": return 1.09
        case "cat_sit": return 1.08
        case "cat_back": return 0.99
        default: return 0.84
        }
    }

    private var catWidth: CGFloat {
        switch catArt {
        case "cat_curled": return 0.40
        case "cat_sit": return 0.34
        case "cat_back": return 0.36
        default: return 0.46
        }
    }

    private var catX: CGFloat {
        switch cat.spot {
        case "ridge": return 0.74      // 爬远了，够不着
        case "bowl": return 0.32
        default: return 0.50
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            if loading {
                ProgressView().tint(palette.onDeepDim)
                Spacer(minLength: 0)
            } else if failed {
                Text("没连上，下拉再试一次")
                    .font(.system(size: 13))
                    .foregroundColor(palette.onDeepDim)
                Spacer(minLength: 0)
            } else {
                statusRow
                buttons
                if showLog { logList } else { logHint }
            }
            Spacer(minLength: 16)
        }
        .padding(.bottom, 22)
    }

    // 自己做头（ownsFullScreen）。这一条压在天空上，用天空那套字色
    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(palette.ink2)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text("檐上")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                Text(cat.mood.isEmpty ? "雨停了，猫爬上来了" : cat.name + " · " + cat.mood)
                    .font(.system(size: 10.5))
                    .foregroundColor(palette.ink2)
            }
            Spacer()
            Button { showStash = true } label: {
                Image(systemName: "shippingbox")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(palette.ink2)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").font(.system(size: 9))
                Text("\(cat.intimacy)").font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(palette.acc)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(palette.glass))
            .overlay(Capsule().stroke(palette.line, lineWidth: 0.7))
        }
        .padding(.horizontal, 14)
        .padding(.top, 54)
        .padding(.bottom, 6)
    }

    private var bowl: some View {
        ZStack {
            Ellipse()
                .fill(palette.deep.opacity(0.75))
                .frame(width: 44, height: 17)
            Ellipse()
                .fill(palette.tile)
                .frame(width: 33, height: 9)
                .offset(y: -3)
        }
    }

    private var speech: some View {
        Text(cat.says)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(palette.ink2)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(palette.glass))
            .overlay(Capsule().stroke(palette.line, lineWidth: 0.7))
            .animation(.easeOut(duration: 0.25), value: cat.says)
    }

    // 撸：手指划过去，每划一段震一下；撸够了它开始呼噜，一直响到手拿开
    private var petGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if cat.spot == "ridge" { return }   // 够不着
                let p = CGPoint(x: value.translation.width, y: value.translation.height)
                let moved = hypot(p.x - lastStrokePoint.x, p.y - lastStrokePoint.y)
                guard moved > 24 else { return }
                lastStrokePoint = p
                strokes += 1
                haptics.stroke(cat.asleep ? 0.22 : 0.46)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                    squish = min(1, squish + 0.34)
                }
                if strokes >= 3 && !purring && !cat.asleep {
                    purring = true
                    haptics.startPurr()
                }
            }
            .onEnded { _ in
                lastStrokePoint = .zero
                withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) { squish = 0 }
                haptics.stopPurr()
                purring = false
                let n = strokes
                strokes = 0
                guard n > 0 else { return }
                Task { await pet(strokes: n) }
            }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            meter("饿", cat.hunger, "fork.knife")
            meter("毛", cat.coat, "wind")
            meter("精神", cat.energy, "moon.zzz")
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }

    private func meter(_ label: String, _ value: Int, _ icon: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(palette.onDeepDim)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.onDeepDim.opacity(0.18))
                    Capsule()
                        .fill(value < 25 ? palette.warm : palette.warm)
                        .frame(width: max(3, geo.size.width * CGFloat(value) / 100))
                }
            }
            .frame(height: 5)
            .animation(.easeOut(duration: 0.4), value: value)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(palette.deepGlass))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(palette.deepLine, lineWidth: 0.7))
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            if !note.isEmpty {
                Text(note)
                    .font(.system(size: 11.5))
                    .foregroundColor(palette.onDeepDim)
                    .transition(.opacity)
            }
            HStack(spacing: 9) {
                actionButton("喂饭", "fork.knife") { Task { await feed() } }
                actionButton(cat.asleep ? "叫醒" : "哄睡", cat.asleep ? "sun.max" : "moon.stars") {
                    Task { await sleepToggle() }
                }
            }
            .opacity(cat.away ? 0.4 : 1)
            .disabled(cat.away)
            Text(cat.away ? "催不了它，只能等" : "撸它 —— 手指在猫身上划")
                .font(.system(size: 10))
                .foregroundColor(palette.onDeepDim.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private func actionButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(title).font(.system(size: 13.5, weight: .medium))
            }
            .foregroundColor(palette.onDeep)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.deepGlass))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.deepLine, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private var logHint: some View {
        Button { withAnimation { showLog = true } } label: {
            HStack(spacing: 5) {
                Text(lastCareLine)
                    .font(.system(size: 11))
                Image(systemName: "chevron.down").font(.system(size: 8))
            }
            .foregroundColor(palette.onDeepDim)
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }

    private var lastCareLine: String {
        if !cat.lastFedByName.isEmpty { return "上一顿是\(cat.lastFedByName)喂的" }
        if !cat.lastPetByName.isEmpty { return "\(cat.lastPetByName)刚撸过它" }
        return "还没人管过它"
    }

    private var logList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation { showLog = false } } label: {
                HStack(spacing: 5) {
                    Text("谁管过它").font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.up").font(.system(size: 8))
                }
                .foregroundColor(palette.onDeepDim)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(cat.log) { entry in
                        HStack(spacing: 7) {
                            Text(entry.whoName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(entry.whoName == "陈霁" ? palette.warm : palette.onDeep)
                            Text(entry.detail)
                                .font(.system(size: 11))
                                .foregroundColor(palette.onDeep)
                            Spacer(minLength: 0)
                            Text(shortTime(entry.createdAt))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(palette.onDeepDim)
                        }
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private func shortTime(_ iso: String) -> String {
        guard iso.count >= 16 else { return "" }
        let start = iso.index(iso.startIndex, offsetBy: 5)
        let end = iso.index(iso.startIndex, offsetBy: 16)
        return String(iso[start..<end]).replacingOccurrences(of: "T", with: " ")
    }

    private func swingTail() {
        withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
            tailPhase = .pi
        }
    }

    // MARK: - 网络

    private func load() async {
        do {
            let raw = try await NativeHouseAPI.object("/api/roof/state")
            await MainActor.run {
                cat = RoofCat(raw.object("cat"))
                loading = false
                failed = false
            }
        } catch {
            await MainActor.run { loading = false; failed = true }
        }
    }

    private func apply(_ raw: [String: Any]) {
        cat = RoofCat(raw.object("cat"))
        let hint = raw.string("note")
        withAnimation { note = hint }
        if !hint.isEmpty {
            Task {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                await MainActor.run { withAnimation { note = "" } }
            }
        }
    }

    private func feed() async {
        guard let raw = try? await NativeHouseAPI.object(
            "/api/roof/feed", method: "POST", body: ["who": me]) else { return }
        await MainActor.run { apply(raw) }
    }

    private func pet(strokes: Int) async {
        guard let raw = try? await NativeHouseAPI.object(
            "/api/roof/pet", method: "POST", body: ["who": me, "strokes": strokes]) else { return }
        await MainActor.run { apply(raw) }
    }

    private func closeHomecoming(_ trip: RoofTrip) async {
        try? await NativeHouseAPI.post("/api/roof/trip/seen", body: ["id": trip.id])
        await load()
    }

    private func sleepToggle() async {
        guard let raw = try? await NativeHouseAPI.object(
            "/api/roof/sleep", method: "POST", body: ["who": me]) else { return }
        await MainActor.run { apply(raw) }
    }
}


// MARK: - 百宝箱

private struct StashSheet: View {
    let palette: RoofPalette
    @Environment(\.dismiss) private var dismiss
    @State private var items: [StashItem] = []
    @State private var onceLeft = 0
    @State private var loading = true

    var body: some View {
        ZStack {
            palette.deep.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("百宝箱")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(palette.onDeep)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(palette.onDeepDim)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)

                if loading {
                    Spacer()
                    ProgressView().tint(palette.onDeepDim)
                    Spacer()
                } else if items.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("还是空的")
                            .font(.system(size: 14))
                            .foregroundColor(palette.onDeepDim)
                        Text("等它出门叼东西回来")
                            .font(.system(size: 11))
                            .foregroundColor(palette.onDeepDim.opacity(0.7))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(items) { it in
                                row(it)
                            }
                            Text("只此一件的还剩 \(onceLeft) 样没被它找着")
                                .font(.system(size: 10.5))
                                .foregroundColor(palette.onDeepDim.opacity(0.7))
                                .padding(.top, 14)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .task { await load() }
    }

    private func row(_ it: StashItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color(it.rarity))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(it.item)
                    .font(.system(size: 14, weight: it.rarity == "once" ? .medium : .regular))
                    .foregroundColor(palette.onDeep)
                if !it.place.isEmpty {
                    Text("捡自" + it.place)
                        .font(.system(size: 10))
                        .foregroundColor(palette.onDeepDim)
                }
            }
            Spacer(minLength: 0)
            if it.count > 1 {
                Text("×\(it.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(palette.onDeepDim)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(palette.deepGlass))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(it.rarity == "once" ? palette.warm.opacity(0.45) : palette.deepLine,
                    lineWidth: 0.8))
    }

    private func color(_ rarity: String) -> Color {
        switch rarity {
        case "once": return palette.warm
        case "rare": return palette.acc
        case "uncommon": return palette.onDeep.opacity(0.7)
        default: return palette.onDeepDim.opacity(0.6)
        }
    }

    private func load() async {
        guard let raw = try? await NativeHouseAPI.object("/api/roof/stash") else {
            await MainActor.run { loading = false }
            return
        }
        let list = raw.array("items").map {
            StashItem(id: $0.string("id"), item: $0.string("item"),
                      rarity: $0.string("rarity"), place: $0.string("place"),
                      count: $0.int("count"))
        }
        await MainActor.run {
            items = list
            onceLeft = raw.int("onceLeft")
            loading = false
        }
    }
}
