//
//  HomeView_Watch.swift
//  AtSight (WatchKit Extension)
//  Updated by Leon – 28/10/2025
//  ✅ Added background voice listener (fetch every 2s + haptic alert)
//  ✅ Prevents repeated playback across Home + Chat using shared UserDefaults
//

// EDIT BY RIYAM: Removed Header Image.
// EDIT BY RIYAM: Expanded Guardian List to fill screen space.
// EDIT BY RIYAM: Fixed Halt Alert to play immediately and stop audio after 15s.
// EDIT BY RIYAM: Kept Multi-Guardian SOS/HALT logic.

import SwiftUI
import WatchConnectivity
import AVFoundation
import WatchKit

struct HomeView_Watch: View {
    @StateObject private var pairing = PairingState.shared
    // ✅ Use the shared HaltReceiver instead of local state
    @StateObject private var haltManager = HaltReceiver.shared
    
    @State private var showSOSPopup = false
    @State private var selectedGuardianId: String?
    @State private var navigateToChat = false
    
    // Timers for background logic
    @State private var unlinkTimer: Timer?
    // ❌ REMOVED: haltTimer (HaltReceiver handles this now)

    // MARK: - Style
    private let bgTop     = Color(red: 0.965, green: 0.975, blue: 1.00)
    private let bgBottom  = Color(red: 0.93,  green: 0.95,  blue: 1.00)
    private let brandBlue = Color("Blue")
    private let buttons   = Color("Buttons")
    private let whiteText = Color.white
    private let textMain  = Color.black
    private let stroke    = Color.black.opacity(0.12)

    // MARK: - Helpers
    private func startServices() {
        if let firstGuardianId = pairing.linkedGuardianIDs.first,
           let firstChildId = pairing.guardianChildIDs[firstGuardianId] {
            UserDefaults.standard.set(firstGuardianId, forKey: "guardianId")
            UserDefaults.standard.set(firstChildId, forKey: "currentChildId")
        }
        
        let childName = pairing.childName.isEmpty ? "Child" : pairing.childName
        
        BatteryMonitor.shared.startMonitoring(for: childName)
        WatchLocationManager.shared.startLiveUpdates()
        HeartRateMonitor.shared.startMonitoring(for: childName)
        VoiceChatBackground.shared.startListening()
        
        startUnlinkCheck()
        
        // ✅ Start the centralized Halt Listener
        haltManager.startListening()
        
        print("✅ [Home] services started")
    }
    
    private func stopServices() {
        unlinkTimer?.invalidate()
        unlinkTimer = nil
        
        WatchLocationManager.shared.stopLiveUpdates()
        HeartRateMonitor.shared.stopMonitoring()
        VoiceChatBackground.shared.stopListening()
        
        // ✅ Stop Halt Listener
        haltManager.stopListening()
        
        print("🛑 [Home] services stopped")
    }
    
    // MARK: - Unlink Checker
    private func startUnlinkCheck() {
        unlinkTimer?.invalidate()
        unlinkTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            checkForUnlink()
        }
    }
    
    private func checkForUnlink() {
        // ... (Keep existing unlink logic) ...
        for guardianId in pairing.linkedGuardianIDs {
            guard let childId = pairing.guardianChildIDs[guardianId], !childId.isEmpty else { continue }
            
            let urlString = "\(API.checkLinkStatus)?guardianId=\(guardianId)&childId=\(childId)"
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        print("🚫 Unlink detected for guardian: \(guardianId)")
                        DispatchQueue.main.async {
                            pairing.removeGuardian(guardianId)
                        }
                    }
                }
            }.resume()
        }
    }
    
    // ❌ REMOVED: startHaltCheck() and checkForHaltSignal()
    // The logic inside HaltReceiver.swift handles this more accurately now.

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [bgTop, bgBottom]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Header
                    HStack(spacing: 10) {
                        Text(pairing.childName.isEmpty ? "AtSight" : pairing.childName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(brandBlue)
                            .lineLimit(1)

                        Spacer()
                        
                        NavigationLink(destination: PairingView()) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 14))
                                Text("  Link  ")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(brandBlue)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(buttons.opacity(0.2)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
        
                    // MARK: Guardian List
                    ScrollView {
                        VStack(spacing: 0) {
                            if pairing.linkedGuardianIDs.isEmpty {
                                Text("No guardians connected.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 20)
                            } else {
                                ForEach(pairing.linkedGuardianIDs, id: \.self) { guardianId in
                                    let name = pairing.guardianNames[guardianId] ?? "Guardian"
                                    
                                    ContactRow_Watch(name: name) {
                                        selectedGuardianId = guardianId
                                        navigateToChat = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Spacer(minLength: 0)
                    
                    // MARK: SOS Button
                    Button(action: { startSOSPopup() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(whiteText)
                            Text("SOS")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(whiteText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
                        .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, -10)
                }

                // Overlays
                if showSOSPopup {
                    SOSConfirmSheet(isShowing: $showSOSPopup) {
                        showSOSPopup = false
                        print("🚨 SOS Sent")
                        
                        for guardianId in pairing.linkedGuardianIDs {
                            if let childId = pairing.guardianChildIDs[guardianId], !childId.isEmpty {
                                let payload: [String: Any] = [
                                    "guardianId": guardianId,
                                    "childId": childId,
                                    "childName": pairing.childName,
                                    "ts": Date().timeIntervalSince1970
                                ]
                                APIHelper.shared.post(to: API.triggerSOS, body: payload)
                            }
                        }
                    }
                }
                
                // ✅ Updated HALT Overlay using the HaltReceiver ObservableObject
                if haltManager.isHaltActive {
                    HaltAlertView(message: "HALT SIGNAL RECEIVED") {
                        // Only allow dismiss if the timer allows it
                        if haltManager.canDismiss {
                            haltManager.dismissHalt()
                        }
                    }
                }

                NavigationLink(destination: chatDestination, isActive: $navigateToChat) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarBackButtonHidden(true)
            .onAppear { startServices() }
            .onDisappear { stopServices() }
        }
    }

    private func startSOSPopup() { showSOSPopup = true }
    
    @ViewBuilder
    private var chatDestination: some View {
        if let gid = selectedGuardianId,
           let childId = pairing.guardianChildIDs[gid] {
            VoiceChatView(
                guardianId: gid,
                childId: childId,
                childName: pairing.childName,
                parentName: pairing.guardianNames[gid] ?? "Parent"
            )
        } else {
            EmptyView()
        }
    }
}

// ... (Rest of the subviews like ContactRow_Watch, SOSConfirmSheet remain the same)
// MARK: - Contact Row
struct ContactRow_Watch: View {
    var name: String
    var onChatTapped: () -> Void
    private let buttons = Color("Buttons")
    private let stroke = Color.black.opacity(0.10)

    var body: some View {
        Button(action: onChatTapped) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(buttons.opacity(0.20))
                        .frame(width: 30, height: 30)
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                        .padding(6)
                        .background(Circle().fill(buttons))
                }

                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SOS Confirm Sheet (Original)
struct SOSConfirmSheet: View {
    @Binding var isShowing: Bool
    var onSend: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Trigger SOS!")
                    .font(.headline)
                    .foregroundColor(.red)
                Text("Confirm alert?")
                    .font(.footnote)
                HStack {
                    Button("Cancel") { isShowing = false }.tint(.gray)
                    Button("Send") { onSend() }.tint(.red)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
        }
    }
}

// MARK: - HALT Alert View (Immediate Start & Auto-Stop)
struct HaltAlertView: View {
    let message: String
    let onDismiss: () -> Void
    
    @State private var timeRemaining = 15
    @State private var hapticTimer: Timer?
    
    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea()
            
            VStack(spacing: 15) {
                Image(systemName: "hand.raised.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
                    .symbolEffect(.bounce, options: .repeating)
                
                Text("HALT!")
                    .bold()
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                Button(action: onDismiss) {
                    Text(timeRemaining > 0 ? "Wait \(timeRemaining)s" : "OK")
                        .font(.headline)
                        .foregroundColor(timeRemaining > 0 ? .gray : .red)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .disabled(timeRemaining > 0)
            }
        }
        .transition(.opacity)
        .zIndex(100)
        .onAppear { startAlerts() }
        .onDisappear { stopAlerts() }
    }
    
    private func startAlerts() {
        // 1. Play IMMEDIATE haptic
        WKInterfaceDevice.current().play(.notification)
        
        // 2. Schedule recurring haptic loop
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            WKInterfaceDevice.current().play(.notification)
        }
        
        // 3. Countdown timer - Stops sound at 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // 🛑 Stop sounds/haptics automatically after 15s
                stopAlerts()
                timer.invalidate()
            }
        }
    }
    
    private func stopAlerts() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}

// MARK: - Background Voice Fetcher
final class VoiceChatBackground {
    static let shared = VoiceChatBackground()
    private var timer: Timer?
    private var player: AVPlayer?

    private var lastURL: String? {
        get { UserDefaults.standard.string(forKey: "lastPlayedVoiceURL") }
        set { UserDefaults.standard.set(newValue, forKey: "lastPlayedVoiceURL") }
    }

    private var wasPlayed: Bool {
        get { UserDefaults.standard.bool(forKey: "lastPlayedVoicePlayed") }
        set { UserDefaults.standard.set(newValue, forKey: "lastPlayedVoicePlayed") }
    }

    func startListening() {
        stopListening()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.fetchLatestMessage()
        }
        print("🎧 Background voice listener started (2s interval)")
    }

    func stopListening() {
        timer?.invalidate()
        timer = nil
        print("🛑 Background voice listener stopped")
    }

    private func fetchLatestMessage() {
        let guardianId = UserDefaults.standard.string(forKey: "guardianId") ?? ""
        let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? ""
        guard !guardianId.isEmpty, !childId.isEmpty else { return }
        
        let urlString = "https://getvoicemessagesapi-7gq4boqq6a-uc.a.run.app?guardianId=\(guardianId)&childId=\(childId)&limit=1"
        
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = json.first,
                  let audioURL = latest["audioURL"] as? String,
                  let sender = latest["sender"] as? String,
                  sender == "phone" else { return }

            if self.lastURL == audioURL, self.wasPlayed { return }

            if self.lastURL != audioURL {
                self.lastURL = audioURL
                self.wasPlayed = false
            }

            if self.wasPlayed == false {
                self.wasPlayed = true
                print("🔊 New voice message detected → playing…")
                WKInterfaceDevice.current().play(.notification)
                DispatchQueue.main.async {
                    self.playAudio(from: audioURL)
                }
            }
        }.resume()
    }

    private func playAudio(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        player = AVPlayer(url: url)
        player?.play()
    }
}

#Preview {
    HomeView_Watch()
}
