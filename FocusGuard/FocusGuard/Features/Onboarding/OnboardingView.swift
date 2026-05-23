import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @State private var step = 0
    @State private var isRequesting = false
    @State private var authError: String?
    @Namespace private var ns

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.10, green: 0.07, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

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

                GlassEffectContainer(spacing: 0) {
                    VStack(spacing: 24) {
                        stepContent
                    }
                    .padding(32)
                    .glassEffect()
                }
                .padding(.horizontal, 24)

                Spacer()

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
                .disabled(isRequesting)
            }
        }
        .alert("Authorization Failed", isPresented: .constant(authError != nil)) {
            Button("OK") { authError = nil }
        } message: {
            Text(authError ?? "")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            featureRow(
                icon: "shield.fill",
                title: "Block distracting apps",
                body: "Set limits, schedules, and open counts for any app."
            )
        case 1:
            featureRow(
                icon: "clock.arrow.circlepath",
                title: "Smart on-demand access",
                body: "Allow yourself a limited number of breaks per day."
            )
        default:
            featureRow(
                icon: "lock.shield",
                title: "Needs Screen Time access",
                body: "FocusGuard uses Apple's Screen Time API. Your data never leaves your device."
            )
        }
    }

    private func featureRow(icon: String, title: String, body: String) -> some View {
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

    private func advance() {
        if step < 2 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                step += 1
            }
        } else {
            requestPermission()
        }
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            do {
                try await BlockingEngine.shared.requestAuthorization()
                await MainActor.run {
                    SharedStore.shared.isOnboardingComplete = true
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                    isRequesting = false
                }
            }
        }
    }
}
