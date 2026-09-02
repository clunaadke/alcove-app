import Foundation
import AVFoundation

// 语音条：点麦克风开始录，点发送出去，跟 PWA 的录音流程一致
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var seconds = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?
    /// 0902：按下录音那一刻歌在不在放。录完把通道还给音乐，刚才在放就接着放
    private var musicWasPlaying = false

    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async { self?.beginRecording() }
        }
    }

    private func beginRecording() {
        musicWasPlaying = MusicModel.shared.isPlaying
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        recorder = rec
        fileURL = url
        rec.record()
        isRecording = true
        seconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.seconds += 1 }
        }
    }

    // 返回录音数据；nil 表示没录出东西
    func stopAndTake() -> Data? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        releaseSession()
        guard let url = fileURL else { return nil }
        fileURL = nil
        return try? Data(contentsOf: url)
    }

    /// 录完把音频通道还回去：
    ///   · 通话缩小着 → 一个字不动，那是通话的命（0902 上午）
    ///   · 歌在放/放着一半 → 通道切回播放模式，刚才在放就接着放（0902 晚她报的「唱片点不动」）
    ///   · 都没有 → 照旧关掉
    private func releaseSession() {
        if AlcoveNotify.shared.inCall { return }
        if MusicModel.shared.nowPlaying != nil {
            MusicModel.shared.reclaimAudioSession(resume: musicWasPlaying)
            return
        }
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        releaseSession()
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
    }
}
