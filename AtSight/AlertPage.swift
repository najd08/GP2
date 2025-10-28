//
//  AlertPage.swift
//  AtSight
//
//  Created by Leon on 28/10/2025.
//  ✅ Fixed all errors (renamed Zone → CustomZone)
//

import SwiftUI
import FirebaseFirestore
import CoreLocation
import UserNotifications
import FirebaseAuth

// ✅ Avoids naming conflict with Foundation.Zone
struct CustomZone {
    let coord: CLLocationCoordinate2D
    let radius: Double
    let name: String
}

struct AlertPage: View {
    @State private var alertMessage: String = "⏳ Waiting for location..."
    @State private var timer: Timer?
    @State private var lastAlertTimes: [String: Date] = [:]
    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 20) {
            Text("📍 Zone Alert Monitor")
                .font(.title2)
                .bold()

            Text(alertMessage)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
        }
        .padding()
        .onAppear {
            NotificationManager.instance.requestAuthorization()
            startMonitoring()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Timer Loop
    private func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            fetchChildrenAndLocations()
        }
    }

    // MARK: - Fetch Children
    private func fetchChildrenAndLocations() {
        guard let guardianId = Auth.auth().currentUser?.uid else {
            print("⚠️ No guardian ID found.")
            return
        }

        let childrenRef = db.collection("guardians").document(guardianId).collection("children")
        childrenRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching children: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else { return }

            for doc in documents {
                let childId = doc.documentID
                let childName = doc.data()["name"] as? String ?? "Unknown Child"
                let historyPath = "guardians/\(guardianId)/children/\(childId)/locationHistory"

                db.collection(historyPath)
                    .order(by: "timestamp", descending: true)
                    .limit(to: 1)
                    .getDocuments { snap, err in
                        if let err = err {
                            print("❌ Error fetching location for \(childName): \(err.localizedDescription)")
                            return
                        }

                        guard let latest = snap?.documents.first,
                              let coords = latest["coordinate"] as? [Double],
                              coords.count == 2 else { return }

                        let current = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
                        checkZones(for: childId, childName: childName, current: current, guardianId: guardianId)
                    }
            }
        }
    }

    // MARK: - Compare Zones
    private func checkZones(for childId: String, childName: String, current: CLLocationCoordinate2D, guardianId: String) {
        let base = "guardians/\(guardianId)/children/\(childId)"
        let safeRef = db.collection("\(base)/safeZone")
        let unsafeRef = db.collection("\(base)/unSafeZone")

        var safeZones: [CustomZone] = []
        var unsafeZones: [CustomZone] = []

        let group = DispatchGroup()

        // Load unsafe zones
        group.enter()
        unsafeRef.getDocuments { snap, _ in
            if let docs = snap?.documents {
                for doc in docs {
                    if let geo = doc["coordinate"] as? GeoPoint {
                        let radius = doc["zoneSize"] as? Double ?? 50
                        let name = doc["zoneName"] as? String ?? "Unsafe area"
                        unsafeZones.append(
                            CustomZone(
                                coord: CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude),
                                radius: radius,
                                name: name
                            )
                        )
                    }
                }
            }
            group.leave()
        }

        // Load safe zones
        group.enter()
        safeRef.getDocuments { snap, _ in
            if let docs = snap?.documents {
                for doc in docs {
                    if let geo = doc["coordinate"] as? GeoPoint {
                        let radius = doc["zoneSize"] as? Double ?? 50
                        let name = doc["zoneName"] as? String ?? "Safe area"
                        safeZones.append(
                            CustomZone(
                                coord: CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude),
                                radius: radius,
                                name: name
                            )
                        )
                    }
                }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            evaluatePosition(
                childId: childId,
                childName: childName,
                current: current,
                safeZones: safeZones,
                unsafeZones: unsafeZones,
                guardianId: guardianId
            )
        }
    }

    // MARK: - Evaluate Position
    private func evaluatePosition(
        childId: String,
        childName: String,
        current: CLLocationCoordinate2D,
        safeZones: [CustomZone],
        unsafeZones: [CustomZone],
        guardianId: String
    ) {
        func zoneContaining(_ zones: [CustomZone]) -> CustomZone? {
            for zone in zones {
                let dist = distance(from: current, to: zone.coord)
                if dist <= zone.radius {
                    print("📏 \(childName) is \(Int(dist))m from \(zone.name) center (radius \(Int(zone.radius))) ✅")
                    return zone
                }
            }
            return nil
        }

        if let zone = zoneContaining(unsafeZones) {
            triggerAlertIfNeeded(
                childId: childId,
                title: "🚨 Unsafe Zone Alert",
                message: "\(childName) entered unsafe zone: \(zone.name)",
                color: "red",
                isSafeZone: false,
                guardianId: guardianId
            )
        } else if zoneContaining(safeZones) == nil {
            triggerAlertIfNeeded(
                childId: childId,
                title: "⚠️ Safe Zone Exit",
                message: "\(childName) left safe zone.",
                color: "orange",
                isSafeZone: true,
                guardianId: guardianId
            )
        } else {
            alertMessage = "✅ \(childName) is in a safe area."
        }
    }

    // MARK: - Control Alert Frequency
    private func triggerAlertIfNeeded(
        childId: String,
        title: String,
        message: String,
        color: String,
        isSafeZone: Bool,
        guardianId: String
    ) {
        let now = Date()
        let lastTime = lastAlertTimes[childId]

        if let lastTime = lastTime, now.timeIntervalSince(lastTime) < 120 {
            print("⏱️ Skipping alert for \(childId).")
            return
        }

        lastAlertTimes[childId] = now
        sendAlert(
            title: title,
            message: message,
            color: color,
            isSafeZone: isSafeZone,
            guardianId: guardianId
        )
    }

    // MARK: - Send Notification + Firestore Save
    private func sendAlert(
        title: String,
        message: String,
        color: String,
        isSafeZone: Bool,
        guardianId: String
    ) {
        alertMessage = message
        print("🔔 ALERT:", message)

        NotificationManager.instance.scheduleNotification(
            title: title,
            body: message,
            soundName: "alert_sound.wav"
        )

        let notifData: [String: Any] = [
            "title": title,
            "body": message,
            "timestamp": Timestamp(date: Date()),
            "isSafeZone": isSafeZone,
            "event": "zone_alert",
            "color": color
        ]

        db.collection("guardians")
            .document(guardianId)
            .collection("notifications")
            .addDocument(data: notifData) { error in
                if let error = error {
                    print("❌ Failed to store notification:", error.localizedDescription)
                } else {
                    print("✅ Notification stored successfully with color \(color).")
                }
            }
    }

    // MARK: - Distance Helper
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }
}
