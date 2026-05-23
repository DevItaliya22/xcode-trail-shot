# FocusGuard

Native iOS digital wellness app built with SwiftUI, Screen Time APIs, and iOS 26 Liquid Glass.

## Requirements

- Xcode 26+ with iOS 26 SDK
- Physical iPhone (Screen Time / Family Controls do not work in Simulator)
- Apple Developer account with **Family Controls** entitlement approved

## Project structure

```
FocusGuard/
├── FocusGuard/              Main app (SwiftUI tabs, onboarding, settings)
├── FocusGuardShieldConfig/  Custom Pause Screen (ShieldConfiguration)
├── FocusGuardShieldAction/  Resume / Stay Focused button handler
├── FocusGuardDeviceActivity/ Schedule & threshold monitor
├── FocusGuardWidget/        Live Activity + Dynamic Island
└── Shared/                  SharedStore, models, ActivityAttributes
```

**App Group:** `group.com.focusguard.shared`

## Open in Xcode

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen
cd FocusGuard
xcodegen generate
open FocusGuard.xcodeproj
```

### Option B — Manual

Create a new iOS App project in Xcode and add all source folders + extension targets following `project.yml`.

## Setup checklist

1. Set your **Development Team** on all 5 targets
2. Enable App Groups capability → `group.com.focusguard.shared` on every target
3. Request **Family Controls** entitlement from Apple Developer portal
4. Embed all 4 extensions in the main app target (General → Frameworks, Libraries, and Embedded Content)
5. Build & run on a **physical device**

## Features

| Tab          | Description                                                              |
| ------------ | ------------------------------------------------------------------------ |
| **Groups**   | Create app groups, set daily limits, on-demand minutes, max opens, goals |
| **Zones**    | GPS Allow Zones — auto-unshield linked groups when inside                |
| **Schedule** | Weekday/time rules per group via DeviceActivity                          |
| **Settings** | Passcode lock, notifications, Screen Time re-auth, daily reset           |

## Pause Screen flow

```
UNBLOCKED → daily limit hit → SHIELDED (Pause Screen)
  → "Resume 30m" (≤ max opens) → TEMPORARILY_UNSHIELDED
  → timer expires → SHIELDED
  → exceeds max opens → HARD_BLOCKED (hidden from home screen)
  → midnight → UNBLOCKED
```

## Notes

- Shield UI is system-controlled (`ShieldConfiguration`) — only colors, title, subtitle, and two buttons
- All cross-process state flows through `SharedStore` (App Group UserDefaults)
- Live Activities require user permission for notifications

## Bundle IDs

| Target          | Bundle ID                           |
| --------------- | ----------------------------------- |
| Main app        | `com.focusguard.app`                |
| Shield Config   | `com.focusguard.app.shieldconfig`   |
| Shield Action   | `com.focusguard.app.shieldaction`   |
| Device Activity | `com.focusguard.app.deviceactivity` |
| Widget          | `com.focusguard.app.widget`         |
