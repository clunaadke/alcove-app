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

// MARK: - 调色（钉死的暖纸账本色，不跟日夜切换）

private enum WalletInk {
    static let paper = Color(red: 0.984, green: 0.973, blue: 0.949)
    static let card = Color(red: 1.0, green: 0.998, blue: 0.992)
    static let ink = Color(red: 0.239, green: 0.216, blue: 0.196)
    static let dim = Color(red: 0.239, green: 0.216, blue: 0.196).opacity(0.5)
    static let faint = Color(red: 0.239, green: 0.216, blue: 0.196).opacity(0.3)
    static let gold = Color(red: 0.784, green: 0.573, blue: 0.259)
    static let goldSoft = Color(red: 0.973, green: 0.925, blue: 0.831)
    static let green = Color(red: 0.302, green: 0.518, blue: 0.404)
    static let red = Color(red: 0.741, green: 0.353, blue: 0.310)
    static let line = Color(red: 0.878, green: 0.847, blue: 0.792)
    static let shadow = Color(red: 0.6, green: 0.53, blue: 0.42).opacity(0.16)
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
            .background(WalletInk.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: WalletInk.shadow, radius: 8, y: 3)
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
    @StateObject private var store = WalletStore()
    @State private var tab: WalletTab = .wallet
    @State private var showTopup = false
    @State private var topupAmount = ""
    @State private var topupNote = ""
    @State private var limitSingle = ""
    @State private var limitDaily = ""
    @State private var limitMonthly = ""
    @State private var limitsFilled = false

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
                WalletInk.paper.ignoresSafeArea()
                VStack(spacing: 0) {
                    header.padding(.top, max(geo.safeAreaInsets.top, safeTop, 16))
                    tabBar
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
                        .padding(.bottom, max(safeBottom, 16) + 20)
                    }
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
        .environment(\.colorScheme, .light)
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
                    .background(WalletInk.card, in: Circle())
                    .shadow(color: WalletInk.shadow, radius: 6, y: 2)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 0) {
                Text("👛 钱包")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(WalletInk.ink)
                Text("wallet")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .tracking(3)
                    .foregroundColor(WalletInk.dim)
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(WalletTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(tab == item ? WalletInk.ink : WalletInk.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tab == item ? WalletInk.goldSoft : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
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
                            .foregroundColor(.white)
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
                                Color(red: 0.94, green: 0.93, blue: 0.90)
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
                                        .foregroundColor(.white)
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
                            .foregroundColor(.white)
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
        .environment(\.colorScheme, .light)
    }

    private func fillLimitsOnce() {
        guard !limitsFilled, let s = store.summary else { return }
        limitsFilled = true
        limitSingle = s.limits.single > 0 ? money(s.limits.single) : ""
        limitDaily = s.limits.daily > 0 ? money(s.limits.daily) : ""
        limitMonthly = s.limits.monthly > 0 ? money(s.limits.monthly) : ""
    }
}
