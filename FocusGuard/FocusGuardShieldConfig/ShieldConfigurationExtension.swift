import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let store = SharedStore.shared

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildConfiguration(for: application.localizedDisplayName, token: application.token)
    }

    override func configuration(
        shielding application: Application,
        in _: ActivityCategory
    ) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    private func buildConfiguration(
        for appName: String?,
        token: ApplicationToken?
    ) -> ShieldConfiguration {
        let displayName = appName ?? "this app"
        var count = 0
        var maxOpens = 3
        var onDemandMinutes = 30
        var goalLabel = ""

        if let token {
            count = store.openCount(for: token)
            let groups = store.loadAppGroups()
            if let group = groups.first(where: { $0.applicationTokenKeys.contains(store.tokenKey(token)) }) {
                maxOpens = group.maxOpenCount
                onDemandMinutes = group.onDemandMinutes
                goalLabel = group.goalLabel
            }
        }

        let remaining = max(0, maxOpens - count)
        let usageMinutes = token.flatMap { token in
            store.loadAppGroups()
                .first { $0.applicationTokenKeys.contains(store.tokenKey(token)) }
                .map { store.usageMinutes(forGroup: $0.id) }
        } ?? 0

        var subtitleParts: [String] = []
        if !goalLabel.isEmpty { subtitleParts.append(goalLabel) }
        if usageMinutes > 0 {
            let hours = usageMinutes / 60
            let mins = usageMinutes % 60
            let usageText = hours > 0 ? "\(hours)h \(mins)m today" : "\(mins)m today"
            subtitleParts.append("Resumed \(count)× · \(usageText)")
        } else if count > 0 {
            subtitleParts.append("Resumed \(count)× today")
        }

        let subtitle = subtitleParts.isEmpty
            ? nil
            : ShieldConfiguration.Label(
                text: subtitleParts.joined(separator: " · "),
                color: UIColor.white.withAlphaComponent(0.6)
            )

        return ShieldConfiguration(
            backgroundColor: UIColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1),
            icon: nil,
            title: ShieldConfiguration.Label(
                text: "Is \(displayName) helping you focus?",
                color: .white
            ),
            subtitle: subtitle,
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Stay Focused",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.42, green: 0.35, blue: 0.90, alpha: 1),
            secondaryButtonLabel: remaining > 0
                ? ShieldConfiguration.Label(
                    text: "Resume for \(onDemandMinutes)m (\(remaining) left)",
                    color: UIColor.white.withAlphaComponent(0.7)
                )
                : nil
        )
    }
}
