import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var groups: [AppGroup] = []
    @Published var selectedGroupID: UUID?
    @Published var showRuleEditor = false
    @Published var editingRule: ScheduleRule?

    private let store = SharedStore.shared
    private let engine = BlockingEngine.shared

    init() {
        reload()
    }

    func reload() {
        groups = store.loadAppGroups()
        if selectedGroupID == nil {
            selectedGroupID = groups.first?.id
        }
    }

    var selectedGroup: AppGroup? {
        groups.first { $0.id == selectedGroupID }
    }

    func addRule(_ rule: ScheduleRule) {
        guard var group = selectedGroup else { return }
        group.scheduleRules.append(rule)
        store.updateGroup(group)
        try? engine.enable(group)
        reload()
    }

    func updateRule(_ rule: ScheduleRule) {
        guard var group = selectedGroup,
              let index = group.scheduleRules.firstIndex(where: { $0.id == rule.id }) else { return }
        group.scheduleRules[index] = rule
        store.updateGroup(group)
        try? engine.enable(group)
        reload()
    }

    func deleteRule(_ rule: ScheduleRule) {
        guard var group = selectedGroup else { return }
        group.scheduleRules.removeAll { $0.id == rule.id }
        store.updateGroup(group)
        try? engine.enable(group)
        reload()
    }
}

struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var showAddRule = false

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Create an app group first to add schedules.")
                    )
                } else {
                    Picker("Group", selection: $viewModel.selectedGroupID) {
                        ForEach(viewModel.groups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    weekGrid

                    List {
                        Section("Rules") {
                            if let group = viewModel.selectedGroup {
                                if group.scheduleRules.isEmpty {
                                    Text("No rules — group is always active")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(group.scheduleRules) { rule in
                                        ScheduleRuleRow(rule: rule, weekdaySymbols: weekdaySymbols)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                viewModel.editingRule = rule
                                                showAddRule = true
                                            }
                                    }
                                    .onDelete { indexSet in
                                        indexSet.map { group.scheduleRules[$0] }.forEach(viewModel.deleteRule)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddRule = true } label: {
                        Image(systemName: "plus")
                    }
                    .glassEffect(.regular.interactive())
                    .disabled(viewModel.selectedGroup == nil)
                }
            }
            .sheet(isPresented: $showAddRule) {
                ScheduleRuleEditor(
                    rule: viewModel.editingRule,
                    onSave: { rule in
                        if viewModel.editingRule != nil {
                            viewModel.updateRule(rule)
                        } else {
                            viewModel.addRule(rule)
                        }
                        viewModel.editingRule = nil
                    }
                )
                .presentationDetents([.medium])
            }
            .onAppear { viewModel.reload() }
        }
    }

    private var weekGrid: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                HStack {
                    ForEach(1 ... 7, id: \.self) { day in
                        Text(weekdaySymbols[day - 1].prefix(1).uppercased())
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(isToday(day) ? .purple : .secondary)
                    }
                }
                if let group = viewModel.selectedGroup {
                    HStack(spacing: 4) {
                        ForEach(1 ... 7, id: \.self) { day in
                            let active = group.scheduleRules.contains { $0.weekdays.contains(day) }
                            RoundedRectangle(cornerRadius: 4)
                                .fill(active ? Color.purple.opacity(0.6) : Color.gray.opacity(0.2))
                                .frame(height: 24)
                        }
                    }
                }
            }
            .padding(12)
            .glassEffect()
        }
        .padding(.horizontal)
    }

    private func isToday(_ weekday: Int) -> Bool {
        Calendar.current.component(.weekday, from: Date()) == weekday
    }
}

struct ScheduleRuleRow: View {
    let rule: ScheduleRule
    let weekdaySymbols: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rule.formattedRange)
                .font(.headline)
            Text(weekdayLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            if rule.coversNow {
                Text("Active now")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
            }
        }
        .padding(.vertical, 4)
    }

    private var weekdayLabel: String {
        let sorted = rule.weekdays.sorted()
        if sorted.count == 7 { return "Every day" }
        return sorted.map { weekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }
}

struct ScheduleRuleEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var weekdays: Set<Int>

    var onSave: (ScheduleRule) -> Void
    private let existingID: UUID?

    init(rule: ScheduleRule?, onSave: @escaping (ScheduleRule) -> Void) {
        existingID = rule?.id
        _startHour = State(initialValue: rule?.startHour ?? 9)
        _startMinute = State(initialValue: rule?.startMinute ?? 0)
        _endHour = State(initialValue: rule?.endHour ?? 17)
        _endMinute = State(initialValue: rule?.endMinute ?? 0)
        _weekdays = State(initialValue: rule?.weekdays ?? [2, 3, 4, 5, 6])
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Start") {
                    Stepper("Hour: \(startHour)", value: $startHour, in: 0 ... 23)
                    Stepper("Minute: \(startMinute)", value: $startMinute, in: 0 ... 55, step: 5)
                }
                Section("End") {
                    Stepper("Hour: \(endHour)", value: $endHour, in: 0 ... 23)
                    Stepper("Minute: \(endMinute)", value: $endMinute, in: 0 ... 55, step: 5)
                }
                Section("Days") {
                    WeekdayPicker(selected: $weekdays)
                }
            }
            .navigationTitle(existingID == nil ? "New Rule" : "Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let rule = ScheduleRule(
                            id: existingID ?? UUID(),
                            startHour: startHour,
                            startMinute: startMinute,
                            endHour: endHour,
                            endMinute: endMinute,
                            weekdays: weekdays
                        )
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(weekdays.isEmpty)
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selected: Set<Int>
    private let symbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        HStack {
            ForEach(1 ... 7, id: \.self) { day in
                Button {
                    if selected.contains(day) {
                        selected.remove(day)
                    } else {
                        selected.insert(day)
                    }
                } label: {
                    Text(symbols[day - 1].prefix(1).uppercased())
                        .font(.caption.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .background(selected.contains(day) ? Color.purple : Color.gray.opacity(0.2))
                        .foregroundStyle(selected.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
