import Combine
@preconcurrency import CoreLocation
import Foundation

@MainActor
final class ZoneMonitor: NSObject, ObservableObject {
    static let shared = ZoneMonitor()

    private let locationManager = CLLocationManager()
    private let store = SharedStore.shared
    private let engine = BlockingEngine.shared

    @Published var zones: [AllowZone] = []
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var activeZoneIDs: Set<UUID> = []

    private var monitoredRegions: [UUID: CLCircularRegion] = [:]

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = locationManager.authorizationStatus
        zones = store.loadAllowZones()
        syncRegions()
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func addZone(_ zone: AllowZone) {
        zones.append(zone)
        store.saveAllowZones(zones)
        syncRegions()
    }

    func updateZone(_ zone: AllowZone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            zones[index] = zone
            store.saveAllowZones(zones)
            syncRegions()
        }
    }

    func deleteZone(_ zoneID: UUID) {
        zones.removeAll { $0.id == zoneID }
        store.saveAllowZones(zones)
        if let region = monitoredRegions[zoneID] {
            locationManager.stopMonitoring(for: region)
            monitoredRegions.removeValue(forKey: zoneID)
        }
        activeZoneIDs.remove(zoneID)
    }

    func syncRegions() {
        for region in monitoredRegions.values {
            locationManager.stopMonitoring(for: region)
        }
        monitoredRegions.removeAll()

        for zone in zones {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude),
                radius: zone.radiusMeters,
                identifier: zone.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            locationManager.startMonitoring(for: region)
            monitoredRegions[zone.id] = region
        }
    }

    private func applyZoneEffect(zoneID: UUID, inside: Bool) {
        guard let zone = zones.first(where: { $0.id == zoneID }) else { return }
        let groups = store.loadAppGroups()
        guard let group = groups.first(where: { $0.id == zone.linkedGroupID }) else { return }

        if inside {
            engine.unshieldGroup(group)
        } else if group.isCurrentlyActive {
            engine.shieldGroup(group)
        }
    }
}

extension ZoneMonitor: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let snapshot = CLLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor in
            currentLocation = snapshot
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let zoneID = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            activeZoneIDs.insert(zoneID)
            applyZoneEffect(zoneID: zoneID, inside: true)
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didExitRegion region: CLRegion) {
        guard let zoneID = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            activeZoneIDs.remove(zoneID)
            applyZoneEffect(zoneID: zoneID, inside: false)
        }
    }
}
