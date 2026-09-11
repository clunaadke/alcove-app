import Foundation

// Run on macOS: swiftc ios/App/App/NativeChat/AlbumModels.swift scripts/album-tests/main.swift -o /tmp/album-tests && /tmp/album-tests
// Isolate the real wire models from UIKit and the rest of the app.
enum AlcoveAPI {
    static let base = URL(string: "https://album-test.invalid")!
    static let session = URLSession.shared
    static func fullURL(_ path: String) -> URL { URL(string: path, relativeTo: base)!.absoluteURL }
    static func attachmentURL(_ path: String) -> URL {
        fullURL(path.hasPrefix("/attachments/") ? "/api" + path : path)
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let photo: [String: Any] = [
    "photo_id": "p1", "original_url": "/attachments/1.jpg", "thumbnail_url": "/thumbs/1.jpg",
    "caption": "今天的雨", "category_id": "c1", "category_name": "日常", "post_status": "unused"
]
var payload: [String: Any] = ["event_id": "e1", "batch_id": "b1", "status": "saved", "photos": [photo]]
func decode(_ object: [String: Any]) -> AlbumSavedBatch? {
    AlbumSavedBatch.decode(try! JSONSerialization.data(withJSONObject: object))
}
let single = decode(payload)!
expect(single.photos.count == 1 && single.photos[0].note == "今天的雨", "Snake-case decoding must retain the caption")
expect(single.photos[0].original?.path == "/api/attachments/1.jpg", "Legacy attachment URLs must use the existing API route")
expect(!single.photos[0].isPosted, "An unused photo must not appear posted")
expect(single.summary.contains("日常") && single.summary.contains("一张"), "Saved card needs category and count")
var second = photo; second["photo_id"] = "p2"; second["category_name"] = "旅行"
payload["photos"] = [second, photo]
expect(decode(payload)?.photos.map(\.id) == ["p2", "p1"], "Server batch order determines the hero image")
expect(decode(payload)?.categorySummary == "旅行、日常", "Mixed-category batches must preserve ordered category names")
payload["photos"] = [photo, photo]
expect(decode(payload) == nil, "Duplicate photo IDs must not reach SwiftUI ForEach")
payload["photos"] = [photo]
for status in ["pending", "failed", "saving"] {
    payload["status"] = status
    expect(decode(payload) == nil, "Uncommitted saves must not render success cards")
}
payload["status"] = "saved"; payload["photos"] = []
expect(decode(payload) == nil, "Empty batches must not render or index photos[0]")
payload["photos"] = [photo]; payload["event_id"] = ""
expect(decode(payload) == nil, "Events require stable IDs")
expect(AlbumAPI.imageURL("file:///tmp/private") == nil, "Remote images cannot open local files")
expect(AlbumAPI.imageURL("javascript:alert(1)") == nil, "Remote images need HTTP(S)")
var posted = photo
posted["posts"] = [["post_id": "x1", "published_at": "2026-09-11T10:00:00Z"]]
let postedPhoto = try! AlbumAPI.decoder().decode(AlbumPhoto.self, from: JSONSerialization.data(withJSONObject: posted))
expect(postedPhoto.isPosted, "Post history overrides a stale unused flag")
let query = AlbumAPI.query([URLQueryItem(name: "q", value: "雨 & 你"), URLQueryItem(name: "cursor", value: "next=1&x+2")])
let parts = URLComponents(string: "https://album-test.invalid/?" + query)!
expect(parts.queryItems?.first?.value == "雨 & 你", "Search must survive query encoding")
expect(parts.queryItems?.last?.value == "next=1&x+2", "Cursor must not inject query fields")
print("Album contract: all checks passed")
