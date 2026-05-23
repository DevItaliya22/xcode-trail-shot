import FamilyControls
import Foundation
import ManagedSettings

enum AppGroupConstants {
    static let suiteName = "group.com.focusguard.shared"
}

private enum Keys {
    static let appGroups = "appGroups"
    static let allowZones = "allowZones"
    static let openCountPrefix = "openCount_"
    static let usageMinutesPrefix = "usageMinutes_"
    static let lastResetDate = "lastResetDate"
    static let reshieldQueue = "reshieldQueue"
    static let activeSession = "activeSession"
    static let onboardingComplete = "onboardingComplete"
    static let passcodeEnabled = "passcodeEnabled"
    static let notificationsEnabled = "notificationsEnabled"
    static let dailyResetScheduled = "dailyResetScheduled"
}

final class SharedStore: @unchecked Sendable {
    static let shared = SharedStore()

    private let defaults: UserDefaults

    private init() {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            fatalError("App Group UserDefaults unavailable: \(AppGroupConstants.suiteName)")
        }
        self.defaults = defaults
    }

    // MARK: - Token helpers

    func tokenKey(_ token: ApplicationToken) -> String {
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return data.base64EncodedString()
    }

    // MARK: - Open count

    func openCount(for token: ApplicationToken) -> Int {
        resetIfNewDay()
        let key = Keys.openCountPrefix + tokenKey(token)
        return defaults.integer(forKey: key)
    }

    func openCount(forGroup group: AppGroup) -> Int {
        resetIfNewDay()
        return group.applicationTokenKeys.reduce(0) { sum, key in
            sum + defaults.integer(forKey: Keys.openCountPrefix + key)
        }
    }

    @discardableResult
    func incrementOpenCount(for token: ApplicationToken) -> Int {
        resetIfNewDay()
        let key = Keys.openCountPrefix + tokenKey(token)
        let newCount = defaults.integer(forKey: key) + 1
        defaults.set(newCount, forKey: key)
        return newCount
    }

    // MARK: - Usage tracking

    func usageMinutes(forGroup groupID: UUID) -> Int {
        resetIfNewDay()
        return defaults.integer(forKey: Keys.usageMinutesPrefix + groupID.uuidString)
    }

    func addUsageMinutes(_ minutes: Int, forGroup groupID: UUID) {
        resetIfNewDay()
        let key = Keys.usageMinutesPrefix + groupID.uuidString
        let current = defaults.integer(forKey: key)
        defaults.set(current + minutes, forKey: key)
    }

    // MARK: - Daily reset

    func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = defaults.object(forKey: Keys.lastResetDate) as? Date
        guard lastReset != today else { return }
        clearDailyCounters()
        defaults.set(today, forKey: Keys.lastResetDate)
    }

    func resetAllCounts() {
        clearDailyCounters()
        defaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.lastResetDate)
    }

    private func clearDailyCounters() {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Keys.openCountPrefix) || $0.hasPrefix(Keys.usageMinutesPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - App groups

    func saveAppGroups(_ groups: [AppGroup]) {
        if let data = try? JSONEncoder().encode(groups) {
            defaults.set(data, forKey: Keys.appGroups)
        }
    }

    func loadAppGroups() -> [AppGroup] {
        guard let data = defaults.data(forKey: Keys.appGroups),
              let groups = try? JSONDecoder().decode([AppGroup].self, from: data)
        else {
            return []
        }
        return groups
    }

    func updateGroup(_ group: AppGroup) {
        var groups = loadAppGroups()
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        saveAppGroups(groups)
    }

    func deleteGroup(_ groupID: UUID) {
        var groups = loadAppGroups()
        groups.removeAll { $0.id == groupID }
        saveAppGroups(groups)
    }

    // MARK: - Allow zones

    func saveAllowZones(_ zones: [AllowZone]) {
        if let data = try? JSONEncoder().encode(zones) {
            defaults.set(data, forKey: Keys.allowZones)
        }
    }

    func loadAllowZones() -> [AllowZone] {
        guard let data = defaults.data(forKey: Keys.allowZones),
              let zones = try? JSONDecoder().decode([AllowZone].self, from: data)
        else {
            return []
        }
        return zones
    }

    // MARK: - Reshield queue

    func scheduleReshield(token: ApplicationToken, afterMinutes: Int) {
        var queue = loadReshieldQueue()
        queue[tokenKey(token)] = Date().addingTimeInterval(Double(afterMinutes) * 60)
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: Keys.reshieldQueue)
        }
    }

    func loadReshieldQueue() -> [String: Date] {
        guard let data = defaults.data(forKey: Keys.reshieldQueue),
              let queue = try? JSONDecoder().decode([String: Date].self, from: data)
        else {
            return [:]
        }
        return queue
    }

    func saveReshieldQueue(_ queue: [String: Date]) {
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: Keys.reshieldQueue)
        }
    }

    // MARK: - Active session

    func saveActiveSession(_ session: ActiveSession?) {
        if let session {
            if let data = try? JSONEncoder().encode(session) {
                defaults.set(data, forKey: Keys.activeSession)
            }
        } else {
            defaults.removeObject(forKey: Keys.activeSession)
        }
    }

    func loadActiveSession() -> ActiveSession? {
        guard let data = defaults.data(forKey: Keys.activeSession) else { return nil }
        return try? JSONDecoder().decode(ActiveSession.self, from: data)
    }

    // MARK: - Preferences

    var isOnboardingComplete: Bool {
        get { defaults.bool(forKey: Keys.onboardingComplete) }
        set { defaults.set(newValue, forKey: Keys.onboardingComplete) }
    }

    var isPasscodeEnabled: Bool {
        get { defaults.bool(forKey: Keys.passcodeEnabled) }
        set { defaults.set(newValue, forKey: Keys.passcodeEnabled) }
    }

    var areNotificationsEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.notificationsEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.notificationsEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }

    var isDailyResetScheduled: Bool {
        get { defaults.bool(forKey: Keys.dailyResetScheduled) }
        set { defaults.set(newValue, forKey: Keys.dailyResetScheduled) }
    }
}
