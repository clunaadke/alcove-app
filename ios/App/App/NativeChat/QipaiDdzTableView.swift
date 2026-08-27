import SwiftUI
import UIKit

// 斗地主牌桌。外壳（顶栏/等人/聊天/toast）在 QipaiTableShell，这里只画开局后的桌面。

struct QipaiDdzTableView: View {
    let code: String
    var onExit: () -> Void

    @StateObject private var store: QipaiTableStore<DdzView>
    @State private var selected: Set<String> = []

    init(code: String, onExit: @escaping () -> Void) {
        self.code = code
        self.onExit = onExit
        _store = StateObject(wrappedValue: QipaiTableStore(code: code))
    }

    var body: some View {
        ZStack {
            QipaiTableShell(store: store, fallbackTitle: "斗地主",
                            round: store.view?.round, onExit: onExit) {
                if let frame = store.frame, let view = store.view {
                    table(frame, view)
                }
            } help: {
                helpContent
            }
            overlays
        }
        .onChange(of: (store.view?.seq ?? 0)) { _ in
            // 每次出牌后清掉已经不在手里的选中牌
            let hand = Set(store.view?.me?.hand ?? [])
            selected = selected.intersection(hand)
        }
    }

    // MARK: 牌桌

    private func table(_ frame: QipaiTableFrame<DdzView>, _ view: DdzView) -> some View {
        VStack(spacing: 8) {
            opponentsRow(view)
            centerBoard(view)
            logStrip(view)
            Spacer(minLength: 4)
            handArea(view)
        }
        .padding(.horizontal, 12)
    }

    /// 对手按出牌顺序排：我的下家在右、上家在左
    private func opponents(_ view: DdzView) -> [DdzPlayerView] {
        guard let you = view.you,
              let idx = view.turnOrder.firstIndex(of: you) else {
            return view.players.filter { $0.id != view.you }
        }
        let order = view.turnOrder
        let next = order[(idx + 1) % order.count]
        let prev = order[(idx + 2) % order.count]
        return [prev, next].compactMap { view.player($0) }   // [左·上家, 右·下家]
    }

    private func opponentsRow(_ view: DdzView) -> some View {
        HStack(spacing: 10) {
            ForEach(opponents(view)) { p in
                seatCard(p, view: view)
            }
        }
    }

    private func seatCard(_ p: DdzPlayerView, view: DdzView) -> some View {
        VStack(spacing: 4) {
            QipaiHalo(active: view.current == p.id)
            HStack(spacing: 4) {
                if p.isAI {
                    Image(systemName: "sparkles").font(.system(size: 9))
                        .foregroundColor(QipaiPalette.accent)
                }
                Text(p.name).font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(QipaiPalette.ink).lineLimit(1)
            }
            HStack(spacing: 5) {
                Text("\(p.handCount)")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(QipaiPalette.ink)
                Text("張").font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
                roleBadge(p, view: view)
            }
            Text(statusLine(p, view: view))
                .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 6)
        .qipaiPanel(corner: 15)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(QipaiPalette.glowRing, lineWidth: view.current == p.id ? 1.6 : 0))
    }

    @ViewBuilder private func roleBadge(_ p: DdzPlayerView, view: DdzView) -> some View {
        if view.landlord != nil {
            QipaiChip(text: p.isLandlord ? "地主" : "農民",
                      tone: p.isLandlord ? .red : .neutral)
        } else if let bid = p.bid {
            QipaiChip(text: bid == 0 ? "不叫" : "\(bid) 分", tone: .neutral)
        }
    }

    private func statusLine(_ p: DdzPlayerView, view: DdzView) -> String {
        if view.phase == "bidding" {
            return view.current == p.id ? (p.isAI ? "思考中…" : "叫分中…") : " "
        }
        if view.current == p.id { return p.isAI ? "思考中…" : "出牌中…" }
        if p.passed { return "過" }
        return " "
    }

    // MARK: 场中央

    private func centerBoard(_ view: DdzView) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if let base = view.base { QipaiChip(text: "底分 \(base)") }
                QipaiChip(text: "×\(view.multiplier)",
                          tone: view.multiplier > 1 ? .red : .neutral,
                          icon: view.bombs > 0 ? "flame" : nil)
                if view.spring { QipaiChip(text: "春天", tone: .red) }
                if view.antiSpring { QipaiChip(text: "反春", tone: .red) }
                Spacer()
                if let bottom = view.bottomCards {
                    HStack(spacing: 2) {
                        ForEach(bottom, id: \.self) { id in
                            QipaiCardFace(id: id, width: 22)
                        }
                    }
                    QipaiWhisper(text: "底牌")
                }
            }

            VStack(spacing: 7) {
                banner(view)
                if let field = view.field {
                    HStack(spacing: -14) {
                        ForEach(field.cards, id: \.self) { id in
                            QipaiCardFace(id: id, width: 42)
                        }
                    }
                    Text("\(view.player(field.by)?.name ?? "?") 出的 · \(QipaiCard.comboLabels[field.combo.type] ?? field.combo.type)")
                        .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                } else if view.phase == "playing" {
                    Text("場上空著，\(view.player(view.leader)?.name ?? "…") 領出")
                        .font(.system(size: 11.5)).foregroundColor(QipaiPalette.inkDim)
                        .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 118)
            .padding(10)
            .qipaiPanel(corner: 17, dotted: true)
        }
    }

    @ViewBuilder private func banner(_ view: DdzView) -> some View {
        switch view.phase {
        case "bidding":
            VStack(spacing: 3) {
                Text("叫分中 · 輪到 \(name(view.current, view))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(QipaiPalette.ink)
                if !view.bids.isEmpty {
                    Text(view.bids.map {
                        "\(name($0.playerId, view)) \($0.value == 0 ? "不叫" : "\($0.value) 分")"
                    }.joined(separator: "，"))
                    .font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
                }
            }
        case "playing":
            Text("輪到 \(name(view.current, view))\(view.current == view.you ? "（你）" : "")")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(view.current == view.you ? QipaiPalette.red : QipaiPalette.ink)
        default:
            EmptyView()
        }
    }

    private func name(_ id: String?, _ view: DdzView) -> String {
        view.player(id)?.name ?? "…"
    }

    // MARK: 事件流

    private func logStrip(_ view: DdzView) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(view.log.suffix(30)) { entry in
                        Text(entry.text)
                            .font(.system(size: 10))
                            .foregroundColor(entry.type == "bomb" || entry.type == "finish"
                                             ? QipaiPalette.red : QipaiPalette.inkDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(entry.seq)
                    }
                }
                .padding(8)
            }
            .frame(height: 74)
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

    // MARK: 手牌与操作

    private func handArea(_ view: DdzView) -> some View {
        VStack(spacing: 8) {
            if let me = view.me {
                HStack(spacing: 6) {
                    QipaiHalo(active: view.current == me.id)
                    Text("你的手牌 \(me.handCount) 張")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(QipaiPalette.inkDim)
                    if view.landlord != nil {
                        QipaiChip(text: me.isLandlord ? "地主" : "農民",
                                  tone: me.isLandlord ? .red : .neutral,
                                  icon: me.isLandlord ? "crown" : nil)
                    }
                    Spacer()
                    if !selected.isEmpty {
                        Button("清空") { selected = [] }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                    }
                }
                handFan(me)
                actionBar(view)
            } else {
                QipaiWhisper(text: "觀戰中 · 誰的手牌都看不見")
                    .padding(.bottom, 20)
            }
        }
        .padding(.bottom, 10)
    }

    private func handFan(_ me: DdzPlayerView) -> some View {
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

    @ViewBuilder private func actionBar(_ view: DdzView) -> some View {
        let mine = view.current == view.you
        switch view.phase {
        case "bidding":
            if mine {
                HStack(spacing: 8) {
                    ForEach(store.legal.filter { $0.type == "bid" }
                        .sorted { ($0.value ?? 0) < ($1.value ?? 0) }) { move in
                        Button((move.value ?? 0) == 0 ? "不叫" : "\(move.value ?? 0) 分") {
                            Task { await store.bid(move.value ?? 0) }
                        }
                        .buttonStyle(QipaiEmbossedButtonStyle(prominent: (move.value ?? 0) == 3))
                        .disabled(store.busy)
                    }
                }
            } else {
                QipaiWhisper(text: "等 \(name(view.current, view)) 叫分…")
            }
        case "playing":
            if mine {
                HStack(spacing: 10) {
                    if store.legal.contains(where: { $0.type == "pass" }) {
                        Button("不要") { Task { await store.pass() } }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                            .disabled(store.busy)
                    }
                    Button("出牌") {
                        Task { await store.play(Array(selected)) }
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(selected.isEmpty || store.busy)
                }
            } else {
                QipaiWhisper(text: "等 \(name(view.current, view)) 出牌…")
            }
        default:
            EmptyView()
        }
    }

    // MARK: 局间/终局盖板

    @ViewBuilder private var overlays: some View {
        if let view = store.view, view.phase == "round_over" || view.phase == "game_over" {
            resultOverlay(view)
        }
    }

    private func resultOverlay(_ view: DdzView) -> some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                if view.phase == "round_over" {
                    Text(view.roundWinner == "landlord" ? "地主勝" : "農民勝")
                        .font(.qipaiDisplay(28))
                        .foregroundColor(QipaiPalette.ink)
                    if view.spring { QipaiChip(text: "春天 ×2", tone: .red) }
                    if view.antiSpring { QipaiChip(text: "反春 ×2", tone: .red) }
                } else {
                    Text("收盤")
                        .font(.qipaiDisplay(28))
                        .foregroundColor(QipaiPalette.ink)
                    if let winner = view.player(view.winner) {
                        Text("\(winner.name) 是最後的大贏家")
                            .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
                    }
                }

                VStack(spacing: 6) {
                    if view.phase == "round_over", let results = view.lastResults {
                        ForEach(results, id: \.identifier) { r in
                            HStack {
                                Text(r.name).font(.system(size: 13, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink)
                                Spacer()
                                Text(r.delta >= 0 ? "+\(r.delta)" : "\(r.delta)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(r.delta >= 0 ? QipaiPalette.accent : QipaiPalette.red)
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
        Text("斗地主 · 玩法")
            .font(.qipaiMemo(18))
            .foregroundColor(QipaiPalette.ink)
        Group {
            Text("三個人，17×3 張牌加 3 張底牌。先叫分（1/2/3 分，也可以不叫），叫得最高的當地主、拿底牌，一打二。")
            Text("牌型：單張、對子、三條（可帶一/帶對）、順子（5 張起）、連對（3 對起）、飛機（±翅膀）、四帶二、炸彈、王炸。2 不能進順子。")
            Text("炸彈王炸砸一切，每響一次倍數 ×2。地主一張沒讓農民出叫春天，反過來叫反春，都再 ×2。")
            Text("計分：底分 × 倍數。地主贏收兩家，輸賠兩家。")
            Text("選牌點一下抬起來，再點放回去。出不了的牌伺服器會攔，放心亂試。")
        }
        .font(.system(size: 12.5))
        .foregroundColor(QipaiPalette.ink.opacity(0.85))
        .lineSpacing(4)
    }
}

// MARK: - 一张牌（扑克，斗地主/炸金花共用）

struct QipaiCardFace: View {
    let id: String
    var width: CGFloat = 48

    var body: some View {
        let card = QipaiCard.parse(id)
        let color = card.isRed ? QipaiPalette.red : QipaiPalette.ink
        return VStack(spacing: 0) {
            if card.isJoker {
                Text(card.rank)
                    .font(.system(size: width * 0.26, weight: .bold))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: -2) {
                    Text(card.rank)
                        .font(.system(size: width * 0.36, weight: .bold, design: .rounded))
                    Text(card.glyph)
                        .font(.system(size: width * 0.3))
                }
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, width * 0.12)
                .padding(.top, width * 0.08)
                Spacer(minLength: 0)
                Text(card.glyph)
                    .font(.system(size: width * 0.34))
                    .foregroundColor(color.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, width * 0.1)
                    .padding(.bottom, width * 0.08)
            }
        }
        .frame(width: width, height: width * 1.38)
        .background(
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(LinearGradient(colors: [.white, QipaiPalette.qhex(0xF2F3F7)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
            .stroke(QipaiPalette.line, lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.55), .clear],
                                 startPoint: .top, endPoint: .center))
            .allowsHitTesting(false))
        .shadow(color: QipaiPalette.shadowTint.opacity(0.14), radius: 2.5, y: 1.5)
    }
}

// MARK: - 牌背（炸金花暗牌用）

struct QipaiCardBack: View {
    var width: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(LinearGradient(colors: [QipaiPalette.qhex(0xB9C1D2), QipaiPalette.qhex(0x9BA5BB)],
                                     startPoint: .top, endPoint: .bottom))
            QipaiDots(spacing: width * 0.18, radius: width * 0.028,
                      color: .white, opacity: 0.5)
                .clipShape(RoundedRectangle(cornerRadius: width * 0.14, style: .continuous))
            RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
                .padding(width * 0.07)
        }
        .frame(width: width, height: width * 1.38)
        .overlay(RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
            .stroke(QipaiPalette.line, lineWidth: 1))
        .shadow(color: QipaiPalette.shadowTint.opacity(0.14), radius: 2.5, y: 1.5)
    }
}
