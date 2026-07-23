import SwiftUI
import PhotosUI

// PWA 表情面板同款：Stickers 标题、陈霁/陈璟 两个 tab、右上传钮、原比例网格
struct StickerSheet: View {
    @ObservedObject var store: ChatStore
    var onPick: (Sticker) -> Void

    @State private var tab = "user" // 她的表情她先看到
    @State private var uploadItem: PhotosPickerItem?
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
                    tabButton(assistantName, key: "assistant")
                }
                .padding(4)
                .background(Color(.systemGray6), in: Capsule())

                Spacer()

                PhotosPicker(selection: $uploadItem, matching: .images) {
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
                            AsyncImage(url: AlcoveAPI.stickerURL(stk.url)) { img in
                                img.resizable().scaledToFit()
                            } placeholder: {
                                Color(.systemGray6)
                                    .frame(height: 100)
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 18)
        .onChange(of: uploadItem) { item in
            guard let item else { return }
            uploadItem = nil
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self) {
                    // GIF 保持原格式，其余转 JPEG
                    let isGif = raw.count > 3 && raw.prefix(3) == Data("GIF".utf8)
                    if isGif {
                        store.uploadSticker(data: raw, mime: "image/gif", owner: tab)
                    } else if let img = UIImage(data: raw),
                              let jpeg = img.jpegData(compressionQuality: 0.9) {
                        store.uploadSticker(data: jpeg, mime: "image/jpeg", owner: tab)
                    }
                }
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
