import SwiftUI
import CallKit
import ReplayKit
import ActivityKit

// 免费 Personal Team 能力体检页。这里刻意不接业务后端：先确认系统门能不能开。
struct CapabilityLabView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calls = CallKitSmokeTester.shared
    @State private var liveMessage = "尚未测试"
    @State private var installedExtensions = InstalledExtensionReport.read()

    var body: some View {
        NavigationStack {
            List {
                Section("安装包 · 扩展签名") {
                    Text(installedExtensions.summary)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button("重新读取安装包") {
                        installedExtensions = .read()
                    }
                    Text("这里读的是手机上已经安装的 App，不是构建服务器里的工程文件。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("CallKit · 系统通话记录") {
                    Text(calls.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        calls.startSmokeCall()
                    } label: {
                        Label("发起 8 秒测试外呼", systemImage: "phone.arrow.up.right")
                    }
                    .disabled(calls.running)
                    Text("挂断后请打开「电话 → 最近通话」，检查是否出现“陈璟”。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("灵动岛 · 本地实时活动") {
                    Text(liveMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await startLiveActivity() }
                    } label: {
                        Label("让陈璟待上灵动岛", systemImage: "rectangle.inset.filled.and.person.filled")
                    }
                    Button(role: .destructive) {
                        Task { await stopLiveActivities() }
                    } label: {
                        Label("结束测试实时活动", systemImage: "xmark.circle")
                    }
                    Text("这里只做本地启动，不申请推送 token。普通机型会显示锁屏实时活动，没有灵动岛胶囊。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("ReplayKit · 屏幕共享") {
                    ZStack {
                        Label("打开系统屏幕共享面板", systemImage: "rectangle.on.rectangle")
                            .foregroundStyle(.pink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                        BroadcastPicker()
                            .opacity(0.02)
                    }
                    Text("请亲手点系统按钮开始。第一版只验证广播扩展能否被免费签名安装和拉起，不上传屏幕。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("免费签名能力体检")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func startLiveActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            liveMessage = "系统没有允许实时活动，请检查设置。"
            return
        }
        do {
            let state = AlcoveLabAttributes.ContentState(message: "我在这里", startedAt: .now)
            _ = try Activity.request(
                attributes: AlcoveLabAttributes(name: "陈璟"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            liveMessage = "系统已接受请求；请锁屏或看灵动岛。"
        } catch {
            liveMessage = "启动失败：\(error.localizedDescription)"
        }
    }

    private func stopLiveActivities() async {
        for activity in Activity<AlcoveLabAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        liveMessage = "已结束。"
    }
}

private struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = "com.luna.alcove.BroadcastUpload"
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

private struct InstalledExtensionReport {
    let summary: String

    static func read() -> Self {
        guard let directory = Bundle.main.builtInPlugInsURL else {
            return .init(summary: "PlugIns 目录：不存在\n结论：安装包没有嵌入任何扩展")
        }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let appex = urls.filter { $0.pathExtension == "appex" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !appex.isEmpty else {
            return .init(summary: "PlugIns 目录：存在\n.appex：0 个\n结论：重签或安装时扩展被剥掉")
        }

        let lines = appex.map { url -> String in
            let bundleID = Bundle(url: url)?.bundleIdentifier ?? "无 Bundle ID"
            let profile = FileManager.default.fileExists(atPath: url.appendingPathComponent("embedded.mobileprovision").path)
            return "• \(url.deletingPathExtension().lastPathComponent)\n  \(bundleID)\n  描述文件：\(profile ? "有" : "无")"
        }
        return .init(summary: "发现 \(appex.count) 个扩展：\n" + lines.joined(separator: "\n"))
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
