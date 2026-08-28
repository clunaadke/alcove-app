import SwiftUI

// UNO 牌桌：弃牌堆顶牌、方向指示、+2 叠加、万能牌选色、摸牌出/留。

struct QipaiUnoTableView: View {
    let code: String
    var onExit: () -> Void

    @StateObject private var store: QipaiTableStore<UnoView>
    // 0828 她要的斗地主式两段出牌：点牌只抬起选中，出牌键**常驻**在操作条上——
    // 原来一点就飞，「没有返回时机」。万能牌同样走出牌键，按了之后才出四色（防手滑）。
    @State private var selected: String?
    @State private var wildPicking: String?   // 按了出牌的万能牌，等选色

    init(code: String, onExit: @escaping () -> Void) {
        self.code = code
        self.onExit = onExit
        _store = StateObject(wrappedValue: QipaiTableStore(code: code))
    }

    var body: some View {
        ZStack {
            QipaiTableShell(store: store, fallbackTitle: "UNO",
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
        // 局面翻页（别人出了牌/换局）选中就作废，免得出牌键出一张已经不在手里的牌
        .onChange(of: (store.view?.seq ?? 0)) { _ in
            let hand = store.view?.me?.hand ?? []
            if let s = selected, !hand.contains(s) { selected = nil }
            if let w = wildPicking, !hand.contains(w) { wildPicking = nil }
        }
    }

    // MARK: 牌桌

    private func table(_ view: UnoView) -> some View {
        VStack(spacing: 8) {
            opponentsRow(view)
            centerBoard(view)
            QipaiFeedStrip(store: store)
            myArea(view)
        }
        .padding(.horizontal, 12)
    }

    private func opponents(_ view: UnoView) -> [UnoPlayerView] {
        guard let you = view.you,
              let idx = view.turnOrder.firstIndex(of: you) else {
            return view.players.filter { $0.id != view.you }
        }
        let order = view.turnOrder
        var out: [UnoPlayerView] = []
        for step in 1..<order.count {
            if let p = view.player(order[(idx + step) % order.count]) { out.append(p) }
        }
        return out
    }

    private func opponentsRow(_ view: UnoView) -> some View {
        HStack(spacing: 8) {
            ForEach(opponents(view)) { p in
                seatCard(p, view: view)
            }
        }
    }

    private func seatCard(_ p: UnoPlayerView, view: UnoView) -> some View {
        VStack(spacing: 4) {
            QipaiHalo(active: view.current == p.id)
            HStack(spacing: 4) {
                if p.isAI {
                    Image(systemName: "sparkles").font(.system(size: 9))
                        .foregroundColor(QipaiPalette.accent)
                }
                Text(p.name).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(QipaiPalette.ink).lineLimit(1)
            }
            HStack(spacing: 5) {
                Text("\(p.handCount)")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(QipaiPalette.ink)
                Text("张").font(.system(size: 9.5)).foregroundColor(QipaiPalette.inkDim)
                if p.uno { QipaiChip(text: "UNO!", tone: .red) }
            }
            Text("累计 \(p.score) 分")
                .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 4)
        .qipaiPanel(corner: 15)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(QipaiPalette.glowRing, lineWidth: view.current == p.id ? 1.6 : 0))
    }

    // MARK: 场中央

    private func centerBoard(_ view: UnoView) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 14) {
                VStack(spacing: 3) {
                    QipaiCardBack(width: 40)
                    Text("牌库 \(view.deckCount)")
                        .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
                }
                if let top = view.top {
                    VStack(spacing: 3) {
                        UnoCardFace(id: top, width: 52)
                        Text(view.topLabel ?? "")
                            .font(.system(size: 9)).foregroundColor(QipaiPalette.inkDim)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    if let colorName = view.activeColorName {
                        HStack(spacing: 4) {
                            Circle().fill(UnoCard.tint(view.activeColor)).frame(width: 10, height: 10)
                            Text("当前色 \(colorName)")
                                .font(.system(size: 10.5)).foregroundColor(QipaiPalette.ink)
                        }
                    }
                    if let dir = view.dirLabel {
                        Text("方向 \(dir)")
                            .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                    }
                    if view.drawStack > 0 {
                        QipaiChip(text: "叠了 +\(view.drawStack)", tone: .red, icon: "flame")
                    }
                }
            }
            if view.phase == "playing" {
                Text("轮到 \(view.player(view.current)?.name ?? "…")\(view.current == view.you ? "（你）" : "")")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(view.current == view.you ? QipaiPalette.red : QipaiPalette.ink)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(10)
        .qipaiPanel(corner: 17, dotted: true)
    }

    // MARK: 事件流

    // MARK: 我的手牌与操作

    private func myArea(_ view: UnoView) -> some View {
        VStack(spacing: 8) {
            if let me = view.me {
                HStack(spacing: 6) {
                    QipaiHalo(active: view.current == me.id)
                    Text("你的手牌 \(me.handCount) 张 · 累计 \(me.score) 分")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(QipaiPalette.inkDim)
                    Spacer()
                    if me.uno { QipaiChip(text: "UNO!", tone: .red) }
                }
                handFan(me, view: view)
                actionBar(view)
            } else {
                Text("观战中 · 谁的手牌都看不见").font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                    .padding(.bottom, 20)
            }
        }
        .padding(.bottom, 10)
    }

    /// 这张牌现在能不能出（合法招里有它就能）
    private func playable(_ id: String) -> Bool {
        store.legal.contains { $0.type == "play" && $0.card == id }
    }

    private func handFan(_ me: UnoPlayerView, view: UnoView) -> some View {
        let mine = view.current == view.you && view.pending == nil
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -16) {
                ForEach(me.hand ?? [], id: \.self) { id in
                    UnoCardFace(id: id, width: 52)
                        .opacity(mine && !playable(id) ? 0.45 : 1)
                        .offset(y: selected == id ? -14 : 0)
                        .onTapGesture {
                            guard mine, playable(id) else { return }
                            // 再点一下取消，跟斗地主一个手感
                            selected = (selected == id) ? nil : id
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.75),
                                   value: selected == id)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 4)
        }
    }

    /// 出一张牌（万能牌带上选的色），出完清状态
    private func play(_ id: String, color: String? = nil) {
        selected = nil
        wildPicking = nil
        var body: [String: Any] = ["type": "play", "card": id]
        if let color { body["color"] = color }
        Task { await store.act(body) }
    }

    /// 按下出牌/出它之后才出现的选色排（第二步，防手滑）
    private func wildColorRow(_ id: String) -> some View {
        HStack(spacing: 6) {
            ForEach(["R", "G", "B", "Y"], id: \.self) { key in
                Button {
                    play(id, color: key)
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(UnoCard.tint(key)).frame(width: 9, height: 9)
                        Text("变\(UnoCard.colorName(key))")
                    }
                }
                .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                .disabled(store.busy)
            }
            Button("算了") { wildPicking = nil }
                .buttonStyle(QipaiEmbossedButtonStyle())
        }
    }

    @ViewBuilder private func actionBar(_ view: UnoView) -> some View {
        let mine = view.phase == "playing" && view.current == view.you
        if mine {
            if let wp = wildPicking {
                // 第二步选色：能走到这儿一定是自己刚按了出牌/出它，不存在手滑
                wildColorRow(wp)
            } else if let pending = view.pending, pending.mine {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("刚摸到")
                            .font(.system(size: 11.5)).foregroundColor(QipaiPalette.inkDim)
                        if let card = pending.card { UnoCardFace(id: card, width: 34) }
                    }
                    HStack(spacing: 10) {
                        if let card = pending.card,
                           store.legal.contains(where: { $0.type == "play" && $0.card == card }) {
                            Button("出它") {
                                if UnoCard.parse(card).isWild { wildPicking = card } else { play(card) }
                            }
                            .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                            .disabled(store.busy)
                        }
                        Button("留下") { Task { await store.act(["type": "keep"]) } }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                            .disabled(store.busy)
                    }
                }
            } else {
                // 0828 她定的手感：摸牌和出牌两个键**常驻**，出牌没选中就灰着。
                // 抬起一张 → 按出牌才飞；万能牌按出牌后再选色。
                HStack(spacing: 10) {
                    if let draw = store.legal.first(where: { $0.type == "draw" }) {
                        Button((draw.count ?? 0) > 0 ? "认吃 \(draw.count ?? 0) 张" : "摸一张") {
                            selected = nil
                            Task { await store.act(["type": "draw"]) }
                        }
                        .buttonStyle(QipaiEmbossedButtonStyle(
                            prominent: !store.legal.contains { $0.type == "play" }))
                        .disabled(store.busy)
                    }
                    Button("出牌") {
                        guard let sel = selected else { return }
                        if UnoCard.parse(sel).isWild { wildPicking = sel } else { play(sel) }
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                    .disabled(selected == nil || store.busy)
                }
            }
        } else if view.phase == "playing" {
            Text("等 \(view.player(view.current)?.name ?? "…") 出牌…").font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
        }
    }

    // MARK: 结算盖板

    @ViewBuilder private var overlays: some View {
        if let view = store.view, view.phase == "round_over" || view.phase == "game_over" {
            resultOverlay(view)
        }
    }

    private func resultOverlay(_ view: UnoView) -> some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                if view.phase == "round_over", let results = view.lastResults {
                    Text("\(view.player(results.winner)?.name ?? "?") 先出完")
                        .font(.qipaiDisplay(26))
                        .foregroundColor(QipaiPalette.ink)
                    QipaiChip(text: "这局进账 \(results.gain) 分", tone: .live)
                    VStack(spacing: 6) {
                        ForEach(results.players) { r in
                            HStack {
                                Text(r.name).font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink)
                                Spacer()
                                if r.playerId == results.winner {
                                    Text("+\(r.gain)")
                                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(QipaiPalette.accent)
                                } else {
                                    Text("剩 \(r.handCount) 张 · \(r.handPoints) 分")
                                        .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                                }
                                Text("累计 \(r.score)")
                                    .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                } else {
                    Text("收盤")
                        .font(.qipaiDisplay(28))
                        .foregroundColor(QipaiPalette.ink)
                    if let winner = view.player(view.winner) {
                        Text("\(winner.name) 是最后的大赢家")
                            .font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
                    }
                    VStack(spacing: 6) {
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
                    .padding(.horizontal, 6)
                }

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
                QipaiWhisper(text: "+4 is not a personal attack. probably.")
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
        Text("UNO · 玩法")
            .font(.qipaiMemo(18))
            .foregroundColor(QipaiPalette.ink)
        Group {
            Text("每人 7 张。跟弃牌堆顶的牌同色或同字就能出；万能牌随时能出、出时选色。")
            Text("跳过、反转、+2 各有各的坏；万能+4 让下家吃四张。摸一张之后能出可以立刻出，也可以留着。")
            Text("一人出完这局结束，按对手剩的手牌计分（数字面值、功能牌 20、万能 50），累计到总分。")
            Text("剩一张牌会自动喊 UNO，不罚。")
        }
        .font(.system(size: 12.5))
        .foregroundColor(QipaiPalette.ink.opacity(0.85))
        .lineSpacing(4)
    }
}

// MARK: - UNO 牌面

struct UnoCardFace: View {
    let id: String
    var width: CGFloat = 48

    var body: some View {
        let face = UnoCard.parse(id)
        let tint = UnoCard.tint(face.colorKey)
        return ZStack {
            RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
                .fill(face.isWild
                      ? LinearGradient(colors: [QipaiPalette.qhex(0x5A6170), QipaiPalette.qhex(0x3E4553)],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [tint.opacity(0.92), tint],
                                       startPoint: .top, endPoint: .bottom))
            Ellipse()
                .fill(.white.opacity(face.isWild ? 0.14 : 0.85))
                .frame(width: width * 0.78, height: width * 1.06)
                .rotationEffect(.degrees(24))
            Text(face.symbol)
                .font(.system(size: width * 0.4, weight: .heavy, design: .rounded))
                .foregroundColor(face.isWild ? .white : tint)
            if face.isWild {
                VStack {
                    Spacer()
                    HStack(spacing: 2.5) {
                        ForEach(["R", "G", "B", "Y"], id: \.self) { key in
                            Circle().fill(UnoCard.tint(key))
                                .frame(width: width * 0.1, height: width * 0.1)
                        }
                    }
                    .padding(.bottom, width * 0.1)
                }
            }
            VStack {
                HStack {
                    Text(face.symbol)
                        .font(.system(size: width * 0.16, weight: .bold, design: .rounded))
                        .foregroundColor(face.isWild ? .white : .white.opacity(0.9))
                        .padding(.leading, width * 0.09).padding(.top, width * 0.06)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(width: width, height: width * 1.42)
        .overlay(RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
            .strokeBorder(.white.opacity(0.85), lineWidth: 1.4)
            .padding(1))
        .overlay(RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
            .stroke(QipaiPalette.line, lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                 startPoint: .top, endPoint: .center))
            .allowsHitTesting(false))
        .shadow(color: QipaiPalette.shadowTint.opacity(0.16), radius: 2.5, y: 1.5)
    }
}
