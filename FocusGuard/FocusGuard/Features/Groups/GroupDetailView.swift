import SwiftUI

struct GroupDetailView: View {
    let group: AppGroup
    @ObservedObject var viewModel: GroupsViewModel

    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var currentGroup: AppGroup

    init(group: AppGroup, viewModel: GroupsViewModel) {
        self.group = group
        self.viewModel = viewModel
        _currentGroup = State(initialValue: group)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusCard
                usageSection
                scheduleSection
                actionsSection
            }
            .padding(16)
        }
        .navigationTitle(currentGroup.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            GroupEditorView(group: currentGroup) { updated in
                viewModel.updateGroup(updated)
                currentGroup = updated
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Delete Group?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deleteGroup(currentGroup)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all blocking rules for this group.")
        }
        .onAppear {
            if let refreshed = viewModel.groups.first(where: { $0.id == group.id }) {
                currentGroup = refreshed
            }
        }
    }

    private var statusCard: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(currentGroup.stateLabel, systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                        .foregroundStyle(currentGroup.isEnabled ? .purple : .secondary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { currentGroup.isEnabled },
                        set: { newValue in
                            currentGroup.isEnabled = newValue
                            viewModel.updateGroup(currentGroup)
                        }
                    ))
                    .labelsHidden()
                }

                HStack(spacing: 24) {
                    statItem(title: "Opens", value: "\(currentGroup.openCountToday)/\(currentGroup.maxOpenCount)")
                    statItem(title: "Usage", value: currentGroup.todayUsageFormatted)
                    statItem(title: "Limit", value: currentGroup.dailyLimitFormatted)
                }

                if !currentGroup.goalLabel.isEmpty {
                    Text(currentGroup.goalLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .glassEffect()
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Usage")
                .font(.headline)
            UsageMiniChart(group: currentGroup)
                .frame(height: 80)
            Text("Weekly Overview")
                .font(.headline)
                .padding(.top, 8)
            WeeklyUsageChart(dailyTotals: weeklyTotals)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule Rules")
                .font(.headline)
            if currentGroup.scheduleRules.isEmpty {
                Text("Always active (no schedule restrictions)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(currentGroup.scheduleRules) { rule in
                    HStack {
                        Text(rule.formattedRange)
                        Spacer()
                        if rule.coversNow {
                            Text("Active now")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                LiveActivityManager.shared.startSession(group: currentGroup, targetApp: currentGroup.name)
            } label: {
                Label("Start Focus Session", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .glassEffect(.regular.tint(.purple).interactive())

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Group", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var weeklyTotals: [Int] {
        let base = currentGroup.todayUsageMinutes
        return (0 ..< 7).map { index in
            index == 6 ? base : max(0, base - (6 - index) * 5)
        }
    }
}
