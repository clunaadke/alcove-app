import SwiftUI
import AVFoundation
import UIKit

// 共影室（2026-08-25 起，0826 大修）。片单粘链接进来，后端把字幕、听写和画面网格备好；
// 播放页是一块能往上拉的布：一档看片、二档边看边聊、三档翻记录。
//
// 0826 修的四件（她说的原话：听不见声音、开始播很慢、没有进度条、布局要重排）：
//   · 声音：这一页从来没配过 AVAudioSession，走的是默认的 soloAmbient，
//     手机侧边静音键一拨就整页没声。别的页面都配了，就这里漏了。
//   · 慢：后端每个 Range 请求都重解析一次直链，现在加了缓存（cowatch.py）。
//   · 进度条：以前只有一层裸 AVPlayerLayer，一个控件都没有。
//   · 布局：画面高度以前按屏幕百分比切，16:9 的片子上下能空出两百多点黑边；
//     现在按视频自己的宽高比算。

struct CowatchItem: Identifiable, Hashable {
    let id: String
    let source: String
    let url: String
    let title: String
    let uploader: String
    let duration: Int
    let status: String
    let transcriptFrom: String
    let cover: String
    let note: String
    let progress: Int

    init(_ row: [String: Any]) {
        id = row["id"] as? String ?? ""
        source = row["source"] as? String ?? ""
        url = row["url"] as? String ?? ""
        title = row["title"] as? String ?? ""
        uploader = row["uploader"] as? String ?? ""
        duration = row["duration"] as? Int ?? 0
        status = row["status"] as? String ?? ""
        transcriptFrom = row["transcript_from"] as? String ?? ""
        cover = row["cover"] as? String ?? ""
        note = row["note"] as? String ?? ""
        progress = row["progress"] as? Int ?? 0
    }

    var stateLine: String {
        switch status {
        case "ready": return transcriptFrom.isEmpty ? "没有台词" : "\(transcriptFrom)就绪"
        case "pending": return "正在听"
        case "failed": return note.isEmpty ? "没弄成" : note
        default: return status
        }
    }
    var lengthLine: String { CowatchClock.stamp(duration) }
}

enum CowatchClock {
    static func stamp(_ seconds: Int) -> String {
        let value = max(0, seconds)
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

// 客厅那套 foyerCard 关在 NativeHouseViews 的 private extension 里，跨文件够不着。
// 这间屋子自己留一张同样气质的卡片。
private extension View {
    func cowatchCard(_ theme: AlcoveTheme) -> some View {
        background(theme.fyCard, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(theme.textDim.opacity(0.14), lineWidth: 0.7)
            )
    }
}

// MARK: - 片单

struct NativeCowatchView: View {
    @AppStorage("alcoveTheme") private var themeName = "haven"
    @State private var items: [CowatchItem] = []
    @State private var link = ""
    @State private var importing = false
    @State private var hint: String?
    @State private var opened: CowatchItem?
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    TextField("粘一条 B站 / YouTube 链接", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13))
                        .padding(.horizontal, 13).frame(height: 40)
                        .background(theme.fyCardSub, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        Task { await importLink() }
                    } label: {
                        Text(importing ? "在处理" : "接进来")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 15).frame(height: 40)
                            .background(theme.fyAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(theme.fyAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(importing || link.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let hint {
                    Text(hint).font(.system(size: 12)).foregroundColor(theme.textDim)
                }

                if items.isEmpty {
                    Text("片单还空着。扔一条链接进来，字幕、听写和画面我先备好，然后我们一起看")
                        .font(.system(size: 13)).foregroundColor(theme.textDim)
                        .padding(.vertical, 22)
                } else {
                    ForEach(items) { item in
                        Button { if item.status == "ready" { opened = item } } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
        }
        .foregroundColor(theme.text)
        .task { await load() }
        .refreshable { await load() }
        .fullScreenCover(item: $opened) { item in
            CowatchPlayerView(item: item) { opened = nil }
        }
    }

    private func row(_ item: CowatchItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(theme.fyCardSub)
                if item.status == "pending" { ProgressView().scaleEffect(0.7) }
                else { Image(systemName: "film").font(.system(size: 15)).foregroundColor(theme.textDim) }
            }
            .frame(width: 74, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 13.5, weight: .medium))
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text("\(item.source) · \(item.uploader)")
                    .font(.system(size: 11)).foregroundColor(theme.textDim).lineLimit(1)
                HStack(spacing: 7) {
                    Text(item.lengthLine).font(.system(size: 10.5, design: .monospaced))
                    Text(item.stateLine).font(.system(size: 10.5))
                        .foregroundColor(item.status == "ready" ? theme.fyAccent : theme.textDim)
                        .lineLimit(1)
                    if item.progress > 3 && item.duration > 0 {
                        Text("看到 \(CowatchClock.stamp(item.progress))")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(theme.fyAccent.opacity(0.8))
                    }
                }
                .foregroundColor(theme.textDim)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cowatchCard(theme)
    }

    @MainActor private func load() async {
        guard let value = try? await NativeHouseAPI.object("/api/cowatch/list") else { return }
        items = (value["items"] as? [[String: Any]] ?? []).map(CowatchItem.init)
    }

    @MainActor private func importLink() async {
        let target = link.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        importing = true
        defer { importing = false }
        let reply = try? await NativeHouseAPI.objectIncludingHTTPError(
            "/api/cowatch/import", method: "POST", body: ["url": target])
        if let reply, reply["ok"] as? Bool == true {
            link = ""
            hint = "接住了，正在把台词和画面备出来"
            await load()
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await load()
        } else {
            hint = reply?["error"] as? String ?? "这条没接住"
        }
    }
}

// MARK: - 播放

struct CowatchPlayerView: View {
    let item: CowatchItem
    var onClose: () -> Void

    @AppStorage("alcoveTheme") private var themeName = "haven"
    @StateObject private var deck = CowatchDeck()
    @State private var gear = 0
    @State private var dragOffset: CGFloat = 0
    @State private var tab = 0
    @State private var draft = ""
    @State private var fullscreen = false
    // 打完字点别处键盘收不回去，这一页从来没管过焦点（0826 她说的）
    @FocusState private var typing: Bool
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height

            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if gear < 2 {
                        ZStack(alignment: .top) {
                            CowatchScreen(player: deck.player)
                                .frame(height: stageHeight(W: W, H: H))
                                .clipped()
                                // 打完字戳一下画面就收键盘（0826 她说点别处下不去）
                                .contentShape(Rectangle())
                                .onTapGesture { typing = false }
                            topBar.padding(.horizontal, 14).padding(.top, geo.safeAreaInsets.top + 6)
                        }
                        controlBar
                    }
                    talkDeck
                }

                if gear == 2 {
                    miniWindow.padding(.top, geo.safeAreaInsets.top + 8).padding(.trailing, 12)
                }

                if fullscreen {
                    CowatchFullscreen(deck: deck) { fullscreen = false }
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: gear)
        }
        .ignoresSafeArea(edges: .top)
        .task { await deck.open(item: item) }
        .onDisappear { deck.close() }
        .statusBarHidden(true)
    }

    /// 画面按视频自己的宽高比撑，不再按屏幕百分比切。
    /// 16:9 的片子在 393 宽下真实高度就是 221 点，以前给它 647 点，上下白空 213 点黑边。
    private func stageHeight(W: CGFloat, H: CGFloat) -> CGFloat {
        let natural = W / max(0.4, deck.aspect)
        let cap = gear == 0 ? H * 0.74 : H * 0.40
        return max(140, min(natural, cap))
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { deck.close(); onClose() } label: {
                Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.4), in: Circle())
            }.buttonStyle(.plain)

            HStack(spacing: 5) {
                Circle().fill(theme.fyAccent).frame(width: 5, height: 5)
                Text("同刻 \(CowatchClock.stamp(Int(deck.current)))")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(theme.fyAccent)
            .padding(.horizontal, 10).frame(height: 26)
            .background(Color.black.opacity(0.42), in: Capsule())

            Spacer()

            Button { withAnimation(.easeInOut(duration: 0.22)) { fullscreen = true } } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.4), in: Circle())
            }.buttonStyle(.plain)
        }
        .foregroundColor(.white)
    }

    // MARK: 进度条与传送键（0826 新增，以前这一整条都没有）

    private var controlBar: some View {
        VStack(spacing: 6) {
            CowatchScrubber(deck: deck, tint: theme.fyAccent)
                .frame(height: 26)

            HStack {
                Text(CowatchClock.stamp(Int(deck.shownTime)))
                Spacer()
                Text(CowatchClock.stamp(max(0, Int(deck.duration - deck.shownTime))) )
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.55))

            HStack(spacing: 26) {
                Button { deck.nudge(-15) } label: {
                    Image(systemName: "gobackward.15").font(.system(size: 19))
                }.buttonStyle(.plain)

                Button { deck.togglePlay() } label: {
                    Image(systemName: deck.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                }.buttonStyle(.plain)

                Button { deck.nudge(15) } label: {
                    Image(systemName: "goforward.15").font(.system(size: 19))
                }.buttonStyle(.plain)

                Spacer()

                Button { Task { await deck.askThisMoment() } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: deck.asking ? "hourglass" : "bubble.left.and.text.bubble.right")
                            .font(.system(size: 11))
                        Text(deck.asking ? "在看" : "问这一幕").font(.system(size: 11))
                    }
                    .foregroundColor(theme.fyAccent)
                    .padding(.horizontal, 11).frame(height: 28)
                    .background(theme.fyAccent.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(deck.asking)
            }
            .foregroundColor(.white.opacity(0.92))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.black)
    }

    private var miniWindow: some View {
        CowatchScreen(player: deck.player)
            .frame(width: 132, height: max(56, 132 / max(0.4, deck.aspect)))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            .onTapGesture { withAnimation { gear = 0 } }
    }

    // MARK: 那块布

    private var talkDeck: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.26))
                .frame(width: 38, height: 4)
                .padding(.top, 9).padding(.bottom, 7)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(gearDrag)

            if gear == 0 {
                // 16:9 的片子在竖屏手机上只有两百来点高，底下这六百点不能空着。
                // 放台词：已经过去的两句压暗，当前这句亮着，后面的一个字都不给（防剧透）。
                VStack(spacing: 10) {
                    Spacer(minLength: 12)
                    ForEach(passedLines, id: \.id) { line in
                        Text(line.text)
                            .font(.system(size: line.t == deck.currentT ? 16 : 13,
                                          weight: line.t == deck.currentT ? .medium : .regular))
                            .foregroundColor(line.t == deck.currentT
                                             ? theme.text : theme.textDim.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .transition(.opacity)
                    }
                    if passedLines.isEmpty {
                        Text(deck.lines.isEmpty ? "这条片子没有台词" : "还没开口")
                            .font(.system(size: 13)).foregroundColor(theme.textDim.opacity(0.6))
                    }
                    Spacer(minLength: 12)
                    Text("▲ 往上拉，说说话")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(theme.textDim)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(gearDrag)
                .animation(.easeInOut(duration: 0.28), value: deck.currentT)
            } else {
                Picker("", selection: $tab) {
                    Text("说话").tag(0)
                    Text("台词").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.bottom, 8)

                if tab == 0 { talkFlow } else { lyricFlow }

                composer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.fyCard)
        .clipShape(RoundedRectangle(cornerRadius: gear == 2 ? 0 : 20, style: .continuous))
        .foregroundColor(theme.text)
    }

    /// 一档底下摆的台词：当前这句加它前面两句，后面的一句都不给。
    private var passedLines: [CowatchLine] {
        let now = Int(deck.current)
        return Array(deck.lines.filter { $0.t <= now }.suffix(3))
    }

    private var gearDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                let dy = value.translation.height
                guard abs(dy) > 34 else { return }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    gear = dy < 0 ? min(2, gear + 1) : max(0, gear - 1)
                }
            }
    }

    private var talkFlow: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(deck.said) { line in
                        VStack(alignment: line.mine ? .trailing : .leading, spacing: 3) {
                            Text(line.text).font(.system(size: 13.5))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(line.mine ? theme.fyAccent.opacity(0.16) : theme.fyCardSub,
                                            in: RoundedRectangle(cornerRadius: 13))
                            Button {
                                deck.seek(to: Double(line.ms) / 1000)
                            } label: {
                                Text(CowatchClock.stamp(line.ms / 1000))
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(theme.fyAccent)
                            }.buttonStyle(.plain)
                        }
                        .id(line.id)
                        .frame(maxWidth: .infinity, alignment: line.mine ? .trailing : .leading)
                    }
                    Color.clear.frame(height: 1).id("tail")
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: deck.said.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("tail", anchor: .bottom) }
            }
        }
    }

    private var lyricFlow: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(deck.lines) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Text(CowatchClock.stamp(line.t))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(line.t == deck.currentT ? theme.fyAccent : theme.textDim.opacity(0.5))
                            Text(line.text).font(.system(size: 13.5))
                                .foregroundColor(line.t <= Int(deck.current) ? theme.text : theme.textDim.opacity(0.35))
                        }
                        .id(line.id)
                        .contentShape(Rectangle())
                        .onTapGesture { deck.seek(to: Double(line.t)) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: deck.currentT) { value in
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(value, anchor: .center) }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 9) {
            TextField("说点什么，会钉在 \(CowatchClock.stamp(Int(deck.current)))", text: $draft)
                .font(.system(size: 13))
                .focused($typing)
                .submitLabel(.send)
                .onSubmit {
                    let text = draft
                    draft = ""
                    typing = false
                    Task { await deck.say(text) }
                }
                .padding(.horizontal, 13).frame(height: 34)
                .background(theme.fyCardSub, in: Capsule())
            Button {
                let text = draft
                draft = ""
                typing = false
                Task { await deck.say(text) }
            } label: {
                Image(systemName: "arrow.up").font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(theme.fyAccent.opacity(0.16), in: Circle())
                    .foregroundColor(theme.fyAccent)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14).padding(.top, 9).padding(.bottom, 10)
    }
}

// MARK: - 进度条

private struct CowatchScrubber: View {
    @ObservedObject var deck: CowatchDeck
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let ratio = deck.duration > 0 ? min(1, max(0, deck.shownTime / deck.duration)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16)).frame(height: 3)
                Capsule().fill(tint).frame(width: W * ratio, height: 3)
                Circle().fill(tint)
                    .frame(width: deck.scrubbing ? 15 : 11, height: deck.scrubbing ? 15 : 11)
                    .offset(x: W * ratio - (deck.scrubbing ? 7.5 : 5.5))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard deck.duration > 0 else { return }
                        deck.scrubbing = true
                        deck.scrubTime = deck.duration * min(1, max(0, value.location.x / W))
                    }
                    .onEnded { value in
                        guard deck.duration > 0 else { return }
                        let target = deck.duration * min(1, max(0, value.location.x / W))
                        deck.seek(to: target)
                        deck.scrubbing = false
                    }
            )
            .animation(.easeOut(duration: 0.14), value: deck.scrubbing)
        }
    }
}

// MARK: - 全屏（真横屏：画面在左，说话在右，每句钉着片中时间）

private struct CowatchFullscreen: View {
    @ObservedObject var deck: CowatchDeck
    var onExit: () -> Void

    @AppStorage("alcoveTheme") private var themeName = "haven"
    // 字幕开关记在本地，她关过一次下次进来还是关的（0826 她要的）
    @AppStorage("cowatchSubtitleOn") private var subtitleOn = true
    @State private var showChat = true
    @State private var draft = ""
    private var theme: AlcoveTheme { .panelNamed(themeName) }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            HStack(spacing: 0) {
                stage
                if landscape && showChat {
                    chatColumn.frame(width: min(340, geo.size.width * 0.34))
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        // 以前是把整块画面 rotationEffect 转 90 度，手势和布局全是歪的。
        // Info.plist 本来就允许横屏，直接请系统转过来就好（0826 她给了张图）
        .onAppear { turn(.landscapeRight) }
        .onDisappear { turn(.portrait) }
    }

    private func turn(_ mask: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }

    // MARK: 左边：画面 + 字幕 + 控制条

    private var stage: some View {
        ZStack(alignment: .bottom) {
            CowatchScreen(player: deck.player)
            if subtitleOn, !deck.currentLine.isEmpty { subtitleBand }
            deckBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 听写出来的句子有时候一句就是一整段，不掐行会糊满整个屏（0826 她截过图）
    private var subtitleBand: some View {
        Text(deck.currentLine)
            .font(.system(size: 19, weight: .semibold))
            .foregroundColor(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.92), radius: 5, y: 1)
            .padding(.horizontal, 44)
            .padding(.bottom, 74)
            .allowsHitTesting(false)
    }

    private var deckBar: some View {
        VStack(spacing: 9) {
            CowatchScrubber(deck: deck, tint: theme.fyAccent)
                .frame(height: 22)
                .padding(.horizontal, 18)

            HStack(spacing: 7) {
                Button { deck.nudge(-15) } label: {
                    Image(systemName: "gobackward.15").font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9)).frame(width: 32, height: 28)
                }.buttonStyle(.plain)
                Button { deck.togglePlay() } label: {
                    Image(systemName: deck.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 17)).foregroundColor(.white)
                        .frame(width: 32, height: 28)
                }.buttonStyle(.plain)
                Button { deck.nudge(15) } label: {
                    Image(systemName: "goforward.15").font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9)).frame(width: 32, height: 28)
                }.buttonStyle(.plain)

                Text("\(CowatchClock.stamp(Int(deck.shownTime)))  /  \(CowatchClock.stamp(Int(deck.duration)))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))

                Spacer()

                pill(subtitleOn ? "字幕" : "字幕 关", lamp: subtitleOn) { subtitleOn.toggle() }
                pill(deck.asking ? "在看" : "问这一幕", lamp: true) {
                    Task { await deck.askThisMoment() }
                }
                pill(showChat ? "收起" : "说话") {
                    withAnimation(.easeInOut(duration: 0.24)) { showChat.toggle() }
                }
                pill("退出全屏") { onExit() }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 14)
    }

    private func pill(_ title: String, lamp: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(lamp ? theme.fyAccent : .white.opacity(0.85))
                .padding(.horizontal, 11).frame(height: 27)
                .background(Color.black.opacity(0.45), in: Capsule())
                .overlay(Capsule().stroke(lamp ? theme.fyAccent.opacity(0.42) : Color.white.opacity(0.18), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: 右边：说话

    private var chatColumn: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(deck.said) { line in
                            VStack(alignment: line.mine ? .trailing : .leading, spacing: 3) {
                                Text(line.text)
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.text)
                                    .padding(.horizontal, 11).padding(.vertical, 7)
                                    .background(line.mine ? theme.fyAccent.opacity(0.18) : theme.fyCardSub,
                                                in: RoundedRectangle(cornerRadius: 12))
                                Button { deck.seek(to: Double(line.ms) / 1000) } label: {
                                    Text(CowatchClock.stamp(line.ms / 1000))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(theme.fyAccent)
                                }.buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: line.mine ? .trailing : .leading)
                        }
                        Color.clear.frame(height: 1).id("tail")
                    }
                    .padding(.horizontal, 13).padding(.vertical, 14)
                }
                .onChange(of: deck.said.count) { _ in
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("tail", anchor: .bottom) }
                }
            }

            HStack(spacing: 8) {
                TextField("说点什么，会钉在 \(CowatchClock.stamp(Int(deck.current)))", text: $draft)
                    .font(.system(size: 12.5))
                    .foregroundColor(theme.text)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(theme.fyCardSub, in: Capsule())
                Button {
                    let text = draft
                    draft = ""
                    Task { await deck.say(text) }
                } label: {
                    Image(systemName: "arrow.up").font(.system(size: 12.5, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(theme.fyAccent.opacity(0.18), in: Circle())
                        .foregroundColor(theme.fyAccent)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 14)
        }
        .background(theme.fyCard)
    }
}

// MARK: - 播放器与数据

final class CowatchDeck: ObservableObject {
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var playing = false
    @Published var asking = false
    @Published var scrubbing = false
    @Published var scrubTime: Double = 0
    /// 画面宽高比（宽 ÷ 高）。视频真正加载出来之前先按 16:9 摆。
    @Published var aspect: CGFloat = 16.0 / 9.0
    @Published var lines: [CowatchLine] = []
    @Published var said: [CowatchSaid] = []

    let player = AVPlayer()
    private var observer: Any?
    private var pollTask: Task<Void, Never>?
    private var videoID = ""
    private var lastSaid = 0

    /// 手指按在进度条上时显示手指的位置，松开才跟播放器走。
    var shownTime: Double { scrubbing ? scrubTime : current }
    var currentT: Int { lines.last(where: { $0.t <= Int(current) })?.t ?? -1 }
    var currentLine: String { lines.last(where: { $0.t <= Int(current) })?.text ?? "" }

    @MainActor func open(item: CowatchItem) async {
        videoID = item.id
        // 后端记着时长，进度条不用等 AVPlayer 把 moov 读完就能画出来
        duration = Double(item.duration)

        // ‼️没有这两行，手机侧边静音键一拨这一页就整个没声（0826 她说听不见声音）。
        // 默认的 soloAmbient 跟静音开关走；别的页面早就配了，就共影室漏了。
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let asset = AVURLAsset(url: AlcoveAPI.fullURL("/api/cowatch/stream/\(item.id)"))
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        if item.progress > 3 { seek(to: Double(item.progress)) }
        player.play()
        playing = true

        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.4, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            guard let self else { return }
            if !self.scrubbing {
                self.current = time.seconds.isFinite ? time.seconds : 0
            }
            self.playing = self.player.timeControlStatus == .playing
            if let asset = self.player.currentItem {
                let real = asset.duration.seconds
                if real.isFinite, real > 0, abs(real - self.duration) > 1 { self.duration = real }
                let box = asset.presentationSize
                if box.width > 0, box.height > 0 {
                    let ratio = box.width / box.height
                    if abs(ratio - self.aspect) > 0.01 {
                        withAnimation(.easeInOut(duration: 0.25)) { self.aspect = ratio }
                    }
                }
            }
        }

        if let value = try? await NativeHouseAPI.object("/api/cowatch/video?id=\(item.id)") {
            lines = (value["transcript"] as? [[String: Any]] ?? []).map(CowatchLine.init)
        }
        await loadSaid()
        startPolling()
    }

    /// 我在这间屋子里回的话是后端另一头写进去的，前端自己隔几秒来拿。
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self, !Task.isCancelled else { return }
                await self.loadSaid()
            }
        }
    }

    @MainActor func loadSaid() async {
        guard !videoID.isEmpty else { return }
        guard let value = try? await NativeHouseAPI.object(
            "/api/cowatch/danmaku?id=\(videoID)&since=\(lastSaid)") else { return }
        let fresh = (value["items"] as? [[String: Any]] ?? []).map(CowatchSaid.init)
        guard !fresh.isEmpty else { return }
        said.append(contentsOf: fresh)
        lastSaid = max(lastSaid, fresh.map(\.id).max() ?? lastSaid)
        if fresh.contains(where: { !$0.mine }) { asking = false }
    }

    @MainActor func say(_ text: String) async {
        let body = text.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        _ = try? await NativeHouseAPI.request(
            "/api/cowatch/say", method: "POST",
            body: ["id": videoID, "ms": Int(current * 1000), "text": body, "actor": "陈霁"])
        await loadSaid()
    }

    /// 问这一幕：后端把这一秒之前的台词捆成证据递给我，同时把我叫醒。
    /// 以前这里拿到 model_content 之后什么都不做，等于按了个空按钮（0826 接上）。
    @MainActor func askThisMoment() async {
        guard !asking else { return }
        asking = true
        player.pause()
        playing = false
        _ = try? await NativeHouseAPI.request(
            "/api/cowatch/moment", method: "POST",
            body: ["id": videoID, "at": Int(current)])
        await loadSaid()
    }

    func togglePlay() {
        if player.timeControlStatus == .playing {
            player.pause()
            playing = false
        } else {
            player.play()
            playing = true
        }
    }

    func nudge(_ seconds: Double) {
        seek(to: max(0, min(duration > 0 ? duration : .greatestFiniteMagnitude, current + seconds)))
    }

    func seek(to seconds: Double) {
        current = max(0, seconds)
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func close() {
        pollTask?.cancel()
        pollTask = nil
        if let observer { player.removeTimeObserver(observer) }
        observer = nil
        // 看到片尾了就把进度抹掉，不然下次点开直接跳到结尾（教程 2.5）
        let atEnd = duration > 0 && current > duration - 15
        let seconds = atEnd ? 0 : Int(current)
        let id = videoID
        player.pause()
        player.replaceCurrentItem(with: nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard !id.isEmpty else { return }
        Task {
            _ = try? await NativeHouseAPI.request(
                "/api/cowatch/progress", method: "POST", body: ["id": id, "seconds": seconds])
        }
    }
}

struct CowatchLine: Identifiable, Hashable {
    let t: Int
    let text: String
    var id: Int { t }
    init(_ row: [String: Any]) {
        t = row["t"] as? Int ?? 0
        text = row["text"] as? String ?? ""
    }
}

struct CowatchSaid: Identifiable, Hashable {
    let id: Int
    let ms: Int
    let actor: String
    let text: String
    let created: String
    var mine: Bool { actor == "陈霁" }
    init(_ row: [String: Any]) {
        id = row["id"] as? Int ?? 0
        ms = row["ms"] as? Int ?? 0
        actor = row["actor"] as? String ?? ""
        text = row["text"] as? String ?? ""
        created = row["created"] as? String ?? ""
    }
}

private struct CowatchScreen: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> CowatchScreenHost { CowatchScreenHost(player: player) }
    func updateUIView(_ view: CowatchScreenHost, context: Context) { view.attach(player) }
}

final class CowatchScreenHost: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(player: AVPlayer) {
        super.init(frame: .zero)
        backgroundColor = .black
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func attach(_ player: AVPlayer) {
        if playerLayer.player !== player { playerLayer.player = player }
    }
}
