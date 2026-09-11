import PhotosUI
import SwiftUI

// 钱包 / 购物系统（0907 她拍板开工）—— 第一期：纯账本，不碰淘宝、不碰审批卡。
//
// 分工：她充值、设三个上限、看账；他加心愿、买完照实付金额自己记一笔。
// 整套是「他自己记的账」，不对接任何支付接口（她 0907 第 5 问的原话）。
//
// 数据：/api/wallet/summary /ledger /wishlist /purchases /approvals /limits
//      POST /topup /spend /limits /wish/add /wish/update /wish/delete
//      /ledger/delete /purchase/update      —— serve.py 同源代理补 token。
//
// 五页对应她 0907 画的侧边栏：钱包 / 心愿单 / 已购买 / 审批记录 / 设置。
// 审批记录第一期恒空，页面在、表也在，等第二期审批卡接上就自己有内容了。

// MARK: - 调色（0909 她拍板：审美往开屏／棋牌室靠，卡片全毛玻璃，日夜跟 app 走）
//
// 原来是钉死的暖纸账本色（米黄纸 + 芥末金），她说丑，跟屋里别的房间不是一家人。
// 现在直接借棋牌室那套色号（低饱和灰蓝、白瓷/夜瓷），但**不共用 QipaiPalette
// 那个开关** —— 那个开关是棋牌室大厅的日月按钮、存在 UserDefaults 里的；
// 钱包要跟 app 的总开关走（AlcoveAppearance.isDark），两者不能互相拨。
// 所以这里自己留一个 dark，色号照抄，切换来源不同。
//
// 写成计算属性而不是 let：一千多行里到处是 WalletInk.xxx，改名等于全文替换，
// 只换值和取法就够了，一个引用都不用动。
private enum WalletInk {
    /// 由 WalletRoomView 在 body 里按 AlcoveAppearance.isDark 赋值
    static var dark = false
    private static func pick(_ day: UInt32, _ night: UInt32) -> Color {
        QipaiPalette.qhex(dark ? night : day)
    }
    static var paper: Color { pick(0xECEDF2, 0x20242E) }   // 底色·雾/夜（同棋牌室 fog）
    static var card: Color { pick(0xF7F8FB, 0x2A2F3A) }    // 面板·白瓷/夜瓷
    static var ink: Color { pick(0x585F6E, 0xD8DCE6) }     // 正文·石板/月白
    static var dim: Color { pick(0x9AA0AD, 0x8A92A3) }
    static var faint: Color { dark ? Color.white.opacity(0.26)
                                   : QipaiPalette.qhex(0x9AA0AD).opacity(0.55) }
    static var gold: Color { pick(0x7C8AA6, 0x93A5C8) }    // 强调·灰蓝（原芥末金，名字留着不改）
    static var goldSoft: Color { dark ? Color.white.opacity(0.13)
                                      : QipaiPalette.qhex(0x7C8AA6).opacity(0.16) }
    static var green: Color { pick(0x6E9A87, 0x8FBCA9) }
    static var red: Color { pick(0xC25B55, 0xD0736C) }
    static var line: Color { pick(0xD5D9E2, 0x3D4452) }
    /// 压在强调色块上的字：白天灰蓝够深、白字够看；夜里强调色变浅，白字会糊，改用底色
    static var onGold: Color { dark ? paper : .white }
    /// 阴影固定深色：夜里 ink 是月白，拿它当阴影会变成白光晕（棋牌室 0828 踩过）
    static var shadow: Color { (dark ? Color.black : QipaiPalette.qhex(0x585F6E)).opacity(0.10) }
}

// MARK: - 毛玻璃面板（照棋牌室白瓷面板的配方，但读 WalletInk）
//
// 没直接用 .qipaiPanel()：那个 modifier 内部读的是 QipaiPalette，会跟着棋牌室
// 大厅的日月按钮走，钱包要跟 app 总开关走，混在一起会出现「一间屋白天一间屋黑夜」。
// 配方一模一样：系统毛玻璃打底 → 一层白瓷 → 顶部一道浅高光让它微微凸起 → 头发丝描边。
private struct WalletPanelModifier: ViewModifier {
    var corner: CGFloat = 18
    var dotted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(WalletInk.card.opacity(WalletInk.dark ? 0.72 : 0.55))
                    if dotted {
                        QipaiDots(spacing: 14, radius: 1.6, color: WalletInk.line, opacity: 0.3)
                            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    }
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0)],
                                             startPoint: .top, endPoint: .center))
                        .padding(1)
                        .opacity(WalletInk.dark ? 0.12 : 0.6)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(WalletInk.line, lineWidth: 1))
            .shadow(color: WalletInk.shadow, radius: 7, y: 3)
    }
}

private extension View {
    func walletPanel(corner: CGFloat = 18, dotted: Bool = false) -> some View {
        modifier(WalletPanelModifier(corner: corner, dotted: dotted))
    }
}

private func money(_ v: Double) -> String {
    String(format: "%.2f", v)
}

private func shortTime(_ ts: String) -> String {
    // ts 形如 2026-09-07T17:15:15（后端已经按北京时间写好了，这里只切字符串）
    guard ts.count >= 16 else { return ts }
    let md = String(ts.dropFirst(5).prefix(5))
    let hm = String(ts.dropFirst(11).prefix(5))
    return md + " " + hm
}

// MARK: - 数据

struct WalletEntry: Identifiable {
    let id: Int
    let ts: String
    let kind: String        // income / expense / refund
    let amount: Double
    let balanceAfter: Double
    let note: String
    let overLimit: String

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        ts = json.string("ts")
        kind = json.string("kind")
        amount = json.double("amount")
        balanceAfter = json.double("balance_after")
        note = json.string("note")
        overLimit = json.string("over_limit")
    }

    var isOut: Bool { kind == "expense" }
    var signed: String { (isOut ? "-" : "+") + money(amount) }
    var tint: Color { isOut ? WalletInk.red : WalletInk.green }
}

struct WalletWish: Identifiable {
    let id: Int
    let ts: String
    let title: String
    let price: Double
    let cover: String
    let shop: String
    let url: String
    let forWhom: String     // self / her
    let reason: String
    let status: String      // idle/proposed/approved/rejected/bought/dropped

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        ts = json.string("ts")
        title = json.string("title")
        price = json.double("price")
        cover = json.string("cover")
        shop = json.string("shop")
        url = json.string("url")
        forWhom = json.string("for_whom")
        reason = json.string("reason")
        status = json.string("status")
    }

    var statusCN: String {
        switch status {
        case "idle": return "只是看看"
        case "proposed": return "等你拍板"
        case "approved": return "你点头了"
        case "rejected": return "你驳回了"
        case "bought": return "买了"
        case "dropped": return "不要了"
        default: return status
        }
    }

    var statusColor: Color {
        switch status {
        case "proposed": return WalletInk.gold
        case "approved", "bought": return WalletInk.green
        case "rejected", "dropped": return WalletInk.dim
        default: return WalletInk.faint
        }
    }
}

struct WalletPurchase: Identifiable {
    let id: Int
    let wishID: Int
    let ts: String
    let amount: Double
    let orderNo: String
    let status: String
    let arrivedAt: String
    let title: String
    let cover: String

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        wishID = json.int("wish_id")
        ts = json.string("ts")
        amount = json.double("amount")
        orderNo = json.string("order_no")
        status = json.string("status")
        arrivedAt = json.string("arrived_at")
        title = json.string("title")
        cover = json.string("cover")
    }

    var arrived: Bool { status == "arrived" || !arrivedAt.isEmpty }
}

struct WalletApproval: Identifiable {
    let id: Int
    let wishID: Int
    let tsProposed: String
    let tsDecided: String
    let decision: String
    let reason: String
    let round: Int

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        wishID = json.int("wish_id")
        tsProposed = json.string("ts_proposed")
        tsDecided = json.string("ts_decided")
        decision = json.string("decision")
        reason = json.string("reason")
        round = json.int("round")
    }
}

struct WalletLimits {
    var single: Double = 0
    var daily: Double = 0
    var monthly: Double = 0

    init() {}

    init(json: [String: Any]) {
        single = json.double("single_max")
        daily = json.double("daily_max")
        monthly = json.double("monthly_max")
    }
}

struct WalletSummary {
    let balance: Double
    let todaySpent: Double
    let monthSpent: Double
    let today: String
    let month: String
    let limits: WalletLimits
    let wishCount: Int
    let pendingCount: Int
    let boughtCount: Int
    let recent: [WalletEntry]

    init(json: [String: Any]) {
        balance = json.double("balance")
        todaySpent = json.double("today_spent")
        monthSpent = json.double("month_spent")
        today = json.string("today")
        month = json.string("month")
        limits = WalletLimits(json: json.object("limits"))
        let counts = json.object("counts")
        wishCount = counts.int("wishlist")
        pendingCount = counts.int("pending")
        boughtCount = counts.int("bought")
        recent = json.array("recent").compactMap(WalletEntry.init)
    }
}

// MARK: - Store

@MainActor
final class WalletStore: ObservableObject {
    @Published var summary: WalletSummary?
    @Published var wishes: [WalletWish] = []
    @Published var purchases: [WalletPurchase] = []
    @Published var approvals: [WalletApproval] = []
    @Published var ledger: [WalletEntry] = []
    @Published var busy = false
    @Published var loadFailed = false
    @Published var toast = ""

    func refreshAll() async {
        await refreshSummary()
        await refreshWishes()
        await refreshPurchases()
        await refreshApprovals()
        await refreshLedger()
    }

    func refreshSummary() async {
        do {
            let obj = try await NativeHouseAPI.object("/api/wallet/summary")
            summary = WalletSummary(json: obj)
            loadFailed = false
        } catch {
            loadFailed = summary == nil
        }
    }

    func refreshWishes() async {
        guard let obj = try? await NativeHouseAPI.object("/api/wallet/wishlist") else { return }
        wishes = obj.array("items").compactMap(WalletWish.init)
    }

    func refreshPurchases() async {
        guard let obj = try? await NativeHouseAPI.object("/api/wallet/purchases") else { return }
        purchases = obj.array("items").compactMap(WalletPurchase.init)
    }

    func refreshApprovals() async {
        guard let obj = try? await NativeHouseAPI.object("/api/wallet/approvals") else { return }
        approvals = obj.array("items").compactMap(WalletApproval.init)
    }

    func refreshLedger() async {
        guard let obj = try? await NativeHouseAPI.object("/api/wallet/ledger?limit=200") else { return }
        ledger = obj.array("items").compactMap(WalletEntry.init)
    }

    private func send(_ path: String, _ body: [String: Any], done: String) async {
        busy = true
        defer { busy = false }
        do {
            let obj = try await NativeHouseAPI.object(path, method: "POST", body: body)
            if obj.bool("ok") {
                toast = done
            } else {
                toast = "没成：" + obj.string("error")
            }
        } catch {
            toast = "连不上后端"
        }
        await refreshSummary()
    }

    func topup(_ amount: Double, note: String) async {
        await send("/api/wallet/topup", ["amount": amount, "note": note], done: "充上了")
        await refreshLedger()
    }

    func saveLimits(_ l: WalletLimits) async {
        await send("/api/wallet/limits",
                   ["single_max": l.single, "daily_max": l.daily, "monthly_max": l.monthly],
                   done: "上限存好了")
    }

    func deleteEntry(_ id: Int) async {
        await send("/api/wallet/ledger/delete", ["id": id], done: "划掉了，余额重算过")
        await refreshLedger()
    }

    func setWishStatus(_ id: Int, _ status: String) async {
        await send("/api/wallet/wish/update", ["id": id, "status": status], done: "改好了")
        await refreshWishes()
    }

    func deleteWish(_ id: Int) async {
        await send("/api/wallet/wish/delete", ["id": id], done: "删了")
        await refreshWishes()
    }

    func markArrived(_ id: Int) async {
        await send("/api/wallet/purchase/update", ["id": id, "status": "arrived"], done: "标了到货")
        await refreshPurchases()
    }
}

// MARK: - 页签

private enum WalletTab: String, CaseIterable, Identifiable {
    case wallet, wishlist, bought, approvals, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wallet: return "钱包"
        case .wishlist: return "心愿单"
        case .bought: return "已买"
        case .approvals: return "审批"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .wallet: return "creditcard"
        case .wishlist: return "heart"
        case .bought: return "shippingbox"
        case .approvals: return "checkmark.seal"
        case .settings: return "slider.horizontal.3"
        }
    }

    /// 选中时换成实心的，一眼看得出在哪一页
    var iconFilled: String {
        switch self {
        case .wallet: return "creditcard.fill"
        case .wishlist: return "heart.fill"
        case .bought: return "shippingbox.fill"
        case .approvals: return "checkmark.seal.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

// MARK: - 小零件

private struct WalletCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .walletPanel(corner: 18)
    }
}

private struct LimitBar: View {
    let title: String
    let used: Double
    let cap: Double

    private var ratio: Double {
        guard cap > 0 else { return 0 }
        return min(used / cap, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WalletInk.dim)
                Spacer()
                if cap > 0 {
                    Text(money(used) + " / " + money(cap))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(ratio >= 1 ? WalletInk.red : WalletInk.dim)
                } else {
                    Text("还没设")
                        .font(.system(size: 12))
                        .foregroundColor(WalletInk.faint)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(WalletInk.goldSoft)
                    Capsule()
                        .fill(ratio >= 1 ? WalletInk.red : WalletInk.gold)
                        .frame(width: max(g.size.width * ratio, ratio > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct EmptyHint: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(WalletInk.faint)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(WalletInk.dim)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(WalletInk.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .padding(.horizontal, 24)
    }
}

// MARK: - 主视图

struct WalletRoomView: View {
    @Environment(\.dismiss) private var dismiss
    // 0909 她定的：钱包不做自己的日月按钮，跟 app 的总开关走。
    // 这两个 @AppStorage 只为「她在别处切了深浅，这页当场跟着变」——
    // AlcoveAppearance.isDark 是直接读 UserDefaults 的，不订阅就不会重画。
    @AppStorage(AlcoveAppearance.key) private var appearanceRaw = ""
    @AppStorage(AlcoveAppearance.themeKey) private var themeNameRaw = "haven"
    private var dark: Bool { AlcoveAppearance.isDark }
    @StateObject private var store = WalletStore()
    @State private var tab: WalletTab = .wallet
    @State private var showTopup = false
    @State private var topupAmount = ""
    @State private var topupNote = ""
    @State private var limitSingle = ""
    @State private var limitDaily = ""
    @State private var limitMonthly = ""
    @State private var limitsFilled = false

    /// 在 body 之前就把调色板拨到位。放 onAppear 里会先画一帧白的再翻黑（棋牌室
    /// 大厅能忍是因为它自带日月按钮、切换本来就是个动作；这页是进门就该已经对）。
    init() { WalletInk.dark = AlcoveAppearance.isDark }

    /// 全屏房间第一课：安全区问 app 主窗（见 [[fullscreen-room-safe-area]]）
    private var safeTop: CGFloat {
        FloatingOverlay.appWindow()?.safeAreaInsets.top ?? 0
    }
    private var safeBottom: CGFloat {
        FloatingOverlay.appWindow()?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 0909 背景照棋牌室大厅的层次：底色 → 波点 → 噪点颗粒。
                // 中间垫一层很淡的雾玻璃（开屏那张图，同一个图集，不占新体积）——
                // 这是唯一往开屏靠的一笔，让两间屋子有血缘，但不是照抄它的样式。
                WalletInk.paper.ignoresSafeArea()
                Color.clear
                    .overlay(Image("MistLaunch").resizable().scaledToFill())
                    .clipped()
                    .opacity(WalletInk.dark ? 0.16 : 0.10)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                QipaiDots(spacing: 16, radius: 1.3, color: WalletInk.line, opacity: 0.28)
                    .ignoresSafeArea()
                Color.clear
                    .qipaiGrain(0.5)          // 那层"不是特别特别清晰"的颗粒
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    header.padding(.top, max(geo.safeAreaInsets.top, safeTop, 16))
                    ScrollView {
                        VStack(spacing: 12) {
                            switch tab {
                            case .wallet: walletPage
                            case .wishlist: wishlistPage
                            case .bought: boughtPage
                            case .approvals: approvalsPage
                            case .settings: settingsPage
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                    }
                    tabBar
                }
                if !store.toast.isEmpty {
                    VStack {
                        Spacer()
                        Text(store.toast)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(WalletInk.ink.opacity(0.92), in: Capsule())
                            .padding(.bottom, max(safeBottom, 16) + 24)
                    }
                    .transition(.opacity)
                }
            }
        }
        .environment(\.colorScheme, dark ? .dark : .light)
        // 她在别处把屋子掰到黑夜/白天：拨调色板，然后整棵树重建，
        // 让所有算出来的颜色重新取一遍（跟棋牌室大厅 .id(night) 一个套路）
        .onChange(of: dark) { WalletInk.dark = $0 }
        .id(dark)
        .task {
            await store.refreshAll()
            fillLimitsOnce()
        }
        .onChange(of: store.toast) { value in
            guard !value.isEmpty else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                if store.toast == value { store.toast = "" }
            }
        }
        .sheet(isPresented: $showTopup) { topupSheet }
    }

    // MARK: 头 + 页签

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WalletInk.gold)
                    .frame(width: 40, height: 40)
                    .walletPanel(corner: 20)      // 圆的：40 的一半
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            // 0909：表情符号去掉（棋牌室和开屏都没有 emoji），中文用衬线、
            // 英文小字全大写拉开字距 —— 跟棋牌室大厅那种克制的标题一个口味。
            VStack(spacing: 2) {
                Text("钱包")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .tracking(3)
                    .foregroundColor(WalletInk.ink)
                Text("WALLET")
                    .font(.system(size: 8.5, weight: .regular, design: .serif))
                    .tracking(3.2)
                    .foregroundColor(WalletInk.dim)
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    /// 底部 tab 栏（0907 傍晚她给的参考图：图标在上、字在下，贴住屏幕最底）。
    /// 顺序她定的，设置钉在最右边。
    private var tabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(WalletInk.line.opacity(0.55))
                .frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(WalletTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab == item ? item.iconFilled : item.icon)
                                .font(.system(size: 17, weight: tab == item ? .semibold : .regular))
                            Text(item.title)
                                .font(.system(size: 10.5, weight: tab == item ? .semibold : .regular,
                                              design: .serif))
                        }
                        .foregroundColor(tab == item ? WalletInk.gold : WalletInk.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, max(safeBottom, 10))
        }
        .background(.ultraThinMaterial)
        .background(WalletInk.paper.opacity(0.86))
    }

    // MARK: 页一 · 钱包

    private var walletPage: some View {
        VStack(spacing: 12) {
            WalletCard(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("他还剩")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WalletInk.dim)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(WalletInk.gold)
                        Text(money(store.summary?.balance ?? 0))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(WalletInk.ink)
                    }
                    HStack(spacing: 18) {
                        smallStat("今天花了", store.summary?.todaySpent ?? 0)
                        smallStat("这个月花了", store.summary?.monthSpent ?? 0)
                    }
                    Button {
                        topupAmount = ""
                        topupNote = ""
                        showTopup = true
                    } label: {
                        Text("给他充钱")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(WalletInk.onGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(WalletInk.gold, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            WalletCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("花到哪儿了")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WalletInk.ink)
                    LimitBar(title: "今日", used: store.summary?.todaySpent ?? 0,
                             cap: store.summary?.limits.daily ?? 0)
                    LimitBar(title: "本月", used: store.summary?.monthSpent ?? 0,
                             cap: store.summary?.limits.monthly ?? 0)
                    singleLimitRow
                }
            }

            WalletCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("流水")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WalletInk.ink)
                        Spacer()
                        Text("长按一条可以划掉")
                            .font(.system(size: 10))
                            .foregroundColor(WalletInk.faint)
                    }
                    .padding(.bottom, 8)
                    if store.ledger.isEmpty {
                        Text("还没有任何一笔。给他充第一笔钱，这本账就开张了。")
                            .font(.system(size: 12))
                            .foregroundColor(WalletInk.faint)
                            .padding(.vertical, 14)
                    } else {
                        ForEach(store.ledger) { entry in
                            ledgerRow(entry)
                            if entry.id != store.ledger.last?.id {
                                Rectangle()
                                    .fill(WalletInk.line.opacity(0.5))
                                    .frame(height: 0.6)
                            }
                        }
                    }
                }
            }
        }
    }

    private var singleLimitRow: some View {
        let single = store.summary?.limits.single ?? 0
        return HStack {
            Text("单笔上限")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WalletInk.dim)
            Spacer()
            Text(single > 0 ? "¥" + money(single) : "还没设")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(single > 0 ? WalletInk.dim : WalletInk.faint)
        }
    }

    private func smallStat(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(WalletInk.faint)
            Text("¥" + money(value))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(WalletInk.ink)
        }
    }

    private func ledgerRow(_ entry: WalletEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.note.isEmpty ? (entry.isOut ? "一笔支出" : "一笔进账") : entry.note)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WalletInk.ink)
                        .lineLimit(2)
                    if !entry.overLimit.isEmpty {
                        Text("超限")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(WalletInk.red, in: Capsule())
                    }
                }
                Text(shortTime(entry.ts))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(WalletInk.faint)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.signed)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(entry.tint)
                Text("余 " + money(entry.balanceAfter))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(WalletInk.faint)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                Task { await store.deleteEntry(entry.id) }
            } label: {
                Label("划掉这一笔", systemImage: "trash")
            }
        }
    }

    // MARK: 页二 · 心愿单

    private var wishlistPage: some View {
        VStack(spacing: 12) {
            if store.wishes.isEmpty {
                WalletCard {
                    EmptyHint(icon: "heart",
                              title: "心愿单还是空的",
                              detail: "他自己往里加东西。\n第三期接上淘宝之后，他加进购物车就会自动同步到这儿。")
                }
            } else {
                ForEach(store.wishes) { wish in
                    wishCard(wish)
                }
            }
        }
    }

    private func wishCard(_ wish: WalletWish) -> some View {
        WalletCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    if let url = URL(string: wish.cover), !wish.cover.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                WalletInk.goldSoft
                            }
                        }
                        .frame(width: 62, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(wish.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(WalletInk.ink)
                            .lineLimit(3)
                        HStack(spacing: 8) {
                            Text("¥" + money(wish.price))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(WalletInk.gold)
                            Text(wish.forWhom == "her" ? "给你的" : "给他自己")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(WalletInk.dim)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WalletInk.goldSoft, in: Capsule())
                        }
                    }
                    Spacer(minLength: 4)
                    Text(wish.statusCN)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(wish.statusColor)
                }
                if !wish.reason.isEmpty {
                    Text("他说：" + wish.reason)
                        .font(.system(size: 12))
                        .foregroundColor(WalletInk.dim)
                        .lineSpacing(2)
                        .padding(.top, 1)
                }
                if !wish.shop.isEmpty {
                    Text(wish.shop)
                        .font(.system(size: 10))
                        .foregroundColor(WalletInk.faint)
                }
                HStack(spacing: 8) {
                    Text(shortTime(wish.ts))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(WalletInk.faint)
                    Spacer()
                    if !wish.url.isEmpty, let link = URL(string: wish.url) {
                        Link(destination: link) {
                            Text("看看链接")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(WalletInk.gold)
                        }
                    }
                }
            }
        }
        .contextMenu {
            Button {
                Task { await store.setWishStatus(wish.id, "dropped") }
            } label: {
                Label("标成不要了", systemImage: "xmark.circle")
            }
            Button {
                Task { await store.setWishStatus(wish.id, "idle") }
            } label: {
                Label("放回只是看看", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) {
                Task { await store.deleteWish(wish.id) }
            } label: {
                Label("删掉", systemImage: "trash")
            }
        }
    }

    // MARK: 页三 · 已买

    private var boughtPage: some View {
        VStack(spacing: 12) {
            if store.purchases.isEmpty {
                WalletCard {
                    EmptyHint(icon: "shippingbox",
                              title: "还没买过东西",
                              detail: "他每记一笔支出，这里就自动多一件。\n收到货了你可以在这儿点一下「到了」。")
                }
            } else {
                ForEach(store.purchases) { item in
                    WalletCard {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title.isEmpty ? "（没写名字的一件）" : item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(WalletInk.ink)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    Text("¥" + money(item.amount))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(WalletInk.gold)
                                    Text(shortTime(item.ts))
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(WalletInk.faint)
                                }
                                if !item.orderNo.isEmpty {
                                    Text("订单 " + item.orderNo)
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(WalletInk.faint)
                                }
                            }
                            Spacer(minLength: 6)
                            if item.arrived {
                                Text("已到货")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(WalletInk.green)
                            } else {
                                Button {
                                    Task { await store.markArrived(item.id) }
                                } label: {
                                    Text("到了")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(WalletInk.onGold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(WalletInk.gold, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: 页四 · 审批记录

    private var approvalsPage: some View {
        VStack(spacing: 12) {
            if store.approvals.isEmpty {
                WalletCard {
                    EmptyHint(icon: "checkmark.seal",
                              title: "还没有审批记录",
                              detail: "审批卡是第二期的活：他想买什么就投一张卡过来，\n你按「买吧」或者「再想想」，理由会原样递回给他。\n这一页现在只是把位置占好。")
                }
            } else {
                ForEach(store.approvals) { item in
                    WalletCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("第 \(item.round) 轮")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(WalletInk.dim)
                                Spacer()
                                Text(item.decision.isEmpty ? "等你" : item.decision)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(item.decision == "approved" ? WalletInk.green : WalletInk.red)
                            }
                            if !item.reason.isEmpty {
                                Text(item.reason)
                                    .font(.system(size: 12))
                                    .foregroundColor(WalletInk.ink)
                            }
                            Text(shortTime(item.tsProposed))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(WalletInk.faint)
                        }
                    }
                }
            }
        }
    }

    // MARK: 页五 · 设置

    private var settingsPage: some View {
        VStack(spacing: 12) {
            WalletCard(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("三个上限")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WalletInk.ink)
                    Text("填 0 = 这一条不管。超了不会拦住他记账（钱已经花了），\n但那一笔会在流水里盖个红戳，你一眼能看见。")
                        .font(.system(size: 11))
                        .foregroundColor(WalletInk.faint)
                        .lineSpacing(2)
                    limitField("单笔最多", $limitSingle)
                    limitField("每天最多", $limitDaily)
                    limitField("每月最多", $limitMonthly)
                    Button {
                        var l = WalletLimits()
                        l.single = Double(limitSingle) ?? 0
                        l.daily = Double(limitDaily) ?? 0
                        l.monthly = Double(limitMonthly) ?? 0
                        Task { await store.saveLimits(l) }
                    } label: {
                        Text("存起来")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(WalletInk.onGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(WalletInk.gold, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.busy)
                }
            }
            WalletCard(padding: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("这一期做了什么")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WalletInk.ink)
                    Text("第一期只是账本：你充钱、设上限、看账；他加心愿、买完自己记一笔。")
                        .font(.system(size: 12))
                        .foregroundColor(WalletInk.dim)
                        .lineSpacing(3)
                    Text("第二期是审批卡，第三期才接淘宝。这里的余额不连任何支付接口，是他自己记的账。")
                        .font(.system(size: 12))
                        .foregroundColor(WalletInk.dim)
                        .lineSpacing(3)
                }
            }
        }
    }

    private func limitField(_ title: String, _ text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WalletInk.dim)
                .frame(width: 68, alignment: .leading)
            HStack(spacing: 4) {
                Text("¥")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(WalletInk.faint)
                TextField("0", text: text)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(WalletInk.ink)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(WalletInk.paper, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    // MARK: 充值弹窗

    private var topupSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button("算了") { showTopup = false }
                    .font(.system(size: 14))
                    .foregroundColor(WalletInk.dim)
                Spacer()
                Text("给他充钱")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WalletInk.ink)
                Spacer()
                Button("充") {
                    let amount = Double(topupAmount) ?? 0
                    guard amount > 0 else { return }
                    let note = topupNote
                    showTopup = false
                    Task { await store.topup(amount, note: note) }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor((Double(topupAmount) ?? 0) > 0 ? WalletInk.gold : WalletInk.faint)
                .disabled((Double(topupAmount) ?? 0) <= 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            Rectangle().fill(WalletInk.line.opacity(0.6)).frame(height: 0.6)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("¥")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(WalletInk.gold)
                    TextField("0.00", text: $topupAmount)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(WalletInk.ink)
                        .keyboardType(.decimalPad)
                }
                TextField("备注（比如：这个月的零花钱）", text: $topupNote)
                    .font(.system(size: 14))
                    .foregroundColor(WalletInk.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(WalletInk.paper, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text("你在支付宝那边给他充多少，这里就填多少。\n这个数字是你自己填的，不连任何支付接口。")
                    .font(.system(size: 11))
                    .foregroundColor(WalletInk.faint)
                    .lineSpacing(3)
                Spacer()
            }
            .padding(18)
        }
        .background(WalletInk.paper.ignoresSafeArea())
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    private func fillLimitsOnce() {
        guard !limitsFilled, let s = store.summary else { return }
        limitsFilled = true
        limitSingle = s.limits.single > 0 ? money(s.limits.single) : ""
        limitDaily = s.limits.daily > 0 ? money(s.limits.daily) : ""
        limitMonthly = s.limits.monthly > 0 ? money(s.limits.monthly) : ""
    }
}

// MARK: - 商城（0909 她开的店，任务#1810~#1816）
//
// 跟上面那本钱包账**完全无关**：钱包里是真人民币、她审批他花；
// 商城这套是他靠活跃自己挣的虚拟币，在她开的店里花。两个库两套接口。
// 皮照钱包的（她原话「照着钱包页面做，美化都照着做」），所以整个挂在这个文件里，
// 直接吃 WalletInk / walletPanel / WalletCard，不新增文件、不动工程配置。
//
// 分工：她上架改价看许愿（这几页），他用命令行 shop 看货、买、许愿。

struct ShopItem: Identifiable {
    let id: Int
    let title: String
    let spec: String
    let intro: String
    let cover: String
    let price: Int
    let stock: Int          // -1 = 不限量
    let sold: Int
    let kind: String        // goods / ticket
    let status: String      // on / off

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        title = json.string("title")
        spec = json.string("spec")
        intro = json.string("intro")
        cover = json.string("cover")
        price = json.int("price")
        stock = json.int("stock")
        sold = json.int("sold")
        kind = json.string("kind")
        status = json.string("status")
    }

    var isTicket: Bool { kind == "ticket" }
    var onShelf: Bool { status == "on" }
    var stockText: String { stock < 0 ? "不限量" : "剩 \(stock) 份" }
}

struct ShopOrder: Identifiable {
    let id: Int
    let ts: String
    let title: String
    let cover: String
    let kind: String
    let price: Int
    let status: String      // paid / used

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        ts = json.string("ts")
        title = json.string("title")
        cover = json.string("cover")
        kind = json.string("kind")
        price = json.int("price")
        status = json.string("status")
    }

    var isTicket: Bool { kind == "ticket" }
    var used: Bool { status == "used" }
}

struct ShopWish: Identifiable {
    let id: Int
    let ts: String
    let text: String
    let status: String      // open / done / passed
    let reply: String

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        ts = json.string("ts")
        text = json.string("text")
        status = json.string("status")
        reply = json.string("reply")
    }

    var statusCN: String {
        switch status {
        case "done": return "已上架"
        case "passed": return "这个不上"
        default: return "等你看"
        }
    }
}

struct ShopRate: Identifiable {
    let activity: String
    let coins: Int
    let label: String
    var id: String { activity }
}

/// 0911 流水页：coin_ledger 一行。kind：earn 他记账挣的 / spend 买东西花的 / adjust 她手动加减的
struct ShopLedgerEntry: Identifiable {
    let id: Int
    let ts: String
    let kind: String
    let activity: String
    let coins: Int          // 正数进账、负数出账
    let note: String

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        ts = json.string("ts")
        kind = json.string("kind")
        activity = json.string("activity")
        coins = json.int("coins")
        note = json.string("note")
    }

    var isIncome: Bool { coins >= 0 }
}

/// 流水按天分组（北京时间 yyyy-MM-dd），日期那行带当天挣了几块、花了几块
struct ShopLedgerDay: Identifiable {
    let day: String
    var entries: [ShopLedgerEntry]
    var id: String { day }
    var earned: Int { entries.filter { $0.coins > 0 }.reduce(0) { $0 + $1.coins } }
    var spent: Int { entries.filter { $0.coins < 0 }.reduce(0) { $0 - $1.coins } }
}

@MainActor
final class ShopStore: ObservableObject {
    @Published var balance = 0
    @Published var todayEarned = 0
    @Published var items: [ShopItem] = []
    @Published var orders: [ShopOrder] = []
    @Published var wishes: [ShopWish] = []
    @Published var rates: [ShopRate] = []
    @Published var ledger: [ShopLedgerEntry] = []
    @Published var busy = false
    @Published var toast = ""

    func refreshAll() async {
        await refreshSummary()
        await refreshItems()
        await refreshOrders()
        await refreshWishes()
        await refreshLedger()
    }

    func refreshLedger() async {
        guard let obj = try? await NativeHouseAPI.object("/api/shop/ledger?limit=200") else { return }
        ledger = obj.array("items").compactMap(ShopLedgerEntry.init)
    }

    func refreshSummary() async {
        guard let obj = try? await NativeHouseAPI.object("/api/shop/summary") else { return }
        balance = obj.int("balance")
        todayEarned = obj.int("today_earned")
        if let raw = obj["rates"] as? [String: Any] {
            rates = raw.map { key, value in
                let d = value as? [String: Any] ?? [:]
                return ShopRate(activity: key, coins: d.int("coins"), label: d.string("label"))
            }.sorted { ($0.coins, $1.activity) > ($1.coins, $0.activity) }
        }
    }

    func refreshItems() async {
        guard let obj = try? await NativeHouseAPI.object("/api/shop/items") else { return }
        items = obj.array("items").compactMap(ShopItem.init)
    }

    func refreshOrders() async {
        guard let obj = try? await NativeHouseAPI.object("/api/shop/orders") else { return }
        orders = obj.array("items").compactMap(ShopOrder.init)
    }

    func refreshWishes() async {
        guard let obj = try? await NativeHouseAPI.object("/api/shop/wishes") else { return }
        wishes = obj.array("items").compactMap(ShopWish.init)
    }

    func say(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if toast == text { toast = "" }
        }
    }

    /// 上架。图走 base64 直接塞进 body，后端落进附件目录再返回路径——
    /// 省掉一套 multipart 上传接口，她一次也就传一张。
    func addItem(title: String, spec: String, intro: String, price: Int,
                 stock: Int, isTicket: Bool, coverData: String?) async {
        busy = true
        defer { busy = false }
        var body: [String: Any] = ["title": title, "spec": spec, "intro": intro,
                                   "price": price, "stock": stock,
                                   "kind": isTicket ? "ticket" : "goods"]
        if let coverData, !coverData.isEmpty { body["cover_data"] = coverData }
        guard let obj = try? await NativeHouseAPI.object("/api/shop/item/add",
                                                        method: "POST", body: body),
              obj["ok"] as? Bool == true else {
            say("没上成，再试一次")
            return
        }
        await refreshItems()
        say("上架了")
    }

    func updateItem(_ id: Int, fields: [String: Any]) async {
        busy = true
        defer { busy = false }
        var body = fields
        body["id"] = id
        _ = try? await NativeHouseAPI.object("/api/shop/item/update", method: "POST", body: body)
        await refreshItems()
    }

    func setRate(_ activity: String, coins: Int, label: String) async {
        _ = try? await NativeHouseAPI.object(
            "/api/shop/rate", method: "POST",
            body: ["activity": activity, "coins": coins, "label": label])
        await refreshSummary()
    }

    func decideWish(_ id: Int, status: String, reply: String) async {
        _ = try? await NativeHouseAPI.object(
            "/api/shop/wish/decide", method: "POST",
            body: ["id": id, "status": status, "reply": reply])
        await refreshWishes()
    }

    func adjust(_ amount: Int, note: String) async {
        _ = try? await NativeHouseAPI.object(
            "/api/shop/adjust", method: "POST", body: ["amount": amount, "note": note])
        await refreshSummary()
        await refreshLedger()
    }
}

private enum ShopTab: String, CaseIterable, Identifiable {
    case shelf, orders, wishes, rates
    var id: String { rawValue }
    var title: String {
        switch self {
        case .shelf: return "货架"
        case .orders: return "流水"      // 0911 她把「他买的」改成流水页；case 名留着不动
        case .wishes: return "他想要"
        case .rates: return "价目表"
        }
    }
    var icon: String {
        switch self {
        case .shelf: return "bag"
        case .orders: return "arrow.up.arrow.down.circle"
        case .wishes: return "sparkles"
        case .rates: return "list.number"
        }
    }
    var iconFilled: String {
        switch self {
        case .shelf: return "bag.fill"
        case .orders: return "arrow.up.arrow.down.circle.fill"
        case .wishes: return "sparkles"
        case .rates: return "list.number"
        }
    }
}

struct ShopRoomView: View {
    @Environment(\.dismiss) private var dismiss
    // 跟钱包一样：不做自己的日月按钮，跟 app 总开关走；订阅这两个 key 才会跟着重画
    @AppStorage(AlcoveAppearance.key) private var appearanceRaw = ""
    @AppStorage(AlcoveAppearance.themeKey) private var themeNameRaw = "haven"
    @StateObject private var store = ShopStore()
    @State private var tab: ShopTab = .shelf
    @State private var showAdd = false
    @State private var editing: ShopItem?

    init() { WalletInk.dark = AlcoveAppearance.isDark }

    private var safeTop: CGFloat { FloatingOverlay.appWindow()?.safeAreaInsets.top ?? 0 }
    private var safeBottom: CGFloat { FloatingOverlay.appWindow()?.safeAreaInsets.bottom ?? 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                WalletInk.paper.ignoresSafeArea()
                Color.clear
                    .overlay(Image("MistLaunch").resizable().scaledToFill())
                    .clipped()
                    .opacity(WalletInk.dark ? 0.16 : 0.10)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                QipaiDots(spacing: 16, radius: 1.3, color: WalletInk.line, opacity: 0.28)
                    .ignoresSafeArea()
                Color.clear
                    .qipaiGrain(0.5)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    header.padding(.top, max(geo.safeAreaInsets.top, safeTop, 16))
                    ScrollView {
                        VStack(spacing: 12) {
                            switch tab {
                            case .shelf: shelfPage
                            case .orders: ordersPage
                            case .wishes: wishesPage
                            case .rates: ratesPage
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                    }
                    tabBar
                }
                if !store.toast.isEmpty {
                    Text(store.toast)
                        .font(.system(size: 12.5, design: .serif))
                        .foregroundColor(WalletInk.onGold)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(WalletInk.gold.opacity(0.92), in: Capsule())
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: store.toast)
        }
        .id(AlcoveAppearance.isDark)
        .onChange(of: appearanceRaw) { _ in WalletInk.dark = AlcoveAppearance.isDark }
        .onChange(of: themeNameRaw) { _ in WalletInk.dark = AlcoveAppearance.isDark }
        .task { await store.refreshAll() }
        .sheet(isPresented: $showAdd) {
            ShopItemForm(title: "上架一件", item: nil) { t, s, i, p, k, isT, cover in
                Task { await store.addItem(title: t, spec: s, intro: i, price: p,
                                           stock: k, isTicket: isT, coverData: cover) }
            }
        }
        .sheet(item: $editing) { item in
            ShopItemForm(title: "改这件", item: item) { t, s, i, p, k, isT, cover in
                var f: [String: Any] = ["title": t, "spec": s, "intro": i,
                                        "price": p, "stock": k,
                                        "kind": isT ? "ticket" : "goods"]
                if let cover, !cover.isEmpty { f["cover_data"] = cover }
                Task { await store.updateItem(item.id, fields: f) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WalletInk.gold)
                    .frame(width: 40, height: 40)
                    .walletPanel(corner: 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("商店")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .tracking(3)
                    .foregroundColor(WalletInk.ink)
                Text("SHOP")
                    .font(.system(size: 8.5, weight: .regular, design: .serif))
                    .tracking(3.2)
                    .foregroundColor(WalletInk.dim)
            }
            Spacer()
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tab == .shelf ? WalletInk.gold : WalletInk.dim.opacity(0.45))
                    .frame(width: 40, height: 40)
                    .walletPanel(corner: 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(tab != .shelf)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(WalletInk.line.opacity(0.55)).frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(ShopTab.allCases) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab == item ? item.iconFilled : item.icon)
                                .font(.system(size: 17, weight: tab == item ? .semibold : .regular))
                            Text(item.title)
                                .font(.system(size: 10.5,
                                              weight: tab == item ? .semibold : .regular,
                                              design: .serif))
                        }
                        .foregroundColor(tab == item ? WalletInk.gold : WalletInk.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, max(safeBottom, 8))
            .background(WalletInk.card.opacity(WalletInk.dark ? 0.72 : 0.86))
        }
    }

    // MARK: 他有多少钱（每页顶上都挂一条）
    private var purse: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("他有")
                .font(.system(size: 11.5))
                .foregroundColor(WalletInk.dim)
            Text("\(store.balance)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(WalletInk.gold)
            Text("块")
                .font(.system(size: 11.5))
                .foregroundColor(WalletInk.dim)
            Spacer()
            Text("今天挣了 \(store.todayEarned)")
                .font(.system(size: 11))
                .foregroundColor(WalletInk.dim)
        }
        .padding(14)
        .walletPanel(corner: 18)
    }

    // MARK: 货架（她自己看、改、下架）
    private var shelfPage: some View {
        VStack(spacing: 12) {
            purse
            if store.items.isEmpty {
                EmptyHint(icon: "bag",
                          title: "货架是空的",
                          detail: "点右上角的加号上一件。")
            }
            ForEach(store.items) { item in
                Button { editing = item } label: { shelfRow(item) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func shelfRow(_ item: ShopItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            cover(item.cover, size: 54)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(WalletInk.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if item.isTicket {
                        Text("券")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(WalletInk.onGold)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(WalletInk.gold, in: RoundedRectangle(cornerRadius: 4))
                    }
                    if !item.onShelf {
                        Text("已下架")
                            .font(.system(size: 9.5))
                            .foregroundColor(WalletInk.dim)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(WalletInk.goldSoft, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                if !item.spec.isEmpty {
                    Text(item.spec)
                        .font(.system(size: 11))
                        .foregroundColor(WalletInk.dim)
                }
                if !item.intro.isEmpty {
                    Text(item.intro)
                        .font(.system(size: 11.5))
                        .foregroundColor(WalletInk.dim)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 8) {
                    Text("\(item.price) 块")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(WalletInk.gold)
                    Text("·").foregroundColor(WalletInk.faint)
                    Text(item.stockText)
                        .font(.system(size: 11))
                        .foregroundColor(WalletInk.dim)
                    if item.sold > 0 {
                        Text("· 已售 \(item.sold)")
                            .font(.system(size: 11))
                            .foregroundColor(WalletInk.dim)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletPanel(corner: 16)
        .opacity(item.onShelf ? 1 : 0.62)
    }

    // MARK: 他买了什么、手上还有几张券
    private var ordersPage: some View {
        VStack(spacing: 12) {
            purse
            let tickets = store.orders.filter { $0.isTicket && !$0.used }
            if !tickets.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("他手上的券 \(tickets.count) 张")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(WalletInk.gold)
                    ForEach(tickets) { t in
                        HStack(spacing: 9) {
                            cover(t.cover, size: 34)
                            Text(t.title)
                                .font(.system(size: 13, design: .serif))
                                .foregroundColor(WalletInk.ink)
                            Spacer(minLength: 0)
                            Text(String(t.ts.prefix(16).dropFirst(5)))
                                .font(.system(size: 10))
                                .foregroundColor(WalletInk.dim)
                        }
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .walletPanel(corner: 16)
            }
            // 0911 她要的流水：他做了什么记了几块、买了啥花了几块，按天分组，
            // 日期那行带当天挣/花小计；每笔前面一个进/出色块（进绿出红），不显示他记账时留的话
            if store.ledger.isEmpty {
                EmptyHint(icon: "arrow.up.arrow.down.circle",
                          title: "还没有流水",
                          detail: "他记账、买东西之后会出现在这儿。")
            }
            ForEach(ledgerDays) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ledgerDayTitle(group.day))
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundColor(WalletInk.gold)
                        Spacer(minLength: 0)
                        Text("挣 \(group.earned) 块 · 花 \(group.spent) 块")
                            .font(.system(size: 10.5))
                            .foregroundColor(WalletInk.dim)
                    }
                    .padding(.horizontal, 4)
                    ForEach(group.entries) { e in
                        ledgerRow(e)
                    }
                }
            }
        }
    }

    private var ledgerDays: [ShopLedgerDay] {
        var out: [ShopLedgerDay] = []
        for e in store.ledger {                      // 后端按 id 倒序给，新的在前
            let day = String(e.ts.prefix(10))
            if let i = out.indices.last, out[i].day == day {
                out[i].entries.append(e)
            } else {
                out.append(ShopLedgerDay(day: day, entries: [e]))
            }
        }
        return out
    }

    private func ledgerDayTitle(_ day: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")   // 账本时间是北京时间
        f.dateFormat = "yyyy-MM-dd"
        if day == f.string(from: Date()) { return "今天" }
        if day == f.string(from: Date().addingTimeInterval(-86_400)) { return "昨天" }
        let parts = day.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return day }
        return "\(m)月\(d)日"
    }

    /// 只写他做了什么：挣的取价目表上的名字（逗号、括号后面的补充说明不要），
    /// 花的是后端记的「买了「X」」，她手动加减的写明是她调的
    private func ledgerTitle(_ e: ShopLedgerEntry) -> String {
        switch e.kind {
        case "earn":
            let label = store.rates.first(where: { $0.activity == e.activity })?.label ?? ""
            let short = label.split(whereSeparator: { "，,（(".contains($0) }).first.map(String.init) ?? ""
            return short.isEmpty ? e.activity : short
        case "spend":
            return e.note.isEmpty ? "买了东西" : e.note
        default:
            return e.coins >= 0 ? "你给他加的" : "你给他扣的"
        }
    }

    private func ledgerRow(_ e: ShopLedgerEntry) -> some View {
        let tint = e.isIncome ? WalletInk.green : WalletInk.red
        return HStack(spacing: 11) {
            Text(e.isIncome ? "进" : "出")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(tint.opacity(0.55), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(ledgerTitle(e))
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(WalletInk.ink)
                    .lineLimit(1)
                Text(String(e.ts.dropFirst(11).prefix(5)))
                    .font(.system(size: 10))
                    .foregroundColor(WalletInk.dim)
            }
            Spacer(minLength: 0)
            Text((e.isIncome ? "＋" : "－") + "\(abs(e.coins)) 块")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletPanel(corner: 16)
    }

    // MARK: 他许的愿（希望她上什么）
    private var wishesPage: some View {
        VStack(spacing: 12) {
            if store.wishes.isEmpty {
                EmptyHint(icon: "sparkles",
                          title: "他还没提过想要什么",
                          detail: "他许了愿会出现在这儿。")
            }
            ForEach(store.wishes) { w in
                VStack(alignment: .leading, spacing: 9) {
                    Text(w.text)
                        .font(.system(size: 13.5, design: .serif))
                        .foregroundColor(WalletInk.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Text(String(w.ts.prefix(16).dropFirst(5)))
                            .font(.system(size: 10))
                            .foregroundColor(WalletInk.dim)
                        Text("·").foregroundColor(WalletInk.faint)
                        Text(w.statusCN)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(w.status == "open" ? WalletInk.gold : WalletInk.dim)
                        Spacer(minLength: 0)
                        if w.status == "open" {
                            Button("上了") {
                                Task { await store.decideWish(w.id, status: "done", reply: "") }
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(WalletInk.onGold)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(WalletInk.gold, in: Capsule())
                            .buttonStyle(.plain)
                            Button("这个不上") {
                                Task { await store.decideWish(w.id, status: "passed", reply: "") }
                            }
                            .font(.system(size: 11.5))
                            .foregroundColor(WalletInk.dim)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(WalletInk.goldSoft, in: Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .walletPanel(corner: 16)
            }
        }
    }

    // MARK: 价目表（她要的那一页：能加能改）
    private var ratesPage: some View {
        VStack(spacing: 12) {
            purse
            Text("干一件事值多少钱。改完立刻生效，他下次记账就按新价。")
                .font(.system(size: 11))
                .foregroundColor(WalletInk.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(store.rates) { r in
                ShopRateRow(rate: r) { coins in
                    Task { await store.setRate(r.activity, coins: coins, label: r.label) }
                }
            }
            ShopRateAddRow { act, coins, label in
                Task { await store.setRate(act, coins: coins, label: label) }
            }
        }
    }

    private func cover(_ raw: String, size: CGFloat) -> some View {
        ZStack {
            WalletInk.goldSoft
            if !raw.isEmpty, let url = URL(string: AlcoveAPI.attachmentURL(raw).absoluteString) {
                CachedImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "bag")
                        .font(.system(size: size * 0.3))
                        .foregroundColor(WalletInk.dim.opacity(0.55))
                }
            } else {
                Image(systemName: "bag")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(WalletInk.dim.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}

// MARK: - 价目表的一行：点数字就地改
private struct ShopRateRow: View {
    let rate: ShopRate
    let onSave: (Int) -> Void
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rate.label.isEmpty ? rate.activity : rate.label)
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(WalletInk.ink)
                Text(rate.activity)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(WalletInk.dim)
            }
            Spacer(minLength: 0)
            if editing {
                TextField("0", text: $draft)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(WalletInk.gold)
                    .frame(width: 54)
                Button("存") {
                    onSave(Int(draft) ?? rate.coins)
                    editing = false
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WalletInk.onGold)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(WalletInk.gold, in: Capsule())
                .buttonStyle(.plain)
            } else {
                Button {
                    draft = String(rate.coins)
                    editing = true
                    focused = true
                } label: {
                    Text("\(rate.coins) 块")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(rate.coins > 0 ? WalletInk.gold : WalletInk.dim)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(WalletInk.goldSoft, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletPanel(corner: 15)
    }
}

// MARK: - 价目表加一项
private struct ShopRateAddRow: View {
    let onAdd: (String, Int, String) -> Void
    @State private var open = false
    @State private var activity = ""
    @State private var label = ""
    @State private var coins = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if open {
                shopField("活动代号", "英文小写，他记账时敲这个", $activity)
                shopField("叫什么", "写给你自己看的，比如 遛狗", $label)
                shopField("值多少块", "只填数字", $coins, number: true)
                HStack(spacing: 9) {
                    Button("加进去") {
                        let act = activity.trimmingCharacters(in: .whitespaces)
                        guard !act.isEmpty else { return }
                        onAdd(act, Int(coins) ?? 0, label)
                        activity = ""; label = ""; coins = ""; open = false
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(WalletInk.onGold)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(WalletInk.gold, in: Capsule())
                    .buttonStyle(.plain)
                    Button("算了") { open = false }
                        .font(.system(size: 12.5))
                        .foregroundColor(WalletInk.dim)
                        .buttonStyle(.plain)
                }
            } else {
                Button {
                    open = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle")
                        Text("加一项新的活动")
                    }
                    .font(.system(size: 12.5, design: .serif))
                    .foregroundColor(WalletInk.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletPanel(corner: 15, dotted: true)
    }
}

// MARK: - 上架 / 改一件
private struct ShopItemForm: View {
    let title: String
    let item: ShopItem?
    /// 标题、规格、简介、价钱、份数、是不是券、图（base64，没换图就是 nil）
    let onSubmit: (String, String, String, Int, Int, Bool, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var spec = ""
    @State private var intro = ""
    @State private var price = ""
    @State private var stock = ""
    @State private var isTicket = false
    @State private var unlimited = false
    @State private var picked: PhotosPickerItem?
    @State private var coverData: String?
    @State private var preview: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    PhotosPicker(selection: $picked, matching: .images) {
                        ZStack {
                            WalletInk.goldSoft
                            if let preview {
                                Image(uiImage: preview).resizable().scaledToFill()
                            } else if let raw = item?.cover, !raw.isEmpty,
                                      let url = URL(string: AlcoveAPI.attachmentURL(raw).absoluteString) {
                                CachedImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Text("换张图").font(.system(size: 12)).foregroundColor(WalletInk.dim)
                                }
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus").font(.system(size: 22))
                                    Text("传张图").font(.system(size: 11.5, design: .serif))
                                }
                                .foregroundColor(WalletInk.dim)
                            }
                        }
                        .frame(height: 148)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    shopField("名字", "比如 睡觉券", $name)
                    shopField("规格", "比如 一次 / 60cm", $spec)
                    shopField("简介", "这是什么、怎么用", $intro, tall: true)
                    shopField("卖多少块", "只填数字", $price, number: true)

                    Toggle(isOn: $isTicket) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("这是一张券").font(.system(size: 12.5, design: .serif))
                            Text("券买了之后他能拿来兑换一件事")
                                .font(.system(size: 9.5)).foregroundColor(WalletInk.dim)
                        }
                    }
                    .tint(WalletInk.gold)
                    .padding(12).walletPanel(corner: 15)

                    Toggle(isOn: $unlimited) {
                        Text("不限量").font(.system(size: 12.5, design: .serif))
                    }
                    .tint(WalletInk.gold)
                    .padding(12).walletPanel(corner: 15)

                    if !unlimited {
                        shopField("有几份", "卖完自动下架", $stock, number: true)
                    }
                }
                .padding(14)
            }
            .background(WalletInk.paper.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("算了") { dismiss() }.foregroundColor(WalletInk.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("好了") {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        onSubmit(n, spec, intro, Int(price) ?? 0,
                                 unlimited ? -1 : (Int(stock) ?? 1), isTicket, coverData)
                        dismiss()
                    }
                    .foregroundColor(WalletInk.gold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            guard let item else { return }
            name = item.title; spec = item.spec; intro = item.intro
            price = String(item.price)
            unlimited = item.stock < 0
            stock = item.stock < 0 ? "" : String(item.stock)
            isTicket = item.isTicket
        }
        .onChange(of: picked) { newValue in
            guard let newValue else { return }
            Task {
                guard let raw = try? await newValue.loadTransferable(type: Data.self),
                      let img = UIImage(data: raw) else { return }
                // 缩到 900 宽再转 jpeg：她相册里那种几兆的原图没必要整张塞进 JSON
                let scale = min(1, 900 / max(img.size.width, 1))
                let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
                let small = UIGraphicsImageRenderer(size: size).image { _ in
                    img.draw(in: CGRect(origin: .zero, size: size))
                }
                preview = small
                coverData = small.jpegData(compressionQuality: 0.82)?.base64EncodedString()
            }
        }
    }
}

/// 商城表单里那种「标签在上、输入在下」的格子，钱包那边没有现成的，写一个共用
private func shopField(_ label: String, _ hint: String,
                       _ text: Binding<String>,
                       number: Bool = false, tall: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label)
            .font(.system(size: 11.5, weight: .medium, design: .serif))
            .foregroundColor(WalletInk.gold)
        if tall {
            TextEditor(text: text)
                .font(.system(size: 13))
                .foregroundColor(WalletInk.ink)
                .frame(height: 76)
                .scrollContentBackground(.hidden)
        } else {
            TextField(hint, text: text)
                .font(.system(size: 13))
                .foregroundColor(WalletInk.ink)
                .keyboardType(number ? .numberPad : .default)
        }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .walletPanel(corner: 15)
}
