import DeviceActivity
import Foundation
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let managedStore = ManagedSettingsStore()
    private let sharedStore = SharedStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity.rawValue == "daily_reset" {
            performDailyReset()
            return
        }

        if activity.rawValue.hasPrefix("reshield_") {
            processReshieldQueue()
            return
        }

        let groups = sharedStore.loadAppGroups()
        if let group = groups.first(where: { $0.activityName == activity.rawValue }) {
            applyShields(for: group)
        }

        processReshieldQueue()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity.rawValue == "daily_reset" { return }
        if activity.rawValue.hasPrefix("reshield_") {
            processReshieldQueue()
            return
        }

        let groups = sharedStore.loadAppGroups()
        if let group = groups.first(where: { $0.activityName == activity.rawValue }) {
            removeShields(for: group)
        }
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        let groups = sharedStore.loadAppGroups()
        if let group = groups.first(where: { $0.activityName == activity.rawValue }) {
            applyShields(for: group)
        }
    }

    private func applyShields(for group: AppGroup) {
        guard let tokens = group.applicationTokenSet else { return }
        var current = managedStore.shield.applications ?? []
        current.formUnion(tokens)
        managedStore.shield.applications = current
    }

    private func removeShields(for group: AppGroup) {
        guard let tokens = group.applicationTokenSet else { return }
        var current = managedStore.shield.applications ?? []
        current.subtract(tokens)
        managedStore.shield.applications = current.isEmpty ? nil : current
    }

    private func performDailyReset() {
        sharedStore.resetAllCounts()
        managedStore.shield.applications = nil
        managedStore.application.blockedApplications = nil

        let groups = sharedStore.loadAppGroups()
        for group in groups where group.isCurrentlyActive {
            applyShields(for: group)
        }
    }

    private func processReshieldQueue() {
        var queue = sharedStore.loadReshieldQueue()
        let now = Date()
        var changed = false

        for (tokenKey, reshieldAt) in queue where reshieldAt <= now {
            queue.removeValue(forKey: tokenKey)
            changed = true
        }

        if changed {
            sharedStore.saveReshieldQueue(queue)
            let groups = sharedStore.loadAppGroups()
            for group in groups where group.isCurrentlyActive {
                applyShields(for: group)
            }
        }
    }
}
