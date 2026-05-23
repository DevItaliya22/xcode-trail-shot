import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class BlockingEngine: ObservableObject {
    static let shared = BlockingEngine()

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore()
    private let sharedStore = SharedStore.shared

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    private init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func enable(_ group: AppGroup) throws {
        guard let tokens = group.applicationTokenSet, group.isEnabled else { return }

        center.stopMonitoring([DeviceActivityName(group.activityName)])

        var current = store.shield.applications ?? []
        if group.isCurrentlyActive {
            current.formUnion(tokens)
            store.shield.applications = current
        }

        let rules = group.scheduleRules.isEmpty
            ? [ScheduleRule(startHour: 0, startMinute: 0, endHour: 23, endMinute: 59)]
            : group.scheduleRules

        for rule in rules {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: rule.startHour, minute: rule.startMinute),
                intervalEnd: DateComponents(hour: rule.endHour, minute: rule.endMinute),
                repeats: true
            )

            if group.dailyLimitMinutes > 0 {
                let event = DeviceActivityEvent(
                    applications: tokens,
                    threshold: DateComponents(minute: group.dailyLimitMinutes)
                )
                try center.startMonitoring(
                    DeviceActivityName(group.activityName),
                    during: schedule,
                    events: [DeviceActivityEvent.Name("\(group.activityName)_limit"): event]
                )
            } else {
                try center.startMonitoring(
                    DeviceActivityName(group.activityName),
                    during: schedule
                )
            }
        }

        startMidnightResetMonitor()
    }

    func disable(_ group: AppGroup) {
        guard let tokens = group.applicationTokenSet else { return }

        var current = store.shield.applications ?? []
        current.subtract(tokens)
        store.shield.applications = current.isEmpty ? nil : current

        var blocked = store.application.blockedApplications ?? []
        blocked.subtract(Set(tokens.map { Application(token: $0) }))
        store.application.blockedApplications = blocked.isEmpty ? nil : blocked

        center.stopMonitoring([DeviceActivityName(group.activityName)])
    }

    func refreshAllGroups() {
        let groups = sharedStore.loadAppGroups()
        for group in groups {
            if group.isEnabled {
                try? enable(group)
            } else {
                disable(group)
            }
        }
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func unshieldGroup(_ group: AppGroup) {
        guard let tokens = group.applicationTokenSet else { return }
        var current = store.shield.applications ?? []
        current.subtract(tokens)
        store.shield.applications = current.isEmpty ? nil : current
    }

    func shieldGroup(_ group: AppGroup) {
        guard let tokens = group.applicationTokenSet else { return }
        var current = store.shield.applications ?? []
        current.formUnion(tokens)
        store.shield.applications = current
    }

    private func startMidnightResetMonitor() {
        guard !sharedStore.isDailyResetScheduled else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        do {
            try center.startMonitoring(DeviceActivityName("daily_reset"), during: schedule)
            sharedStore.isDailyResetScheduled = true
        } catch {
            // Already monitoring — safe to ignore duplicate schedule errors.
        }
    }
}
