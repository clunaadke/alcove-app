import SwiftUI

private struct SurfBookmark: Identifiable {
    let id: Int
    let ts, platform, url, title, summary, cover, author: String

    init(_ raw: [String: Any]) {
        id = (raw["id"] as? NSNumber)?.intValue ?? 0
        ts = raw["ts"] as? String ?? ""
        platform = raw["platform"] as? String ?? ""
        url = raw["url"] as? String ?? ""
        title = raw["title"] as? String ?? ""
        summary = raw["summary"] as? String ?? ""
        cover = raw["cover"] as? String ?? ""
        author = raw["author"] as? String ?? ""
    }
}

struct NativeSurfCollectionView: View {
    @AppStorage("houseInterfaceAppearance") private var appearance = "system"
    @Environment(\.colorScheme) private var systemScheme
    @State private var selected = "x"
    @State private var items: [SurfBookmark] = []
    @State private var loading = false

    private let platforms: [(id: String, title: String, icon: String)] = [
        ("x", "X", "xmark"),
        ("xhs", "小红书", "book.closed.fill"),
        ("bilibili", "B站", "play.rectangle.fill"),
        ("youtube", "YouTube", "play.fill"),
    ]

    // 0826 她说这页太丑且一进去闪白：皮换成檐下那套，暗色判断改用环境里的
    // colorScheme（UITraitCollection.current 首帧还停在 light，才会白闪一下）。
    private var dark: Bool {
        appearance == "dark" || (appearance == "system" && systemScheme == .dark)
    }
    private var pal: YanxiaPal { YanxiaPal(night: dark) }
    private var card: Color { pal.card }
    private var ink: Color { pal.ink }
    private var dim: Color { pal.ink3 }

    var body: some View {
        ZStack {
            CoreadYanxiaBackground(isNight: dark).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("冲浪收藏")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .tracking(1.2)
                    .foregroundColor(pal.ink)
                    .padding(.top, 14)
                platformPicker
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if loading {
                            ProgressView().padding(.top, 50)
                        } else if items.isEmpty {
                            VStack(spacing: 9) {
                                Image(systemName: platforms.first(where: { $0.id == selected })?.icon ?? "safari")
                                    .font(.system(size: 25, weight: .light))
                                Text(selected == "bilibili" || selected == "youtube"
                                     ? "这个入口还没接上" : "他还没在这里留下东西")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(dim).padding(.top, 70)
                        } else {
                            ForEach(items) { item in bookmarkRow(item) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 30)
                }
            }
            .foregroundColor(ink)
        }
        .task(id: selected) { await load() }
    }

    private var platformPicker: some View {
        HStack(spacing: 0) {
            ForEach(platforms, id: \.id) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selected = p.id }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: p.icon).font(.system(size: 13, weight: .semibold))
                        Text(p.title).font(.system(size: 11.5, weight: selected == p.id ? .semibold : .regular))
                    }
                    .foregroundColor(selected == p.id ? pal.accent : dim)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selected == p.id ? pal.accent.opacity(dark ? 0.20 : 0.14) : .clear,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(pal.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private func bookmarkRow(_ item: SurfBookmark) -> some View {
        Button {
            if let url = URL(string: item.url) { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    pal.card2
                    if let url = coverURL(item.cover) {
                        CachedImage(url: url) { $0.resizable().scaledToFill() }
                            placeholder: { Image(systemName: "link").foregroundColor(dim) }
                    } else {
                        Image(systemName: "link").foregroundColor(dim)
                    }
                }
                .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title.isEmpty ? item.url : item.title)
                        .font(.system(size: 14, weight: .medium)).lineLimit(2)
                    if !item.summary.isEmpty { Text(item.summary).font(.system(size: 11.5)).foregroundColor(dim).lineLimit(2) }
                    Text([item.author, String(item.ts.prefix(16)).replacingOccurrences(of: "T", with: " ")]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 10)).foregroundColor(dim)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(dim)
            }
            .padding(12)
            .background(card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(pal.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func coverURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        return raw.hasPrefix("/attachments") ? AlcoveAPI.attachmentURL(raw) : URL(string: raw)
    }

    private func load() async {
        loading = true
        let raw = (try? await NativeHouseAPI.array(
            "/api/surf/list?platform=\(selected)&limit=150", key: "items")) ?? []
        items = raw.map(SurfBookmark.init)
        loading = false
    }
}
