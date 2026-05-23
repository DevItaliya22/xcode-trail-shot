import FamilyControls
import SwiftUI

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published var groups: [AppGroup] = []
    @Published var showCreator = false
    @Published var errorMessage: String?

    private let store = SharedStore.shared
    private let engine = BlockingEngine.shared

    init() {
        reload()
    }

    func reload() {
        groups = store.loadAppGroups()
    }

    func addGroup(_ group: AppGroup) {
        store.updateGroup(group)
        do {
            try engine.enable(group)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateGroup(_ group: AppGroup) {
        store.updateGroup(group)
        do {
            if group.isEnabled {
                try engine.enable(group)
            } else {
                engine.disable(group)
            }
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroup(_ group: AppGroup) {
        engine.disable(group)
        store.deleteGroup(group.id)
        reload()
    }

    func toggleGroup(_ group: AppGroup) {
        var updated = group
        updated.isEnabled.toggle()
        updateGroup(updated)
    }
}
