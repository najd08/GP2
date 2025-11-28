//
//  HaltManager.swift
//  AtSight
//
//  This file contains the client-side logic for the parent
//  to send a "Halt" signal to a child's watch.
//
//  EDIT BY RIYAM: Added the sendHaltSignal function to call the new triggerHalt cloud function via APIHelper.
//

import Foundation
import FirebaseAuth

class HaltManager {
    
    static let shared = HaltManager()
    
    /**
     * Calls the 'triggerHalt' cloud function.
     * This function sends the guardian's and child's IDs to Firestore,
     * creating a new 'halt_alert' notification.
     */
    func sendHaltSignal(childId: String, childName: String, completion: @escaping (Bool, String) -> Void) {
        
        // 1. Get the current guardian's ID
        guard let guardianId = Auth.auth().currentUser?.uid else {
            print("🛑 [HaltManager] Error: No guardian is logged in.")
            completion(false, "You are not logged in.")
            return
        }
        
        print("🚦 [HaltManager] Attempting to send HALT signal for child: \(childId) (Name: \(childName)) from guardian: \(guardianId)")

        // 2. Prepare the payload for the cloud function
        let payload: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "childName": childName,
            "ts": Date().timeIntervalSince1970
        ]
        
        // 3. Use the APIHelper to send the POST request
        APIHelper.shared.post(to: API.triggerHalt, body: payload) { success, error in
            if success {
                print("✅ [HaltManager] Successfully sent HALT signal.")
                completion(true, "HALT signal sent successfully.")
            } else {
                let errorMessage = error?.localizedDescription ?? "An unknown error occurred."
                print("❌ [HaltManager] Failed to send HALT signal: \(errorMessage)")
                completion(false, errorMessage)
            }
        }
    }
}
