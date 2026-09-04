import SwiftUI

// 育儿室（0905 她拍板）：llm-nursery 的妈妈通道。
// 她=妈妈走这个页面；陈璟=爸爸走 CLI，他干的活会以小卡出现在气泡流里。
// 风格她定的：粉白波点、圆润无硬边框、韩系 ins 萌。整屋钉死浅色可爱一套，不跟日夜切换。
// 数据：/api/nursery/status /feed /birth /name /say /act /choose（serve.py 同源代理补 token）。

// MARK: - 调色（钉死的粉白）

private enum NurseryInk {
    static let cream = Color(red: 1.00, green: 0.972, blue: 0.965)      // 奶油底
    static let dot = Color(red: 0.969, green: 0.851, blue: 0.890)       // 波点粉
    static let rose = Color(red: 0.910, green: 0.655, blue: 0.741)      // 主粉
    static let roseDeep = Color(red: 0.816, green: 0.482, blue: 0.600)  // 按钮粉
    static let ink = Color(red: 0.427, green: 0.353, blue: 0.376)       // 深可可字
    static let dim = Color(red: 0.427, green: 0.353, blue: 0.376).opacity(0.55)
    static let mamaBubble = Color(red: 0.976, green: 0.851, blue: 0.898)
    static let childBubble = Color.white
    static let mint = Color(red: 0.839, green: 0.929, blue: 0.894)      // 事件薄荷
    static let lilac = Color(red: 0.918, green: 0.882, blue: 0.957)     // 爸爸淡紫
    static let shadow = Color(red: 0.85, green: 0.62, blue: 0.70).opacity(0.25)
}

// MARK: - 数据

struct NurseryStatus {
    let stage: String
    let stageCN: String
    let name: String
    let ageDays: Double
    let state: [String: Int]
    let bonds: [String: [String: Int]]

    init(json: [String: Any]) {
        stage = json["stage"] as? String ?? "unborn"
        stageCN = json["stage_cn"] as? String ?? ""
        name = json["name"] as? String ?? ""
        ageDays = json["age_days"] as? Double ?? 0
        state = (json["state"] as? [String: Any] ?? [:]).compactMapValues { ($0 as? NSNumber)?.intValue }
        var b: [String: [String: Int]] = [:]
        for (k, v) in json["bonds"] as? [String: Any] ?? [:] {
            b[k] = (v as? [String: Any] ?? [:]).compactMapValues { ($0 as? NSNumber)?.intValue }
        }
        bonds = b
    }
}

struct NurseryFeedItem: Identifiable {
    let id: Int
    let ts: String
    let who: String     // mama / child / papa / system
    let kind: String
    let text: String

    init?(json: [String: Any]) {
        guard let id = (json["id"] as? NSNumber)?.intValue else { return nil }
        self.id = id
        ts = json["ts"] as? String ?? ""
        who = json["who"] as? String ?? ""
        kind = json["kind"] as? String ?? ""
        text = json["text"] as? String ?? ""
    }

    var hm: String {
        guard ts.count >= 16 else { return "" }
        return String(ts.dropFirst(11).prefix(5))
    }
}

@MainActor
final class NurseryStore: ObservableObject {
    @Published var status: NurseryStatus?
    @Published var items: [NurseryFeedItem] = []
    @Published var busy = false
    @Published var loadFailed = false
    private var lastID = 0

    func refresh() async {
        do {
            let s = try await NativeHouseAPI.object("/api/nursery/status")
            status = NurseryStatus(json: s)
            loadFailed = false
        } catch { loadFailed = status == nil }
        await pullFeed()
    }

    func pullFeed() async {
        guard let obj = try? await NativeHouseAPI.object("/api/nursery/feed?since=\(lastID)") else { return }
        let fresh = (obj["items"] as? [[String: Any]] ?? []).compactMap(NurseryFeedItem.init)
        guard !fresh.isEmpty else { return }
        items.append(contentsOf: fresh)
        lastID = fresh.last?.id ?? lastID
        if items.count > 500 { items.removeFirst(items.count - 500) }
    }

    func birth(name: String) async {
        busy = true; defer { busy = false }
        _ = try? await NativeHouseAPI.object("/api/nursery/birth", method: "POST",
                                             body: name.isEmpty ? [:] : ["name": name])
        await refresh()
    }

    func say(_ text: String) async {
        busy = true; defer { busy = false }
        _ = try? await NativeHouseAPI.object("/api/nursery/say", method: "POST", body: ["text": text])
        await refresh()
    }

    func act(_ action: String) async {
        busy = true; defer { busy = false }
        _ = try? await NativeHouseAPI.object("/api/nursery/act", method: "POST", body: ["action": action])
        await refresh()
    }
}

// MARK: - 波点背景

private struct NurseryDots: View {
    var body: some View {
        ZStack {
            NurseryInk.cream.ignoresSafeArea()
            Canvas { ctx, size in
                let step: CGFloat = 46
                var row = 0
                var y: CGFloat = -20
                while y < size.height + 20 {
                    let offset: CGFloat = row % 2 == 0 ? 0 : step / 2
                    var x: CGFloat = -20 + offset
                    while x < size.width + 20 {
                        let r: CGFloat = 3.4
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(NurseryInk.dot))
                        x += step
                    }
                    row += 1
                    y += step
                }
            }
            .ignoresSafeArea()
            .opacity(0.85)
        }
    }
}

/// 圆滚滚的软卡：无描边，靠浅粉影子浮起来
private struct SoftCard: ViewModifier {
    var fill: Color = .white
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: NurseryInk.shadow, radius: 10, y: 4)
    }
}

// MARK: - 主视图

struct NurseryRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = NurseryStore()
    @State private var draft = ""
    @State private var babyName = ""
    @FocusState private var inputFocused: Bool

    /// 全屏房间第一课：安全区问 app 主窗（见 [[fullscreen-room-safe-area]]）
    private var safeTop: CGFloat {
        FloatingOverlay.appWindow()?.safeAreaInsets.top ?? 0
    }
    private var safeBottom: CGFloat {
        FloatingOverlay.appWindow()?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                NurseryDots()
                VStack(spacing: 0) {
                    header.padding(.top, max(geo.safeAreaInsets.top, safeTop, 16))
                    if let s = store.status {
                        if s.stage == "unborn" {
                            birthView
                        } else {
                            statusRibbon(s)
                            feedList
                            composer.padding(.bottom, max(safeBottom, 10))
                        }
                    } else {
                        Spacer()
                        if store.loadFailed {
                            Text("摇篮房连不上了，稍等一下再来 🍼")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(NurseryInk.dim)
                        } else {
                            ProgressView().tint(NurseryInk.rose)
                        }
                        Spacer()
                    }
                }
            }
        }
        .environment(\.colorScheme, .light)   // 整屋钉死可爱浅色
        .task {
            await store.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await store.pullFeed()
            }
        }
    }

    // MARK: 头

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(NurseryInk.roseDeep)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.9), in: Circle())
                    .shadow(color: NurseryInk.shadow, radius: 6, y: 2)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 0) {
                Text("🧸 育儿室")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(NurseryInk.ink)
                Text("nursery")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .tracking(3)
                    .foregroundColor(NurseryInk.dim)
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: 接生

    private var birthView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text("🥚")
                    .font(.system(size: 64))
                Text("小家伙还没出生")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(NurseryInk.ink)
                Text("接生那一刻他就开始长大了\n名字可以现在取，也可以以后慢慢想")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(NurseryInk.dim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                TextField("给他起个名字（可以先空着）", text: $babyName)
                    .font(.system(size: 15, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .background(NurseryInk.cream, in: Capsule())
                Button {
                    let name = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await store.birth(name: name) }
                } label: {
                    Text(store.busy ? "接生中…" : "接生 🍼")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NurseryInk.roseDeep, in: Capsule())
                        .shadow(color: NurseryInk.shadow, radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(store.busy)
            }
            .padding(26)
            .modifier(SoftCard())
            .padding(.horizontal, 30)
            Spacer()
            Spacer()
        }
    }

    // MARK: 状态条

    private func statusRibbon(_ s: NurseryStatus) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text(s.name.isEmpty ? "还没有名字" : s.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(NurseryInk.ink)
                Text("\(s.stageCN) · 第 \(max(1, Int(s.ageDays) + 1)) 天")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(NurseryInk.roseDeep)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(NurseryInk.mamaBubble, in: Capsule())
                Spacer()
                if let papa = s.bonds["papa"]?["attachment"], let mama = s.bonds["mama"]?["attachment"] {
                    Text("👨🏻 \(papa) · 👩🏻 \(mama)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(NurseryInk.dim)
                }
            }
            HStack(spacing: 10) {
                meter("心情", s.state["mood"])
                meter("健康", s.state["health"])
                meter("亲密", s.state["intimacy"])
                meter("饱饱", s.state["nutrition"])
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .modifier(SoftCard(fill: Color.white.opacity(0.92), radius: 22))
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func meter(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(NurseryInk.dim)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(NurseryInk.cream)
                    Capsule().fill(NurseryInk.rose)
                        .frame(width: g.size.width * CGFloat(min(100, max(0, value ?? 0))) / 100)
                }
            }
            .frame(height: 7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 气泡流

    private var feedList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.items.isEmpty {
                        Text("跟他说说话吧，他听得进去的 ☁️")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundColor(NurseryInk.dim)
                            .padding(.top, 40)
                    }
                    ForEach(store.items) { item in
                        bubble(item).id(item.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.items.count) { _ in
                if let last = store.items.last {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = store.items.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder private func bubble(_ item: NurseryFeedItem) -> some View {
        switch item.who {
        case "mama":
            HStack {
                Spacer(minLength: 60)
                Text(item.text)
                    .font(.system(size: 14.5, design: .rounded))
                    .foregroundColor(NurseryInk.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(NurseryInk.mamaBubble,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: NurseryInk.shadow, radius: 5, y: 2)
            }
        case "child":
            HStack(alignment: .bottom, spacing: 7) {
                Text(item.kind.hasPrefix("event:") ? "😢" : "🐣")
                    .font(.system(size: 22))
                Text(item.text)
                    .font(.system(size: 14.5, design: .rounded))
                    .foregroundColor(NurseryInk.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(item.kind.hasPrefix("event:") ? NurseryInk.mint : NurseryInk.childBubble,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: NurseryInk.shadow, radius: 5, y: 2)
                Spacer(minLength: 60)
            }
        case "papa":
            HStack {
                Spacer()
                Text("💼 " + item.text)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(NurseryInk.ink.opacity(0.75))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(NurseryInk.lilac, in: Capsule())
                Spacer()
            }
        default:   // system：出生、定名这类里程碑
            HStack {
                Spacer()
                Text("🌸 " + item.text)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(NurseryInk.roseDeep)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.white.opacity(0.9), in: Capsule())
                    .shadow(color: NurseryInk.shadow, radius: 4, y: 2)
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: 输入区

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionChip("🤗 抱抱", "hug")
                actionChip("🎵 哄哄", "soothe")
                actionChip("☁️ 摸摸", "touch")
                Spacer()
            }
            .padding(.horizontal, 16)
            HStack(spacing: 8) {
                TextField("说给他听（他会学的）", text: $draft, axis: .vertical)
                    .font(.system(size: 15, design: .rounded))
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 15).padding(.vertical, 10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: NurseryInk.shadow, radius: 6, y: 2)
                Button {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty, !store.busy else { return }
                    draft = ""
                    Task { await store.say(text) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(NurseryInk.roseDeep, in: Circle())
                        .shadow(color: NurseryInk.shadow, radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(store.busy)
            }
            .padding(.horizontal, 14)
        }
        .padding(.top, 6)
    }

    private func actionChip(_ label: String, _ action: String) -> some View {
        Button {
            guard !store.busy else { return }
            Task { await store.act(action) }
        } label: {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(NurseryInk.roseDeep)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Color.white.opacity(0.92), in: Capsule())
                .shadow(color: NurseryInk.shadow, radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}
