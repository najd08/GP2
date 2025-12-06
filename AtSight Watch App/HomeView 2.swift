//
//  HomeView_Watch.swift
//  AtSight (WatchKit Extension)
//  Updated by Leon – 28/10/2025
//  ✅ Added background voice listener (fetch every 2s + haptic alert)
//  ✅ Prevents repeated playback across Home + Chat using shared UserDefaults
//
//  UPDATED BY RIYAM: Implemented MessageNotifier for universal popup and Last Messages queue.
//  UPDATED BY RIYAM: Adjusted MessagePopupView positioning (top-center) and text color.
//  UPDATED BY RIYAM: Implemented SEQUENTIAL playback and counter logic.
//  UPDATED BY RIYAM: REMOVED Last Messages button from HomeView.
//  ✅ FINAL FIX: ADDED Unheard Message Badge to Guardian Contact Row AND Fixed Popup Sender Name Display.
//  ❌ CORRECTION: REMOVED incorrect badge placement from Pairing Code Button.

// EDIT BY RIYAM: Removed Header Image.
// EDIT BY RIYAM: Expanded Guardian List to fill screen space.
// EDIT BY RIYAM: Fixed Halt Alert to play immediately and stop audio after 15s.
// EDIT BY RIYAM: Kept Multi-Guardian SOS/HALT logic.

import SwiftUI
import WatchConnectivity
import AVFoundation
import WatchKit

// MARK: - Shared Message Notifier (Handles Notification, Queue, and Playback)
final class MessageNotifier: ObservableObject {
    static let shared = MessageNotifier()
    
    @Published var isMessageAlertActive = false
    @Published var latestAudioURL: String?
    @Published var latestSenderName: String?
    
    private var player: AVPlayer?
    private var playerDidFinishObserver: NSObjectProtocol?
    
    private let unplayedQueueKey = "unplayedMessageQueue"
    
    deinit {
        if let observer = playerDidFinishObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // --- Message Queue Logic (Counter) ---
    var unheardMessageCount: Int {
        return UserDefaults.standard.stringArray(forKey: unplayedQueueKey)?.count ?? 0
    }
    
    // ✅ Logic to count messages in the queue specific to a given sender name (Used for Badge Count)
    func getUnheardCount(for senderName: String) -> Int {
        let queue = UserDefaults.standard.stringArray(forKey: unplayedQueueKey) ?? []
        // Filters queue items based on the sender name (stored as "URL|NAME")
        return queue.filter { $0.hasSuffix("|\(senderName)") }.count
    }
    
    var hasUnheardMessages: Bool {
        return unheardMessageCount > 0
    }
    
    func addToLaterQueue(url: String, name: String) {
        var queue = UserDefaults.standard.stringArray(forKey: unplayedQueueKey) ?? []
        // Store as "URL|NAME"
        queue.append("\(url)|\(name)")
        UserDefaults.standard.set(queue, forKey: unplayedQueueKey)
        DispatchQueue.main.async { self.objectWillChange.send() } // Update count on UI
    }
    
    // --- Notification Logic ---
    func notifyNewMessage(audioURL: String, senderName: String) {
        guard !isMessageAlertActive else { return }
        
        self.latestAudioURL = audioURL
        self.latestSenderName = senderName
        
        DispatchQueue.main.async {
            WKInterfaceDevice.current().play(.notification)
            self.isMessageAlertActive = true
            self.objectWillChange.send() // Ensure UI updates, especially the chat button badge
        }
    }
    
    func dismissAlert() {
        self.latestAudioURL = nil
        self.latestSenderName = nil
        self.isMessageAlertActive = false
    }
    
    func playLatestMessage() {
        guard let urlString = latestAudioURL else { return }
        
        self.dismissAlert()
        self.playAudio(from: urlString, isQueued: false, for: nil) // Play the notification message
    }

    // --- Playback Logic (Sequential Playback) ---
    // ✅ MODIFIED: Playback is now isolated to messages belonging to the specific guardian OR the most recent overall message.
    func playQueueOrLatest(for guardianName: String) {
        var queue = UserDefaults.standard.stringArray(forKey: unplayedQueueKey) ?? []
        
        // 1️⃣ Find the OLDEST message in the queue that belongs to THIS specific guardian.
        if let index = queue.firstIndex(where: { $0.hasSuffix("|\(guardianName)") }) {
            let item = queue.remove(at: index)
            UserDefaults.standard.set(queue, forKey: unplayedQueueKey)
            
            let urlString = item.components(separatedBy: "|").first ?? ""
            
            DispatchQueue.main.async {
                self.objectWillChange.send() // Update the badge immediately
            }
            
            print("🔊 Playing queued message for \(guardianName): \(urlString)")
            // Call playAudio and set up continuation for the SAME guardian's remaining messages.
            playAudio(from: urlString, isQueued: true, for: guardianName)
            return
        }
        
        // 2️⃣ FALLBACK: If the queue for THIS guardian is empty, play the most recent message received from THIS guardian.
        let fallbackKey = "lastPlayedVoiceURL_\(guardianName)"
        
        if let recentURL = UserDefaults.standard.string(forKey: fallbackKey) {
            print("🔊 Playing recent message for \(guardianName): \(recentURL) (Queue empty)")
            // Play it as a one-off (not queued)
            playAudio(from: recentURL, isQueued: false, for: nil)
        }
    }
    
    // NOTE: This function is used ONLY for sequential playback continuation within the same guardian's queue.
    private func playAudio(from urlString: String, isQueued: Bool, for sequentialGuardian: String?) {
        guard let url = URL(string: urlString) else { return }
        
        if let observer = playerDidFinishObserver {
            NotificationCenter.default.removeObserver(observer)
            playerDidFinishObserver = nil
        }
        
        player?.pause()
        player = AVPlayer(url: url)
        player?.play()
        
        if isQueued, let gName = sequentialGuardian {
            // Set up continuation to find the NEXT message specifically for this guardian
            playerDidFinishObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { [weak self] _ in
                // Recursively call the isolated function to get the next message for this guardian
                self?.playQueueOrLatest(for: gName)
            }
        }
    }
    
    // NOTE: The original playNextQueuedMessage is now fully replaced by playQueueOrLatest(for:) for queue handling.
}


// MARK: - Message Popup View (Unchanged)
struct MessagePopupView: View {
    @ObservedObject var notifier: MessageNotifier
    private let buttons   = Color("Buttons")
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("You received a new message")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(buttons)
                
                // ✅ FIX: Directly use latestSenderName for display
                Text("From: \(notifier.latestSenderName ?? "Guardian")")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                HStack {
                    Button("Listen") {
                        notifier.playLatestMessage()
                    }
                    .tint(buttons)
                    
                    Button("Later") {
                        if let url = notifier.latestAudioURL,
                           let name = notifier.latestSenderName {
                            notifier.addToLaterQueue(url: url, name: name)
                        }
                        notifier.dismissAlert()
                    }
                    .tint(.gray)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: 10)
        }
        .zIndex(100)
    }
}


struct HomeView_Watch: View {
    @StateObject private var pairing = PairingState.shared
    @StateObject private var haltManager = HaltReceiver.shared
    // ✅ NEW: observe HeartRateMonitor so we can show the off-wrist popup
    @StateObject private var heartRateMonitor = HeartRateMonitor.shared
    
    @State private var showSOSPopup = false
    @State private var selectedGuardianId: String?
    @State private var navigateToChat = false
    
    @State private var unlinkTimer: Timer?

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
        
        // --- MODIFIED: Pass pairing state to background listener ---
        VoiceChatBackground.shared.startListening(
            with: messageNotifier,
            pairingState: pairing
        )
        // -----------------------------------------------------------
        
        startUnlinkCheck()
        
        haltManager.startListening()
        
        print("✅ [Home] services started")
    }
    
    private func stopServices() {
        unlinkTimer?.invalidate()
        unlinkTimer = nil
        
        WatchLocationManager.shared.stopLiveUpdates()
        HeartRateMonitor.shared.stopMonitoring()
        VoiceChatBackground.shared.stopListening()
        
        haltManager.stopListening()
        
        print("🛑 [Home] services stopped")
    }
    
    private func startUnlinkCheck() {
        unlinkTimer?.invalidate()
        unlinkTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            checkForUnlink()
        }
    }
    
    private func checkForUnlink() {
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
                            // CORRECTED: Badge logic removed from here
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 12))

                                Text("Pairing Code")
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundColor(brandBlue)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
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
                                    
                                    // Inject messageNotifier into the row
                                    ContactRow_Watch(name: name, messageNotifier: messageNotifier) {
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

                // MARK: - Overlays

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
                
                // ✅ HALT Overlay using the HaltReceiver ObservableObject
                if haltManager.isHaltActive {
                    HaltAlertView(message: "HALT SIGNAL RECEIVED") {
                        if haltManager.canDismiss {
                            haltManager.dismissHalt()
                        }
                    }
                }
                
                // MARK: New Message Overlay (Using top-center position)
                if messageNotifier.isMessageAlertActive {
                    MessagePopupView(notifier: messageNotifier)
                }

                // ✅ NEW: Off-wrist confirmation popup for the child
                if heartRateMonitor.showOffWristPrompt {
                                    OffWristPromptView(
                                        childName: pairing.childName.isEmpty ? "you" : pairing.childName,
                                        onStillHere: {
                                            HeartRateMonitor.shared.childConfirmedStillHere()
                                        }
                                        // ❌ Removed onNotHere argument
                                    )
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

// MARK: - Contact Row
struct ContactRow_Watch: View {
    var name: String
    @ObservedObject var messageNotifier: MessageNotifier // Inject notifier
    var onChatTapped: () -> Void
    private let buttons = Color("Buttons")
    private let stroke = Color.black.opacity(0.10)
    
    // Calculate the number of unheard messages for this specific guardian
    private var badgeCount: Int {
        // Uses the new function in MessageNotifier
        return messageNotifier.getUnheardCount(for: name)
    }

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
                    
                    // ✅ Unheard Message Badge UI (MOVED TO TOP-RIGHT)
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Color.red))
                            .offset(x: 15, y: -15) // FIXED OFFSET for Top-Right
                    }
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

// MARK: - SOS Confirm Sheet (No Change)
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

// MARK: - HALT Alert View (No Change)
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
        WKInterfaceDevice.current().play(.notification)
        
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            WKInterfaceDevice.current().play(.notification)
        }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
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


// MARK: - NEW Off-wrist prompt view

struct OffWristPromptView: View {
    let childName: String
    let onStillHere: () -> Void
    
    // Same timeout behavior
    @State private var timeRemaining = 15
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 14) {
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color("Blue").opacity(0.2))
                        .frame(width: 46, height: 46)
                    Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundColor(Color.green.opacity(0.9))
                }
                
                // Title
                Text("Watch Check")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                // Body text
                Text("Are you still wearing the watch?")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Timer badge
                let timerColor: Color = timeRemaining <= 5
                    ? .red
                    : Color.green.opacity(0.9)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                    Text("Timeout in \(Int(timeRemaining))s")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(timerColor.opacity(0.18))
                .foregroundColor(timerColor)
                .clipShape(Capsule())
                
                // Button
                Button(action: {
                    timer?.invalidate()
                    onStillHere()
                }) {
                    Text("Yes, I'm here")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.20))
            .cornerRadius(18)
            .padding(.horizontal, 12) // extra inset so nothing touches screen edges
        }
        .onAppear {
            WKInterfaceDevice.current().play(.notification)
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timeRemaining = 15
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if timeRemaining > 0 {
                DispatchQueue.main.async {
                    self.timeRemaining -= 1
                }
            } else {
                t.invalidate()
                HeartRateMonitor.shared.promptTimeoutAction()
            }
        }
    }
}



// MARK: - Background Voice Fetcher
final class VoiceChatBackground {
    static let shared = VoiceChatBackground()
    private var timer: Timer?
    private weak var pairing: PairingState?

    // --- Helper functions for per-guardian state management ---
    
    private func lastURL(for guardianId: String) -> String? {
        return UserDefaults.standard.string(forKey: "lastPlayedVoiceURL_\(guardianId)")
    }

    private func setLastURL(_ url: String, for guardianId: String) {
        UserDefaults.standard.set(url, forKey: "lastPlayedVoiceURL_\(guardianId)")
    }
    
    private func wasPlayed(for guardianId: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "lastPlayedVoicePlayed_\(guardianId)")
    }

    private func setWasPlayed(_ played: Bool, for guardianId: String) {
        UserDefaults.standard.set(played, forKey: "lastPlayedVoicePlayed_\(guardianId)")
    }
    // -------------------------------------------------------------

    func startListening(with notifier: MessageNotifier? = nil, pairingState: PairingState) {
        stopListening()
        self.pairing = pairingState
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchAllLatestMessages(notifier: notifier)
        }
        print("🎧 Background voice listener started (2s interval) for all guardians.")
    }

    func stopListening() {
        timer?.invalidate()
        timer = nil
        self.pairing = nil
        print("🛑 Background voice listener stopped")
    }

    // --- MODIFIED: Function to check all guardians (fixes Main Actor isolation) ---
    private func fetchAllLatestMessages(notifier: MessageNotifier? = nil) {
        Task { @MainActor in
            guard let pairing = self.pairing else { return }
            
            // Iterate through all linked guardian IDs (Accessed on Main Actor)
            for guardianId in pairing.linkedGuardianIDs {
                guard let childId = pairing.guardianChildIDs[guardianId], !childId.isEmpty else { continue }
                
                let senderName = pairing.guardianNames[guardianId] ?? "Guardian"
                
                // Call the network function (which runs on a background thread)
                self.fetchLatestMessage(
                    guardianId: guardianId,
                    childId: childId,
                    notifier: notifier,
                    senderName: senderName
                )
            }
        }
    }
    
    // --- MODIFIED: fetchLatestMessage using per-guardian state AND global tracking ---
    private func fetchLatestMessage(guardianId: String, childId: String, notifier: MessageNotifier? = nil, senderName: String) {
        
        let urlString = "https://getvoicemessagesapi-7gq4boqq6a-uc.a.run.app?guardianId=\(guardianId)&childId=\(childId)&limit=1"
        
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = json.first,
                  let audioURL = latest["audioURL"] as? String,
                  let sender = latest["sender"] as? String,
                  sender == "phone" else { return }

            let currentLastURL = self.lastURL(for: guardianId)
            let currentWasPlayed = self.wasPlayed(for: guardianId)

            // 1. Check if the latest message is the one we already saw and played for THIS guardian.
            if currentLastURL == audioURL && currentWasPlayed { return }

            // 2. If it's a NEW message (URL is different) for THIS guardian, update the URL and mark as unplayed/un-notified.
            if currentLastURL != audioURL {
                self.setLastURL(audioURL, for: guardianId)
                self.setWasPlayed(false, for: guardianId) // Reset the played status for the new message
                
                // ✅ FIX FOR GLOBAL PLAYBACK: Update the GLOBAL last played URL for fallback playback
                // This variable is checked by playQueueOrLatest when the queue is empty.
                UserDefaults.standard.set(audioURL, forKey: "lastPlayedVoiceURL")
            }

            // 3. If it's new (or the same but marked unplayed/un-notified), trigger the notification.
            if !self.wasPlayed(for: guardianId) {
                // Mark as notified/played *for this guardian's message*
                self.setWasPlayed(true, for: guardianId)
                
                notifier?.notifyNewMessage(audioURL: audioURL, senderName: senderName)
                
                print("🔊 New voice message detected from \(senderName) → triggering alert…")
            }
        }.resume()
    }
}

#Preview {
    HomeView_Watch()
}

