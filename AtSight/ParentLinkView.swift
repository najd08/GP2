//
//  ParentLinkView.swift
//  AtSight
//
//  Created by Leena on 04/09/2025.
//

import SwiftUI
import WatchConnectivity
import FirebaseAuth

struct ParentLinkView: View {
    // Pass these when presenting the view
    let childId: String
    let childName: String
    let parentName: String   // e.g. from Firestore "FirstName" or current user display name

    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var status = "Enter the 6-digit code shown on the watch"
    @State private var isSending = false

    // Only 6 digits are allowed
    private var digitsOnly: String { code.filter { $0.isNumber } }
    private var isValidCode: Bool { digitsOnly.count == 6 }

    var body: some View {
        VStack(spacing: 16) {
            TextField("123456", text: $code)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 160)
                .onChange(of: code) { newValue in
                    let trimmed = newValue.filter { $0.isNumber }
                    code = String(trimmed.prefix(6))
                }

            Button {
                sendLinkCode()
            } label: {
                HStack(spacing: 8) {
                    if isSending { ProgressView().scaleEffect(0.8) }
                    Text("Link")
                }
            }
            .disabled(!isValidCode || isSending)
            .buttonStyle(.borderedProminent)

            Text(status)
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding()
        .onAppear {
            PhoneConnectivity.shared.activate()
            let state = WCSession.default.activationState
            switch state {
            case .activated:
                status = "Enter the 6-digit code shown on the watch"
            case .inactive:
                status = "Session inactive — will auto-reactivate."
            case .notActivated:
                status = "Session not activated yet — open the watch app to activate."
            @unknown default:
                status = "Unknown session state."
            }
        }
    }

    private func sendLinkCode() {
        guard WCSession.default.activationState == .activated else {
            status = "Session not activated — open the watch app and try again."
            return
        }
        guard WCSession.default.isReachable else {
            status = "Watch not reachable — open the AtSight app on the watch."
            return
        }
        guard isValidCode else {
            status = "Please enter a valid 6-digit code."
            return
        }

        isSending = true
        let guardianId = Auth.auth().currentUser?.uid ?? "unknownGuardian"

        let payload: [String: Any] = [
            "type": "link",
            "pin": digitsOnly,
            "childName": childName,
            "parentName": parentName,
            "childId": childId,
            "guardianId": guardianId   // ✅ أضفنا هذا السطر
        ]

        WCSession.default.sendMessage(
            payload,
            replyHandler: { reply in
                DispatchQueue.main.async {
                    self.isSending = false
                    let s = (reply["status"] as? String) ?? "OK"
                    switch s {
                    case "linked":
                        self.status = "✅ Linked successfully."
                        // Keep local “linked” state + remember last linked child for later location messages
                        UserDefaults.standard.set(true, forKey: "linked_\(childId)")
                        UserDefaults.standard.set(childId, forKey: "lastLinkedChildId")
                        self.dismiss()

                    case "wrong_pin", "wrong pin":
                        self.status = "❌ Wrong code — double-check the 6 digits on the watch."

                    case "missing_pin":
                        self.status = "Code missing — try again."

                    default:
                        self.status = "Watch: \(s)"
                    }
                }
            },
            errorHandler: { err in
                DispatchQueue.main.async {
                    self.isSending = false
                    self.status = "Error: \(err.localizedDescription)"
                }
            }
        )
    }
}
