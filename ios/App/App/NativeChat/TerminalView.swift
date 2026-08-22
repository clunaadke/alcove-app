import SwiftUI

private enum CCWorkState: Equatable {
    case disconnected
    case thinking
    case resting
}

// 0822 她要的：终端页分两种看法。cli = tmux 真终端；sdk = 后端把 SDK session 翻成同款样子。
// 默认跟着主聊天当前 channel 开，但不焊死，顶上能切着看。
enum TerminalMode: String {
    case cli, sdk
}

// 原生终端页：点头像进来看我干活的地方
// tabs/红绿灯/工具键/命令行 全套照 PWA 搬
struct TerminalView: View {
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)? = nil
    var mini = false
    var initialSession = "main"
    var availableSessions = ["main", "assistant", "gemini", "ghost"]
    @State private var session = "main"
    @State private var output = ""
    @State private var cmd = ""
    @State private var workState: CCWorkState = .resting
    @State private var pollTask: Task<Void, Never>?
    @State private var mode: TerminalMode = .cli
    @State private var modeResolved = false   // 第一次按 channel 定默认；之后她切了就听她的
    @State private var sdkSending = false
    @FocusState private var cmdFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty ? "…" : output)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(Color(red: 0.85, green: 0.87, blue: 0.85))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                        .textSelection(.enabled)
                        .id("out")
                }
                .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                .onTapGesture { cmdFocused = false }
                .onChange(of: output) { _ in
                    proxy.scrollTo("out", anchor: .bottom)
                }
            }
            if !mini {
                if mode == .cli { toolbar } else { sdkToolbar }
                inputBar
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: mini ? 24 : 0, style: .continuous))
        .overlay {
            if mini {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            }
        }
        .shadow(color: mini ? .black.opacity(0.2) : .clear, radius: 16, y: 6)
        .preferredColorScheme(.dark)
        .onAppear { session = initialSession; resolveMode(); startPoll() }
        .onDisappear { pollTask?.cancel() }
    }

    // 工作室那页传的是 work 会话，SDK 跟它没关系，不给切换
    private var canSwitchMode: Bool { availableSessions.contains("main") }

    private func resolveMode() {
        guard canSwitchMode, !modeResolved else { return }
        Task {
            if let ch = try? await AlcoveAPI.sdkChannel(), !modeResolved {
                mode = (ch == "sdk") ? .sdk : .cli
                modeResolved = true
                output = ""
                capture()
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 2) {
            ForEach([TerminalMode.cli, .sdk], id: \.self) { m in
                Button {
                    guard mode != m else { return }
                    modeResolved = true
                    mode = m
                    output = ""
                    capture()
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(mode == m ? .black : .gray)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(mode == m ? Color(red: 0.62, green: 0.87, blue: 0.66) : .clear,
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            if !mini {
                Button {
                    if let onDismiss { onDismiss() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                }
            }
            HStack(spacing: 5) {
                Circle().fill(lampColor(.disconnected))
                    .frame(width: 11, height: 11)
                Circle().fill(lampColor(.thinking))
                    .frame(width: 11, height: 11)
                Circle().fill(lampColor(.resting))
                    .frame(width: 11, height: 11)
            }
            .padding(.trailing, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if mode == .sdk {
                        Text("sdk")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.14), in: Capsule())
                    } else {
                        ForEach(availableSessions, id: \.self) { s in
                            Button {
                                session = s
                                output = ""
                                capture()
                            } label: {
                                Text(s)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(session == s ? .white : .gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(session == s ? Color.white.opacity(0.14) : .clear,
                                                in: Capsule())
                            }
                        }
                    }
                }
            }
            Spacer()
            if canSwitchMode { modeSwitch }
            if mini {
                Button { onDismiss?() } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起终端")
            }
        }
        .padding(.horizontal, mini ? 12 : 10)
        .padding(.vertical, mini ? 8 : 6)
    }

    // 三盏灯互斥：红=断线，黄=CC 正在思考/干活，绿=在线休息。
    private func lampColor(_ lamp: CCWorkState) -> Color {
        let active: Color
        switch lamp {
        case .disconnected:
            active = Color(red: 1, green: 0.37, blue: 0.34)
        case .thinking:
            active = Color(red: 1, green: 0.74, blue: 0.18)
        case .resting:
            active = Color(red: 0.16, green: 0.79, blue: 0.25)
        }
        return workState == lamp ? active : active.opacity(0.18)
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                termKey("Esc") { sendKey("Escape") }
                termKey("↑") { sendKey("Up") }
                termKey("↑↑") { sendKey("Up"); sendKey("Up") }
                termKey("↓") { sendKey("Down") }
                termKey("Tab") { sendKey("Tab") }
                termKey("Enter") { sendKey("Enter") }
                termKey("clear") { sendKeys("clear", enter: true) }
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 6)
    }

    // SDK 没有按键可发，给两个真有用的：刷新、回到底部
    private var sdkToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                termKey("刷新") { capture() }
                termKey("清屏") { output = "" }
                Text(sdkSending ? "发送中…" : (workState == .thinking ? "陈璟在想…" : "session 空闲"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 6)
    }

    private func termKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.green)
            TextField("命令", text: $cmd)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($cmdFocused)
                .onSubmit(sendCmd)
            Button(action: sendCmd) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(cmd.isEmpty ? .gray : .green)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
    }

    // MARK: 网络

    private func startPoll() {
        pollTask = Task {
            capture()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                capture()
            }
        }
    }

    private func capture() {
        if mode == .sdk { captureSDK(); return }
        Task {
            var comps = URLComponents(url: AlcoveAPI.fullURL("/api/terminal/capture"),
                                      resolvingAgainstBaseURL: false)!
            var query = [URLQueryItem(name: "session", value: session),
                         URLQueryItem(name: "lines", value: "120"),
                         URLQueryItem(name: "columns", value: "80")]
            if mini { query.append(URLQueryItem(name: "clean", value: "1")) }
            comps.queryItems = query
            guard let (data, _) = try? await AlcoveAPI.session.data(from: comps.url!),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                workState = .disconnected
                return
            }
            if let content = obj["content"] as? String {
                output = content
                // /api/poll 是聊天页已经在用的 CC 实时状态，不靠终端文字猜。
                if let status = try? await AlcoveAPI.poll(since: nil, limit: 1) {
                    workState = status.isTyping ? .thinking : .resting
                } else {
                    workState = .disconnected
                }
            } else {
                workState = .disconnected
            }
        }
    }

    // SDK 终端：session 记录 + 正在进行的这一轮（实时流）拼在一起，两秒一刷跟 tmux 一个节奏
    private func captureSDK() {
        Task {
            guard let r = try? await AlcoveAPI.sdkTerminal(lines: mini ? 60 : 120) else {
                workState = .disconnected
                return
            }
            let busy = r.busy
            var text = r.content
            if busy, let live = try? await AlcoveAPI.liveStream(), live.active {
                // 正在跑的这轮 jsonl 还没落全，把实时流接在转轮后面，像 CLI 边想边打字那样
                var tail: [String] = []
                if !live.thinking.isEmpty {
                    tail.append("∴ " + live.thinking.replacingOccurrences(of: "\n", with: "\n  "))
                }
                for t in live.tools where !t.name.isEmpty { tail.append("⏺ " + t.name) }
                let say = live.say.isEmpty ? live.pendingSay : live.say
                if !say.isEmpty { tail.append("● " + say.replacingOccurrences(of: "\n", with: "\n  ")) }
                if !tail.isEmpty { text += tail.joined(separator: "\n") + "\n" }
            }
            output = text
            workState = busy ? .thinking : .resting
        }
    }

    private func sendCmd() {
        let c = cmd.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        cmd = ""
        if mode == .sdk {
            // SDK 没有命令行可敲：这里敲的就是一句话，走主聊天同一条路（会落进聊天页，跟 tmux 里打字一个效果）
            sdkSending = true
            Task {
                _ = try? await AlcoveAPI.send(text: c)
                sdkSending = false
                capture()
            }
            return
        }
        sendKeys(c, enter: true)
    }

    private func sendKeys(_ keys: String, enter: Bool) {
        post(["keys": keys, "session": session, "enter": enter])
    }

    private func sendKey(_ key: String) {
        post(["key": key, "session": session])
    }

    private func post(_ body: [String: Any]) {
        Task {
            var req = URLRequest(url: AlcoveAPI.fullURL("/api/terminal/send"))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await AlcoveAPI.session.data(for: req)
            try? await Task.sleep(nanoseconds: 400_000_000)
            capture()
        }
    }
}
