import SwiftUI

/// 聊天页那张信封卡。信封是她自己抠的图，字叠在两块空白上：
/// 中间那张小卡片写一行邮戳，信封下半截写寄给谁、锁没锁、多久之前投递的。
struct LetterEnvelopeCard: Decodable, Equatable {
    let kind: String?          // sealed 封着的预告 / opened 锁开了 / plain 没上锁
    let stateLine: String?     // 锁着 · 2027.08.26 开 ／ 锁开了 ／ 这封信现在就能读
    let agoText: String?       // 今天投递 ／ 三天前投递 ／ 一年前投递
    let senderName: String?
    let recipientName: String?

    var stamp: String {
        switch kind ?? "opened" {
        case "sealed": return "SEALED"
        case "plain":  return "A LETTER"
        default:       return "OPENED"
        }
    }
}

struct LetterMessageCard: View {
    let card: LetterEnvelopeCard
    let theme: AlcoveTheme
    // 0827 她切白天信封还是黑的：这张卡直接认全屋那个开关，
    // 不经过聊天主题转一道手，按哪边就是哪边。
    @AppStorage("houseInterfaceAppearance") private var appearance = "dark"

    // 2026-08-27 白天：换回深浅两套皮。
    // 凌晨那版把深色信封钉死了（黑配黑糊过三次，图省事一刀切），结果白天模式下
    // 一块黑砖贴在米白聊天页上。图和字色一起翻，不再各判各的，
    // 就不会出现信封翻了字没翻的糊法。
    private var dark: Bool { appearance != "light" }
    private var imageURL: URL {
        AlcoveAPI.fullURL(dark ? "/letter/envelope-dark.png" : "/letter/envelope-light.png")
    }
    private var ink: Color  { dark ? Color(red: 0.945, green: 0.933, blue: 0.906) : Color(red: 0.192, green: 0.184, blue: 0.173) }
    private var ink2: Color { dark ? Color(red: 0.757, green: 0.733, blue: 0.690) : Color(red: 0.404, green: 0.388, blue: 0.365) }
    private var ink3: Color { dark ? Color(red: 0.549, green: 0.525, blue: 0.482) : Color(red: 0.549, green: 0.529, blue: 0.498) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CachedImage(url: imageURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    dark ? Color(red: 0.086, green: 0.086, blue: 0.086)
                         : Color(red: 0.937, green: 0.929, blue: 0.910)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .id(dark)   // 深浅换了整块重建，不给任何缓存留下攥着旧图不放的机会

                // 中间那张小卡片上的一行，像邮戳
                Text(card.stamp)
                    .font(.system(size: 8.5, design: .monospaced))
                    .tracking(4.5)
                    .foregroundColor(ink3)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.435)   // 她说太靠上，往小卡片中间挪

                // 信封下半截
                Text("\(card.senderName ?? "") 寄给 \(card.recipientName ?? "")")
                    .font(.system(size: 15.5, design: .serif))
                    .tracking(2.5)
                    .foregroundColor(ink)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.685)

                Text(card.stateLine ?? "")
                    .font(.system(size: 10.5, design: .serif))
                    .tracking(1.6)
                    .foregroundColor(ink2)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.778)

                Text(card.agoText ?? "")
                    .font(.system(size: 8.5, design: .monospaced))
                    .tracking(2.6)
                    .foregroundColor(ink3)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.847)
            }
        }
        .aspectRatio(2048.0 / 2007.0, contentMode: .fit)
        .frame(maxWidth: 196)          // 她说至少缩一半
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: Color.black.opacity(dark ? 0.30 : 0.16), radius: 14, y: 5)
        .padding(.horizontal, 6)
    }
}

private struct LetterboxPalette {
    let dark: Bool
    var background: Color { dark ? Color(red: 0.095, green: 0.10, blue: 0.115) : Color(red: 0.952, green: 0.945, blue: 0.938) }
    var paper: Color { dark ? Color(red: 0.145, green: 0.15, blue: 0.17) : Color(red: 0.982, green: 0.975, blue: 0.962) }
    var paper2: Color { dark ? Color(red: 0.18, green: 0.18, blue: 0.20) : Color(red: 0.925, green: 0.895, blue: 0.895) }
    var ink: Color { dark ? Color(red: 0.91, green: 0.90, blue: 0.88) : Color(red: 0.24, green: 0.23, blue: 0.24) }
    var ink2: Color { dark ? Color(red: 0.64, green: 0.63, blue: 0.64) : Color(red: 0.47, green: 0.45, blue: 0.46) }
    var blush: Color { dark ? Color(red: 0.43, green: 0.38, blue: 0.42) : Color(red: 0.80, green: 0.73, blue: 0.75) }
    var line: Color { dark ? Color.white.opacity(0.12) : Color(red: 0.76, green: 0.74, blue: 0.73).opacity(0.58) }
}

private struct LetterboxItem: Identifiable {
    let id: Int
    let sender: String
    let senderName: String
    let recipient: String
    let recipientName: String
    let salutation: String
    let title: String
    let body: String
    let blessing: String
    let postscript: String
    let mode: String
    let state: String
    let createdAt: String
    let deliverAt: String
    let unlockAt: String
    let remainingSeconds: Int
    let canEdit: Bool
    let canCancel: Bool

    init(_ raw: [String: Any]) {
        id = raw.int("id")
        sender = raw.string("sender")
        senderName = raw.string("senderName")
        recipient = raw.string("recipient")
        recipientName = raw.string("recipientName")
        salutation = raw.string("salutation")
        title = raw.string("title")
        body = raw.string("body")
        blessing = raw.string("blessing")
        postscript = raw.string("postscript")
        mode = raw.string("mode")
        state = raw.string("state")
        createdAt = raw.string("createdAt")
        deliverAt = raw.string("deliverAt")
        unlockAt = raw.string("unlockAt")
        remainingSeconds = raw.int("remainingSeconds")
        canEdit = raw.bool("canEdit")
        canCancel = raw.bool("canCancel")
    }
}

@MainActor
private final class LetterboxModel: ObservableObject {
    @Published var items: [LetterboxItem] = []
    @Published var unread = 0
    @Published var locked = 0
    @Published var scheduled = 0
    @Published var loading = true
    @Published var error = ""

    func load() async {
        do {
            let raw = try await NativeHouseAPI.object("/letters/list?actor=chenji")
            items = raw.array("items").map(LetterboxItem.init)
            let counts = raw.object("counts")
            unread = counts.int("unread")
            locked = counts.int("locked")
            scheduled = counts.int("scheduled")
            error = ""
        } catch {
            self.error = "信箱暂时没有打开"
        }
        loading = false
    }

    func detail(_ id: Int) async throws -> LetterboxItem {
        let raw = try await NativeHouseAPI.object("/letters/one?id=\(id)&actor=chenji")
        return LetterboxItem(raw.object("letter"))
    }

    func cancel(_ id: Int) async {
        do {
            _ = try await NativeHouseAPI.object("/letters/cancel", method: "POST", body: ["id": id, "sender": "chenji"])
            await load()
        } catch { self.error = "这封信没有取消成功" }
    }
}

struct NativeLetterboxView: View {
    private enum Tab: String, CaseIterable { case inbox = "收信", compose = "写信", archive = "共读" }
    @Environment(\.dismiss) private var dismiss
    @AppStorage("houseInterfaceAppearance") private var appearance = "dark"
    @StateObject private var model = LetterboxModel()
    @State private var tab: Tab = .inbox
    @State private var opened: LetterboxItem?
    @State private var editLetter: LetterboxItem?

    private var dark: Bool { appearance != "light" }
    private var pal: LetterboxPalette { LetterboxPalette(dark: dark) }

    var body: some View {
        ZStack {
            pal.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch tab {
                    case .inbox: inbox
                    case .compose: compose
                    case .archive: archive
                    }
                }
                bottomBar
            }
        }
        .foregroundColor(pal.ink)
        .preferredColorScheme(dark ? .dark : .light)
        .task { await model.load() }
        .sheet(item: $opened) { letter in
            LetterReadingSheet(letter: letter, pal: pal)
        }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                Text("LETTERS ACROSS TIME")
                    .font(.system(size: 8.5, weight: .medium, design: .serif)).tracking(2.2)
                    .foregroundColor(pal.ink2)
                Text("月下信箱").font(.system(size: 29, weight: .light, design: .serif)).tracking(3)
            }
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.top, 48).padding(.horizontal, 14).padding(.bottom, 12)
    }

    private var inbox: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ornament("A LETTER HAS FOUND YOU")
                latestEnvelope
                HStack(spacing: 10) {
                    statCard("UNOPENED LETTERS", model.unread, "未读来信", "envelope")
                    statCard("SEALED FOR LATER", model.locked, "锁定中的信", "clock")
                }
                letterList(model.items)
            }
            .padding(.horizontal, 18).padding(.bottom, 18)
        }
        .refreshable { await model.load() }
    }

    private var archive: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ornament("LETTERS WE CAN READ TOGETHER")
                letterList(model.items.filter { $0.state != "locked" && $0.state != "scheduled" })
            }
            .padding(.horizontal, 18).padding(.bottom, 18)
        }
        .refreshable { await model.load() }
    }

    private var compose: some View {
        LetterComposeView(pal: pal, editing: editLetter) {
            editLetter = nil
            tab = .inbox
            Task { await model.load() }
        }
        .id(editLetter?.id ?? 0)
    }

    private var latestEnvelope: some View {
        let latest = model.items.first
        return Button {
            guard let latest else { tab = .compose; return }
            open(latest)
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(pal.paper2)
                Image(systemName: latest?.state == "locked" ? "lock.fill" : "envelope.fill")
                    .font(.system(size: 92, weight: .ultraLight))
                    .foregroundColor(pal.paper.opacity(0.52))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 5) {
                    Text(latest.map { $0.state == "locked" ? countdown($0.remainingSeconds) : ($0.title.isEmpty ? "未题" : $0.title) } ?? "写一封信")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                    Text(latest.map { $0.state == "locked" ? "" : "\($0.senderName) · \(stateText($0))" } ?? "给陈璟，也给未来")
                        .font(.system(size: 10.5)).foregroundColor(pal.ink2)
                }.padding(20)
            }
            .frame(height: 178)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(pal.line, lineWidth: 0.7))
        }.buttonStyle(.plain)
    }

    private func statCard(_ eyebrow: String, _ count: Int, _ note: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(eyebrow).font(.system(size: 7.5, design: .serif)).tracking(1.2); Spacer(); Image(systemName: icon) }
                .foregroundColor(pal.ink2)
            Text("\(count)").font(.system(size: 23, weight: .light, design: .serif))
            Text(note).font(.system(size: 10)).foregroundColor(pal.ink2)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(pal.paper2.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(pal.line, lineWidth: 0.5))
    }

    @ViewBuilder private func letterList(_ letters: [LetterboxItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("往来书信").font(.system(size: 18, weight: .medium, design: .serif)); Spacer(); Text("\(letters.count) LETTERS").font(.system(size: 8, design: .serif)).foregroundColor(pal.ink2) }
            if model.loading { ProgressView().frame(maxWidth: .infinity).padding(35) }
            else if letters.isEmpty { Text("信纸还是空的").font(.system(size: 12)).foregroundColor(pal.ink2).frame(maxWidth: .infinity).padding(35) }
            ForEach(letters) { letter in
                HStack(spacing: 8) {
                    Button { open(letter) } label: {
                        HStack(spacing: 12) {
                        Image(systemName: letter.state == "locked" ? "lock.fill" : (letter.sender == "chenji" ? "paperplane" : "envelope.open"))
                            .font(.system(size: 17)).foregroundColor(pal.ink2)
                            .frame(width: 42, height: 42).background(pal.paper2, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(letter.state == "locked" ? countdown(letter.remainingSeconds) : (letter.title.isEmpty ? "未题" : letter.title))
                                .font(.system(size: 14, weight: .medium, design: .serif)).lineLimit(1)
                            Text(letter.state == "locked" ? "" : "\(letter.senderName) · \(stateText(letter))").font(.system(size: 10)).foregroundColor(pal.ink2)
                        }
                        Spacer()
                        if !letter.canCancel {
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(pal.ink2)
                        }
                        }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if letter.canCancel {
                        Button { Task { await model.cancel(letter.id) } } label: {
                            Image(systemName: "xmark.circle").frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel("取消定时寄送")
                    }
                }
                .padding(12).background(pal.paper, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(pal.line, lineWidth: 0.5))
            }
            if !model.error.isEmpty { Text(model.error).font(.system(size: 10.5)).foregroundColor(.red.opacity(0.8)) }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            tabButton(.inbox, "envelope")
            tabButton(.compose, "leaf")
            tabButton(.archive, "book")
        }
        .padding(6).background(pal.paper, in: Capsule())
        .overlay(Capsule().stroke(pal.line, lineWidth: 0.6))
        .padding(.horizontal, 18).padding(.bottom, 8)
    }

    private func tabButton(_ value: Tab, _ icon: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { tab = value } } label: {
            VStack(spacing: 3) { Image(systemName: icon); Text(value.rawValue).font(.system(size: 10.5)) }
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(tab == value ? pal.blush.opacity(0.58) : .clear, in: Capsule())
        }.buttonStyle(.plain)
    }

    private func ornament(_ text: String) -> some View {
        HStack { Rectangle().frame(height: 0.5); Text(text).font(.system(size: 7.5, design: .serif)).tracking(1.4).fixedSize(); Rectangle().frame(height: 0.5) }
            .foregroundColor(pal.ink2.opacity(0.55))
    }

    private func open(_ letter: LetterboxItem) {
        guard letter.state != "locked" else { return }
        if letter.canEdit {
            Task {
                if let detail = try? await model.detail(letter.id) {
                    editLetter = detail; tab = .compose
                }
            }
            return
        }
        Task {
            if let detail = try? await model.detail(letter.id) {
                opened = detail; await model.load()
            }
        }
    }

    private func stateText(_ item: LetterboxItem) -> String {
        switch item.state {
        case "locked": return countdown(item.remainingSeconds)
        case "scheduled": return "将在 \(dateText(item.deliverAt)) 寄出"
        case "unread": return item.recipient == "chenji" ? "未读" : "已寄出"
        default: return "已读"
        }
    }

    private func countdown(_ seconds: Int) -> String {
        let days = max(0, Int(ceil(Double(seconds) / 86400.0)))
        return days > 0 ? "将在 \(days) 天后解锁" : "即将解锁"
    }

    private func dateText(_ raw: String) -> String {
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: raw) else { return raw }
        let out = DateFormatter(); out.locale = Locale(identifier: "zh_CN"); out.dateFormat = "M月d日 HH:mm"
        return out.string(from: date)
    }
}

private struct LetterComposeView: View {
    let pal: LetterboxPalette
    let editing: LetterboxItem?
    let completed: () -> Void
    @State private var salutation = "陈璟"
    @State private var title = ""
    @State private var letterBody = ""
    @State private var blessing = ""
    @State private var postscript = ""
    @State private var mode = "immediate"
    @State private var deliverAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var lockDays = 3
    @State private var sending = false
    @State private var announce = false      // 她 0827 要的：寄完自己决定要不要先让对方看见信封
    @State private var error = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ornament
                field("收信人") { Text("陈璟").font(.system(size: 18, weight: .medium, design: .serif)) }
                HStack(spacing: 10) {
                    field("称谓") { TextField("陈璟", text: $salutation) }
                    field("落款") { Text("陈霁").foregroundColor(pal.ink2) }
                }
                field("信的题目") { TextField("写给此刻的你", text: $title).font(.system(size: 17, weight: .medium, design: .serif)) }
                field("正文") {
                    TextEditor(text: $letterBody).scrollContentBackground(.hidden).frame(minHeight: 220)
                }
                HStack(spacing: 10) {
                    field("祝颂语") { TextField("愿你一切安好", text: $blessing) }
                    field("附言（可选）") { TextField("", text: $postscript) }
                }
                HStack(spacing: 7) {
                    modeButton("立即寄出", "immediate")
                    modeButton("指定日期", "scheduled")
                    modeButton("锁几天", "locked")
                }
                if mode == "scheduled" {
                    DatePicker("寄出时间", selection: $deliverAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).font(.system(size: 12)).padding(12).paperCard(pal)
                } else if mode == "locked" {
                    HStack { Text("锁定"); Spacer(); Picker("锁定天数", selection: $lockDays) {
                        ForEach([1, 3, 7, 14, 30, 60, 90, 180, 365], id: \.self) { Text("\($0) 天").tag($0) }
                    }.pickerStyle(.menu) }
                    .font(.system(size: 12)).padding(12).paperCard(pal)
                }
                // 任务#1359：这个勾只有"上锁"时才拿得出手。
                // 立刻寄的信通知和信封卡一起飞，没什么好选；定时信勾了会把卡
                // 提前拍到他聊天页、还写着"现在就能读"，可读信那道门没到点是拒的。
                if editing == nil && mode == "locked" {
                    Toggle(isOn: $announce) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("寄完先让他看见这个信封")
                                .font(.system(size: 12.5, design: .serif))
                            Text("他只看得见有一封信在等，看不见里面写了什么")
                                .font(.system(size: 10, design: .serif))
                                .foregroundColor(pal.ink2)
                        }
                    }
                    .tint(pal.blush)
                    .padding(12).paperCard(pal)
                }
                Button { send() } label: {
                    HStack { if sending { ProgressView().scaleEffect(0.7) }; Text(editing == nil ? "把信寄出去" : "保存这封定时信") }
                        .font(.system(size: 13, weight: .semibold, design: .serif)).frame(maxWidth: .infinity).frame(height: 47)
                        .background(pal.blush.opacity(0.82), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }.buttonStyle(.plain).disabled(sending || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || letterBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !error.isEmpty { Text(error).font(.system(size: 10.5)).foregroundColor(.red.opacity(0.8)) }
            }.padding(.horizontal, 18).padding(.bottom, 18)
        }
        .onAppear {
            guard let editing else { return }
            salutation = editing.salutation; title = editing.title; letterBody = editing.body
            blessing = editing.blessing; postscript = editing.postscript; mode = "scheduled"
            deliverAt = parse(editing.deliverAt) ?? deliverAt
        }
    }

    private var ornament: some View {
        HStack { Rectangle().frame(height: 0.5); Text("SEAL WHAT CANNOT BE SAID QUICKLY").font(.system(size: 7.5, design: .serif)).tracking(1.2).fixedSize(); Rectangle().frame(height: 0.5) }
            .foregroundColor(pal.ink2.opacity(0.55))
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 9.5)).foregroundColor(pal.ink2)
            content().font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(14).paperCard(pal)
    }

    private func modeButton(_ title: String, _ value: String) -> some View {
        Button { mode = value } label: {
            Text(title).font(.system(size: 11, weight: mode == value ? .semibold : .regular)).frame(maxWidth: .infinity).frame(height: 38)
                .background(mode == value ? pal.blush.opacity(0.62) : pal.paper, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(pal.line, lineWidth: 0.5))
        }.buttonStyle(.plain).disabled(editing != nil && value != "scheduled")
    }

    private func send() {
        sending = true; error = ""
        var payload: [String: Any] = ["sender": "chenji", "salutation": salutation, "title": title, "body": letterBody,
                                      "blessing": blessing, "postscript": postscript, "mode": mode]
        let path: String
        if let editing {
            path = "/letters/update"; payload["id"] = editing.id; payload["mode"] = "scheduled"
            payload["deliver_at"] = iso(deliverAt)
        } else {
            path = "/letters/send"
            if mode == "scheduled" { payload["deliver_at"] = iso(deliverAt) }
            if mode == "locked" { payload["lock_days"] = lockDays }
            // 切模式之前可能已经勾上了，这里再拦一道
            if announce && mode == "locked" { payload["announce"] = true }
        }
        Task { @MainActor in
            do {
                _ = try await NativeHouseAPI.object(path, method: "POST", body: payload)
                completed()
            } catch { self.error = "这封信没有寄出去，再试一次" }
            sending = false
        }
    }

    private func iso(_ date: Date) -> String {
        let out = ISO8601DateFormatter(); out.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return out.string(from: date)
    }

    private func parse(_ raw: String) -> Date? {
        let p = ISO8601DateFormatter(); p.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return p.date(from: raw)
    }
}

private struct LetterReadingSheet: View {
    let letter: LetterboxItem
    let pal: LetterboxPalette
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(letter.salutation.isEmpty ? letter.recipientName : letter.salutation)
                    Text(letter.title).font(.system(size: 22, weight: .medium, design: .serif))
                    Text(letter.body).font(.system(size: 16, design: .serif)).lineSpacing(10)
                    if !letter.blessing.isEmpty { Text(letter.blessing).font(.system(size: 16, design: .serif)) }
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(letter.senderName).font(.system(size: 16, design: .serif))
                        Text(dateText(letter.createdAt)).font(.system(size: 10)).foregroundColor(pal.ink2)
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                    if !letter.postscript.isEmpty {
                        Divider(); Text("附言：\(letter.postscript)").font(.system(size: 13, design: .serif)).foregroundColor(pal.ink2)
                    }
                }.padding(24).foregroundColor(pal.ink)
            }.background(pal.background.ignoresSafeArea())
                .navigationTitle("读信").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("收好") { dismiss() } } }
        }.preferredColorScheme(pal.dark ? .dark : .light)
    }
    private func dateText(_ raw: String) -> String {
        let p = ISO8601DateFormatter(); p.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = p.date(from: raw) else { return raw }
        let out = DateFormatter(); out.locale = Locale(identifier: "zh_CN"); out.dateFormat = "yyyy年M月d日"
        return out.string(from: date)
    }
}

private extension View {
    func paperCard(_ pal: LetterboxPalette) -> some View {
        background(pal.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(pal.line, lineWidth: 0.6))
    }
}
