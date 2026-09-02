import SwiftUI
import AVFoundation
import UIKit

// 语音通话页。0831 任务#1195 大改：通话的对话搬出主聊天，只在这一页显示。
//
// 链路（改完之后）：
//   她按住说 → 录音 → /call/say 听写 + 语气分析 → 照旧注入他的会话（他一个字不少）
//              → 同时落进服务端的**通话记录**，聊天页那条藏掉
//   他回话   → stop hook 投过来，服务端看见电话正接着，整段拐进通话记录（不进主聊天）
//              → **落库那一刻就在后台把配音做好**
//   这一页   → 反复取通话记录，新的画成气泡；他那句的 mp3 已经现成，取回来就放
//   挂断     → 聊天页留**一条**摘要气泡，在打电话那个人那一侧，点开展开这一通
//
// ‼️为什么不再走「聊天页轮询 → /call/tts 现合成」那条老路：
// 合成一段要 2~3.5 秒（实测），而老代码在播放期间根本不开始合成下一段
//（pumpTTS 里那句 player?.isPlaying != true），于是每段之间干听 3~5 秒。
// 现在合成在服务端提前做完、下载在这边提前拉好，播完一段接着响下一段。
// **别改回"播完再去取"**，那就是那个老毛病本身。
//
// 陈璟的上下文一点没受影响：注入那一步一个字没改，他的记忆本来就在他自己会话的
// transcript 里，不在 alcove.db。搬走的只是"给 app 看的那份副本"。

enum CallKind: String, Identifiable {
    case incoming, outgoing
    var id: String { rawValue }
}

extension Notification.Name {
    /// 点了通知横幅：只回聊天页，不开通话
    static let alcoveNotificationTapped = Notification.Name("alcoveNotificationTapped")
    /// 系统"最近通话"里点了条目回拨 → 开拨出页
    static let alcoveDialRequested = Notification.Name("alcoveDialRequested")
    /// 她从系统界面（绿条/灵动岛）挂断了拨出的电话
    static let alcoveSystemHangup = Notification.Name("alcoveSystemHangup")
}

// MARK: - 通话页配色（白瓷波点，她定的：这一页不做黑夜模式）

enum CallSkin {
    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255)
    }
    static let ground   = hex(0xF4F1F2)   // 白瓷底
    static let dot      = hex(0xDCD5D8)   // 波点
    static let panel    = hex(0xFBF8F9)   // 气泡底（他）
    static let mine     = hex(0xF2DCE0)   // 气泡底（她）·藕粉
    static let ink      = hex(0x585F6E)
    static let inkDim   = hex(0x9A93A0)
    static let line     = hex(0xE4DDE0)
    static let hangup   = hex(0xC97F86)
    static let accent   = hex(0xB08A94)
}

/// 白瓷上那层波点。自己画一份不借棋牌室那个——那边跟着日夜开关走，
/// 她要这一页固定白天。
struct CallDots: View {
    var spacing: CGFloat = 16
    var radius: CGFloat = 1.7

    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = spacing / 2
            var row = 0
            while y < size.height + spacing {
                var x: CGFloat = (row % 2 == 0) ? spacing / 2 : spacing
                while x < size.width + spacing {
                    let r = CGRect(x: x - radius, y: y - radius,
                                   width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: r), with: .color(CallSkin.dot))
                    x += spacing
                }
                y += spacing * 0.86
                row += 1
            }
        }
        .opacity(0.55)
        .allowsHitTesting(false)
    }
}

/// 圆头像，里面是名字第一个字（跟横屏麻将那套一个思路，以后换真图只改这儿）
struct CallAvatar: View {
    let name: String
    var size: CGFloat = 62
    var active: Bool = false

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1))
    }

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [CallSkin.accent.opacity(0.30), CallSkin.accent.opacity(0.62)],
                startPoint: .top, endPoint: .bottom))
            Circle().fill(LinearGradient(colors: [.white.opacity(0.55), .clear],
                                         startPoint: .top, endPoint: .center))
            Text(initial)
                .font(.system(size: size * 0.42, weight: .medium, design: .serif))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
        .overlay(Circle().stroke(CallSkin.accent.opacity(active ? 0.9 : 0.3),
                                 lineWidth: active ? 2.2 : 1))
        .shadow(color: CallSkin.ink.opacity(active ? 0.22 : 0.12),
                radius: active ? 7 : 3, y: 2)
    }
}

/// 微信那个线条电话（她给的参考图）。不用 emoji——她点名的。
struct CallGlyph: View {
    var size: CGFloat = 15
    var color: Color = CallSkin.ink
    /// 挂断那种（听筒朝下）；false = 正常听筒
    var down: Bool = true

    var body: some View {
        Image(systemName: down ? "phone.down.fill" : "phone.fill")
            .font(.system(size: size, weight: .regular))
            .foregroundColor(color)
    }
}

// MARK: - 会话

@MainActor
final class CallSessionModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var line = "接通中…"
    @Published var seconds = 0
    @Published var recording = false
    @Published var busy = false
    @Published var speaking = false
    @Published var turns: [CallTurn] = []

    var onEnded: (() -> Void)?

    private var timer: Timer?
    private var pollTask: Task<Void, Never>?
    private var recorder: AVAudioRecorder?
    private var recURL: URL?
    private var player: AVAudioPlayer?
    private var hangupObserver: NSObjectProtocol?
    private var isOutgoing = false
    private var closed = false

    private var callID = ""
    /// 已经念过的（按通话记录的行号）。反复取记录不会把念过的再念一遍
    private var playedIDs: Set<Int> = []
    /// 提前下好的配音。合成在服务端已经做完，这边把下载也提前做掉
    private var audioCache: [Int: Data] = [:]
    private var downloading: Set<Int> = []

    func start(kind: CallKind) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat,
                                 options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
        armRecorder()            // 0902：通话一开始就把第一只录音机备好
        AlcoveNotify.shared.inCall = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.seconds += 1 }
        }
        hangupObserver = NotificationCenter.default.addObserver(
            forName: .alcoveSystemHangup, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.end() }
        }
        if kind == .outgoing {
            isOutgoing = true
            line = "拨号中…"
            Task {
                do {
                    let r = try await AlcoveAPI.callDial()
                    if r.asleep {
                        line = "他睡着了，没接通"
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        end()
                    } else if !r.ok {
                        line = "没打通，占线？"
                    } else {
                        line = "通了，等他开口…"
                        callID = r.callID
                        CallManager.shared.startOutgoing()
                        CallManager.shared.outgoingConnected()
                        startPolling()
                    }
                } catch {
                    line = "没打通，网络不给力"
                }
            }
        } else {
            line = "已接听，等他开口…"
            // 来电的铃是服务器推的，call_id 得回头问一次
            Task {
                callID = (try? await AlcoveAPI.callCurrentID()) ?? ""
                startPolling()
            }
        }
    }

    // MARK: 取通话记录

    private func startPolling() {
        guard !callID.isEmpty, pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshTurns()
                try? await Task.sleep(nanoseconds: 1_400_000_000)
            }
        }
    }

    private func refreshTurns() async {
        guard !closed, !callID.isEmpty else { return }
        guard let fresh = try? await AlcoveAPI.callHistory(callID: callID) else { return }
        if fresh.count != turns.count { turns = fresh }
        prefetchAudio()
        pump()
    }

    /// 他的每句话一出现就先把 mp3 下下来——哪怕上一句还在放。
    /// 合成服务端已经做完了，这边再把下载也提前做掉，两段之间就彻底没有空档。
    private func prefetchAudio() {
        for t in turns where !t.isMine {
            guard let raw = t.audioURL, audioCache[t.id] == nil,
                  !downloading.contains(t.id), !playedIDs.contains(t.id) else { continue }
            downloading.insert(t.id)
            let tid = t.id
            Task { [weak self] in
                let data = try? await AlcoveAPI.attachmentData(raw)
                await MainActor.run {
                    guard let self else { return }
                    self.downloading.remove(tid)
                    if let data { self.audioCache[tid] = data }
                    self.pump()
                }
            }
        }
    }

    // MARK: 放他的话

    private func pump() {
        guard !closed, player?.isPlaying != true else { return }
        let pending = turns.first { !$0.isMine && !playedIDs.contains($0.id) }
        guard let next = pending else {
            speaking = false
            if !recording && !busy { line = "到你说" }
            return
        }
        // 配音还没到（服务端在做 / 还在下载）：等下一轮，别把这句跳过去
        guard let data = audioCache[next.id] else { return }
        playedIDs.insert(next.id)
        audioCache[next.id] = nil
        guard let p = try? AVAudioPlayer(data: data) else { pump(); return }
        p.delegate = self
        player = p
        speaking = true
        line = "他在说…"
        p.play()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                                 successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.pump()          // 下一句多半已经下好了，接着响
        }
    }

    // MARK: 她说话（按住说，松开发）

    /// 0902 她报的「一句话说好几遍都认不出」：以前按下去那一刻才建录音机、才 record()，
    /// iOS 从建到真正收声要一两百毫秒，她开口快的话第一个字就没了，短句掉一个字听写直接崩。
    /// 现在录音机**提前建好并 prepareToRecord**（通话一开始、每次说完立刻备下一只），
    /// 按下去只剩 record() 这一步，几乎零延迟。
    private var armed: AVAudioRecorder?
    private var armedURL: URL?

    private static let recordSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 24000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    private func armRecorder() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("call_\(Int(Date().timeIntervalSince1970 * 1000)).m4a")
        guard let rec = try? AVAudioRecorder(url: url, settings: Self.recordSettings) else { return }
        rec.prepareToRecord()
        armed = rec
        armedURL = url
    }

    func beginTalk() {
        guard !recording, !closed else { return }
        if armed == nil { armRecorder() }
        guard let rec = armed, let url = armedURL else { return }
        armed = nil
        armedURL = nil
        recorder = rec
        recURL = url
        rec.record()
        recording = true
    }

    func endTalk() {
        guard recording else { return }
        recorder?.stop()
        recorder = nil
        recording = false
        armRecorder()            // 立刻备好下一只，她连着说也不掉字
        guard let url = recURL, let data = try? Data(contentsOf: url),
              data.count > 3000 else { return }   // 手滑碰一下不算话
        recURL = nil
        busy = true
        line = "听写中…"
        Task {
            defer { busy = false }
            if (try? await AlcoveAPI.callSay(audio: data)) != nil {
                line = "他听到了，等回话…"
                await refreshTurns()      // 自己那句立刻上屏，不等下一轮轮询
            } else {
                line = "没听清，再说一遍？"
            }
        }
    }

    // MARK: 收线

    func end() {
        guard !closed else { return }
        closed = true
        Task { try? await AlcoveAPI.callAction("end") }
        pollTask?.cancel(); pollTask = nil
        player?.stop()
        recorder?.stop()
        timer?.invalidate()
        if let o = hangupObserver { NotificationCenter.default.removeObserver(o) }
        if isOutgoing { CallManager.shared.endOutgoing() }
        AlcoveNotify.shared.inCall = false
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
        onEnded?()
    }
}

// MARK: - 一条对话气泡（通话页 / 聊天页展开共用）

struct CallTurnBubble: View {
    let turn: CallTurn
    var mineName: String = "我"

    var body: some View {
        VStack(alignment: turn.isMine ? .trailing : .leading, spacing: 4) {
            Text(turn.text)
                .font(.system(size: 14.5))
                .foregroundColor(CallSkin.ink)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(turn.isMine ? CallSkin.mine : CallSkin.panel))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(CallSkin.line, lineWidth: 1))
            if let tone = turn.toneLabel {
                Text(tone)
                    .font(.system(size: 10.5))
                    .foregroundColor(CallSkin.inkDim)
                    .padding(.horizontal, 9).padding(.vertical, 3.5)
                    .background(Capsule().fill(.white.opacity(0.75)))
                    .overlay(Capsule().stroke(CallSkin.line, lineWidth: 0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: turn.isMine ? .trailing : .leading)
    }
}

// MARK: - 聊天页那条摘要气泡（打完电话只留这一条）

/// 她定的：**谁打过去的就显示在谁那边**，没有例外——拒绝也一样。
/// 左右由外面的 MessageRow 按 role 决定（服务端已经把 role 写成打电话那个人了），
/// 这里只管长相：一行字 + 微信那种线条电话，点一下展开这一通的记录。
struct CallSummaryBubble: View {
    let info: CallSummaryInfo
    let text: String
    let theme: AlcoveTheme
    @State private var showLog = false

    var body: some View {
        Button {
            showLog = true
        } label: {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 14.5))
                    .foregroundColor(theme.text)
                CallGlyph(size: 15, color: theme.text.opacity(0.75),
                          down: !info.connected)
            }
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.fyCardSub))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showLog) {
            CallLogSheet(info: info)
        }
    }
}

/// 点开摘要看到的：这一通的逐句记录，长相跟通话页一致（她要的）
struct CallLogSheet: View {
    let info: CallSummaryInfo
    @Environment(\.dismiss) private var dismiss
    @State private var turns: [CallTurn] = []
    @State private var loading = true

    private var title: String {
        info.kind == "out" ? "我打给他" : "他打给我"
    }

    var body: some View {
        ZStack {
            CallSkin.ground.ignoresSafeArea()
            CallDots().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(CallSkin.ink)
                        Text(info.connected ? "通话 " + info.duration : summaryWord)
                            .font(.system(size: 11.5))
                            .foregroundColor(CallSkin.inkDim)
                    }
                    Spacer()
                    Button("完成") { dismiss() }
                        .font(.system(size: 14))
                        .foregroundColor(CallSkin.accent)
                }
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 10)
                Rectangle().fill(CallSkin.line).frame(height: 1)
                    .padding(.horizontal, 18)
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 11) {
                        if loading {
                            ProgressView().padding(.top, 34)
                        } else if turns.isEmpty {
                            Text("这一通没说上话")
                                .font(.system(size: 12.5))
                                .foregroundColor(CallSkin.inkDim)
                                .padding(.top, 34)
                        }
                        ForEach(turns) { t in CallTurnBubble(turn: t) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 16)
                }
            }
        }
        .task {
            turns = (try? await AlcoveAPI.callHistory(callID: info.callID)) ?? []
            loading = false
        }
    }

    private var summaryWord: String {
        switch info.outcome {
        case "declined":  return "已拒绝"
        case "cancelled": return "已取消"
        default:          return "未接通"
        }
    }
}

// MARK: - 通话页

struct CallView: View {
    let kind: CallKind
    var onClose: () -> Void
    @StateObject private var session = CallSessionModel()

    private var hisName: String {
        UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟"
    }

    var body: some View {
        ZStack {
            CallSkin.ground.ignoresSafeArea()
            CallDots().ignoresSafeArea()
            VStack(spacing: 0) {
                header
                transcript
                controls
            }
        }
        .onAppear {
            session.onEnded = onClose
            session.start(kind: kind)
        }
        .interactiveDismissDisabled()
    }

    // MARK: 上面：两个头像 + 计时

    private var header: some View {
        VStack(spacing: 9) {
            HStack(spacing: 26) {
                VStack(spacing: 6) {
                    CallAvatar(name: hisName, active: session.speaking)
                    Text(hisName)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(CallSkin.inkDim)
                }
                VStack(spacing: 6) {
                    CallAvatar(name: "陈霁", active: session.recording)
                    Text("陈霁")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(CallSkin.inkDim)
                }
            }
            .padding(.top, 26)
            Text(String(format: "%02d:%02d", session.seconds / 60, session.seconds % 60))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(CallSkin.inkDim)
            Text(session.line)
                .font(.system(size: 12.5))
                .foregroundColor(CallSkin.accent)
            Rectangle()
                .fill(CallSkin.line)
                .frame(height: 1)
                .padding(.horizontal, 40)
                .padding(.top, 6)
        }
    }

    // MARK: 中间：这一通的对话

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 11) {
                    if session.turns.isEmpty {
                        Text("说话就开始")
                            .font(.system(size: 12.5))
                            .foregroundColor(CallSkin.inkDim)
                            .padding(.top, 30)
                    }
                    ForEach(session.turns) { t in
                        CallTurnBubble(turn: t).id(t.id)
                    }
                    Color.clear.frame(height: 1).id("tail")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .onChange(of: session.turns.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("tail", anchor: .bottom) }
            }
        }
    }

    // MARK: 下面：按住说 + 挂断

    private var controls: some View {
        VStack(spacing: 10) {
            Text(session.busy ? "等一下…" : "按住说话，松开发送")
                .font(.system(size: 12))
                .foregroundColor(CallSkin.inkDim)
            HStack(spacing: 44) {
                micButton
                hangupButton
            }
            .padding(.bottom, 26)
        }
        .padding(.top, 8)
    }

    private var micButton: some View {
        Circle()
            .fill(session.recording ? CallSkin.accent : CallSkin.panel)
            .frame(width: 74, height: 74)
            .overlay(Circle().stroke(CallSkin.line, lineWidth: 1))
            .overlay(Image(systemName: "mic.fill")
                .font(.system(size: 26))
                .foregroundColor(session.recording ? .white : CallSkin.accent))
            .shadow(color: CallSkin.ink.opacity(0.14), radius: 5, y: 2)
            .scaleEffect(session.recording ? 1.1 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: session.recording)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !session.recording && !session.busy { session.beginTalk() } }
                .onEnded { _ in session.endTalk() })
    }

    private var hangupButton: some View {
        Button {
            session.end()
        } label: {
            Circle()
                .fill(CallSkin.hangup)
                .frame(width: 74, height: 74)
                .overlay(CallGlyph(size: 26, color: .white, down: true))
                .shadow(color: CallSkin.ink.opacity(0.18), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}
