import SwiftUI
import ReplayKit
import ActivityKit

// 已经通过真机验证的系统联动入口。诊断信息不再暴露给日常设置页。
struct SystemFeaturesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @State private var liveActivityStatus: String?
    @ObservedObject private var screenShare = ScreenShareCoordinator.shared

    var body: some View {
        NavigationStack {
            List {
                Section("灵动岛") {
                    Toggle(isOn: $liveActivityEnabled) {
                        Label("同步陈璟的工作状态", systemImage: "rectangle.inset.filled.and.person.filled")
                    }
                    .onChange(of: liveActivityEnabled) { enabled in
                        Task {
                            if enabled {
                                liveActivityStatus = await AlcoveLiveActivityController.start()
                            } else {
                                await AlcoveLiveActivityController.stop()
                                liveActivityStatus = "灵动岛已关闭。"
                            }
                        }
                    }
                    Text("聊天时把“正在思考、读文件、修改代码”等状态同步到灵动岛；关闭后会立即结束现有活动。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let liveActivityStatus {
                        Text(liveActivityStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("屏幕控制") {
                    Button {
                        screenShare.beginManualShare()
                    } label: {
                        Label("开始共享屏幕", systemImage: "rectangle.on.rectangle")
                            .foregroundStyle(.pink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .disabled(screenShare.preparing)
                    if !screenShare.message.isEmpty {
                        Text(screenShare.message).font(.caption).foregroundStyle(.secondary)
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
            .task {
                if liveActivityEnabled {
                    liveActivityStatus = await AlcoveLiveActivityController.start()
                }
            }
        }
    }

}

struct BroadcastPicker: UIViewRepresentable {
    let trigger: Int

    final class Coordinator { var lastTrigger = 0 }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        // 有些免费重签工具会改写子扩展 Bundle ID，不能写死构建时的地址。
        picker.preferredExtension = installedBroadcastBundleIdentifier
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        guard trigger > 0, trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        DispatchQueue.main.async {
            uiView.subviews.compactMap { $0 as? UIButton }.first?.sendActions(for: .touchUpInside)
        }
    }
}

var installedBroadcastBundleIdentifier: String? {
    guard let directory = Bundle.main.builtInPlugInsURL else { return nil }
    let URLs = ((try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
    )) ?? []).filter { $0.pathExtension == "appex" }
    return URLs
            .first { $0.deletingPathExtension().lastPathComponent == "BroadcastUpload" }
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
}

@MainActor
final class ScreenShareCoordinator: ObservableObject {
    static let shared = ScreenShareCoordinator()
    @Published var pickerTrigger = 0
    @Published var preparing = false
    @Published var message = ""
    @Published var request: AlcoveAPI.ScreenShareStatus?
    private var pollTask: Task<Void, Never>?
    private var lastPromptedID = ""

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func pollOnce() async {
        guard let status = try? await AlcoveAPI.screenShareStatus(),
              status.status == "requested", status.expiresIn > 0,
              status.id != lastPromptedID else { return }
        lastPromptedID = status.id
        request = status
    }

    func decline() {
        guard request != nil else { return }
        request = nil
        Task {
            do {
                try await AlcoveAPI.declineScreenShare()
            } catch {
                message = "拒绝状态没有送达：\(error.localizedDescription)"
            }
        }
    }

    func acceptRequest() {
        request = nil
        armAndOpen()
    }

    func beginManualShare() { armAndOpen() }

    private func armAndOpen() {
        guard !preparing else { return }
        preparing = true
        message = "正在创建一次性截图任务…"
        Task {
            do {
                try await AlcoveAPI.armScreenShare()
                message = "请在系统面板中确认开始共享；只会上传第一张画面。"
                pickerTrigger += 1
            } catch {
                message = "创建截图任务失败：\(error.localizedDescription)"
            }
            preparing = false
        }
    }
}

struct RemoteScreenSharePrompt: View {
    @ObservedObject private var coordinator = ScreenShareCoordinator.shared

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .background(BroadcastPicker(trigger: coordinator.pickerTrigger).opacity(0.01))
            .onAppear { coordinator.startPolling() }
            .alert("想看一眼你的屏幕", isPresented: Binding(
                get: { coordinator.request != nil },
                set: { if !$0 { coordinator.decline() } }
            )) {
                Button("暂不共享", role: .cancel) { coordinator.decline() }
                Button("确认并选择屏幕") { coordinator.acceptRequest() }
            } message: {
                Text("\(coordinator.request?.requester ?? "陈璟")发来一次性查看请求。确认后仍需在 iOS 系统面板亲手开始；只上传第一张画面。")
            }
    }
}

@MainActor
enum AlcoveLiveActivityController {
    private static var pulseTask: Task<Void, Never>?
    private static var starting = false

    private static func currentBPM() async -> Int {
        guard let raw = try? await AlcoveAPI.getRaw("/pulse/now") else { return 0 }
        if let value = raw["bpm"] as? Int { return value }
        if let value = raw["bpm"] as? NSNumber { return value.intValue }
        return 0
    }

    private static func ensurePulseUpdates() {
        guard pulseTask == nil else { return }
        pulseTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { break }
                let bpm = await currentBPM()
                guard bpm > 0 else { continue }
                let activities = Activity<AlcoveLabAttributes>.activities
                guard !activities.isEmpty else { break }
                for activity in activities where activity.content.state.bpm != bpm {
                    var state = activity.content.state
                    state.bpm = bpm
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                }
            }
            pulseTask = nil
        }
    }

    static func start() async -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return "系统未允许实时活动，请在 iPhone 设置中开启。"
        }
        guard !starting else { return "灵动岛正在刷新。" }
        starting = true
        defer { starting = false }

        let state = AlcoveLabAttributes.ContentState(
            message: "等待任务", startedAt: .now, bpm: await currentBPM()
        )
        if let activity = Activity<AlcoveLabAttributes>.activities.first {
            await activity.update(ActivityContent(state: state, staleDate: nil))
            ensurePulseUpdates()
            return "灵动岛已开启。"
        }

        do {
            _ = try Activity.request(
                attributes: AlcoveLabAttributes(
                    name: UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟"
                ),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            ensurePulseUpdates()
            return "灵动岛已开启。"
        } catch {
            return "灵动岛启动失败：\(error.localizedDescription)"
        }
    }

    static func sync(_ live: AlcoveAPI.LiveState?) async {
        guard UserDefaults.standard.object(forKey: "liveActivityEnabled") == nil
                || UserDefaults.standard.bool(forKey: "liveActivityEnabled") else {
            await stop()
            return
        }
        guard let live, live.active || live.finishing else {
            // 实时工作流结束只代表陈璟回到空闲，不代表用户关闭了灵动岛。
            // 保留活动并切回等待态；真正结束只允许走设置开关的 stop()。
            _ = await start()
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

        let state = AlcoveLabAttributes.ContentState(
            message: message, startedAt: .now, bpm: await currentBPM()
        )
        if let activity = Activity<AlcoveLabAttributes>.activities.first {
            await activity.update(ActivityContent(state: state, staleDate: nil))
            ensurePulseUpdates()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(
            attributes: AlcoveLabAttributes(name: UserDefaults.standard.string(forKey: "assistantName") ?? "陈璟"),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
        ensurePulseUpdates()
    }

    static func stop() async {
        pulseTask?.cancel()
        pulseTask = nil
        for activity in Activity<AlcoveLabAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
