# MASTER PROMPT — FocusGuard iOS App (Cape-like, iOS 26 Liquid Glass)

> Copy this entire document into any AI coding session (Claude, Cursor, Copilot, etc.)
> to get production-quality, error-free SwiftUI code with no handwaving.

---

## SECTION 1 — WHO YOU ARE AND WHAT WE'RE BUILDING

You are an expert iOS engineer specializing in SwiftUI, Swift 6 concurrency,
and Apple's Screen Time API ecosystem (FamilyControls, ManagedSettings,
DeviceActivity). You write production-grade code with zero placeholder comments,
no TODO stubs, no "implement this later" gaps. Every function is complete.
Every extension compiles. Every App Group key is named and consistent.

We are building **FocusGuard** — a digital wellness / screen-time guardian app
for iPhone (iOS 26+). Think of it as a premium, modern version of the Cape app
or One Sec, but rebuilt from scratch with iOS 26's Liquid Glass design language.

---

## SECTION 2 — FULL PRODUCT SPEC (read this before writing any code)

### Core concept
FocusGuard lets users create "App Groups" (e.g. "Distracting Apps", "Work Apps",
"Time-wasters"). For each group the user sets:
- A daily screen-time limit (e.g. 2h 30m)
- A per-open time allowance when paused (e.g. 30 min on-demand)
- A hard open-count limit (e.g. after 3 opens today, the app is fully hidden)
- Optional: an Allow Zone (GPS location where the group is unrestricted)
- Optional: a Focus mode that auto-enables/disables the group

When a user tries to open a blocked app, they see FocusGuard's **Pause Screen**
(the ShieldConfiguration). This custom screen shows:
- The app icon and name
- An accountability question ("Is YouTube helping you focus?")
- Days until a user-set goal (e.g. "7 days until Final Exam")
- Their stats today: resumed N×, consumed Xh Xm (XX%)
- Primary button: "Stay Focused" (keeps the block)
- Secondary button: "Resume [App] for 30m" (grants temporary access, increments counter)
- After the N-th open (configurable, default 3), the secondary button disappears
  and on the 4th+ attempt, the app switches from shielded to fully blocked
  (hidden from home screen)

### App screens
1. **Onboarding** — requests FamilyControls permission, explains what the app does
2. **Groups tab** — card grid of App Groups with today's usage charts (like Cape screenshot 2)
3. **Zones tab** — geofence setup (CoreLocation)
4. **Schedule tab** — time-based rules (DeviceActivitySchedule)
5. **Settings tab** — global preferences, passcode lock, notification settings
6. **Session HUD** — Live Activity on lock screen + Dynamic Island showing
   active focus session countdown and open-count status

### The Pause Screen (Shield) — key UX
This is what the user sees when they try to open a blocked app.
It uses ShieldConfiguration (limited to colors + title + subtitle + 2 buttons).
IMPORTANT: No React Native, no arbitrary SwiftUI here — only ShieldConfiguration struct.
The intelligence (counters, state machine) lives in App Group UserDefaults,
read by the ShieldConfigurationDataSource and ShieldActionDelegate extensions.

### State machine for each app/group
```
UNBLOCKED
  → user hits daily time limit → SHIELDED (shows Pause Screen)
  → user taps "Resume 30m" (1st, 2nd, 3rd time) → TEMPORARILY_UNSHIELDED (30 min timer)
  → timer expires → back to SHIELDED
  → user taps "Resume" for the Nth+ time (N = configurable, default 4) → HARD_BLOCKED
  → midnight reset → back to UNBLOCKED
```

---

## SECTION 3 — XCODE PROJECT STRUCTURE (5 targets, all required)

```
FocusGuard/                          ← Main app target
  App/
    FocusGuardApp.swift              ← @main, sets up AuthorizationCenter
    AppDelegate.swift
  Features/
    Onboarding/
    Groups/                          ← Card grid, usage charts
    Zones/                           ← CoreLocation geofences
    Schedule/
    Settings/
    Session/                         ← Live Activity management
  Core/
    SharedStore.swift                ← ALL App Group reads/writes here
    BlockingEngine.swift             ← Applies/removes shields
    Models/
      AppGroup.swift
      FocusRule.swift
      OpenCountRecord.swift

FocusGuardShieldConfig/              ← ShieldConfiguration extension target
  ShieldConfigurationExtension.swift

FocusGuardShieldAction/              ← ShieldAction extension target
  ShieldActionExtension.swift

FocusGuardDeviceActivity/            ← DeviceActivityMonitor extension target
  DeviceActivityMonitorExtension.swift

FocusGuardWidget/                    ← Widget + Live Activity extension target
  FocusSessionLiveActivity.swift
  FocusSessionAttributes.swift
```

**App Group identifier (use EXACTLY this string everywhere):**
`group.com.focusguard.shared`

**Bundle ID pattern:**
- Main app:              `com.focusguard.app`
- ShieldConfig ext:      `com.focusguard.app.shieldconfig`
- ShieldAction ext:      `com.focusguard.app.shieldaction`
- DeviceActivity ext:    `com.focusguard.app.deviceactivity`
- Widget ext:            `com.focusguard.app.widget`

---

## SECTION 4 — REQUIRED ENTITLEMENTS & INFO.PLIST KEYS

### Entitlements (all targets that need them):
```xml
<!-- Main app, ShieldConfig, ShieldAction, DeviceActivity -->
<key>com.apple.developer.family-controls</key>
<true/>

<!-- All 5 targets -->
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.focusguard.shared</string>
</array>

<!-- Main app + Widget -->
<key>com.apple.developer.usernotifications.communication</key>
<true/>
```

### Info.plist (main app):
```xml
<key>NSFamilyControlsUsageDescription</key>
<string>FocusGuard needs Screen Time access to help you stay focused by managing app access.</string>
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
<key>NSLocationWhenInUseUsageDescription</key>
<string>FocusGuard uses your location to enable Allow Zones where certain apps are unrestricted.</string>
```

---

## SECTION 5 — SHARED STORE (the single source of truth across all processes)

```swift
// SharedStore.swift — used by ALL 5 targets
import Foundation
import ManagedSettings
import FamilyControls

// MARK: - Keys
private enum Keys {
    static let appGroups        = "appGroups"
    static let openCountPrefix  = "openCount_"
    static let lastResetDate    = "lastResetDate"
    static let reshieldQueue    = "reshieldQueue"
    static let activeSession    = "activeSession"
}

// MARK: - SharedStore
final class SharedStore {

    static let shared = SharedStore()
    
    private let defaults = UserDefaults(suiteName: "group.com.focusguard.shared")!
    
    private init() {}

    // MARK: Open count per app token (resets daily)
    func openCount(for token: ApplicationToken) -> Int {
        resetIfNewDay()
        let key = Keys.openCountPrefix + tokenKey(token)
        return defaults.integer(forKey: key)
    }

    @discardableResult
    func incrementOpenCount(for token: ApplicationToken) -> Int {
        resetIfNewDay()
        let key = Keys.openCountPrefix + tokenKey(token)
        let newCount = defaults.integer(forKey: key) + 1
        defaults.set(newCount, forKey: key)
        return newCount
    }

    // MARK: Daily reset
    func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = defaults.object(forKey: Keys.lastResetDate) as? Date
        guard lastReset != today else { return }
        // Clear all open counts
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Keys.openCountPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
        defaults.set(today, forKey: Keys.lastResetDate)
    }

    func resetAllCounts() {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Keys.openCountPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
        defaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.lastResetDate)
    }

    // MARK: App groups (stored as JSON)
    func saveAppGroups(_ groups: [AppGroup]) {
        let data = try? JSONEncoder().encode(groups)
        defaults.set(data, forKey: Keys.appGroups)
    }

    func loadAppGroups() -> [AppGroup] {
        guard let data = defaults.data(forKey: Keys.appGroups),
              let groups = try? JSONDecoder().decode([AppGroup].self, from: data)
        else { return [] }
        return groups
    }

    // MARK: Reshield queue (token → reshield-at timestamp)
    func scheduleReshield(token: ApplicationToken, afterMinutes: Int) {
        var queue = loadReshieldQueue()
        queue[tokenKey(token)] = Date().addingTimeInterval(Double(afterMinutes) * 60)
        let data = try? JSONEncoder().encode(queue)
        defaults.set(data, forKey: Keys.reshieldQueue)
    }

    func loadReshieldQueue() -> [String: Date] {
        guard let data = defaults.data(forKey: Keys.reshieldQueue),
              let queue = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return queue
    }

    // MARK: Active session for Live Activity
    func saveActiveSession(_ session: ActiveSession?) {
        let data = try? JSONEncoder().encode(session)
        defaults.set(data, forKey: Keys.activeSession)
    }

    func loadActiveSession() -> ActiveSession? {
        guard let data = defaults.data(forKey: Keys.activeSession) else { return nil }
        return try? JSONDecoder().decode(ActiveSession.self, from: data)
    }

    // MARK: Token key helper
    private func tokenKey(_ token: ApplicationToken) -> String {
        // ApplicationToken conforms to Codable — encode to stable string
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return data.base64EncodedString()
    }
}
```

---

## SECTION 6 — SHIELD CONFIGURATION EXTENSION

```swift
// ShieldConfigurationExtension.swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let store = SharedStore.shared

    override func configuration(shielding application: Application)
    -> ShieldConfiguration {
        let token = application.token!
        let count = store.openCount(for: token)
        let groups = store.loadAppGroups()
        let group = groups.first { $0.applicationTokenKeys.contains(store.tokenKey(token)) }
        let maxOpens = group?.maxOpenCount ?? 3
        let remaining = max(0, maxOpens - count)
        let goalLabel = group?.goalLabel ?? ""

        return ShieldConfiguration(
            backgroundColor: UIColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1),
            icon: application.localizedDisplayName.map { _ in nil } ?? nil,
            title: ShieldConfiguration.Label(
                text: "Is \(application.localizedDisplayName ?? "this app") helping you focus?",
                color: .white
            ),
            subtitle: goalLabel.isEmpty ? nil : ShieldConfiguration.Label(
                text: goalLabel,
                color: UIColor.white.withAlphaComponent(0.6)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Stay Focused",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.42, green: 0.35, blue: 0.90, alpha: 1),
            secondaryButtonLabel: remaining > 0
                ? ShieldConfiguration.Label(
                    text: "Resume for \(group?.onDemandMinutes ?? 30)m (\(remaining) left)",
                    color: UIColor.white.withAlphaComponent(0.7)
                  )
                : nil
        )
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }
}
```

---

## SECTION 7 — SHIELD ACTION EXTENSION

```swift
// ShieldActionExtension.swift
import ManagedSettings
import DeviceActivity
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {

    private let managedStore = ManagedSettingsStore()
    private let sharedStore  = SharedStore.shared

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // "Stay Focused" — keep the block, close the shield overlay
            completionHandler(.close)

        case .secondaryButtonPressed:
            handleResume(application: application, completionHandler: completionHandler)

        @unknown default:
            completionHandler(.close)
        }
    }

    private func handleResume(application: ApplicationToken,
                              completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let count = sharedStore.incrementOpenCount(for: application)
        let groups = sharedStore.loadAppGroups()
        let maxOpens = groups
            .first { $0.applicationTokenKeys.contains(sharedStore.tokenKey(application)) }
            .map { $0.maxOpenCount } ?? 3
        let onDemandMinutes = groups
            .first { $0.applicationTokenKeys.contains(sharedStore.tokenKey(application)) }
            .map { $0.onDemandMinutes } ?? 30

        if count > maxOpens {
            // Hard-block: hide from home screen entirely
            var blocked = managedStore.application.blockedApplications ?? []
            blocked.insert(application)
            managedStore.application.blockedApplications = blocked
            // Remove from shield set
            managedStore.shield.applications?.remove(application)
            sendBlockedNotification()
            completionHandler(.close)
        } else {
            // Soft-unshield: grant temporary access
            managedStore.shield.applications?.remove(application)
            sharedStore.scheduleReshield(token: application, afterMinutes: onDemandMinutes)
            // Notify main app to re-apply shield after timer (via DeviceActivity schedule)
            scheduleReshieldMonitor(application: application, minutes: onDemandMinutes)
            completionHandler(.defer)
        }
    }

    private func scheduleReshieldMonitor(application: ApplicationToken, minutes: Int) {
        // Use a DeviceActivityCenter schedule to fire back and re-apply the shield
        let center = DeviceActivityCenter()
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let end = Calendar.current.dateComponents(
            [.hour, .minute],
            from: Date().addingTimeInterval(Double(minutes) * 60)
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: now,
            intervalEnd: end,
            repeats: false
        )
        try? center.startMonitoring(
            DeviceActivityName("reshield_\(UUID().uuidString)"),
            during: schedule
        )
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
```

---

## SECTION 8 — DEVICE ACTIVITY MONITOR EXTENSION

```swift
// DeviceActivityMonitorExtension.swift
import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let managedStore = ManagedSettingsStore()
    private let sharedStore  = SharedStore.shared

    // Called when a schedule interval STARTS (e.g. work hours begin → enable block)
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity.rawValue == "daily_reset" {
            performDailyReset()
            return
        }

        // Apply shields for the group associated with this activity name
        let groups = sharedStore.loadAppGroups()
        if let group = groups.first(where: { $0.activityName == activity.rawValue }) {
            applyShields(for: group)
        }

        // Process any pending reshield queue
        processReshieldQueue()
    }

    // Called when a schedule interval ENDS (e.g. work hours over → remove block)
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity.rawValue == "daily_reset" { return }

        let groups = sharedStore.loadAppGroups()
        if let group = groups.first(where: { $0.activityName == activity.rawValue }) {
            removeShields(for: group)
        }
    }

    // Called when a usage threshold is hit (e.g. app used 30 min)
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        let groups = sharedStore.loadAppGroups()
        if let group = groups.first(where: { $0.activityName == activity.rawValue }) {
            applyShields(for: group)
        }
    }

    // MARK: - Helpers

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
        // Remove all hard blocks (re-shield them softly if they were in a group)
        managedStore.shield.applications = nil
        managedStore.application.blockedApplications = nil
        // Re-apply shields that should be active right now
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
            // Time to re-apply this shield
            // (token key → we can't reconstruct ApplicationToken here, 
            //  so we re-apply all group shields as a safe fallback)
            queue.removeValue(forKey: tokenKey)
            changed = true
        }
        if changed {
            // Re-apply all active shields
            let groups = sharedStore.loadAppGroups()
            for group in groups where group.isCurrentlyActive {
                applyShields(for: group)
            }
        }
    }
}
```

---

## SECTION 9 — LIVE ACTIVITY (LOCK SCREEN + DYNAMIC ISLAND)

```swift
// FocusSessionAttributes.swift — shared between main app and Widget target
import ActivityKit
import Foundation

struct FocusSessionAttributes: ActivityAttributes {
    // Static — set once when session starts
    var sessionName: String
    var groupName: String

    // Dynamic — updated as the session progresses
    struct ContentState: Codable, Hashable {
        var secondsRemaining: Int
        var openCount: Int
        var maxOpenCount: Int
        var isHardBlocked: Bool
        var targetAppName: String
    }
}

// FocusSessionLiveActivity.swift — in Widget target
import ActivityKit
import WidgetKit
import SwiftUI

struct FocusSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            // Lock screen / StandBy view
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
                        ForEach(0..<context.state.maxOpenCount, id: \.self) { i in
                            Circle()
                                .fill(i < context.state.openCount ? Color.purple : Color.gray.opacity(0.3))
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
                    Label("\(context.state.openCount)/\(context.state.maxOpenCount)",
                          systemImage: "eye.slash.fill")
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
```

---

## SECTION 10 — iOS 26 LIQUID GLASS UI RULES (read before writing any view)

### The glassEffect API (iOS 26+)

```swift
// Basic glass surface
Text("Stay Focused")
    .padding()
    .glassEffect()

// Tinted interactive glass (buttons)
Button("Resume for 30m") { }
    .glassEffect(.regular.tint(.purple).interactive())

// Glass container — morphs overlapping glass shapes into one fluid form
GlassEffectContainer(spacing: 20) {
    HStack {
        pillButton("Apps")
        pillButton("Zones")
        pillButton("Schedule")
    }
}

// Glass morphing transition — matching IDs animate glass shape between states
@Namespace var ns
view.glassEffect().glassEffectID("myElement", in: ns)
```

### Golden rules for this app

1. **Glass belongs only on navigation chrome** — tab bar, toolbar, floating cards,
   modal sheets, the Pause Screen overlay. NEVER on list rows or scrollable content.
2. **Content is always opaque** — usage charts, app icons, text paragraphs.
   Glass sits above content, not under it.
3. **Use `.glassEffect(.regular.interactive())` on every tappable glass element**
   so iOS 26 gives it the physical scaling + shimmer feedback automatically.
4. **Wrap related glass controls in `GlassEffectContainer`** — the morphing between
   states is the signature animation of iOS 26 native apps. Use it for tab-switching,
   expanding panels, and the Pause Screen button states.
5. **Never stack two glass layers** — one glass surface per visual layer, period.
6. **Accessibility**: always test with Increase Contrast enabled. Glass degrades
   gracefully to high-contrast mode automatically, but check text legibility.

### How the tab bar looks on iOS 26 (automatic)
Just compile against iOS 26 SDK with `TabView` — it gets Liquid Glass automatically.
No extra code needed. The tab bar floats above content on a glass surface.

### Sheets on iOS 26
```swift
.sheet(isPresented: $showGroupEditor) {
    GroupEditorView()
        .presentationDetents([.medium, .large])
        // iOS 26: medium sheets float with Liquid Glass background automatically
}
```

### NavigationStack on iOS 26
The navigation bar chrome becomes Liquid Glass automatically.
Use `.toolbarBackground(.hidden, for: .navigationBar)` on screens with
full-bleed backgrounds (like the Pause Screen recreation in main app).

---

## SECTION 11 — MODELS

```swift
// AppGroup.swift
import Foundation
import FamilyControls
import ManagedSettings

struct AppGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var selection: FamilyActivitySelection   // contains applicationTokens
    var dailyLimitMinutes: Int               // 0 = no limit
    var onDemandMinutes: Int                 // how long each "resume" grants
    var maxOpenCount: Int                    // opens before hard block (default 3)
    var goalLabel: String                    // e.g. "7 days until Final Exam"
    var activityName: String                 // raw value for DeviceActivityName
    var scheduleRules: [ScheduleRule]
    var focusFilterEnabled: Bool
    var isEnabled: Bool
    var allowZoneIdentifier: String?         // CLRegion identifier

    // Computed
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
        // Check if any schedule rule covers current time
        return scheduleRules.contains { $0.coversNow }
    }
}

struct ScheduleRule: Codable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var weekdays: Set<Int>  // 1=Sunday … 7=Saturday

    var coversNow: Bool {
        let now = Calendar.current.dateComponents([.weekday, .hour, .minute], from: Date())
        guard let weekday = now.weekday, weekdays.contains(weekday),
              let hour = now.hour, let minute = now.minute else { return false }
        let current = hour * 60 + minute
        let start   = startHour * 60 + startMinute
        let end     = endHour * 60 + endMinute
        return current >= start && current < end
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
```

---

## SECTION 12 — BLOCKING ENGINE (main app)

```swift
// BlockingEngine.swift
import DeviceActivity
import ManagedSettings
import FamilyControls

@MainActor
final class BlockingEngine: ObservableObject {

    static let shared = BlockingEngine()
    private let center = DeviceActivityCenter()
    private let store  = ManagedSettingsStore()
    private let sharedStore = SharedStore.shared

    private init() {}

    // Enable blocking for a group (apply shield + start schedule)
    func enable(_ group: AppGroup) throws {
        guard let tokens = group.applicationTokenSet else { return }

        // Apply immediate shield
        var current = store.shield.applications ?? []
        current.formUnion(tokens)
        store.shield.applications = current

        // Start DeviceActivity schedule
        for rule in group.scheduleRules {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(
                    hour: rule.startHour, minute: rule.startMinute),
                intervalEnd: DateComponents(
                    hour: rule.endHour, minute: rule.endMinute),
                repeats: true
            )
            // Usage threshold event
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

        // Start midnight reset monitor (once, idempotent)
        startMidnightResetMonitor()
    }

    // Disable blocking for a group
    func disable(_ group: AppGroup) {
        guard let tokens = group.applicationTokenSet else { return }
        var current = store.shield.applications ?? []
        current.subtract(tokens)
        store.shield.applications = current.isEmpty ? nil : current
        var blocked = store.application.blockedApplications ?? []
        blocked.subtract(tokens)
        store.application.blockedApplications = blocked.isEmpty ? nil : blocked
        center.stopMonitoring([DeviceActivityName(group.activityName)])
    }

    // Request FamilyControls permission at onboarding
    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    // MARK: - Private

    private func startMidnightResetMonitor() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd:   DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try? center.startMonitoring(DeviceActivityName("daily_reset"), during: schedule)
    }
}
```

---

## SECTION 13 — ONBOARDING SCREEN (Liquid Glass, iOS 26)

```swift
// OnboardingView.swift
import SwiftUI
import FamilyControls

struct OnboardingView: View {

    @State private var step = 0
    @State private var isRequesting = false
    @State private var authError: String?
    @Namespace private var ns
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Deep dark background — glass floats above this
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.12),
                         Color(red: 0.10, green: 0.07, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .glassEffect(.regular.tint(.purple))
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.purple)
                        .symbolEffect(.bounce, value: step)
                }
                .padding(.bottom, 40)

                // Step content
                GlassEffectContainer(spacing: 0) {
                    VStack(spacing: 24) {
                        stepContent
                    }
                    .padding(32)
                    .glassEffect()
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA button
                Button(action: advance) {
                    HStack {
                        if isRequesting {
                            ProgressView().tint(.white)
                        }
                        Text(step < 2 ? "Continue" : "Allow Screen Time Access")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .glassEffect(.regular.tint(.purple).interactive())
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    @ViewBuilder
    var stepContent: some View {
        switch step {
        case 0:
            featureRow(icon: "shield.fill", title: "Block distracting apps",
                       body: "Set limits, schedules, and open counts for any app.")
        case 1:
            featureRow(icon: "clock.arrow.circlepath", title: "Smart on-demand access",
                       body: "Allow yourself a limited number of breaks per day.")
        default:
            featureRow(icon: "lock.shield", title: "Needs Screen Time access",
                       body: "FocusGuard uses Apple's Screen Time API. Your data never leaves your device.")
        }
    }

    func featureRow(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.purple)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(body)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    func advance() {
        if step < 2 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { step += 1 }
        } else {
            requestPermission()
        }
    }

    func requestPermission() {
        isRequesting = true
        Task {
            do {
                try await BlockingEngine.shared.requestAuthorization()
                await MainActor.run { onComplete() }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                    isRequesting = false
                }
            }
        }
    }
}
```

---

## SECTION 14 — GROUPS TAB (the main dashboard)

```swift
// GroupsView.swift
import SwiftUI
import FamilyControls

struct GroupsView: View {

    @StateObject private var vm = GroupsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 16) {
                    ForEach(vm.groups) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                    // Add new group
                    Button { vm.showCreator = true } label: {
                        AddGroupCard()
                    }
                }
                .padding(16)
            }
            .navigationTitle("My Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { vm.showCreator = true }) {
                        Image(systemName: "plus")
                    }
                    .glassEffect(.regular.interactive())
                }
            }
        }
        .sheet(isPresented: $vm.showCreator) {
            GroupCreatorView(onSave: vm.addGroup)
                .presentationDetents([.medium, .large])
        }
    }
}

struct GroupCard: View {
    let group: AppGroup
    @Namespace private var ns

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Circle()
                        .fill(group.isEnabled ? Color.purple : Color.gray)
                        .frame(width: 10, height: 10)
                }
                // Usage mini chart would go here (use Swift Charts)
                UsageMiniChart(groupID: group.id)
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
```

---

## SECTION 15 — FOCUS FILTER (AppIntents)

```swift
// FocusGuardFilter.swift
import AppIntents
import ManagedSettings

struct FocusGuardFilter: SetFocusFilterIntent {

    static let title: LocalizedStringResource = "FocusGuard: restrict app groups"
    static let description = IntentDescription(
        "Automatically enable or disable FocusGuard app groups when this Focus is active."
    )

    @Parameter(title: "Groups to enable")
    var groupsToEnable: [String]?   // group IDs

    @Parameter(title: "Groups to disable")
    var groupsToDisable: [String]?

    func perform() async throws -> some IntentResult {
        let allGroups = SharedStore.shared.loadAppGroups()
        let engine = BlockingEngine.shared

        for group in allGroups {
            if groupsToEnable?.contains(group.id.uuidString) == true {
                try engine.enable(group)
            } else if groupsToDisable?.contains(group.id.uuidString) == true {
                engine.disable(group)
            }
        }
        return .result()
    }
}
```

---

## SECTION 16 — LIVE ACTIVITY MANAGER

```swift
// LiveActivityManager.swift
import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {

    static let shared = LiveActivityManager()
    private var activity: Activity<FocusSessionAttributes>?
    private init() {}

    func startSession(group: AppGroup, targetApp: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = FocusSessionAttributes(
            sessionName: group.name,
            groupName: group.name
        )
        let state = FocusSessionAttributes.ContentState(
            secondsRemaining: group.dailyLimitMinutes * 60,
            openCount: 0,
            maxOpenCount: group.maxOpenCount,
            isHardBlocked: false,
            targetAppName: targetApp
        )
        activity = try? Activity.request(
            attributes: attrs,
            contentState: state,
            pushType: nil
        )
    }

    func update(openCount: Int, secondsRemaining: Int, isHardBlocked: Bool) {
        guard let activity else { return }
        let state = FocusSessionAttributes.ContentState(
            secondsRemaining: secondsRemaining,
            openCount: openCount,
            maxOpenCount: activity.attributes.sessionName.count, // placeholder
            isHardBlocked: isHardBlocked,
            targetAppName: ""
        )
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }

    func endSession() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
```

---

## SECTION 17 — CODING RULES FOR THIS PROJECT

### Swift version & concurrency
- Swift 6, strict concurrency. All `@MainActor` on ViewModels and UI-touching classes.
- Use `async/await` everywhere. No completion handlers in new code.
- Actors for shared mutable state (`SharedStore` is already a class with no async — 
  wrap in actor if accessed from multiple extensions concurrently).

### Error handling
- Never use `try?` except where explicitly listed above with a comment explaining why.
- Propagate errors to the UI via `@Published var error: Error?` on ViewModels.
- Show errors as SwiftUI alerts, not print statements.

### App Group access
- EVERY read/write of cross-process state goes through `SharedStore`.
- Never access `UserDefaults.standard` — always `UserDefaults(suiteName: "group.com.focusguard.shared")`.

### ManagedSettingsStore
- One shared `ManagedSettingsStore()` instance per process. 
  In extensions, create it locally per method call (it's cheap and stateless).
- Always read current shield set before modifying: `var current = store.shield.applications ?? []`
  then `.insert()` or `.remove()`, then reassign. Never replace the whole set blindly.

### DeviceActivity scheduling
- Stop monitoring before re-starting to avoid duplicate schedule errors:
  `center.stopMonitoring([name])` before `center.startMonitoring(name, during:, events:)`.
- Handle the known iOS 26 bug: `eventDidReachThreshold` may not fire.
  Add a fallback in `intervalDidStart` that checks current usage and applies shields proactively.

### Minimum deployment target
iOS 26.0 — use `.glassEffect()`, `GlassEffectContainer`, `.glassEffectID(_:in:)` freely.
No `#available` guards needed for these APIs.

### No placeholder code
When asked to implement a view or function, implement it completely.
No `// TODO`, no `fatalError("implement me")`, no empty bodies.

---

## SECTION 18 — WHAT TO ASK FOR NEXT (suggested prompts to use after this)

Use this master prompt as the system context, then send these follow-up prompts:

1. "Implement `GroupCreatorView` — a sheet where user names a group, picks apps with 
   `FamilyActivityPicker`, sets daily limit, on-demand minutes, max open count, and goal label.
   Use iOS 26 Liquid Glass styling throughout."

2. "Implement `GroupDetailView` showing the usage charts with Swift Charts,
   the state machine status, schedule rules list, and edit/delete actions."

3. "Implement `ScheduleView` — a calendar-week grid where user taps cells to create
   time-block rules. Glass styling. Fully functional, saves to SharedStore."

4. "Implement `ZonesView` using MapKit and CoreLocation. User drops a pin, sets a radius,
   associates it with an AppGroup. Shield is auto-removed when inside the zone."

5. "Implement `UsageMiniChart` using Swift Charts showing hourly usage for today
   and a 7-day bar chart (using DeviceActivityReport)."

6. "Write the complete `AppGroup+Extension.swift` adding all computed properties 
   referenced in the UI (todayUsageFormatted, openCountToday, etc.) pulling from SharedStore."

7. "Add biometric/passcode lock to Settings so user can prevent FocusGuard 
   from being disabled. Use LocalAuthentication."

---

*End of master prompt. Copy everything above this line into your AI coding session.*