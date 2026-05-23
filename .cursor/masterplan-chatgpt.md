# Rich UI and Micro‑Interactions

To create an engaging, fluid UI on iOS, use modern animation and feedback APIs. Apple’s Human Interface Guidelines stress that _“micro-interactions and smooth animations breathe life into an app”_【24†L53-L56】. In practice, this means using SwiftUI’s animation modifiers or UIKit’s `UIViewPropertyAnimator`/Core Animation to add physics-based motion and subtle transitions. For complex motion graphics, consider the Lottie library (from Airbnb) to play vector animations exported from After Effects【25†L142-L144】. Combine animations with haptic feedback (`UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`) for touch responses. In SwiftUI 6 (iOS 18+) the animation APIs have been greatly improved for “fluid, organic” motion【24†L53-L56】. In summary, focus on small, context‑aware animations (button presses, page transitions, pull‑to‑refresh, etc.) and use tools like Lottie for rich custom effects【25†L142-L144】【24†L53-L56】.

# Screen Time & Parental‑Control APIs

Apple provides dedicated frameworks for screen‑time management (originally for parental controls) that we can leverage:

- **FamilyControls.framework (Screen Time permission)** – Your app must first request the _Family Controls_ entitlement (`com.apple.developer.family-controls`) and call `AuthorizationCenter.shared.requestAuthorization` to gain access【28†L50-L58】【28†L62-L70】. For example, on first launch:

  ```swift
  try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
  ```

  The system will prompt the user for permission and biometric unlock【28†L62-L70】. Once granted, iOS will list your app under _Screen Time > App Access_, allowing you to manage restrictions.

- **FamilyActivityPicker (app chooser UI)** – Use the built‑in picker to let the user select which apps or categories to control. In SwiftUI, the `.familyActivityPicker` view lets the user choose apps and categories securely【28†L78-L87】. This produces a `FamilyActivitySelection` containing opaque tokens for each chosen app/category.

- **ManagedSettings.framework (shielding apps)** – Once authorized, use `ManagedSettingsStore` to restrict (“shield”) apps or categories. For example, you can create a named store and assign `shield.applications` or `shield.applicationCategories`. In a monitor or app extension, you might do:

  ```swift
  let store = ManagedSettingsStore(named: "MyRestrictions")
  store.shield.applications = .specific([targetAppToken])
  ```

  This hides/locks the selected app. You can also shield entire categories _except_ specific apps (see below)【43†L198-L206】【40†L398-L406】. (Note: when multiple stores apply, iOS enforces the most restrictive setting【40†L279-L288】.)

- **DeviceActivity.framework (scheduling and monitoring)** – Use `DeviceActivitySchedule` and `DeviceActivityEvent` to define when and how apps are monitored. For example, to schedule a daily window:

  ```swift
  let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd:   DateComponents(hour: 23, minute: 59),
      repeats: true
  )  // daily from midnight to 23:59【30†L225-L233】
  ```

  Then create an event with usage thresholds and selected apps:

  ```swift
  let event = DeviceActivityEvent(
      applications: selectedTokens,
      categories:  selectedCategoryTokens,
      threshold:   DateComponents(minute: timeLimit)
  )
  ```

  Finally start monitoring with:

  ```swift
  try DeviceActivityCenter.shared.startMonitoring(
      .named("MyActivity"),
      during: schedule,
      events: ["MyEvent": event]
  )
  ```

  This sets up background monitoring of the chosen apps within the time window【30†L225-L233】【30†L274-L282】.

- **DeviceActivityMonitor extension** – Add a background “Device Activity” extension to respond when thresholds or intervals elapse. In your `DeviceActivityMonitor` subclass, override methods like `eventDidReachThreshold()` and `intervalDidEnd()`. For example, when the usage limit is reached you could automatically shield (pause) the apps. In code:
  ```swift
  class MyMonitor: DeviceActivityMonitor {
      override func eventDidReachThreshold(
          _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
      ) {
          // Called when user hits the time limit.  E.g., apply shielding:
          let store = ManagedSettingsStore(named: .individual)
          store.shield.applicationCategories = .specific([socialCategoryToken])
      }
  }
  ```
  (See CrunchyBagel example of using the extension and warningTime【30†L323-L331】【40†L398-L406】.) You can also set a `warningTime` on the schedule to get an early callback (`eventWillReachThresholdWarning`) if you want to notify the user before pausing【30†L323-L331】.

# Scheduling and Pausing Apps

Combining the above APIs lets you enforce complex schedules. For example:

- **Define availability windows** with `DeviceActivitySchedule` and corresponding `DeviceActivityEvent` (set to the apps or categories from the user’s selection)【30†L225-L233】【30†L246-L254】.
- **Start/stop monitoring** around those windows via `DeviceActivityCenter`【30†L274-L282】.
- **Hide or pause apps** when limits are reached by invoking `ManagedSettingsStore`. For example, to completely hide apps after the 3rd launch of the day, you could count openings (with the Activity Monitor) and then do:

  ```swift
  let store = ManagedSettingsStore(named: "UserRestrictions")
  store.shield.applications = .specific([appToken1, appToken2])
  ```

  This effectively blocks the apps. Apple ensures that category‑level shields override more permissive settings, but you can also use the `.except:` parameter to allow exceptions【43†L198-L206】.

- **Warning notifications** – Use the same scheduling APIs to warn the user. If you set a `warningTime` on the schedule, your `DeviceActivityMonitor`’s `eventWillReachThresholdWarning()` will fire【30†L323-L331】. You can then post a local notification (via UserNotifications API) to alert the user before pausing the app.

In short, use the Screen Time frameworks to model “allow zones” and “block zones.” For example, Worklog (Apple demo) shows a Social store that is automatically unshielded between 5–8pm and re-shielded otherwise【40†L290-L298】. Our app can do the same for any apps: “allow” them during permitted hours and “pause/hide” them otherwise, using `ManagedSettingsStore` to enforce the block.

# Focus Mode Integration

iOS 15+ lets your app adapt when the user switches Focus modes. Although iOS doesn’t let you _programmatically_ switch Focus, you can respond to it:

- **Focus Filters (App Intents)** – In iOS 16+, you can define a `SetFocusFilterIntent` so that your app is notified when a specified Focus is enabled. For example, implement:

  ```swift
  struct MyFocusFilter: SetFocusFilterIntent {
      @Parameter(title: "Focus Name") var focusName: String
      func perform() async throws -> some IntentResult {
          print("Focus changed: \(focusName)")
          return .result()
      }
  }
  ```

  The system will call this when the user activates the Focus (assuming they added your app’s filter in Settings)【9†L198-L204】【9†L225-L233】. You can then adjust your UI or restrictions (for instance, only show “Work” apps in a Work Focus). You can also query `try await AppFocusFilter.current.focusName` to get the active focus name【9†L216-L223】.

- **Focus Status (SiriKit)** – iOS 15 introduced `INFocusStatus`, a SiriKit class that tells you if the device is in Do Not Disturb/Focus mode (true/false). While it doesn’t give the focus name, it can let you check whether any focus is active. (For more granularity, use the App Intents approach above.)

By combining Focus and Screen Time APIs, you might for example auto-hide certain apps when the user enters “Work” Focus, or use focus scheduling to complement your Screen Time schedule. (Note: Some developers simply change allowed Home screens per Focus, but the system’s App Library still shows all apps【60†L345-L353】, so using the Screen Time “shield” is required to fully hide them as in the user’s request.)

# Live Activities & Dynamic Island

To show live updates (e.g. on Lock Screen or Dynamic Island) you can use **ActivityKit** (iOS 16+) and push notifications:

- **ActivityKit (Live Activities)** – Define an `ActivityAttributes` for your event and start a live activity in your app when an “allow” or “pause” event is triggered. For example, if you want a countdown or status update to appear on the Dynamic Island, you can start a Live Activity (`ActivitySession<Attributes>`) with an initial content state. Apple will then display it on the Lock Screen/dynamic island. Updates to the activity must be sent by the app (or via server push) and require the user’s authorization for notifications. The system only shows the Dynamic Island UI for active live activities, and the user must tap it to expand details. (In practice, this means you need to programmatically start the activity at the right time or send a push with an updated payload.)

- **Notifications & Shortcuts** – Optionally, schedule local or push notifications to notify the user (especially if you can’t or don’t use Live Activities for a given event). Note that normal banner notifications do not by default use the Dynamic Island; only specific live activities, incoming calls, timers, etc., appear there. Apple does not provide an API to arbitrarily push a Dynamic Island banner – it only shows content for live activities that your app has explicitly started.

# End‑to‑End Implementation Plan

1. **Request Screen Time permission:** In your app’s `App` or initial view, call
   ```swift
   try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
   ```
   as soon as possible【28†L62-L70】. This will prompt the user to allow Screen Time control (with Face/TouchID).
2. **Let user pick apps:** Present the system `FamilyActivityPicker` so the user selects which apps/categories to monitor. Save the resulting `FamilyActivitySelection`.
3. **Create schedule windows:** Decide the “allow” windows or limits. For each schedule (e.g. daily), create a `DeviceActivitySchedule`【30†L225-L233】. You may create multiple schedules for different days/times.
4. **Define events:** For each schedule, create a `DeviceActivityEvent` using the tokens from the user’s selection and a time threshold. For example:
   ```swift
   let event = DeviceActivityEvent(applications: selection.applicationTokens,
                                   categories: selection.categoryTokens,
                                   threshold: DateComponents(minute: maxDailyMinutes))
   ```
   As in Streaks, this marks the deadline for allowed usage【30†L238-L247】.
5. **Start monitoring:** Call `DeviceActivityCenter.shared.startMonitoring(_:, during: events:)` with a `DeviceActivityName` and your schedule and event dictionary【30†L274-L282】. This activates background tracking.
6. **Implement the extension:** Add a _Device Activity_ extension to your app. In its `DeviceActivityMonitor` subclass, override:
   - `intervalDidStart(for:)` – called at the beginning of each scheduled window. You can use this to _remove restrictions_ (clear shields) when apps become available【40†L398-L406】.
   - `intervalDidEnd(for:)` – called when the window closes. Here reapply shields (e.g. `store.shield.applicationCategories = .specific([...])`) to hide the apps【40†L398-L406】.
   - `eventDidReachThreshold(...)` – called when the time limit is reached. Use this to mark the session over or to pause the apps by shielding them. For example, apply `store.shield.applications = .specific([...])` here.
   - `eventWillReachThresholdWarning(...)` – if you set a `warningTime`, use this to notify the user (perhaps with a local notification) that their limit is almost up【30†L323-L331】.

7. **Shield (hide) apps:** In those extension callbacks (or in your app when needed), use `ManagedSettingsStore.shield` to block the apps. For instance:
   ```swift
   let store = ManagedSettingsStore(named: .individual)
   store.shield.applications = .specific([targetAppToken])
   ```
   or by category with exceptions:
   ```swift
   store.shield.applicationCategories =
       .specific(Set([utilitiesCatToken]), except: Set([calculatorAppToken]))
   ```
   as recommended to exclude specific apps【43†L198-L206】. This ensures the targeted apps are hidden from the Home Screen and require FaceID (just like Cape).
8. **Integrate Focus filters:** Register and handle a `SetFocusFilterIntent`. For each Focus the user cares about (e.g. Work, Personal), ask them to add your app’s filter in Settings. Your handler will then run when that Focus is active【9†L198-L204】. In your intent’s `perform()`, you can adjust the UI or toggle additional restrictions depending on `focusName`. You can also check the current focus with `AppFocusFilter.current.focusName`.
9. **Live Activities / Notifications:** If you want to show a live countdown or summary, start an ActivityKit live activity when an “allow” period begins or ends. Update it with the remaining time or status. Be aware that iOS only displays the dynamic island UI when an ActivityKit activity is active. Alternatively, schedule a local notification or use a notification ContentExtension to alert the user at key moments (e.g. when apps are paused).
10. **UI polish:** Throughout, use SwiftUI or UIKit with custom animations (e.g. `.animation` in SwiftUI, or `UIView.animate`) and Lottie files for any illustrative sequences (like a “pause screen” animation). Leverage haptics on important interactions. As one designer notes, these “invisible magic” touches (animations, haptic feedback, subtle motion) are what keep users engaged【24†L53-L56】.

**Key Apple APIs and frameworks:**

- Screen Time: _FamilyControls_ (permission and FamilyActivitySelection), _DeviceActivity_ (scheduling, monitoring), _ManagedSettings_ (shielding apps)【28†L62-L70】【30†L225-L233】.
- Focus: _AppIntents/Focus_ (SetFocusFilterIntent)【9†L198-L204】, and SiriKit’s `INFocusStatus` if just checking DND state.
- Live Activities: _ActivityKit_ (for Dynamic Island/Lock Screen updates) plus _UserNotifications_ for alerts.
- UI/UX: SwiftUI or UIKit animation APIs; Lottie for rich animations【25†L142-L144】; UIFeedbackGenerator for haptics.

Each of these APIs should be used as documented. For example, Apple’s WWDC sample shows requesting authorization with `AuthorizationCenter.shared.requestAuthorization(for: .individual)` in `onAppear`【40†L379-L384】 and using multiple `ManagedSettingsStore` named stores to toggle restrictions【40†L398-L406】. By following this plan and using the above APIs, you can build an app with full-screen-time control, custom pause screens, scheduled availability, and polished animations.【28†L62-L70】【30†L225-L233】【9†L198-L204】

**Sources:** Authoritative iOS developer documentation and community examples, including Apple’s WWDC and documentation【28†L62-L70】【40†L398-L406】, StackOverflow posts【9†L198-L204】【43†L198-L206】, and developer blogs and forums【24†L53-L56】【25†L142-L144】【60†L287-L290】. These cover the relevant APIs and usage patterns end to end.
