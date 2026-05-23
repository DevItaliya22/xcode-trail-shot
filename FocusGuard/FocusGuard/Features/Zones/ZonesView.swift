import MapKit
import SwiftUI

@MainActor
final class ZonesViewModel: ObservableObject {
    @Published var zones: [AllowZone] = []
    @Published var groups: [AppGroup] = []
    @Published var showCreator = false
    @Published var selectedZone: AllowZone?

    private let zoneMonitor = ZoneMonitor.shared
    private let store = SharedStore.shared

    init() {
        reload()
    }

    func reload() {
        zones = zoneMonitor.zones
        groups = store.loadAppGroups()
    }

    func addZone(name: String, coordinate: CLLocationCoordinate2D, radius: Double, groupID: UUID) {
        let zone = AllowZone(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: radius,
            linkedGroupID: groupID
        )
        zoneMonitor.addZone(zone)
        reload()
    }

    func deleteZone(_ zone: AllowZone) {
        zoneMonitor.deleteZone(zone.id)
        reload()
    }

    func groupName(for id: UUID) -> String {
        groups.first { $0.id == id }?.name ?? "Unknown"
    }
}

struct ZonesView: View {
    @StateObject private var viewModel = ZonesViewModel()
    @StateObject private var zoneMonitor = ZoneMonitor.shared
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.zones.isEmpty {
                    ContentUnavailableView(
                        "No Allow Zones",
                        systemImage: "location.slash",
                        description: Text("Add a zone where app groups become unrestricted.")
                    )
                } else {
                    ForEach(viewModel.zones) { zone in
                        ZoneRow(
                            zone: zone,
                            groupName: viewModel.groupName(for: zone.linkedGroupID),
                            isActive: zoneMonitor.activeZoneIDs.contains(zone.id)
                        )
                    }
                    .onDelete { indexSet in
                        indexSet.map { viewModel.zones[$0] }.forEach(viewModel.deleteZone)
                    }
                }
            }
            .navigationTitle("Allow Zones")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .glassEffect(.regular.interactive())
                    .disabled(viewModel.groups.isEmpty)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ZoneCreatorView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .onAppear {
                zoneMonitor.requestAuthorization()
                viewModel.reload()
            }
        }
    }
}

struct ZoneRow: View {
    let zone: AllowZone
    let groupName: String
    let isActive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(.headline)
                Text("Linked to \(groupName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(zone.radiusMeters))m radius")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isActive {
                Text("Inside")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ZoneCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ZonesViewModel

    @State private var name = ""
    @State private var radius: Double = 200
    @State private var selectedGroupID: UUID?
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )
    @State private var pinCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $position) {
                    Marker(name.isEmpty ? "Zone" : name, coordinate: pinCoordinate)
                        .tint(.purple)
                    MapCircle(center: pinCoordinate, radius: radius)
                        .foregroundStyle(.purple.opacity(0.2))
                        .stroke(.purple, lineWidth: 2)
                }
                .frame(height: 280)
                .onMapCameraChange { context in
                    pinCoordinate = context.region.center
                }

                Form {
                    Section("Zone Details") {
                        TextField("Zone name", text: $name)
                        Picker("Linked Group", selection: $selectedGroupID) {
                            Text("Select group").tag(UUID?.none)
                            ForEach(viewModel.groups) { group in
                                Text(group.name).tag(Optional(group.id))
                            }
                        }
                    }
                    Section("Radius") {
                        Slider(value: $radius, in: 50 ... 1000, step: 50) {
                            Text("Radius")
                        }
                        Text("\(Int(radius)) meters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Allow Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || selectedGroupID == nil)
                }
            }
            .onAppear {
                if selectedGroupID == nil {
                    selectedGroupID = viewModel.groups.first?.id
                }
                if let location = ZoneMonitor.shared.currentLocation {
                    pinCoordinate = location.coordinate
                    position = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
        }
    }

    private func save() {
        guard let groupID = selectedGroupID else { return }
        viewModel.addZone(
            name: name,
            coordinate: pinCoordinate,
            radius: radius,
            groupID: groupID
        )
        dismiss()
    }
}
