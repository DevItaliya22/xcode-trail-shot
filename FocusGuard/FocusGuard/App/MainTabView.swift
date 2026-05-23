import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            GroupsView()
                .tabItem {
                    Label("Groups", systemImage: "square.grid.2x2.fill")
                }

            ZonesView()
                .tabItem {
                    Label("Zones", systemImage: "location.fill")
                }

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SessionHUDView()
        }
    }
}

struct RootView: View {
    @State private var showOnboarding: Bool

    init() {
        _showOnboarding = State(initialValue: !SharedStore.shared.isOnboardingComplete)
    }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView {
                    withAnimation {
                        showOnboarding = false
                    }
                }
            } else {
                MainTabView()
            }
        }
        .onAppear {
            BlockingEngine.shared.refreshAllGroups()
        }
    }
}
