import SwiftUI

// 战绩房（0829 她定的版式）：一个页面往下滑——
// 顶上计分板卡（五个游戏切换，总分制排行，带局数/胜/负/胜率），
// 下面历史房卡（卡上直接看游戏和胜者），点卡进详情（结果大卡置顶）。
// 全套白瓷波点，跟棋牌室一屋子一个味道。

struct QipaiHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [QipaiAPI.HistorySummary] = []
    @State private var board: [String: [QipaiAPI.LeaderboardRow]] = [:]
    @State private var boardGame = "ddz"
    @State private var loading = true
    @State private var errorText: String?
    @State private var record: QipaiAPI.HistoryRecord?
    @State private var loadingDetail = false

    /// 计分板的游戏标签（固定文案走繁体手写系，monopoly 在建灰着）
    private static let boardGames: [(key: String, name: String, ready: Bool)] = [
        ("ddz", "斗地主", true), ("zjh", "炸金花", true), ("uno", "UNO", true),
        ("daifugo", "大富豪", true), ("monopoly", "大富翁", true), ("mahjong", "麻将", true),
    ]

    var body: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            QipaiDots(spacing: 16, radius: 1.3, opacity: 0.28).ignoresSafeArea()
            VStack(spacing: 12) {
                header
                if let record {
                    detailView(record)
                } else {
                    listView
                }
            }
            .padding(16)
        }
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if record != nil {
                Button {
                    record = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(QipaiEmbossedButtonStyle())
            }
            Text("戰績")
                .font(.qipaiMemo(19))
                .foregroundColor(QipaiPalette.ink)
            QipaiWhisper(text: "old scores, still faces.")
            Spacer()
            Button("关上") { dismiss() }
                .buttonStyle(QipaiEmbossedButtonStyle())
        }
    }

    // MARK: 列表页（计分板 + 历史，一个滚动）

    @ViewBuilder private var listView: some View {
        if loading && items.isEmpty && board.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorText {
            VStack(spacing: 8) {
                Text(errorText).font(.system(size: 12)).foregroundColor(QipaiPalette.red)
                Button("再试一次") { Task { await reload() } }
                    .buttonStyle(QipaiEmbossedButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    scoreboard
                    sectionTitle("往局", note: "on the record")
                    if items.isEmpty {
                        VStack(spacing: 5) {
                            Text("还没有留档的牌局").font(.system(size: 12.5)).foregroundColor(QipaiPalette.inkDim)
                            QipaiWhisper(text: "play one, close it, it lands here.")
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(items) { item in row(item) }
                        }
                    }
                    QipaiWhisper(text: "no real money. only face.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
                .font(.qipaiMemo(16))
                .foregroundColor(QipaiPalette.ink)
            QipaiWhisper(text: note)
        }
    }

    // MARK: 计分板

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("計分板", note: "total points, no mercy.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.boardGames, id: \.key) { game in
                        Button {
                            boardGame = game.key
                        } label: {
                            Text(game.ready ? game.name : "\(game.name)·在建")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(boardGame == game.key ? .white :
                                                    (game.ready ? QipaiPalette.ink : QipaiPalette.inkDim))
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .background(Capsule().fill(boardGame == game.key
                                                           ? QipaiPalette.accent
                                                           : QipaiPalette.chipBg))
                                .overlay(Capsule().stroke(QipaiPalette.line, lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!game.ready)
                    }
                }
                .padding(.vertical, 2)
            }

            let rows = board[boardGame] ?? []
            if rows.isEmpty {
                VStack(spacing: 4) {
                    Text("这个游戏还没打完过一场").font(.system(size: 12)).foregroundColor(QipaiPalette.inkDim)
                    QipaiWhisper(text: "the board waits.")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        boardRow(rank: index + 1, row: row)
                        if index < rows.count - 1 {
                            Divider().overlay(QipaiPalette.line.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(14)
        .qipaiPanel(corner: 20, dotted: true)
    }

    private func boardRow(rank: Int, row: QipaiAPI.LeaderboardRow) -> some View {
        let champion = rank == 1
        let rate = row.games > 0 ? Int((Double(row.wins) / Double(row.games) * 100).rounded()) : 0
        return HStack(spacing: 10) {
            ZStack {
                if champion {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 15))
                        .foregroundColor(QipaiPalette.red)
                } else {
                    Text("\(rank)")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(QipaiPalette.inkDim)
                }
            }
            .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 13.5, weight: champion ? .bold : .medium))
                    .foregroundColor(champion ? QipaiPalette.red : QipaiPalette.ink)
                Text("\(row.games) 局 · 胜 \(row.wins) 负 \(row.losses)\((row.draws ?? 0) > 0 ? " 平 \(row.draws ?? 0)" : "") · 胜率 \(rate)%")
                    .font(.system(size: 9.5))
                    .foregroundColor(QipaiPalette.inkDim)
            }
            Spacer()
            Text(row.score > 0 ? "+\(row.score)" : "\(row.score)")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundColor(champion ? QipaiPalette.red : QipaiPalette.ink)
        }
        .padding(.vertical, 8)
    }

    // MARK: 历史房卡

    private func row(_ item: QipaiAPI.HistorySummary) -> some View {
        Button {
            Task { await openDetail(item) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name.isEmpty ? item.gameName : item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(QipaiPalette.ink)
                        .lineLimit(1)
                    Spacer()
                    if loadingDetail {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(QipaiPalette.inkDim)
                    }
                }
                // 胜者行：不点进去就知道谁赢了
                winnerLine(item)
                HStack(spacing: 6) {
                    QipaiChip(text: item.gameName, tone: .live)
                    if !item.finished { QipaiChip(text: "半途关的", tone: .done) }
                    if item.round > 0 {
                        Text("第 \(item.round) 轮")
                            .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                    }
                    Spacer()
                    Text(Self.dateText(item.closedAt))
                        .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                }
                HStack(spacing: 5) {
                    ForEach(item.players) { seat in
                        Text(seat.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(QipaiPalette.ink.opacity(0.85))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(QipaiPalette.panelDeep.opacity(0.8)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(13)
            .qipaiPanel(corner: 17)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func winnerLine(_ item: QipaiAPI.HistorySummary) -> some View {
        let winners = (item.results ?? []).filter { $0.winner }
        let isDraw = item.finished && (item.results ?? []).contains { $0.draw == true }
        if isDraw {
            HStack(spacing: 5) {
                Image(systemName: "equal.circle")
                    .font(.system(size: 11))
                    .foregroundColor(QipaiPalette.accent)
                Text("平局收场")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(QipaiPalette.accent)
            }
        } else if item.finished, !winners.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11))
                    .foregroundColor(QipaiPalette.red)
                Text(winners.map { "\($0.name) \($0.score > 0 ? "+\($0.score)" : "\($0.score)")" }
                    .joined(separator: "、"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(QipaiPalette.red)
            }
        } else if !item.finished {
            Text("没打完，不计分")
                .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
        }
    }

    // MARK: 详情页

    private func detailView(_ record: QipaiAPI.HistoryRecord) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                resultHero(record)

                VStack(alignment: .leading, spacing: 6) {
                    Text(record.name.isEmpty ? record.gameName : record.name)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(QipaiPalette.ink)
                    HStack(spacing: 6) {
                        QipaiChip(text: record.gameName, tone: .live)
                        if !record.finished { QipaiChip(text: "半途关的", tone: .done) }
                        Text("\(record.code) · \(Self.dateText(record.closedAt))")
                            .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .qipaiPanel(corner: 17)

                if let log = record.state?.log, !log.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("牌局回放")
                            .font(.qipaiMemo(14))
                            .foregroundColor(QipaiPalette.ink)
                        ForEach(log) { e in
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("›").font(.system(size: 10, weight: .bold))
                                    .foregroundColor(QipaiPalette.inkDim.opacity(0.6))
                                Text(e.text)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(QipaiPalette.inkDim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .qipaiPanel(corner: 17, dotted: true)
                }

                if let chat = record.chat, !chat.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("牌桌闲话")
                            .font(.qipaiMemo(14))
                            .foregroundColor(QipaiPalette.ink)
                        ForEach(chat) { m in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.name)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(QipaiPalette.accent)
                                Text(m.text)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(QipaiPalette.ink)
                            }
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .qipaiPanel(corner: 17)
                }
                QipaiWhisper(text: "no rematch for the past.")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
        }
    }

    /// 结果大卡：赢家大字置顶，每人一行得分，赢家红字带冠
    @ViewBuilder private func resultHero(_ record: QipaiAPI.HistoryRecord) -> some View {
        let results = record.results ?? []
        if !results.isEmpty {
            VStack(spacing: 10) {
                if record.finished && results.contains(where: { $0.draw == true }) {
                    Text("平局")
                        .font(.qipaiDisplay(26))
                        .foregroundColor(QipaiPalette.accent)
                } else if record.finished {
                    let winners = results.filter { $0.winner }.map(\.name).joined(separator: "、")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18))
                            .foregroundColor(QipaiPalette.red)
                        Text(winners)
                            .font(.system(size: 21, weight: .heavy))
                            .foregroundColor(QipaiPalette.red)
                        Text("勝")
                            .font(.qipaiDisplay(26))
                            .foregroundColor(QipaiPalette.red)
                    }
                } else {
                    Text("半途收档 · 不計分")
                        .font(.qipaiMemo(16))
                        .foregroundColor(QipaiPalette.inkDim)
                }
                VStack(spacing: 6) {
                    ForEach(results.sorted { $0.score > $1.score }, id: \.name) { r in
                        HStack(spacing: 7) {
                            if r.winner && record.finished {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10)).foregroundColor(QipaiPalette.red)
                            } else {
                                Color.clear.frame(width: 12, height: 1)
                            }
                            Text(r.name)
                                .font(.system(size: 13.5, weight: r.winner ? .bold : .medium))
                                .foregroundColor(r.winner && record.finished
                                                 ? QipaiPalette.red : QipaiPalette.ink.opacity(0.8))
                            Spacer()
                            Text(r.score > 0 ? "+\(r.score)" : "\(r.score)")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(r.winner && record.finished
                                                 ? QipaiPalette.red : QipaiPalette.inkDim)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .qipaiPanel(corner: 20, dotted: true)
        }
    }

    // MARK: 动作

    @MainActor private func reload() async {
        loading = true
        defer { loading = false }
        do {
            items = try await QipaiAPI.history()
            board = (try? await QipaiAPI.leaderboard()) ?? [:]
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor private func openDetail(_ item: QipaiAPI.HistorySummary) async {
        guard !loadingDetail else { return }
        loadingDetail = true
        defer { loadingDetail = false }
        do {
            record = try await QipaiAPI.historyDetail(
                id: item.id, service: QipaiAPI.service(for: item.game))
        } catch {
            errorText = error.localizedDescription
        }
    }

    private static func dateText(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d HH:mm"
        return fmt.string(from: date)
    }
}
