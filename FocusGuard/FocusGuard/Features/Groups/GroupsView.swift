import FamilyControls
import SwiftUI

struct GroupsView: View {
    @StateObject private var viewModel = GroupsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.groups.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.groups) { group in
                            NavigationLink(value: group) {
                                GroupCard(group: group)
                            }
                            .buttonStyle(.plain)
                        }
                        Button { viewModel.showCreator = true } label: {
                            AddGroupCard()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("My Groups")
            .navigationDestination(for: AppGroup.self) { group in
                GroupDetailView(group: group, viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { viewModel.showCreator = true } label: {
                        Image(systemName: "plus")
                    }
                    .glassEffect(.regular.interactive())
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreator) {
            GroupCreatorView(onSave: viewModel.addGroup)
                .presentationDetents([.medium, .large])
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear { viewModel.reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple.opacity(0.6))
            Text("No app groups yet")
                .font(.title3.weight(.semibold))
            Text("Create a group to start blocking distracting apps.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Create Group") { viewModel.showCreator = true }
                .glassEffect(.regular.tint(.purple).interactive())
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
        }
        .padding(32)
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}
