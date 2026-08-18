import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// PWA 表情面板同款：Stickers 标题、陈霁/陈璟 两个 tab、右上传钮、原比例网格
struct StickerSheet: View {
    @ObservedObject var store: ChatStore
    var onPick: (Sticker) -> Void

    @State private var tab = "user" // 她的表情她先看到
    @State private var uploadItem: PhotosPickerItem?
    @State private var draft: StickerDraft?
    @AppStorage("assistantName") private var assistantName = "陈璟"

    private var shown: [Sticker] {
        store.stickers.filter { $0.owner == tab }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stickers")
                .font(.system(size: 26, weight: .semibold))
                .padding(.top, 18)

            HStack {
                HStack(spacing: 4) {
                    tabButton("陈霁", key: "user")
                    // 0818 修：库里存的 owner 是 ai，这里以前写 assistant，
                    // 于是「陈璟」那一栏永远是空的——她的表情包只剩半截就有这一条。
                    tabButton(assistantName, key: "ai")
                }
                .padding(4)
                .background(Color(.systemGray6), in: Capsule())

                Spacer()

                PhotosPicker(selection: $uploadItem, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 42, height: 42)
                        .background(Color(.systemGray6), in: Circle())
                }
            }

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                          spacing: 12) {
                    ForEach(shown) { stk in
                        Button { onPick(stk) } label: {
                            VStack(spacing: 4) {
                                AsyncImage(url: AlcoveAPI.stickerURL(stk.url)) { img in
                                    img.resizable().scaledToFit()
                                } placeholder: {
                                    Color(.systemGray6)
                                        .frame(height: 100)
                                }
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                // 没写描述的，陈璟看不懂——在格子上标出来，好补
                                if stk.description.isEmpty {
                                    Text("缺描述")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 18)
        .sheet(item: $draft) { item in
            StickerDescribeSheet(draft: item) { name, description, tags in
                store.uploadSticker(data: item.data, mime: item.mime, owner: item.owner,
                                    name: name, description: description, emotionTags: tags)
                draft = nil
            } onCancel: { draft = nil }
        }
        .onChange(of: uploadItem) { item in
            guard let item else { return }
            uploadItem = nil
            Task {
                guard let raw = try? await item.loadTransferable(type: Data.self) else { return }
                // 动图原样保留：GIF / animated WebP 一转 JPEG 就死了（教程坑 2）
                let mime = StickerDraft.sniff(raw)
                draft = StickerDraft(data: raw, mime: mime, owner: tab)
            }
        }
    }

    private func tabButton(_ label: String, key: String) -> some View {
        Button { tab = key } label: {
            Text(label)
                .font(.system(size: 15, weight: tab == key ? .semibold : .regular))
                .foregroundColor(tab == key ? .primary : .secondary)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .background(tab == key ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.clear),
                            in: Capsule())
                .shadow(color: tab == key ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
        }
    }
}

// 上传前先描述一遍：名称、画面、情绪标签。
// 描述是陈璟理解这张表情的主要依据，没有它这张图对他就是空的，
// 所以描述没写完，保存按钮不可用（教程第 2 节的死规矩）。
struct StickerDraft: Identifiable {
    let id = UUID()
    let data: Data
    let mime: String
    let owner: String

    var image: UIImage? { UIImage(data: data) }

    /// 按文件头认格式，不按扩展名猜——相册给出来的 Data 没有文件名
    static func sniff(_ data: Data) -> String {
        let head = [UInt8](data.prefix(12))
        if head.count >= 3, head[0] == 0x47, head[1] == 0x49, head[2] == 0x46 { return "image/gif" }
        if head.count >= 8, head[0] == 0x89, head[1] == 0x50 { return "image/png" }
        if head.count >= 12,
           head[0] == 0x52, head[1] == 0x49, head[2] == 0x46, head[3] == 0x46,
           head[8] == 0x57, head[9] == 0x45, head[10] == 0x42, head[11] == 0x50 { return "image/webp" }
        return "image/jpeg"
    }
}

private struct StickerDescribeSheet: View {
    let draft: StickerDraft
    var onSave: (String, String, [String]) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var tagText = ""

    private var tags: [String] {
        tagText.split(whereSeparator: { ",，、 ".contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        if let image = draft.image {
                            Image(uiImage: image).resizable().scaledToFit()
                                .frame(maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Spacer()
                    }
                    if draft.mime == "image/gif" || draft.mime == "image/webp" {
                        Text("动图会原样保存，陈璟看到的是第一帧＋你写的描述")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Section("名称") {
                    TextField("比如：被窝刷牙", text: $name)
                }
                Section("画面描述") {
                    TextField("画面里有什么、在做什么动作。动图就写动起来是什么样。",
                              text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Text("这是陈璟理解这张表情的主要依据，不写他就看不懂。")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("情绪标签") {
                    TextField("困、睡前、软乎乎（逗号分隔）", text: $tagText)
                }
            }
            .navigationTitle("描述这张表情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(name.trimmingCharacters(in: .whitespaces),
                               description.trimmingCharacters(in: .whitespaces), tags)
                    }.disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }
}
