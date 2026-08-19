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
            if f.key == "heartbeat" {
                // 心跳走专用的：整条 prompt 摆出来，代码算的锁住给她看，
                // 她写的那几段给她改（0819 她要的：「完整的不缺一个字的prompt」）
                PromptEditor(palette: palette) { Task { await load() } }
            } else {
                FactoryEditor(palette: palette, file: f) { Task { await load() } }
            }
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


// MARK: - 心跳 prompt：整条摆出来，锁住的给她看，她写的给她改

private struct PromptBlock: Identifiable {
    let id = UUID()
    let kind: String        // locked / edit / gap
    let key: String
    let label: String
    let note: String
    let text: String
    let empty: Bool

    init(_ raw: [String: Any]) {
        kind = raw.string("kind")
        key = raw.string("key")
        label = raw.string("label")
        note = raw.string("note")
        text = raw.string("text")
        empty = raw.bool("empty")
    }
}

private struct PromptEditor: View {
    let palette: GlassPalette
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var blocks: [PromptBlock] = []
    @State private var edits: [String: String] = [:]
    @State private var original: [String: String] = [:]
    @State private var loading = true
    @State private var saving = false
    @State private var note = ""

    private var dirty: Bool { edits != original }

    var body: some View {
        ZStack {
            GlassBackdrop(palette: palette)
            VStack(spacing: 0) {
                GlassHeader(title: "心跳 prompt", palette: palette, onBack: { dismiss() })
                if loading {
                    Spacer(); ProgressView().tint(palette.ink3); Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("这是他被叫醒时读到的**整条**——灰的是代码现算的，改不了但看得见；\n带框的是你写的，随便改。")
                                .font(.system(size: 10.5))
                                .foregroundColor(palette.ink3)
                                .lineSpacing(3)
                                .padding(.bottom, 14)
                            ForEach(blocks) { b in
                                block(b)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                    bottomBar
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder private func block(_ b: PromptBlock) -> some View {
        if b.kind == "gap" {
            Rectangle().fill(Color.clear).frame(height: 10)
        } else if b.kind == "locked" {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill").font(.system(size: 8))
                    Text(b.label).font(.system(size: 10, weight: .medium)).tracking(0.5)
                    Spacer(minLength: 0)
                }
                .foregroundColor(palette.ink3)
                if b.empty {
                    Text("（现在是空的，有未读的时候这块才出现）")
                        .font(.system(size: 11.5))
                        .foregroundColor(palette.ink3.opacity(0.7))
                        .italic()
                } else {
                    Text(b.text)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundColor(palette.ink2)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !b.note.isEmpty {
                    Text(b.note).font(.system(size: 9.5)).foregroundColor(palette.ink3.opacity(0.8))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.ink3.opacity(0.07)))
            .padding(.bottom, 9)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "pencil").font(.system(size: 8))
                    Text(b.label).font(.system(size: 10, weight: .medium)).tracking(0.5)
                    Spacer(minLength: 0)
                    Text("\(edits[b.key]?.count ?? 0) 字")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(palette.acc)
                TextEditor(text: Binding(
                    get: { edits[b.key] ?? "" },
                    set: { edits[b.key] = $0 }))
                    .font(.system(size: 12.5))
                    .foregroundColor(palette.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 92, maxHeight: 260)
                    .padding(.horizontal, 6)
                if !b.note.isEmpty {
                    Text(b.note).font(.system(size: 9.5)).foregroundColor(palette.ink3)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(palette, radius: 13)
            .padding(.bottom, 9)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if !note.isEmpty {
                Text(note).font(.system(size: 10.5)).foregroundColor(palette.gold).lineLimit(2)
            }
            Spacer(minLength: 0)
            Button { Task { await save() } } label: {
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

    private func load() async {
        let raw = (try? await NativeHouseAPI.object("/api/files/prompt")) ?? [:]
        let bs = raw.array("blocks").map { PromptBlock($0) }
        var e: [String: String] = [:]
        for b in bs where b.kind == "edit" {
            e[b.key] = b.text
        }
        await MainActor.run {
            blocks = bs
            edits = e
            original = e
            loading = false
        }
    }

    private func save() async {
        await MainActor.run { saving = true }
        // {hdr} 是拼的时候换成 token 的，存回去要写回占位符
        var payload: [String: String] = [:]
        for (k, v) in edits {
            payload[k] = v.replacingOccurrences(
                of: "-H \"Content-Type: application/json\" -H \"X-Auth-Token: $(cat /root/.ots/secret)\"",
                with: "{hdr}")
        }
        let raw = (try? await NativeHouseAPI.object(
            "/api/files/prompt", method: "POST", body: ["sections": payload])) ?? [:]
        await MainActor.run {
            saving = false
            note = raw.string("note")
            if raw.bool("ok") { original = edits }
            onSaved()
        }
        await load()
    }
}
