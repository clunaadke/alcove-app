import SwiftUI

// 出厂设置（2026-08-19 她要的面板）。
//
// 她原话：「我还想加一个我能直接改心跳prompt的面板，直接连接后端的改完自动重启。
// 这样不用老麻烦你了哦！」后来又补：「你的claude.md、output style、hook我是不是
// 也都能让你做个前端我自己改」「memory里我也能改吗」。
//
// 能改的只有白名单里那些纯文本：心跳文案、说话方式、情书、开窗喂的几份、memory。
// stop hook 不进来（她定的）——那是他说话的通道，剪错一刀就哑了。
//
// 每次存之前后端自动留一份带时间戳的旧版，右上角能翻回去。存完按文件跑生效动作：
// 心跳文案 → 重启心跳；说话方式 → 重拼 output style；情书 → cp 成 CLAUDE.md。

private struct FactoryFile: Identifiable {
    var id: String { key + "/" + name }
    let key: String
    let name: String
    let title: String
    let desc: String
    let chars: Int
    let at: String

    init(_ raw: [String: Any]) {
        key = raw.string("key")
        name = raw.string("name")
        title = raw.string("title")
        desc = raw.string("desc")
        chars = raw.int("chars")
        at = raw.string("at")
    }
}

private struct FactoryGroup: Identifiable {
    var id: String { group }
    let group: String
    let items: [FactoryFile]
}

struct NativeFactoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoveTheme") private var themeName = "haven"

    @State private var groups: [FactoryGroup] = []
    @State private var loading = true
    @State private var opened: FactoryFile?

    private var palette: GlassPalette { .named(themeName) }

    var body: some View {
        ZStack {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                GlassHeader(title: "出厂设置", palette: palette, onBack: { dismiss() })
                if loading {
                    Spacer(); ProgressView().tint(palette.ink3); Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Text("改坏了最多他说话变怪，右上角能翻回上一版")
                                .font(.system(size: 10.5))
                                .foregroundColor(palette.ink3)
                                .padding(.bottom, 12)
                            ForEach(groups) { g in
                                Text(g.group.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(2)
                                    .foregroundColor(palette.acc.opacity(0.85))
                                    .padding(.top, 14).padding(.bottom, 8)
                                ForEach(g.items) { f in
                                    row(f).onTapGesture { opened = f }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .task { await load() }
        .sheet(item: $opened) { f in
            FactoryEditor(palette: palette, file: f) { Task { await load() } }
        }
    }

    private func row(_ f: FactoryFile) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(f.title)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(palette.ink)
                if !f.desc.isEmpty {
                    Text(f.desc).font(.system(size: 10.5)).foregroundColor(palette.ink3)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(f.chars) B")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(palette.ink3)
                Text(f.at)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(palette.ink3.opacity(0.75))
            }
            Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(palette.ink3)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(palette, radius: 14)
        .padding(.bottom, 8)
    }

    private func load() async {
        let raw = (try? await NativeHouseAPI.object("/api/files/list")) ?? [:]
        let gs = raw.array("groups").map { g in
            FactoryGroup(group: g.string("group"),
                         items: g.array("items").map { FactoryFile($0) })
        }
        await MainActor.run { groups = gs; loading = false }
    }
}

// MARK: - 编辑器

private struct FactoryEditor: View {
    let palette: GlassPalette
    let file: FactoryFile
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var original = ""
    @State private var versions: [String] = []
    @State private var loading = true
    @State private var saving = false
    @State private var note = ""
    @State private var showVersions = false

    private var dirty: Bool { text != original && !text.isEmpty }

    var body: some View {
        ZStack {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                GlassHeader(title: file.title, palette: palette, onBack: { dismiss() },
                            trailing: AnyView(versionButton))
                if loading {
                    Spacer(); ProgressView().tint(palette.ink3); Spacer()
                } else {
                    if !note.isEmpty {
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundColor(palette.gold)
                            .padding(.horizontal, 18).padding(.bottom, 6)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 13.5, design: .monospaced))
                        .foregroundColor(palette.ink)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 13)
                        .glassCard(palette, radius: 16)
                        .padding(.horizontal, 14)
                    HStack(spacing: 10) {
                        Text("\(text.count) 字")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(palette.ink3)
                        Spacer()
                        Button {
                            Task { await save() }
                        } label: {
                            Text(saving ? "存着…" : (dirty ? "存下来" : "没改动"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(dirty ? palette.ink : palette.ink3)
                                .padding(.horizontal, 20).padding(.vertical, 9)
                                .background(Capsule().fill(dirty ? palette.glass : Color.clear))
                                .overlay(Capsule().strokeBorder(
                                    dirty ? palette.line : palette.ink3.opacity(0.25), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!dirty || saving)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
        }
        .task { await load() }
        .confirmationDialog("翻回哪一版", isPresented: $showVersions, titleVisibility: .visible) {
            ForEach(versions.prefix(8), id: \.self) { v in
                Button(pretty(v)) { Task { await restore(v) } }
            }
            Button("算了", role: .cancel) {}
        }
    }

    private var versionButton: some View {
        Button { showVersions = true } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(versions.isEmpty ? palette.ink3.opacity(0.4) : palette.ink2)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(versions.isEmpty)
    }

    private func pretty(_ v: String) -> String {
        guard v.count >= 15 else { return v }
        let a = v.index(v.startIndex, offsetBy: 4)
        let b = v.index(v.startIndex, offsetBy: 8)
        let c = v.index(v.startIndex, offsetBy: 11)
        let d = v.index(v.startIndex, offsetBy: 13)
        return "\(v[a..<b].prefix(2))-\(v[b..<v.index(b, offsetBy: 2)]) \(v[c..<d]):\(v[d..<v.index(d, offsetBy: 2)])"
    }

    private func query() -> String {
        var q = "key=\(file.key)"
        if !file.name.isEmpty,
           let e = file.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            q += "&name=" + e
        }
        return q
    }

    private func load() async {
        let raw = (try? await NativeHouseAPI.object("/api/files/read?" + query())) ?? [:]
        await MainActor.run {
            text = raw.string("text")
            original = text
            versions = raw["versions"] as? [String] ?? []
            loading = false
        }
    }

    private func save() async {
        await MainActor.run { saving = true }
        var body: [String: Any] = ["key": file.key, "text": text]
        if !file.name.isEmpty { body["name"] = file.name }
        let raw = (try? await NativeHouseAPI.object(
            "/api/files/write", method: "POST", body: body)) ?? [:]
        await MainActor.run {
            saving = false
            note = raw.string("note")
            if raw.bool("ok") { original = text }
            onSaved()
        }
        await load()
    }

    private func restore(_ v: String) async {
        var body: [String: Any] = ["key": file.key, "version": v]
        if !file.name.isEmpty { body["name"] = file.name }
        let raw = (try? await NativeHouseAPI.object(
            "/api/files/restore", method: "POST", body: body)) ?? [:]
        await MainActor.run { note = raw.string("note") }
        await load()
        onSaved()
    }
}
