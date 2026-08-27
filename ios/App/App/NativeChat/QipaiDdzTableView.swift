import SwiftUI
import UIKit

// 斗地主牌桌。古早味：雾灰蓝桌面 + 噪点，白瓷牌，轮到谁谁头上亮光环。

struct QipaiDdzTableView: View {
    let code: String
    var onExit: () -> Void

    @StateObject private var store: QipaiTableStore
    @State private var selected: Set<String> = []
    @State private var showChat = false
    @State private var showHelp = false
    @State private var chatDraft = ""
    @State private var inviteCopied = false

    init(code: String, onExit: @escaping () -> Void) {
        self.code = code
        self.onExit = onExit
        _store = StateObject(wrappedValue: QipaiTableStore(code: code))
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                if let frame = store.frame {
                    if !frame.started {
                        waitingRoom(frame)
                    } else if let view = store.view {
                        table(frame, view)
                    } else {
                        ProgressView().frame(maxHeight: .infinity)
                    }
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            overlays
            toast
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
        .onChange(of: store.frame?.closed ?? false) { closed in
            if closed { onExit() }
        }
        .onChange(of: store.view?.seq ?? 0) { _ in
            // 每次出牌后清掉已经不在手里的选中牌
            let hand = Set(store.view?.me?.hand ?? [])
            selected = selected.intersection(hand)
        }
        .sheet(isPresented: $showChat) { chatSheet }
        .sheet(isPresented: $showHelp) { helpSheet }
    }

    // MARK: 背景与顶栏

    private var background: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            Image("QipaiWallPortrait2")
                .resizable().scaledToFill().ignoresSafeArea().opacity(0.45)
            QipaiPalette.fog.opacity(0.55).ignoresSafeArea()
            QipaiDots(spacing: 18, radius: 1.2, opacity: 0.16).ignoresSafeArea()
        }
        .qipaiGrain(0.5)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { onExit() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())

            VStack(alignment: .leading, spacing: 1) {
                Text(store.frame.map { $0.name.isEmpty ? $0.gameName : $0.name } ?? "斗地主")
                    .font(.system(size: 14.5, weight: .bold, design: .serif))
                    .foregroundColor(QipaiPalette.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(code).font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(QipaiPalette.inkDim)
                    if let round = store.view?.round {
                        Text("第 \(round) 局").font(.system(size: 9.5))
                            .foregroundColor(QipaiPalette.inkDim)
                    }
                }
            }
            Spacer()
            Circle()
                .fill(store.connected ? QipaiPalette.accent : QipaiPalette.red)
                .frame(width: 7, height: 7)
            Text(store.connected ? "已连接" : "重连中")
                .font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
            Button { showChat = true } label: {
                Image(systemName: "bubble.left").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())
            Button { showHelp = true } label: {
                Image(systemName: "questionmark").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(QipaiEmbossedButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: 等人开局

    private func waitingRoom(_ frame: QipaiTableFrame) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("等人上桌")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(QipaiPalette.ink)
            Text("\(frame.seats.count)/\(frame.maxPlayers) 人 · 房号 \(frame.code)")
                .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
            VStack(spacing: 8) {
                ForEach(frame.seats) { seat in
                    HStack(spacing: 8) {
                        Image(systemName: seat.isAI ? "sparkles" : "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(QipaiPalette.accent)
                        Text(seat.name).font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(QipaiPalette.ink)
                        if seat.isHost { QipaiChip(text: "房主", tone: .live) }
                        Spacer()
                    }
                    .padding(11)
                    .qipaiPanel(corner: 13)
                }
            }
            .padding(.horizontal, 30)

            if let invite = frame.inviteToken {
                Button {
                    UIPasteboard.general.string = QipaiAPI.inviteLink(code: frame.code, inviteToken: invite)
                    inviteCopied = true
                } label: {
                    Label(inviteCopied ? "邀请链接已复制" : "复制邀请链接",
                          systemImage: inviteCopied ? "checkmark" : "link")
                }
                .buttonStyle(QipaiEmbossedButtonStyle())
            }

            Spacer()
            if store.isHost {
                if frame.seats.count >= frame.minPlayers {
                    QipaiSlideControl(label: "slide to 开局") { Task { await store.startGame() } }
                        .padding(.horizontal, 34)
                } else {
                    QipaiWhisper(text: "人齐了才能开。喊人，或者回大厅拉 AI。")
                }
            } else {
                QipaiWhisper(text: "等房主开局…")
            }
            Spacer().frame(height: 30)
        }
    }

    // MARK: 牌桌

    private func table(_ frame: QipaiTableFrame, _ view: DdzView) -> some View {
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
                Text("张").font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
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
            QipaiChip(text: p.isLandlord ? "地主" : "农民",
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
        if p.passed { return "过" }
        return " "
    }

    // MARK: 场中央

    private func centerBoard(_ view: DdzView) -> some View {
        VStack(spacing: 8) {
            // 状态行：底分 · 倍数 · 炸弹
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

            // 主区
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

    @ViewBuilder private func banner(_ view: DdzView) -> some View {
        switch view.phase {
        case "bidding":
            VStack(spacing: 3) {
                Text("叫分中 · 轮到 \(name(view.current, view))")
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
            Text("轮到 \(name(view.current, view))\(view.current == view.you ? "（你）" : "")")
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
                    Text("你的手牌 \(me.handCount) 张")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(QipaiPalette.inkDim)
                    if view.landlord != nil {
                        QipaiChip(text: me.isLandlord ? "地主" : "农民",
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
                QipaiWhisper(text: "观战中 · 谁的手牌都看不见")
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

    // MARK: 局间/终局盖板 + toast

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
                    Text(view.roundWinner == "landlord" ? "地主胜" : "农民胜")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(QipaiPalette.ink)
                    if view.spring { QipaiChip(text: "春天 ×2", tone: .red) }
                    if view.antiSpring { QipaiChip(text: "反春 ×2", tone: .red) }
                } else {
                    Text("收盘")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(QipaiPalette.ink)
                    if let winner = view.player(view.winner) {
                        Text("\(winner.name) 是最后的大赢家")
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
                            Button("再来一局") { Task { await store.nextRound() } }
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
        .background(QipaiPalette.ink.opacity(0.25).ignoresSafeArea())
    }

    @ViewBuilder private var toast: some View {
        if let text = store.toast {
            VStack {
                Spacer()
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(QipaiPalette.ink.opacity(0.92)))
                    .padding(.bottom, 130)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: store.toast)
            .allowsHitTesting(false)
        }
    }

    // MARK: 聊天

    private var chatSheet: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            QipaiDots(spacing: 16, radius: 1.3, opacity: 0.25).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("牌桌闲聊")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(QipaiPalette.ink)
                    .padding(.top, 16)
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.frame?.chat ?? []) { msg in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(msg.name)
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundColor(QipaiPalette.accent)
                                    Text(msg.text)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(QipaiPalette.ink)
                                        .padding(.horizontal, 11).padding(.vertical, 7)
                                        .background(RoundedRectangle(cornerRadius: 13)
                                            .fill(.white.opacity(0.85)))
                                        .overlay(RoundedRectangle(cornerRadius: 13)
                                            .stroke(QipaiPalette.line, lineWidth: 0.8))
                                }
                                .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: store.frame?.chat.count ?? 0) { _ in
                        if let last = store.frame?.chat.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = store.frame?.chat.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                HStack(spacing: 8) {
                    TextField("说点什么…", text: $chatDraft)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Capsule().fill(.white.opacity(0.9)))
                        .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 1))
                    Button {
                        let text = chatDraft
                        chatDraft = ""
                        Task { await store.sendChat(text) }
                    } label: {
                        Image(systemName: "paperplane.fill").font(.system(size: 13))
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(chatDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .qipaiGrain(0.4)
        .presentationDetents([.medium, .large])
    }

    // MARK: 玩法说明

    private var helpSheet: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("斗地主 · 玩法")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(QipaiPalette.ink)
                    Group {
                        Text("三个人，17×3 张牌加 3 张底牌。先叫分（1/2/3 分，也可以不叫），叫得最高的当地主、拿底牌，一打二。")
                        Text("牌型：单张、对子、三条（可带一/带对）、顺子（5 张起）、连对（3 对起）、飞机（±翅膀）、四带二、炸弹、王炸。2 不能进顺子。")
                        Text("炸弹王炸砸一切，每响一次倍数 ×2。地主一张没让农民出叫春天，反过来叫反春，都再 ×2。")
                        Text("计分：底分 × 倍数。地主赢收两家，输赔两家。")
                        Text("选牌点一下抬起来，再点放回去。出不了的牌服务器会拦，放心乱试。")
                    }
                    .font(.system(size: 12.5))
                    .foregroundColor(QipaiPalette.ink.opacity(0.85))
                    .lineSpacing(4)
                    QipaiWhisper(text: "no real money. only face.")
                }
                .padding(20)
            }
        }
        .qipaiGrain(0.4)
        .presentationDetents([.medium])
    }
}

// MARK: - 一张牌

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
        .shadow(color: QipaiPalette.ink.opacity(0.14), radius: 2.5, y: 1.5)
    }
}
