// EDIT BY RIYAM:
// - Removed Regenerate Button.
// - Forces new PIN generation on Appear.
// - Implemented specific Admin/ChildName logic based on empty list check.
// - EDIT BY RIYAM: Added Admin Approval logic. Sends 'adminId' and 'adminChildId' to API.
// - Handles 'waiting_for_approval' and 'rejected' statuses.
// - Fixed variable name error (childName -> incomingChildName).
// - UPDATED: Auto-dismiss view on rejection after 3 seconds.

import SwiftUI

struct PairingView: View {
    @StateObject private var state = PairingState.shared
    @State private var showSuccess = false
    @State private var pollingTimer: Timer?
    @Environment(\.dismiss) var dismiss
    
    // EDIT BY RIYAM: State for feedback message (waiting/rejected)
    @State private var statusMessage: String = "Enter this code on your iPhone"
    @State private var statusColor: Color = .gray

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                        .padding(.bottom, 5)
                    
                    Text("Linked Successfully")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                } else {
                    Text("Pair Code")
                        .font(.headline)
                    
                    Text(state.pin)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .padding(.vertical, 15)
                        .foregroundColor(Color("Blue"))
                    
                    // EDIT BY RIYAM: Use dynamic status message and color
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                        .multilineTextAlignment(.center)
                    
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.top, 10)
                }
            }
            .padding()
            .onAppear {
                // Force generate a new random code every time this view appears
                state.generatePin()
                startPolling()
            }
            .onDisappear {
                stopPolling()
            }
            .onChange(of: showSuccess) { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startPolling() {
        stopPolling()
        print("📡 Starting API polling for PIN: \(state.pin)")
        // Reset message
        statusMessage = "Enter this code on your iPhone"
        statusColor = .gray
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            checkPairingStatus()
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func checkPairingStatus() {
        guard let url = URL(string: API.checkPairingCode) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // EDIT BY RIYAM: Find Admin ID and Admin Child ID to send to API
        var body: [String: Any] = ["pin": state.pin]
        
        if !state.linkedGuardianIDs.isEmpty {
            // Find the admin ID from the map
            var adminId: String?
            if let id = state.guardianAdmins.first(where: { $0.value == true })?.key {
                adminId = id
            } else if let firstId = state.linkedGuardianIDs.first {
                // Fallback to first guardian if no explicit admin set
                adminId = firstId
            }
            
            if let adminId = adminId {
                body["adminId"] = adminId
                // Pass the child ID associated with this admin
                if let childId = state.guardianChildIDs[adminId] {
                     body["adminChildId"] = childId
                }
            }
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    
                    // EDIT BY RIYAM: Handle various statuses
                    DispatchQueue.main.async {
                        if status == "linked" {
                            print("✅ API Pairing verified: \(json)")
                            stopPolling()
                            
                            let guardianId = json["guardianId"] as? String ?? ""
                            let childId = json["childId"] as? String ?? ""
                            let incomingChildName = json["childName"] as? String ?? ""
                            let parentName = json["parentName"] as? String ?? ""
                            
                            // Always update current IDs for context
                            UserDefaults.standard.set(guardianId, forKey: "guardianId")
                            UserDefaults.standard.set(childId, forKey: "currentChildId")
                            
                            // Logic Implementation
                            // Check if this is the first guardian (list is empty)
                            let isFirstGuardian = state.linkedGuardianIDs.isEmpty
                            let isAdmin: Bool
                            
                            if isFirstGuardian {
                                // If list is empty -> Make Admin, Update Child Name
                                isAdmin = true
                                state.childName = incomingChildName
                                if !incomingChildName.isEmpty {
                                    UserDefaults.standard.set(incomingChildName, forKey: "childDisplayName")
                                }
                                print("👑 First Guardian paired. Set as Admin. Child Name updated to: \(incomingChildName)")
                            } else {
                                // If list is NOT empty -> Not Admin, Ignore Child Name update
                                isAdmin = false
                                print("👥 Subsequent guardian paired. Not Admin. Keeping existing Child Name: \(state.childName)")
                            }
                            
                            // Add guardian with the calculated admin status
                            state.addGuardian(id: guardianId, name: parentName, childId: childId, isAdmin: isAdmin)
                            
                            withAnimation {
                                showSuccess = true
                            }
                        } else if status == "waiting_for_approval" {
                            // Show waiting text
                            self.statusMessage = "Waiting for Admin Approval..."
                            self.statusColor = .orange
                        } else if status == "rejected" {
                            // ❌ Show rejected text and STOP POLLING
                            stopPolling()
                            self.statusMessage = "Connection Denied by Admin."
                            self.statusColor = .red
                            
                            // ✅ NEW: Dismiss View after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                dismiss()
                            }
                        }
                    }
                }
            } catch {
                print("⚠️ API Parsing error: \(error)")
            }
        }.resume()
    }
}
