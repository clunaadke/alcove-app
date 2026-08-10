import SwiftUI
import ReplayKit
import ActivityKit

// 已经通过真机验证的系统联动入口。诊断信息不再暴露给日常设置页。
struct SystemFeaturesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true

    var body: some View {
        NavigationStack {
            List {
                Section("灵动岛") {
                    Toggle(isOn: $liveActivityEnabled) {
                        Label("同步陈璟的工作状态", systemImage: "rectangle.inset.filled.and.person.filled")
                    }
                    .onChange(of: liveActivityEnabled) { enabled in
                        if !enabled { Task { await AlcoveLiveActivityController.stop() } }
                    }
                    Text("聊天时把“正在思考、读文件、修改代码”等状态同步到灵动岛；关闭后会立即结束现有活动。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("屏幕控制") {
                    ZStack {
                        Label("开始共享屏幕", systemImage: "rectangle.on.rectangle")
                            .foregroundStyle(.pink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                        BroadcastPicker()
                            .opacity(0.02)
                    }
                    Text("由你亲手在系统面板中开始或停止。开启期间 iOS 会持续显示录屏提示。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("系统联动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

}

private struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        // 有些免费重签工具会改写子扩展 Bundle ID，不能写死构建时的地址。
        picker.preferredExtension = installedBroadcastBundleIdentifier
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

private var installedBroadcastBundleIdentifier: String? {
    guard let directory = Bundle.main.builtInPlugInsURL else { return nil }
    let URLs = ((try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
    )) ?? []).filter { $0.pathExtension == "appex" }
    return URLs
            .first { $0.deletingPathExtension().lastPathComponent == "BroadcastUpload" }
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
}

enum AlcoveLiveActivityController {
    static func sync(_ live: AlcoveAPI.LiveState?) async {
        guard UserDefaults.standard.object(forKey: "liveActivityEnabled") == nil
                || UserDefaults.standard.bool(forKey: "liveActivityEnabled") else {
            await stop()
            return
        }
        guard let live, live.active || live.finishing else {
            await stop()
            return
        }

        let message: String
        if !live.tool.isEmpty {
            message = "正在\(live.tool)…"
        } else if !live.pendingSay.isEmpty || !live.say.isEmpty {
            message = "正在回复你…"
        } else {
            message = "正在思考…"
        }

        let state = AlcoveLabAttributes.ContentState(message: message, startedAt: .now)
        if let activity = Activity<AlcoveLabAttributes>.activities.first {
            await activity.update(ActivityContent(state: state, staleDate: nil))
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(
            attributes: AlcoveLabAttributes(name: UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟"),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    static func stop() async {
        for activity in Activity<AlcoveLabAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

@MainActor
private final class CallKitSmokeTester: NSObject, ObservableObject, CXProviderDelegate {
    static let shared = CallKitSmokeTester()

    @Published var status = "尚未测试"
    @Published var running = false

    private let controller = CXCallController()
    private let provider: CXProvider
    private var activeUUID: UUID?

    override private init() {
        let config = CXProviderConfiguration(localizedName: "Alcove")
        config.supportsVideo = false
        config.includesCallsInRecents = true
        config.supportedHandleTypes = [.generic]
        config.maximumCallsPerCallGroup = 1
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func startSmokeCall() {
        guard !running else { return }
        let uuid = UUID()
        activeUUID = uuid
        running = true
        status = "正在向 CallKit 请求外呼…"

        let handle = CXHandle(type: .generic, value: "陈璟")
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = false
        controller.request(CXTransaction(action: action)) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.status = "CallKit 拒绝：\(error.localizedDescription)"
                    self.running = false
                    self.activeUUID = nil
                } else {
                    self.status = "请求已送达，等待系统回调。"
                }
            }
        }
    }

    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            activeUUID = nil
            running = false
            status = "CallKit 已重置。"
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: .now)
        provider.reportOutgoingCall(with: action.callUUID, connectedAt: .now)
        action.fulfill()
        Task { @MainActor in
            status = "已接通测试外呼；8 秒后自动挂断。"
        }
        Task {
            try? await Task.sleep(for: .seconds(8))
            await MainActor.run { self.endSmokeCall() }
        }
    }

    private func endSmokeCall() {
        guard let uuid = activeUUID else { return }
        controller.request(CXTransaction(action: CXEndCallAction(call: uuid))) { [weak self] error in
            Task { @MainActor in
                if let error { self?.status = "挂断失败：\(error.localizedDescription)" }
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        Task { @MainActor in
            activeUUID = nil
            running = false
            status = "测试通话已结束。现在去系统最近通话验收。"
        }
    }
}
