import SwiftUI
import UIKit

// 大富豪牌桌。外壳（顶栏/等人/聊天/toast）在 QipaiTableShell，这里只画开局后的桌面。
// 走独立的 daifugo 服务（store service = "daifugo"），牌 id 和扑克组件与斗地主同一套。

// MARK: - 视图模型（daifugo viewFor 的脱敏视图，只解用得上的字段）

struct DaifugoPlayerView: Decodable, Identifiable {
    let id: String
    let name: String
    let isAI: Bool
    let rank: String?        // daifugo / fugo / heimin / hinmin / daihinmin
    let finished: Int?       // 出完的次序（1 起），nil = 还在打
    let passed: Bool
    let foul: String?
    let score: Int
    let handCount: Int
    let hand: [String]?
}

struct DaifugoCombo: Decodable {
    let type: String         // set / stair
    let size: Int
}

struct DaifugoField: Decodable {
    let cards: [String]
    let by: String
    let combo: DaifugoCombo
}

struct DaifugoExchangeItem: Decodable, Identifiable {
    let from: String
    let to: String
    let count: Int
    let done: Bool
    let taken: [String]?     // 只对当事双方可见
    let given: [String]?
    var id: String { "\(from)>\(to)" }
}

struct DaifugoExchange: Decodable {
    let pending: [DaifugoExchangeItem]
}

struct DaifugoResult: Decodable {
    let playerId: String?
    let name: String
    let place: Int
    let rank: String
    let gain: Int
    let score: Int
    let foul: String?
}

struct DaifugoRoundEntry: Decodable, Identifiable {
    let round: Int
    let results: [DaifugoResult]
    var id: Int { round }
}

struct DaifugoView: Decodable {
    let seq: Int
    let phase: String        // exchange / playing / round_over / game_over
    let round: Int
    let turnOrder: [String]
    let current: String?
    let leader: String?
    let you: String?
    let players: [DaifugoPlayerView]
    let field: DaifugoField?
    let lastToPlay: String?
    let revolution: Bool
    let suitLock: [String]?
    let exchange: DaifugoExchange?
    let lastResults: [DaifugoResult]?
    let rounds: [DaifugoRoundEntry]
    let winner: String?
    let log: [QipaiLogEntry]

    func player(_ id: String?) -> DaifugoPlayerView? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
    var me: DaifugoPlayerView? { player(you) }
}

extension DaifugoView: QipaiGameView {}

// MARK: - 牌桌

struct QipaiDaifugoTableView: View {
    let code: String
    var onExit: () -> Void

    @StateObject private var store: QipaiTableStore<DaifugoView>
    @State private var selected: Set<String> = []

    init(code: String, onExit: @escaping () -> Void) {
        self.code = code
        self.onExit = onExit
        _store = StateObject(wrappedValue: QipaiTableStore(code: code, service: "daifugo"))
    }

    private static let rankLabels: [String: String] = [
        "daifugo": "大富豪", "fugo": "富豪", "heimin": "平民",
        "hinmin": "贫民", "daihinmin": "大贫民"
    ]

    var body: some View {
        ZStack {
            QipaiTableShell(store: store, fallbackTitle: "大富豪",
                            round: store.view?.round, onExit: onExit) {
                if let view = store.view {
                    table(view)
                }
            } help: {
                helpContent
            }
            overlays
        }
        // cover 根上的键盘豁免（免疫罩之外的保险：overlays 也不许被键盘顶）
        .ignoresSafeArea(.keyboard)
        .onChange(of: (store.view?.seq ?? 0)) { _ in
            let hand = Set(store.view?.me?.hand ?? [])
            selected = selected.intersection(hand)
        }
    }

    private func table(_ view: DaifugoView) -> some View {
        VStack(spacing: 8) {
            opponentsRow(view)
            centerBoard(view)
            QipaiFeedStrip(store: store)
            handArea(view)
        }
        .padding(.horizontal, 12)
    }

    // MARK: 对手条（2~4 人局，按出牌顺序从我的下家排起）

    private func opponents(_ view: DaifugoView) -> [DaifugoPlayerView] {
        guard let you = view.you,
              let idx = view.turnOrder.firstIndex(of: you) else {
            return view.players.filter { $0.id != view.you }
        }
        let order = view.turnOrder
        return (1..<order.count).compactMap { view.player(order[(idx + $0) % order.count]) }
    }

    private func opponentsRow(_ view: DaifugoView) -> some View {
        HStack(spacing: 8) {
            ForEach(opponents(view)) { p in
                seatCard(p, view: view)
            }
        }
    }


    /// 座位色：对手卡名字/行动描边跟牌桌闲聊同一套（0828 她要的分色）
    private func seatTone(_ id: String) -> Color? {
        store.seatIndex(ofPlayer: id).map(QipaiPalette.seatTone)
    }

    private func seatCard(_ p: DaifugoPlayerView, view: DaifugoView) -> some View {
        VStack(spacing: 4) {
            QipaiHalo(active: view.current == p.id)
            HStack(spacing: 4) {
                if p.isAI {
                    Image(systemName: "sparkles").font(.system(size: 9))
                        .foregroundColor(QipaiPalette.accent)
                }
                Text(p.name).font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(seatTone(p.id) ?? QipaiPalette.ink).lineLimit(1)
            }
            HStack(spacing: 5) {
                Text("\(p.handCount)")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(QipaiPalette.ink)
                Text("张").font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
                rankBadge(p)
            }
            Text(statusLine(p, view: view))
                .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 4)
        .qipaiPanel(corner: 15)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(seatTone(p.id) ?? QipaiPalette.glowRing, lineWidth: view.current == p.id ? 1.6 : 0))
    }

    @ViewBuilder private func rankBadge(_ p: DaifugoPlayerView) -> some View {
        if let rank = p.rank, let label = Self.rankLabels[rank] {
            QipaiChip(text: label, tone: rank == "daifugo" ? .red : .neutral)
        }
    }

    private func statusLine(_ p: DaifugoPlayerView, view: DaifugoView) -> String {
        if p.foul != nil { return "犯规垫底" }
        if let place = p.finished { return "第 \(place) 个出完" }
        if view.phase == "exchange" { return "换牌中…" }
        if view.current == p.id { return p.isAI ? "思考中…" : "出牌中…" }
        if p.passed { return "过" }
        return " "
    }

    // MARK: 场中央

    private func comboLabel(_ combo: DaifugoCombo) -> String {
        if combo.type == "stair" { return "阶梯 ×\(combo.size)" }
        switch combo.size {
        case 1: return "单张"
        case 2: return "对子"
        case 3: return "三条"
        default: return "四条+"
        }
    }

    private func centerBoard(_ view: DaifugoView) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if view.revolution { QipaiChip(text: "革命中", tone: .red, icon: "arrow.2.squarepath") }
                if let lock = view.suitLock {
                    QipaiChip(text: "縛り " + lock.map(suitGlyph).joined(), tone: .live, icon: "lock")
                }
                Spacer()
                QipaiChip(text: "第 \(view.round) 轮")
            }

            VStack(spacing: 7) {
                banner(view)
                if view.phase == "exchange" {
                    exchangeBoard(view)
                } else if let field = view.field {
                    HStack(spacing: -14) {
                        ForEach(field.cards, id: \.self) { id in
                            QipaiCardFace(id: id, width: 42)
                        }
                    }
                    Text("\(view.player(field.by)?.name ?? "?") 出的 · \(comboLabel(field.combo))")
                        .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                } else if view.phase == "playing" {
                    Text("场上空着，\(view.player(view.leader)?.name ?? "…") 领出")
                        .font(.system(size: 11.5)).foregroundColor(QipaiPalette.inkDim)
                        .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 118)
            .padding(10)
            .qipaiPanel(corner: 17, dotted: true)
        }
    }

    private func suitGlyph(_ s: String) -> String {
        switch s {
        case "S": return "♠"
        case "H": return "♥"
        case "D": return "♦"
        default:  return "♣"
        }
    }

    @ViewBuilder private func banner(_ view: DaifugoView) -> some View {
        switch view.phase {
        case "exchange":
            Text("换牌回合 · 贫方上缴，富方回赠")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(QipaiPalette.ink)
        case "playing":
            Text("轮到 \(view.player(view.current)?.name ?? "…")\(view.current == view.you ? "（你）" : "")")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(view.current == view.you ? QipaiPalette.red : QipaiPalette.ink)
        default:
            EmptyView()
        }
    }

    /// 换牌阶段的进度板。pending 的 from = 富方（要回赠的人），to = 贫方；
    /// taken = 贫方自动上缴给富方的牌，只对当事双方可见。
    private func exchangeBoard(_ view: DaifugoView) -> some View {
        VStack(spacing: 6) {
            ForEach(view.exchange?.pending ?? []) { item in
                VStack(spacing: 3) {
                    HStack(spacing: 5) {
                        Text("\(view.player(item.to)?.name ?? "?") 上缴 → \(view.player(item.from)?.name ?? "?") 回赠")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(QipaiPalette.ink)
                        QipaiChip(text: "\(item.count) 张", tone: .neutral)
                        QipaiChip(text: item.done ? "已回赠" : "等回赠", tone: item.done ? .done : .live)
                    }
                    if let taken = item.taken, !taken.isEmpty {
                        HStack(spacing: 4) {
                            Text(item.to == view.you ? "上缴了" : "收到")
                                .font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
                            HStack(spacing: -10) {
                                ForEach(taken, id: \.self) { QipaiCardFace(id: $0, width: 26) }
                            }
                            if let given = item.given, !given.isEmpty {
                                Text("回赠").font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
                                HStack(spacing: -10) {
                                    ForEach(given, id: \.self) { QipaiCardFace(id: $0, width: 26) }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: 手牌与操作

    /// 富方在换牌阶段欠几张回赠（不欠 = 0）
    private func owedGiveBack(_ view: DaifugoView) -> Int {
        guard view.phase == "exchange", let you = view.you else { return 0 }
        return view.exchange?.pending.first { $0.from == you && !$0.done }?.count ?? 0
    }

    private func handArea(_ view: DaifugoView) -> some View {
        VStack(spacing: 8) {
            if let me = view.me {
                HStack(spacing: 6) {
                    QipaiHalo(active: view.current == me.id && view.phase == "playing")
                    Text("你的手牌 \(me.handCount) 张")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(QipaiPalette.inkDim)
                    rankBadge(me)
                    Spacer()
                    if !selected.isEmpty {
                        Button("清空") { selected = [] }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                    }
                }
                handFan(me)
                actionBar(view)
            } else {
                Text("观战中 · 谁的手牌都看不见").font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                    .padding(.bottom, 20)
            }
        }
        .padding(.bottom, 10)
    }

    private func handFan(_ me: DaifugoPlayerView) -> some View {
        let hand = QipaiCard.sortDesc(me.hand ?? [])
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -22) {
                ForEach(hand, id: \.self) { id in
                    QipaiCardFace(id: id, width: 52)
                        .offset(y: selected.contains(id) ? -14 : 0)
                        .onTapGesture {
                            if selected.contains(id) { selected.remove(id) }
                            else { selected.insert(id) }
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.75),
                                   value: selected.contains(id))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 4)
        }
    }

    /// 选中的牌能凑成哪一招（王可替身：同一把牌可能有多种解释，取最弱的那种）
    private func matchedPlay() -> QipaiLegalMove? {
        store.legal.first { $0.type == "play" && Set($0.cards ?? []) == selected }
    }

    @ViewBuilder private func actionBar(_ view: DaifugoView) -> some View {
        let owed = owedGiveBack(view)
        if owed > 0 {
            HStack(spacing: 10) {
                Text("选 \(owed) 张回赠")
                    .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                Button("回赠") {
                    Task { await store.act(["type": "give_back", "cards": Array(selected)]) }
                }
                .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                .disabled(selected.count != owed || store.busy)
            }
        } else if view.phase == "exchange" {
            Text("等富方回赠完就开打…").font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
        } else if view.phase == "playing" {
            if view.current == view.you {
                HStack(spacing: 10) {
                    if store.legal.contains(where: { $0.type == "pass" }) {
                        Button("过") { Task { await store.pass() } }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                            .disabled(store.busy)
                    }
                    let matched = matchedPlay()
                    let title: String = {
                        if let label = matched?.label { return "出牌 · \(label)" }
                        return "出牌"
                    }()
                    Button(title) {
                        if let matched {
                            var body: [String: Any] = ["type": "play", "cards": matched.cards ?? []]
                            if let asType = matched.asType { body["as"] = asType }
                            Task { await store.act(body) }
                        }
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(matched == nil || store.busy)
                }
            } else {
                Text("等 \(view.player(view.current)?.name ?? "…") 出牌…")
                    .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
            }
        }
    }

    // MARK: 局间/终局盖板

    @ViewBuilder private var overlays: some View {
        if let view = store.view, view.phase == "round_over" || view.phase == "game_over" {
            resultOverlay(view)
        }
    }

    private func resultOverlay(_ view: DaifugoView) -> some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                if view.phase == "round_over" {
                    Text("名次揭曉")
                        .font(.qipaiDisplay(28))
                        .foregroundColor(QipaiPalette.ink)
                } else {
                    Text("收盤")
                        .font(.qipaiDisplay(28))
                        .foregroundColor(QipaiPalette.ink)
                    if let winner = view.player(view.winner) {
                        Text("\(winner.name) 是最后的大赢家")
                            .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
                    }
                }

                VStack(spacing: 6) {
                    if view.phase == "round_over", let results = view.lastResults {
                        ForEach(results, id: \.name) { r in
                            HStack {
                                Text(r.name).font(.system(size: 13, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink)
                                QipaiChip(text: Self.rankLabels[r.rank] ?? r.rank,
                                          tone: r.rank == "daifugo" ? .red : .neutral)
                                if r.foul != nil { QipaiChip(text: "犯规", tone: .red) }
                                Spacer()
                                Text(r.gain >= 0 ? "+\(r.gain)" : "\(r.gain)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(r.gain > 0 ? QipaiPalette.accent : QipaiPalette.inkDim)
                                Text("共 \(r.score)")
                                    .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                            }
                        }
                    } else {
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
                }
                .padding(.horizontal, 6)

                if view.phase == "round_over" {
                    HStack(spacing: 10) {
                        if store.mySeat != nil {
                            Button("再来一轮") { Task { await store.nextRound() } }
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
                            Button("关房") {
                                Task { await store.closeRoom(); onExit() }
                            }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                        }
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

    // MARK: 玩法说明

    @ViewBuilder private var helpContent: some View {
        Text("大富豪 · 玩法")
            .font(.qipaiMemo(18))
            .foregroundColor(QipaiPalette.ink)
        Group {
            Text("2~4 人爬牌。54 张轮发到尽，先出完的当大富豪，最后的当大贫民。")
            Text("牌型：单张、对子、三条、四条+（王可替任意牌）、同花色连号的阶梯（3 张起）。跟牌要同型同张数、严格更大；过了这墩就不能再出。")
            Text("八切：出的牌里带 8 → 立刻清场重新领出。革命：四条+ 触发，大小整个反转。王单出最大，但会被黑桃 3 反杀（可选规则）。")
            Text("第 2 轮起换牌：大贫民自动上缴最强牌给大富豪（2 张），富豪贫民 1 张，富方挑牌回赠，回齐才开打。")
            Text("计分按名次累计，想玩几轮玩几轮，房主随时收盘出总榜。")
            Text("选牌点一下抬起来，凑不成合法牌型出牌键会灰着——王替谁由系统挑最划算的解释。")
        }
        .font(.system(size: 12.5))
        .foregroundColor(QipaiPalette.ink.opacity(0.85))
        .lineSpacing(4)
    }
}
