import SwiftUI
import CryptoKit

/// 0821 她要的「微信那样」的图片缓存：看过的图存进手机自己的存储
/// （Caches/alcove-images），下次直接从本地开，不再去服务器拉；
/// 设置页能看大小、按日期清、只留最近几天、全部清空。VPS 一个字节不多占。
final class ImageDiskCache {
    static let shared = ImageDiskCache()

    let dir: URL
    private let mem = NSCache<NSURL, UIImage>()
    private var inflight: [URL: Task<UIImage?, Never>] = [:]
    private let lock = NSLock()

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = caches.appendingPathComponent("alcove-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        mem.countLimit = 400
    }

    // MARK: - 读

    func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(name + ".img")
    }

    /// 同步命中：内存或硬盘里有就立刻给，没有返回 nil（不发网络）
    func cached(_ url: URL) -> UIImage? {
        if let hit = mem.object(forKey: url as NSURL) { return hit }
        let f = fileURL(for: url)
        guard let data = try? Data(contentsOf: f), let img = UIImage(data: data) else { return nil }
        mem.setObject(img, forKey: url as NSURL)
        return img
    }

    /// 本地没有就下载一次、落盘、进内存。同一个 URL 并发只下一次。
    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        lock.lock()
        if let running = inflight[url] {
            lock.unlock()
            return await running.value
        }
        let task = Task<UIImage?, Never> { [self] in
            defer {
                lock.lock(); inflight[url] = nil; lock.unlock()
            }
            guard let (data, resp) = try? await URLSession.shared.data(from: url),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let img = UIImage(data: data) else { return nil }
            try? data.write(to: fileURL(for: url), options: .atomic)
            mem.setObject(img, forKey: url as NSURL)
            return img
        }
        inflight[url] = task
        lock.unlock()
        return await task.value
    }

    /// 预热：还没存的才下，四个一起，不阻塞界面
    func prefetch(_ urls: [URL]) async {
        let todo = urls.filter { !FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
        guard !todo.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            var it = todo.makeIterator()
            for _ in 0..<4 {
                if let u = it.next() { group.addTask { _ = await self.image(for: u) } }
            }
            for await _ in group {
                if let u = it.next() { group.addTask { _ = await self.image(for: u) } }
            }
        }
    }

    /// 最近 N 天聊天里的图（缩略图那份，气泡里用的就是它），打开 app 时后台存好
    func prewarmRecent(days: Int) async {
        guard let obj = try? await AlcoveAPI.getRaw("/api/attachments/recent?days=\(days)"),
              let raw = obj["urls"] as? [String] else { return }
        await prefetch(raw.map { AlcoveAPI.attachmentThumbnailURL($0) })
    }

    // MARK: - 算账 / 清理

    private func entries() -> [(url: URL, size: Int64, date: Date)] {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: Array(keys)) else { return [] }
        return files.compactMap { f in
            guard let v = try? f.resourceValues(forKeys: keys) else { return nil }
            return (f, Int64(v.fileSize ?? 0), v.contentModificationDate ?? .distantPast)
        }
    }

    func totalBytes() -> Int64 { entries().reduce(0) { $0 + $1.size } }
    func fileCount() -> Int { entries().count }
    func oldestDate() -> Date? { entries().map(\.date).min() }

    /// 清掉某天之前存的；传 nil 就是全部清。返回腾出来的字节数。
    @discardableResult
    func clear(before cutoff: Date?) -> Int64 {
        var freed: Int64 = 0
        for e in entries() where cutoff == nil || e.date < cutoff! {
            if (try? FileManager.default.removeItem(at: e.url)) != nil { freed += e.size }
        }
        mem.removeAllObjects()
        return freed
    }

    @discardableResult
    func keepRecent(days: Int) -> Int64 {
        clear(before: Calendar.current.date(byAdding: .day, value: -days, to: Date()))
    }

    static func format(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

// MARK: - 视图：跟 AsyncImage 同款用法，换个名字就行

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

/// `AsyncImage(url:) { img in } placeholder: { }` 的替身
struct CachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var ui: UIImage?

    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _ui = State(initialValue: url.flatMap { ImageDiskCache.shared.cached($0) })
    }

    var body: some View {
        Group {
            if let ui { content(Image(uiImage: ui)) } else { placeholder() }
        }
        // 0827：原来这里写的是 `guard let url, ui == nil`，
        // 于是 URL 换了、手里还攥着上一张图时就直接 return，图永远不换。
        // 信封的白天/黑夜两张就栽在这儿：她把开关掰过去，字色翻了，图还是黑的。
        .task(id: url) {
            guard let url else { ui = nil; return }
            if let hit = ImageDiskCache.shared.cached(url) { ui = hit; return }
            ui = await ImageDiskCache.shared.image(for: url)
        }
    }
}

/// `AsyncImage(url:) { phase in switch phase … }` 的替身
struct CachedPhaseImage<Content: View>: View {
    let url: URL?
    @ViewBuilder var content: (CachedImagePhase) -> Content
    @State private var phase: CachedImagePhase

    init(url: URL?, @ViewBuilder content: @escaping (CachedImagePhase) -> Content) {
        self.url = url
        self.content = content
        if let url, let hit = ImageDiskCache.shared.cached(url) {
            _phase = State(initialValue: .success(Image(uiImage: hit)))
        } else {
            _phase = State(initialValue: .empty)
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else { phase = .empty; return }
                // 同上：URL 换了就得重新取，不能因为手里已有一张成功的图就跳过
                if let hit = ImageDiskCache.shared.cached(url) {
                    phase = .success(Image(uiImage: hit)); return
                }
                if let img = await ImageDiskCache.shared.image(for: url) {
                    phase = .success(Image(uiImage: img))
                } else {
                    phase = .failure
                }
            }
    }
}
