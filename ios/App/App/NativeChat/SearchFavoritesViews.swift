import SwiftUI

// 搜索与收藏（2026-08-19 她要的四件）：
//   · 收藏分单条和整段聊天记录——聊天页多选几条就收成一段，选一条还是单条
//   · 语音、链接也能搜能收——类型筛选下沉到服务端，不打关键词只点"语音"也能捞
//   · 搜索框下面加选项
//   · 样式跟檐下一样（GlassKit 那套冷蓝玻璃），全屏自己铺，壁纸不动
//
// 跳转高亮走的还是老路子：.alcoveJumpToMessage 带 ts 发出去，ChatView 收到后
// loadAround + 滚过去 + 闪一下。这条链是她点名要守的，换皮不许撞断。

// MARK: - 搜索

struct GlassSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("userName") private var userName = "Luna"
    @AppStorage("assistantName") private var assistantName = "陈璟"

    @State private var query = ""
    @State private var results: [ChatMessage] = []
    @State private var filterType = "all"
    @State private var searching = false
    @State private var searched = false
    @State private var month = Date()
    @State private var dayCounts: [String: Int] = [:]
    @State private var picking = false
    @State private var picked: Set<UUID> = []
    @State private var toast = ""

    private var palette: GlassPalette { .named(themeName) }
    private let types: [(String, String)] = [
        ("all", "全部"), ("text", "文字"), ("image", "图片"), ("audio", "语音"), ("link", "链接")
    ]
    private let calendar = Calendar(identifier: .gregorian)
    private let weekColumns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        ZStack(alignment: .bottom) {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                GlassHeader(title: "Search", palette: palette, onBack: { dismiss() },
                            trailing: AnyView(pickToggle))
                searchField
                GlassChips(options: types, selection: $filterType, palette: palette) { _ in
                    Task { await search() }
                }
                .padding(.top, 9)
                list
            }
            if picking && !picked.isEmpty { pickBar }
            if !toast.isEmpty { toastBar }
        }
        .task { await loadMonth() }
    }

    private var pickToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                picking.toggle()
                if !picking { picked.removeAll() }
            }
        } label: {
            Image(systemName: picking ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(picking ? palette.acc : palette.ink3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("挑几条收起来")
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(palette.ink3)
            TextField("", text: $query, prompt: Text("搜聊天记录")
                .foregroundColor(palette.ink3))
                .font(.system(size: 14, design: .serif))
                .foregroundColor(palette.ink)
                .submitLabel(.search)
                .onSubmit { Task { await search() } }
            if searching {
                ProgressView().scaleEffect(0.7).tint(palette.ink3)
            } else if !query.isEmpty {
                Button {
                    query = ""; results = []; searched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(palette.ink3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .glassCard(palette, radius: 14)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if !searched { calendarCard }
                ForEach(results) { message in
                    row(message)
                }
                if searched && results.isEmpty && !searching {
                    Text(query.isEmpty ? "这一类还没有" : "没有找到")
                        .font(.system(size: 12.5, design: .serif))
                        .foregroundColor(palette.ink3)
                        .padding(.top, 40)
                }
                Color.clear.frame(height: 70)
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
        }
    }

    private func row(_ message: ChatMessage) -> some View {
        let isPicked = picked.contains(message.uid)
        return Button {
            if picking {
                if isPicked { picked.remove(message.uid) } else { picked.insert(message.uid) }
            } else {
                NotificationCenter.default.post(name: .alcoveJumpToMessage, object: message.ts)
                dismiss()
            }
        } label: {
            HStack(alignment: .top, spacing: 11) {
                if picking {
                    Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(isPicked ? palette.acc : palette.ink3)
                        .padding(.top, 9)
                } else {
                    GlassBead(isHers: message.role == "user", size: 30).padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(message.role == "user" ? userName : assistantName)
                            .font(.system(size: 11.5, weight: .medium, design: .serif))
                            .tracking(0.8)
                            .foregroundColor(palette.ink2)
                        if let kind = badge(message) {
                            Text(kind)
                                .font(.system(size: 9, design: .monospaced))
                                .tracking(0.8)
                                .foregroundColor(palette.ink3)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().strokeBorder(palette.line, lineWidth: 0.6))
                        }
                        Spacer()
                        Text(message.date, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(palette.ink3)
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 13.5, design: .serif))
                            .foregroundColor(palette.ink)
                            .lineSpacing(3)
                            .lineLimit(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(palette)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isPicked ? palette.acc.opacity(0.55) : .clear, lineWidth: 1.2))
    }

    private func badge(_ message: ChatMessage) -> String? {
        if message.attachmentType == "audio" { return "语音" }
        if message.attachmentType == "image" { return "图片" }
        if message.text.contains("http://") || message.text.contains("https://") { return "链接" }
        return nil
    }

    // 挑几条收起来：多于一条就收成一段聊天记录
    private var pickBar: some View {
        HStack(spacing: 14) {
            Text("已挑 \(picked.count) 条")
                .font(.system(size: 12.5, design: .serif))
                .foregroundColor(palette.ink2)
            Spacer()
            Button("取消") {
                withAnimation { picking = false; picked.removeAll() }
            }
            .font(.system(size: 12.5, design: .serif))
            .foregroundColor(palette.ink3)
            Button(picked.count > 1 ? "收成一段" : "收起来") {
                Task { await keep() }
            }
            .font(.system(size: 12.5, weight: .medium, design: .serif))
            .foregroundColor(palette.acc)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .glassCard(palette, radius: 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
    }

    private var toastBar: some View {
        Text(toast)
            .font(.system(size: 12, design: .serif))
            .foregroundColor(palette.ink)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .glassCard(palette, radius: 14)
            .padding(.bottom, 90)
            .transition(.opacity)
    }

    private var calendarCard: some View {
        VStack(spacing: 9) {
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .light))
                        .frame(width: 34, height: 34).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(month, format: .dateTime.year().month(.wide))
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .tracking(2)
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .frame(width: 34, height: 34).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(palette.ink2)
            LazyVGrid(columns: weekColumns, spacing: 5) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) {
                    Text($0).font(.system(size: 9, design: .monospaced))
                        .foregroundColor(palette.ink3)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let key = dayKey(date)
                        let count = dayCounts[key]
                        Button { Task { await jumpToDay(key) } } label: {
                            VStack(spacing: 1) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundColor(count == nil ? palette.ink3 : palette.ink)
                                Text(count.map { "\($0)" } ?? " ")
                                    .font(.system(size: 7.5, design: .monospaced))
                                    .foregroundColor(palette.ink3)
                            }
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(count == nil ? Color.clear : palette.acc.opacity(0.11)))
                        }
                        .buttonStyle(.plain)
                        .disabled(count == nil)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
        .padding(13)
        .glassCard(palette)
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let offset = calendar.component(.weekday, from: interval.start) - 1
        return Array(repeating: nil, count: offset)
            + days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
                  .map(Optional.some)
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.string(from: date)
    }

    private func monthKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; f.timeZone = .current
        return f.string(from: date)
    }

    private func changeMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: month) {
            month = d
            Task { await loadMonth() }
        }
    }

    @MainActor private func loadMonth() async {
        dayCounts = (try? await AlcoveAPI.calendarCounts(month: monthKey(month))) ?? [:]
    }

    @MainActor private func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // 不打关键词、只点一类，也要能翻——这是她要的"语音链接也能搜"
        guard !q.isEmpty || filterType != "all" else {
            results = []; searched = false; return
        }
        searching = true
        defer { searching = false }
        results = (try? await AlcoveAPI.searchHistory(
            query: q, type: filterType, limit: 800)) ?? []
        searched = true
    }

    @MainActor private func jumpToDay(_ day: String) async {
        guard let first = (try? await AlcoveAPI.searchHistory(day: day, limit: 1))?.first
        else { return }
        NotificationCenter.default.post(name: .alcoveJumpToMessage, object: first.ts)
        dismiss()
    }

    @MainActor private func keep() async {
        let chosen = results.filter { picked.contains($0.uid) }
            .sorted { $0.ts < $1.ts }
        guard !chosen.isEmpty else { return }
        try? await AlcoveAPI.favoriteAdd(chosen)
        withAnimation {
            picking = false
            picked.removeAll()
            toast = chosen.count > 1 ? "收成一段了 · \(chosen.count) 条" : "收起来了"
        }
        try? await Task.sleep(nanoseconds: 1_600_000_000)
        withAnimation { toast = "" }
    }
}

// MARK: - 收藏

private struct FavoriteMember: Identifiable {
    let id = UUID()
    let ts: String
    let text: String
    let role: String
    let attachmentURL: String
    let attachmentType: String

    init(_ raw: [String: Any]) {
        ts = raw.string("ts")
        text = raw.string("text")
        role = raw.string("role")
        attachmentURL = raw.string("attachment_url")
        attachmentType = raw.string("attachment_type")
    }
}

private struct FavoriteEntry: Identifiable {
    let id: Int
    let ts: String
    let text: String
    let role: String
    let kind: String        // single | thread
    let title: String
    let atype: String       // text | image | audio | link
    let attURL: String
    let members: [FavoriteMember]
    let created: String

    var isThread: Bool { kind == "thread" }

    init(_ raw: [String: Any]) {
        id = raw.int("id")
        ts = raw.string("ts")
        text = raw.string("text")
        role = raw.string("role")
        kind = raw.string("kind").isEmpty ? "single" : raw.string("kind")
        title = raw.string("title")
        atype = raw.string("atype").isEmpty ? "text" : raw.string("atype")
        attURL = raw.string("att_url")
        members = raw.array("members").map(FavoriteMember.init)
        created = raw.string("created")
    }
}

struct GlassFavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @AppStorage("userName") private var userName = "Luna"
    @AppStorage("assistantName") private var assistantName = "陈璟"

    @State private var entries: [FavoriteEntry] = []
    @State private var kindFilter = "all"
    @State private var typeFilter = "all"
    @State private var loading = true
    @State private var opened: FavoriteEntry?

    private var palette: GlassPalette { .named(themeName) }
    private let kinds: [(String, String)] = [
        ("all", "全部"), ("single", "单条"), ("thread", "聊天记录")
    ]
    private let types: [(String, String)] = [
        ("all", "不限"), ("text", "文字"), ("audio", "语音"), ("link", "链接"), ("image", "图片")
    ]

    var body: some View {
        ZStack {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                GlassHeader(title: "Favorites", palette: palette, onBack: { dismiss() })
                GlassChips(options: kinds, selection: $kindFilter, palette: palette) { _ in
                    Task { await load() }
                }
                .padding(.top, 2)
                GlassChips(options: types, selection: $typeFilter, palette: palette) { _ in
                    Task { await load() }
                }
                .padding(.top, 7)
                content
            }
        }
        .task { await load() }
        .sheet(item: $opened) { entry in
            FavoriteThreadSheet(entry: entry, palette: palette,
                                userName: userName, assistantName: assistantName)
        }
    }

    private var content: some View {
        Group {
            if loading {
                Spacer(); ProgressView().tint(palette.ink3); Spacer()
            } else if entries.isEmpty {
                Spacer()
                Text(kindFilter == "thread" ? "还没收过整段的\n在搜索里挑几条就能收成一段" : "还没有收藏")
                    .font(.system(size: 12.5, design: .serif))
                    .foregroundColor(palette.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(entries) { entry in
                            card(entry)
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                }
            }
        }
    }

    private func card(_ entry: FavoriteEntry) -> some View {
        Button {
            if entry.isThread {
                opened = entry
            } else {
                NotificationCenter.default.post(name: .alcoveJumpToMessage, object: entry.ts)
                dismiss()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    if entry.isThread {
                        Text(entry.title.isEmpty ? "聊天记录" : entry.title)
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(palette.ink)
                    } else {
                        GlassBead(isHers: entry.role == "user", size: 22)
                        Text(entry.role == "user" ? userName : assistantName)
                            .font(.system(size: 11.5, weight: .medium, design: .serif))
                            .tracking(0.8)
                            .foregroundColor(palette.ink2)
                    }
                    if entry.atype != "text" {
                        Text(typeLabel(entry.atype))
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(palette.ink3)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().strokeBorder(palette.line, lineWidth: 0.6))
                    }
                    Spacer()
                }
                Text(entry.text)
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(entry.isThread ? palette.ink2 : palette.ink)
                    .lineSpacing(3)
                    .lineLimit(entry.isThread ? 3 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().overlay(palette.line)
                HStack {
                    Text(entry.isThread ? "\(entry.members.count) 条" : stamp(entry.ts))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(palette.ink3)
                    Spacer()
                    if entry.isThread {
                        Text(stamp(entry.ts))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(palette.ink3)
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(palette)
        .contextMenu {
            Button(role: .destructive) {
                Task { await remove(entry) }
            } label: {
                Label("不收了", systemImage: "trash")
            }
        }
    }

    private func typeLabel(_ t: String) -> String {
        switch t {
        case "audio": return "语音"
        case "image": return "图片"
        case "link": return "链接"
        default: return "文字"
        }
    }

    private func stamp(_ raw: String) -> String {
        guard raw.count >= 16 else { return raw }
        return "\(raw.dropFirst(5).prefix(5)) \(raw.dropFirst(11).prefix(5))"
    }

    @MainActor private func load() async {
        loading = true
        let raw = (try? await AlcoveAPI.favorites(kind: kindFilter, type: typeFilter)) ?? []
        entries = raw.map(FavoriteEntry.init)
        loading = false
    }

    @MainActor private func remove(_ entry: FavoriteEntry) async {
        try? await AlcoveAPI.favoriteRemove(id: entry.id)
        await load()
    }
}

// MARK: - 收藏的整段聊天记录，点开逐条排

private struct FavoriteThreadSheet: View {
    let entry: FavoriteEntry
    let palette: GlassPalette
    let userName: String
    let assistantName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(palette.ink2)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    VStack(spacing: 3) {
                        Text(entry.title.isEmpty ? "聊天记录" : entry.title)
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .tracking(3)
                            .foregroundColor(palette.ink)
                        Text("\(entry.members.count) 条")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(palette.ink3)
                    }
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .padding(.top, 18)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(entry.members.enumerated()), id: \.element.id) { index, m in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 8) {
                                    GlassBead(isHers: m.role == "user", size: 26)
                                    Text(m.role == "user" ? userName : assistantName)
                                        .font(.system(size: 11.5, weight: .medium, design: .serif))
                                        .tracking(0.8)
                                        .foregroundColor(palette.ink2)
                                    Spacer()
                                    Text(stamp(m.ts))
                                        .font(.system(size: 9.5, design: .monospaced))
                                        .foregroundColor(palette.ink3)
                                }
                                if m.attachmentType == "image", !m.attachmentURL.isEmpty {
                                    AsyncImage(url: AlcoveAPI.attachmentURL(m.attachmentURL)) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Rectangle().fill(palette.glass)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 168)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                } else if m.attachmentType == "audio" {
                                    Label("语音", systemImage: "waveform")
                                        .font(.system(size: 12, design: .serif))
                                        .foregroundColor(palette.ink2)
                                }
                                if !m.text.isEmpty {
                                    Text(m.text)
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundColor(palette.ink)
                                        .lineSpacing(4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 13)
                            if index < entry.members.count - 1 {
                                Rectangle().fill(palette.line).frame(height: 0.7)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func stamp(_ raw: String) -> String {
        guard raw.count >= 16 else { return raw }
        return "\(raw.dropFirst(5).prefix(5)) \(raw.dropFirst(11).prefix(5))"
    }
}
