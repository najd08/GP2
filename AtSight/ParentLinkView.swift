//
//  ParentLinkView.swift
//  AtSight
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CodeScanner

struct ParentLinkView: View {

    let childId: String
    let childName: String
    let parentName: String

    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var status = "Enter the 6-digit code shown on the watch"

    @State private var isSending = false
    @State private var isWaitingForApproval = false
    @State private var showSuccess = false

    @State private var isShowingScanner = false
    @State private var showManualPinSheet = false
    @State private var showInvalidQRAlert = false

    @State private var listener: ListenerRegistration?

    private var digitsOnly: String { code.filter { $0.isNumber } }
    private var isValidCode: Bool { digitsOnly.count == 6 }

    var body: some View {

        ZStack {

            // ============================
            // SUCCESS SCREEN
            // ============================
            if showSuccess {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color("Blue"))

                    Text("Linked Successfully")
                        .font(.title)
                        .bold()
                        .foregroundColor(Color("BlackFont"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // ============================
            // WAITING FOR APPROVAL
            // ============================
            else if isWaitingForApproval {
                VStack(spacing: 20) {
                    ProgressView().scaleEffect(1.5)

                    Text("Request Sent")
                        .font(.title2).bold()

                    Text("Waiting for the main guardian to approve your request...\nPlease keep this page open.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    Button("Cancel Request") { cancelRequest() }
                        .foregroundColor(.red)
                }
            }

            // ============================
            // SCANNER SCREEN
            // ============================
            else if isShowingScanner {

                ZStack {
                    Color("BgColor").ignoresSafeArea()

                    VStack {

                        // BACK BUTTON
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color("BlackFont"))
                                    .padding()
                            }
                            Spacer()
                        }

                        Text("Scan QR Code")
                            .font(.largeTitle).bold()
                            .foregroundColor(Color("button"))

                        Text("Point your camera at the watch.")
                            .foregroundColor(Color("button"))

                        Spacer()

                        CodeScannerView(
                            codeTypes: [.qr],
                            scanMode: .continuous,
                            showViewfinder: true
                        ) { result in
                            switch result {
                            case .success(let scanned):
                                isShowingScanner = false
                                handleScan(result: scanned.string)
                            case .failure:
                                showInvalidQRAlert = true
                            }
                        }
                        .frame(width: 350, height: 350)
                        .cornerRadius(22)

                        Spacer()

                        // MANUAL PIN BUTTON
                        Button {
                            showManualPinSheet = true
                        } label: {
                            Text("Enter PIN manually")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 40)
                                .background(Color("button"))
                                .cornerRadius(30)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }

            // ============================
            // REMOVE DEFAULT PAGE → Always open scanner
            // ============================
            else {
                // مباشرة افتح شاشة الكاميرا، بدون أي UI إضافي
                Color.clear.onAppear { isShowingScanner = true }
            }
        }

        // INVALID QR ALERT
        .alert("Invalid QR Code", isPresented: $showInvalidQRAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This QR code does not match the expected format.")
        }

        // MANUAL PIN SHEET
        .sheet(isPresented: $showManualPinSheet) {
            manualPinEntrySection.padding()
        }

        .navigationBarBackButtonHidden(true)
        .onDisappear { listener?.remove() }
    }

    // ===========================================
    // MANUAL PIN VIEW
    // ===========================================
    private var manualPinEntrySection: some View {

        VStack(spacing: 20) {

            Text("Enter the PIN")
                .font(.title3).bold()

            TextField("123456", text: $code)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 200)
                .onChange(of: code) { newValue in
                    let trimmed = newValue.filter(\.isNumber)
                    code = trimmed.count > 6 ? String(trimmed.prefix(6)) : trimmed
                }

            Button {
                sendLinkCode()
            } label: {
                HStack {
                    if isSending { ProgressView().tint(.white) }
                    Text("Link").bold()
                }
                .foregroundColor(.white)
                 .font(.headline)
                 .padding(.vertical, 14)
                 .frame(width: 250)     
                 .background(isValidCode ? Color("button") : Color.gray)
                 .cornerRadius(30)
            }
            .disabled(!isValidCode || isSending)
            Text(status)
                .foregroundColor(status.contains("Invalid") || status.contains("Rejected") ? .red : .gray)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
    }

    // ===========================================
    // QR SCAN HANDLER
    // ===========================================
    private func handleScan(result: String) {

        let trimmed = result.filter(\.isNumber)

        guard trimmed.count == 6 else {
            showInvalidQRAlert = true
            return
        }

        code = trimmed
        sendLinkCode()
    }

    // ===========================================
    // SEND PIN LOGIC
    // ===========================================
    private func sendLinkCode() {
        guard isValidCode else {
            status = "Invalid code length."
            return
        }

        guard let guardianId = Auth.auth().currentUser?.uid else {
            status = "Error: You must be logged in."
            return
        }

        isSending = true

        let db = Firestore.firestore()
        let pinCode = digitsOnly
        let docRef = db.collection("pairingCodes").document(pinCode)

        docRef.getDocument { snapshot, error in

            if let error = error {
                isSending = false
                status = "Error checking PIN: \(error.localizedDescription)"
                return
            }

            guard let snapshot = snapshot, snapshot.exists else {
                isSending = false
                showInvalidQRAlert = true
                return
            }

            let data: [String: Any] = [
                "guardianId": guardianId,
                "childId": childId,
                "childName": childName,
                "parentName": parentName,
                "timestamp": FieldValue.serverTimestamp(),
                "approvalStatus": "",
                "notificationSent": false
            ]

            docRef.updateData(data) { error in

                if let error = error {
                    isSending = false
                    status = "Failed to send request: \(error.localizedDescription)"
                    return
                }

                isSending = false
                isWaitingForApproval = true
                listenForApproval(pin: pinCode, guardianId: guardianId)
            }
        }
    }

    // ===========================================
    // FIRESTORE LISTENER
    // ===========================================
    private func listenForApproval(pin: String, guardianId: String) {

        listener = Firestore.firestore()
            .collection("pairingCodes")
            .document(pin)
            .addSnapshotListener { snapshot, _ in

                guard let data = snapshot?.data() else { return }

                if let status = data["approvalStatus"] as? String {

                    if status == "approved" {
                        handleSuccess(guardianId: guardianId)
                    } else if status == "rejected" {
                        listener?.remove()
                        isWaitingForApproval = false
                        self.status = "Connection Rejected by Admin."
                    }
                }
            }
    }

    // ===========================================
    // SUCCESS HANDLER
    // ===========================================
    private func handleSuccess(guardianId: String) {

        Firestore.firestore()
            .collection("guardians")
            .document(guardianId)
            .collection("children")
            .document(childId)
            .updateData(["isWatchLinked": true])

        UserDefaults.standard.set(true, forKey: "linked_\(childId)")

        listener?.remove()

        withAnimation { showSuccess = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            dismiss()
        }
    }

    private func cancelRequest() {
        listener?.remove()
        isWaitingForApproval = false
        Firestore.firestore().collection("pairingCodes").document(digitsOnly).delete()
    }
}
