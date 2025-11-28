//
//  SOSAlertManager.swift
//  AtSight
//
//  This file creates a global alert manager to listen for and display SOS alerts
//  over any view in the app.
//
//  RESTARTED FROM SCRATCH - Nov 9, 2025
//  - Added logic to ignore "missed" alerts on launch.
//  - Added repeating haptic vibration that stops on dismiss.
//
//  EDIT BY RIYAM: Updated SOSAlert model and SOSAlertView to include Halt button logic
//  and integrate with HaltManager to send a HALT signal back to the child's watch.
//  (V2: Added static shared singleton)
//  (V3: Updated parsing logic to fetch childName/childId from Firestore data)
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import AVFoundation

// MARK: - SOS Alert Model

/// This model represents a new SOS alert document from Firestore.
struct SOSAlert: Identifiable {
    let id: String
    let title: String
    let body: String
    let timestamp: Timestamp
    // ADDED FOR HALT FEATURE
    let childId: String
    let childName: String
}

// MARK: - SOS Alert Manager

/// This manager object lives at the root of the app and listens for new SOS alerts.
@MainActor
class SOSAlertManager: ObservableObject {
    
    static let shared = SOSAlertManager()
    
    // Published properties to control the alert view
    @Published var isShowingAlert: Bool = false
    @Published var currentAlert: SOSAlert?
    
    private var listener: ListenerRegistration?
    
    // Tracks the timestamp of the *last notification we've processed*.
    private var lastProcessedTimestamp: Timestamp
    
    // ✨ 1. Flag to ignore the first batch of results on launch
    private var hasProcessedInitialFetch: Bool = false
    
    // ✨ 2. Properties for sound and vibration
    private var soundPlayer: AVAudioPlayer?
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var vibrationTimer: Timer?

    private init() {
        // We load the last seen timestamp from disk.
        let lastSeconds = UserDefaults.standard.double(forKey: "lastShownSOSTimestamp")
        if lastSeconds > 0 {
            self.lastProcessedTimestamp = Timestamp(seconds: Int64(lastSeconds), nanoseconds: 0)
        } else {
            // First install: set timestamp to now to ignore *all* past alerts.
            self.lastProcessedTimestamp = Timestamp()
        }
        
        print("SOS Manager: Initialized. Will only process alerts newer than \(self.lastProcessedTimestamp.dateValue().description).")
    }

    /// Attaches a snapshot listener to the 'notifications' collection in Firestore.
    func startListeningForSOS() {
        guard let guardianID = Auth.auth().currentUser?.uid else {
            print("SOS Manager: No guardian ID, cannot start listener.")
            return
        }
        
        stopListening()
        
        let db = Firestore.firestore()
        
        // Query: Get all new notifications newer than the last one we've processed.
        let query = db.collection("guardians")
            .document(guardianID)
            .collection("notifications")
            .whereField("timestamp", isGreaterThan: self.lastProcessedTimestamp)
            .order(by: "timestamp", descending: true)
        
        print("SOS Manager: Starting listener for all alerts newer than \(self.lastProcessedTimestamp.dateValue())...")

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("SOS Manager: Error listening for alerts: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else { return }

            // ✨ 3. HANDLE INITIAL FETCH
            if !self.hasProcessedInitialFetch {
                self.hasProcessedInitialFetch = true
                
                // Find the newest "missed" alert (if any) and set it as the baseline.
                if let newestDocument = snapshot.documents.first {
                    let newTimestamp = newestDocument.data()["timestamp"] as? Timestamp ?? self.lastProcessedTimestamp
                    if newTimestamp.seconds > self.lastProcessedTimestamp.seconds {
                        self.lastProcessedTimestamp = newTimestamp
                        UserDefaults.standard.set(Double(newTimestamp.seconds), forKey: "lastShownSOSTimestamp")
                        print("SOS Manager: Initial baseline set to \(newTimestamp.dateValue().description). Ignoring all alerts up to this time.")
                    }
                }
                return // IMPORTANT: Do not process alerts on the first fetch.
            }

            // ✨ 4. HANDLE *NEW* ALERTS
            let newDocuments = snapshot.documentChanges
                .filter { $0.type == .added }
                .map { $0.document }
                .sorted(by: {
                    ($0["timestamp"] as? Timestamp ?? Timestamp())
                        .seconds > ($1["timestamp"] as? Timestamp ?? Timestamp()).seconds
                })
            
            if newDocuments.isEmpty { return }

            // Get the newest document that was just added
            guard let newestDocument = newDocuments.first else { return }
            
            let data = newestDocument.data()
            let newTimestamp = data["timestamp"] as? Timestamp ?? Timestamp()
            
            // Update our timestamp to this new event so we never process it again.
            self.lastProcessedTimestamp = newTimestamp
            
            // ✨ 5. CHECK FOR SOS:
            if data["event"] as? String == "sos_alert" {
                
                // ✅ FIX: Retrieve the real child name from the notification document
                // If the cloud function hasn't been updated yet, these might be nil, so we keep the fallback.
                let childId = data["childId"] as? String ?? UserDefaults.standard.string(forKey: "lastLinkedChildId") ?? "unknown"
                let childName = data["childName"] as? String ?? UserDefaults.standard.string(forKey: "childDisplayName") ?? "Child"
                
                print("SOS Manager: New SOS alert received! ID: \(newestDocument.documentID) from \(childName)")

                let alert = SOSAlert(
                    id: newestDocument.documentID,
                    title: data["title"] as? String ?? "SOS Alert",
                    body: data["body"] as? String ?? "An SOS has been triggered!",
                    timestamp: newTimestamp,
                    childId: childId,
                    childName: childName
                )
                
                self.currentAlert = alert
                self.isShowingAlert = true
                
                // Play sound
                self.soundPlayer?.stop()
                self.soundPlayer = SoundPlayer.shared.playSound(named: "sos_sound")
                
                // ✨ 6. Start vibrations
                self.feedbackGenerator.prepare()
                self.startVibrations()
                
            } else {
                print("SOS Manager: New non-SOS notification received. Ignoring pop-up.")
            }
        }
    }
    
    /// Starts a repeating timer to trigger haptic feedback.
    private func startVibrations() {
        // Stop any old timer
        vibrationTimer?.invalidate()
        
        // Trigger the first vibration immediately
        self.feedbackGenerator.notificationOccurred(.error)
        
        // Start a timer to vibrate every 1 second
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.feedbackGenerator.notificationOccurred(.error)
        }
    }
    
    /// Removes the Firestore listener.
    func stopListening() {
        listener?.remove()
        listener = nil
        print("SOS Manager: Stopped listener.")
    }
    
    /// Dismisses the current alert.
    func dismissAlert() {
        isShowingAlert = false
        currentAlert = nil
        
        // ✨ 7. Stop sound and vibrations
        soundPlayer?.stop()
        soundPlayer = nil
        
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        
        // Save the timestamp of the alert we just dismissed.
        // This prevents it from re-appearing when the app next launches.
        UserDefaults.standard.set(Double(self.lastProcessedTimestamp.seconds), forKey: "lastShownSOSTimestamp")
        print("SOS Manager: Alert dismissed. Saved last timestamp: \(self.lastProcessedTimestamp.dateValue())")
    }
}

// MARK: - SOS Alert View

/// The SwiftUI View for the SOS pop-up.
struct SOSAlertView: View {
    
    @Binding var isShowing: Bool
    let alert: SOSAlert
    @State private var isSendingHalt = false
    @State private var haltAlertMessage: String?
    @State private var haltAlertTitle: String = ""

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            // Alert content
            VStack(spacing: 20) {
                // Icon and Title
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color("ColorRed"))
                
                Text(alert.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color("BlackFont"))
                
                Text(alert.body)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Buttons
                VStack(spacing: 12) {
                    // HALT Button
                    Button(action: {
                        isSendingHalt = true
                        
                        HaltManager.shared.sendHaltSignal(childId: alert.childId, childName: alert.childName) { success, message in
                            isSendingHalt = false
                            if success {
                                SOSAlertManager.shared.dismissAlert()
                            }
                            self.haltAlertTitle = success ? "HALT Sent!" : "HALT Failed"
                            self.haltAlertMessage = message
                        }
                    }) {
                        ZStack {
                            if isSendingHalt {
                                ProgressView().tint(.white)
                            } else {
                                Text("Halt")
                            }
                        }
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSendingHalt ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isSendingHalt)
                    
                    // Close Button
                    Button(action: {
                        SOSAlertManager.shared.dismissAlert()
                    }) {
                        Text("Close")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Color("ColorRed"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("ColorGray"), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(30)
            .background(Color("BgColor"))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            .padding(30)
            .transition(.scale.combined(with: .opacity))
            
            .alert(haltAlertTitle, isPresented: .constant(haltAlertMessage != nil)) {
                Button("OK") {
                    haltAlertMessage = nil
                }
            } message: {
                Text(haltAlertMessage ?? "")
            }
        }
    }
}
