import SwiftUI
import UIKit

// 大富翁牌桌。外壳（顶栏/等人/聊天/toast）在 QipaiTableShell，这里只画开局后的桌面。
// 走独立的 monopoly 服务（store service = "monopoly"）。
// 和牌类不同：state 全视角公开（没有手牌这种秘密），谁的现金地产都摆在明面上；
// 服务端把合法动作展开成带中文标签的按钮（build/sell 逐格列出），操作条直接照单画。

// MARK: - 视图模型（monopoly 的公开 state，只解用得上的字段）

struct MonopolyPlayerView: Decodable, Identifiable {
    let id: String
    let name: String
    let color: String?
    let cash: Int
    let pos: Int
    let inJail: Bool
    let jailTurns: Int
    let getOutFree: Int
    let bankrupt: Bool
}

struct MonopolyCell: Decodable {
    let idx: Int
    let type: String         // go / prop / rail / util / tax / luxury_tax / chance / community / jail / goto_jail / parking
    let name: String
    let group: String?
    let price: Int?
    let rents: [Int]?
    let houseCost: Int?
    let amount: Int?         // tax 的税额
}

struct MonopolyOwnedCell: Decodable {
    let owner: String
    let houses: Int
}

struct MonopolyCardFace: Decodable {
    let id: String
    let text: String?
}

struct MonopolyPendingCard: Decodable {
    let deck: String         // chance / community
    let card: MonopolyCardFace
}

struct MonopolyDebt: Decodable {
    let playerId: String
    let amount: Int
    let creditor: String?
}

struct MonopolyConfig: Decodable {
    let bail: Int?
    let salary: Int?
    let maxHouses: Int?
}

struct MonopolyView: Decodable {
    let seq: Int
    let phase: String        // awaiting_roll / awaiting_buy / awaiting_end / game_over
    let currentPlayer: String?
    let dice: [Int]?
    let extraRoll: Bool?
    let players: [MonopolyPlayerView]
    let cells: [String: MonopolyOwnedCell]
    let pendingCard: MonopolyPendingCard?
    let pendingDebt: MonopolyDebt?
    let board: [MonopolyCell]
    let config: MonopolyConfig?
    let winner: String?
    let log: [QipaiLogEntry]

    func player(_ id: String?) -> MonopolyPlayerView? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
    func cellAt(_ idx: Int) -> MonopolyCell? {
        guard idx >= 0, idx < board.count else { return nil }
        return board[idx]
    }
    func owned(_ idx: Int) -> MonopolyOwnedCell? {
        cells[String(idx)]
    }
}

extension MonopolyView: QipaiGameView {}

// MARK: - 牌桌

struct QipaiMonopolyTableView: View {
    let code: String
    var onExit: () -> Void

    @StateObject private var store: QipaiTableStore<MonopolyView>
    @State private var pickedCell: MonopolyCellSelection?

    init(code: String, onExit: @escaping () -> Void) {
        self.code = code
        self.onExit = onExit
        _store = StateObject(wrappedValue: QipaiTableStore(code: code, service: "monopoly"))
    }

    /// 同色组的经典配色（棋盘数据只给组号，颜色是前端的事）
    private static let groupColors: [String: Color] = [
        "g1": QipaiPalette.qhex(0xA97C50), "g2": QipaiPalette.qhex(0x9EC9E8),
        "g3": QipaiPalette.qhex(0xE89EB8), "g4": QipaiPalette.qhex(0xEFA25C),
        "g5": QipaiPalette.qhex(0xE06055), "g6": QipaiPalette.qhex(0xE8CF5A),
        "g7": QipaiPalette.qhex(0x7DC98F), "g8": QipaiPalette.qhex(0x5C77C9),
    ]

    var body: some View {
        ZStack {
            QipaiTableShell(store: store, fallbackTitle: "大富翁",
                            round: nil, onExit: onExit) {
                if let view = store.view {
                    table(view)
                }
            } help: {
                helpContent
            }
            cardOverlay
            gameOverOverlay
        }
        .sheet(item: $pickedCell) { sel in
            if let view = store.view {
                cellDetailSheet(view, idx: sel.idx)
            }
        }
    }

    private var you: String? { store.frame?.you }

    private func table(_ view: MonopolyView) -> some View {
        VStack(spacing: 8) {
            playersStrip(view)
            boardView(view)
            QipaiFeedStrip(store: store)
            actionBar(view)
        }
        .padding(.horizontal, 12)
    }

    // MARK: 玩家条（2~4 人，现金地位全公开）

    private func playersStrip(_ view: MonopolyView) -> some View {
        HStack(spacing: 8) {
            ForEach(view.players) { p in
                playerCard(p, view: view)
            }
        }
    }

    private func playerCard(_ p: MonopolyPlayerView, view: MonopolyView) -> some View {
        let active = view.currentPlayer == p.id && view.phase != "game_over"
        return VStack(spacing: 3) {
            QipaiHalo(active: active)
            HStack(spacing: 4) {
                Circle().fill(Self.hexColor(p.color))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                Text(p.name).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(QipaiPalette.ink).lineLimit(1)
            }
            Text("¥\(p.cash)")
                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                .foregroundColor(p.bankrupt ? QipaiPalette.inkDim : QipaiPalette.ink)
            HStack(spacing: 3) {
                if p.bankrupt {
                    QipaiChip(text: "破产", tone: .red)
                } else if p.inJail {
                    QipaiChip(text: "监狱", tone: .red, icon: "lock")
                } else {
                    Text(statusLine(p, view: view))
                        .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
                }
                if p.getOutFree > 0 {
                    QipaiChip(text: "出狱卡", tone: .neutral)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7).padding(.horizontal, 4)
        .qipaiPanel(corner: 14)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(QipaiPalette.glowRing, lineWidth: active ? 1.6 : 0))
        .opacity(p.bankrupt ? 0.55 : 1)
    }

    private func statusLine(_ p: MonopolyPlayerView, view: MonopolyView) -> String {
        let props = view.cells.values.filter { $0.owner == p.id }.count
        return props > 0 ? "地产 \(props) 处" : " "
    }

    // MARK: 棋盘（11×11 周圈 40 格，逆时针：右下起点 → 左下监狱 → 左上停车场 → 右上进监狱）

    /// idx → (row, col)，row/col 都是 0~10
    private static func gridPos(_ idx: Int) -> (row: Int, col: Int) {
        switch idx {
        case 0...10:  return (10, 10 - idx)
        case 11...19: return (20 - idx, 0)
        case 20...30: return (0, idx - 20)
        default:      return (idx - 30, 10)
        }
    }

    private func boardView(_ view: MonopolyView) -> some View {
        GeometryReader { geo in
            let unit = geo.size.width / 11
            ZStack {
                ForEach(0..<40, id: \.self) { idx in
                    let pos = Self.gridPos(idx)
                    cellView(view, idx: idx, size: unit)
                        .frame(width: unit - 1.5, height: unit - 1.5)
                        .position(x: (CGFloat(pos.col) + 0.5) * unit,
                                  y: (CGFloat(pos.row) + 0.5) * unit)
                }
                centerInfo(view)
                    .frame(width: unit * 8.6, height: unit * 8.6)
                    .position(x: geo.size.width / 2, y: geo.size.width / 2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// 「北京·南锣鼓巷」在 33pt 的格子里摆不下，取「·」后面那截
    private static func shortName(_ cell: MonopolyCell?) -> String {
        guard let cell else { return "" }
        if let dot = cell.name.firstIndex(of: "·"), cell.type == "prop" {
            return String(cell.name[cell.name.index(after: dot)...])
        }
        return cell.name
    }

    private func cellView(_ view: MonopolyView, idx: Int, size: CGFloat) -> some View {
        let cell = view.cellAt(idx)
        let owned = view.owned(idx)
        let ownerColor = owned.flatMap { view.player($0.owner)?.color }.map { Self.hexColor($0) }
        let here = view.players.filter { !$0.bankrupt && $0.pos == idx }
        let maxHouses = view.config?.maxHouses ?? 5

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(QipaiPalette.fieldBg)
            if let ownerColor {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(ownerColor.opacity(0.22))
            }
            VStack(spacing: 1) {
                if let group = cell?.group, let gc = Self.groupColors[group] {
                    RoundedRectangle(cornerRadius: 1).fill(gc)
                        .frame(height: size * 0.14)
                        .padding(.horizontal, 2).padding(.top, 2)
                }
                Text(Self.shortName(cell))
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundColor(QipaiPalette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 1)
                if let owned, owned.houses > 0 {
                    Text(owned.houses >= maxHouses ? "旅館" : "房×\(owned.houses)")
                        .font(.system(size: size * 0.17, weight: .semibold))
                        .foregroundColor(QipaiPalette.accent)
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if !here.isEmpty {
                HStack(spacing: 2) {
                    ForEach(here) { p in
                        Circle().fill(Self.hexColor(p.color))
                            .frame(width: size * 0.18, height: size * 0.18)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .stroke(ownerColor ?? QipaiPalette.line, lineWidth: ownerColor != nil ? 1.3 : 0.8))
        .contentShape(Rectangle())
        .onTapGesture { pickedCell = MonopolyCellSelection(idx: idx) }
    }

    private func centerInfo(_ view: MonopolyView) -> some View {
        VStack(spacing: 7) {
            if let dice = view.dice, dice.count == 2 {
                HStack(spacing: 8) {
                    Image(systemName: "die.face.\(min(max(dice[0], 1), 6))")
                    Image(systemName: "die.face.\(min(max(dice[1], 1), 6))")
                }
                .font(.system(size: 30, weight: .light))
                .foregroundColor(QipaiPalette.ink)
            }
            Text(turnLine(view))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(view.currentPlayer == you ? QipaiPalette.red : QipaiPalette.ink)
                .multilineTextAlignment(.center)
            if view.extraRoll == true {
                QipaiChip(text: "双数，还能再掷", tone: .live, icon: "dice")
            }
            if let debt = view.pendingDebt {
                Text("\(view.player(debt.playerId)?.name ?? "?") 欠 ¥\(debt.amount) 还不上")
                    .font(.system(size: 10.5)).foregroundColor(QipaiPalette.red)
            }
        }
        .padding(8)
        .qipaiPanel(corner: 16, dotted: true)
    }

    private func turnLine(_ view: MonopolyView) -> String {
        if view.phase == "game_over" {
            return view.player(view.winner).map { "\($0.name) 赢下整局" } ?? "全员破产，无人生还"
        }
        let name = view.player(view.currentPlayer)?.name ?? "…"
        let mine = view.currentPlayer == you
        switch view.phase {
        case "awaiting_buy": return mine ? "买不买这块地？" : "\(name) 在考虑买地…"
        case "awaiting_end": return mine ? "盖房/卖房，或结束回合" : "\(name) 行动中…"
        default:             return mine ? "轮到你掷骰子" : "轮到 \(name)"
        }
    }

    // MARK: 操作条（服务端把合法动作展开成带标签的招，照单画按钮）

    @ViewBuilder private func actionBar(_ view: MonopolyView) -> some View {
        if view.phase == "game_over" {
            EmptyView()
        } else if store.mySeat == nil {
            Text("观战中").font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                .padding(.bottom, 8)
        } else if store.legal.isEmpty {
            Text("等 \(view.player(view.currentPlayer)?.name ?? "…") 行动…")
                .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                .padding(.bottom, 8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.legal) { move in
                        Button(move.label ?? move.type) {
                            var body: [String: Any] = ["type": move.type]
                            if let idx = move.cellIdx { body["cellIdx"] = idx }
                            Task { await store.act(body) }
                        }
                        .buttonStyle(QipaiEmbossedButtonStyle(prominent: isPrimary(move.type)))
                        .disabled(store.busy)
                    }
                }
                .padding(.horizontal, 2).padding(.vertical, 4)
            }
            .padding(.bottom, 6)
        }
    }

    private func isPrimary(_ type: String) -> Bool {
        ["roll", "buy", "card_ack", "declare_bankrupt"].contains(type)
    }

    // MARK: 翻卡确认（机会/命运）

    @ViewBuilder private var cardOverlay: some View {
        if let view = store.view, let pending = view.pendingCard,
           view.currentPlayer == you, view.phase != "game_over" {
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    QipaiChip(text: pending.deck == "chance" ? "机会" : "命运",
                              tone: pending.deck == "chance" ? .live : .neutral,
                              icon: pending.deck == "chance" ? "questionmark.circle" : "shippingbox")
                    Text(pending.card.text ?? pending.card.id)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(QipaiPalette.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    Button("翻开 · 认了") {
                        Task { await store.act(["type": "card_ack"]) }
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(store.busy)
                }
                .padding(22)
                .frame(maxWidth: 300)
                .qipaiPanel(corner: 20, dotted: true)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.28).ignoresSafeArea())
        }
    }

    // MARK: 终局盖板

    @ViewBuilder private var gameOverOverlay: some View {
        if let view = store.view, view.phase == "game_over" {
            VStack(spacing: 14) {
                Spacer()
                VStack(spacing: 12) {
                    Text("收盤")
                        .font(.qipaiDisplay(28))
                        .foregroundColor(QipaiPalette.ink)
                    if let winner = view.player(view.winner) {
                        Text("\(winner.name) 把所有人都送进了当铺")
                            .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
                    }
                    VStack(spacing: 6) {
                        ForEach(view.players.sorted { $0.cash > $1.cash }) { p in
                            HStack {
                                Circle().fill(Self.hexColor(p.color)).frame(width: 8, height: 8)
                                Text(p.name).font(.system(size: 13, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink)
                                if p.id == view.winner { QipaiChip(text: "赢家", tone: .red) }
                                if p.bankrupt { QipaiChip(text: "破产", tone: .neutral) }
                                Spacer()
                                Text("¥\(p.cash)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(QipaiPalette.ink)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    HStack(spacing: 10) {
                        Button("回大厅") { onExit() }
                            .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                        if store.isHost {
                            Button("关房") {
                                Task { await store.closeRoom(); onExit() }
                            }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                        }
                    }
                    QipaiWhisper(text: "the only thing anyone loses here is face.")
                }
                .padding(20)
                .frame(maxWidth: 320)
                .qipaiPanel(corner: 22, dotted: true)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.32).ignoresSafeArea())
        }
    }

    // MARK: 格子详情弹层

    private func cellDetailSheet(_ view: MonopolyView, idx: Int) -> some View {
        let cell = view.cellAt(idx)
        let owned = view.owned(idx)
        let owner = owned.flatMap { view.player($0.owner) }
        return ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            QipaiDots(spacing: 16, radius: 1.3, opacity: 0.28).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let group = cell?.group, let gc = Self.groupColors[group] {
                        RoundedRectangle(cornerRadius: 3).fill(gc).frame(width: 16, height: 16)
                    }
                    Text(cell?.name ?? "第 \(idx) 格")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(QipaiPalette.ink)
                    Spacer()
                    QipaiChip(text: Self.typeLabel(cell?.type), tone: .neutral)
                }
                if let price = cell?.price {
                    detailRow("售价", "¥\(price)")
                }
                if let owner {
                    HStack(spacing: 6) {
                        Text("地主").font(.system(size: 11.5)).foregroundColor(QipaiPalette.inkDim)
                        Circle().fill(Self.hexColor(owner.color)).frame(width: 8, height: 8)
                        Text(owner.name).font(.system(size: 13, weight: .semibold))
                            .foregroundColor(QipaiPalette.ink)
                        if let houses = owned?.houses, houses > 0 {
                            QipaiChip(text: houses >= (view.config?.maxHouses ?? 5)
                                      ? "旅館" : "房 ×\(houses)", tone: .live)
                        }
                    }
                } else if cell?.price != nil {
                    detailRow("地主", "还没人买")
                }
                if let rents = cell?.rents, !rents.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cell?.type == "prop" ? "租金（空地 → 满房）" : "租金档位")
                            .font(.system(size: 11.5)).foregroundColor(QipaiPalette.inkDim)
                        Text(rents.map { "¥\($0)" }.joined(separator: " · "))
                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            .foregroundColor(QipaiPalette.ink)
                    }
                }
                if let houseCost = cell?.houseCost {
                    detailRow("盖一栋房", "¥\(houseCost)（卖房半价回收）")
                }
                if let amount = cell?.amount {
                    detailRow("税额", "¥\(amount)")
                }
                let visitors = view.players.filter { !$0.bankrupt && $0.pos == idx }
                if !visitors.isEmpty {
                    detailRow("停着", visitors.map(\.name).joined(separator: "、"))
                }
                Spacer()
                QipaiWhisper(text: "location, location, location.")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
        }
        .presentationDetents([.height(320)])
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 11.5)).foregroundColor(QipaiPalette.inkDim)
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(QipaiPalette.ink)
        }
    }

    private static func typeLabel(_ type: String?) -> String {
        switch type {
        case "prop": return "地产"
        case "rail": return "车站"
        case "util": return "公用事业"
        case "tax", "luxury_tax": return "税"
        case "chance": return "机会"
        case "community": return "命运"
        case "go": return "起点"
        case "jail": return "监狱"
        case "goto_jail": return "进监狱"
        case "parking": return "停车场"
        default: return "空地"
        }
    }

    private static func hexColor(_ hex: String?) -> Color {
        guard let hex, hex.hasPrefix("#"), hex.count == 7,
              let v = Int(hex.dropFirst(), radix: 16) else { return QipaiPalette.accent }
        return Color(red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }

    // MARK: 玩法说明

    @ViewBuilder private var helpContent: some View {
        Text("大富翁 · 玩法")
            .font(.qipaiMemo(18))
            .foregroundColor(QipaiPalette.ink)
        Group {
            Text("2~4 人，中国城市棋盘。掷骰子绕圈走，路过起点领工资，踩到没主的地可以买，踩到别人的地要交租。")
            Text("集齐同一个颜色组的所有地才能盖房，房子越多租金越狠，第 5 栋变旅馆。盖房要均衡：同组各地的房数相差不能超过 1。")
            Text("掷出双数再走一次，连掷三次双数直接进监狱。出狱靠：掷双数、交保释金、或用出狱卡。")
            Text("机会/命运格抽卡，点「翻开·认了」生效。现金掏不出来时系统先自动半价卖房抵账，还不够就只能宣布破产出局。")
            Text("最后一个没破产的人赢下整局。点棋盘上任何一格能看它的价格、租金和地主。")
        }
        .font(.system(size: 12.5))
        .foregroundColor(QipaiPalette.ink.opacity(0.85))
        .lineSpacing(4)
    }
}

/// sheet(item:) 要 Identifiable，包一层
struct MonopolyCellSelection: Identifiable {
    let idx: Int
    var id: Int { idx }
}
