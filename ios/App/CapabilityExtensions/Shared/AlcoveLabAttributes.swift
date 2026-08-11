import ActivityKit
import Foundation

struct AlcoveLabAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var message: String
        var startedAt: Date
        var bpm: Int
    }

    var name: String
}
