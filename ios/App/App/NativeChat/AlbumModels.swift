import Foundation
import Combine

// Shared wire contract: docs/album-backend-contract.md. Album uploads deliberately
// use their own endpoint; /api/upload also sends chat messages and must not be used.
struct AlbumPhoto: Codable, Identifiable, Hashable {
    let photoId: String
    let originalUrl: String
    var thumbnailUrl: String?
    var caption: String?
    var categoryId: String?
    var categoryName: String?
    var uploadedBy: String?
    var source: String?
    var createdAt: String?
    var postStatus: String?
    var posts: [AlbumPost]?
    var id: String { photoId }
    var note: String { caption ?? "" }
    var category: String { categoryName ?? "未分类" }
    var isPosted: Bool { postStatus == "posted" || !(posts ?? []).isEmpty }
    var thumbnail: URL? { AlbumAPI.imageURL(thumbnailUrl ?? originalUrl) }
    var original: URL? { AlbumAPI.imageURL(originalUrl) }
}

struct AlbumPost: Codable, Hashable {
    let postId: String
    let publishedAt: String
    var url: String?
}

struct AlbumCategory: Codable, Identifiable, Hashable {
    let categoryId: String
    let name: String
    var count: Int?
    var coverUrl: String?
    var id: String { categoryId }
}

struct AlbumPage: Decodable {
    let photos: [AlbumPhoto]
    let nextCursor: String?
}

struct AlbumSavedBatch: Codable, Identifiable {
    let eventId: String
    let batchId: String
    let status: String
    let photos: [AlbumPhoto]
    var caption: String?
    var assistantName: String?
    var id: String { eventId }
    var isValid: Bool {
        status == "saved" && !eventId.isEmpty && !batchId.isEmpty && !photos.isEmpty
            && photos.allSatisfy { !$0.photoId.isEmpty && $0.original != nil }
            && Set(photos.map(\.photoId)).count == photos.count
    }
    var categorySummary: String {
        var seen = Set<String>()
        return photos.map(\.category).filter { seen.insert($0).inserted }.joined(separator: "、")
    }
    var summary: String {
        "\(assistantName ?? "他")往「\(categorySummary)」里存了\(photos.count == 1 ? "一" : String(photos.count))张照片"
    }
    static func decode(_ data: Data) -> AlbumSavedBatch? {
        guard let value = try? AlbumAPI.decoder().decode(Self.self, from: data), value.isValid else { return nil }
        return value
    }
}

enum AlbumAPI {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func imageURL(_ raw: String) -> URL? {
        guard !raw.isEmpty,
              let url = URL(string: raw, relativeTo: AlcoveAPI.base)?.absoluteURL,
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return raw.hasPrefix("/attachments/") ? AlcoveAPI.attachmentURL(raw) : url
    }

    static func request<T: Decodable>(_ path: String, method: String = "GET",
                                      body: [String: Any]? = nil) async throws -> T {
        var request = URLRequest(url: AlcoveAPI.fullURL(path))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await AlcoveAPI.session.data(for: request)
        try check(response)
        return try decoder().decode(T.self, from: data)
    }

    static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200..<300: return
        case 404, 501, 503: throw AlbumError.unavailable
        case 401, 403: throw AlbumError.denied
        case 413: throw AlbumError.tooLarge
        default: throw URLError(.badServerResponse)
        }
    }

    static func query(_ items: [URLQueryItem]) -> String {
        var parts = URLComponents()
        parts.queryItems = items
        return (parts.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
    }

    static func photos(category: String?, filter: String, search: String, cursor: String?) async throws -> AlbumPage {
        var items = [URLQueryItem(name: "limit", value: "60"), URLQueryItem(name: "filter", value: filter)]
        if let category { items.append(.init(name: "category_id", value: category)) }
        if !search.isEmpty { items.append(.init(name: "q", value: search)) }
        if let cursor { items.append(.init(name: "cursor", value: cursor)) }
        return try await request("/api/album/photos?" + query(items))
    }

    struct Categories: Decodable { let categories: [AlbumCategory] }
    struct PhotoResponse: Decodable { let photo: AlbumPhoto }
    struct CategoryResponse: Decodable { let category: AlbumCategory }

    static func categories() async throws -> [AlbumCategory] {
        let response: Categories = try await request("/api/album/categories")
        return response.categories
    }

    static func category(name: String, id: String? = nil) async throws -> AlbumCategory {
        var body: [String: Any] = ["name": name]
        if let id { body["category_id"] = id }
        let response: CategoryResponse = try await request("/api/album/categories", method: id == nil ? "POST" : "PATCH", body: body)
        return response.category
    }

    static func edit(_ photo: AlbumPhoto, caption: String, category: String?) async throws -> AlbumPhoto {
        let response: PhotoResponse = try await request("/api/album/photos", method: "PATCH", body: [
            "photo_id": photo.id, "caption": caption, "category_id": category as Any? ?? NSNull()
        ])
        return response.photo
    }

    // One photo per request. The request ID survives a failed retry; the server
    // must return the original saved record when the upload already committed.
    static func upload(data: Data, caption: String, category: String?, requestId: String) async throws -> AlbumPhoto {
        let boundary = "AlcoveAlbum-" + UUID().uuidString
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("caption", caption)
        if let category { field("category_id", category) }
        field("source", "album_upload")
        field("notify_assistant", "false")
        field("index_memory", "true")
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: AlcoveAPI.fullURL("/api/album/upload"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(requestId, forHTTPHeaderField: "Idempotency-Key")
        let (responseData, response) = try await AlcoveAPI.session.upload(for: request, from: body)
        try check(response)
        return try decoder().decode(PhotoResponse.self, from: responseData).photo
    }
}

enum AlbumError: LocalizedError {
    case unavailable, denied, tooLarge, invalidImage
    var errorDescription: String? {
        switch self {
        case .unavailable: return "相册暂时无法连接，请稍后重试。"
        case .denied: return "暂时无法访问相册，请检查连接权限。"
        case .tooLarge: return "这张照片太大了，请选择较小的图片。"
        case .invalidImage: return "这张图片没能读取，请重新选择。"
        }
    }
}

@MainActor
final class AlbumStore: ObservableObject {
    @Published var photos: [AlbumPhoto] = []
    @Published var categories: [AlbumCategory] = []
    @Published var loading = false
    @Published var error: String?
    @Published var categoryError: String?
    @Published var category: String?
    @Published var filter = "all"
    @Published var search = ""
    private var cursor: String?
    private var generation = 0
    private var loaded = false
    var hasMore: Bool { cursor != nil }
    var queryKey: String { [category ?? "", filter, search].joined(separator: "\u{1f}") }

    func loadCategories() async {
        do { categories = try await AlbumAPI.categories(); categoryError = nil }
        catch { if !Task.isCancelled { categoryError = error.localizedDescription } }
    }

    func reload() async {
        generation += 1
        let current = generation
        loading = true; error = nil; cursor = nil; loaded = false
        // Never show photos from the previous category beneath the new title.
        photos = []
        do {
            let result = try await AlbumAPI.photos(category: category, filter: filter, search: search, cursor: nil)
            guard current == generation, !Task.isCancelled else { return }
            var seen = Set<String>()
            photos = result.photos.filter { seen.insert($0.id).inserted }
            cursor = result.nextCursor.flatMap { $0.isEmpty ? nil : $0 }
            loaded = true
        } catch {
            if current == generation, !Task.isCancelled { self.error = error.localizedDescription }
        }
        if current == generation { loading = false }
    }

    func more() async {
        guard loaded, !loading, let cursor else { return }
        let current = generation
        loading = true; error = nil
        do {
            let result = try await AlbumAPI.photos(category: category, filter: filter, search: search, cursor: cursor)
            guard current == generation, !Task.isCancelled else { return }
            var seen = Set(photos.map(\.id))
            photos += result.photos.filter { seen.insert($0.id).inserted }
            self.cursor = result.nextCursor.flatMap { $0.isEmpty || $0 == cursor ? nil : $0 }
        } catch {
            if current == generation, !Task.isCancelled { self.error = error.localizedDescription }
        }
        if current == generation { loading = false }
    }
}
