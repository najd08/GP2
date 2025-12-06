// EDIT BY RIYAM: Modified to accept guardianId/names as parameters to support multi-guardian chats. Removed internal @State loading for IDs.
// UPDATED BY RIYAM: Integrated MessageNotifier for universal popup and applied new color requirements (Req 1 & 3).
// UPDATED BY RIYAM: Corrected header colors.
// UPDATED BY RIYAM: ADDED Last Messages button to chat page with counter badge, and adjusted size to match profile icon.

import SwiftUI
import AVFoundation
import WatchKit

// Re-using the MessageNotifier class from HomeView for notification handling inside chat
private let messageNotifier = MessageNotifier.shared

struct VoiceChatView: View {
    @ObservedObject private var messageNotifier = MessageNotifier.shared
    
    var guardianId: String
    var childId: String
    var childName: String
    var parentName: String // هذا هو المفتاح لتصفية الرسائل

    @State private var recorder: AVAudioRecorder?
    @State private var player: AVPlayer?
    @State private var isRecording = false
    @State private var audioURL: URL?
    @State private var timer: Timer?
    
    // MARK: - Style (Requirement 3 & Chat Header Color Fixes)
    private let bgColor   = Color(red: 0.965, green: 0.975, blue: 1.00)
    private let buttons   = Color("Buttons")
    private let brandBlue = Color("Blue")

    // --- NEW: Per-Guardian Tracking Helpers (Same as HomeView 2) ---
    private func lastURL() -> String? {
        return UserDefaults.standard.string(forKey: "lastPlayedVoiceURL_\(guardianId)")
    }

    private func setLastURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "lastPlayedVoiceURL_\(guardianId)")
    }
    
    private func wasPlayed() -> Bool {
        return UserDefaults.standard.bool(forKey: "lastPlayedVoicePlayed_\(guardianId)")
    }

    private func setWasPlayed(_ played: Bool) {
        UserDefaults.standard.set(played, forKey: "lastPlayedVoicePlayed_\(guardianId)")
    }
    // ----------------------------------------------------------------
    
    // ✅ NEW: Computed property to get the unheard count SPECIFICALLY for this guardian.
    private var unheardCountForThisGuardian: Int {
        // نستخدم اسم الوصي الحالي parentName لتصفية قائمة الانتظار العالمية
        return messageNotifier.getUnheardCount(for: parentName)
    }

    var body: some View {
        // MARK: Apply Background Color (Requirement 3)
        ZStack {
            bgColor.ignoresSafeArea()
            
            VStack(spacing: 12) {
                // MARK: Header (Name and Icon Color Fixes, and Last Messages Button)
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28) // Profile Icon Size
                        .foregroundColor(brandBlue)
                    Text(parentName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black) // Name in Black
                    
                    Spacer()
                    
                    // MARK: Last Messages Button (Size Adjusted to 28x28)
                    Button(action: {
                        // ✅ MODIFIED: استدعاء الدالة المُعدلة وتمرير اسم الوصي الحالي (ParentName)
                        messageNotifier.playQueueOrLatest(for: parentName)
                    }) {
                        ZStack {
                            Image(systemName: "message.circle.fill")
                                .resizable()
                                .frame(width: 28, height: 28) // Matched Profile Icon Size
                                .foregroundColor(buttons)
                            
                            // Counter Badge (The red circle is conditional)
                            // --- MODIFIED: Show badge using the SPECIFIC guardian count ---
                            if unheardCountForThisGuardian > 0 {
                                Text("\(unheardCountForThisGuardian)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 14, height: 14)
                                    .background(Circle().fill(Color.red))
                                    .offset(x: 10, y: -10)
                            }
                            // ---------------------------------------------
                        }
                    }
                    .buttonStyle(.plain)

                }
                .padding(.horizontal)
                .padding(.top, 4)

                Spacer()

                // Mic Button
                ZStack {
                    // MARK: Mic Row Background Color (Requirement 3)
                    Circle()
                        .fill(isRecording ? Color.red : buttons.opacity(0.8)) // Use buttons color
                        .frame(width: 80, height: 80)
                        .shadow(radius: 5)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        )
                        .onTapGesture {
                            isRecording ? stopRecording() : startRecording()
                        }
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                }

                Spacer()
            }
        }
        .onAppear {
            startAutoFetch()
        }
        .onDisappear {
            timer?.invalidate()
        }
        // MARK: New Message Overlay (Ensuring popup appears in chat)
        .overlay {
            if messageNotifier.isMessageAlertActive {
                MessagePopupView(notifier: messageNotifier)
            }
        }
    }

    // MARK: - Start Recording
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            session.requestRecordPermission { granted in
                guard granted else { return }

                let url = FileManager.default.temporaryDirectory.appendingPathComponent("watch_record.m4a")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]

                do {
                    recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder?.record()
                    audioURL = url
                    DispatchQueue.main.async { isRecording = true }
                } catch { print(error) }
            }
        } catch { print(error) }
    }

    // MARK: - Stop Recording
    private func stopRecording() {
        recorder?.stop()
        isRecording = false
        guard let url = audioURL else { return }
        uploadToAPI(fileURL: url)
    }

    // MARK: - Upload
    private func uploadToAPI(fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let base64 = data.base64EncodedString()
        guard let url = URL(string: "https://uploadvoicemessageapi-7gq4boqq6a-uc.a.run.app") else { return }

        let body: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "sender": "watch",
            "audioBase64": base64,
            "duration": recorder?.currentTime ?? 3.0,
            "ts": Date().timeIntervalSince1970
        ]

        APIHelper.shared.post(to: url.absoluteString, body: body)
    }

    // MARK: - Fetch (MODIFIED to use per-guardian tracking)
    private func startAutoFetch() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            fetchLatestMessage()
        }
    }

    // VoiceChatView.swift (Inside struct VoiceChatView)
    private func fetchLatestMessage() {
        guard let url = URL(string:
            "https://getvoicemessagesapi-7gq4boqq6a-uc.a.run.app?guardianId=\(guardianId)&childId=\(childId)&limit=1"
        ) else { return }

        // NOTE: [self] is used here instead of [weak self] because VoiceChatView is a struct.
        URLSession.shared.dataTask(with: url) { [self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = json.first,
                  let audioURL = latest["audioURL"] as? String,
                  let sender = latest["sender"] as? String,
                  sender == "phone" else { return }

            let senderName = latest["senderName"] as? String ?? "Guardian"
            
            // --- UPDATED LOGIC (using per-guardian tracking helpers) ---
            let currentLastURL = self.lastURL()
            let currentWasPlayed = self.wasPlayed()

            if currentLastURL == audioURL && currentWasPlayed { return }

            if currentLastURL != audioURL {
                self.setLastURL(audioURL)
                self.setWasPlayed(false)
                
                // ✅ Update the GLOBAL last played URL for fallback playback
                UserDefaults.standard.set(audioURL, forKey: "lastPlayedVoiceURL")
            }

            if !self.wasPlayed() {
                self.setWasPlayed(true)
                
                messageNotifier.notifyNewMessage(audioURL: audioURL, senderName: senderName)
            }
            // ---------------------
        }.resume()
    }
}
