import SwiftUI
import UIKit

// 棋牌室大厅。古早味 6s：壁纸铺底 + 雾 + 噪点，拟物玻璃图标墙，白瓷房间卡。
// 牌桌页是第 2 期，现在进房先给施工占位页。

struct QipaiLobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var games: [QipaiAPI.GameInfo] = []
    @State private var rooms: [QipaiAPI.RoomSummary] = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var createGame: QipaiAPI.GameInfo?
    @State private var openedRoom: QipaiAPI.RoomSummary?
    @State private var tableRoute: QipaiTableRoute?
    @State private var joiningCode: String?

    private let gameIcons: [String: String] = [
        "ddz": "QipaiIconMustache",   // 地主的胡子
        "zjh": "QipaiIconClover",     // 炸金"花"
        "uno": "QipaiIconKitty",
    ]
    // 第 4 期的两位，先在图标墙占座
    private let comingSoon: [(key: String, name: String, icon: String)] = [
        ("daifugo", "大富豪", "QipaiIconPiano"),
        ("monopoly", "大富翁", "QipaiIconCity"),
    ]

    /// 全屏页自己管安全区（灵动岛 0828 她抓的）——容器不给垫，从窗口拿
    private var safeTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let inset = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 0
        return max(inset, 14)
    }

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    iconWall
                    roomSection
                    QipaiWhisper(text: "will you stay or leave?")
                        .padding(.bottom, 26)
                }
                .padding(.horizontal, 16)
                .padding(.top, safeTop + 6)
            }
            .refreshable { await reload() }
        }
        .task { await reload() }
        .sheet(item: $createGame) { game in
            QipaiCreateRoomSheet(game: game) { created in
                createGame = nil
                Task { await reload() }
                // 等建房面板收完再开房间页，不然第二个 sheet 会被吃掉
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    if created.game == "ddz" {
                        tableRoute = QipaiTableRoute(code: created.code)
                    } else {
                        openedRoom = created
                    }
                }
            }
        }
        .sheet(item: $openedRoom) { room in
            QipaiTableStubView(room: room)
        }
        .fullScreenCover(item: $tableRoute) { route in
            QipaiDdzTableView(code: route.code) {
                tableRoute = nil
                Task { await reload() }
            }
        }
    }

    // MARK: 背景

    private var background: some View {
        // 她 0828 拍板：壁纸用干净不带线条那张原图，不加噪点不加雾
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            Image("QipaiWallPortrait2")
                .resizable().scaledToFill()
                .ignoresSafeArea()
        }
    }

    // MARK: 题头（居中古早宋体 + 天使翅膀）

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                VStack(spacing: 3) {
                    Text("棋牌室")
                        .font(.custom("Songti SC", size: 30).weight(.black))
                        .foregroundColor(QipaiPalette.ink)
                    Text("M O O N   D E N")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(QipaiPalette.inkDim)
                }
                .frame(maxWidth: .infinity)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle())
                    Spacer()
                }
            }
            Image("QipaiWings")
                .resizable().scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
        }
    }

    // MARK: 图标墙

    private var iconWall: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("玩什么", note: "pick a table")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 13), count: 3),
                      spacing: 15) {
                ForEach(games) { game in
                    gameTile(name: game.name, caption: game.playersLabel,
                             icon: gameIcons[game.key] ?? "QipaiIconDots",
                             dimmed: !game.ready) {
                        if game.ready { createGame = game }
                    }
                }
                ForEach(comingSoon, id: \.key) { item in
                    gameTile(name: item.name, caption: "在建", icon: item.icon, dimmed: true) {}
                }
            }
        }
        .padding(14)
        .qipaiPanel(corner: 20, dotted: true)
    }

    private func gameTile(name: String, caption: String, icon: String,
                          dimmed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                QipaiGlassTile(corner: 19) {
                    Image(icon)
                        .resizable().scaledToFill()
                        .frame(width: 74, height: 74)
                }
                .frame(width: 74, height: 74)
                .saturation(dimmed ? 0.4 : 1)
                .opacity(dimmed ? 0.55 : 1)
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(QipaiPalette.ink)
                Text(caption)
                    .font(.system(size: 9.5))
                    .foregroundColor(QipaiPalette.inkDim)
            }
        }
        .buttonStyle(.plain)
        .disabled(dimmed)
    }

    // MARK: 房间列表

    private var roomSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("房间", note: "on the table")
                Spacer()
                Button {
                    Task { await reload() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold))
                        Text("刷新")
                    }
                }
                .buttonStyle(QipaiEmbossedButtonStyle())
            }

            if loading && rooms.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 26)
            } else if let errorText {
                VStack(spacing: 8) {
                    Text(errorText).font(.system(size: 12)).foregroundColor(QipaiPalette.red)
                    Button("再试一次") { Task { await reload() } }
                        .buttonStyle(QipaiEmbossedButtonStyle())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else if rooms.isEmpty {
                VStack(spacing: 5) {
                    Text("还没有房间").font(.system(size: 12.5)).foregroundColor(QipaiPalette.inkDim)
                    QipaiWhisper(text: "there are no answers.")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 22)
            } else {
                ForEach(rooms) { room in roomCard(room) }
            }
        }
    }

    private func roomCard(_ room: QipaiAPI.RoomSummary) -> some View {
        Button {
            Task { await enter(room) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(room.name.isEmpty ? room.gameName : room.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(QipaiPalette.ink)
                        .lineLimit(1)
                    Spacer()
                    if joiningCode == room.code {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(QipaiPalette.inkDim)
                    }
                }
                HStack(spacing: 6) {
                    QipaiChip(text: room.statusLabel,
                              tone: room.finished ? .done : (room.started ? .live : .neutral))
                    Text("\(room.code) · \(room.playerCount)/\(room.maxPlayers) 人")
                        .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                    if room.round > 0 {
                        Text("第 \(room.round) 轮")
                            .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)
                    }
                    if room.hasAI { QipaiChip(text: "AI 在座", tone: .live, icon: "sparkles") }
                }
                HStack(spacing: 5) {
                    if room.hasMySeat { QipaiChip(text: "有你的座位", tone: .live, icon: "person.fill") }
                    ForEach(room.players) { seat in
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

    private func sectionTitle(_ title: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
                .font(.system(size: 13.5, weight: .bold, design: .serif))
                .foregroundColor(QipaiPalette.ink)
            QipaiWhisper(text: note)
        }
    }

    // MARK: 动作

    @MainActor private func reload() async {
        loading = true
        defer { loading = false }
        do {
            let lobby = try await QipaiAPI.lobby()
            games = lobby.games
            rooms = lobby.rooms
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor private func enter(_ room: QipaiAPI.RoomSummary) async {
        // 斗地主走原生牌桌；炸金花/UNO 还是占位页（第 3 期换）。
        // 已结束的房不再入座，直接进去看战绩/占位；其余先把座占上（有旧凭证就是复座）。
        if room.finished {
            if room.game == "ddz" { tableRoute = QipaiTableRoute(code: room.code) }
            else { openedRoom = room }
            return
        }
        joiningCode = room.code
        defer { joiningCode = nil }
        do {
            let name = QipaiAPI.nickname.isEmpty ? "陈霁" : QipaiAPI.nickname
            _ = try await QipaiAPI.join(code: room.code, name: name)
            if room.game == "ddz" { tableRoute = QipaiTableRoute(code: room.code) }
            else { openedRoom = room }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct QipaiTableRoute: Identifiable {
    let code: String
    var id: String { code }
}

// MARK: - 建房面板

struct QipaiCreateRoomSheet: View {
    let game: QipaiAPI.GameInfo
    var onCreated: (QipaiAPI.RoomSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var roomName = ""
    @State private var nickname = QipaiAPI.nickname
    @State private var rulesExpanded = false
    @State private var aiExpanded = true
    @State private var flagRules: [String: Bool] = [:]
    @State private var numberRules: [String: String] = [:]
    @State private var aiSeats: [String: Bool] = ["external": false, "opus": false,
                                                  "sonnet": false, "haiku": false]
    @State private var working = false
    @State private var errorText: String?

    private let aiRoster: [(id: String, name: String, note: String)] = [
        ("external", "工程师·本人档", "工作室那位，带记忆，出牌要等他几秒"),
        ("opus", "分身·Opus", "话多，牌品未知"),
        ("sonnet", "分身·Sonnet", "手快"),
        ("haiku", "分身·Haiku", "省着用的小脑子"),
    ]

    var body: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            QipaiDots(spacing: 16, radius: 1.3, opacity: 0.28).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("开个新房间 · \(game.name)")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundColor(QipaiPalette.ink)
                        Spacer()
                        Button("先不了") { dismiss() }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                    }
                    Text(game.playersLabel)
                        .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)

                    field("房间名") {
                        TextField("比如「周五晚上别睡」", text: $roomName)
                    }
                    field("你的昵称") {
                        TextField("上桌用的名字", text: $nickname)
                    }

                    rulesBox
                    aiBox

                    if let errorText {
                        Text(errorText).font(.system(size: 12)).foregroundColor(QipaiPalette.red)
                    }

                    if working {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                    } else {
                        QipaiSlideControl(label: "slide to 开房") { Task { await create() } }
                    }
                    QipaiWhisper(text: "no real money. only face.")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(16)
            }
        }
        .onAppear {
            for rule in game.ruleMeta {
                if rule.def.isFlag { flagRules[rule.key] = rule.def.boolValue }
                else { numberRules[rule.key] = String(Int(rule.def.numberValue)) }
            }
        }
    }

    // 0828 构建修复：这个小工具当初调了没写，编译器当场抓获
    private func field<Content: View>(_ label: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(QipaiPalette.inkDim)
            content()
                .font(.system(size: 14))
                .foregroundColor(QipaiPalette.ink)
                .padding(.horizontal, 13).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white))
                // 白底白框看不清（0828 她抓的），描边加深
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(QipaiPalette.inkDim.opacity(0.55), lineWidth: 1.2))
        }
    }

    private var rulesBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { rulesExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "scroll")
                        .font(.system(size: 12)).foregroundColor(QipaiPalette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("可选规则").font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(QipaiPalette.ink)
                        Text(rulesSummary).font(.system(size: 10.5))
                            .foregroundColor(QipaiPalette.inkDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(QipaiPalette.inkDim)
                        .rotationEffect(.degrees(rulesExpanded ? 180 : 0))
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if rulesExpanded {
                VStack(spacing: 9) {
                    ForEach(game.ruleMeta) { rule in
                        if rule.def.isFlag {
                            HStack {
                                ruleText(rule)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { flagRules[rule.key] ?? false },
                                    set: { flagRules[rule.key] = $0 }))
                                .labelsHidden()
                                .tint(QipaiPalette.accent)
                            }
                            .padding(11)
                            .qipaiPanel(corner: 13)
                        } else {
                            HStack {
                                ruleText(rule)
                                Spacer()
                                TextField("", text: Binding(
                                    get: { numberRules[rule.key] ?? "" },
                                    set: { numberRules[rule.key] = $0.filter(\.isNumber) }))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(QipaiPalette.ink)
                                .frame(width: 74)
                                .padding(.vertical, 5).padding(.horizontal, 8)
                                .background(RoundedRectangle(cornerRadius: 9)
                                    .fill(QipaiPalette.panelDeep))
                            }
                            .padding(11)
                            .qipaiPanel(corner: 13)
                        }
                    }
                }
                .padding([.horizontal, .bottom], 11)
            }
        }
        .qipaiPanel(corner: 16)
    }

    private var rulesSummary: String {
        let on = game.ruleMeta.filter { $0.def.isFlag && (flagRules[$0.key] ?? false) }
            .map(\.label)
        return on.isEmpty ? "全关（最朴素的打法）" : on.joined(separator: " · ")
    }

    private func ruleText(_ rule: QipaiAPI.RuleMeta) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rule.label).font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(QipaiPalette.ink)
            Text(rule.note).font(.system(size: 10))
                .foregroundColor(QipaiPalette.inkDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aiBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { aiExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12)).foregroundColor(QipaiPalette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("请谁上桌").font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(QipaiPalette.ink)
                        Text(aiSummary).font(.system(size: 10.5))
                            .foregroundColor(QipaiPalette.inkDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(QipaiPalette.inkDim)
                        .rotationEffect(.degrees(aiExpanded ? 180 : 0))
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if aiExpanded {
                VStack(spacing: 9) {
                    ForEach(aiRoster, id: \.id) { ai in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ai.name).font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(QipaiPalette.ink)
                                Text(ai.note).font(.system(size: 10))
                                    .foregroundColor(QipaiPalette.inkDim)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { aiSeats[ai.id] ?? false },
                                set: { aiSeats[ai.id] = $0 }))
                            .labelsHidden()
                            .tint(QipaiPalette.accent)
                        }
                        .padding(11)
                        .qipaiPanel(corner: 13)
                    }
                    QipaiWhisper(text: "陈璟的本人档还没接，先别惦记。")
                }
                .padding([.horizontal, .bottom], 11)
            }
        }
        .qipaiPanel(corner: 16)
    }

    private var aiSummary: String {
        let picked = aiRoster.filter { aiSeats[$0.id] ?? false }.map(\.name)
        return picked.isEmpty ? "这局只有人类（也可以之后再喊）" : picked.joined(separator: " · ")
    }

    @MainActor private func create() async {
        let name = nickname.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { errorText = "先起个上桌的名字"; return }
        QipaiAPI.nickname = name
        working = true
        defer { working = false }
        do {
            var rules: [String: Any] = [:]
            for rule in game.ruleMeta {
                if rule.def.isFlag { rules[rule.key] = flagRules[rule.key] ?? false }
                else if let text = numberRules[rule.key], let n = Int(text) { rules[rule.key] = n }
            }
            let ai = aiRoster.map(\.id).filter { aiSeats[$0] ?? false }
            let created = try await QipaiAPI.createRoom(
                game: game.key,
                name: roomName.trimmingCharacters(in: .whitespaces),
                rules: rules, aiPlayers: ai)
            _ = try await QipaiAPI.join(code: created.code, name: name)
            UserDefaults.standard.set(created.inviteToken, forKey: "qipai.invite.\(created.code)")
            // 房主入座后 AI 才落座；拉一次大厅拿回真实座次
            let lobby = try await QipaiAPI.lobby()
            if let summary = lobby.rooms.first(where: { $0.code == created.code }) {
                onCreated(summary)
            } else {
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - 牌桌占位页（第 2 期换成真牌桌）

struct QipaiTableStubView: View {
    let room: QipaiAPI.RoomSummary
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var inviteLink: String? {
        guard let token = UserDefaults.standard.string(forKey: "qipai.invite.\(room.code)"),
              !token.isEmpty else { return nil }
        return QipaiAPI.inviteLink(code: room.code, inviteToken: token)
    }

    var body: some View {
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            Image("QipaiWallPortrait2")
                .resizable().scaledToFill().ignoresSafeArea().opacity(0.55)
            QipaiPalette.fog.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Image("QipaiIconScene")
                    .resizable().scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .qipaiPanel(corner: 21)
                Text(room.name.isEmpty ? room.gameName : room.name)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(QipaiPalette.ink)
                HStack(spacing: 6) {
                    QipaiChip(text: room.gameName)
                    QipaiChip(text: room.code, icon: "number")
                    QipaiChip(text: "\(room.playerCount)/\(room.maxPlayers) 人")
                }
                Text("你的座位已经占好了。\n原生牌桌正在第 2 期施工，这一局先用网页版打：")
                    .font(.system(size: 12.5))
                    .foregroundColor(QipaiPalette.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Link("qipai.ob-memory.uk/cards",
                     destination: URL(string: "https://qipai.ob-memory.uk/cards/")!)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(QipaiPalette.accent)
                if let inviteLink {
                    Button {
                        UIPasteboard.general.string = inviteLink
                        copied = true
                    } label: {
                        Label(copied ? "邀请链接已复制" : "复制邀请链接",
                              systemImage: copied ? "checkmark" : "link")
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle(prominent: true))
                }
                Spacer()
                Button("回大厅") { dismiss() }
                    .buttonStyle(QipaiEmbossedButtonStyle())
                QipaiWhisper(text: "the table is being built. stay.")
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 28)
        }
    }
}
