// EDIT BY RIYAM:
// - Added `guardianAdmins` to persist admin flags.
// - Updated addGuardian to handle isAdmin logic.
// - Updated removeGuardian to clean up admin data.
// - ADDED: syncGuardiansToCloud() to push the list to Firestore via API.

import Foundation
import Combine

@MainActor
final class PairingState: ObservableObject {
    static let shared = PairingState()

    @Published var pin: String = ""
    @Published var linked = false
    @Published var childName: String = ""
    
    // ✅ Store names for each guardian ID
    @Published var guardianNames: [String: String] = [:] {
        didSet {
            UserDefaults.standard.set(guardianNames, forKey: "guardianNames")
            UserDefaults.standard.synchronize()
        }
    }
    
    // ✅ Map Guardian ID -> Child ID
    @Published var guardianChildIDs: [String: String] = [:] {
        didSet {
            UserDefaults.standard.set(guardianChildIDs, forKey: "guardianChildIDs")
            UserDefaults.standard.synchronize()
        }
    }
    
    // ✅ Store Admin Status for each guardian ID
    @Published var guardianAdmins: [String: Bool] = [:] {
        didSet {
            UserDefaults.standard.set(guardianAdmins, forKey: "guardianAdmins")
            UserDefaults.standard.synchronize()
        }
    }
    
    // ✅ Track list of linked guardians
    @Published var linkedGuardianIDs: [String] = [] {
        didSet {
            UserDefaults.standard.set(linkedGuardianIDs, forKey: "linkedGuardianIDs")
            UserDefaults.standard.synchronize()
            linked = !linkedGuardianIDs.isEmpty
        }
    }
    
    @Published var lastPairingEvent: Date? = nil

    private init() {
        // Load saved data
        self.linkedGuardianIDs = UserDefaults.standard.array(forKey: "linkedGuardianIDs") as? [String] ?? []
        self.guardianNames = UserDefaults.standard.dictionary(forKey: "guardianNames") as? [String: String] ?? [:]
        self.guardianChildIDs = UserDefaults.standard.dictionary(forKey: "guardianChildIDs") as? [String: String] ?? [:]
        self.guardianAdmins = UserDefaults.standard.dictionary(forKey: "guardianAdmins") as? [String: Bool] ?? [:]
        
        self.linked = !linkedGuardianIDs.isEmpty
        self.childName = UserDefaults.standard.string(forKey: "childDisplayName") ?? ""
        
        generatePin()
    }

    func generatePin() {
        pin = String(format: "%06d", Int.random(in: 0..<1_000_000))
        print("🎲 Generated new pairing PIN: \(pin)")
    }
    
    func addGuardian(id: String, name: String, childId: String, isAdmin: Bool) {
        guard !id.isEmpty else { return }
        
        if !linkedGuardianIDs.contains(id) {
            linkedGuardianIDs.append(id)
        }
        // Update name and child ID mapping
        let safeName = name.isEmpty ? "Parent" : name
        guardianNames[id] = safeName
        
        if !childId.isEmpty {
            guardianChildIDs[id] = childId
        }
        
        // Save admin status
        guardianAdmins[id] = isAdmin
        
        print("➕ Guardian added: \(safeName) (\(id)). Admin: \(isAdmin).")
        lastPairingEvent = Date()
        
        // ✅ TRIGGER SYNC
        syncGuardiansToCloud()
    }
    
    func removeGuardian(_ id: String) {
        if let index = linkedGuardianIDs.firstIndex(of: id) {
            linkedGuardianIDs.remove(at: index)
            guardianNames.removeValue(forKey: id)
            guardianChildIDs.removeValue(forKey: id)
            guardianAdmins.removeValue(forKey: id)
            
            // Force save
            UserDefaults.standard.set(linkedGuardianIDs, forKey: "linkedGuardianIDs")
            UserDefaults.standard.set(guardianNames, forKey: "guardianNames")
            UserDefaults.standard.set(guardianChildIDs, forKey: "guardianChildIDs")
            UserDefaults.standard.set(guardianAdmins, forKey: "guardianAdmins")
            UserDefaults.standard.synchronize()
            
            print("➖ Guardian removed: \(id). Remaining: \(linkedGuardianIDs.count)")
            
            // ✅ TRIGGER SYNC (To remove this guardian from others' lists)
            syncGuardiansToCloud()
            
            if linkedGuardianIDs.isEmpty {
                childName = ""
                UserDefaults.standard.removeObject(forKey: "childDisplayName")
                generatePin()
            }
        }
    }
    
    // MARK: - API Sync Logic
    private func syncGuardiansToCloud() {
        // Construct payload of all current guardians
        var guardiansList: [[String: Any]] = []
        
        for id in linkedGuardianIDs {
            // We need the childId to know where to write in Firestore
            if let childId = guardianChildIDs[id] {
                let name = guardianNames[id] ?? "Unknown"
                let isAdmin = guardianAdmins[id] ?? false
                
                guardiansList.append([
                    "id": id,
                    "name": name,
                    "childId": childId,
                    "isAdmin": isAdmin
                ])
            }
        }
        
        guard !guardiansList.isEmpty else { return }
        
        let payload: [String: Any] = ["guardians": guardiansList]
        
        print("☁️ Syncing Authorized Guardians to Cloud: \(guardiansList.count) items")
        
        // Use APIHelper (assuming it is available in Watch target)
        // Note: APIHelper uses 'post(to:body:)'
        // We need to ensure API.syncAuthorizedGuardians is defined
        
        // Check if APIHelper handles errors internally or we just fire and forget
        if let url = URL(string: API.syncAuthorizedGuardians) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    print("❌ Sync failed: \(error.localizedDescription)")
                } else {
                    print("✅ Sync completed successfully.")
                }
            }.resume()
        }
    }
}
