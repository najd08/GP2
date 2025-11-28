import SwiftUI
import FirebaseFirestore
import UserNotifications

// ==========================================
// 1. THE MODEL
// ==========================================
struct PairingRequest: Identifiable {
    let id: String            // Notification Document ID
    let pin: String           // Pairing Code PIN
    let requesterName: String
    let childName: String
}

// ==========================================
// 2. THE LISTENER (VIEW MODEL)
// ==========================================
class PairingRequestListener: ObservableObject {
    @Published var activeRequest: PairingRequest?
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    func startListening(guardianId: String) {
        stopListening()
        
        print("🎧 [Listener] Starting for Guardian: \(guardianId)")
        
        let ref = db.collection("guardians")
            .document(guardianId)
            .collection("notifications")
            .whereField("event", isEqualTo: "connection_request")
        
        listenerRegistration = ref.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("❌ [Listener] Error: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            // Check for NEW additions to trigger the Local Notification
            snapshot?.documentChanges.forEach { change in
                if change.type == .added {
                    let data = change.document.data()
                    let requester = data["requestingGuardianName"] as? String ?? "Someone"
                    let childName = data["childName"] as? String ?? ""
                    
                    print("🆕 [Listener] New Request for child: \(childName)")
                    
                    // 🔔 TRIGGER LOCAL NOTIFICATION (With Name-Based Lookup)
                    self?.sendLocalNotification(
                        guardianId: guardianId,
                        requester: requester,
                        childName: childName
                    )
                }
            }
            
            // Handle the Active Request for the UI (Pop-up)
            if let doc = documents.first {
                let data = doc.data()
                
                let newRequest = PairingRequest(
                    id: doc.documentID,
                    pin: data["pin"] as? String ?? "",
                    requesterName: data["requestingGuardianName"] as? String ?? "Unknown",
                    childName: data["childName"] as? String ?? "Child"
                )
                
                DispatchQueue.main.async {
                    if !newRequest.pin.isEmpty {
                        self?.activeRequest = newRequest
                    }
                }
            } else {
                DispatchQueue.main.async { self?.activeRequest = nil }
            }
        }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
    }
    
    // MARK: - Local Notification Logic (Corrected Lookup)
    private func sendLocalNotification(guardianId: String, requester: String, childName: String) {
        let title = "Connection Request"
        let body = "\(requester) wants to connect to \(childName)'s watch."
        
        guard !childName.isEmpty else {
            schedule(title: title, body: body, sound: "default_sound.wav")
            return
        }
        
        // 1. Find the Child ID in Admin's list by matching the NAME
        db.collection("guardians")
            .document(guardianId)
            .collection("children")
            .whereField("name", isEqualTo: childName)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                
                guard let self = self, let doc = snapshot?.documents.first else {
                    print("⚠️ [Listener] Child not found by name: \(childName). Using default.")
                    self?.schedule(title: title, body: body, sound: "default_sound.wav")
                    return
                }
                
                let childId = doc.documentID
                print("✅ [Listener] Found Child ID: \(childId) for name: \(childName)")
                
                // 2. Fetch Settings for THIS child
                self.db.collection("guardians")
                    .document(guardianId)
                    .collection("children")
                    .document(childId)
                    .collection("notifications")
                    .document("settings")
                    .getDocument { settingsSnap, _ in
                        
                        var soundFile = "default_sound"
                        var newConnectionRequestAlert = true // Default to ON
                        
                        if let settingsData = settingsSnap?.data() {
                            // A. Check Permission
                            if let enabled = settingsData["newConnectionRequest"] as? Bool {
                                newConnectionRequestAlert = enabled
                            }
                            // B. Get Sound
                            if let customSound = settingsData["sound"] as? String, !customSound.isEmpty {
                                soundFile = customSound
                            }
                        }
                        
                        // 3. Check if Alert is Allowed
                        if newConnectionRequestAlert == false {
                            print("🚫 [Listener] 'New Author Account' alert is DISABLED for \(childName).")
                            return
                        }
                        
                        // 4. Format and Play
                        if !soundFile.hasSuffix(".wav") {
                            soundFile += ".wav"
                        }
                        
                        print("🔔 [Listener] Playing sound: \(soundFile)")
                        self.schedule(title: title, body: body, sound: soundFile)
                    }
            }
    }
    
    private func schedule(title: String, body: String, sound: String) {
        NotificationManager.instance.scheduleNotification(
            title: title,
            body: body,
            soundName: sound
        )
    }
}

// ==========================================
// 3. THE VIEW
// ==========================================
struct PairingRequestView: View {
    let request: PairingRequest
    let guardianId: String
    
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color("BgColor").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Image(systemName: "person.badge.clock.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(Color("Blue"))
                    .padding(.top, 40)
                
                VStack(spacing: 8) {
                    Text("Connection Request")
                        .font(.title2).bold()
                        .foregroundColor(Color("BlackFont"))
                    
                    Text("\(request.requesterName) wants to connect to \(request.childName)'s watch.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Text("PIN Code: \(request.pin)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 5)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { handleDecision(status: "rejected") }) {
                        Text("Deny")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                    Button(action: { handleDecision(status: "approved") }) {
                        Text("Approve")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("Blue"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            
            if isLoading {
                ZStack {
                    Color.black.opacity(0.2).edgesIgnoringSafeArea(.all)
                    ProgressView("Processing...").padding()
                }
            }
        }
        .alert(item: $errorMessage) { error in
            Alert(title: Text("Error"), message: Text(error), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Firestore Logic
    func handleDecision(status: String) {
        guard !request.pin.isEmpty else {
            self.errorMessage = "Error: Invalid PIN code."
            return
        }
        
        isLoading = true
        let db = Firestore.firestore()
        let docRef = db.collection("pairingCodes").document(request.pin)
        
        // 1. Update Pairing Code Status
        docRef.setData(["approvalStatus": status], merge: true) { error in
            if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                return
            }
            
            // 2. Delete Notification
            db.collection("guardians")
                .document(guardianId)
                .collection("notifications")
                .document(request.id)
                .delete()
            
            DispatchQueue.main.async {
                self.isLoading = false
                dismiss()
            }
        }
    }
}

extension String: Identifiable {
    public var id: String { self }
}
