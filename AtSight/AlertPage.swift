//MARK: this page needs fixing... zone alert simulator does everything for now...
////
////  AlertPage.swift
////  AtSight
////
////  Created by Leon on 28/10/2025.
////  ✅ Fixed all errors (renamed Zone → CustomZone)
////  ✅ FIX: Added state tracking to prevent false alerts on launch.
////  ✅ FIX: Added logic to fetch and use child's custom alert sound.
////
//
//import SwiftUI
//import FirebaseFirestore
//import CoreLocation
//import UserNotifications
//import FirebaseAuth
//
//// ✅ Avoids naming conflict with Foundation.Zone
//struct CustomZone {
//    let coord: CLLocationCoordinate2D
//    let radius: Double
//    let name: String
//}
//
//struct AlertPage: View {
//    @State private var alertMessage: String = "⏳ Waiting for location..."
//    @State private var timer: Timer?
//    @State private var lastAlertTimes: [String: Date] = [:]
//    
//    // MARK: FIX - State variable to track the *previous* state of each child
//    // This prevents false alerts on app launch. (Bool = is in a safe zone)
//    @State private var lastKnownSafeStatus: [String: Bool] = [:]
//
//    private let db = Firestore.firestore()
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("📍 Zone Alert Monitor")
//                .font(.title2)
//                .bold()
//
//            Text(alertMessage)
//                .foregroundColor(.white)
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(Color.red.opacity(0.8))
//                .cornerRadius(12)
//        }
//        .padding()
//        .onAppear {
//            NotificationManager.instance.requestAuthorization()
//            startMonitoring()
//        }
//        .onDisappear {
//            timer?.invalidate()
//        }
//    }
//
//    // MARK: - Timer Loop
//    private func startMonitoring() {
//        timer?.invalidate()
//        // Run first check immediately, then start timer
//        fetchChildrenAndLocations()
//        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
//            fetchChildrenAndLocations()
//        }
//    }
//
//    // MARK: - Fetch Children
//    private func fetchChildrenAndLocations() {
//        guard let guardianId = Auth.auth().currentUser?.uid else {
//            print("⚠️ No guardian ID found.")
//            return
//        }
//
//        let childrenRef = db.collection("guardians").document(guardianId).collection("children")
//        childrenRef.getDocuments { snapshot, error in
//            if let error = error {
//                print("❌ Error fetching children: \(error.localizedDescription)")
//                return
//            }
//
//            guard let documents = snapshot?.documents else { return }
//
//            for doc in documents {
//                let childId = doc.documentID
//                let childName = doc.data()["name"] as? String ?? "Unknown Child"
//                let historyPath = "guardians/\(guardianId)/children/\(childId)/locationHistory"
//
//                db.collection(historyPath)
//                    .order(by: "timestamp", descending: true)
//                    .limit(to: 1)
//                    .getDocuments { snap, err in
//                        if let err = err {
//                            print("❌ Error fetching location for \(childName): \(err.localizedDescription)")
//                            return
//                        }
//
//                        guard let latest = snap?.documents.first,
//                              let coords = latest["coordinate"] as? [Double],
//                              coords.count == 2 else { return }
//
//                        let current = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
//                        checkZones(for: childId, childName: childName, current: current, guardianId: guardianId)
//                    }
//            }
//        }
//    }
//
//    // MARK: - Compare Zones
//    private func checkZones(for childId: String, childName: String, current: CLLocationCoordinate2D, guardianId: String) {
//        let base = "guardians/\(guardianId)/children/\(childId)"
//        let safeRef = db.collection("\(base)/safeZone")
//        let unsafeRef = db.collection("\(base)/unSafeZone")
//
//        var safeZones: [CustomZone] = []
//        var unsafeZones: [CustomZone] = []
//
//        let group = DispatchGroup()
//
//        // Load unsafe zones
//        group.enter()
//        unsafeRef.getDocuments { snap, _ in
//            if let docs = snap?.documents {
//                for doc in docs {
//                    if let geo = doc["coordinate"] as? GeoPoint {
//                        let radius = doc["zoneSize"] as? Double ?? 50
//                        let name = doc["zoneName"] as? String ?? "Unsafe area"
//                        unsafeZones.append(
//                            CustomZone(
//                                coord: CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude),
//                                radius: radius,
//                                name: name
//                            )
//                        )
//                    }
//                }
//            }
//            group.leave()
//        }
//
//        // Load safe zones
//        group.enter()
//        safeRef.getDocuments { snap, _ in
//            if let docs = snap?.documents {
//                for doc in docs {
//                    if let geo = doc["coordinate"] as? GeoPoint {
//                        let radius = doc["zoneSize"] as? Double ?? 50
//                        let name = doc["zoneName"] as? String ?? "Safe area"
//                        safeZones.append(
//                            CustomZone(
//                                coord: CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude),
//                                radius: radius,
//                                name: name
//                            )
//                        )
//                    }
//                }
//            }
//            group.leave()
//        }
//
//        group.notify(queue: .main) {
//            evaluatePosition(
//                childId: childId,
//                childName: childName,
//                current: current,
//                safeZones: safeZones,
//                unsafeZones: unsafeZones,
//                guardianId: guardianId
//            )
//        }
//    }
//
//    // MARK: - Evaluate Position (FIXED LOGIC)
//    private func evaluatePosition(
//        childId: String,
//        childName: String,
//        current: CLLocationCoordinate2D,
//        safeZones: [CustomZone],
//        unsafeZones: [CustomZone],
//        guardianId: String
//    ) {
//        func zoneContaining(_ zones: [CustomZone]) -> CustomZone? {
//            for zone in zones {
//                let dist = distance(from: current, to: zone.coord)
//                if dist <= zone.radius {
//                    print("📏 \(childName) is \(Int(dist))m from \(zone.name) center (radius \(Int(zone.radius))) ✅")
//                    return zone
//                }
//            }
//            return nil
//        }
//        
//        // Get the child's *previous* status
//        let wasInSafeZone = lastKnownSafeStatus[childId]
//
//        // 1. Check if child is in an UNSAFE zone
//        if let zone = zoneContaining(unsafeZones) {
//            // Only alert if they were previously safe or unknown (first run)
//            if wasInSafeZone == nil || wasInSafeZone == true {
//                triggerAlertIfNeeded(
//                    childId: childId,
//                    title: "🚨 Unsafe Zone Alert",
//                    message: "\(childName) entered unsafe zone: \(zone.name)",
//                    color: "red",
//                    isSafeZone: false,
//                    guardianId: guardianId
//                )
//            }
//            // Update status: they are NOT in a safe zone
//            lastKnownSafeStatus[childId] = false
//        
//        // 2. Check if child is in a SAFE zone
//        } else if zoneContaining(safeZones) != nil {
//            // Child is safe.
//            alertMessage = "✅ \(childName) is in a safe area."
//            // Update status: they ARE in a safe zone
//            lastKnownSafeStatus[childId] = true
//            
//        // 3. Child is OUTSIDE (not safe, not unsafe)
//        } else {
//            // Only alert if they were *previously* in a safe zone
//            if wasInSafeZone == true {
//                triggerAlertIfNeeded(
//                    childId: childId,
//                    title: "⚠️ Safe Zone Exit",
//                    message: "\(childName) left safe zone.",
//                    color: "orange",
//                    isSafeZone: true, // This event is related to a safe-zone
//                    guardianId: guardianId
//                )
//            }
//            // Update status: they are NOT in a safe zone
//            lastKnownSafeStatus[childId] = false
//        }
//    }
//
//    // MARK: - Control Alert Frequency (FIXED)
//    private func triggerAlertIfNeeded(
//        childId: String,
//        title: String,
//        message: String,
//        color: String,
//        isSafeZone: Bool,
//        guardianId: String
//    ) {
//        let now = Date()
//        // Check if we've alerted *for this child* recently
//        if let lastTime = lastAlertTimes[childId], now.timeIntervalSince(lastTime) < 120 {
//            print("⏱️ Skipping alert for \(childId).")
//            return
//        }
//
//        // MARK: FIX - Fetch custom sound *before* sending the alert
//        let settingsDoc = db.collection("guardians")
//            .document(guardianId)
//            .collection("children")
//            .document(childId)
//            .collection("notifications")
//            .document("settings")
//
//        settingsDoc.getDocument { snapshot, error in
//            var soundName = "alert_sound.wav" // Default sound
//            
//            if let error = error {
//                print("❌ Error fetching sound, using default. \(error.localizedDescription)")
//            } else if let data = snapshot?.data(), let soundFile = data["sound"] as? String {
//                soundName = soundFile + ".wav" // Use custom sound
//                print("✅ Using custom sound: \(soundName)")
//            } else {
//                print("⚠️ No custom sound set, using default.")
//            }
//
//            // Now, send the alert with the correct sound
//            // We set the time *after* fetching the sound to avoid race conditions
//            DispatchQueue.main.async {
//                self.lastAlertTimes[childId] = now
//                self.sendAlert(
//                    title: title,
//                    message: message,
//                    color: color,
//                    isSafeZone: isSafeZone,
//                    guardianId: guardianId,
//                    soundName: soundName // Pass the correct sound
//                )
//            }
//        }
//    }
//
//    // MARK: - Send Notification + Firestore Save (FIXED)
//    private func sendAlert(
//        title: String,
//        message: String,
//        color: String,
//        isSafeZone: Bool,
//        guardianId: String,
//        soundName: String // MARK: FIX - Added soundName parameter
//    ) {
//        alertMessage = message
//        print("🔔 ALERT:", message)
//
//        // MARK: FIX - Use the soundName parameter
//        NotificationManager.instance.scheduleNotification(
//            title: title,
//            body: message,
//            soundName: soundName
//        )
//
//        let notifData: [String: Any] = [
//            "title": title,
//            "body": message,
//            "timestamp": Timestamp(date: Date()),
//            "isSafeZone": isSafeZone,
//            "event": "zone_alert",
//            "color": color
//        ]
//
//        db.collection("guardians")
//            .document(guardianId)
//            .collection("notifications")
//            .addDocument(data: notifData) { error in
//                if let error = error {
//                    print("❌ Failed to store notification:", error.localizedDescription)
//                } else {
//                    print("✅ Notification stored successfully with color \(color).")
//                }
//            }
//    }
//
//    // MARK: - Distance Helper
//    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
//        CLLocation(latitude: from.latitude, longitude: from.longitude)
//            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
//    } 
//}
