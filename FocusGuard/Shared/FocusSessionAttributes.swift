import ActivityKit
import Foundation

struct FocusSessionAttributes: ActivityAttributes {
    var sessionName: String
    var groupName: String

    struct ContentState: Codable, Hashable {
        var secondsRemaining: Int
        var openCount: Int
        var maxOpenCount: Int
        var isHardBlocked: Bool
        var targetAppName: String
    }
}
