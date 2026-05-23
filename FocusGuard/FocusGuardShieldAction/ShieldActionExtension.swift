import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {
    private let managedStore = ManagedSettingsStore()
    private let sharedStore = SharedStore.shared

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            handleResume(application: application, completionHandler: completionHandler)
        default:
            completionHandler(.close)
        }
    }

    private func handleResume(
        application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let count = sharedStore.incrementOpenCount(for: application)
        let groups = sharedStore.loadAppGroups()
        let tokenKey = sharedStore.tokenKey(application)
        let group = groups.first { $0.applicationTokenKeys.contains(tokenKey) }
        let maxOpens = group?.maxOpenCount ?? 3
        let onDemandMinutes = group?.onDemandMinutes ?? 30

        if count > maxOpens {
            var blocked = managedStore.application.blockedApplications ?? []
            blocked.insert(Application(token: application))
            managedStore.application.blockedApplications = blocked

            var shielded = managedStore.shield.applications ?? []
            shielded.remove(application)
            managedStore.shield.applications = shielded.isEmpty ? nil : shielded

            sendBlockedNotification()
            completionHandler(.close)
        } else {
            var shielded = managedStore.shield.applications ?? []
            shielded.remove(application)
            managedStore.shield.applications = shielded.isEmpty ? nil : shielded

            sharedStore.scheduleReshield(token: application, afterMinutes: onDemandMinutes)
            scheduleReshieldMonitor(minutes: onDemandMinutes)
            completionHandler(.defer)
        }
    }

    private func scheduleReshieldMonitor(minutes: Int) {
        let center = DeviceActivityCenter()
        let now = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        let end = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: Date().addingTimeInterval(Double(minutes) * 60)
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: now,
            intervalEnd: end,
            repeats: false
        )
        let name = DeviceActivityName("reshield_\(UUID().uuidString)")
        try? center.startMonitoring(name, during: schedule)
    }

    private func sendBlockedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "App fully blocked"
        content.body = "You've reached your open limit. Open FocusGuard to adjust your settings."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
