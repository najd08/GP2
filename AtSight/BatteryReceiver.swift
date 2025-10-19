//
//  BatteryReceiver.swift
//  AtSight
//
//  Created by Najd Alsabi on 07/09/2025.
//

import UIKit
import WatchConnectivity
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UserNotifications
import CoreLocation

/// The ONE iPhone-side WCSession delegate.
/// - Receives messages, userInfo, applicationContext, files
/// - Sends link / generic messages
/// - Pushes lowBatteryThreshold via Application Context
final class BatteryReceiver: NSObject, WCSessionDelegate {
    static let shared = BatteryReceiver()                // keep alive for app lifetime
    private let session = WCSession.default

    // MARK: - Init / Activate
    override private init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self                      // ✅ Single delegate
            session.activate()
            print("📡 WC(iOS) BatteryReceiver activated()")
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
            if let err = err { print("🔔 Notification permission error:", err.localizedDescription) }
            else { print("🔔 Notifications allowed?", granted) }
        }
    }

    // MARK: - Public send helpers (used by UI / other classes)
    /// Send 6-digit PIN to Watch and expect a reply.
    func sendLink(pin: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let payload: [String: Any] = ["type": "link", "pin": pin]
        sendMessage(payload, expectReply: true, completion: completion)
    }

    /// Generic message sender (sendMessage). Falls back error if not reachable.
    func sendMessage(_ message: [String: Any],
                     expectReply: Bool,
                     completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard session.activationState == .activated else {
            completion(.failure(NSError(domain: "WCSession", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Session not activated"])))
            return
        }
        guard session.isReachable else {
            completion(.failure(NSError(domain: "WCSession", code: -2,
                                        userInfo: [NSLocalizedDescriptionKey: "Watch not reachable"])))
            return
        }

        if expectReply {
            session.sendMessage(message, replyHandler: { reply in
                completion(.success(reply))
            }, errorHandler: { error in
                completion(.failure(error))
            })
        } else {
            session.sendMessage(message, replyHandler: nil) { error in
                completion(.failure(error))
            }
        }
    }

    /// Push threshold to Watch via Application Context (reliable async sync).
    func pushThresholdToWatch(_ value: Int) {
        do {
            print("📤 Pushing lowBatteryThreshold to Watch:", value)
            try session.updateApplicationContext(["lowBatteryThreshold": value])
            UserDefaults.standard.set(value, forKey: "lowBatteryThreshold_last")
        } catch {
            print("⚠️ Failed to update app context:", error.localizedDescription)
        }
    }

    // MARK: - Foreground delivery (sendMessage)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📩 didReceiveMessage:", message)
        handleIncoming(message)
    }

    // MARK: - Background delivery (transferUserInfo)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("📦 didReceiveUserInfo:", userInfo)
        handleIncoming(userInfo)
    }

    // MARK: - Application Context (from Watch if you ever send back)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📥 iOS got applicationContext:", applicationContext)
        // (Currently we only push threshold iPhone -> Watch.)
    }

    // MARK: - Unified handler (lowBattery + watch_location + heartRate + watch_removed)
    private func handleIncoming(_ dict: [String: Any]) {
        guard let type = dict["type"] as? String else { return }

        switch type {
        case "lowBattery":
            handleLowBatteryPayload(dict)

        case "heart_rate":
            handleHeartRatePayload(dict)

        case "watch_removed":
            handleWatchRemovedPayload(dict)

        case "heartRate":
            handleHeartRatePayload(dict) // ✅ kept your old case for backward compatibility

        case "watch_location":
            // 🔎 Log raw payload for debugging
            print("🗺️ raw watch_location:", dict)

            // Extract values (accept either [lat,lon] or lat/lon keys if you later add both)
            let lat  = dict["lat"] as? CLLocationDegrees
            let lon  = dict["lon"] as? CLLocationDegrees
            let acc  = dict["acc"] as? CLLocationAccuracy
            let ts   = dict["ts"]  as? TimeInterval
            let childId = (dict["childId"] as? String)
                ?? UserDefaults.standard.string(forKey: "lastLinkedChildId")

            print("📥 iPhone got watch_location childId=\(childId ?? "nil") lat=\(lat ?? .nan) lon=\(lon ?? .nan) acc=\(acc ?? .nan) ts=\(ts ?? .nan)")

            // Keep your local save (if you rely on it elsewhere)
            LocationStore.saveFirstFix(childId: childId, lat: lat, lon: lon, acc: acc, ts: ts)

            // ✅ ALSO save to Firestore so ChildLocationView can load it
            guard let guardianID = Auth.auth().currentUser?.uid else {
                print("⚠️ Skipping Firestore save (no guardian logged in).")
                return
            }
            guard let cid = childId, let lt = lat, let ln = lon, let ts = ts else {
                print("⚠️ Skipping Firestore save (missing childId/coords/ts).")
                return
            }

            let db = Firestore.firestore()
            let liveDoc: [String: Any] = [
                "coordinate": [lt, ln],
                "accuracy": acc ?? 0,
                "timestamp": Timestamp(seconds: Int64(ts), nanoseconds: 0)
            ]

            db.collection("guardians")
                .document(guardianID)
                .collection("children")
                .document(cid)
                .collection("liveLocation")
                .addDocument(data: liveDoc) { e in
                    if let e = e {
                        print("❌ Firestore save error (liveLocation):", e.localizedDescription)
                    } else {
                        print("✅ Live location saved to Firestore for childId:", cid)
                    }
                }

        default:
            print("ℹ️ Unhandled WC type:", type)
        }
    }

    // MARK: - Common low-battery handler
    private func handleLowBatteryPayload(_ dict: [String: Any]) {
        guard
            let type = dict["type"] as? String, type == "lowBattery",
            let level = dict["batteryLevel"] as? Int
        else { return }

        let childName = (dict["childName"] as? String) ?? "Your child"
        print("✅ Low battery for \(childName) at \(level)%")
        saveLowBatteryNotification(level: level, childName: childName)
        triggerLocalNotification(level: level, childName: childName)
    }

    // MARK: - Firestore save (battery notification)
    private func saveLowBatteryNotification(level: Int, childName: String) {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "title": "Low Battery Alert",
            "body": "\(childName)’s watch battery is at \(level)% ",
            "timestamp": Timestamp(date: Date()),
            "isSafeZone": false,
            "type": "battery"
        ]
        db.collection("guardians")
            .document(guardianID)
            .collection("notifications")
            .document("\(childName)_battery")
            .setData(data, merge: true) { error in
                if let error = error {
                    print("❌ Firestore save error (battery):", error.localizedDescription)
                } else {
                    print("💾 Battery notification saved/updated")
                }
            }
    }

    // MARK: - Local notification
    private func triggerLocalNotification(level: Int, childName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Low Battery Alert"
        content.body = "\(childName)’s watch battery is at \(level)% ⚠️"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { err in
            if let err = err { print("❌ Local notification error:", err.localizedDescription) }
            else { print("🔔 Local notification triggered") }
        }
    }

    // MARK: - 🔥 Heart Rate / Watch Removal Handler
    private func handleHeartRatePayload(_ dict: [String: Any]) {
        guard let bpm = dict["bpm"] as? Double,
              let childName = dict["childName"] as? String,
              let childId = dict["childId"] as? String else { return }

        print("❤️ Received heartRate:", bpm, "from", childName)

        // 1. Store timestamp
        let now = Date()
        UserDefaults.standard.set(now, forKey: "lastHeartRateTime_\(childId)")

        // 2. Save to Firestore
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let doc: [String: Any] = [
            "bpm": bpm,
            "timestamp": Timestamp(date: Date())
        ]
        db.collection("guardians")
            .document(guardianID)
            .collection("children")
            .document(childId)
            .collection("heartRate")
            .addDocument(data: doc) { e in
                if let e = e {
                    print("❌ Firestore error (heart rate):", e.localizedDescription)
                } else {
                    print("✅ Heart rate saved for", childName)
                }
            }

        // 3. If bpm < 20 → possible watch removal
        if bpm < 20 {
            triggerWatchRemovedNotification(childName: childName)
            saveWatchRemovedNotification(childName: childName)
        }
    }

    // MARK: - Handle explicit “watch removed” payload
    private func handleWatchRemovedPayload(_ dict: [String: Any]) {
        guard
            let childName = dict["childName"] as? String,
            let childId = dict["childId"] as? String
        else { return }

        print("🚨 Watch removed payload received for", childName)

        triggerWatchRemovedNotification(childName: childName)
        saveWatchRemovedNotification(childName: childName)
    }

    // MARK: - Firestore save (watch removed)
    private func saveWatchRemovedNotification(childName: String) {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "title": "Watch Removed",
            "body": "\(childName)’s watch may have been removed.",
            "timestamp": Timestamp(date: Date()),
            "isSafeZone": false,
            "type": "watch_removed"
        ]
        db.collection("guardians")
            .document(guardianID)
            .collection("notifications")
            .document("\(childName)_watchRemoved")
            .setData(data, merge: true) { error in
                if let error = error {
                    print("❌ Firestore save error (watch removed):", error.localizedDescription)
                } else {
                    print("💾 Watch removal notification saved/updated")
                }
            }
    }

    // MARK: - Local notification (watch removed)
    private func triggerWatchRemovedNotification(childName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Watch Removed"
        content.body = "\(childName)’s watch may have been removed. ⚠️"
        content.sound = .default
        content.categoryIdentifier = "WATCH_REMOVED_CATEGORY" // ✅ attach category so "OK" action shows

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { err in
            if let err = err {
                print("❌ Local notification error:", err.localizedDescription)
            } else {
                print("🔔 Watch removed local notification triggered")
            }
        }
    }

    // MARK: - Receive Voice File from Watch
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let tmpURL = file.fileURL
        let meta   = file.metadata ?? [:]

        let childId  = meta["childId"] as? String ?? "unknownChild"
        let duration = (meta["duration"] as? String).flatMap(Double.init) ?? 0
        let ts       = (meta["timestamp"] as? String).flatMap(Double.init) ?? Date().timeIntervalSince1970

        let fname = tmpURL.lastPathComponent
        let storagePath = "voiceMessages/\(childId)/\(fname)"
        let ref = Storage.storage().reference().child(storagePath)

        print("📥 Received file from watch:", fname, "meta:", meta)

        // 1) Upload to Storage
        ref.putFile(from: tmpURL, metadata: nil) { _, error in
            if let error = error { print("❌ Upload error:", error.localizedDescription); return }

            // 2) Get download URL
            ref.downloadURL { url, err in
                guard let url = url, err == nil else {
                    print("❌ DownloadURL error:", err?.localizedDescription ?? "unknown")
                    return
                }

                // 3) Write to Firestore
                let db = Firestore.firestore()
                let doc: [String: Any] = [
                    "type": "voice",
                    "childId": childId,
                    "sender": "watch",
                    "duration": duration,
                    "storagePath": storagePath,
                    "downloadURL": url.absoluteString,
                    "timestamp": Timestamp(seconds: Int64(ts), nanoseconds: 0)
                ]
                db.collection("messages").addDocument(data: doc) { e in
                    if let e = e { print("❌ Firestore error (voice):", e.localizedDescription) }
                    else { print("✅ Voice message saved:", storagePath) }
                }
            }
        }
    }

    // MARK: - Activation / reachability logs
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("iPhone WCSession activation state:", activationState.rawValue, "error:", String(describing: error))

        // Optional: re-push last threshold once session is active
        let last = UserDefaults.standard.integer(forKey: "lowBatteryThreshold_last")
        if last > 0 { pushThresholdToWatch(last) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) { print("iPhone WCSession didBecomeInactive") }
    func sessionDidDeactivate(_ session: WCSession) { print("iPhone WCSession didDeactivate"); session.activate() }
    func sessionReachabilityDidChange(_ session: WCSession) { print("iPhone reachable?", session.isReachable) }
}
