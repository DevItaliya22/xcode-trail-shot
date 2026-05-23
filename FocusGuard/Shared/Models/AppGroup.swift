import FamilyControls
import Foundation
import ManagedSettings

struct AppGroup: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var dailyLimitMinutes: Int
    var onDemandMinutes: Int
    var maxOpenCount: Int
    var goalLabel: String
    var activityName: String
    var scheduleRules: [ScheduleRule]
    var focusFilterEnabled: Bool
    var isEnabled: Bool
    var allowZoneIdentifier: String?

    init(
        id: UUID = UUID(),
        name: String,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        dailyLimitMinutes: Int = 120,
        onDemandMinutes: Int = 30,
        maxOpenCount: Int = 3,
        goalLabel: String = "",
        activityName: String? = nil,
        scheduleRules: [ScheduleRule] = [],
        focusFilterEnabled: Bool = false,
        isEnabled: Bool = true,
        allowZoneIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.dailyLimitMinutes = dailyLimitMinutes
        self.onDemandMinutes = onDemandMinutes
        self.maxOpenCount = maxOpenCount
        self.goalLabel = goalLabel
        self.activityName = activityName ?? "group_\(id.uuidString)"
        self.scheduleRules = scheduleRules
        self.focusFilterEnabled = focusFilterEnabled
        self.isEnabled = isEnabled
        self.allowZoneIdentifier = allowZoneIdentifier
    }

    var applicationTokenSet: Set<ApplicationToken>? {
        let tokens = selection.applicationTokens
        return tokens.isEmpty ? nil : tokens
    }

    var applicationTokenKeys: Set<String> {
        Set(selection.applicationTokens.compactMap {
            (try? JSONEncoder().encode($0))?.base64EncodedString()
        })
    }

    var isCurrentlyActive: Bool {
        guard isEnabled else { return false }
        if scheduleRules.isEmpty { return true }
        return scheduleRules.contains { $0.coversNow }
    }

    var appCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    static func == (lhs: AppGroup, rhs: AppGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ScheduleRule: Codable, Hashable, Identifiable {
    var id: UUID
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var weekdays: Set<Int>

    init(
        id: UUID = UUID(),
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        weekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    ) {
        self.id = id
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    var coversNow: Bool {
        let now = Calendar.current.dateComponents([.weekday, .hour, .minute], from: Date())
        guard let weekday = now.weekday, weekdays.contains(weekday),
              let hour = now.hour, let minute = now.minute else { return false }
        let current = hour * 60 + minute
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        if start <= end {
            return current >= start && current < end
        }
        return current >= start || current < end
    }

    var formattedRange: String {
        String(format: "%02d:%02d – %02d:%02d", startHour, startMinute, endHour, endMinute)
    }
}

struct ActiveSession: Codable {
    var groupName: String
    var targetAppName: String
    var startedAt: Date
    var endsAt: Date
    var openCount: Int
    var maxOpenCount: Int
}

struct AllowZone: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var linkedGroupID: UUID

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 200,
        linkedGroupID: UUID
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.linkedGroupID = linkedGroupID
    }
}

struct OpenCountRecord: Codable {
    var tokenKey: String
    var count: Int
    var date: Date
}

struct FocusRule: Codable, Identifiable {
    let id: UUID
    var name: String
    var groupIDs: [UUID]
    var isActive: Bool

    init(id: UUID = UUID(), name: String, groupIDs: [UUID], isActive: Bool = true) {
        self.id = id
        self.name = name
        self.groupIDs = groupIDs
        self.isActive = isActive
    }
}
