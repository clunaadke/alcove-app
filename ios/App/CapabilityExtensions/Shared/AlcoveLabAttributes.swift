import ActivityKit
import Foundation

struct AlcoveLabAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var message: String
        var startedAt: Date
    }

    var name: String
}
