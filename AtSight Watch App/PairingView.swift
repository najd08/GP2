
// EDIT BY RIYAM:
// - Removed Regenerate Button. (REVERTED: Regenerate button is now included below the PIN)
// - Forces new PIN generation on Appear.
// - Implemented specific Admin/ChildName logic based on empty list check.
// - EDIT BY RIYAM: Added Admin Approval logic. Sends 'adminId' and 'adminChildId' to API.
// - Handles 'waiting_for_approval' and 'rejected' statuses.
// - Fixed variable name error (childName -> incomingChildName).
// - UPDATED: Auto-dismiss view on rejection after 3 seconds.
// - NEW: Added QR Code fetching and display logic.

import SwiftUI
import UIKit // Needed for UIImage conversion in the helper struct

struct PairingView: View {
    @StateObject private var state = PairingState.shared
    @State private var showSuccess = false
    @State private var pollingTimer: Timer?
    @Environment(\.dismiss) var dismiss
    
    // EDIT BY RIYAM: State for feedback message (waiting/rejected)
    // NOTE: Initial value is the static instruction text.
    @State private var statusMessage: String = "Scan QR to connect"
    @State private var statusColor: Color = Color("Buttons") // ✅ Set initial color to "Buttons"

    var body: some View {
        NavigationStack {
            
            // ✅ WRAPPING CONTENT IN SCROLLVIEW
            ScrollView {
                // ⬇️ REDUCED SPACING ⬇️
                VStack(spacing: 5) {
                    if showSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                            .padding(.bottom, 5)
                        
                        Text("Linked Successfully")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                    } else {
                        
                        // ✅ Static Instruction Text (Now above QR, without the dynamic loading icon)
                        Text(statusMessage)
                            .font(.headline)
                            .foregroundColor(statusColor)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 5)
                        
                        // ✅ Display the QR code here (has built-in loading placeholder)
                        QRCodeImage(dataURL: state.qrCodeBase64)
                            .padding(.vertical, 5) // Reduced padding
                        Text("enter pin manually").foregroundColor(Color("button"))


                        Text(state.pin)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(Color("Blue"))
                            .padding(.bottom, 10) // Small spacing above status/button
                        
                        // ✅ MOVED: Dynamic Status/Loading Indicator (Below PIN)
                        HStack {
                            
                            // Show loading indicator when polling is active and NOT rejected/linked
                            if !showSuccess && statusColor != .red && statusColor != .white {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(statusColor)
                            }
                        }
                        // .padding(.top, 10) // Removed extra top padding on HStack
                        
                        // ✅ NEW: REGENERATE BUTTON (Updated Text & Style to remove gray tint)
                        Button(action: {
                            stopPolling()
                            state.generatePin() // Generates new PIN and clears QR state
                            fetchQRCode()     // Fetches new QR code
                            startPolling()    // Starts polling for the new PIN
                        }) {
                            Text("Regenerate Code") // ✅ Updated text
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 160, height: 35)
                                .background(Color("button"))
                                .cornerRadius(20)
                        }
                        // ✅ Added .plain to ensure no default system button styling or background tint is applied
                        .buttonStyle(.plain)
                        .padding(.top, 5) // Padding below the status area
                        
                    }
                }
                .padding() // Apply padding to the VStack inside the ScrollView
            }
            // End ScrollView
            .background(Color("BgColor").ignoresSafeArea()) // ✅ ADDED IGNORES SAFE AREA
            
            .onAppear {
                // Force generate a new random code every time this view appears
                state.generatePin()
                
                // ✅ Fetch the QR code for the new PIN
                fetchQRCode()
                
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
        }.background(Color("BgColor").ignoresSafeArea())   

    }
    
    // MARK: - QR Code Logic
    private func fetchQRCode() {
        // Use the endpoint defined in API.swift
        guard let url = URL(string: API.generateQR) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["pin": state.pin]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ QR API Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let qrString = json["qr"] as? String {
                    
                    // Assign the Base64 string to the published state property
                    DispatchQueue.main.async {
                        self.state.qrCodeBase64 = qrString
                        print("✅ QR Code data received and stored.")
                    }
                }
            } catch {
                print("⚠️ QR API Parsing error: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Polling Logic
    private func startPolling() {
        stopPolling()
        print("📡 Starting API polling for PIN: \(state.pin)")
        
        // Reset to initial state and color (Buttons)
        statusMessage = "Scan QR to connect"
        statusColor = Color("Buttons")
        
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

// MARK: - QR Code Image Helper
// Helper struct to handle Base64 decoding and display
struct QRCodeImage: View {
    let dataURL: String?
    
    var body: some View {
        Group {
            if let dataURL = dataURL,
               let image = imageFromBase64DataURL(dataURL) {
                
                // Display the UIImage wrapped in a SwiftUI Image view
                Image(uiImage: image)
                    .interpolation(.none) // Crucial for sharp QR code lines
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150) // Adjust size for watchOS screen
            } else {
                // Placeholder while the image is loading
                ProgressView()
                    .frame(width: 150, height: 150)
            }
        }
    }
    
    // Helper function to convert the full Data URL string into a UIImage
    private func imageFromBase64DataURL(_ dataURL: String) -> UIImage? {
        // Find the start of the Base64 data (after "base64,")
        guard let separatorRange = dataURL.range(of: "base64,"),
              let base64String = dataURL.split(separator: ",", maxSplits: 1).last else {
            print("Decoding Error: Could not find 'base64,' separator.")
            return nil
        }
        
        // Decode the Base64 string into raw Data
        guard let imageData = Data(base64Encoded: String(base64String), options: .ignoreUnknownCharacters) else {
            print("Decoding Error: Base64 string is invalid.")
            return nil
        }
        
        // Create a UIImage from the Data
        return UIImage(data: imageData)
    }
}
