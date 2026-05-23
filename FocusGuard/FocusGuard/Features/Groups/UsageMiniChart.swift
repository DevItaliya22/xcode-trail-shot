import Charts
import SwiftUI

struct UsageMiniChart: View {
    let groupID: UUID
    let usagePercent: Double
    let hourlyUsage: [Int]

    init(group: AppGroup) {
        groupID = group.id
        usagePercent = group.usagePercent
        hourlyUsage = group.hourlyUsage
    }

    var body: some View {
        Chart {
            ForEach(Array(hourlyUsage.enumerated()), id: \.offset) { hour, minutes in
                BarMark(
                    x: .value("Hour", hour),
                    y: .value("Minutes", minutes)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.8), .purple.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(2)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .overlay(alignment: .trailing) {
            if usagePercent > 0 {
                Text("\(Int(usagePercent * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
            }
        }
    }
}

struct WeeklyUsageChart: View {
    let dailyTotals: [Int]

    var body: some View {
        Chart {
            ForEach(Array(dailyTotals.enumerated()), id: \.offset) { day, minutes in
                BarMark(
                    x: .value("Day", dayLabel(for: day)),
                    y: .value("Minutes", minutes)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(4)
            }
        }
        .frame(height: 160)
    }

    private func dayLabel(for index: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        let offset = (today - (6 - index) + 7) % 7
        return symbols[offset]
    }
}
