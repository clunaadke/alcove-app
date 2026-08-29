import Foundation
import CallKit
import AVFoundation
import UserNotifications
import UIKit

// 0829 原生来电与前台通知（工作室任务#1111-1113）。
// 免费开发者账号方案：不走 APNs。app 活着（前台，或后台被无声音频保活吊着）时，
// /chat/poll 捎回 call 状态 → CallKit 弹系统级全屏来电；新消息走本地通知横幅。

extension Notification.Name {
    /// 她在系统来电界面按了接听：回聊天页
    static let alcoveCallAnswered = Notification.Name("alcoveCallAnswered")
}

// MARK: - CallKit 来电

final class CallManager: NSObject, CXProviderDelegate {
    static let shared = CallManager()

    private let provider: CXProvider
    private var currentUUID: UUID?
    private var currentCallId: String?

    private override init() {
        let cfg = CXProviderConfiguration()
        cfg.supportsVideo = false
        cfg.maximumCallGroups = 1
        cfg.maximumCallsPerCallGroup = 1
        cfg.supportedHandleTypes = [.generic]
        // 铃声不设 = iOS 默认来电铃声（她定的）。要换必须在这里设，创建后改无效。
        cfg.includesCallsInRecents = false
        provider = CXProvider(configuration: cfg)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    /// 每次轮询把服务器的通话状态灌进来
    func apply(state: String, callId: String) {
        switch state {
        case "ringing":
            guard callId != currentCallId else { return } // 同一通铃只弹一次
            currentCallId = callId
            let uuid = UUID()
            currentUUID = uuid
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: "陈璟")
            update.localizedCallerName = "陈璟"
            update.hasVideo = false
            provider.reportNewIncomingCall(with: uuid, update: update) { _ in }
        default:
            // idle/ended：他那边撤回或响铃超时，把还在响的铃收掉
            if state == "idle", let uuid = currentUUID {
                provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
                currentUUID = nil
                currentCallId = nil
            }
        }
    }

    // MARK: CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        currentUUID = nil
        currentCallId = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { try? await AlcoveAPI.callAction("answer") }
        action.fulfill()
        NotificationCenter.default.post(name: .alcoveCallAnswered, object: nil)
        // 这不是真语音通道，接起=收到提醒。稍等一拍把系统通话界面收掉，
        // 免得顶栏挂着一个没有声音的"通话中"。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, let uuid = self.currentUUID else { return }
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            self.currentUUID = nil
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // 响铃中挂断=拒接；接听后的收尾走上面的 reportCall，不会进这里
        Task { try? await AlcoveAPI.callAction("decline") }
        currentUUID = nil
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
}

// MARK: - 本地通知（前台横幅 + 锁屏）

final class AlcoveNotify: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlcoveNotify()

    /// RootView 维护：她正停在聊天页（前台且没盖小屋全屏页）就别弹横幅
    var chatVisible = true

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// 新消息进来喊一声。她盯着聊天页时闭嘴，其他情况（别的页面/后台/锁屏）都响。
    func newMessage(_ text: String) {
        let onChat = chatVisible && UIApplication.shared.applicationState == .active
        guard !onChat else { return }
        let content = UNMutableNotificationContent()
        content.title = "陈璟"
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = trimmed.isEmpty ? "发来一条消息" : String(trimmed.prefix(120))
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // 前台也把横幅画出来（不实现这个回调，前台通知会被系统静默吞掉）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // 点通知=回聊天页，复用接听的跳转
        NotificationCenter.default.post(name: .alcoveCallAnswered, object: nil)
        completionHandler()
    }
}

// MARK: - 无声音频保活（锁屏/后台把轮询吊着）

final class KeepAlive {
    static let shared = KeepAlive()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var wired = false
    private(set) var running = false

    func start() {
        guard !running else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // mixWithOthers：别掐断她正在放的歌/播客
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            // 格式必须显式给 mono 44100：format nil 会取硬件双声道，
            // 跟 mono buffer 对不上，scheduleBuffer 直接 crash（踩坑速查表）
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100,
                                             channels: 1) else { return }
            if !wired {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                wired = true
            }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                frameCapacity: 44100) else { return }
            buffer.frameLength = 44100
            if let ch = buffer.floatChannelData {
                memset(ch[0], 0, 44100 * MemoryLayout<Float>.size)
            }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            try engine.start()
            player.play()
            running = true
        } catch {
            running = false
        }
    }

    func stop() {
        guard running else { return }
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false,
                                                       options: .notifyOthersOnDeactivation)
        running = false
    }
}
