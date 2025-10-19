//
//  HomeView_Watch.swift
//  AtSight (WatchKit Extension)
//

import SwiftUI
import WatchConnectivity

struct HomeView_Watch: View {
    @StateObject private var pairing = PairingState.shared
    @State private var showSOSPopup = false
    @State private var navigateToChat = false

    // MARK: - Style
    private let bgTop     = Color(red: 0.965, green: 0.975, blue: 1.00)
    private let bgBottom  = Color(red: 0.93,  green: 0.95,  blue: 1.00)
    private let brandBlue = Color("Blue")
    private let buttons   = Color("Buttons")
    private let whiteText = Color.white
    private let textMain  = Color.black
    private let stroke    = Color.black.opacity(0.12)

    // MARK: - Helpers
    private func startServicesIfPossible(context: String) {
        let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? ""
        guard pairing.linked, !childId.isEmpty else {
            print("⚠️ [Home] skip start (\(context)) linked=\(pairing.linked) childId=\(childId.isEmpty ? "nil" : childId)")
            return
        }

        // Ensure WCSession is active
        if WCSession.isSupported(), WCSession.default.activationState == .notActivated {
            WatchConnectivityManager.shared.activate()
        }

        // Start services
        let childName = pairing.childName.isEmpty
            ? (UserDefaults.standard.string(forKey: "childDisplayName") ?? "Child")
            : pairing.childName

        BatteryMonitor.shared.startMonitoring(for: childName)
        WatchLocationManager.shared.startLiveUpdates()
        HeartRateMonitor.shared.startMonitoring(for: childName) // ✅ Added heart rate service

        print("✅ [Home] services started (\(context)) for childId=\(childId) name=\(childName)")
    }

    private func stopServices(context: String) {
        WatchLocationManager.shared.stopLiveUpdates()
        HeartRateMonitor.shared.stopMonitoring() // ✅ Stop heart rate when leaving
        print("🛑 [Home] services stopped (\(context))")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: [bgTop, bgBottom]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // MARK: Header
                    HStack(spacing: 10) {
                        Text(pairing.childName.isEmpty ? "AtSight" : pairing.childName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(brandBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 8)

                        // Logo
                        Image("Image")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .padding(6)
                            .background(Circle().fill(buttons.opacity(0.20)))
                            .overlay(Circle().stroke(buttons.opacity(0.35), lineWidth: 1))
                            .shadow(color: buttons.opacity(0.20), radius: 2, x: 0, y: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    // MARK: Contact Card → VoiceChat
                    ContactRow_Watch(
                        name: pairing.parentName.isEmpty ? "Parent" : pairing.parentName
                    ) {
                        navigateToChat = true
                    }

                    Spacer(minLength: 2)

                    // MARK: SOS Button
                    Button(action: { startSOSPopup() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(whiteText)
                            Text("SOS button")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(whiteText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.98, green: 0.28, blue: 0.26),
                                        Color(red: 0.82, green: 0.00, blue: 0.00)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .shadow(color: Color.red.opacity(0.28), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 2)
                }

                // MARK: SOS Popup
                if showSOSPopup {
                    SOSConfirmSheet(
                        isShowing: $showSOSPopup,
                        onSend: {
                            showSOSPopup = false
                            print("SOS Sent")
                        }
                    )
                }

                // MARK: Navigation → VoiceChat
                NavigationLink(destination: VoiceChatView(), isActive: $navigateToChat) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                startServicesIfPossible(context: "onAppear")
            }
            .onDisappear {
                stopServices(context: "onDisappear")
            }
            .onChange(of: pairing.linked) { new in
                if new {
                    startServicesIfPossible(context: "onChange(linked=true)")
                } else {
                    stopServices(context: "onChange(linked=false)")
                }
            }
        }
    }

    // MARK: - SOS Logic
    private func startSOSPopup() { showSOSPopup = true }
    private func cancelSOS() { showSOSPopup = false }
}

// MARK: - Contact Row
struct ContactRow_Watch: View {
    var name: String
    var onChatTapped: () -> Void

    private let buttons = Color("Buttons")
    private let textMain = Color.black
    private let stroke   = Color.black.opacity(0.10)

    var body: some View {
        Button(action: onChatTapped) {
            HStack(spacing: 10) {
                // Mic icon
                ZStack {
                    Circle()
                        .fill(buttons.opacity(0.20))
                        .frame(width: 28, height: 28)
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .medium))
                        .padding(6)
                        .background(Circle().fill(buttons))
                        .shadow(color: buttons.opacity(0.25), radius: 3, x: 0, y: 1)
                }

                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - SOS Confirm Sheet
struct SOSConfirmSheet: View {
    @Binding var isShowing: Bool
    var onSend: () -> Void

    private let titleRed1   = Color(red: 1.00, green: 0.23, blue: 0.23)
    private let bodyText    = Color.black.opacity(0.9)
    private let sheetStroke = Color.black.opacity(0.08)
    private let sendGrad1   = Color(red: 0.98, green: 0.28, blue: 0.26)
    private let sendGrad2   = Color(red: 0.82, green: 0.00, blue: 0.00)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Trigger SOS !")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(titleRed1)

                Text("Are you sure you want to trigger SOS?")
                    .font(.system(size: 12))
                    .foregroundColor(bodyText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)

                HStack(spacing: 12) {
                    Button(action: { isShowing = false }) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.gray))
                    }
                    .buttonStyle(.plain)

                    Button(action: { onSend() }) {
                        Text("Send")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [sendGrad1, sendGrad2]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(sheetStroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 6)
            .padding(.horizontal, 10)
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView_Watch()
}
