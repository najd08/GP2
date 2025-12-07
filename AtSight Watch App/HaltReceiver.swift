//
//  HaltReceiver.swift
//  AtSight
//
//
//  EDIT BY RIYAM: Implemented the HaltReceiver as a shared ObservableObject to poll the checkHaltStatus API,
//  manage the HALT popup state, the 15-second dismissal timer, and the repeating haptics.
//  (V4: Increased haptic frequency from 2.0s to 0.75s for more intense vibration.)
//

import Foundation
import WatchKit
import Combine // Required for ObservableObject

final class HaltReceiver: NSObject, ObservableObject { // ✅ Made ObservableObject
    
    static let shared = HaltReceiver()
    
    // MARK: - State & Management
    @Published var isHaltActive: Bool = false // ✅ Triggers the UI overlay
    @Published var canDismiss: Bool = false    // ✅ Enables the close button
    
    private var pollingTimer: Timer?
    private var countdownTimer: Timer?
    private var hapticTimer: Timer? // ✅ For repeating haptics

    // Stores the timestamp (as TimeInterval) of the last alert we've seen
        private var lastSeenAlertTs: TimeInterval {
            get {
                UserDefaults.standard.double(forKey: "lastSeenHaltTs")
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "lastSeenHaltTs")
            }
        }
        
        private override init() {
            super.init()
            // ✅ FIX: If this is the first run, set baseline to NOW.
            // This ignores any old alerts sitting in Firestore.
            if UserDefaults.standard.object(forKey: "lastSeenHaltTs") == nil {
                let now = Date().timeIntervalSince1970
                UserDefaults.standard.set(now, forKey: "lastSeenHaltTs")
                print("🛑 [HaltReceiver] First run detected. Baseline set to: \(now)")
            }
        }
    
    // MARK: - API Polling
    
    /**
     * Starts a timer that polls the `checkHaltStatus` API every 5 seconds.
     */
    func startListening() {
        stopListening() // Ensure no other timer is running
        
        // Start a new polling timer
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForHaltSignal()
        }
        
        print("🛑 [HaltReceiver] Started polling for HALT signals.")
    }
    
    /**
     * Stops the polling timer.
     */
    func stopListening() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("🛑 [HaltReceiver] Stopped polling for HALT signals.")
    }
    
    /**
         * Iterates through all linked guardians and checks for HALT signals from each.
         */
        private func checkForHaltSignal() {
            // Access PairingState on the Main Actor to get the list of all guardians
            Task { @MainActor in
                let guardians = PairingState.shared.linkedGuardianIDs
                let childMap = PairingState.shared.guardianChildIDs
                
                if guardians.isEmpty {
                    print("🛑 [HaltReceiver] No linked guardians to poll.")
                    return
                }
                
                // Loop through EVERY guardian, not just the first one
                for guardianId in guardians {
                    // Get the child ID specifically for this guardian relation
                    if let childId = childMap[guardianId] {
                        // Check status for this specific guardian-child pair
                        self.checkHaltStatusFor(guardianId: guardianId, childId: childId)
                    }
                }
            }
        }

        /**
         * Performs the GET request for a specific guardian/child pair.
         */
        private func checkHaltStatusFor(guardianId: String, childId: String) {
            guard var components = URLComponents(string: API.checkHaltStatus) else { return }
            
            components.queryItems = [
                URLQueryItem(name: "guardianId", value: guardianId),
                URLQueryItem(name: "childId", value: childId),
                URLQueryItem(name: "lastSeenTs", value: String(lastSeenAlertTs))
            ]
            
            guard let url = components.url else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            // print("📡 Checking HALT for guardian: \(guardianId)") // Optional debug log
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if error != nil { return }
                guard let data = data else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        if let status = json["status"] as? String, status == "found",
                           let alert = json["alert"] as? [String: Any],
                           let newTs = alert["ts"] as? TimeInterval {
                            
                            // Check timestamp logic
                            if newTs > self.lastSeenAlertTs {
                                print("🚨 [HaltReceiver] HALT SIGNAL DETECTED from guardian: \(guardianId)!")
                                self.lastSeenAlertTs = newTs
                                
                                DispatchQueue.main.async {
                                    self.triggerHaltSignal()
                                }
                            }
                        }
                    }
                } catch {
                    print("❌ [HaltReceiver] JSON parsing error for \(guardianId)")
                }
            }.resume()
        }
    
    // MARK: - UI State & Haptic Management
    
    /**
     * Called when a new HALT signal is detected. Starts the countdown and haptics.
     */
    func triggerHaltSignal() {
        self.isHaltActive = true
        self.canDismiss = false
        print("🚨 [HaltReceiver] HALT is ACTIVE. Starting countdown...")
        self.startHaptics()
        self.startHaltCountdown()
    }
    
    /**
     * Stops the haptics and allows the user to dismiss the overlay.
     */
    func dismissHalt() {
        self.isHaltActive = false
        self.canDismiss = false
        self.stopHaptics()
        self.countdownTimer?.invalidate()
        print("✅ [HaltReceiver] HALT signal DISMISSED.")
    }
    
    /**
     * Starts the 15-second timer until the popup can be dismissed.
     */
    private func startHaltCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("🛑 [HaltReceiver] 15 seconds elapsed. Can now dismiss.")
            
            DispatchQueue.main.async {
                self.canDismiss = true
                self.stopHaptics()
                WKInterfaceDevice.current().play(.success) // Final confirmation haptic
            }
        }
    }
    
    /**
     * Starts a repeating haptic buzz.
     */
    private func startHaptics() {
        hapticTimer?.invalidate()
        WKInterfaceDevice.current().play(.failure) // Play one immediately
        
        // 🚨 EDIT: Increased frequency for "violent" effect (V4)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { _ in
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    /**
     * Stops the repeating haptic buzz.
     */
    private func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}
