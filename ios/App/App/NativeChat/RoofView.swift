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
        tile: Color(red: 0xA8/255, green: 0x6F/255, blue: 0x53/255),
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
        tile: Color(red: 0x4A/255, green: 0x33/255, blue: 0x2A/255),
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
            let h = geo.size.height
            ZStack(alignment: .top) {
                // 瓦面
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.32))
                    p.addLine(to: CGPoint(x: w, y: h * 0.32))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [palette.tile, palette.tile.opacity(0.82)],
                                     startPoint: .top, endPoint: .bottom))
                // 瓦垄
                HStack(spacing: w / 13) {
                    ForEach(0..<12, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(palette.isDark ? 0.16 : 0.09))
                            .frame(width: 1.4)
                    }
                }
                .padding(.top, h * 0.32)
                // 檐口那道亮边
                Rectangle()
                    .fill(palette.warm.opacity(palette.isDark ? 0.30 : 0.55))
                    .frame(height: 2.5)
                    .offset(y: h * 0.32)
            }
        }
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

    private let haptics = RoofHaptics.shared
    private var palette: RoofPalette { .named(themeName) }
    /// 她是 ji。这一页从 app 上按下去的每一下都记在她名下
    private let me = "ji"

    var body: some View {
        ZStack {
            sky
            content
        }
        .task { await load() }
        .onAppear { swingTail() }
    }

    private var sky: some View {
        LinearGradient(colors: [palette.skyTop, palette.skyMid, palette.skyBottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay(
                Circle()
                    .fill(palette.warm.opacity(palette.isDark ? 0.18 : 0.34))
                    .frame(width: 190, height: 190)
                    .blur(radius: 46)
                    .offset(x: 96, y: -180)
            )
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            if loading {
                Spacer()
                ProgressView().tint(palette.ink3)
                Spacer()
            } else if failed {
                Spacer()
                Text("没连上，下拉再试一次")
                    .font(.system(size: 13))
                    .foregroundColor(palette.ink3)
                Spacer()
            } else {
                stage
                statusRow
                buttons
                if showLog { logList } else { logHint }
                Spacer(minLength: 8)
            }
        }
        .padding(.bottom, 22)
    }

    // 自己做头（ownsFullScreen）
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
                Text(cat.mood.isEmpty ? "雨停了，猫爬上来了" : "\(cat.name) · \(cat.mood)")
                    .font(.system(size: 10.5))
                    .foregroundColor(palette.ink3)
            }
            Spacer()
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

    // 猫待的那块地方
    private var stage: some View {
        ZStack(alignment: .bottom) {
            RoofTiles(palette: palette)
                .frame(height: 168)
            CatShape(palette: palette,
                     asleep: cat.asleep,
                     squish: squish,
                     tailPhase: tailPhase,
                     turnedAway: cat.spot == "ridge")
                .frame(width: 132, height: 132)
                .offset(x: catOffsetX, y: -34)
                .animation(.spring(response: 0.5, dampingFraction: 0.72), value: cat.spot)
                .gesture(petGesture)
            // 空碗
            if cat.hunger < 30 {
                bowl.offset(x: -108, y: -12)
            }
        }
        .frame(height: 220)
        .padding(.top, 4)
        .overlay(alignment: .top) { speech }
    }

    private var catOffsetX: CGFloat {
        switch cat.spot {
        case "ridge": return 74      // 爬远了
        case "bowl": return -72
        case "lap": return 0
        default: return 12
        }
    }

    private var bowl: some View {
        ZStack {
            Ellipse()
                .fill(palette.ink3.opacity(0.5))
                .frame(width: 40, height: 15)
            Ellipse()
                .fill(palette.skyBottom)
                .frame(width: 30, height: 8)
                .offset(y: -2)
        }
    }

    private var speech: some View {
        Text(cat.says)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(palette.ink2)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(palette.glass))
            .overlay(Capsule().stroke(palette.line, lineWidth: 0.7))
            .padding(.top, 2)
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
            .foregroundColor(palette.ink3)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.ink3.opacity(0.18))
                    Capsule()
                        .fill(value < 25 ? palette.acc : palette.warm)
                        .frame(width: max(3, geo.size.width * CGFloat(value) / 100))
                }
            }
            .frame(height: 5)
            .animation(.easeOut(duration: 0.4), value: value)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(palette.glass))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(palette.line, lineWidth: 0.7))
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            if !note.isEmpty {
                Text(note)
                    .font(.system(size: 11.5))
                    .foregroundColor(palette.ink3)
                    .transition(.opacity)
            }
            HStack(spacing: 9) {
                actionButton("喂饭", "fork.knife") { Task { await feed() } }
                actionButton(cat.asleep ? "叫醒" : "哄睡", cat.asleep ? "sun.max" : "moon.stars") {
                    Task { await sleepToggle() }
                }
            }
            Text("撸它 —— 手指在猫身上划")
                .font(.system(size: 10))
                .foregroundColor(palette.ink3.opacity(0.85))
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
            .foregroundColor(palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.glass))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.line, lineWidth: 0.8))
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
            .foregroundColor(palette.ink3)
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
                .foregroundColor(palette.ink3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(cat.log) { entry in
                        HStack(spacing: 7) {
                            Text(entry.whoName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(entry.whoName == "陈霁" ? palette.acc : palette.ink2)
                            Text(entry.detail)
                                .font(.system(size: 11))
                                .foregroundColor(palette.ink2)
                            Spacer(minLength: 0)
                            Text(shortTime(entry.createdAt))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(palette.ink3)
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

    private func sleepToggle() async {
        guard let raw = try? await NativeHouseAPI.object(
            "/api/roof/sleep", method: "POST", body: ["who": me]) else { return }
        await MainActor.run { apply(raw) }
    }
}
