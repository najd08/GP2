//MARK: This file is added to better manage "AddZonePage" & "SavedZonesView" & "ZoneAlertSimulation" files and to avoid redundancy.

import SwiftUI
import MapKit
import CoreLocation // Required for location services
import FirebaseFirestore
import FirebaseAuth

//MARK: - Zone struct:
// Zone struct: Defines the data structure for a geographical zone.
struct Zone: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var zoneName: String
    var isSafeZone: Bool
    var zoneSize: Double // This is the radius in meters
}

// MARK: - Location Manager Class
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    //send alert to user to ask for his location:
    func requestLocationPermission() {
        authorizationStatus = locationManager.authorizationStatus
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        default:
            break
        }
    }
    
    //update location of the user depending on where he is
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        if newLocation.horizontalAccuracy < 100 {
            location = newLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
        default:
            break
        }
    }
}


class ZonesViewModel: ObservableObject {

    @Published var zones: [Zone] = []
    
    // Use childID so we save/fetch/delete zones of the correct child
    var childID: String

    // MARK: - Location Properties
    private let locationManager = LocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var newZoneCoordinateToFocus: CLLocationCoordinate2D?

    init(childID: String) {
        self.childID = childID
        
        // Listen for updates from the LocationManager and update our own published properties
        locationManager.$location
            .map { $0?.coordinate }
            .receive(on: DispatchQueue.main)
            .assign(to: &$userLocation)
        
        locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$authorizationStatus)
    }

    //MARK: - Functions:
    //Load the saved zones for the current child
    func fetchZones() {
            guard let guardianID = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            let childRef = db.collection("guardians").document(guardianID).collection("children").document(childID)

            let group = DispatchGroup()
            var fetchedZones: [Zone] = []

            for collection in ["safeZone", "unSafeZone"] {
                group.enter()
                childRef.collection(collection).getDocuments { snapshot, error in
                    
                    // MARK: FIX - Added error handling here
                    if let error = error {
                        print("❌ Error fetching zones from '\(collection)': \(error.localizedDescription)")
                        // This is likely a Firestore Security Rules issue.
                    }
                    
                    if let documents = snapshot?.documents {
                        for doc in documents {
                            let data = doc.data()
                            if let geo = data["coordinate"] as? GeoPoint,
                               let name = data["zoneName"] as? String,
                               let isSafe = data["isSafeZone"] as? Bool,
                               let size = data["zoneSize"] as? Double {
                                let zone = Zone(
                                    coordinate: CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude),
                                    zoneName: name,
                                    isSafeZone: isSafe,
                                    zoneSize: size
                                )
                                fetchedZones.append(zone)
                            }
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.zones = fetchedZones
            }
        }
    
    //function to add the specified zone to the "zones" list:
    func addZone(coordinates: CLLocationCoordinate2D, size: Double, isSafe: Bool, name: String) {
        let newZone = Zone(coordinate: coordinates, zoneName: name, isSafeZone: isSafe, zoneSize: size)
        zones.append(newZone)
        
        // Save to Firebase
        saveZoneToFirebase(zone: newZone)

        // Publish the new coordinate to trigger auto-zoom in the view
        newZoneCoordinateToFocus = newZone.coordinate
    }

    //function to save zone of the current child to firebase
    func saveZoneToFirebase(zone: Zone) {
        let db = Firestore.firestore()
        guard let guardianID = Auth.auth().currentUser?.uid else { return }

        let collection = zone.isSafeZone ? "safeZone" : "unSafeZone"

        db.collection("guardians").document(guardianID)
            .collection("children").document(childID)
            .collection(collection).addDocument(data: [
                "coordinate": GeoPoint(latitude: zone.coordinate.latitude, longitude: zone.coordinate.longitude),
                "zoneName": zone.zoneName,
                "isSafeZone": zone.isSafeZone,
                "zoneSize": zone.zoneSize
            ])
    }
    
    //Updates the zone name in Firebase.
    func updateZoneNameInFirebase(zoneToUpdate: Zone, newName: String) {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let db = Firestore.firestore()
        let collectionName = zoneToUpdate.isSafeZone ? "safeZone" : "unSafeZone"

        db.collection("guardians")
            .document(guardianID)
            .collection("children")
            .document(childID) // ✅ use correct childID
            .collection(collectionName)
            .whereField("coordinate", isEqualTo: GeoPoint(latitude: zoneToUpdate.coordinate.latitude, longitude: zoneToUpdate.coordinate.longitude))
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let document = snapshot?.documents.first {
                        // Update the document in Firebase
                        document.reference.updateData(["zoneName": trimmedName]) { error in
                            if error == nil {
                                // Update local zones array
                                if let index = self.zones.firstIndex(where: { $0.id == zoneToUpdate.id }) {
                                    self.zones[index].zoneName = trimmedName
                                }
                            }
                        }
                    }
                }
            }
    }
    
    //function to delete zones.
    func deleteZone(_ zone: Zone) {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let collectionName = zone.isSafeZone ? "safeZone" : "unSafeZone"

        db.collection("guardians")
            .document(guardianID)
            .collection("children")
            .document(childID) // ✅ use correct childID
            .collection(collectionName)
            .whereField("coordinate", isEqualTo: GeoPoint(latitude: zone.coordinate.latitude, longitude: zone.coordinate.longitude))
            .getDocuments { snapshot, error in
                if let document = snapshot?.documents.first {
                    document.reference.delete { error in
                        if error == nil {
                            DispatchQueue.main.async {
                                if let index = self.zones.firstIndex(where: { $0.id == zone.id }) {
                                    self.zones.remove(at: index)
                                }
                            }
                        }
                    }
                }
            }
    }

    // MARK: - Location and UI Helper Functions
    
    // Called from the view to start the location permission process.
    func requestLocationPermission() {
        locationManager.requestLocationPermission()
    }
    
    //add a way for user to go to his setting immediatly to give access to his location:
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Helper to dismiss the keyboard
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
