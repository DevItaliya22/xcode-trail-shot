import AppIntents
import Foundation

struct FocusGuardFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "FocusGuard: restrict app groups"
    static let description = IntentDescription(
        "Automatically enable or disable FocusGuard app groups when this Focus is active."
    )

    @Parameter(title: "Groups to enable")
    var groupsToEnable: [String]?

    @Parameter(title: "Groups to disable")
    var groupsToDisable: [String]?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "FocusGuard",
            subtitle: "Restrict app groups"
        )
    }

    func perform() async throws -> some IntentResult {
        let allGroups = SharedStore.shared.loadAppGroups()

        try await MainActor.run {
            let engine = BlockingEngine.shared
            for group in allGroups {
                if groupsToEnable?.contains(group.id.uuidString) == true {
                    try engine.enable(group)
                } else if groupsToDisable?.contains(group.id.uuidString) == true {
                    engine.disable(group)
                }
            }
        }

        return .result()
    }
}
