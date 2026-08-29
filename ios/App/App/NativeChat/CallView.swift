import SwiftUI
import AVFoundation
import UIKit

// 0829 语音通话页（工作室任务#1122-1126）。
// 电话＝聊天回路的语音皮：按住说话 → 录音 → /call/say 听写并注入主聊天 →
// 他本人（CLI 会话）回复 → 轮询收到 → /call/tts 用他的声音合成 → 这里播放。
// 对讲机节奏，脑子是他本人，聊天页自动留完整文字记录。

enum CallKind: String, Identifiable {
    case incoming, outgoing
    var id: String { rawValue }
}

extension Notification.Name {
    /// ChatStore 轮询到他的新消息正文（通话页拿去合成语音）
    static let alcoveAssistantSpoke = Notification.Name("alcoveAssistantSpoke")
    /// 点了通知横幅：只回聊天页，不开通话
    static let alcoveNotificationTapped = Notification.Name("alcoveNotificationTapped")
    /// 系统"最近通话"里点了条目回拨 → 开拨出页
    static let alcoveDialRequested = Notification.Name("alcoveDialRequested")
}

@MainActor
final class CallSessionModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var line = "接通中…"
    @Published var seconds = 0
    @Published var recording = false
    @Published var busy = false
    @Published var speaking = false
    @Published var lastHeard = ""

    var onEnded: (() -> Void)?

    private var timer: Timer?
    private var recorder: AVAudioRecorder?
    private var recURL: URL?
    private var player: AVAudioPlayer?
    private var ttsQueue: [String] = []
    private var fetchingTTS = false
    private var observer: NSObjectProtocol?
    private var closed = false

    func start(kind: CallKind) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat,
                                 options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
        AlcoveNotify.shared.inCall = true
        observer = NotificationCenter.default.addObserver(
            forName: .alcoveAssistantSpoke, object: nil, queue: .main) { [weak self] note in
            guard let text = note.object as? String, !text.isEmpty else { return }
            Task { @MainActor in self?.enqueueTTS(text) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.seconds += 1 }
        }
        if kind == .outgoing {
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
                    }
                } catch {
                    line = "没打通，网络不给力"
                }
            }
        } else {
            line = "已接听，等他开口…"
        }
    }

    // MARK: 他说话（TTS 队列，一段播完接一段）

    private func enqueueTTS(_ text: String) {
        guard !closed else { return }
        ttsQueue.append(text)
        pumpTTS()
    }

    private func pumpTTS() {
        guard !fetchingTTS, player?.isPlaying != true, !ttsQueue.isEmpty else { return }
        let text = ttsQueue.removeFirst()
        fetchingTTS = true
        speaking = true
        line = "他在说…"
        Task {
            defer { fetchingTTS = false }
            if let data = try? await AlcoveAPI.callTTSAudio(text: text),
               let p = try? AVAudioPlayer(data: data) {
                p.delegate = self
                player = p
                p.play()
            } else {
                speaking = player?.isPlaying == true
                pumpTTS()
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                                 successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.speaking = false
            if self.ttsQueue.isEmpty { self.line = "到你说" }
            self.pumpTTS()
        }
    }

    // MARK: 她说话（按住说，松开发）

    func beginTalk() {
        guard !recording, !closed else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("call_\(Int(Date().timeIntervalSince1970 * 1000)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 24000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
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
        guard let url = recURL, let data = try? Data(contentsOf: url),
              data.count > 3000 else { return } // 手滑碰一下不算话
        recURL = nil
        busy = true
        line = "听写中…"
        Task {
            defer { busy = false }
            if let heard = try? await AlcoveAPI.callSay(audio: data) {
                lastHeard = heard
                line = "他听到了，等回话…"
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
        player?.stop()
        recorder?.stop()
        timer?.invalidate()
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        AlcoveNotify.shared.inCall = false
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
        onEnded?()
    }
}

struct CallView: View {
    let kind: CallKind
    var onClose: () -> Void
    @StateObject private var session = CallSessionModel()
    @AppStorage("alcoveTheme") private var themeName = "haven"
    private var theme: AlcoveTheme { .named(themeName) }
    private var name: String {
        UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.09, blue: 0.12),
                                    Color(red: 0.05, green: 0.05, blue: 0.07)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer().frame(height: 46)
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 108, height: 108)
                    .overlay(Text("R").font(.system(size: 40, design: .serif))
                        .foregroundColor(.white.opacity(0.85)))
                    .overlay(Circle().stroke(Color.white.opacity(session.speaking ? 0.5 : 0.12),
                                             lineWidth: 2)
                        .scaleEffect(session.speaking ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                                   value: session.speaking))
                Text(name)
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .foregroundColor(.white)
                Text(String(format: "%02d:%02d", session.seconds / 60, session.seconds % 60))
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                Text(session.line)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                if !session.lastHeard.isEmpty {
                    Text("你：\(session.lastHeard)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(3)
                        .padding(.horizontal, 32)
                }
                Spacer()
                // 按住说话
                Circle()
                    .fill(session.recording ? Color.white.opacity(0.9) : Color.white.opacity(0.14))
                    .frame(width: 96, height: 96)
                    .overlay(Image(systemName: "mic.fill")
                        .font(.system(size: 34))
                        .foregroundColor(session.recording ? .black : .white))
                    .scaleEffect(session.recording ? 1.14 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7),
                               value: session.recording)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !session.recording && !session.busy { session.beginTalk() } }
                        .onEnded { _ in session.endTalk() })
                Text(session.busy ? "等一下…" : "按住说话，松开发送")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                Spacer().frame(height: 8)
                Button {
                    session.end()
                } label: {
                    Circle()
                        .fill(Color(red: 0.86, green: 0.22, blue: 0.2))
                        .frame(width: 64, height: 64)
                        .overlay(Image(systemName: "phone.down.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white))
                }
                Spacer().frame(height: 24)
            }
        }
        .onAppear {
            session.onEnded = onClose
            session.start(kind: kind)
        }
        .interactiveDismissDisabled()
    }
}
