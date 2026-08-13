import SwiftUI

private enum CCWorkState: Equatable {
    case disconnected
    case thinking
    case resting
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
                toolbar
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
        .onAppear { session = initialSession; startPoll() }
        .onDisappear { pollTask?.cancel() }
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
            Spacer()
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

    private func sendCmd() {
        let c = cmd.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        cmd = ""
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
