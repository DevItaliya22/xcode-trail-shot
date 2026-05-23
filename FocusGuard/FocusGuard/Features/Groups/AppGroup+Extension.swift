import Foundation

extension AppGroup {
    var openCountToday: Int {
        SharedStore.shared.openCount(forGroup: self)
    }

    var todayUsageMinutes: Int {
        SharedStore.shared.usageMinutes(forGroup: id)
    }

    var todayUsageFormatted: String {
        let minutes = todayUsageMinutes
        if minutes == 0 { return "0m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }

    var dailyLimitFormatted: String {
        if dailyLimitMinutes == 0 { return "No limit" }
        let hours = dailyLimitMinutes / 60
        let mins = dailyLimitMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }

    var usagePercent: Double {
        guard dailyLimitMinutes > 0 else { return 0 }
        return min(1.0, Double(todayUsageMinutes) / Double(dailyLimitMinutes))
    }

    var stateLabel: String {
        if !isEnabled { return "Disabled" }
        if openCountToday > maxOpenCount { return "Hard Blocked" }
        if isCurrentlyActive { return "Active" }
        return "Scheduled"
    }

    var hourlyUsage: [Int] {
        let total = todayUsageMinutes
        guard total > 0 else { return Array(repeating: 0, count: 24) }
        let hour = Calendar.current.component(.hour, from: Date())
        var buckets = Array(repeating: 0, count: 24)
        buckets[hour] = total
        return buckets
    }
}
