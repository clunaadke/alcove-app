import SwiftUI

// 炸金花牌桌：暗牌牌背、看牌翻面、筹码池、跟注/加注/比牌。

struct QipaiZjhTableView: View {
    let code: String
    var onExit: () -> Void

    @StateObject private var store: QipaiTableStore<ZjhView>
    @State private var showCompare = false

    init(code: String, onExit: @escaping () -> Void) {
        self.code = code
        self.onExit = onExit
        _store = StateObject(wrappedValue: QipaiTableStore(code: code))
    }

    var body: some View {
        ZStack {
            QipaiTableShell(store: store, fallbackTitle: "炸金花",
                            round: store.view?.round, onExit: onExit) {
                if let view = store.view {
                    table(view)
                }
            } help: {
                helpContent
            }
            overlays
        }
    }

    // MARK: 牌桌

    private func table(_ view: ZjhView) -> some View {
        VStack(spacing: 8) {
            opponentsRow(view)
            centerBoard(view)
            logStrip(view)
            Spacer(minLength: 4)
            myArea(view)
        }
        .padding(.horizontal, 12)
    }

    private func opponents(_ view: ZjhView) -> [ZjhPlayerView] {
        guard let you = view.you,
              let idx = view.turnOrder.firstIndex(of: you) else {
            return view.players.filter { $0.id != view.you }
        }
        let order = view.turnOrder
        var out: [ZjhPlayerView] = []
        for step in 1..<order.count {
            if let p = view.player(order[(idx + step) % order.count]) { out.append(p) }
        }
        return out
    }

    private func opponentsRow(_ view: ZjhView) -> some View {
        HStack(spacing: 8) {
            ForEach(opponents(view)) { p in
                seatCard(p, view: view)
            }
        }
    }

    private func seatCard(_ p: ZjhPlayerView, view: ZjhView) -> some View {
        VStack(spacing: 4) {
            QipaiHalo(active: view.current == p.id)
            Text(p.name).font(.system(size: 12, weight: .semibold))
                .foregroundColor(QipaiPalette.ink).lineLimit(1)
            HStack(spacing: -8) {
                if let cards = p.cards {
                    ForEach(cards, id: \.self) { QipaiCardFace(id: $0, width: 26) }
                } else {
                    ForEach(0..<p.handCount, id: \.self) { _ in QipaiCardBack(width: 26) }
                }
            }
            .opacity(p.folded ? 0.35 : 1)
            if let hand = p.hand {
                Text(hand).font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(QipaiPalette.red)
            }
            Text("籌碼 \(p.chips)")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(QipaiPalette.inkDim)
            statusChip(p, view: view)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 4)
        .qipaiPanel(corner: 15)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(QipaiPalette.glowRing, lineWidth: view.current == p.id ? 1.6 : 0))
        .opacity(p.out ? 0.5 : 1)
    }

    @ViewBuilder private func statusChip(_ p: ZjhPlayerView, view: ZjhView) -> some View {
        if p.out { QipaiChip(text: "輪空", tone: .done) }
        else if p.folded { QipaiChip(text: "棄牌", tone: .done) }
        else if p.allin { QipaiChip(text: "全押", tone: .red) }
        else if view.current == p.id { QipaiChip(text: p.isAI ? "思考中" : "行動中", tone: .live) }
        else { QipaiChip(text: p.looked ? "看過牌" : "悶著", tone: .neutral) }
    }

    // MARK: 场中央

    private func centerBoard(_ view: ZjhView) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text("池底")
                    .font(.qipaiMemo(14)).foregroundColor(QipaiPalette.inkDim)
                Text("\(view.pot)")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(QipaiPalette.ink)
            }
            HStack(spacing: 6) {
                QipaiChip(text: "當前注 \(view.currentBet)")
                if let dealer = view.player(view.dealer) {
                    QipaiChip(text: "莊 \(dealer.name)", icon: "circle.circle")
                }
            }
            if view.phase == "betting" {
                Text("輪到 \(view.player(view.current)?.name ?? "…")\(view.current == view.you ? "（你）" : "")")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(view.current == view.you ? QipaiPalette.red : QipaiPalette.ink)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(10)
        .qipaiPanel(corner: 17, dotted: true)
    }

    // MARK: 事件流

    private func logStrip(_ view: ZjhView) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(view.log.suffix(30)) { entry in
                        Text(entry.text)
                            .font(.system(size: 10))
                            .foregroundColor(entry.type == "showdown" || entry.type == "compare"
                                             ? QipaiPalette.red : QipaiPalette.inkDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(entry.seq)
                    }
                }
                .padding(8)
            }
            .frame(height: 70)
            .qipaiPanel(corner: 13)
            .onChange(of: view.log.count) { _ in
                if let last = view.log.last {
                    withAnimation { proxy.scrollTo(last.seq, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = view.log.last { proxy.scrollTo(last.seq, anchor: .bottom) }
            }
        }
    }

    // MARK: 我的区域

    private func myArea(_ view: ZjhView) -> some View {
        VStack(spacing: 8) {
            if let me = view.me {
                HStack(spacing: 6) {
                    QipaiHalo(active: view.current == me.id)
                    Text("籌碼 \(me.chips) · 本局已下 \(me.bet)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(QipaiPalette.inkDim)
                    Spacer()
                    if let hand = me.hand {
                        Text(hand).font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(QipaiPalette.red)
                    }
                }
                HStack(spacing: -14) {
                    if let cards = me.cards {
                        ForEach(cards, id: \.self) { QipaiCardFace(id: $0, width: 62) }
                    } else {
                        ForEach(0..<me.handCount, id: \.self) { _ in QipaiCardBack(width: 62) }
                    }
                }
                .opacity(me.folded ? 0.4 : 1)
                actionBar(view, me: me)
            } else {
                QipaiWhisper(text: "觀戰中 · 誰的牌都看不見")
                    .padding(.bottom, 20)
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder private func actionBar(_ view: ZjhView, me: ZjhPlayerView) -> some View {
        let mine = view.phase == "betting" && view.current == view.you
        if mine {
            let bets = store.legal.filter { $0.type == "bet" }
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if store.legal.contains(where: { $0.type == "look" }) {
                        Button("看牌") { Task { await store.act(["type": "look"]) } }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                            .disabled(store.busy)
                    }
                    ForEach(bets) { move in
                        Button(betLabel(move)) {
                            Task { await store.act(["type": "bet", "amount": move.amount ?? 0]) }
                        }
                        .buttonStyle(QipaiEmbossedButtonStyle(prominent: move.kind == "call"))
                        .disabled(store.busy)
                    }
                }
                HStack(spacing: 8) {
                    Button("棄牌") { Task { await store.act(["type": "fold"]) } }
                        .buttonStyle(QipaiEmbossedButtonStyle())
                        .disabled(store.busy)
                    if store.legal.contains(where: { $0.type == "compare" }) {
                        Button("比牌") { showCompare = true }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                            .disabled(store.busy)
                    }
                }
            }
            .confirmationDialog("跟誰比牌？（要先付當前注）", isPresented: $showCompare, titleVisibility: .visible) {
                ForEach(store.legal.filter { $0.type == "compare" }) { move in
                    Button(move.targetName ?? move.target ?? "?") {
                        Task { await store.act(["type": "compare", "target": move.target ?? ""]) }
                    }
                }
                Button("算了", role: .cancel) {}
            }
        } else if view.phase == "betting" {
            QipaiWhisper(text: "等 \(view.player(view.current)?.name ?? "…") 行動…")
        }
    }

    private func betLabel(_ move: QipaiLegalMove) -> String {
        let amount = move.amount ?? 0
        switch move.kind {
        case "call": return (move.blind == true ? "悶跟 " : "跟注 ") + "\(amount)"
        case "allin": return "全押 \(amount)"
        case "raise_allin": return "加到全押 \(amount)"
        default: return (move.blind == true ? "悶加 " : "加注 ") + "\(amount)"
        }
    }

    // MARK: 结算盖板

    @ViewBuilder private var overlays: some View {
        if let view = store.view, view.phase == "round_over" || view.phase == "game_over" {
            resultOverlay(view)
        }
    }

    private func resultOverlay(_ view: ZjhView) -> some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                if view.phase == "round_over", let results = view.lastResults {
                    Text(results.winners.count == 1
                         ? "\(results.winners[0].name) 收池"
                         : "平分池底")
                        .font(.qipaiDisplay(26))
                        .foregroundColor(QipaiPalette.ink)
                    QipaiChip(text: "池底 \(results.pot)", tone: .live)
                    VStack(spacing: 6) {
                        ForEach(results.reveal) { r in
                            HStack(spacing: 6) {
                                Text(r.name).font(.system(size: 12, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink)
                                    .frame(width: 64, alignment: .leading)
                                HStack(spacing: -8) {
                                    ForEach(r.cards, id: \.self) { QipaiCardFace(id: $0, width: 24) }
                                }
                                Spacer()
                                Text(r.label).font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(QipaiPalette.red)
                            }
                        }
                        ForEach(results.winners) { w in
                            HStack {
                                Text(w.name).font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(QipaiPalette.ink)
                                Spacer()
                                Text("+\(w.gain)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(QipaiPalette.accent)
                                Text("現有 \(w.chips)")
                                    .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                } else {
                    Text("收盤")
                        .font(.qipaiDisplay(28))
                        .foregroundColor(QipaiPalette.ink)
                    VStack(spacing: 6) {
                        ForEach(view.players.sorted { $0.chips > $1.chips }) { p in
                            HStack {
                                Text(p.name).font(.system(size: 13, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink)
                                Spacer()
                                Text("籌碼 \(p.chips)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(QipaiPalette.ink)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }

                if view.phase == "round_over" {
                    HStack(spacing: 10) {
                        if store.mySeat != nil {
                            Button("再來一局") { Task { await store.nextRound() } }
                                .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                                .disabled(store.busy)
                        }
                        if store.isHost {
                            Button("收盤") { Task { await store.endMatch() } }
                                .buttonStyle(QipaiEmbossedButtonStyle())
                                .disabled(store.busy)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        Button("回大廳") { onExit() }
                            .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                        if store.isHost {
                            Button("關房") {
                                Task { await store.closeRoom(); onExit() }
                            }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                        }
                    }
                }
                QipaiWhisper(text: "no real money. only face.")
            }
            .padding(20)
            .frame(maxWidth: 330)
            .qipaiPanel(corner: 22, dotted: true)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.32).ignoresSafeArea())
    }

    // MARK: 玩法说明

    @ViewBuilder private var helpContent: some View {
        Text("炸金花 · 玩法")
            .font(.qipaiMemo(18))
            .foregroundColor(QipaiPalette.ink)
        Group {
            Text("52 張無王，每人 3 張。輪流行動：看牌、跟注、加注、棄牌，或者付當前注跟人比牌，輸的一方棄局。")
            Text("悶牌（不看牌）下注只要一半。牌力：豹子 > 順金 > 金花 > 順子 > 對子 > 散牌，A23 算最小順。")
            Text("只剩一個人沒棄牌，或比到只剩一人，他收走整個池底。籌碼不夠底注的人本局輪空。")
        }
        .font(.system(size: 12.5))
        .foregroundColor(QipaiPalette.ink.opacity(0.85))
        .lineSpacing(4)
    }
}
