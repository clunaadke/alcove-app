import SwiftUI
import UIKit
import PhotosUI
import Photos

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

struct TarotCard: Identifiable, Hashable {
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

/// 客观解读（0903 她要的：不认识她、只看牌的那份。服务端 tarot_reading.build 查表拼的，免费）
struct TarotInterp: Hashable {
    struct Card: Hashable, Identifiable {
        let id: String
        let name: String
        let reversed: Bool
        let positionName: String
        let intro: String
        let nature: String
        let text: String
        let advice: String
    }
    let category: String
    let categoryName: String
    let overall: String
    let cards: [Card]
    let relations: [String]
    let advice: [String]
    let oneline: String

    init?(json: [String: Any]?) {
        guard let json, let overall = json["overall"] as? String else { return nil }
        category = json["category"] as? String ?? "daily"
        categoryName = json["category_name"] as? String ?? "日常"
        self.overall = overall
        cards = (json["cards"] as? [[String: Any]] ?? []).compactMap { c in
            guard let id = c["id"] as? String else { return nil }
            return Card(id: id, name: c["name"] as? String ?? id, reversed: c["reversed"] as? Bool ?? false,
                        positionName: c["position_name"] as? String ?? "", intro: c["intro"] as? String ?? "",
                        nature: c["nature"] as? String ?? "", text: c["text"] as? String ?? "",
                        advice: c["advice"] as? String ?? "")
        }
        relations = json["relations"] as? [String] ?? []
        advice = json["advice"] as? [String] ?? []
        oneline = json["oneline"] as? String ?? ""
    }
}

/// AI 细解（0903：她很想了解的时候按一下，DeepSeek 写的，存过一次就不再花钱）
struct TarotAI: Hashable {
    struct Card: Hashable, Identifiable {
        let name: String
        let reading: String
        var id: String { name + "|" + reading.prefix(12) }
    }
    let category: String
    let overall: String
    let cards: [Card]
    let relations: String
    let advice: String
    let oneline: String

    init?(json: [String: Any]?) {
        guard let json, let overall = json["overall"] as? String else { return nil }
        category = json["category"] as? String ?? ""
        self.overall = overall
        cards = (json["cards"] as? [[String: Any]] ?? []).compactMap { c in
            guard let n = c["name"] as? String else { return nil }
            return Card(name: n, reading: c["reading"] as? String ?? "")
        }
        relations = json["relations"] as? String ?? ""
        advice = json["advice"] as? String ?? ""
        oneline = json["oneline"] as? String ?? ""
    }
}

struct TarotReading: Identifiable, Hashable {
    let id: String
    let ts: String
    let spread: String
    let question: String
    let cards: [TarotDrawn]
    var asked: Bool
    /// 谁抽的：her / him（0903 凌晨陈璟也能抽了）
    let by: String
    /// 谁出的题：'' / him（他出题、她在聊天页抽的那种）
    let askedBy: String

    /// 客观解读，服务端一起给
    let interp: TarotInterp?

    var byHim: Bool { by == "him" }
    var askedByHim: Bool { askedBy == "him" }

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else { return nil }
        self.id = id
        ts = json["ts"] as? String ?? ""
        spread = json["spread"] as? String ?? "one"
        question = json["question"] as? String ?? ""
        by = json["by"] as? String ?? "her"
        askedBy = json["asked_by"] as? String ?? ""
        interp = TarotInterp(json: json["interp"] as? [String: Any])
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

    /// 换一种问题类型重算客观解读（不存，拿着就行）
    func interp(_ id: String, category: String?) async -> TarotInterp? {
        var body: [String: Any] = ["id": id]
        if let category { body["category"] = category }
        guard let obj = try? await NativeHouseAPI.object("/api/tarot/interp", method: "POST", body: body) else { return nil }
        return TarotInterp(json: obj["interp"] as? [String: Any])
    }

    func aiCached(_ id: String) async -> TarotAI? {
        guard let obj = try? await NativeHouseAPI.object("/api/tarot/ai?id=\(id)") else { return nil }
        return TarotAI(json: obj["ai"] as? [String: Any])
    }

    /// AI 细解：生成（或拿缓存）。返回 (结果, 错误话)
    func ai(_ id: String, category: String?, force: Bool = false) async -> (TarotAI?, String) {
        var body: [String: Any] = ["id": id, "force": force]
        if let category { body["category"] = category }
        guard let obj = try? await NativeHouseAPI.objectIncludingHTTPError("/api/tarot/ai", method: "POST", body: body) else {
            return (nil, "没连上，网络不给力")
        }
        guard obj["ok"] as? Bool == true else { return (nil, (obj["error"] as? String).map { "AI 没写出来：" + $0 } ?? "AI 没写出来") }
        return (TarotAI(json: obj["ai"] as? [String: Any]), "")
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
    private static func pick(_ night: Double, _ day: Double) -> Double { dark ? night : day }

    /// 正文
    static var ink: Color   { pick(Color(red: 0.93, green: 0.90, blue: 1.0), Color(red: 0.17, green: 0.12, blue: 0.27)) }
    static var dim: Color   { ink.opacity(0.62) }
    static var faint: Color { ink.opacity(0.38) }
    /// 点缀色：细线、边框、位置名、小标签。夜里是薰衣草银，白天是深一点的紫
    static var gold: Color  { pick(Color(red: 0.72, green: 0.62, blue: 1.0), Color(red: 0.47, green: 0.34, blue: 0.78)) }
    /// 牌面单色染成的那个紫（她参考图里那种）
    static var tint: Color  { pick(Color(red: 0.72, green: 0.60, blue: 1.0), Color(red: 0.60, green: 0.48, blue: 0.90)) }
    // 雾面玻璃（暗玻璃卡 / 胶囊 / 按钮紫晕）：0902 深夜她要一个调色盘自己拧。
    // 颜色和浓度存在 UserDefaults（TarotDecor 写，这里直接读，不牵扯 actor）；
    // 没拧过 = 跟她验收过的那版一模一样（白 0.055 / 0.14 / 0.09，紫晕 0.42）。
    private static var mode: String { dark ? "night" : "day" }
    static var glassCustom: Color? {
        guard let hex = UserDefaults.standard.string(forKey: "tarotGlass.\(mode).color") else { return nil }
        return Color(hexString: hex)
    }
    static var glassStrength: Double {
        let k = "tarotGlass.\(mode).strength"
        guard UserDefaults.standard.object(forKey: k) != nil else { return TarotGlassConfig.defaultStrength }
        return min(1, max(0, UserDefaults.standard.double(forKey: k)))
    }
    /// 默认浓度下 = 1，往上拧玻璃越实
    private static var glassK: Double { glassStrength / TarotGlassConfig.defaultStrength }
    private static var glassBase: Color { glassCustom ?? pick(.white, .black) }
    /// 暗玻璃卡：底色 + 边线 + 胶囊底。0902 深夜她说「玻璃要糊一点、不那么透」：
    /// 浓度往上拧主要是换更厚的磨砂材质（glassMaterial），底色只跟着涨一点、封顶，字永远看得清
    static var glass: Color     { glassBase.opacity(min(0.30, pick(0.055, 0.045) * glassK)) }
    static var glassLine: Color { glassBase.opacity(min(0.55, pick(0.14, 0.10) * glassK)) }
    static var pill: Color      { glassBase.opacity(min(0.40, pick(0.09, 0.06) * glassK)) }
    /// 玻璃的磨砂档位：浓度越高越糊越不透
    static var glassMaterial: Material {
        switch glassStrength {
        case ..<0.3: return .ultraThinMaterial
        case ..<0.55: return .thinMaterial
        case ..<0.8: return .regularMaterial
        default: return .thickMaterial
        }
    }
    /// 按钮底下那层紫晕（玻璃是透的，得靠它才看得出是颗按钮）。
    /// 0902 深夜她抓的：这层原来跟玻璃色 / 浓度走，她把玻璃拧成白色高浓度后按钮白得刺眼——
    /// 现在固定跟屋子的紫走，不再吃玻璃设置
    static var buttonGlow: Color {
        pick(Color(red: 0.45, green: 0.25, blue: 0.80).opacity(0.42),
             Color(red: 0.55, green: 0.42, blue: 0.85).opacity(0.28))
    }
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

// MARK: - 屋子的装修（0902 深夜她要的三个调色盘：牌面染色 / 雾面玻璃 / 壁纸）
//
// 牌面 = 公版扫描 → 抽色 → 刷一层色。她问「这颜色是染的吧」，然后要自己调：
//   · strength 0…1：0 是原图，1 是整张刷成 color；中间原图透出来一点
//   · mono：没染到的那部分是黑白还是彩色（黑白 + strength 0 = 素描）
//   · color：刷的那层颜色，nil = 跟着 TarotInk.tint（夜薰衣草紫 / 日深紫）。牌背也吃这个颜色
// 玻璃：暗玻璃卡 / 胶囊 / 按钮紫晕的颜色和浓度（TarotInk 读 UserDefaults 算出来）
// 壁纸：整间屋（选牌阵 / 抽牌 / 结果）全屏一张，夜里白天各一张，存在 Documents 里
// 三样都是夜里一套、白天一套。TarotCardFace / TarotCardBack / TarotSky 盯着这个单例，拧一下当场重画。

struct TarotTintConfig: Equatable {
    var strength: Double = 1
    var mono: Bool = true
    var color: Color? = nil
}

struct TarotGlassConfig: Equatable {
    static let defaultStrength = 0.2
    var strength: Double = TarotGlassConfig.defaultStrength
    var color: Color? = nil
}

@MainActor
final class TarotDecor: ObservableObject {
    static let shared = TarotDecor()

    @Published private(set) var night: TarotTintConfig
    @Published private(set) var day: TarotTintConfig
    @Published private(set) var glassNight: TarotGlassConfig
    @Published private(set) var glassDay: TarotGlassConfig
    @Published private(set) var wallpaperNight: UIImage?
    @Published private(set) var wallpaperDay: UIImage?
    /// 壁纸上面还要不要撒那层会呼吸的星星
    @Published var starsOnWallpaper: Bool {
        didSet { UserDefaults.standard.set(starsOnWallpaper, forKey: "tarotSky.stars") }
    }

    private init() {
        night = Self.loadTint("night")
        day = Self.loadTint("day")
        glassNight = Self.loadGlass("night")
        glassDay = Self.loadGlass("day")
        wallpaperNight = UIImage(contentsOfFile: Self.wallpaperURL("night").path)
        wallpaperDay = UIImage(contentsOfFile: Self.wallpaperURL("day").path)
        starsOnWallpaper = UserDefaults.standard.object(forKey: "tarotSky.stars") == nil
            ? true : UserDefaults.standard.bool(forKey: "tarotSky.stars")
    }

    private static var mode: String { TarotInk.dark ? "night" : "day" }

    // MARK: 牌面染色

    private static func tintKey(_ mode: String, _ what: String) -> String { "tarotTint.\(mode).\(what)" }

    private static func loadTint(_ mode: String) -> TarotTintConfig {
        let d = UserDefaults.standard
        var c = TarotTintConfig()
        if d.object(forKey: tintKey(mode, "strength")) != nil {
            c.strength = min(1, max(0, d.double(forKey: tintKey(mode, "strength"))))
        }
        if d.object(forKey: tintKey(mode, "mono")) != nil { c.mono = d.bool(forKey: tintKey(mode, "mono")) }
        if let hex = d.string(forKey: tintKey(mode, "color")), let col = Color(hexString: hex) { c.color = col }
        return c
    }

    private static func storeTint(_ c: TarotTintConfig, _ mode: String) {
        let d = UserDefaults.standard
        d.set(c.strength, forKey: tintKey(mode, "strength"))
        d.set(c.mono, forKey: tintKey(mode, "mono"))
        if let hex = c.color?.hexString {
            d.set(hex, forKey: tintKey(mode, "color"))
        } else {
            d.removeObject(forKey: tintKey(mode, "color"))
        }
    }

    /// 当前这套（跟全屋日夜走）
    var current: TarotTintConfig { TarotInk.dark ? night : day }
    var isDefault: Bool { current == TarotTintConfig() }

    func update(_ f: (inout TarotTintConfig) -> Void) {
        if TarotInk.dark {
            f(&night); Self.storeTint(night, "night")
        } else {
            f(&day); Self.storeTint(day, "day")
        }
    }

    func resetCurrent() { update { $0 = TarotTintConfig() } }

    /// 刷的那层颜色：没自定义就用屋子的紫。牌背的线也是这个色
    var color: Color { current.color ?? TarotInk.tint }

    /// 给 .saturation：染满 = 全抽色；黑白开着也全抽色；否则按浓度留一点原色
    var saturation: Double { current.mono ? 0 : 1 - current.strength }

    /// 给 .colorMultiply：白 → color 之间按浓度插值（乘白 = 原样）
    var multiply: Color {
        let s = current.strength
        guard s > 0.001 else { return .white }
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        _ = UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: 1 - (1 - Double(r)) * s,
                     green: 1 - (1 - Double(g)) * s,
                     blue: 1 - (1 - Double(b)) * s)
    }

    /// color 压暗成牌背的底色（k 越小越黑）
    func deep(_ k: Double) -> Color {
        var r: CGFloat = 0.5, g: CGFloat = 0.3, b: CGFloat = 0.8, a: CGFloat = 1
        _ = UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: Double(r) * k, green: Double(g) * k, blue: Double(b) * k)
    }

    // MARK: 雾面玻璃

    private static func glassKey(_ mode: String, _ what: String) -> String { "tarotGlass.\(mode).\(what)" }

    private static func loadGlass(_ mode: String) -> TarotGlassConfig {
        let d = UserDefaults.standard
        var c = TarotGlassConfig()
        if d.object(forKey: glassKey(mode, "strength")) != nil {
            c.strength = min(1, max(0, d.double(forKey: glassKey(mode, "strength"))))
        }
        if let hex = d.string(forKey: glassKey(mode, "color")), let col = Color(hexString: hex) { c.color = col }
        return c
    }

    private static func storeGlass(_ c: TarotGlassConfig, _ mode: String) {
        let d = UserDefaults.standard
        d.set(c.strength, forKey: glassKey(mode, "strength"))
        if let hex = c.color?.hexString {
            d.set(hex, forKey: glassKey(mode, "color"))
        } else {
            d.removeObject(forKey: glassKey(mode, "color"))
        }
    }

    var glass: TarotGlassConfig { TarotInk.dark ? glassNight : glassDay }
    var glassIsDefault: Bool { glass == TarotGlassConfig() }
    /// 玻璃现在的底色（没自定义 = 夜白 / 日黑）
    var glassColor: Color { glass.color ?? (TarotInk.dark ? .white : .black) }

    func updateGlass(_ f: (inout TarotGlassConfig) -> Void) {
        if TarotInk.dark {
            f(&glassNight); Self.storeGlass(glassNight, "night")
        } else {
            f(&glassDay); Self.storeGlass(glassDay, "day")
        }
    }

    func resetGlass() { updateGlass { $0 = TarotGlassConfig() } }

    // MARK: 壁纸

    private static func wallpaperURL(_ mode: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("TarotWallpaper-\(mode).jpg")
    }

    /// 当前日夜那张壁纸；nil = 用代码画的天
    var wallpaper: UIImage? { TarotInk.dark ? wallpaperNight : wallpaperDay }

    /// 相册里选的那张：缩到长边 2400 以内、存成 JPEG，当场换上
    func setWallpaper(data: Data) {
        guard let raw = UIImage(data: data) else { return }
        let img = Self.downscale(raw, maxSide: 2400)
        guard let jpg = img.jpegData(compressionQuality: 0.88) else { return }
        try? jpg.write(to: Self.wallpaperURL(Self.mode), options: .atomic)
        if TarotInk.dark { wallpaperNight = img } else { wallpaperDay = img }
    }

    func clearWallpaper() {
        try? FileManager.default.removeItem(at: Self.wallpaperURL(Self.mode))
        if TarotInk.dark { wallpaperNight = nil } else { wallpaperDay = nil }
    }

    private static func downscale(_ img: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(img.size.width, img.size.height)
        guard longest > maxSide else { return img }
        let k = maxSide / longest
        let size = CGSize(width: img.size.width * k, height: img.size.height * k)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - 字体（0902 深夜她要棋牌室那两款：赤薔薇 = 大标题，たぬゴ = 小标题 / 按钮）
//
// 都是日文字体，只有繁体字形 → 固定文案一律繁体（跟棋牌室 0828 的拍板一样）。
// 服务器来的牌名 / 关键词 / 位置名 / 死解是简体，一律留系统字体，免得缺字混排。
// 两款都没有「每」「你」「錄」，赤薔薇还缺「關」「沒」「璟」「黑」的字形（空白），文案绕开了。

extension Font {
    static func tarotTitle(_ size: CGFloat) -> Font { .custom("CQW-Akabara", size: size) }
    static func tarotHand(_ size: CGFloat) -> Font { .custom("Tanugo-S-TTF-Regular", size: size) }
}

/// 慢慢呼吸的透明度（空牌格轮到谁谁在呼吸）
struct TarotBreathing: ViewModifier {
    var on: Bool
    @State private var phase = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? (phase ? 1 : 0.55) : 1)
            .animation(on ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .default, value: phase)
            .onAppear { phase = on }
            .onChange(of: on) { _, v in phase = v }
    }
}

/// iOS 那种雾面玻璃按钮：不实心，底下压一层紫晕，边上一圈细亮线
struct TarotGlassButtonStyle: ViewModifier {
    var prominent: Bool = true

    func body(content: Content) -> some View {
        content
            .foregroundColor(TarotInk.buttonInk)
            .background(TarotInk.buttonGlow.opacity(prominent ? 1 : 0.45), in: Capsule())
            .background(TarotInk.glassMaterial, in: Capsule())
            .overlay(Capsule().stroke(TarotInk.ink.opacity(prominent ? 0.28 : 0.16), lineWidth: 1))
            .shadow(color: TarotInk.buttonGlow.opacity(prominent ? 0.6 : 0), radius: 14, y: 4)
    }
}

extension View {
    func tarotGlassButton(prominent: Bool = true) -> some View {
        modifier(TarotGlassButtonStyle(prominent: prominent))
    }
}

/// 夜空：深蓝到深紫的底，两团星云，一层会呼吸的星星。
/// 她在调色抽屉里选了壁纸就整屋铺她的图（全屏、盖到安全区外），星星那层看开关决定留不留。
struct TarotSky: View {
    @ObservedObject private var decor = TarotDecor.shared

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
            if let wp = decor.wallpaper {
                GeometryReader { geo in
                    Image(uiImage: wp)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                if decor.starsOnWallpaper { starField.opacity(0.85) }
            } else {
                LinearGradient(colors: [TarotInk.skyTop, TarotInk.skyMid, TarotInk.skyBottom],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [TarotInk.nebulaA, .clear],
                               center: UnitPoint(x: 0.2, y: 0.25), startRadius: 0, endRadius: 320)
                RadialGradient(colors: [TarotInk.nebulaB, .clear],
                               center: UnitPoint(x: 0.85, y: 0.7), startRadius: 0, endRadius: 300)
                starField
            }
        }
        .ignoresSafeArea()
    }

    private var starField: some View {
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
}

// MARK: - 牌

/// 牌面：公版韦特扫描 → 抽掉颜色 → 染成夜空淡紫。逆位倒着放。
/// 抽多少色、染成什么色由 TarotDecor 决定（她自己在屋里的装修抽屉拧）。
struct TarotCardFace: View {
    let cardID: String
    var reversed: Bool = false
    var width: CGFloat = 120
    @ObservedObject var decor = TarotDecor.shared

    var body: some View {
        let h = width * 1.72
        let shape = RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
        return Image("Tarot_" + cardID)
            .resizable()
            .scaledToFill()
            .saturation(decor.saturation)
            .colorMultiply(decor.multiply)
            .frame(width: width, height: h)
            .clipShape(shape)
            .overlay(shape.stroke(TarotInk.gold.opacity(0.55), lineWidth: 1))
            .rotationEffect(.degrees(reversed ? 180 : 0))
            .shadow(color: .black.opacity(0.45), radius: width * 0.08, y: width * 0.05)
    }
}

/// 牌背（0902 深夜她换的）：她发的那张黑底星盘（Assets/TarotBack，只裁了框里面的花纹），
/// 抽色后按调色抽屉里的颜色染线，底下压一层同色压暗的渐变，边框还是我们自己的细亮线。
/// 换了牌面颜色牌背一起变。
struct TarotCardBack: View {
    var width: CGFloat = 120
    @ObservedObject var decor = TarotDecor.shared
    /// 老牌背的线色，别处还引用着
    static let line = Color(red: 0.78, green: 0.70, blue: 1.0)

    var body: some View {
        let h = width * 1.72
        let shape = RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
        let tint = decor.color
        return ZStack {
            shape.fill(LinearGradient(colors: [decor.deep(0.30), decor.deep(0.10)],
                                      startPoint: .top, endPoint: .bottom))
            // 花纹是黑底白线：抽色 → 染成 tint → screen 混合，黑的部分透出底色，线是 tint
            Image("TarotBack")
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.94, height: h * 0.94)
                .saturation(0)
                .colorMultiply(tint)
                .blendMode(.screen)
            shape.stroke(tint.opacity(0.75), lineWidth: 1)
            RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 0.8)
                .padding(width * 0.06)
        }
        .compositingGroup()
        .frame(width: width, height: h)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.45), radius: width * 0.06, y: width * 0.04)
    }
}

// MARK: - 牌带零件

/// 牌带（0902 深夜照她发的粉色参考图做的；0903 凌晨抽成零件，聊天页「他出题她抽」的卡也用它）：
/// 整副牌一字排开、只带一点弧度，手指左右拖整副牌跟着走，滚到正中间的那张自动往前突出来放大；
/// 再点它 → onChoose(第几张)。两头滑到头就停，但首尾也能到正中间。松手带一点惯性，然后吸到最近的一张。
/// 只画屏幕附近那十几张；两边渐隐。放进聊天页的 ScrollView 里要 highPriority，不然竖着滚会把它吞掉。
struct TarotDeckBand: View {
    let deck: [String]
    var cardW: CGFloat = 84
    var gap: CGFloat = 46            // 相邻两张中心距（叠着排）
    var arc: CGFloat = 1500          // 弧的半径：越大越直
    var lift: CGFloat = 34           // 中间那张往上顶多少
    var pop: CGFloat = 0.22          // 中间那张放大多少
    var highPriority: Bool = false
    let onChoose: (Int) -> Void

    /// 滚到哪：以「第几张在正中间」计，可以是小数（手指拖着的时候）。-1 = 还没定位
    @State private var scroll: CGFloat = -1
    @State private var dragStart: CGFloat?

    private var maxScroll: CGFloat { CGFloat(max(0, deck.count - 1)) }
    private func clamp(_ v: CGFloat) -> CGFloat { min(max(0, v), maxScroll) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if highPriority {
                band(width: w, height: h).highPriorityGesture(drag(width: w))
            } else {
                band(width: w, height: h).gesture(drag(width: w))
            }
        }
        .onAppear { if scroll < 0 { scroll = CGFloat(deck.count / 2) } }
        .onChange(of: deck.count) { _, _ in scroll = clamp(scroll) }
    }

    private func band(width: CGFloat, height: CGFloat) -> some View {
        let n = deck.count
        let baseY = height * 0.58
        let half = Int(ceil(width / 2 / gap)) + 2
        let c = Int(max(0, scroll).rounded())
        let lo = max(0, c - half), hi = min(n - 1, c + half)
        return ZStack {
            if n > 0, lo <= hi {
                ForEach(lo...hi, id: \.self) { i in
                    let d = CGFloat(i) - max(0, scroll)            // 离正中间几张（带小数）
                    let dx = d * gap
                    let wgt = max(0, 1 - abs(d))                   // 「突出」程度：正中间 1，隔一张 0
                    let ang = atan(dx / arc)
                    let y = baseY + dx * dx / (2 * arc) - wgt * lift
                    TarotCardBack(width: cardW)
                        .scaleEffect(1 + pop * wgt)
                        .rotationEffect(.radians(Double(ang)))
                        .position(x: width / 2 + dx, y: y)
                        .zIndex(1000 - Double(abs(d)))
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .mask(
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: .black, location: 0.22),
                                   .init(color: .black, location: 0.78),
                                   .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .contentShape(Rectangle())
        .drawingGroup()
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragStart == nil { dragStart = scroll }
                scroll = clamp((dragStart ?? scroll) - v.translation.width / gap)
            }
            .onEnded { v in
                let start = dragStart ?? scroll
                dragStart = nil
                let dist = hypot(v.translation.width, v.translation.height)
                if dist < 8 {
                    // 点：点的是正中间那张就选它；点的是旁边的就把那张滚到中间
                    let hit = (v.location.x - width / 2) / gap
                    let center = Int(scroll.rounded())
                    if abs(hit) < 0.75, abs(scroll - CGFloat(center)) < 0.05, center < deck.count {
                        onChoose(center)
                    } else {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            scroll = clamp((scroll + hit).rounded())
                        }
                    }
                    return
                }
                // 松手：按预测的落点带一点惯性，最多再飞 6 张，然后吸到最近一张
                var target = start - v.predictedEndTranslation.width / gap
                target = min(max(target, scroll - 6), scroll + 6)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    scroll = clamp(target.rounded())
                }
            }
    }
}

// MARK: - 房间

struct TarotRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TarotStore.shared
    @ObservedObject private var decor = TarotDecor.shared

    private enum Phase: Equatable { case pick, draw, result }
    @State private var phase: Phase = .pick
    @State private var spread: TarotSpread?
    @State private var question = ""
    @State private var deckOrder: [String] = []
    @State private var drawn: [TarotDrawn] = []
    @State private var fanVisible = true
    @State private var chosen: TarotDrawn?
    @State private var flip: Double = 0         // 0 背面 … 180 正面
    @State private var bigScale: CGFloat = 0.4
    @State private var reading: TarotReading?
    @State private var showHistory = false
    @State private var showTint = false
    @State private var showCompendium = false
    /// 开屏左上那两张叠着的牌：上面是本周还是今日
    @State private var stackShowsWeek = false
    @State private var stackDrag: CGFloat = 0
    @State private var busy = false
    @State private var toast = ""
    @FocusState private var questionFocused: Bool

    /// 顶部安全区：这间屋是 ownsFullScreen，外面那层把安全区全吃了（ignoresSafeArea），
    /// 头得自己让开灵动岛。GeometryReader 在这里读到的是 0，去问 key window。
    /// ‼️这个坑这项目踩了 N 次（0901 麻将、0902 通话、0902 占星室），全屏房间第一件事就是它。
    private var safeTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let win = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.flatMap(\.windows).first
        return win?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        GeometryReader { geo in
        ZStack {
            TarotSky()
            VStack(spacing: 0) {
                header
                    .padding(.top, max(geo.safeAreaInsets.top, safeTop, 20))
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
        }
        .task {
            await store.loadDeck()
            await store.loadReadings()
        }
        .sheet(isPresented: $showHistory) {
            TarotHistorySheet(store: store)
        }
        .sheet(isPresented: $showTint) {
            TarotDecorSheet()
        }
        .sheet(isPresented: $showCompendium) {
            TarotCompendiumView(store: store)
        }
    }

    // MARK: 头

    /// 0902 深夜她抓的：返回键在哪页都直接退出屋子。改成一层层退：抽牌页 / 结果页 → 选牌阵页，
    /// 选牌阵页 → 出屋。抽到一半按返回，这一次就作废（还没存）
    private func goBack() {
        switch phase {
        case .pick:
            dismiss()
        case .draw, .result:
            reset()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(TarotInk.dim)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Color.clear.frame(width: 38, height: 38)
            VStack(spacing: 1) {
                // 0902 深夜她要法语标头。赤薔薇有拉丁字母但没有带音标的（é è ç…），
                // 所以词要挑没音标的；たぬゴ全有。她换词的话只改这一行
                Text("Chambre des Étoiles")
                    .font(.tarotHand(21))
                    .foregroundColor(TarotInk.ink)
                Text("占星室")
                    .font(.tarotHand(10))
                    .tracking(3)
                    .foregroundColor(TarotInk.gold.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            Button { showTint = true } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(TarotInk.dim)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
    //
    // 0902 深夜她定的：入口是带牌面的牌，比上一版小一号。
    //   左上：「今日 / 本周」两张叠在一起（像 iMessage 发多图那样叠着），左右滑换哪张在上面，点上面那张就抽；
    //         这两种不用写问题，一天 / 一周只抽一次，抽过再点直接看那次
    //   右上：单张；下面：三张、关系
    //   再往下一行「牌義圖鑑」进图鉴；然后是所问 + 洗牌

    private struct Entry: Identifiable {
        let id: String          // 牌阵 id
        let cardID: String      // 入口上画哪张牌面
        let name: String        // 固定文案（繁体，走たぬゴ）
        let fallbackHint: String
    }

    private static let dailyEntry = Entry(id: "one", cardID: "major_19", name: "今日一牌", fallbackHint: "听听今天想告诉你的话")
    private static let weekEntry = Entry(id: "week", cardID: "major_17", name: "本周運勢", fallbackHint: "本周主轴 · 行动建议 · 温柔提醒")
    private static let entries: [Entry] = [
        Entry(id: "one", cardID: "major_01", name: "單張", fallbackHint: "一句话问，一张牌答"),
        Entry(id: "three", cardID: "major_18", name: "三張", fallbackHint: "过去 · 现在 · 未来"),
        Entry(id: "relation", cardID: "major_06", name: "關係", fallbackHint: "我 · 他 · 我们之间 · 阻碍 · 走向"),
    ]

    /// 今日一牌 / 本周运势 靠 question 这两句来认（服务端不用知道）
    static let dailyQuestion = "每日一牌"
    static let weeklyQuestion = "本周运势"

    private var pickView: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if store.loadFailed {
                        Text("牌义表没拉下来，下拉再试")
                            .font(.system(size: 12)).foregroundColor(TarotInk.dim).padding(.top, 40)
                    } else if store.spreads.isEmpty {
                        ProgressView().tint(TarotInk.dim).padding(.top, 40)
                    } else {
                        let cardW = min(100, (geo.size.width - 36 - 22) / 2 - 12)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 22), GridItem(.flexible(), spacing: 22)],
                                  spacing: 16) {
                            periodicStack(width: cardW)
                            ForEach(Self.entries) { e in
                                entryCard(e, width: cardW)
                            }
                        }
                        .padding(.top, 4)

                        compendiumRow

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("所問")
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
                            Text(spread == nil ? "先點一張牌選牌陣" : "洗牌")
                                .font(.tarotHand(17))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .tarotGlassButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(spread == nil)
                        .opacity(spread == nil ? 0.4 : 1)
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .refreshable {
                store.loadFailed = false
                await store.loadDeck()
            }
            .onTapGesture { questionFocused = false }
        }
    }

    /// 一张入口牌：牌面 + 名字 + 一句说明。选中的那张描金边、往上顶一点
    private func entryCard(_ e: Entry, width: CGFloat) -> some View {
        let sp = store.spread(e.id)
        let selected = spread?.id == e.id && question != Self.dailyQuestion && question != Self.weeklyQuestion
        return Button {
            questionFocused = false
            if let sp {
                if question == Self.dailyQuestion || question == Self.weeklyQuestion { question = "" }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { spread = sp }
            }
        } label: {
            VStack(spacing: 8) {
                TarotCardFace(cardID: e.cardID, width: width)
                    .overlay(RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
                        .stroke(TarotInk.gold.opacity(selected ? 0.95 : 0), lineWidth: 1.5))
                    .shadow(color: TarotInk.gold.opacity(selected ? 0.45 : 0), radius: 14)
                    .offset(y: selected ? -6 : 0)
                    .padding(.top, 8)
                Text(e.name)
                    .font(.tarotHand(16))
                    .foregroundColor(TarotInk.ink)
                Text(sp?.hint ?? e.fallbackHint)
                    .font(.system(size: 10.5))
                    .foregroundColor(selected ? TarotInk.gold : TarotInk.dim)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28, alignment: .top)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 左上那格：今日 / 本周 两张叠着的牌。下面那张往右上错开一点、微微歪；
    /// 左右滑 → 换哪张在上面；点上面那张 → 抽（或看今天 / 这周已经抽过的那次）
    private func periodicStack(width: CGFloat) -> some View {
        let top = stackShowsWeek ? Self.weekEntry : Self.dailyEntry
        let under = stackShowsWeek ? Self.dailyEntry : Self.weekEntry
        return VStack(spacing: 8) {
            ZStack {
                TarotCardFace(cardID: under.cardID, width: width)
                    .rotationEffect(.degrees(7))
                    .offset(x: 12, y: -4)
                    .opacity(0.8)
                TarotCardFace(cardID: top.cardID, width: width)
                    .rotationEffect(.degrees(-3 + Double(stackDrag / 30)))
                    .offset(x: stackDrag * 0.55, y: 0)
            }
            .frame(width: width + 24, height: width * 1.72 + 8)
            .padding(.top, 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in stackDrag = max(-60, min(60, v.translation.width)) }
                    .onEnded { v in
                        if abs(v.translation.width) > 28 {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { stackShowsWeek.toggle() }
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { stackDrag = 0 }
                    }
            )
            .onTapGesture {
                questionFocused = false
                if stackShowsWeek { startWeekly() } else { startDaily() }
            }
            Text(top.name)
                .font(.tarotHand(16))
                .foregroundColor(TarotInk.ink)
                .contentTransition(.opacity)
            Text(top.fallbackHint)
                .font(.system(size: 10.5))
                .foregroundColor(TarotInk.dim)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28, alignment: .top)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 4) {
                        Circle().fill(TarotInk.gold.opacity(stackShowsWeek ? 0.3 : 0.9)).frame(width: 4, height: 4)
                        Circle().fill(TarotInk.gold.opacity(stackShowsWeek ? 0.9 : 0.3)).frame(width: 4, height: 4)
                    }
                    .offset(y: 10)
                }
        }
    }

    /// 底下那一行：进牌义图鉴
    private var compendiumRow: some View {
        Button {
            questionFocused = false
            showCompendium = true
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: -16) {
                    ForEach(["major_00", "major_02", "major_09", "major_21"], id: \.self) { id in
                        TarotCardFace(cardID: id, width: 30)
                    }
                }
                .frame(width: 30 + 3 * 14, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("牌義圖鑑")
                        .font(.tarotHand(15))
                        .foregroundColor(TarotInk.ink)
                    Text("78 张牌，正逆位的关键词和一句解")
                        .font(.system(size: 10.5))
                        .foregroundColor(TarotInk.dim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundColor(TarotInk.faint)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(glassCard(selected: false))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 今日一牌：今天抽过就直接看那张；没抽过就单张、不填问题、直接洗牌
    private func startDaily() {
        if let r = store.readings.first(where: { $0.question == Self.dailyQuestion && Calendar.current.isDateInToday($0.date) }) {
            reading = r
            withAnimation(.easeInOut(duration: 0.25)) { phase = .result }
            return
        }
        guard let sp = store.spread("one") else { return }
        spread = sp
        question = Self.dailyQuestion
        startDrawing()
    }

    /// 本周运势：这周抽过就直接看那次；没抽过就「本周」三张、不填问题、直接洗牌
    private func startWeekly() {
        let cal = Calendar.current
        if let r = store.readings.first(where: {
            $0.question == Self.weeklyQuestion && cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }) {
            reading = r
            withAnimation(.easeInOut(duration: 0.25)) { phase = .result }
            return
        }
        guard let sp = store.spread("week") else {
            toast = "本周牌阵没拉下来，下拉刷新一下"
            return
        }
        spread = sp
        question = Self.weeklyQuestion
        startDrawing()
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(.tarotHand(12))
            .tracking(2)
            .foregroundColor(TarotInk.gold.opacity(0.75))
            .padding(.leading, 4)
    }

    private func glassCard(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(TarotInk.glassMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selected ? TarotInk.pill : TarotInk.glass))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? TarotInk.gold.opacity(0.7) : TarotInk.glassLine, lineWidth: 1))
    }

    // MARK: 抽牌

    private var nextPosition: TarotPosition? {
        guard let sp = spread, drawn.count < sp.positions.count else { return nil }
        return sp.positions[drawn.count]
    }

    /// 扇形那块的高度。0902 晚她验收：抽牌页整体太靠下、中间太空 → 牌阵格子下移做大，
    /// 扇子做高往上提，提示字放在两者之间偏上。手势 / 弹簧 / drawingGroup 一律没动。
    private let fanHeight: CGFloat = 300

    private var drawView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                slotsRow
                    .padding(.top, 44)
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
                        Text("左右滑动整副牌，中间那张再点一下就是它")
                            .font(.system(size: 11.5))
                            .foregroundColor(TarotInk.dim)
                    }
                    Spacer(minLength: 0)
                    Spacer(minLength: 0)
                }
                TarotDeckBand(deck: deckOrder, onChoose: { choose(index: $0) })
                    .frame(height: fanHeight)
                    .opacity(fanVisible ? 1 : 0)
                    .scaleEffect(fanVisible ? 1 : 0.92, anchor: .bottom)
                    .allowsHitTesting(fanVisible && chosen == nil)
                    .padding(.bottom, 8)
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
                            emptySlot(width: slotWidth(sp), active: pos.key == nextPosition?.key)
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

    /// 空格子（0902 深夜她说光一个虚线框太空）：里面垫一张很淡的牌背当「影子」，
    /// 轮到的那格影子亮一点、慢慢呼吸；没轮到的就是一道淡影 + 虚线
    private func emptySlot(width: CGFloat, active: Bool) -> some View {
        ZStack {
            TarotCardBack(width: width)
                .opacity(active ? 0.42 : 0.16)
                .modifier(TarotBreathing(on: active))
            RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
                .stroke(TarotInk.gold.opacity(active ? 0.8 : 0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
        .frame(width: width, height: width * 1.72)
    }

    private func slotWidth(_ sp: TarotSpread) -> CGFloat {
        switch sp.positions.count {
        case 1: return 120
        case 3: return 92
        default: return 60
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

    private func startDrawing() {
        guard spread != nil else { return }
        deckOrder = store.cards.map { $0.id }.shuffled()
        drawn = []
        chosen = nil
        fanVisible = true
        withAnimation(.easeInOut(duration: 0.25)) { phase = .draw }
    }

    private func choose(index: Int) {
        guard index < deckOrder.count, let pos = nextPosition, chosen == nil else { return }
        let id = deckOrder.remove(at: index)
        let pick = TarotDrawn(cardID: id, reversed: Bool.random(), position: pos.key)
        flip = 0
        bigScale = 0.4
        chosen = pick
        // 1) 扇子退场，选中那张放大
        withAnimation(.easeOut(duration: 0.28)) { fanVisible = false }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { bigScale = 1 }
        // 2) 翻面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard phase == .draw else { return }        // 中途按了返回就别接着演了
            withAnimation(.easeInOut(duration: 0.55)) { flip = 180 }
        }
        // 3) 落进牌阵
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            guard phase == .draw, chosen != nil else { return }
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
        // 今日一牌 / 本周运势自动填的那句问题别留在输入框里
        if question == Self.dailyQuestion || question == Self.weeklyQuestion { question = "" }
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
    @ObservedObject var decor = TarotDecor.shared
    var onAgain: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var toast: ((String) -> Void)? = nil
    @State private var asking = false
    @State private var asked = false
    @State private var saving = false
    /// 客观解读：进来用服务端给的；她点了别的类型就重算
    @State private var interp: TarotInterp?
    @State private var category: String?
    @State private var interpBusy = false
    /// AI 细解
    @State private var ai: TarotAI?
    @State private var aiBusy = false
    @State private var aiError = ""

    private var spread: TarotSpread? { store.spread(reading.spread) }
    private var shownInterp: TarotInterp? { interp ?? reading.interp }

    private struct Category: Identifiable { let id: String; let name: String }
    private static let categories: [Category] = [
        Category(id: "love", name: "感情"), Category(id: "work", name: "事業"),
        Category(id: "self", name: "自我"), Category(id: "daily", name: "日常"),
    ]

    /// 0902 深夜她要的：把这次占卜画成一张竖长票存进相册（TarotTicketView 用 ImageRenderer 出图）
    private func saveTicket() {
        saving = true
        let renderer = ImageRenderer(content: TarotTicketView(reading: reading, store: store))
        renderer.scale = 3
        guard let img = renderer.uiImage else {
            saving = false
            toast?("没画出来")
            return
        }
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                saving = false
                toast?("没有相册权限，去设置里开一下")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: img)
                }
                toast?("存进相册了")
            } catch {
                toast?("没存上")
            }
            saving = false
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("READING")
                        .font(.tarotHand(10)).tracking(3)
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
                        if reading.byHim || reading.askedByHim {
                            Text(reading.byHim ? "他抽的" : "他出的題")
                                .font(.tarotHand(10))
                                .foregroundColor(TarotInk.gold)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().stroke(TarotInk.gold.opacity(0.7), lineWidth: 1))
                        }
                    }
                }
                .padding(.top, 8)

                if !reading.question.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("所問").font(.tarotHand(12)).tracking(2)
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

                if let ip = shownInterp {
                    interpBlock(ip)
                }
                aiBlock

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
                        Text((asked || reading.asked) ? "已經發給陳璟了" : "讓陳璟解牌")
                    }
                    .font(.tarotHand(16))
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
                    Button(saving ? "存着…" : "存成圖片") { saveTicket() }
                        .disabled(saving)
                    if let onDelete {
                        Button("刪除這一條") { onDelete() }
                    }
                }
                .font(.tarotHand(13))
                .foregroundColor(TarotInk.dim)
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
    }

    private var glass: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(TarotInk.glassMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TarotInk.glass))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TarotInk.glassLine, lineWidth: 1))
    }

    // MARK: 客观解读（查表拼的）

    private func interpBlock(_ ip: TarotInterp) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("客觀解讀").font(.tarotHand(13)).tracking(1).foregroundColor(TarotInk.gold)
                Spacer()
                if interpBusy { ProgressView().controlSize(.mini).tint(TarotInk.dim) }
            }
            // 问题类型：不点 = 服务端按问题猜的那种
            HStack(spacing: 6) {
                ForEach(Self.categories) { c in
                    let on = (category ?? ip.category) == c.id
                    Button {
                        guard !interpBusy else { return }
                        category = c.id
                        interpBusy = true
                        Task {
                            if let fresh = await store.interp(reading.id, category: c.id) { interp = fresh }
                            interpBusy = false
                        }
                    } label: {
                        Text(c.name).font(.tarotHand(11))
                            .foregroundColor(on ? TarotInk.ink : TarotInk.dim)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(on ? TarotInk.pill : Color.clear))
                            .overlay(Capsule().stroke(on ? TarotInk.gold.opacity(0.7) : TarotInk.glassLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            para("整體印象", ip.overall)
            ForEach(ip.cards) { c in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if ip.cards.count > 1 && !c.positionName.isEmpty {
                            Text(c.positionName).font(.system(size: 10.5, weight: .semibold)).foregroundColor(TarotInk.gold)
                        }
                        Text(c.name).font(.system(size: 14, weight: .medium, design: .serif)).foregroundColor(TarotInk.ink)
                        Text(c.reversed ? "逆位" : "正位").font(.system(size: 10)).foregroundColor(c.reversed ? TarotInk.gold : TarotInk.tint)
                    }
                    Text(c.intro).font(.system(size: 11)).foregroundColor(TarotInk.faint)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(c.text).font(.system(size: 13, design: .serif)).foregroundColor(TarotInk.ink).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if !c.advice.isEmpty {
                        Text("→ " + c.advice).font(.system(size: 12)).foregroundColor(TarotInk.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !ip.relations.isEmpty { para("牌面關係", ip.relations.joined(separator: "\n")) }
            if !ip.advice.isEmpty { para("建議", ip.advice.map { "· " + $0 }.joined(separator: "\n")) }
            para("一句話", ip.oneline)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(glass)
    }

    private func para(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.tarotHand(11)).tracking(1.5).foregroundColor(TarotInk.gold.opacity(0.8))
            Text(body).font(.system(size: 13, design: .serif)).foregroundColor(TarotInk.ink).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: AI 细解（按需，两三分钱一次，存过就不再花）

    private var aiBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("AI 細解").font(.tarotHand(13)).tracking(1).foregroundColor(TarotInk.gold)
                Spacer()
                if ai != nil {
                    Button { runAI(force: true) } label: {
                        Text(aiBusy ? "寫著…" : "重寫").font(.tarotHand(11)).foregroundColor(TarotInk.dim)
                    }
                    .buttonStyle(.plain).disabled(aiBusy)
                }
            }
            if let a = ai {
                para("整體印象", a.overall)
                ForEach(a.cards) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.name).font(.system(size: 14, weight: .medium, design: .serif)).foregroundColor(TarotInk.ink)
                        Text(c.reading).font(.system(size: 13, design: .serif)).foregroundColor(TarotInk.ink).lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !a.relations.isEmpty { para("牌面關係", a.relations) }
                if !a.advice.isEmpty { para("建議", a.advice) }
                if !a.oneline.isEmpty { para("一句話", a.oneline) }
            } else {
                Text("很想深挖的时候再按。一个不认识你的塔罗师，只看牌，写得很细。一次两三分钱，写过就存着。")
                    .font(.system(size: 11.5)).foregroundColor(TarotInk.dim)
                    .fixedSize(horizontal: false, vertical: true)
                Button { runAI(force: false) } label: {
                    HStack(spacing: 8) {
                        if aiBusy { ProgressView().controlSize(.small).tint(TarotInk.ink) }
                        Text(aiBusy ? "寫著，要半分鐘…" : "讓 AI 細解")
                    }
                    .font(.tarotHand(14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .tarotGlassButton(prominent: false)
                }
                .buttonStyle(.plain).disabled(aiBusy)
            }
            if !aiError.isEmpty {
                Text(aiError).font(.system(size: 11)).foregroundColor(TarotInk.gold)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(glass)
        .task {
            if ai == nil, let hit = await store.aiCached(reading.id) { ai = hit }
        }
    }

    private func runAI(force: Bool) {
        guard !aiBusy else { return }
        aiBusy = true
        aiError = ""
        Task {
            let (res, err) = await store.ai(reading.id, category: category ?? shownInterp?.category, force: force)
            aiBusy = false
            if let res { ai = res } else { aiError = err }
        }
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
    @ObservedObject private var decor = TarotDecor.shared
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
                            .background(Capsule().fill(TarotInk.glassMaterial))
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
    @ObservedObject var decor = TarotDecor.shared
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
                    if r.byHim || r.askedByHim {
                        Text(r.byHim ? "他抽的" : "他出的題")
                            .font(.tarotHand(9)).foregroundColor(TarotInk.gold)
                    }
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TarotInk.glassMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(TarotInk.glassLine, lineWidth: 1))
    }
}

// MARK: - 装修抽屉（壁纸 / 牌面染色 / 雾面玻璃）

/// 她自己拧的抽屉：三段。壁纸（相册选一张，整屋全屏铺；星星开关）、牌面染色（样牌 + 浓度 + 黑白 + 颜色）、
/// 雾面玻璃（浓度 + 颜色）。拧的都是当前日夜那一套。
struct TarotDecorSheet: View {
    @ObservedObject private var decor = TarotDecor.shared
    @State private var pick: PhotosPickerItem?
    @State private var loadingWallpaper = false

    /// 样牌：星星。画面亮、颜色多，最看得出染没染
    private let sampleID = "major_17"

    private struct Preset: Identifiable {
        let name: String
        let color: Color
        var id: String { name }
    }

    private static let presets: [Preset] = [
        Preset(name: "薰衣草", color: Color(red: 0.72, green: 0.60, blue: 1.0)),
        Preset(name: "玫瑰", color: Color(red: 1.0, green: 0.64, blue: 0.80)),
        Preset(name: "金", color: Color(red: 0.96, green: 0.80, blue: 0.50)),
        Preset(name: "青", color: Color(red: 0.56, green: 0.86, blue: 0.92)),
        Preset(name: "鼠尾草", color: Color(red: 0.68, green: 0.84, blue: 0.70)),
        Preset(name: "胭脂", color: Color(red: 0.88, green: 0.40, blue: 0.46)),
        Preset(name: "霜", color: Color(red: 0.88, green: 0.90, blue: 0.97)),
    ]

    private static let glassPresets: [Preset] = [
        Preset(name: "白", color: .white),
        Preset(name: "黑", color: .black),
        Preset(name: "薰衣草", color: Color(red: 0.72, green: 0.60, blue: 1.0)),
        Preset(name: "玫瑰", color: Color(red: 1.0, green: 0.64, blue: 0.80)),
        Preset(name: "金", color: Color(red: 0.96, green: 0.80, blue: 0.50)),
        Preset(name: "青", color: Color(red: 0.56, green: 0.86, blue: 0.92)),
        Preset(name: "墨", color: Color(red: 0.16, green: 0.10, blue: 0.30)),
    ]

    var body: some View {
        let c = decor.current
        let g = decor.glass
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 8) {
                    Text("占星室裝修")
                        .font(.tarotTitle(22))
                        .foregroundColor(TarotInk.ink)
                    Text(TarotInk.dark ? "夜里这套" : "白天这套")
                        .font(.system(size: 10, weight: .semibold)).tracking(1)
                        .foregroundColor(TarotInk.gold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().stroke(TarotInk.gold.opacity(0.6), lineWidth: 1))
                    Spacer()
                }
                .padding(.top, 22)

                // —— 壁纸 ——
                VStack(alignment: .leading, spacing: 10) {
                    label("壁纸")
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            if let wp = decor.wallpaper {
                                Image(uiImage: wp).resizable().scaledToFill()
                            } else {
                                LinearGradient(colors: [TarotInk.skyTop, TarotInk.skyMid, TarotInk.skyBottom],
                                               startPoint: .top, endPoint: .bottom)
                                Text("代码画的天")
                                    .font(.system(size: 10)).foregroundColor(TarotInk.dim)
                            }
                            if loadingWallpaper { ProgressView().tint(TarotInk.ink) }
                        }
                        .frame(width: 72, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(TarotInk.glassLine, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 10) {
                            Text("整间屋全屏铺一张，选牌阵、抽牌、看结果都是它。夜里、白天各存一张。")
                                .font(.system(size: 11.5)).foregroundColor(TarotInk.dim)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                PhotosPicker(selection: $pick, matching: .images) {
                                    Text(decor.wallpaper == nil ? "去相册选一张" : "换一张")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .tarotGlassButton()
                                }
                                .buttonStyle(.plain)
                                if decor.wallpaper != nil {
                                    Button { decor.clearWallpaper() } label: {
                                        Text("用回代码画的天")
                                            .font(.system(size: 12.5, weight: .medium))
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .tarotGlassButton(prominent: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Toggle(isOn: $decor.starsOnWallpaper) {
                                Text("壁纸上面撒星星")
                                    .font(.system(size: 13)).foregroundColor(TarotInk.ink)
                            }
                            .tint(TarotInk.gold)
                            .disabled(decor.wallpaper == nil)
                            .opacity(decor.wallpaper == nil ? 0.45 : 1)
                        }
                    }
                }

                divider

                // —— 牌面染色 ——
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 8) {
                            TarotCardFace(cardID: sampleID, width: 84)
                            TarotCardBack(width: 84)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            label("牌面染色")
                            Text("原图是彩色的老扫描件。浓度往左是原图，往右是整张刷成一个颜色。牌背的花纹跟着同一个颜色走。")
                                .font(.system(size: 11.5)).foregroundColor(TarotInk.dim)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text("染色浓度").font(.system(size: 12)).foregroundColor(TarotInk.ink)
                                Spacer()
                                Text("\(Int((c.strength * 100).rounded()))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(TarotInk.gold)
                            }
                            Slider(value: Binding(get: { c.strength },
                                                  set: { v in decor.update { $0.strength = v } }),
                                   in: 0...1)
                                .tint(TarotInk.gold)
                            Toggle(isOn: Binding(get: { c.mono }, set: { v in decor.update { $0.mono = v } })) {
                                Text("没染到的部分用黑白")
                                    .font(.system(size: 12)).foregroundColor(TarotInk.ink)
                            }
                            .tint(TarotInk.gold)
                        }
                    }
                    colorRow(title: "染的颜色", presets: Self.presets, current: decor.color) { col in
                        decor.update { $0.color = col }
                    }
                    resetButton(disabled: decor.isDefault) { decor.resetCurrent() }
                }

                divider

                // —— 雾面玻璃 ——
                VStack(alignment: .leading, spacing: 12) {
                    label("雾面玻璃")
                    Text("暗玻璃卡和胶囊的颜色。浓度越高越糊、越不透。默认夜里白、白天黑。")
                        .font(.system(size: 11.5)).foregroundColor(TarotInk.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("样子")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(TarotInk.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TarotInk.glass))
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TarotInk.glassMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(TarotInk.glassLine, lineWidth: 1))
                    HStack {
                        Text("浓度").font(.system(size: 12)).foregroundColor(TarotInk.ink)
                        Spacer()
                        Text("\(Int((g.strength * 100).rounded()))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(TarotInk.gold)
                    }
                    Slider(value: Binding(get: { g.strength },
                                          set: { v in decor.updateGlass { $0.strength = v } }),
                           in: 0.05...1)
                        .tint(TarotInk.gold)
                    colorRow(title: "玻璃颜色", presets: Self.glassPresets, current: decor.glassColor) { col in
                        decor.updateGlass { $0.color = col }
                    }
                    resetButton(disabled: decor.glassIsDefault) { decor.resetGlass() }
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 22)
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            loadingWallpaper = true
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    if let data { decor.setWallpaper(data: data) }
                    loadingWallpaper = false
                    pick = nil
                }
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground {
            LinearGradient(colors: [TarotInk.skyMid, TarotInk.skyBottom],
                           startPoint: .top, endPoint: .bottom)
        }
        .preferredColorScheme(TarotInk.dark ? .dark : .light)
    }

    private var divider: some View {
        Rectangle().fill(TarotInk.glassLine).frame(height: 1)
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(2.5)
            .foregroundColor(TarotInk.gold.opacity(0.75))
    }

    /// 一行颜色：取色盘 + 一排预设色点
    private func colorRow(title: String, presets: [Preset], current: Color,
                          set: @escaping (Color) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundColor(TarotInk.ink)
                Spacer()
                ColorPicker("", selection: Binding(get: { current }, set: set), supportsOpacity: false)
                    .labelsHidden()
            }
            HStack(spacing: 12) {
                ForEach(presets) { p in
                    let on = p.color.hexString == current.hexString
                    Button { set(p.color) } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(p.color)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(TarotInk.ink.opacity(on ? 0.95 : 0.22),
                                                         lineWidth: on ? 2 : 1))
                            Text(p.name)
                                .font(.system(size: 9))
                                .foregroundColor(on ? TarotInk.ink : TarotInk.faint)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func resetButton(disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("恢复默认")
                .font(.system(size: 12.5, weight: .medium, design: .serif))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .tarotGlassButton(prominent: false)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}


// MARK: - 存成图片的长票

/// 一次占卜画成一张竖长票（宽 390，高随内容）：标头、日期、牌阵、所问、一排牌面、每张的位置 · 牌名 · 正逆位 · 关键词 · 一句解、落款。
/// 底是她的壁纸（没有就是代码画的天）。只给 ImageRenderer 用，不上屏。
struct TarotTicketView: View {
    let reading: TarotReading
    @ObservedObject var store: TarotStore
    @ObservedObject var decor = TarotDecor.shared

    private var spread: TarotSpread? { store.spread(reading.spread) }
    private var cardW: CGFloat {
        switch reading.cards.count {
        case 1: return 170
        case 2, 3: return 100
        default: return 62
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 4) {
                Text("Chambre des Étoiles").font(.tarotHand(20)).foregroundColor(TarotInk.ink)
                Text("占星室").font(.tarotHand(9)).tracking(3).foregroundColor(TarotInk.gold.opacity(0.8))
            }
            .padding(.top, 34)
            HStack(spacing: 8) {
                Text(TarotReadingView.dateText(reading.date))
                    .font(.system(size: 15, weight: .medium, design: .serif)).foregroundColor(TarotInk.ink)
                Text(spread?.name ?? reading.spread)
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(TarotInk.tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().stroke(TarotInk.tint.opacity(0.7), lineWidth: 1))
            }
            if !reading.question.isEmpty {
                Text("「\(reading.question)」")
                    .font(.system(size: 14, weight: .medium, design: .serif)).foregroundColor(TarotInk.ink)
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.horizontal, 30)
            }
            HStack(alignment: .top, spacing: reading.cards.count > 3 ? 8 : 14) {
                ForEach(reading.cards) { d in
                    VStack(spacing: 6) {
                        TarotCardFace(cardID: d.cardID, reversed: d.reversed, width: cardW)
                        if reading.cards.count > 1 {
                            Text(spread?.positions.first { $0.key == d.position }?.name ?? "")
                                .font(.system(size: 9.5, weight: .semibold)).foregroundColor(TarotInk.gold)
                        }
                    }
                }
            }
            Rectangle().fill(TarotInk.glassLine).frame(height: 1).padding(.horizontal, 40)
            VStack(spacing: 18) {
                ForEach(reading.cards) { d in
                    let card = store.card(d.cardID)
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            if reading.cards.count > 1 {
                                Text((spread?.positions.first { $0.key == d.position }?.name ?? "") + " · ")
                                    .font(.system(size: 13, design: .serif)).foregroundColor(TarotInk.gold)
                            }
                            Text(card?.name ?? d.cardID)
                                .font(.system(size: 15, weight: .medium, design: .serif)).foregroundColor(TarotInk.ink)
                            Text(d.reversed ? "逆位" : "正位")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(d.reversed ? TarotInk.gold : TarotInk.tint)
                        }
                        Text(card?.keywords(reversed: d.reversed).joined(separator: " · ") ?? "")
                            .font(.system(size: 10.5)).foregroundColor(TarotInk.dim)
                        Text(card?.meaning(reversed: d.reversed) ?? "")
                            .font(.system(size: 12, design: .serif)).foregroundColor(TarotInk.ink.opacity(0.9))
                            .multilineTextAlignment(.center).lineSpacing(3)
                            .padding(.horizontal, 26)
                    }
                }
            }
            if let ip = reading.interp {
                Rectangle().fill(TarotInk.glassLine).frame(height: 1).padding(.horizontal, 40)
                VStack(spacing: 8) {
                    Text("客觀解讀 · \(ip.categoryName)").font(.tarotHand(10)).tracking(2).foregroundColor(TarotInk.gold.opacity(0.8))
                    Text(ip.overall).font(.system(size: 12, design: .serif)).foregroundColor(TarotInk.ink)
                        .multilineTextAlignment(.center).lineSpacing(3).padding(.horizontal, 26)
                    Text(ip.oneline).font(.system(size: 12, weight: .medium, design: .serif)).foregroundColor(TarotInk.gold)
                        .multilineTextAlignment(.center).padding(.horizontal, 26)
                }
            }
            Text("ALCOVE · TAROT").font(.tarotHand(9)).tracking(3).foregroundColor(TarotInk.faint)
                .padding(.top, 8).padding(.bottom, 34)
        }
        .frame(width: 390)
        .background(
            ZStack {
                if let wp = decor.wallpaper {
                    Image(uiImage: wp).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [TarotInk.skyTop, TarotInk.skyMid, TarotInk.skyBottom],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .clipped()
        )
    }
}

// MARK: - 牌义图鉴

/// 78 张牌三列摆开，顶上筛大牌 / 四个花色，点一张看正逆位的关键词和那句解。牌面跟着她调的染色走。
struct TarotCompendiumView: View {
    @ObservedObject var store: TarotStore
    @ObservedObject private var decor = TarotDecor.shared
    @Environment(\.dismiss) private var dismiss
    @State private var filter = "all"
    @State private var open: TarotCard?

    /// 筛选标签是固定文案走たぬゴ（「卡」字它没有，大阿卡那叫「大牌」）
    private struct Filter: Identifiable { let id: String; let name: String }
    private static let filters: [Filter] = [
        Filter(id: "all", name: "全部"), Filter(id: "major", name: "大牌"), Filter(id: "cups", name: "聖杯"),
        Filter(id: "wands", name: "權杖"), Filter(id: "swords", name: "寶劍"), Filter(id: "pents", name: "星幣"),
    ]

    private var cards: [TarotCard] {
        switch filter {
        case "all": return store.cards
        case "major": return store.cards.filter { $0.arcana == "major" }
        default: return store.cards.filter { $0.suit == filter }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TarotSky()
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.filters) { f in
                                let on = filter == f.id
                                Button { withAnimation(.easeOut(duration: 0.15)) { filter = f.id } } label: {
                                    Text(f.name)
                                        .font(.tarotHand(13))
                                        .foregroundColor(on ? TarotInk.ink : TarotInk.dim)
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(Capsule().fill(on ? TarotInk.pill : Color.clear))
                                        .background(Capsule().fill(TarotInk.glassMaterial))
                                        .overlay(Capsule().stroke(on ? TarotInk.gold.opacity(0.7) : TarotInk.glassLine, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    GeometryReader { geo in
                        let w = (geo.size.width - 32 - 20) / 3
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                                ForEach(cards) { c in
                                    Button { open = c } label: {
                                        VStack(spacing: 5) {
                                            TarotCardFace(cardID: c.id, width: w)
                                            Text(c.name)
                                                .font(.system(size: 11, weight: .medium, design: .serif))
                                                .foregroundColor(TarotInk.ink)
                                                .lineLimit(1).minimumScaleFactor(0.8)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("牌義圖鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(TarotInk.dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundColor(TarotInk.dim)
                    }
                }
            }
            .navigationDestination(item: $open) { c in
                TarotCardDetailView(card: c)
            }
        }
        .preferredColorScheme(TarotInk.dark ? .dark : .light)
    }
}

/// 一张牌的牌义：大牌面、中英文名、正位一块、逆位一块
struct TarotCardDetailView: View {
    let card: TarotCard
    @ObservedObject private var decor = TarotDecor.shared

    var body: some View {
        ZStack {
            TarotSky()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    TarotCardFace(cardID: card.id, width: 190)
                        .padding(.top, 12)
                    VStack(spacing: 4) {
                        Text(card.name)
                            .font(.system(size: 22, weight: .medium, design: .serif)).foregroundColor(TarotInk.ink)
                        Text(card.en.uppercased())
                            .font(.tarotHand(10)).tracking(2).foregroundColor(TarotInk.gold.opacity(0.8))
                    }
                    meaningBlock(title: "正位", tint: TarotInk.tint, reversed: false)
                    meaningBlock(title: "逆位", tint: TarotInk.gold, reversed: true)
                }
                .padding(.horizontal, 18).padding(.bottom, 30)
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(TarotInk.dark ? .dark : .light, for: .navigationBar)
    }

    private func meaningBlock(title: String, tint: Color, reversed: Bool) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.tarotHand(12)).tracking(2).foregroundColor(tint)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Capsule().stroke(tint.opacity(0.7), lineWidth: 1))
            FlowPills(card.keywords(reversed: reversed))
            Text(card.meaning(reversed: reversed))
                .font(.system(size: 13.5, design: .serif)).foregroundColor(TarotInk.ink)
                .multilineTextAlignment(.center).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TarotInk.glass))
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TarotInk.glassMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(TarotInk.glassLine, lineWidth: 1))
    }
}
