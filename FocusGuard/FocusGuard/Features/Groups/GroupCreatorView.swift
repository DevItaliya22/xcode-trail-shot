import FamilyControls
import SwiftUI

struct GroupCreatorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selection = FamilyActivitySelection()
    @State private var dailyLimitHours = 2
    @State private var dailyLimitMinutes = 0
    @State private var onDemandMinutes = 30
    @State private var maxOpenCount = 3
    @State private var goalLabel = ""
    @State private var showPicker = false

    var onSave: (AppGroup) -> Void

    private var totalDailyMinutes: Int {
        dailyLimitHours * 60 + dailyLimitMinutes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("e.g. Distracting Apps", text: $name)
                }

                Section("Apps") {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Text("Select Apps")
                            Spacer()
                            Text("\(selection.applicationTokens.count + selection.categoryTokens.count) selected")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Daily Limit") {
                    Stepper("Hours: \(dailyLimitHours)", value: $dailyLimitHours, in: 0 ... 12)
                    Stepper("Minutes: \(dailyLimitMinutes)", value: $dailyLimitMinutes, in: 0 ... 55, step: 5)
                    Text("Total: \(totalDailyMinutes) min/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("On-Demand Access") {
                    Stepper("Resume duration: \(onDemandMinutes)m", value: $onDemandMinutes, in: 5 ... 120, step: 5)
                    Stepper("Max opens per day: \(maxOpenCount)", value: $maxOpenCount, in: 1 ... 10)
                }

                Section("Goal") {
                    TextField("e.g. 7 days until Final Exam", text: $goalLabel)
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        }
    }

    private func save() {
        let group = AppGroup(
            name: name.trimmingCharacters(in: .whitespaces),
            selection: selection,
            dailyLimitMinutes: totalDailyMinutes,
            onDemandMinutes: onDemandMinutes,
            maxOpenCount: maxOpenCount,
            goalLabel: goalLabel
        )
        onSave(group)
        dismiss()
    }
}

struct GroupEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var group: AppGroup
    @State private var dailyLimitHours: Int
    @State private var dailyLimitMinutes: Int
    @State private var showPicker = false

    var onSave: (AppGroup) -> Void

    init(group: AppGroup, onSave: @escaping (AppGroup) -> Void) {
        _group = State(initialValue: group)
        _dailyLimitHours = State(initialValue: group.dailyLimitMinutes / 60)
        _dailyLimitMinutes = State(initialValue: group.dailyLimitMinutes % 60)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("Name", text: $group.name)
                }

                Section("Apps") {
                    Button { showPicker = true } label: {
                        HStack {
                            Text("Edit Apps")
                            Spacer()
                            Text("\(group.appCount) selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Daily Limit") {
                    Stepper("Hours: \(dailyLimitHours)", value: $dailyLimitHours, in: 0 ... 12)
                    Stepper("Minutes: \(dailyLimitMinutes)", value: $dailyLimitMinutes, in: 0 ... 55, step: 5)
                }

                Section("On-Demand Access") {
                    Stepper("Resume: \(group.onDemandMinutes)m", value: $group.onDemandMinutes, in: 5 ... 120, step: 5)
                    Stepper("Max opens: \(group.maxOpenCount)", value: $group.maxOpenCount, in: 1 ... 10)
                }

                Section("Goal") {
                    TextField("Goal label", text: $group.goalLabel)
                }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $group.selection)
        }
    }

    private func save() {
        group.dailyLimitMinutes = dailyLimitHours * 60 + dailyLimitMinutes
        onSave(group)
        dismiss()
    }
}
