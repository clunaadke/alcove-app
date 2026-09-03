import SwiftUI
import UIKit

// 棋牌室大厅。古早味 6s：壁纸铺底，拟物玻璃图标墙，白瓷房間卡。
// 三个游戏（斗地主/炸金花/UNO）都有原生牌桌，按 game 分流。

struct QipaiLobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("qipai.night") private var night = false
    @State private var games: [QipaiAPI.GameInfo] = []
    @State private var rooms: [QipaiAPI.RoomSummary] = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var createGame: QipaiAPI.GameInfo?
    @State private var tableRoute: QipaiTableRoute?
    @State private var joiningCode: String?
    @State private var showHistory = false
    @State private var swipedCode: String?      // 当前滑开的房卡
    @State private var deletingCode: String?    // 正在关的房

    private let gameIcons: [String: String] = [
        "ddz": "QipaiIconMustache",   // 地主的胡子
        "zjh": "QipaiIconClover",     // 炸金"花"
        "uno": "QipaiIconKitty",
        "daifugo": "QipaiIconPiano",  // 大富豪的钢琴
        "monopoly": "QipaiIconCity",  // 大富翁的城市
        "mahjong": "QipaiIconTile",   // 麻将的一张牌
    ]
    // 还在建的，先在图标墙占座（0828 大富翁转正后暂时空着）
    private let comingSoon: [(key: String, name: String, icon: String)] = []

    /// 全屏页自己管安全区（灵动岛 0828 她抓的）——容器不给垫，从窗口拿
    private var safeTop: CGFloat {
        // 0904：问 app 主窗，不问 key window（按住悬浮唱片时 key window 是那扇小窗，安全区为 0）
        let inset = FloatingOverlay.appWindow()?.safeAreaInsets.top ?? 0
        return max(inset, 14)
    }

    var body: some View {
        // 0828 连环案备忘：内容曾被撑宽/右偏 → 用 GeometryReader 钉死；
        // 但背景不能一起关进裁剪盒（会顶上留黑、壁纸像被放大），背景独立全屏铺。
        ZStack {
            background
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        iconWall
                        roomSection
                        QipaiWhisper(text: night ? "the den never sleeps." : "will you stay or leave?")
                            .padding(.bottom, 26)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, safeTop + 6)
                    .frame(width: geo.size.width)
                }
                .refreshable { await reload() }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
        }
        // 调色盘是静态计算属性，切日夜靠整树重建（牌桌只能从这里进，不会中途换肤）
        .id(night)
        .onAppear { QipaiPalette.night = night }
        .task { await reload() }
        .sheet(item: $createGame) { game in
            QipaiCreateRoomSheet(game: game) { created in
                createGame = nil
                Task { await reload() }
                // 等建房面板收完再开牌桌，不然第二层弹层会被吃掉
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    tableRoute = QipaiTableRoute(code: created.code, game: created.game)
                }
            }
        }
        .fullScreenCover(item: $tableRoute) { route in
            switch route.game {
            case "zjh":
                QipaiZjhTableView(code: route.code) {
                    tableRoute = nil
                    Task { await reload() }
                }
            case "uno":
                QipaiUnoTableView(code: route.code) {
                    tableRoute = nil
                    Task { await reload() }
                }
            case "daifugo":
                QipaiDaifugoTableView(code: route.code) {
                    tableRoute = nil
                    Task { await reload() }
                }
            case "monopoly":
                QipaiMonopolyTableView(code: route.code) {
                    tableRoute = nil
                    Task { await reload() }
                }
            case "mahjong":
                QipaiMahjongTableView(code: route.code) {
                    tableRoute = nil
                    Task { await reload() }
                }
            default:
                QipaiDdzTableView(code: route.code) {
                    tableRoute = nil
                    Task { await reload() }
                }
            }
        }
        .sheet(isPresented: $showHistory) { QipaiHistorySheet() }
    }

    // MARK: 背景

    private var background: some View {
        // 她 0828 拍板：壁纸用干净不带线条那张原图，不加噪点不加雾。
        // 夜版走程序压暗（她亲自对比过，比她手调的好看，反悔记录在案 #762）。
        ZStack {
            QipaiPalette.fog.ignoresSafeArea()
            // ‼️壁纸锁进 overlay+clipped 笼子（同 QipaiTableShell 的注释）：
            // 裸 scaledToFill 上报超屏尺寸撑大画布，就是「撑宽/右偏」悬案的根因
            Color.clear
                .overlay(Image("QipaiWallPortrait2").resizable().scaledToFill())
                .clipped()
                .ignoresSafeArea()
            if night {
                Color.black.opacity(0.62).ignoresSafeArea()
            }
        }
    }

    // MARK: 题头（居中古早宋体 + 天使翅膀）

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                VStack(spacing: 3) {
                    Text("棋牌室")
                        .font(.qipaiDisplay(36))
                        .foregroundColor(QipaiPalette.ink)
                    Text("MOON DEN")
                        .font(.qipaiHand(11))
                        .tracking(3)
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
                    Button {
                        night.toggle()
                        QipaiPalette.night = night
                    } label: {
                        Image(systemName: night ? "moon.stars.fill" : "sun.max")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(QipaiEmbossedButtonStyle())
                }
            }
            Image("QipaiWings")
                .resizable().scaledToFit()   // 0829 她要的：宽度跟面板对齐（撤掉额外内缩）
        }
    }

    // MARK: 图标墙

    private var iconWall: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("玩什麼", note: "pick a table")
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
        .qipaiPanel(corner: 20, dotted: true)   // 0829 她点名换回白瓷波点（f00e64e 误伤）
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
                // 夜里图标不压暗，保持亮着（0828 她拍板：73cbdbe 那版的样子）
                Text(name)
                    .font(.qipaiMemo(14))
                    .foregroundColor(QipaiPalette.ink)
                Text(caption)
                    .font(.system(size: 9.5))
                    .foregroundColor(QipaiPalette.inkDim)
            }
        }
        .buttonStyle(.plain)
        .disabled(dimmed)
    }

    // MARK: 房間列表

    private var roomSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("房間", note: "on the table")
                Spacer()
                Button {
                    showHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 10, weight: .semibold))
                        Text("戰績")
                    }
                }
                .buttonStyle(QipaiEmbossedButtonStyle())
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
                // 0829 她要的：面板里按状态分组——已開場 / 候場 / 關房，空组不占地
                roomGroup("已開場", note: "in play",
                          rooms.filter { $0.started && !$0.finished })
                roomGroup("候場", note: "waiting",
                          rooms.filter { !$0.started })
                roomGroup("關房", note: "wrapped",
                          rooms.filter { $0.finished })
            }
        }
        .padding(14)
        .qipaiPanel(corner: 20, dotted: true)   // 同上：房間区跟图标墙一致
    }

    /// 房間面板里的状态小组：小标签头 + 该状态下的房卡；一间都没有就整组不出现
    @ViewBuilder private func roomGroup(_ title: String, note: String,
                                        _ list: [QipaiAPI.RoomSummary]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.qipaiMemo(13))
                        .foregroundColor(QipaiPalette.inkDim)
                    QipaiWhisper(text: note)
                    Spacer()
                    Text("\(list.count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(QipaiPalette.inkDim.opacity(0.8))
                }
                .padding(.horizontal, 3)
                ForEach(list) { room in roomRow(room) }
            }
            .padding(.top, 2)
        }
    }

    /// 房卡 + 左滑删除（0829 她要的）：滑开露出红色删除钮，点了就关房。
    /// 开过局的服务端自动归档进战绩，没开局的直接消失。
    private func roomRow(_ room: QipaiAPI.RoomSummary) -> some View {
        ZStack(alignment: .trailing) {
            Button {
                Task { await deleteRoom(room) }
            } label: {
                VStack(spacing: 3) {
                    if deletingCode == room.code {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                        Text("删除").font(.system(size: 10, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 64)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(QipaiPalette.red))
            }
            .buttonStyle(.plain)
            .disabled(deletingCode != nil)

            roomCard(room)
                .offset(x: swipedCode == room.code ? -76 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipedCode)
                .onTapGesture {
                    // 有滑开的卡时，第一下点击只收回，不进房
                    if swipedCode != nil { swipedCode = nil }
                    else { Task { await enter(room) } }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { v in
                            guard abs(v.translation.width) > abs(v.translation.height) else { return }
                            if v.translation.width < -40 {
                                swipedCode = room.code
                            } else if v.translation.width > 30, swipedCode == room.code {
                                swipedCode = nil
                            }
                        }
                )
        }
    }

    @MainActor private func deleteRoom(_ room: QipaiAPI.RoomSummary) async {
        swipedCode = nil
        deletingCode = room.code
        defer { deletingCode = nil }
        do {
            try await QipaiAPI.closeRoom(code: room.code,
                                         service: QipaiAPI.service(for: room.game))
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    // 0829 误触修复：不再用 Button（它对手指位移太宽容，左滑抬手也算点击），
    // 点击改在 roomRow 里用 onTapGesture 挂——真滑动不会被认成 tap
    private func roomCard(_ room: QipaiAPI.RoomSummary) -> some View {
        Group {
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
        .contentShape(Rectangle())
    }

    private func sectionTitle(_ title: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
                .font(.qipaiMemo(16))
                .foregroundColor(QipaiPalette.ink)
            QipaiWhisper(text: note)
        }
    }

    // MARK: 动作

    @MainActor private func reload() async {
        loading = true
        defer { loading = false }
        do {
            // cards 枢纽必须活着；daifugo / monopoly 是独立服务，挂了不拖累整个大厅
            let main = try await QipaiAPI.lobby()
            let dai = try? await QipaiAPI.lobby(service: "daifugo")
            let mono = try? await QipaiAPI.lobby(service: "monopoly")
            games = main.games + (dai?.games ?? []) + (mono?.games ?? [])
            rooms = (main.rooms + (dai?.rooms ?? []) + (mono?.rooms ?? []))
                .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor private func enter(_ room: QipaiAPI.RoomSummary) async {
        // 已結束的房不再入座，直接进去看战绩；其余先把座占上（有旧凭证就是复座）
        if room.finished {
            tableRoute = QipaiTableRoute(code: room.code, game: room.game)
            return
        }
        joiningCode = room.code
        defer { joiningCode = nil }
        do {
            let name = QipaiAPI.nickname.isEmpty ? "陈霁" : QipaiAPI.nickname
            _ = try await QipaiAPI.join(code: room.code, name: name,
                                        service: QipaiAPI.service(for: room.game))
            tableRoute = QipaiTableRoute(code: room.code, game: room.game)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct QipaiTableRoute: Identifiable {
    let code: String
    let game: String
    var id: String { code }
}

// MARK: - 建房面板

struct QipaiCreateRoomSheet: View {
    let game: QipaiAPI.GameInfo
    var onCreated: (QipaiAPI.RoomSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var roomName = ""
    @State private var nickname = QipaiAPI.nickname
    @State private var aiPrompts: [String: String] = [:]   // 每个 AI 单独的人设
    @State private var rulesExpanded = false
    @State private var aiExpanded = true
    @State private var flagRules: [String: Bool] = [:]
    @State private var numberRules: [String: String] = [:]
    @State private var aiSeats: [String: Bool] = ["external": false, "opus": false,
                                                  "sonnet": false, "haiku": false]
    @State private var working = false
    @State private var errorText: String?

    private let aiRoster: [(id: String, name: String, note: String)] = [
        ("chenjing", "陈璟", "真身。简报送进主聊天，他出牌要等他回神"),
        ("external", "Fable·工程师", "工作室那位真身，带记忆，出牌要等他几秒"),
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
                        Text("開個新房間 · \(game.name)")
                            .font(.qipaiMemo(19))
                            .foregroundColor(QipaiPalette.ink)
                        Spacer()
                        Button("先不了") { dismiss() }
                            .buttonStyle(QipaiEmbossedButtonStyle())
                    }
                    Text(game.playersLabel)
                        .font(.system(size: 11)).foregroundColor(QipaiPalette.inkDim)

                    field("房间名") {
                        TextField("", text: $roomName,
                                  prompt: Text("比如「周五晚上别睡」")
                                    .foregroundColor(QipaiPalette.inkDim.opacity(0.7)))
                    }
                    field("你的昵称") {
                        TextField("", text: $nickname,
                                  prompt: Text("上桌用的名字")
                                    .foregroundColor(QipaiPalette.inkDim.opacity(0.7)))
                    }

                    // 大富翁没有可选规则，整块不出现
                    if !game.ruleMeta.isEmpty { rulesBox }
                    aiBox

                    if let errorText {
                        Text(errorText).font(.system(size: 12)).foregroundColor(QipaiPalette.red)
                    }

                    if working {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                    } else {
                        QipaiSlideControl(label: "slide to 開房") { Task { await create() } }
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
                    .fill(QipaiPalette.fieldBg))
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
                        Text("可選規則").font(.qipaiMemo(15))
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
                        Text("請誰來玩").font(.qipaiMemo(15))
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
                        VStack(spacing: 8) {
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
                            // 勾上才弹出这个 AI 自己的人设框（0829 她要的：这个毒舌那个温柔）
                            if aiSeats[ai.id] ?? false {
                                TextField("", text: Binding(
                                    get: { aiPrompts[ai.id] ?? "" },
                                    set: { aiPrompts[ai.id] = $0 }),
                                          prompt: Text("给 \(ai.name) 的人设/规矩（可空）")
                                            .foregroundColor(QipaiPalette.inkDim.opacity(0.7)),
                                          axis: .vertical)
                                    .lineLimit(1...3)
                                    .font(.system(size: 12))
                                    .foregroundColor(QipaiPalette.ink)
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(QipaiPalette.fieldBg))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(QipaiPalette.inkDim.opacity(0.45), lineWidth: 1))
                            }
                        }
                        .padding(11)
                        .qipaiPanel(corner: 13)
                    }
                    QipaiWhisper(text: "真身出牌要等工作室醒，急不得。")
                }
                .padding([.horizontal, .bottom], 11)
            }
        }
        .qipaiPanel(corner: 16)
    }

    private var aiSummary: String {
        let picked = aiRoster.filter { aiSeats[$0.id] ?? false }.map(\.name)
        return picked.isEmpty ? "這局只有人類（也可以之後再喊）" : picked.joined(separator: " · ")
    }

    @MainActor private func create() async {
        let name = nickname.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { errorText = "先起個上桌的名字"; return }
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
            let service = QipaiAPI.service(for: game.key)
            // 只送勾上的 AI 的非空人设
            var prompts: [String: String] = [:]
            for id in ai {
                let p = (aiPrompts[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !p.isEmpty { prompts[id] = p }
            }
            let created = try await QipaiAPI.createRoom(
                game: game.key,
                name: roomName.trimmingCharacters(in: .whitespaces),
                rules: rules, aiPlayers: ai,
                aiPrompts: prompts)
            _ = try await QipaiAPI.join(code: created.code, name: name, service: service)
            UserDefaults.standard.set(created.inviteToken, forKey: "qipai.invite.\(created.code)")
            // 房主入座后 AI 才落座；拉一次大厅拿回真实座次
            let lobby = try await QipaiAPI.lobby(service: service)
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
