import SwiftUI
import PhotosUI
import UIKit

// 池子（2026-08-18 七夕她立的项）——念头＋许愿＋朋友圈同一条时间线。
//
// 一张表两个 kind：wish 许愿（带状态：想要→在做→成了）、thought 念头（纯流水）。
// "朋友圈"不是第三种东西，是这两种混在一条时间线上、两个人交替冒头的那个视图。
//
// 皮按她 0818 给的四张参考图（Sui-IB/InternalBeyond-Mobile）：冷蓝玻璃、
// 强噪点、光从下面照上来、衬线标题＋等宽元信息。这套配色暂时只活在这一页，
// 没进主题引擎——她说了新主题先不动。

// MARK: - 这一页自己的配色

private struct PondPalette {
    let isDark: Bool
    let ink: Color          // 正文
    let ink2: Color         // 次要
    let ink3: Color         // 三级/元信息
    let acc: Color          // 强调蓝
    let gold: Color         // 许愿成了的那个金
    let glass: Color        // 玻璃填充
    let line: Color         // 玻璃描边（内高光）
    let bgTop: Color
    let bgMid: Color
    let bgBottom: Color
    let glow: Color         // 底部那团光

    static let light = PondPalette(
        isDark: false,
        ink: Color(red: 0x0A/255, green: 0x1E/255, blue: 0x42/255),
        ink2: Color(red: 0x3D/255, green: 0x57/255, blue: 0x88/255),
        ink3: Color(red: 0x7D/255, green: 0x92/255, blue: 0xB5/255),
        acc: Color(red: 0x2A/255, green: 0x6B/255, blue: 0xB0/255),
        gold: Color(red: 0xC9/255, green: 0xA8/255, blue: 0x6A/255),
        glass: Color.white.opacity(0.40),
        line: Color.white.opacity(0.74),
        bgTop: Color(red: 0xFA/255, green: 0xFC/255, blue: 0xFE/255),
        bgMid: Color(red: 0xEC/255, green: 0xF1/255, blue: 0xF7/255),
        bgBottom: Color(red: 0xCF/255, green: 0xDA/255, blue: 0xE8/255),
        glow: Color(red: 0x9E/255, green: 0xC2/255, blue: 0xEC/255).opacity(0.42))

    static let dark = PondPalette(
        isDark: true,
        ink: Color(red: 0xE0/255, green: 0xE6/255, blue: 0xF2/255),
        ink2: Color(red: 0xAD/255, green: 0xB8/255, blue: 0xD0/255),
        ink3: Color(red: 0x7E/255, green: 0x90/255, blue: 0xB2/255),
        acc: Color(red: 0x72/255, green: 0xA8/255, blue: 0xD8/255),
        gold: Color(red: 0xD0/255, green: 0xA4/255, blue: 0x4E/255),
        glass: Color(red: 20/255, green: 28/255, blue: 52/255).opacity(0.46),
        line: Color(red: 165/255, green: 188/255, blue: 230/255).opacity(0.26),
        bgTop: Color(red: 0x4A/255, green: 0x4E/255, blue: 0x56/255),
        bgMid: Color(red: 0x1A/255, green: 0x1D/255, blue: 0x24/255),
        bgBottom: Color(red: 0x12/255, green: 0x1B/255, blue: 0x33/255),
        glow: Color(red: 0x1E/255, green: 0x5F/255, blue: 0xD0/255).opacity(0.55))
}

// MARK: - 数据

private struct PondReply: Identifiable {
    let id: String
    let author: String
    let text: String
    let poke: String
    let createdAt: String
}

private struct PondCard {
    let title: String
    let site: String
    let author: String
    let cover: String
}

private struct PondItem: Identifiable {
    let id: String
    let kind: String        // wish | thought
    let author: String      // ji | jing
    let text: String
    let url: String
    let images: [String]
    let status: String      // "" | doing | done
    let statusNote: String
    let mood: String
    let pinned: Bool
    let likedBy: [String]
    let createdAt: String
    let card: PondCard?
    let replies: [PondReply]

    var isWish: Bool { kind == "wish" }
    var isHers: Bool { author == "ji" }

    init(_ raw: [String: Any]) {
        id = raw.string("id")
        kind = raw.string("kind")
        author = raw.string("author")
        text = raw.string("text")
        url = raw.string("url")
        images = (raw["images"] as? [String]) ?? []
        status = raw.string("status")
        statusNote = raw.string("statusNote")
        mood = raw.string("mood")
        pinned = raw.bool("pinned")
        likedBy = (raw["likedBy"] as? [String]) ?? []
        createdAt = raw.string("createdAt")
        let c = raw.object("card")
        card = c.isEmpty ? nil : PondCard(
            title: c.string("title"),
            site: c.string("site"),
            author: c.string("author"),
            cover: c.string("cover"))
        replies = raw.array("replies").map {
            PondReply(id: $0.string("id"), author: $0.string("author"),
                      text: $0.string("text"), poke: $0.string("poke"),
                      createdAt: $0.string("createdAt"))
        }
    }
}

private enum PondFilter: String, CaseIterable {
    case all, wish, thought
    var label: String {
        switch self {
        case .all: return "全部"
        case .wish: return "许愿"
        case .thought: return "念头"
        }
    }
    var query: String { self == .all ? "" : rawValue }
}

// MARK: - 玻璃珠头像（参考图里那颗蓝珠子，不用图片资源，直接画）

private struct GlassBead: View {
    let isHers: Bool
    let palette: PondPalette
    var size: CGFloat = 38

    private var core: Color {
        isHers
            ? Color(red: 0xE8/255, green: 0xC6/255, blue: 0xD2/255)   // 她：暖粉珠
            : Color(red: 0x3C/255, green: 0x74/255, blue: 0xC8/255)   // 我：蓝珠
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [core.opacity(0.30), core, core.opacity(0.72)],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: size * 0.04,
                        endRadius: size * 0.72))
            // 底部反光：光从下面照上来，跟整页光源一致
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(isHers ? 0.55 : 0.42), .clear],
                        center: UnitPoint(x: 0.62, y: 0.86),
                        startRadius: 0,
                        endRadius: size * 0.42))
            // 顶部高光
            Ellipse()
                .fill(Color.white.opacity(0.72))
                .frame(width: size * 0.34, height: size * 0.22)
                .offset(x: -size * 0.13, y: -size * 0.26)
                .blur(radius: size * 0.045)
            Circle().strokeBorder(Color.white.opacity(0.42), lineWidth: 0.6)
        }
        .frame(width: size, height: size)
        .shadow(color: core.opacity(0.35), radius: size * 0.16, y: size * 0.08)
    }
}

// MARK: - 噪点（参考图那层胶片颗粒，把渐变的台阶打碎）

private struct PondGrain: View {
    var opacity: Double = 0.055
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 1000) / 1000.0
            }
            let step: CGFloat = 2
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let v = next()
                    if v > 0.55 {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: step, height: step)),
                            with: .color(.white.opacity(v * 0.5)))
                    } else if v < 0.16 {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: step, height: step)),
                            with: .color(.black.opacity(0.35)))
                    }
                    x += step
                }
                y += step
            }
        }
        .opacity(opacity)
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// MARK: - 玻璃卡背景

private struct PondGlass: ViewModifier {
    let palette: PondPalette
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(palette.glass))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(palette.line, lineWidth: 0.7))
                    .shadow(color: palette.isDark
                            ? Color.black.opacity(0.32)
                            : Color(red: 90/255, green: 120/255, blue: 170/255).opacity(0.14),
                            radius: 12, y: 5))
    }
}

private extension View {
    func pondGlass(_ palette: PondPalette, radius: CGFloat = 18) -> some View {
        modifier(PondGlass(palette: palette, radius: radius))
    }
}

// MARK: - 主页面

struct NativePondView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName = "haven"

    @State private var items: [PondItem] = []
    @State private var filter: PondFilter = .all
    @State private var loading = true
    @State private var failed = false
    @State private var composing = false
    @State private var replyingTo: PondItem?

    private var palette: PondPalette {
        AlcoveTheme.named(themeName).isDark ? .dark : .light
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            background
            content
            composeButton
        }
        .task { await load() }
        .sheet(isPresented: $composing) {
            PondComposeSheet(palette: palette) { kind, text, url, photos in
                Task { await add(kind: kind, text: text, url: url, photos: photos) }
            }
        }
        .sheet(item: $replyingTo) { item in
            PondReplySheet(palette: palette, item: item) { text in
                Task { await reply(to: item.id, text: text) }
            }
        }
    }

    // 光从下面照上来：浅色底部压灰，深色底部烧一团蓝
    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [palette.bgTop, palette.bgMid, palette.bgBottom],
                startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [palette.glow, .clear],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 10, endRadius: 420)
            PondGrain(opacity: palette.isDark ? 0.05 : 0.075)
        }
        .ignoresSafeArea()
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            filterBar
            if loading {
                Spacer()
                ProgressView().tint(palette.ink3)
                Spacer()
            } else if failed {
                Spacer()
                emptyNote("没捞上来，下拉再试一次")
                Spacer()
            } else if items.isEmpty {
                Spacer()
                emptyNote(filter == .wish
                          ? "还没许过愿。贴个链接就算一条，一个字都不用写"
                          : "池子是空的")
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            PondItemCard(item: item, palette: palette,
                                         onReply: { replyingTo = item },
                                         onLike: { Task { await like(item.id) } },
                                         onStatus: { status in
                                             Task { await setStatus(item.id, status) }
                                         })
                        }
                        Color.clear.frame(height: 76)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                }
                .refreshable { await load() }
            }
        }
    }

    // 0819 全屏：房子的顶栏会透出后面的壁纸，接缝很明显，所以这一页自己做头
    private var header: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .light))
                    .foregroundColor(palette.ink2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            Spacer()
            Text("檐下")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .tracking(7)
                .foregroundColor(palette.ink)
                .padding(.leading, 7)   // 抵掉字距在右边多出来的那一格
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 54)
    }

    private var filterBar: some View {
        HStack(spacing: 7) {
            ForEach(PondFilter.allCases, id: \.self) { f in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { filter = f }
                    Task { await load() }
                } label: {
                    Text(f.label)
                        .font(.system(size: 12.5, weight: filter == f ? .semibold : .regular,
                                      design: .serif))
                        .tracking(1.2)
                        .foregroundColor(filter == f ? palette.ink : palette.ink3)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(filter == f ? palette.glass : Color.clear)
                                .overlay(Capsule().strokeBorder(
                                    filter == f ? palette.line : Color.clear, lineWidth: 0.7)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, design: .serif))
            .foregroundColor(palette.ink3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
    }

    private var composeButton: some View {
        Button { composing = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .light))
                .foregroundColor(palette.ink)
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(.ultraThinMaterial)
                        .overlay(Circle().fill(palette.glass))
                        .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.8))
                        .shadow(color: palette.isDark ? .black.opacity(0.4)
                                : Color(red: 90/255, green: 120/255, blue: 170/255).opacity(0.22),
                                radius: 14, y: 6))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    // MARK: 网络

    private func load() async {
        failed = false
        do {
            var path = "/api/pond/list?limit=80"
            if !filter.query.isEmpty { path += "&kind=\(filter.query)" }
            let raw = try await NativeHouseAPI.object(path)
            items = raw.array("items").map(PondItem.init)
            loading = false
            await markSeen()
        } catch {
            failed = true
            loading = false
        }
    }

    private func add(kind: String, text: String, url: String, photos: [Data]) async {
        var uploaded: [String] = []
        for jpeg in photos {
            if let path = await upload(jpeg) { uploaded.append(path) }
        }
        var body: [String: Any] = ["kind": kind, "author": "ji", "text": text]
        if !url.isEmpty { body["url"] = url }
        if !uploaded.isEmpty { body["images"] = uploaded }
        try? await NativeHouseAPI.post("/api/pond/add", body: body)
        await load()
    }

    /// 图走 raw body，跟工作室发图一个路子，回来是 /attachments/xxx.jpg
    private func upload(_ jpeg: Data) async -> String? {
        guard var comps = URLComponents(
            url: AlcoveAPI.fullURL("/api/pond/upload"), resolvingAgainstBaseURL: false)
        else { return nil }
        comps.queryItems = [URLQueryItem(name: "filename", value: "pond.jpg")]
        guard let url = comps.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jpeg
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        guard let (data, _) = try? await AlcoveAPI.session.data(for: request),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["ok"] as? Bool == true
        else { return nil }
        return object["url"] as? String
    }

    private func reply(to id: String, text: String) async {
        try? await NativeHouseAPI.post(
            "/api/pond/reply", body: ["item_id": id, "author": "ji", "text": text])
        await load()
    }

    private func like(_ id: String) async {
        try? await NativeHouseAPI.post("/api/pond/like", body: ["item_id": id, "author": "ji"])
        await load()
    }

    private func setStatus(_ id: String, _ status: String) async {
        try? await NativeHouseAPI.post(
            "/api/pond/status", body: ["item_id": id, "status": status])
        await load()
    }

    private func markSeen() async {
        let unseen = items.filter { $0.author == "jing" }.map { $0.id }
        guard !unseen.isEmpty else { return }
        try? await NativeHouseAPI.post("/api/pond/seen", body: ["who": "ji", "ids": unseen])
    }
}

// MARK: - 一条

private struct PondItemCard: View {
    let item: PondItem
    let palette: PondPalette
    var onReply: () -> Void
    var onLike: () -> Void
    var onStatus: (String) -> Void

    private var stamp: String {
        // "2026-08-19T02:27:21.202+08:00" → "08-19 02:27"
        let s = item.createdAt
        guard s.count >= 16 else { return s }
        let date = s.dropFirst(5).prefix(5)
        let time = s.dropFirst(11).prefix(5)
        return "\(date) \(time)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            GlassBead(isHers: item.isHers, palette: palette)
            VStack(alignment: .leading, spacing: 8) {
                header
                if !item.text.isEmpty {
                    Text(item.text)
                        .font(.system(size: 14.5, design: .serif))
                        .foregroundColor(palette.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !item.images.isEmpty { imageWall }
                if item.card != nil || !item.url.isEmpty { linkCard }
                if item.isWish { statusRow }
                if !item.replies.isEmpty { repliesBlock }
                footer
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pondGlass(palette)
        .overlay(alignment: .topTrailing) {
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundColor(palette.acc.opacity(0.7))
                    .padding(10)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text(item.isHers ? "陈霁" : "陈璟")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .tracking(1.0)
                .foregroundColor(palette.ink2)
            Text(item.isWish ? "许愿" : "念头")
                .font(.system(size: 9, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(palette.ink3)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().strokeBorder(palette.line, lineWidth: 0.6))
            if !item.mood.isEmpty {
                Text(item.mood)
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(palette.acc)
            }
            Spacer()
        }
    }

    // 一张就铺开，多张走两列
    private var imageWall: some View {
        let columns = item.images.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)]
        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach(item.images, id: \.self) { path in
                AsyncImage(url: AlcoveAPI.attachmentURL(path)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(palette.glass)
                    }
                }
                .frame(height: item.images.count == 1 ? 178 : 104)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(palette.line.opacity(0.5), lineWidth: 0.6))
            }
        }
    }

    private var linkCard: some View {
        HStack(spacing: 10) {
            if let cover = item.card?.cover, !cover.isEmpty {
                AsyncImage(url: AlcoveAPI.attachmentURL(cover)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(palette.glass)
                    }
                }
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                Image(systemName: "link")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(palette.ink3)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(palette.glass))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.card?.title.isEmpty == false ? item.card!.title : item.url)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(palette.ink)
                    .lineLimit(2)
                if let c = item.card, !c.site.isEmpty || !c.author.isEmpty {
                    Text([c.site, c.author].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(palette.ink3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.glass.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.line.opacity(0.6), lineWidth: 0.6)))
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            ForEach([("", "想要"), ("doing", "在做"), ("done", "成了")], id: \.0) { value, label in
                let on = item.status == value
                Button { onStatus(value) } label: {
                    Text(label)
                        .font(.system(size: 10, design: .serif))
                        .tracking(0.6)
                        .foregroundColor(on ? (value == "done" ? palette.gold : palette.acc)
                                            : palette.ink3)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().strokeBorder(
                            on ? (value == "done" ? palette.gold : palette.acc).opacity(0.55)
                               : palette.line.opacity(0.5),
                            lineWidth: 0.7))
                }
                .buttonStyle(.plain)
            }
            if !item.statusNote.isEmpty {
                Text(item.statusNote)
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(palette.ink3)
            }
            Spacer()
        }
    }

    private var repliesBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(item.replies) { r in
                HStack(alignment: .top, spacing: 6) {
                    Text(r.author == "ji" ? "陈霁" : "陈璟")
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundColor(r.author == "ji" ? palette.ink2 : palette.acc)
                    if !r.poke.isEmpty {
                        Text(r.poke).font(.system(size: 11))
                    }
                    if !r.text.isEmpty {
                        Text(r.text)
                            .font(.system(size: 11.5, design: .serif))
                            .foregroundColor(palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.leading, 9)
        .overlay(alignment: .leading) {
            Rectangle().fill(palette.line).frame(width: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(stamp)
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.4)
                .foregroundColor(palette.ink3)
            Spacer()
            Button(action: onLike) {
                HStack(spacing: 4) {
                    Image(systemName: item.likedBy.isEmpty ? "heart" : "heart.fill")
                        .font(.system(size: 11.5, weight: .light))
                    if item.likedBy.count > 1 {
                        Text("2").font(.system(size: 9.5, design: .monospaced))
                    }
                }
                .foregroundColor(item.likedBy.isEmpty ? palette.ink3 : palette.acc)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: onReply) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(palette.ink3)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 1)
    }
}

// MARK: - 放一条

private struct PondComposeSheet: View {
    let palette: PondPalette
    var onSubmit: (String, String, String, [Data]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "wish"
    @State private var text = ""
    @State private var url = ""
    @State private var picks: [PhotosPickerItem] = []
    @State private var pending: [PondPendingPhoto] = []
    @State private var uploading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("放一条")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .tracking(2)
                    .foregroundColor(palette.ink)
                Spacer()
                Button("放进去") {
                    onSubmit(kind, text.trimmingCharacters(in: .whitespacesAndNewlines),
                             url.trimmingCharacters(in: .whitespacesAndNewlines),
                             pending.map { $0.jpeg })
                    dismiss()
                }
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(canSubmit ? palette.acc : palette.ink3)
                .disabled(!canSubmit)
            }

            HStack(spacing: 8) {
                ForEach([("wish", "许愿"), ("thought", "念头")], id: \.0) { value, label in
                    Button { kind = value } label: {
                        Text(label)
                            .font(.system(size: 12.5, design: .serif))
                            .tracking(1)
                            .foregroundColor(kind == value ? palette.ink : palette.ink3)
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(Capsule()
                                .fill(kind == value ? palette.glass : .clear)
                                .overlay(Capsule().strokeBorder(
                                    kind == value ? palette.line : palette.line.opacity(0.4),
                                    lineWidth: 0.7)))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            TextEditor(text: $text)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(palette.ink)
                .scrollContentBackground(.hidden)
                .frame(height: 120)
                .padding(10)
                .pondGlass(palette, radius: 14)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(kind == "wish" ? "想要什么，不写字也行" : "刚被戳到的那下")
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(palette.ink3)
                            .padding(.horizontal, 15).padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }

            TextField("", text: $url, prompt: Text("贴个链接（可以只有链接）")
                .foregroundColor(palette.ink3))
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundColor(palette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(11)
                .pondGlass(palette, radius: 12)

            HStack(spacing: 10) {
                PhotosPicker(selection: $picks, maxSelectionCount: 9, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 13, weight: .light))
                        Text(pending.isEmpty ? "加图" : "\(pending.count) 张")
                            .font(.system(size: 12, design: .serif)).tracking(1)
                    }
                    .foregroundColor(palette.ink2)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().strokeBorder(palette.line, lineWidth: 0.7))
                }
                if uploading { ProgressView().scaleEffect(0.7).tint(palette.ink3) }
                Spacer()
            }

            if !pending.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pending) { photo in
                            Image(uiImage: photo.thumb)
                                .resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 62, height: 62)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        pending.removeAll { $0.id == photo.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white, .black.opacity(0.45))
                                            .padding(2)
                                    }
                                    .buttonStyle(.plain)
                                }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(colors: [palette.bgTop, palette.bgMid, palette.bgBottom],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [palette.glow, .clear],
                               center: UnitPoint(x: 0.5, y: 1.05),
                               startRadius: 10, endRadius: 380)
                PondGrain(opacity: palette.isDark ? 0.05 : 0.07)
            }.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .onChange(of: picks) { _, items in
            Task { await loadPicks(items) }
        }
    }

    private var canSubmit: Bool {
        !(text.isEmpty && url.isEmpty && pending.isEmpty)
    }

    @MainActor
    private func loadPicks(_ items: [PhotosPickerItem]) async {
        uploading = true
        var out: [PondPendingPhoto] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.82) {
                out.append(PondPendingPhoto(thumb: image, jpeg: jpeg))
            }
        }
        pending = out
        uploading = false
    }
}

private struct PondPendingPhoto: Identifiable {
    let id = UUID()
    let thumb: UIImage
    let jpeg: Data
}

// MARK: - 回一句

private struct PondReplySheet: View {
    let palette: PondPalette
    let item: PondItem
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("回一句")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .tracking(2)
                    .foregroundColor(palette.ink)
                Spacer()
                Button("发") {
                    onSubmit(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(text.isEmpty ? palette.ink3 : palette.acc)
                .disabled(text.isEmpty)
            }
            if !item.text.isEmpty {
                Text(item.text)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(palette.ink3)
                    .lineLimit(3)
            }
            TextEditor(text: $text)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(palette.ink)
                .scrollContentBackground(.hidden)
                .frame(height: 100)
                .padding(10)
                .pondGlass(palette, radius: 14)
            Spacer()
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(colors: [palette.bgTop, palette.bgMid, palette.bgBottom],
                               startPoint: .top, endPoint: .bottom)
                PondGrain(opacity: palette.isDark ? 0.05 : 0.07)
            }.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
