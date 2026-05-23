import SwiftUI

struct SessionHUDView: View {
    @State private var session: ActiveSession?
    @State private var timer: Timer?
    @State private var secondsRemaining = 0

    var body: some View {
        Group {
            if let session {
                sessionCard(session)
            }
        }
        .onAppear { refresh() }
        .onDisappear { timer?.invalidate() }
    }

    private func sessionCard(_ activeSession: ActiveSession) -> some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activeSession.groupName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(activeSession.targetAppName)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedTime(secondsRemaining))
                        .font(.caption.monospacedDigit().weight(.semibold))
                    HStack(spacing: 3) {
                        ForEach(0 ..< activeSession.maxOpenCount, id: \.self) { index in
                            Circle()
                                .fill(index < activeSession.openCount ? Color.purple : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                Button {
                    Task {
                        await LiveActivityManager.shared.endSession()
                        session = nil
                        timer?.invalidate()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .glassEffect()
        }
        .padding(.horizontal)
    }

    private func refresh() {
        session = SharedStore.shared.loadActiveSession()
        updateRemaining()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                updateRemaining()
            }
        }
    }

    private func updateRemaining() {
        guard let session else { return }
        secondsRemaining = max(0, Int(session.endsAt.timeIntervalSinceNow))
        if secondsRemaining == 0 {
            Task {
                await LiveActivityManager.shared.endSession()
                self.session = nil
                timer?.invalidate()
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
