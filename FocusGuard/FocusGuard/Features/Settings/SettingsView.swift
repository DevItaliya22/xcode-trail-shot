import FamilyControls
import LocalAuthentication
import SwiftUI
import UserNotifications

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var passcodeEnabled: Bool
    @Published var notificationsEnabled: Bool
    @Published var authStatus: AuthorizationStatus
    @Published var errorMessage: String?
    @Published var showResetConfirm = false

    private let store = SharedStore.shared
    private let engine = BlockingEngine.shared

    init() {
        passcodeEnabled = store.isPasscodeEnabled
        notificationsEnabled = store.areNotificationsEnabled
        authStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func togglePasscode() {
        if passcodeEnabled {
            passcodeEnabled = false
            store.isPasscodeEnabled = false
            return
        }
        authenticateToEnablePasscode()
    }

    func toggleNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        store.areNotificationsEnabled = enabled
        if enabled {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            }
        }
    }

    func resetDailyCounts() {
        store.resetAllCounts()
        engine.refreshAllGroups()
    }

    func reauthorize() {
        Task {
            do {
                try await engine.requestAuthorization()
                authStatus = AuthorizationCenter.shared.authorizationStatus
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func authenticateToEnablePasscode() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Biometrics unavailable"
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Enable passcode lock for FocusGuard settings"
        ) { success, authError in
            Task { @MainActor in
                if success {
                    self.passcodeEnabled = true
                    self.store.isPasscodeEnabled = true
                } else {
                    self.errorMessage = authError?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var isUnlocked = false
    @State private var showLockScreen = true

    var body: some View {
        Group {
            if SharedStore.shared.isPasscodeEnabled && showLockScreen && !isUnlocked {
                PasscodeLockView(onUnlock: { isUnlocked = true; showLockScreen = false })
            } else {
                settingsContent
            }
        }
    }

    private var settingsContent: some View {
        NavigationStack {
            Form {
                Section("Screen Time") {
                    HStack {
                        Text("Authorization")
                        Spacer()
                        Text(authStatusLabel)
                            .foregroundStyle(.secondary)
                    }
                    Button("Re-authorize Screen Time") {
                        viewModel.reauthorize()
                    }
                }

                Section("Security") {
                    Toggle("Passcode Lock", isOn: Binding(
                        get: { viewModel.passcodeEnabled },
                        set: { _ in viewModel.togglePasscode() }
                    ))
                }

                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { viewModel.notificationsEnabled },
                        set: { viewModel.toggleNotifications($0) }
                    ))
                }

                Section("Data") {
                    Button("Reset Daily Counts", role: .destructive) {
                        viewModel.showResetConfirm = true
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("App Group")
                        Spacer()
                        Text(AppGroupConstants.suiteName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset all daily open counts?",
                isPresented: $viewModel.showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { viewModel.resetDailyCounts() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var authStatusLabel: String {
        switch viewModel.authStatus {
        case .approved, .approvedWithDataAccess: return "Approved"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }
}

struct PasscodeLockView: View {
    var onUnlock: () -> Void
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("FocusGuard Locked")
                .font(.title2.weight(.semibold))
            Button("Unlock with Face ID / Passcode") {
                authenticate()
            }
            .glassEffect(.regular.tint(.purple).interactive())
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .alert("Unlock Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func authenticate() {
        let context = LAContext()
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock FocusGuard settings"
        ) { success, error in
            Task { @MainActor in
                if success {
                    onUnlock()
                } else {
                    errorMessage = error?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }
}
