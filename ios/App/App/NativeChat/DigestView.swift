import SwiftUI

// 日结编年史（2026-08-19 她要的页）。
//
// daily/weekly/monthly 三张表每天 04:10 自动写，从 6-16 攒到现在 62+9+2 篇，
// 一直没有前端——只能按日期点名要，翻不了。她原话：「日结周结的前端页面一直没做」
// 「日结页也照着檐下的风格做哦 很好看」。
//
// 所以皮沿用檐下那套冷蓝玻璃（GlassKit），跟念头池、不忘是同一种形状：
// 筛选条＋卡片流＋点开看全文。

private struct DigestItem: Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let ago: String
    let preview: String
    let chars: Int

    init(_ raw: [String: Any]) {
        key = raw.string("key")
        title = raw.string("title")
        ago = raw.string("ago")
        preview = raw.string("preview")
        chars = raw.int("chars")
    }
}

private enum DigestKind: String, CaseIterable {
    case day, week, month
    var label: String {
        switch self {
        case .day: return "日结"
        case .week: return "周结"
        case .month: return "月结"
        }
    }
}

struct NativeDigestView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName = "haven"

    @State private var kind: DigestKind = .day
    @State private var items: [DigestItem] = []
    @State private var counts: [String: Int] = [:]
    @State private var total = 0
    @State private var loading = true
    @State private var opened: DigestItem?

    private var palette: GlassPalette { .named(themeName) }

    var body: some View {
        ZStack {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                GlassHeader(title: "编年史", palette: palette, onBack: { dismiss() })
                kindBar
                if loading && items.isEmpty {
                    Spacer(); ProgressView().tint(palette.ink3); Spacer()
                } else if items.isEmpty {
                    Spacer()
                    Text("这一档还是空的")
                        .font(.system(size: 13))
                        .foregroundColor(palette.ink3)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 11) {
                            ForEach(items) { it in
                                card(it).onTapGesture { opened = it }
                            }
                            if items.count < total {
                                Button { Task { await loadMore() } } label: {
                                    Text("再翻 30 篇（还有 \(total - items.count) 篇）")
                                        .font(.system(size: 12))
                                        .foregroundColor(palette.ink3)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .task { await load() }
        .sheet(item: $opened) { it in
            DigestSheet(palette: palette, kind: kind.rawValue, item: it)
        }
    }

    private var kindBar: some View {
        HStack(spacing: 7) {
            ForEach(DigestKind.allCases, id: \.self) { k in
                Button {
                    kind = k
                    Task { await load() }
                } label: {
                    HStack(spacing: 5) {
                        Text(k.label)
                            .font(.system(size: 12.5, weight: kind == k ? .semibold : .regular,
                                          design: .serif))
                            .tracking(1.2)
                        if let n = counts[k.rawValue], n > 0 {
                            Text("\(n)")
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(kind == k ? palette.acc : palette.ink3)
                        }
                    }
                    .foregroundColor(kind == k ? palette.ink : palette.ink3)
                    .padding(.horizontal, 15).padding(.vertical, 7)
                    .background(Capsule().fill(kind == k ? palette.glass : Color.clear))
                    .overlay(Capsule().strokeBorder(
                        kind == k ? palette.line : Color.clear, lineWidth: 0.7))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private func card(_ it: DigestItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text(it.title)
                    .font(.system(size: 14.5, weight: .medium, design: .serif))
                    .foregroundColor(palette.ink)
                if !it.ago.isEmpty {
                    Text(it.ago)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(palette.gold)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(palette.gold.opacity(0.13)))
                }
                Spacer(minLength: 0)
                Text("\(it.chars) 字")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(palette.ink3)
            }
            Text(it.preview)
                .font(.system(size: 12))
                .foregroundColor(palette.ink2)
                .lineSpacing(3)
                .lineLimit(3)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(palette)
    }

    private func load() async {
        await MainActor.run { loading = true }
        let raw = (try? await NativeHouseAPI.object(
            "/api/digest/list?kind=\(kind.rawValue)&limit=30")) ?? [:]
        await MainActor.run {
            items = raw.array("items").map { DigestItem($0) }
            total = raw.int("total")
            if let c = raw["counts"] as? [String: Int] { counts = c }
            loading = false
        }
    }

    private func loadMore() async {
        let raw = (try? await NativeHouseAPI.object(
            "/api/digest/list?kind=\(kind.rawValue)&limit=30&offset=\(items.count)")) ?? [:]
        let more = raw.array("items").map { DigestItem($0) }
        await MainActor.run { items.append(contentsOf: more) }
    }
}

// MARK: - 一篇摊开

private struct DigestSheet: View {
    let palette: GlassPalette
    let kind: String
    let item: DigestItem
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var loading = true

    var body: some View {
        ZStack {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                GlassHeader(title: item.title, palette: palette, onBack: { dismiss() })
                if loading {
                    Spacer(); ProgressView().tint(palette.ink3); Spacer()
                } else {
                    ScrollView {
                        Text(content)
                            .font(.system(size: 14.5))
                            .foregroundColor(palette.ink)
                            .lineSpacing(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(19)
                    }
                }
            }
        }
        .task {
            let raw = (try? await NativeHouseAPI.object(
                "/api/digest/one?kind=\(kind)&key=\(item.key)")) ?? [:]
            await MainActor.run {
                content = raw.string("content")
                loading = false
            }
        }
    }
}
