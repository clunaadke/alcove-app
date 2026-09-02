import SwiftUI
import UIKit

// 占星室（0902 陈霁立的项）：塔罗。
//
// 她定的：
//   · 侧边栏一间屋，夜空神秘的感觉，风格参考她发的那两张图（暗玻璃卡 + 单色染的韦特牌）
//   · 78 张韦特牌（公版扫描，Assets 里 Tarot_<id>），单色染成夜空的淡紫
//   · 牌背自己画
//   · 交互：牌背扇形摊开，手指在上面滑，滑到哪张哪张抬起；抬起的那张再点一下就是选中；
//     选中 → 这张放大、其余消失、翻过来；再放进牌阵
//   · 先死解（每张牌正逆位各一段，服务端 tarot.py 里），再一颗「让陈璟解牌」的按钮
//   · 三种牌阵：单张 / 三张（过去现在未来）/ 关系五张（我·他·我们之间·阻碍·走向）
//
// 数据全在服务端：/api/tarot/deck 拉牌义表（进屋拉一次），/api/tarot/reading 存一次占卜，
// /api/tarot/ask 把这次的牌以她的身份发进主聊天，陈璟在聊天页解。

// MARK: - 数据

struct TarotCard: Identifiable, Equatable {
    let id: String
    let name: String
    let en: String
    let arcana: String
    let suit: String
    let number: Int
    let keywordsUp: [String]
    let keywordsRev: [String]
    let meaningUp: String
    let meaningRev: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let name = json["name"] as? String else { return nil }
        self.id = id
        self.name = name
        en = json["en"] as? String ?? ""
        arcana = json["arcana"] as? String ?? ""
        suit = json["suit"] as? String ?? ""
        number = json["number"] as? Int ?? 0
        keywordsUp = json["keywordsUp"] as? [String] ?? []
        keywordsRev = json["keywordsRev"] as? [String] ?? []
        meaningUp = json["meaningUp"] as? String ?? ""
        meaningRev = json["meaningRev"] as? String ?? ""
    }

    func keywords(reversed: Bool) -> [String] { reversed ? keywordsRev : keywordsUp }
    func meaning(reversed: Bool) -> String { reversed ? meaningRev : meaningUp }
}

struct TarotPosition: Identifiable, Equatable {
    let key: String
    let name: String
    var id: String { key }
}

struct TarotSpread: Identifiable, Equatable {
    let id: String
    let name: String
    let hint: String
    let positions: [TarotPosition]

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let name = json["name"] as? String else { return nil }
        self.id = id
        self.name = name
        hint = json["hint"] as? String ?? ""
        positions = (json["positions"] as? [[String: Any]] ?? []).compactMap { p in
            guard let k = p["key"] as? String, let n = p["name"] as? String else { return nil }
            return TarotPosition(key: k, name: n)
        }
    }
}

/// 抽出来的一张：哪张牌、正逆位、落在牌阵哪个位置
struct TarotDrawn: Identifiable, Hashable {
    let cardID: String
    let reversed: Bool
    let position: String
    var id: String { cardID + "@" + position }

    var json: [String: Any] { ["id": cardID, "reversed": reversed, "position": position] }
}

struct TarotReading: Identifiable, Hashable {
    let id: String
    let ts: String
    let spread: String
    let question: String
    let cards: [TarotDrawn]
    var asked: Bool

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else { return nil }
        self.id = id
        ts = json["ts"] as? String ?? ""
        spread = json["spread"] as? String ?? "one"
        question = json["question"] as? String ?? ""
        cards = (json["cards"] as? [[String: Any]] ?? []).compactMap { c in
            guard let cid = c["id"] as? String else { return nil }
            return TarotDrawn(cardID: cid, reversed: c["reversed"] as? Bool ?? false,
                              position: c["position"] as? String ?? "")
        }
        asked = json["asked"] as? Bool ?? false
    }

    var date: Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: ts) ?? ISO8601DateFormatter().date(from: ts) ?? Date()
    }
}

@MainActor
final class TarotStore: ObservableObject {
    static let shared = TarotStore()
    @Published var cards: [TarotCard] = []
    @Published var spreads: [TarotSpread] = []
    @Published var readings: [TarotReading] = []
    @Published var loadFailed = false
    private var byID: [String: TarotCard] = [:]

    func card(_ id: String) -> TarotCard? { byID[id] }
    func spread(_ id: String) -> TarotSpread? { spreads.first { $0.id == id } }

    func loadDeck() async {
        guard cards.isEmpty else { return }
        do {
            let obj = try await NativeHouseAPI.object("/api/tarot/deck")
            let cs = (obj["cards"] as? [[String: Any]] ?? []).compactMap(TarotCard.init(json:))
            let ss = (obj["spreads"] as? [[String: Any]] ?? []).compactMap(TarotSpread.init(json:))
            cards = cs
            spreads = ss
            byID = Dictionary(uniqueKeysWithValues: cs.map { ($0.id, $0) })
            loadFailed = cs.isEmpty
        } catch {
            loadFailed = true
        }
    }

    func loadReadings() async {
        if let obj = try? await NativeHouseAPI.object("/api/tarot/readings?limit=100") {
            readings = (obj["readings"] as? [[String: Any]] ?? []).compactMap(TarotReading.init(json:))
        }
    }

    func save(spread: String, question: String, cards drawn: [TarotDrawn]) async -> TarotReading? {
        let body: [String: Any] = ["spread": spread, "question": question, "cards": drawn.map { $0.json }]
        guard let obj = try? await NativeHouseAPI.object("/api/tarot/reading", method: "POST", body: body),
              let raw = obj["reading"] as? [String: Any],
              let reading = TarotReading(json: raw) else { return nil }
        readings.insert(reading, at: 0)
        return reading
    }

    /// 让陈璟解牌：服务端把这次的牌以她的身份发进主聊天。返回 (成功, 他睡着了)
    func ask(_ id: String) async -> (Bool, Bool) {
        guard let obj = try? await NativeHouseAPI.object("/api/tarot/ask", method: "POST", body: ["id": id]),
              obj["ok"] as? Bool == true else { return (false, false) }
        if let i = readings.firstIndex(where: { $0.id == id }) { readings[i].asked = true }
        return (true, obj["asleep"] as? Bool ?? false)
    }

    func delete(_ id: String) async {
        _ = try? await NativeHouseAPI.object("/api/tarot/delete", method: "POST", body: ["id": id])
        readings.removeAll { $0.id == id }
    }
}

// MARK: - 屋子的颜色（0902 她定的：黑夜照她发的那两张图，深紫、哥特、神秘；白天她还没想好，
// 我先给一版「晨雾」——淡紫灰的天、深紫的字，牌染成深一点的紫，她看了再改）
//
// 跟着全屋的日夜开关走（houseInterfaceAppearance），进屋那一刻读一次。

enum TarotInk {
    static var dark: Bool { UserDefaults.standard.string(forKey: AlcoveAppearance.key) != "light" }

    private static func pick(_ night: Color, _ day: Color) -> Color { dark ? night : day }

    /// 正文
    static var ink: Color   { pick(Color(red: 0.93, green: 0.90, blue: 1.0), Color(red: 0.17, green: 0.12, blue: 0.27)) }
    static var dim: Color   { ink.opacity(0.62) }
    static var faint: Color { ink.opacity(0.38) }
    /// 点缀色：细线、边框、位置名、小标签。夜里是薰衣草银，白天是深一点的紫
    static var gold: Color  { pick(Color(red: 0.72, green: 0.62, blue: 1.0), Color(red: 0.47, green: 0.34, blue: 0.78)) }
    /// 牌面单色染成的那个紫（她参考图里那种）
    static var tint: Color  { pick(Color(red: 0.72, green: 0.60, blue: 1.0), Color(red: 0.60, green: 0.48, blue: 0.90)) }
    /// 暗玻璃卡：底色 + 边线 + 胶囊底
    static var glass: Color     { pick(Color.white.opacity(0.055), Color.black.opacity(0.045)) }
    static var glassLine: Color { pick(Color.white.opacity(0.14), Color.black.opacity(0.10)) }
    static var pill: Color      { pick(Color.white.opacity(0.09), Color.black.opacity(0.06)) }
    /// 按钮底下那层紫晕（玻璃是透的，得靠它才看得出是颗按钮）
    static var buttonGlow: Color { pick(Color(red: 0.45, green: 0.25, blue: 0.80).opacity(0.42),
                                        Color(red: 0.55, green: 0.42, blue: 0.85).opacity(0.28)) }
    static var toastBack: Color { pick(Color.black.opacity(0.62), Color.white.opacity(0.82)) }
    /// 天：夜里近黑带紫 → 深紫 → 暗紫；白天淡紫灰的晨雾
    static var skyTop: Color    { pick(Color(red: 0.03, green: 0.02, blue: 0.06), Color(red: 0.95, green: 0.93, blue: 0.98)) }
    static var skyMid: Color    { pick(Color(red: 0.10, green: 0.05, blue: 0.20), Color(red: 0.90, green: 0.87, blue: 0.96)) }
    static var skyBottom: Color { pick(Color(red: 0.06, green: 0.03, blue: 0.11), Color(red: 0.96, green: 0.94, blue: 0.97)) }
    /// 两团星云
    static var nebulaA: Color   { pick(Color(red: 0.42, green: 0.18, blue: 0.78).opacity(0.46), Color(red: 0.62, green: 0.50, blue: 0.90).opacity(0.32)) }
    static var nebulaB: Color   { pick(Color(red: 0.58, green: 0.16, blue: 0.62).opacity(0.34), Color(red: 0.90, green: 0.62, blue: 0.80).opacity(0.24)) }
    static var star: Color      { pick(.white, Color(red: 0.40, green: 0.30, blue: 0.65)) }
    /// 按钮文字：玻璃是透的，字直接用正文色
    static var buttonInk: Color { ink }
}

/// iOS 那种雾面玻璃按钮：不实心，底下压一层紫晕，边上一圈细亮线
struct TarotGlassButtonStyle: ViewModifier {
    var prominent: Bool = true

    func body(content: Content) -> some View {
        content
            .foregroundColor(TarotInk.buttonInk)
            .background(TarotInk.buttonGlow.opacity(prominent ? 1 : 0.45), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(TarotInk.ink.opacity(prominent ? 0.28 : 0.16), lineWidth: 1))
            .shadow(color: TarotInk.buttonGlow.opacity(prominent ? 0.6 : 0), radius: 14, y: 4)
    }
}

extension View {
    func tarotGlassButton(prominent: Bool = true) -> some View {
        modifier(TarotGlassButtonStyle(prominent: prominent))
    }
}

/// 夜空：深蓝到深紫的底，两团星云，一层会呼吸的星星
struct TarotSky: View {
    /// 星星的位置按固定种子算，每次进屋是同一片天
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, phase: Double)] = {
        var s: UInt64 = 0x5EED_7A20
        func next() -> CGFloat {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((s >> 33) & 0xFFFF) / 65535
        }
        return (0..<170).map { _ in (next(), next(), 0.5 + next() * 1.3, Double(next()) * 6.28) }
    }()

    var body: some View {
        ZStack {
            LinearGradient(colors: [TarotInk.skyTop, TarotInk.skyMid, TarotInk.skyBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [TarotInk.nebulaA, .clear],
                           center: UnitPoint(x: 0.2, y: 0.25), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [TarotInk.nebulaB, .clear],
                           center: UnitPoint(x: 0.85, y: 0.7), startRadius: 0, endRadius: 300)
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for st in Self.stars {
                        let tw = 0.55 + 0.45 * sin(t * 1.3 + st.phase)
                        let r = st.r * (0.8 + 0.4 * tw)
                        let rect = CGRect(x: st.x * size.width - r, y: st.y * size.height - r,
                                          width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(TarotInk.star.opacity(0.35 + 0.55 * tw)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 牌

/// 牌面：公版韦特扫描 → 抽掉颜色 → 染成夜空淡紫。逆位倒着放。
struct TarotCardFace: View {
    let cardID: String
    var reversed: Bool = false
    var width: CGFloat = 120

    var body: some View {
        let h = width * 1.72
        let shape = RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
        return Image("Tarot_" + cardID)
            .resizable()
            .scaledToFill()
            .saturation(0)
            .colorMultiply(TarotInk.tint)
            .frame(width: width, height: h)
            .clipShape(shape)
            .overlay(shape.stroke(TarotInk.gold.opacity(0.55), lineWidth: 1))
            .rotationEffect(.degrees(reversed ? 180 : 0))
            .shadow(color: .black.opacity(0.45), radius: width * 0.08, y: width * 0.05)
    }
}

/// 牌背：深夜蓝、细金边、一格格小星、正中一枚月亮
struct TarotCardBack: View {
    var width: CGFloat = 120
    /// 牌背上的线：薰衣草银。牌背不分昼夜
    static let line = Color(red: 0.78, green: 0.70, blue: 1.0)

    var body: some View {
        let h = width * 1.72
        let shape = RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
        return ZStack {
            shape.fill(LinearGradient(colors: [Color(red: 0.16, green: 0.08, blue: 0.32),
                                               Color(red: 0.06, green: 0.03, blue: 0.14)],
                                      startPoint: .top, endPoint: .bottom))
            Canvas { ctx, size in
                let step = size.width / 6
                var y = step * 0.6
                var row = 0
                while y < size.height {
                    var x = (row % 2 == 0) ? step * 0.5 : step
                    while x < size.width {
                        ctx.fill(Self.star(at: CGPoint(x: x, y: y), r: step * 0.11),
                                 with: .color(Self.line.opacity(0.30)))
                        x += step
                    }
                    y += step * 0.75
                    row += 1
                }
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let R = size.width * 0.19
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)),
                         with: .color(Self.line.opacity(0.92)))
                let off = CGPoint(x: c.x + R * 0.42, y: c.y - R * 0.18)
                ctx.fill(Path(ellipseIn: CGRect(x: off.x - R * 0.86, y: off.y - R * 0.86,
                                                width: R * 1.72, height: R * 1.72)),
                         with: .color(Color(red: 0.10, green: 0.05, blue: 0.22)))
            }
            .clipShape(shape)
            shape.stroke(Self.line.opacity(0.7), lineWidth: 1)
            RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                .stroke(Self.line.opacity(0.35), lineWidth: 0.8)
                .padding(width * 0.06)
        }
        .frame(width: width, height: h)
        .shadow(color: .black.opacity(0.45), radius: width * 0.06, y: width * 0.04)
    }

    static func star(at c: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        let inner = r * 0.38
        for i in 0..<8 {
            let a = Double(i) * .pi / 4 - .pi / 2
            let rr = i % 2 == 0 ? r : inner
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// 扇形里 78 张牌背用同一张渲染好的图，不然 78 个 Canvas 一起动会卡（她点名要丝滑）
@MainActor
enum TarotBackCache {
    private static var cache: [Int: UIImage] = [:]
    static func image(width: CGFloat) -> UIImage? {
        let key = Int(width)
        if let img = cache[key] { return img }
        let r = ImageRenderer(content: TarotCardBack(width: width).padding(8))
        r.scale = UIScreen.main.scale
        guard let img = r.uiImage else { return nil }
        cache[key] = img
        return img
    }
}

// MARK: - 房间

struct TarotRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TarotStore.shared

    private enum Phase: Equatable { case pick, draw, result }
    @State private var phase: Phase = .pick
    @State private var spread: TarotSpread?
    @State private var question = ""
    @State private var deckOrder: [String] = []
    @State private var drawn: [TarotDrawn] = []
    @State private var hovered: Int?
    @State private var lifted: Int?
    @State private var fanVisible = true
    @State private var chosen: TarotDrawn?
    @State private var flip: Double = 0         // 0 背面 … 180 正面
    @State private var bigScale: CGFloat = 0.4
    @State private var reading: TarotReading?
    @State private var showHistory = false
    @State private var busy = false
    @State private var toast = ""
    @FocusState private var questionFocused: Bool

    var body: some View {
        ZStack {
            TarotSky()
            VStack(spacing: 0) {
                header
                switch phase {
                case .pick: pickView
                case .draw: drawView
                case .result:
                    if let r = reading {
                        TarotReadingView(reading: r, store: store, onAgain: { reset() },
                                         toast: { toast = $0 })
                    }
                }
            }
            if !toast.isEmpty { toastView }
        }
        .task {
            await store.loadDeck()
            await store.loadReadings()
        }
        .sheet(isPresented: $showHistory) {
            TarotHistorySheet(store: store)
        }
    }

    // MARK: 头

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(TarotInk.dim)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(spacing: 1) {
                Text("占星室")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundColor(TarotInk.ink)
                Text("TAROT")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(TarotInk.gold.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(TarotInk.dim)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: 选牌阵 + 问题

    private var pickView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if store.loadFailed {
                    Text("牌义表没拉下来，下拉再试")
                        .font(.system(size: 12)).foregroundColor(TarotInk.dim).padding(.top, 40)
                } else if store.spreads.isEmpty {
                    ProgressView().tint(TarotInk.dim).padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("牌阵")
                        ForEach(store.spreads) { sp in
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) { spread = sp }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(sp.name)
                                        .font(.system(size: 15, weight: .medium, design: .serif))
                                        .foregroundColor(TarotInk.ink)
                                    Text(sp.hint)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(TarotInk.dim)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(sp.positions.count) 张")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundColor(TarotInk.gold.opacity(0.8))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 13)
                                .background(glassCard(selected: spread?.id == sp.id))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("所问")
                        TextField("", text: $question, prompt: Text("想问什么，不写也行").foregroundColor(TarotInk.faint),
                                  axis: .vertical)
                            .lineLimit(1...4)
                            .font(.system(size: 15))
                            .foregroundColor(TarotInk.ink)
                            .tint(TarotInk.gold)
                            .focused($questionFocused)
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            .background(glassCard(selected: false))
                    }
                    Button {
                        questionFocused = false
                        startDrawing()
                    } label: {
                        Text("洗牌")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .tarotGlassButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(spread == nil)
                    .opacity(spread == nil ? 0.4 : 1)
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .refreshable {
            store.loadFailed = false
            await store.loadDeck()
        }
        .onTapGesture { questionFocused = false }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(2.5)
            .foregroundColor(TarotInk.gold.opacity(0.75))
            .padding(.leading, 4)
    }

    private func glassCard(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(selected ? TarotInk.pill : TarotInk.glass)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? TarotInk.gold.opacity(0.7) : TarotInk.glassLine, lineWidth: 1))
    }

    // MARK: 抽牌

    private var nextPosition: TarotPosition? {
        guard let sp = spread, drawn.count < sp.positions.count else { return nil }
        return sp.positions[drawn.count]
    }

    private var drawView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                slotsRow
                    .padding(.top, 8)
                Spacer(minLength: 0)
                if let c = chosen {
                    bigCard(c)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                } else if let pos = nextPosition {
                    VStack(spacing: 4) {
                        Text("为「\(pos.name)」抽一张")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(TarotInk.ink)
                        Text(lifted == nil ? "手指在牌上滑，抬起的那张再点一下" : "再点一下这张，就是它了")
                            .font(.system(size: 11.5))
                            .foregroundColor(TarotInk.dim)
                    }
                    .padding(.bottom, 6)
                }
                fan(width: geo.size.width)
                    .frame(height: 250)
                    .opacity(fanVisible ? 1 : 0)
                    .scaleEffect(fanVisible ? 1 : 0.92, anchor: .bottom)
                    .allowsHitTesting(fanVisible && chosen == nil)
            }
        }
    }

    /// 上面一排牌阵格子：抽过的放小牌面，没抽的是空框
    private var slotsRow: some View {
        HStack(spacing: 10) {
            if let sp = spread {
                ForEach(sp.positions) { pos in
                    VStack(spacing: 5) {
                        if let d = drawn.first(where: { $0.position == pos.key }) {
                            TarotCardFace(cardID: d.cardID, reversed: d.reversed, width: slotWidth(sp))
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        } else {
                            RoundedRectangle(cornerRadius: slotWidth(sp) * 0.07, style: .continuous)
                                .stroke(TarotInk.gold.opacity(pos.key == nextPosition?.key ? 0.8 : 0.3),
                                        style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                                .frame(width: slotWidth(sp), height: slotWidth(sp) * 1.72)
                        }
                        Text(pos.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(pos.key == nextPosition?.key ? TarotInk.gold : TarotInk.dim)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func slotWidth(_ sp: TarotSpread) -> CGFloat {
        switch sp.positions.count {
        case 1: return 74
        case 3: return 66
        default: return 52
        }
    }

    /// 选中那张：放大 → 翻面 → 亮出名字
    private func bigCard(_ c: TarotDrawn) -> some View {
        let w: CGFloat = 176
        let showFace = flip >= 90
        return VStack(spacing: 14) {
            ZStack {
                if showFace {
                    TarotCardFace(cardID: c.cardID, reversed: c.reversed, width: w)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    TarotCardBack(width: w)
                }
            }
            .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(bigScale)
            if showFace, let card = store.card(c.cardID) {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(card.name)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(TarotInk.ink)
                        Text(c.reversed ? "逆位" : "正位")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(c.reversed ? TarotInk.gold : TarotInk.tint)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().stroke(c.reversed ? TarotInk.gold.opacity(0.7)
                                                                    : TarotInk.tint.opacity(0.7), lineWidth: 1))
                    }
                    Text(card.keywords(reversed: c.reversed).joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundColor(TarotInk.dim)
                }
                .transition(.opacity)
            }
        }
    }

    /// 扇形牌背。78 张沿一段圆弧排开，圆心在屏幕下方看不见的地方。
    /// 手指滑到哪张哪张沿着自己的方向抬起；松手那张留着；再点一下就选中。
    private func fan(width: CGFloat) -> some View {
        let n = deckOrder.count
        let cardW: CGFloat = 58
        let radius: CGFloat = 420
        let span: Double = min(118, Double(n) * 2.2)
        let step: Double = n > 1 ? span / Double(n - 1) : 0
        let center = CGPoint(x: width / 2, y: 250 + radius - 96)
        let back = TarotBackCache.image(width: cardW)
        let active = hovered ?? lifted
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let a = -span / 2 + Double(i) * step
                let rad = a * .pi / 180
                let lift: CGFloat = (active == i) ? 30 : 0
                let x = center.x + (radius + lift) * CGFloat(sin(rad))
                let y = center.y - (radius + lift) * CGFloat(cos(rad))
                Group {
                    if let back {
                        Image(uiImage: back).resizable().scaledToFit()
                    } else {
                        TarotCardBack(width: cardW)
                    }
                }
                .frame(width: cardW + 16, height: cardW * 1.72 + 16)
                .rotationEffect(.degrees(a))
                .position(x: x, y: y)
                .zIndex(active == i ? 1000 : Double(i))
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.72), value: active)
            }
        }
        .frame(width: width, height: 250)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    hovered = fanIndex(at: v.location, center: center, span: span, step: step, n: n)
                }
                .onEnded { v in
                    let dist = hypot(v.translation.width, v.translation.height)
                    let idx = fanIndex(at: v.location, center: center, span: span, step: step, n: n)
                    if dist < 10, let idx, idx == lifted {
                        choose(index: idx)
                    } else {
                        lifted = idx
                    }
                    hovered = nil
                }
        )
        .drawingGroup()
    }

    /// 手指点 → 圆弧上的角度 → 第几张。只认圆弧那一圈附近，点到空处返回 nil
    private func fanIndex(at p: CGPoint, center: CGPoint, span: Double, step: Double, n: Int) -> Int? {
        guard n > 0, step > 0 else { return n > 0 ? 0 : nil }
        let dx = p.x - center.x, dy = center.y - p.y
        let r = hypot(dx, dy)
        guard r > 300 else { return nil }
        let a = atan2(dx, dy) * 180 / .pi
        let i = Int((a + span / 2) / step + 0.5)
        return max(0, min(n - 1, i))
    }

    private func startDrawing() {
        guard spread != nil else { return }
        deckOrder = store.cards.map { $0.id }.shuffled()
        drawn = []
        hovered = nil
        lifted = nil
        chosen = nil
        fanVisible = true
        withAnimation(.easeInOut(duration: 0.25)) { phase = .draw }
    }

    private func choose(index: Int) {
        guard index < deckOrder.count, let pos = nextPosition, chosen == nil else { return }
        let id = deckOrder.remove(at: index)
        let pick = TarotDrawn(cardID: id, reversed: Bool.random(), position: pos.key)
        lifted = nil
        hovered = nil
        flip = 0
        bigScale = 0.4
        chosen = pick
        // 1) 扇子退场，选中那张放大
        withAnimation(.easeOut(duration: 0.28)) { fanVisible = false }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { bigScale = 1 }
        // 2) 翻面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.easeInOut(duration: 0.55)) { flip = 180 }
        }
        // 3) 落进牌阵
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                drawn.append(pick)
                chosen = nil
            }
            if nextPosition == nil {
                finish()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeOut(duration: 0.3)) { fanVisible = true }
                }
            }
        }
    }

    private func finish() {
        guard let sp = spread else { return }
        busy = true
        Task {
            let r = await store.save(spread: sp.id, question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                                     cards: drawn)
            busy = false
            if let r {
                reading = r
                withAnimation(.easeInOut(duration: 0.3)) { phase = .result }
            } else {
                toast = "没存上，网络不给力"
                dismissToastLater()
            }
        }
    }

    private func reset() {
        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .pick
            reading = nil
            drawn = []
            chosen = nil
        }
    }

    private var toastView: some View {
        VStack {
            Spacer()
            Text(toast)
                .font(.system(size: 12.5))
                .foregroundColor(TarotInk.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(TarotInk.toastBack))
                .overlay(Capsule().stroke(TarotInk.glassLine, lineWidth: 1))
                .padding(.bottom, 40)
        }
        .transition(.opacity)
        .onAppear { dismissToastLater() }
    }

    private func dismissToastLater() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toast = "" }
        }
    }
}

// MARK: - 结果（抽完 / 翻记录都用它）

struct TarotReadingView: View {
    let reading: TarotReading
    @ObservedObject var store: TarotStore
    var onAgain: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var toast: ((String) -> Void)? = nil
    @State private var asking = false
    @State private var asked = false

    private var spread: TarotSpread? { store.spread(reading.spread) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("READING")
                        .font(.system(size: 9, weight: .semibold)).tracking(3)
                        .foregroundColor(TarotInk.gold.opacity(0.75))
                    HStack(spacing: 8) {
                        Text(Self.dateText(reading.date))
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(TarotInk.ink)
                        Text(spread?.name ?? reading.spread)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(TarotInk.tint)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().stroke(TarotInk.tint.opacity(0.7), lineWidth: 1))
                    }
                }
                .padding(.top, 8)

                if !reading.question.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("所问").font(.system(size: 10, weight: .semibold)).tracking(2)
                            .foregroundColor(TarotInk.gold.opacity(0.75))
                        Text(reading.question)
                            .font(.system(size: 15)).foregroundColor(TarotInk.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(glass)
                }

                ForEach(reading.cards) { d in
                    cardBlock(d)
                }

                Button {
                    guard !asking, !asked, !reading.asked else { return }
                    asking = true
                    Task {
                        let (ok, asleep) = await store.ask(reading.id)
                        asking = false
                        if ok {
                            asked = true
                            toast?(asleep ? "他睡着了，牌先放着，醒了就看见" : "发给他了，去聊天页看他怎么说")
                        } else {
                            toast?("没发出去，再试一次")
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if asking { ProgressView().tint(TarotInk.ink).controlSize(.small) }
                        else { Image(systemName: "bubble.left.and.text.bubble.right") }
                        Text((asked || reading.asked) ? "已经发给陈璟了" : "让陈璟解牌")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .tarotGlassButton(prominent: !(asked || reading.asked))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                HStack(spacing: 24) {
                    if let onAgain {
                        Button("再抽一次") { onAgain() }
                    }
                    if let onDelete {
                        Button("删除这条记录") { onDelete() }
                    }
                }
                .font(.system(size: 12.5))
                .foregroundColor(TarotInk.dim)
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
    }

    private var glass: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(TarotInk.glass)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TarotInk.glassLine, lineWidth: 1))
    }

    private func cardBlock(_ d: TarotDrawn) -> some View {
        let card = store.card(d.cardID)
        let posName = spread?.positions.first { $0.key == d.position }?.name ?? ""
        return VStack(spacing: 12) {
            if (spread?.positions.count ?? 1) > 1 {
                Text(posName)
                    .font(.system(size: 10, weight: .semibold)).tracking(2)
                    .foregroundColor(TarotInk.gold.opacity(0.8))
            }
            TarotCardFace(cardID: d.cardID, reversed: d.reversed, width: 150)
            HStack(spacing: 8) {
                Text(card?.name ?? d.cardID)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundColor(TarotInk.ink)
                Text(d.reversed ? "逆位" : "正位")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(d.reversed ? TarotInk.gold : TarotInk.tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().stroke(d.reversed ? TarotInk.gold.opacity(0.7)
                                                            : TarotInk.tint.opacity(0.7), lineWidth: 1))
            }
            if let card {
                FlowPills(card.keywords(reversed: d.reversed))
                Text(card.meaning(reversed: d.reversed))
                    .font(.system(size: 13.5))
                    .lineSpacing(4)
                    .foregroundColor(TarotInk.dim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16).padding(.vertical, 18)
        .background(glass)
    }

    static func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

/// 关键词小胶囊，两行居中
struct FlowPills: View {
    let words: [String]
    init(_ words: [String]) { self.words = words }

    var body: some View {
        let rows = stride(from: 0, to: words.count, by: 3).map { Array(words[$0..<min($0 + 3, words.count)]) }
        VStack(spacing: 7) {
            ForEach(Array(rows.enumerated()), id: \.offset) { row in
                HStack(spacing: 7) {
                    ForEach(row.element, id: \.self) { w in
                        Text(w)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(TarotInk.ink)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(Capsule().fill(TarotInk.pill))
                            .overlay(Capsule().stroke(TarotInk.glassLine, lineWidth: 1))
                    }
                }
            }
        }
    }
}

// MARK: - 占卜记录

struct TarotHistorySheet: View {
    @ObservedObject var store: TarotStore
    @Environment(\.dismiss) private var dismiss
    @State private var open: TarotReading?
    @State private var toast = ""

    var body: some View {
        NavigationStack {
            ZStack {
                TarotSky()
                if store.readings.isEmpty {
                    Text("还没抽过牌")
                        .font(.system(size: 13)).foregroundColor(TarotInk.dim)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(store.readings) { r in
                                Button { open = r } label: { row(r) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                if !toast.isEmpty {
                    VStack {
                        Spacer()
                        Text(toast).font(.system(size: 12.5)).foregroundColor(TarotInk.ink)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(TarotInk.toastBack))
                            .padding(.bottom, 30)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toast = "" } }
                    }
                }
            }
            .navigationTitle("占卜记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(TarotInk.dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundColor(TarotInk.dim)
                }
            }
            .navigationDestination(item: $open) { r in
                ZStack {
                    TarotSky()
                    TarotReadingView(reading: r, store: store,
                                     onDelete: {
                                         Task {
                                             await store.delete(r.id)
                                             open = nil
                                         }
                                     },
                                     toast: { toast = $0 })
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(TarotInk.dark ? .dark : .light, for: .navigationBar)
            }
        }
        .task { await store.loadReadings() }
        .preferredColorScheme(TarotInk.dark ? .dark : .light)
    }

    private func row(_ r: TarotReading) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: -14) {
                ForEach(r.cards.prefix(3)) { d in
                    TarotCardFace(cardID: d.cardID, reversed: d.reversed, width: 34)
                }
            }
            .frame(width: 34 + CGFloat(min(3, r.cards.count) - 1) * 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(TarotReadingView.dateText(r.date))
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(TarotInk.ink)
                    Text(store.spread(r.spread)?.name ?? r.spread)
                        .font(.system(size: 10)).foregroundColor(TarotInk.tint)
                    if r.asked {
                        Image(systemName: "bubble.left.fill").font(.system(size: 9)).foregroundColor(TarotInk.gold)
                    }
                }
                Text(r.question.isEmpty
                     ? r.cards.compactMap { store.card($0.cardID)?.name }.joined(separator: " · ")
                     : r.question)
                    .font(.system(size: 12)).foregroundColor(TarotInk.dim).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(TarotInk.faint)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TarotInk.glass))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(TarotInk.glassLine, lineWidth: 1))
    }
}
