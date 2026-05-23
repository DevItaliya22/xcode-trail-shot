import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FocusGuardWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusSessionLiveActivity()
    }
}

struct FocusSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.sessionName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(context.state.targetAppName)
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(context.state.secondsRemaining / 60)m left")
                        .font(.caption.monospacedDigit())
                    HStack(spacing: 2) {
                        ForEach(0 ..< context.state.maxOpenCount, id: \.self) { index in
                            Circle()
                                .fill(index < context.state.openCount ? Color.purple : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        "\(context.state.openCount)/\(context.state.maxOpenCount)",
                        systemImage: "eye.slash.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.secondsRemaining / 60)m")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.targetAppName)
                        .font(.caption.weight(.medium))
                }
            } compactLeading: {
                Image(systemName: context.state.isHardBlocked ? "lock.fill" : "lock.open.fill")
                    .foregroundStyle(.purple)
            } compactTrailing: {
                Text("\(context.state.openCount)×")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.purple)
            } minimal: {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.purple)
            }
        }
    }
}
