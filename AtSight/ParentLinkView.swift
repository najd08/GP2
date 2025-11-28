//
//  ParentLinkView.swift
//  AtSight
//
//  Updated: Shows "Linked Successfully" screen on success.
//  Updated: Checks for invalid PIN before sending request.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ParentLinkView: View {
    let childId: String
    let childName: String
    let parentName: String

    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var status = "Enter the 6-digit code shown on the watch"
    
    // UI States
    @State private var isSending = false
    @State private var isWaitingForApproval = false
    @State private var showSuccess = false // ✅ New Success State
    
    // Listener for real-time updates
    @State private var listener: ListenerRegistration?

    private var digitsOnly: String { code.filter { $0.isNumber } }
    private var isValidCode: Bool { digitsOnly.count == 6 }

    var body: some View {
        VStack(spacing: 20) {
            
            if showSuccess {
                // MARK: - Success UI (Linked Successfully)
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text("Linked Successfully")
                        .font(.title)
                        .bold()
                        .foregroundColor(Color("BlackFont"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if isWaitingForApproval {
                // MARK: - Waiting UI
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("Request Sent")
                        .font(.title2)
                        .bold()
                    
                    Text("Waiting for the main guardian to approve your request... Please keep this page open...")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Button("Cancel Request") {
                        cancelRequest()
                    }
                    .foregroundColor(.red)
                    .padding(.top)
                }
            } else {
                // MARK: - Entry UI
                Text("Link Watch")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)
                
                Text("Enter the code displayed on \(childName)'s watch.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                TextField("123456", text: $code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 200)
                    .padding(.vertical)
                    .onChange(of: code) { newValue in
                        let trimmed = newValue.filter { $0.isNumber }
                        if trimmed.count > 6 {
                            code = String(trimmed.prefix(6))
                        } else {
                            code = trimmed
                        }
                    }

                Button {
                    sendLinkCode()
                } label: {
                    HStack(spacing: 8) {
                        if isSending { ProgressView().tint(.white) }
                        Text("Link")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidCode ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isValidCode || isSending)
                .padding(.horizontal)

                Text(status)
                    .font(.footnote)
                    .foregroundColor(status.contains("Failed") || status.contains("Invalid") || status.contains("Rejected") ? .red : .gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
        .padding()
        .animation(.easeInOut, value: showSuccess) // Smooth transition
        .animation(.easeInOut, value: isWaitingForApproval)
        .onDisappear {
            // Clean up listener when view closes
            listener?.remove()
        }
    }

    // MARK: - 1. Send Request (With Validation)
    private func sendLinkCode() {
        guard isValidCode else { return }
        
        guard let guardianId = Auth.auth().currentUser?.uid else {
            status = "Error: You must be logged in."
            return
        }

        isSending = true
        let db = Firestore.firestore()
        let pinCode = digitsOnly
        let docRef = db.collection("pairingCodes").document(pinCode)
        
        // 1. CHECK IF PIN EXISTS (Registered by Watch)
        docRef.getDocument { snapshot, error in
            if let error = error {
                self.isSending = false
                self.status = "Error checking PIN: \(error.localizedDescription)"
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                // ❌ PIN NOT FOUND (Watch hasn't registered it yet)
                self.isSending = false
                self.status = "Invalid PIN! Please check the watch and try again."
                return
            }
            
            // 2. PIN EXISTS -> Update it with our request
            let pairingData: [String: Any] = [
                "guardianId": guardianId,
                "childId": childId,
                "childName": childName,
                "parentName": parentName,
                "timestamp": FieldValue.serverTimestamp(),
                "approvalStatus": "", // Reset to waiting
                "notificationSent": false
            ]
            
            docRef.updateData(pairingData) { error in
                if let error = error {
                    self.isSending = false
                    self.status = "Failed to send request: \(error.localizedDescription)"
                    return
                }
                
                // Success -> Start Listening
                print("✅ PIN verified and request sent. Listening for Admin...")
                self.isSending = false
                self.isWaitingForApproval = true
                self.listenForApproval(pin: pinCode, guardianId: guardianId)
            }
        }
    }
    
    // MARK: - 2. Listen for Approval (The Feedback Loop)
    private func listenForApproval(pin: String, guardianId: String) {
        let db = Firestore.firestore()
        
        listener = db.collection("pairingCodes").document(pin)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }
                
                // Check the status field updated by the Admin
                if let status = data["approvalStatus"] as? String {
                    
                    if status == "approved" {
                        // 🎉 Success!
                        handleSuccess(guardianId: guardianId)
                    } else if status == "rejected" {
                        // ❌ Denied
                        self.listener?.remove()
                        self.isWaitingForApproval = false
                        self.status = "Connection Rejected by Admin."
                    }
                }
            }
    }
    
    // MARK: - 3. Handle Success UI
    private func handleSuccess(guardianId: String) {
        let db = Firestore.firestore()
        
        // 1. Update the child document locally to show it's linked
        db.collection("guardians").document(guardianId).collection("children").document(childId)
            .updateData(["isWatchLinked": true])
        
        // 2. Save local defaults
        UserDefaults.standard.set(true, forKey: "linked_\(childId)")
        
        // 3. Stop listening
        self.listener?.remove()
        
        // 4. Show Success Message UI
        withAnimation {
            self.showSuccess = true
        }
        
        // 5. Dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            dismiss()
        }
    }
    
    private func cancelRequest() {
        listener?.remove()
        isWaitingForApproval = false
        // Optional: Delete the document to cancel alert on Admin's phone
        Firestore.firestore().collection("pairingCodes").document(digitsOnly).delete()
    }
}
