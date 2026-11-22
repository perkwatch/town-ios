import ActivityKit

struct TownPresenceAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var headline: String
        var detail: String
        var freshCount: Int
    }
}
