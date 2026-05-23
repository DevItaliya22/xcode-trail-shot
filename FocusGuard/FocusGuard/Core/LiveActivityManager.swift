@preconcurrency import ActivityKit
import Combine
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var activity: Activity<FocusSessionAttributes>?
    private var maxOpenCount: Int = 3

    private init() {}

    func startSession(group: AppGroup, targetApp: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attrs = FocusSessionAttributes(
            sessionName: group.name,
            groupName: group.name
        )
        maxOpenCount = group.maxOpenCount
        let state = FocusSessionAttributes.ContentState(
            secondsRemaining: group.onDemandMinutes * 60,
            openCount: SharedStore.shared.openCount(forGroup: group),
            maxOpenCount: group.maxOpenCount,
            isHardBlocked: false,
            targetAppName: targetApp
        )

        activity = try? Activity.request(
            attributes: attrs,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )

        let session = ActiveSession(
            groupName: group.name,
            targetAppName: targetApp,
            startedAt: Date(),
            endsAt: Date().addingTimeInterval(Double(group.onDemandMinutes) * 60),
            openCount: state.openCount,
            maxOpenCount: group.maxOpenCount
        )
        SharedStore.shared.saveActiveSession(session)
    }

    func update(openCount: Int, secondsRemaining: Int, isHardBlocked: Bool, targetAppName: String) async {
        guard let activity else { return }
        let state = FocusSessionAttributes.ContentState(
            secondsRemaining: secondsRemaining,
            openCount: openCount,
            maxOpenCount: maxOpenCount,
            isHardBlocked: isHardBlocked,
            targetAppName: targetAppName
        )
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func endSession() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
        SharedStore.shared.saveActiveSession(nil)
    }
}
