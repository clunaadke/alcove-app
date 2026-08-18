import SwiftUI
import SafariServices

// 链接小卡片（她 2026-08-18 问「发你小红书链接要咋样才能渲染成小卡片」）
//
// 正文里带链接的消息，气泡下面长一张卡：封面 + 标题 + 作者·赞 + 站点·图数。
// 数据从后端 /api/linkcard?url= 取（后端拿家里那个登录着的浏览器去读页面，
// 封面存本地，同一链接只抓一次）。点开走 Safari 视图，登录态跟着系统 Safari。

struct LinkCard: Equatable {
    let url: String
    let finalURL: String
    let kind: String
    let site: String
    let title: String
    let author: String
    let likes: String
    let cover: String
    let images: Int

    init?(_ raw: [String: Any]?) {
        guard let raw, let url = raw["url"] as? String, !url.isEmpty else { return nil }
        self.url = url
        finalURL = raw["finalUrl"] as? String ?? url
        kind = raw["kind"] as? String ?? "web"
        site = raw["site"] as? String ?? ""
        title = raw["title"] as? String ?? ""
        author = raw["author"] as? String ?? ""
        likes = raw["likes"] as? String ?? ""
        cover = raw["cover"] as? String ?? ""
        images = (raw["images"] as? NSNumber)?.intValue ?? 0
    }

    var coverURL: URL? { cover.isEmpty ? nil : AlcoveAPI.attachmentURL(cover) }
    var openURL: URL? { URL(string: finalURL.isEmpty ? url : finalURL) }
}

@MainActor
final class LinkCardStore: ObservableObject {
    static let shared = LinkCardStore()

    enum State: Equatable { case loading, ready(LinkCard), failed }
    @Published private(set) var cards: [String: State] = [:]

    func state(for url: String) -> State? { cards[url] }

    func load(_ url: String) {
        guard cards[url] == nil else { return }
        cards[url] = .loading
        Task { [weak self] in
            var comps = URLComponents(url: AlcoveAPI.fullURL("/api/linkcard"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "url", value: url)]
            var req = URLRequest(url: comps.url!)
            req.timeoutInterval = 40          // 后端第一次要开浏览器去读，给它点时间
            guard let (data, _) = try? await AlcoveAPI.session.data(for: req),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let card = LinkCard(obj["card"] as? [String: Any]) else {
                self?.cards[url] = .failed
                return
            }
            self?.cards[url] = .ready(card)
        }
    }
}

extension ChatMessage {
    /// 正文里第一个链接。有它就在气泡下面长一张卡。
    var firstLinkURL: String? {
        let text = displayText
        guard text.contains("http") else { return nil }
        guard let range = text.range(of: #"https?://[^\s<>"'）)]+"#, options: .regularExpression) else { return nil }
        var s = String(text[range])
        while let last = s.last, ".,;:!?，。！？、".contains(last) { s.removeLast() }
        return s
    }

    /// 气泡里的正文：有卡片的话把那行链接藏掉（卡就在下面），别的字照旧
    var textWithoutLink: String {
        guard let link = firstLinkURL else { return displayText }
        let stripped = displayText.replacingOccurrences(of: link, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? displayText : stripped
    }

    /// 整条正文就只是一个链接——那就只留卡，不再吐一个光秃秃的链接气泡
    var isBareLink: Bool {
        guard let link = firstLinkURL else { return false }
        return displayText.trimmingCharacters(in: .whitespacesAndNewlines) == link
    }
}

struct LinkPreviewCard: View {
    let url: String
    let theme: AlcoveTheme
    let isUser: Bool
    @ObservedObject private var store = LinkCardStore.shared
    @State private var opening = false

    var body: some View {
        Group {
            switch store.state(for: url) {
            case .ready(let card):
                Button { opening = true } label: { body(for: card) }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $opening) {
                        if let u = card.openURL { SafariSheet(url: u).ignoresSafeArea() }
                    }
                    .contextMenu {
                        if let u = card.openURL {
                            Button { UIApplication.shared.open(u) } label: { Label("在浏览器打开", systemImage: "safari") }
                            Button { UIPasteboard.general.string = u.absoluteString } label: { Label("复制链接", systemImage: "doc.on.doc") }
                        }
                    }
            case .loading:
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.7).tint(theme.fyAccent)
                    Text("正在把那页取回来…")
                        .font(.system(size: 11, design: .serif)).foregroundColor(theme.textDim)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(theme.fyCard.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
            case .failed, .none:
                // 抓不到就什么都不画——链接本身还在气泡里，不碍事
                EmptyView()
            }
        }
        .onAppear { store.load(url) }
    }

    private func body(for card: LinkCard) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Color.black.opacity(0.06)
                if let cover = card.coverURL {
                    AsyncImage(url: cover) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: card.kind == "xhs" ? "book.closed" : "link")
                            .foregroundColor(theme.textDim.opacity(0.5))
                    }
                } else {
                    Image(systemName: card.kind == "xhs" ? "book.closed" : "link")
                        .foregroundColor(theme.textDim.opacity(0.5))
                }
            }
            .frame(width: 66, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title.isEmpty ? card.url : card.title)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !card.author.isEmpty || !card.likes.isEmpty {
                    Text([card.author.isEmpty ? "" : "@\(card.author)",
                          card.likes.isEmpty ? "" : "赞 \(card.likes)"]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 11.5, design: .serif))
                        .foregroundColor(theme.textDim)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(card.kind == "xhs" ? "📕" : "🔗").font(.system(size: 10))
                    Text([card.site, card.images > 0 ? "\(card.images) 张图" : ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 10.5, design: .serif))
                        .foregroundColor(theme.textDim.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: 300, alignment: .leading)
        .background(theme.fyCard.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.fyBorder.opacity(0.7), lineWidth: 0.7))
    }
}

/// SFSafariViewController 的 SwiftUI 壳：小红书这类站在里面能正常登录、能滑图
struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: cfg)
        vc.dismissButtonStyle = .close
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
