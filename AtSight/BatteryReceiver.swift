//
//  BatteryReceiver.swift
//  AtSight Watch App
//
//  Created by Najd Alsabi on 10/10/2025.
//
//  EDIT BY RIYAM: Added Auth state listener to ensure we only listen for alerts AFTER login.
//  EDIT BY RIYAM: Fixed Timestamp initialization.
//  EDIT BY RIYAM: Added 'sendLowBatteryLocalNotification' with settings lookup.
//  Removed some parts of the code that required WCsession.
//

import UIKit
import WatchConnectivity
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UserNotifications
import CoreLocation

/// The ONE iPhone-side WCSession delegate.
final class BatteryReceiver: NSObject, WCSessionDelegate {
    static let shared = BatteryReceiver()                // keep alive for app lifetime
    private let session = WCSession.default
    
    // Listener for API-triggered alerts
    private var firestoreListener: ListenerRegistration?
    private var authListenerHandle: AuthStateDidChangeListenerHandle? // ✅ To track login state
    
    // Initialize with current date to ignore old alerts from the past
    private var lastProcessedTimestamp: Timestamp = Timestamp(date: Date())

    // MARK: - Init / Activate
    override private init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            print("📡 WC(iOS) BatteryReceiver activated()")
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
            if let err = err { print("🔔 Notification permission error:", err.localizedDescription) }
            else { print("🔔 Notifications allowed?", granted) }
        }
        
        // ✅ START WATCHING AUTH STATE
        // This ensures we start the Firestore listener only when a user is actually logged in.
        self.authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                print("👤 [BatteryReceiver] User logged in: \(user.uid). Starting alert listener.")
                self?.startListeningForCloudBatteryAlerts(guardianId: user.uid)
            } else {
                print("👤 [BatteryReceiver] User logged out. Stopping alert listener.")
                self?.stopListeningForAlerts()
            }
        }
    }
    
    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        stopListeningForAlerts()
    }
    
    // MARK: - Firestore Listener (Fix for API-only Watch)
    private func startListeningForCloudBatteryAlerts(guardianId: String) {
        // 1. Stop any existing listener to avoid duplicates
        stopListeningForAlerts()
        
        // 2. Reset the "last processed" time to NOW so we don't show old alerts
        self.lastProcessedTimestamp = Timestamp(date: Date())
        
        let db = Firestore.firestore()
        
        print("🎧 [BatteryReceiver] Listening for new battery alerts for guardian: \(guardianId)")
        
        // 3. Listen for new notifications
        firestoreListener = db.collection("guardians")
            .document(guardianId)
            .collection("notifications")
            .whereField("timestamp", isGreaterThan: lastProcessedTimestamp)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ [BatteryReceiver] Listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                for diff in snapshot.documentChanges {
                    if diff.type == .added {
                        let data = diff.document.data()
                        
                        // Update timestamp marker so we don't re-process if listener restarts
                        if let ts = data["timestamp"] as? Timestamp, ts.seconds > self.lastProcessedTimestamp.seconds {
                            self.lastProcessedTimestamp = ts
                        }
                        
                        // Check if this is a battery alert
                        if let event = data["event"] as? String, event == "battery_low" {
                            let childName = data["childName"] as? String ?? "Your Child"
                            let level = data["batteryLevel"] as? Int ?? 0
                            
                            print("🔋 [BatteryReceiver] Detected cloud alert for \(childName) at \(level)%")
                            
                            // Trigger the smart local notification logic
                            self.sendLowBatteryLocalNotification(guardianId: guardianId, childName: childName, level: level)
                        }
                    }
                }
            }
    }
    
    private func stopListeningForAlerts() {
        firestoreListener?.remove()
        firestoreListener = nil
    }

    // MARK: - Local Notification Logic (Corrected Lookup)
    private func sendLowBatteryLocalNotification(guardianId: String, childName: String, level: Int) {
        let title = "Low Battery Alert"
        let body = "\(childName)’s watch battery is at \(level)%!"
        
        // If name is missing, just send default immediately
        guard !childName.isEmpty else {
            NotificationManager.instance.scheduleNotification(title: title, body: body, soundName: "default_sound.wav")
            return
        }
        
        let db = Firestore.firestore()
        
        // 1. Find the Child ID in Admin's list by matching the NAME
        db.collection("guardians")
            .document(guardianId)
            .collection("children")
            .whereField("name", isEqualTo: childName)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                
                // If child not found or error, fallback to default sound
                guard let doc = snapshot?.documents.first else {
                    print("⚠️ [BatteryReceiver] Child not found by name: \(childName). Using default.")
                    NotificationManager.instance.scheduleNotification(title: title, body: body, soundName: "default_sound.wav")
                    return
                }
                
                let childId = doc.documentID
                print("✅ [BatteryReceiver] Found Child ID: \(childId) for name: \(childName)")
                
                // 2. Fetch Settings for THIS child
                db.collection("guardians")
                    .document(guardianId)
                    .collection("children")
                    .document(childId)
                    .collection("notifications")
                    .document("settings")
                    .getDocument { settingsSnap, _ in
                        
                        var soundFile = "default_sound"
                        var lowBatteryAlert = true // Default to ON
                        
                        if let settingsData = settingsSnap?.data() {
                            // A. Check Permission
                            if let enabled = settingsData["lowBatteryAlert"] as? Bool {
                                lowBatteryAlert = enabled
                            }
                            // B. Get Sound
                            if let customSound = settingsData["sound"] as? String, !customSound.isEmpty {
                                soundFile = customSound
                            }
                        }
                        
                        // 3. Check if Alert is Allowed
                        if lowBatteryAlert == false {
                            print("🚫 [BatteryReceiver] 'Low Battery' alert is DISABLED for \(childName).")
                            return
                        }
                        
                        // 4. Format and Play
                        if !soundFile.hasSuffix(".wav") {
                            soundFile += ".wav"
                        }
                        
                        print("🔔 [BatteryReceiver] Playing sound: \(soundFile)")
                        NotificationManager.instance.scheduleNotification(title: title, body: body, soundName: soundFile)
                    }
            }
    }

    // MARK: - Public send helpers
    func sendLink(pin: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let payload: [String: Any] = ["type": "link", "pin": pin]
        sendMessage(payload, expectReply: true, completion: completion)
    }

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

    func pushThresholdToWatch(_ value: Int) {
        do {
            print("📤 Pushing lowBatteryThreshold to Watch:", value)
            try session.updateApplicationContext(["lowBatteryThreshold": value])
            UserDefaults.standard.set(value, forKey: "lowBatteryThreshold_last")
        } catch {
            print("⚠️ Failed to update app context:", error.localizedDescription)
        }
    }

    // MARK: - WCSessionDelegate Stub Methods
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        print("iPhone WCSession activation state:", state.rawValue)
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    
    // Note: Incoming WCSession handling is removed/minimized since watch sends via API.
    // We keep the delegate methods to satisfy the protocol.
}
