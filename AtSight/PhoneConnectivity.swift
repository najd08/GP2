//
//  PhoneConnectivity.swift
//  AtSight
//
//  Created by Leena on 07/09/2025.
//

import Foundation
import WatchConnectivity
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

/// PhoneConnectivity (MERGED)
/// - Backward compatible facade **and** full WCSessionDelegate implementation.
/// - Default behavior matches the lightweight facade (delegated to BatteryReceiver).
/// - You can switch to owning the WCSession delegate by calling activate(.phoneConnectivity).
final class PhoneConnectivity: NSObject {
    static let shared = PhoneConnectivity()
    private override init() { super.init() }
    
    // Ownership mode
    enum OwnershipMode {
        case batteryReceiver
        case phoneConnectivity
    }
    
    private(set) var mode: OwnershipMode = .batteryReceiver
}

// MARK: - Public API
extension PhoneConnectivity {
    
    /// Backward-compatible activate(): delegates to BatteryReceiver by default
    func activate() {
        activate(.batteryReceiver)
    }
    
    /// Explicitly choose who owns WCSession delegate
    func activate(_ ownership: OwnershipMode) {
        mode = ownership
        switch ownership {
        case .batteryReceiver:
            // Do nothing; ensure BatteryReceiver exists and owns the session
            print("📡 PhoneConnectivity.activate(.batteryReceiver) — facade mode. BatteryReceiver owns WCSession.")
            _ = BatteryReceiver.shared
            
        case .phoneConnectivity:
            guard WCSession.isSupported() else {
                print("WC not supported on this device")
                return
            }
            let s = WCSession.default
            s.delegate = self
            s.activate()
            print("📡 WC(iOS) activate() — PhoneConnectivity owns WCSession delegate")
        }
    }
    
    /// Send a pairing/link PIN (reply expected by default)
    func sendLink(pin: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        // ✅ Get guardian ID from Firebase Auth (the current parent)
        let guardianId = Auth.auth().currentUser?.uid ?? "unknownGuardian"
        
        // يمكنك لاحقاً جلب childId و childName من الواجهة أو قاعدة البيانات
        let selectedChildId = UserDefaults.standard.string(forKey: "currentChildId") ?? ""
        let selectedChildName = UserDefaults.standard.string(forKey: "childDisplayName") ?? ""
        let parentName = Auth.auth().currentUser?.displayName ?? "Parent"
        
        // ✅ Build message payload to send to the watch
        let payload: [String: Any] = [
            "type": "link",
            "pin": pin,
            "guardianId": guardianId,
            "childId": selectedChildId,
            "childName": selectedChildName,
            "parentName": parentName
        ]
        
        print("📡 Sending link message to Watch:", payload)
        sendMessage(payload, expectReply: true, completion: completion)
    }

    /// Generic sender that either forwards to BatteryReceiver or uses WCSession directly
    func sendMessage(
        _ message: [String: Any],
        expectReply: Bool,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        switch mode {
        case .batteryReceiver:
            // Forward to BatteryReceiver to avoid breaking old call sites
            BatteryReceiver.shared.sendMessage(message, expectReply: expectReply, completion: completion)
            
        case .phoneConnectivity:
            let session = WCSession.default
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
                session.sendMessage(
                    message,
                    replyHandler: { reply in completion(.success(reply)) },
                    errorHandler: { error in completion(.failure(error)) }
                )
            } else {
                session.sendMessage(
                    message,
                    replyHandler: nil,
                    errorHandler: { error in completion(.failure(error)) }
                )
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension PhoneConnectivity: WCSessionDelegate {
    
    // Activation lifecycle
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let e = error {
            print("❌ WC(iOS) activation error:", e.localizedDescription)
        } else {
            print("✅ WC(iOS) activated:", activationState.rawValue)
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("iOS reachable?", session.isReachable)
    }
    
    // Receive message (no reply)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard mode == .phoneConnectivity else { return }
        print("iOS received message:", message)
        handle(message)
    }
    
    // Receive message (expects reply)
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        guard mode == .phoneConnectivity else { return }
        print("iOS received (needs reply):", message)
        handle(message)
        replyHandler(["status": "ok"])
    }
    
    // App context / user info
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard mode == .phoneConnectivity else { return }
        print("iOS got applicationContext:", applicationContext)
        handle(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard mode == .phoneConnectivity else { return }
        print("iOS got userInfo:", userInfo)
        handle(userInfo)
    }
    
    // Files (voice messages)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard mode == .phoneConnectivity else { return }
        
        let tmpURL = file.fileURL
        let meta = file.metadata ?? [:]
        let childId = meta["childId"] as? String ?? "unknownChild"
        let duration = (meta["duration"] as? String).flatMap(Double.init) ?? 0
        let ts = (meta["timestamp"] as? String).flatMap(Double.init) ?? Date().timeIntervalSince1970
        let fname = tmpURL.lastPathComponent
        let storagePath = "voiceMessages/\(childId)/\(fname)"
        let ref = Storage.storage().reference().child(storagePath)
        
        print("📥 Received file from watch:", fname, "meta:", meta)
        
        ref.putFile(from: tmpURL, metadata: nil) { meta, error in
            if let error = error {
                print("❌ Upload error:", error.localizedDescription)
                return
            }
            ref.downloadURL { url, err in
                guard let url = url, err == nil else {
                    print("❌ DownloadURL error:", err?.localizedDescription ?? "unknown")
                    return
                }
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
                    if let e = e {
                        print("❌ Firestore error:", e.localizedDescription)
                    } else {
                        print("✅ Voice message saved:", storagePath)
                    }
                }
            }
        }
    }
}

// MARK: - Internal helpers
private extension PhoneConnectivity {
    func handle(_ dict: [String: Any]) {
        guard mode == .phoneConnectivity else { return }
        guard let type = dict["type"] as? String else { return }
        
        switch type {
        case "watch_location":
            let lat = dict["lat"] as? CLLocationDegrees
            let lon = dict["lon"] as? CLLocationDegrees
            let acc = dict["acc"] as? CLLocationAccuracy
            let ts = dict["ts"] as? TimeInterval
            let childId = dict["childId"] as? String
            
            print("📍 iPhone received watch_location:",
                  lat ?? .nan, lon ?? .nan, acc ?? .nan, ts ?? .nan,
                  "childId:", childId ?? "-")
            
            // Uses separate LocationStore.swift util (kept same call)
            LocationStore.saveFirstFix(childId: childId,
                                       lat: lat,
                                       lon: lon,
                                       acc: acc,
                                       ts: ts)
        default:
            break
        }
    }
}
