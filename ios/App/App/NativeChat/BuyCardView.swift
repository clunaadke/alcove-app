import SwiftUI
import UIKit

// 审批卡（0907 二期）：他想买东西 → 投一张卡进聊天流 → 她拍板 → 理由递回给他。
//
// 她画的样子：没展开时跟他的气泡列在一堆，小小一张；点开背景模糊压暗，
// 卡片浮起来居中。里面像淘宝下单页一样列商品，**他勾中的几件铺在卡上，
// 车里其他的折在「还有 N 件」里**，她也能动那几个勾。
//
// 两个按钮：「买吧」「再想想」。再想想必须写理由——她自己定的规矩，
// 理由原样递给他，他拿着重新挑。
//
// 数据：正文里只有 id 和一句摘要，展开的内容现取 /api/wallet/approval?id=。
// 所以她拍完板，聊天里那张卡自己就变样了，不用去改已经发出去的消息。

// MARK: - 浮层（背景透明，才能把后面的聊天糊掉）

@MainActor
private enum BuyCardPresenter {
    /// 照 FloatingOverlay.present 那条路找最上面那个页面——共读室/工作室是
    /// fullScreenCover，从它们头上弹才不会把它们顶掉（0902 她抓过这个 bug）。
    /// 差别只有一处：overFullScreen + 透明底，这样才能自己铺模糊层。
    static func present<V: View>(@ViewBuilder content: () -> V) {
        guard let win = FloatingOverlay.appWindow(), var top = win.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        let host = UIHostingController(rootView: content())
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        host.view.backgroundColor = .clear
        top.present(host, animated: true)
    }

    static func dismiss() {
        guard let win = FloatingOverlay.appWindow(), var top = win.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        top.dismiss(animated: true)
    }
}

// MARK: - 数据

struct BuyItem: Identifiable {
    let id: Int
    let title: String
    let price: Double
    let cover: String
    let shop: String
    let url: String
    let reason: String
    let forWhom: String
    let picked: Bool
    let approved: Bool

    init?(json: [String: Any]) {
        let rid = json.int("id")
        guard rid > 0 else { return nil }
        id = rid
        title = json.string("title")
        price = json.double("price")
        cover = json.string("cover")
        shop = json.string("shop")
        url = json.string("url")
        reason = json.string("reason")
        forWhom = json.string("for_whom")
        picked = json.bool("picked")
        approved = json.bool("approved")
    }
}

struct BuyApprovalDetail {
    let id: Int
    let status: String          // pending / decided
    let note: String
    let decision: String        // buy / think / ""
    let reason: String
    let round: Int
    let picked: [BuyItem]
    let others: [BuyItem]
    let singleMax: Double
    let balance: Double

    init(json: [String: Any]) {
        id = json.int("id")
        status = json.string("status")
        note = json.string("note")
        decision = json.string("decision")
        reason = json.string("reason")
        round = json.int("round")
        picked = json.array("picked").compactMap(BuyItem.init)
        others = json.array("others").compactMap(BuyItem.init)
        singleMax = json.object("limits").double("single_max")
        balance = json.double("balance")
    }

    var decided: Bool { status == "decided" }
    var approvedItems: [BuyItem] { (picked + others).filter { $0.approved } }
}

@MainActor
final class BuyApprovalStore: ObservableObject {
    static let shared = BuyApprovalStore()

    @Published private(set) var details: [Int: BuyApprovalDetail] = [:]
    @Published var busy = false

    func detail(_ id: Int) -> BuyApprovalDetail? { details[id] }

    func load(_ id: Int, force: Bool = false) {
        if !force, details[id] != nil { return }
        Task { await reload(id) }
    }

    func reload(_ id: Int) async {
        guard let obj = try? await NativeHouseAPI.object("/api/wallet/approval?id=\(id)") else { return }
        guard obj.bool("ok") else { return }
        details[id] = BuyApprovalDetail(json: obj)
    }

    /// 返回 nil = 成了；返回一句话 = 没成，把话给她看
    func decide(_ id: Int, decision: String, picked: [Int], reason: String) async -> String? {
        busy = true
        defer { busy = false }
        do {
            let obj = try await NativeHouseAPI.objectIncludingHTTPError(
                "/api/wallet/decide", method: "POST",
                body: ["id": id, "decision": decision, "picked": picked, "reason": reason])
            if obj.bool("ok") {
                details[id] = BuyApprovalDetail(json: obj)
                return nil
            }
            switch obj.string("error") {
            case "reason_required": return "「再想想」得写个理由，他要拿这句话重新挑"
            case "already_decided": return "这张卡已经拍过板了"
            default: return "没成：" + obj.string("error")
            }
        } catch {
            return "连不上后端"
        }
    }
}

// MARK: - 聊天流里那张小卡

struct BuyApprovalMessageCard: View {
    let card: BuyApprovalCard
    let theme: AlcoveTheme
    @ObservedObject private var store = BuyApprovalStore.shared

    private var detail: BuyApprovalDetail? { store.detail(card.id) }

    private var stateText: String {
        guard let d = detail else { return "等你拍板" }
        if !d.decided { return "等你拍板" }
        return d.decision == "buy" ? "你说了买吧" : "你让他再想想"
    }

    private var stateColor: Color {
        guard let d = detail, d.decided else { return theme.fyAccent }
        return d.decision == "buy"
            ? Color(red: 0.302, green: 0.518, blue: 0.404)
            : theme.textDim
    }

    var body: some View {
        Button {
            BuyCardPresenter.present {
                BuyApprovalSheet(cardID: card.id, theme: theme)
            }
        } label: {
            HStack(alignment: .center, spacing: 11) {
                thumbs
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(.system(size: 13.5, weight: .medium, design: .serif))
                        .foregroundColor(theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text("¥" + String(format: "%.2f", card.amount))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(theme.fyAccent)
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textDim.opacity(0.6))
                        Text(stateText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(stateColor)
                    }
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textDim.opacity(0.55))
            }
            .padding(10)
            .frame(maxWidth: 300, alignment: .leading)
            .background(theme.fyCard.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.fyBorder.opacity(0.7), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .onAppear { store.load(card.id) }
    }

    private var headline: String {
        card.count > 1 ? "他想买 \(card.count) 件：" + card.headline : card.headline
    }

    /// 一件就一张图；多件叠两张，一眼看出是一车
    private var thumbs: some View {
        ZStack(alignment: .topLeading) {
            if card.count > 1 {
                thumb(nil)
                    .offset(x: 9, y: 6)
                    .opacity(0.55)
            }
            thumb(card.coverURL)
        }
        .frame(width: 56, height: 56, alignment: .topLeading)
    }

    private func thumb(_ raw: String?) -> some View {
        ZStack {
            Color.black.opacity(0.06)
            if let raw, !raw.isEmpty, let url = URL(string: raw) {
                CachedImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "bag")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textDim.opacity(0.5))
                }
            } else {
                Image(systemName: "bag")
                    .font(.system(size: 15))
                    .foregroundColor(theme.textDim.opacity(0.5))
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - 展开：背景糊掉压暗，卡片浮起来居中

struct BuyApprovalSheet: View {
    let cardID: Int
    let theme: AlcoveTheme

    @ObservedObject private var store = BuyApprovalStore.shared
    @State private var checked: Set<Int> = []
    @State private var showOthers = false
    @State private var askReason = false
    @State private var reasonDraft = ""
    @State private var hint = ""
    @State private var loadedOnce = false

    private var detail: BuyApprovalDetail? { store.detail(cardID) }

    private var allItems: [BuyItem] {
        guard let d = detail else { return [] }
        return d.picked + d.others
    }

    private var total: Double {
        allItems.filter { checked.contains($0.id) }.reduce(0) { $0 + $1.price }
    }

    private var overSingle: Bool {
        guard let d = detail, d.singleMax > 0 else { return false }
        return total > d.singleMax
    }

    private var overBalance: Bool {
        guard let d = detail else { return false }
        return total > d.balance
    }

    var body: some View {
        ZStack {
            // 她指定的效果：后面的聊天糊掉、压暗
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Color.black.opacity(0.22).ignoresSafeArea()
                .onTapGesture { BuyCardPresenter.dismiss() }

            if let d = detail {
                card(d)
                    .padding(.horizontal, 18)
            } else {
                ProgressView().tint(.white)
            }
        }
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .task {
            if !loadedOnce {
                loadedOnce = true
                await store.reload(cardID)
                if let d = detail { checked = Set(d.picked.map { $0.id }) }
            }
        }
    }

    // MARK: 卡片本体

    private func card(_ d: BuyApprovalDetail) -> some View {
        VStack(spacing: 0) {
            cover(d)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(d)
                    ForEach(d.picked) { item in itemRow(item, dimmed: d.decided) }
                    if !d.others.isEmpty { othersBlock(d) }
                    totalBlock(d)
                    if d.decided { verdict(d) } else { buttons(d) }
                }
                .padding(16)
            }
        }
        .background(theme.fyCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(theme.fyBorder.opacity(0.6), lineWidth: 0.7))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 26, y: 10)
        .frame(maxHeight: 620)
        .overlay(alignment: .topTrailing) {
            Button { BuyCardPresenter.dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.black.opacity(0.35), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .alert("为什么再想想？", isPresented: $askReason) {
            TextField("他会拿着这句话重新挑", text: $reasonDraft)
            Button("算了", role: .cancel) {}
            Button("发给他") {
                let why = reasonDraft
                Task { await send(d, decision: "think", reason: why) }
            }
        } message: {
            Text("这句话会原样递到他那儿。")
        }
    }

    /// 顶上那条横图（她给的参考卡就是这个版式）。商品主图是方的，
    /// 横着放会切掉上下——所以这里只当个门面，完整的方图在下面每一行里。
    private func cover(_ d: BuyApprovalDetail) -> some View {
        let first = d.picked.first(where: { !$0.cover.isEmpty }) ?? d.picked.first
        return ZStack {
            if let raw = first?.cover, !raw.isEmpty, let url = URL(string: raw) {
                CachedImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    theme.fyAccentSoft
                }
            } else {
                theme.fyAccentSoft
                Image(systemName: "bag.fill")
                    .font(.system(size: 30))
                    .foregroundColor(theme.fyAccent.opacity(0.5))
            }
        }
        .frame(height: 116)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func header(_ d: BuyApprovalDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(d.decided ? "他当时想买这些" : "他想买这 \(d.picked.count) 件")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(theme.text)
                Spacer()
                if d.round > 1 {
                    Text("第 \(d.round) 轮")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textDim)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(theme.fyAccentSoft, in: Capsule())
                }
            }
            if !d.note.isEmpty {
                Text(d.note)
                    .font(.system(size: 12.5, design: .serif))
                    .foregroundColor(theme.textDim)
                    .lineSpacing(3)
            }
        }
    }

    private func itemRow(_ item: BuyItem, dimmed: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                guard !dimmed else { return }
                if checked.contains(item.id) { checked.remove(item.id) } else { checked.insert(item.id) }
            } label: {
                Image(systemName: checked.contains(item.id) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17))
                    .foregroundColor(checked.contains(item.id) ? theme.fyAccent : theme.textDim.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(dimmed)

            ZStack {
                Color.black.opacity(0.06)
                if !item.cover.isEmpty, let url = URL(string: item.cover) {
                    CachedImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "bag").foregroundColor(theme.textDim.opacity(0.5))
                    }
                } else {
                    Image(systemName: "bag").foregroundColor(theme.textDim.opacity(0.5))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text("¥" + String(format: "%.2f", item.price))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(theme.fyAccent)
                    if !item.shop.isEmpty {
                        Text(item.shop)
                            .font(.system(size: 10))
                            .foregroundColor(theme.textDim)
                            .lineLimit(1)
                    }
                    if item.forWhom == "her" {
                        Text("给你的")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.fyAccent)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(theme.fyAccentSoft, in: Capsule())
                    }
                }
                if !item.reason.isEmpty {
                    Text("他说：" + item.reason)
                        .font(.system(size: 11.5, design: .serif))
                        .foregroundColor(theme.textDim)
                        .lineSpacing(2)
                }
            }
            Spacer(minLength: 0)
        }
        .opacity(dimmed && !item.approved ? 0.45 : 1)
    }

    private func othersBlock(_ d: BuyApprovalDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showOthers.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Rectangle().fill(theme.fyBorder.opacity(0.6)).frame(height: 0.6)
                    Text("车里还有 \(d.others.count) 件")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textDim)
                    Image(systemName: showOthers ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.textDim)
                    Rectangle().fill(theme.fyBorder.opacity(0.6)).frame(height: 0.6)
                }
            }
            .buttonStyle(.plain)
            if showOthers {
                ForEach(d.others) { item in itemRow(item, dimmed: d.decided) }
                if !d.decided {
                    Text("这些是他加进车但这次没勾的。你觉得该买，勾上就一起批了。")
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textDim.opacity(0.8))
                }
            }
        }
    }

    private func totalBlock(_ d: BuyApprovalDetail) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("合计")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textDim)
                Text("¥" + String(format: "%.2f", total))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(overSingle || overBalance ? Color(red: 0.741, green: 0.353, blue: 0.310) : theme.text)
                Spacer()
                Text("他还剩 ¥" + String(format: "%.2f", d.balance))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(theme.textDim)
            }
            if overSingle {
                Text("这一车超了你设的单笔上限 ¥" + String(format: "%.2f", d.singleMax))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(red: 0.741, green: 0.353, blue: 0.310))
            }
            if overBalance {
                Text("超过他钱包里剩下的钱了")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(red: 0.741, green: 0.353, blue: 0.310))
            }
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.741, green: 0.353, blue: 0.310))
            }
        }
        .padding(.top, 2)
    }

    private func buttons(_ d: BuyApprovalDetail) -> some View {
        HStack(spacing: 10) {
            Button {
                reasonDraft = ""
                askReason = true
            } label: {
                Text("再想想")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.fyAccentSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Task { await send(d, decision: "buy", reason: "") }
            } label: {
                Text(checked.isEmpty ? "一件都没勾" : "买吧")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(checked.isEmpty ? theme.textDim.opacity(0.4) : theme.fyAccent,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(checked.isEmpty || store.busy)
        }
        .padding(.top, 4)
    }

    private func verdict(_ d: BuyApprovalDetail) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: d.decision == "buy" ? "checkmark.seal.fill" : "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(d.decision == "buy"
                                     ? Color(red: 0.302, green: 0.518, blue: 0.404) : theme.textDim)
                Text(d.decision == "buy"
                     ? "你说了买吧（批了 \(d.approvedItems.count) 件）" : "你让他再想想")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)
            }
            if !d.reason.isEmpty {
                Text("你说：" + d.reason)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(theme.textDim)
                    .lineSpacing(3)
            }
            Text("这句话已经递给他了。")
                .font(.system(size: 10.5))
                .foregroundColor(theme.textDim.opacity(0.7))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.fyAccentSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func send(_ d: BuyApprovalDetail, decision: String, reason: String) async {
        hint = ""
        let ids = Array(checked)
        if let problem = await store.decide(d.id, decision: decision, picked: ids, reason: reason) {
            hint = problem
        } else {
            BuyCardPresenter.dismiss()
        }
    }
}

// MARK: - 付款单（0909 她照参考图定的：他付完了，留一张单子给她）
//
// 她定的几条：收货地址写死「默认地址」四个字，不读真实地址；
// 白天黑夜跟着聊天页的 theme 走（theme 本身就跟 app 总开关走，不另做开关）。

struct PaidReceiptMessageCard: View {
    let card: PaidReceiptCard
    let theme: AlcoveTheme

    /// 「已支付」那颗徽章的绿，跟审批卡里「你说了买吧」同一个色
    private var paidGreen: Color { Color(red: 0.302, green: 0.518, blue: 0.404) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            goods
            amountRow
            dashLine
            addressRow
            if !card.message.isEmpty { wordsBlock }
            Text("这笔已经付好啦")
                .font(.system(size: 10.5))
                .foregroundColor(theme.textDim.opacity(0.7))
                .padding(.top, 10)
        }
        .padding(14)
        .frame(maxWidth: 320, alignment: .leading)
        .background(theme.fyCard.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(theme.fyBorder.opacity(0.7), lineWidth: 0.7))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ALCOVE CHECKOUT")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(2.2)
                    .foregroundColor(theme.textDim.opacity(0.7))
                Text("给你留的付款单")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(theme.text)
            }
            Spacer(minLength: 6)
            Text("已支付")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(paidGreen)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(paidGreen.opacity(theme.isDark ? 0.18 : 0.12), in: Capsule())
        }
        .padding(.bottom, 13)
    }

    private var goods: some View {
        HStack(spacing: 10) {
            ZStack {
                Color.black.opacity(0.06)
                if let url = URL(string: card.coverURL), !card.coverURL.isEmpty {
                    CachedImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "bag")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textDim.opacity(0.5))
                    }
                } else {
                    Image(systemName: "bag")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textDim.opacity(0.5))
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Text(card.headline)
                .font(.system(size: 13, design: .serif))
                .foregroundColor(theme.text.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
    }

    private var amountRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("应付")
                .font(.system(size: 12))
                .foregroundColor(theme.textDim)
            Spacer(minLength: 8)
            Text("¥" + String(format: "%.2f", card.paid))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(theme.fyAccent)
        }
        .padding(.bottom, 11)
    }

    /// 参考图上那道虚线。Rectangle 描边会把四条边都画出来，所以自己给一条横线
    private var dashLine: some View {
        DashRule()
            .stroke(style: StrokeStyle(lineWidth: 0.8, dash: [3, 3.6]))
            .foregroundColor(theme.fyDash.opacity(0.85))
            .frame(height: 1)
            .padding(.bottom, 11)
    }

    private var addressRow: some View {
        HStack(spacing: 9) {
            Text("送到")
                .font(.system(size: 11.5))
                .foregroundColor(theme.textDim)
            Text("默认地址")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundColor(theme.text)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.fyCardSub.opacity(theme.isDark ? 0.55 : 0.75),
                    in: RoundedRectangle(cornerRadius: 11))
    }

    private var wordsBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "paperclip")
                .font(.system(size: 11))
                .foregroundColor(theme.fyAccent.opacity(0.75))
                .padding(.top, 1.5)
            Text(card.message)
                .font(.system(size: 12.5, design: .serif))
                .foregroundColor(theme.text.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.fyAccentSoft.opacity(theme.isDark ? 0.22 : 0.35),
                    in: RoundedRectangle(cornerRadius: 11))
        .padding(.top, 9)
    }
}

/// 一条横虚线，宽度跟着容器走
private struct DashRule: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
