// LocationStore.swift  (iOS target)
import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

enum LocationStore {
    static let geocoder = CLGeocoder()

    /// يحفظ آخر موقع في liveLocation + يسجل نقطة في history مع اسم الشارع
    static func saveFirstFix(childId: String?, lat: CLLocationDegrees?, lon: CLLocationDegrees?, acc: CLLocationAccuracy?, ts: TimeInterval?) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ [LocationStore] no guardian uid")
            return
        }
        guard let childId = childId ?? UserDefaults.standard.string(forKey: "lastLinkedChildId") else {
            print("⚠️ [LocationStore] missing childId")
            return
        }
        guard let la = lat, let lo = lon else {
            print("⚠️ [LocationStore] missing coordinates")
            return
        }

        let db = Firestore.firestore()
        let childRef = db.collection("guardians").document(uid).collection("children").document(childId)

        let location = CLLocation(latitude: la, longitude: lo)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error { print("🟡 [LocationStore] geocoder error:", error.localizedDescription) }

            var streetName = "Unknown"
            if let placemark = placemarks?.first {
                streetName = placemark.thoroughfare ?? placemark.name ?? "Unknown"
            }

            // A) liveLocation/latest
            let liveData: [String: Any] = [
                "coordinate": [la, lo],
                "streetName": streetName,
                "accuracy": acc ?? 0,
                "timestamp": ts != nil
                    ? Timestamp(date: Date(timeIntervalSince1970: ts!))
                    : FieldValue.serverTimestamp()
            ]
            childRef.collection("liveLocation").document("latest").setData(liveData, merge: true)

            // B) locationHistory/{autoID}
            let historyDoc: [String: Any] = [
                "coordinate": [la, lo],
                "streetName": streetName,
                "isSafeZone": true,
                "timestamp": FieldValue.serverTimestamp()
            ]
            childRef.collection("locationHistory").addDocument(data: historyDoc)

            print("✅ [LocationStore] Saved location for child \(childId) at \(streetName)")
        }
    }
}
