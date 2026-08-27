import SwiftUI

// 战绩房：关掉的房不再销尸灭迹，cards 服务把终局归档，这里翻旧账。
// 列表（新→旧）+ 单局详情（名单、事件回放、牌桌闲聊）。

struct QipaiHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [QipaiAPI.HistorySummary] = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var record: QipaiAPI.HistoryRecord?
    @State private var loadingDetail = false

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

    // MARK: 列表

    @ViewBuilder private var listView: some View {
        if loading && items.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorText {
            VStack(spacing: 8) {
                Text(errorText).font(.system(size: 12)).foregroundColor(QipaiPalette.red)
                Button("再试一次") { Task { await reload() } }
                    .buttonStyle(QipaiEmbossedButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty {
            VStack(spacing: 5) {
                Text("还没有留档的牌局").font(.system(size: 12.5)).foregroundColor(QipaiPalette.inkDim)
                QipaiWhisper(text: "play one, close it, it lands here.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(items) { item in row(item) }
                }
            }
        }
    }

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
                HStack(spacing: 6) {
                    QipaiChip(text: item.gameName, tone: .live)
                    QipaiChip(text: item.finished ? "打完了" : "半途关的",
                              tone: item.finished ? .neutral : .done)
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

    // MARK: 详情

    private func detailView(_ record: QipaiAPI.HistoryRecord) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.name.isEmpty ? record.gameName : record.name)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(QipaiPalette.ink)
                    HStack(spacing: 6) {
                        QipaiChip(text: record.gameName, tone: .live)
                        QipaiChip(text: record.finished ? "打完了" : "半途关的",
                                  tone: record.finished ? .neutral : .done)
                        Text("\(record.code) · \(Self.dateText(record.closedAt))")
                            .font(.system(size: 10.5)).foregroundColor(QipaiPalette.inkDim)
                    }
                    HStack(spacing: 5) {
                        ForEach(record.players) { seat in
                            HStack(spacing: 3) {
                                if seat.isAI {
                                    Image(systemName: "sparkles").font(.system(size: 8))
                                        .foregroundColor(QipaiPalette.accent)
                                }
                                Text(seat.name).font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(QipaiPalette.ink.opacity(0.85))
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(QipaiPalette.panelDeep.opacity(0.8)))
                        }
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

    // MARK: 动作

    @MainActor private func reload() async {
        loading = true
        defer { loading = false }
        do {
            items = try await QipaiAPI.history()
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
