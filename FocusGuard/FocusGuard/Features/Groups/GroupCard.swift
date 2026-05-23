import SwiftUI

struct GroupCard: View {
    let group: AppGroup

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Circle()
                        .fill(group.isEnabled ? Color.purple : Color.gray)
                        .frame(width: 10, height: 10)
                }

                UsageMiniChart(group: group)
                    .frame(height: 44)

                HStack {
                    Label("\(group.openCountToday)×", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(group.todayUsageFormatted, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .glassEffect()
        }
    }
}

struct AddGroupCard: View {
    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.purple)
                Text("New Group")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassEffect()
        }
    }
}
