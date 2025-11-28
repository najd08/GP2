// EDIT BY RIYAM: Modified to accept guardianId/names as parameters to support multi-guardian chats. Removed internal @State loading for IDs.

import SwiftUI
import AVFoundation
import WatchKit

struct VoiceChatView: View {
    // ✅ Parameters passed from HomeView
    var guardianId: String
    var childId: String
    var childName: String
    var parentName: String

    @State private var recorder: AVAudioRecorder?
    @State private var player: AVPlayer?
    @State private var isRecording = false
    @State private var audioURL: URL?
    @State private var timer: Timer?
    
    // Shared playback tracking
    private var lastURL: String? {
        get { UserDefaults.standard.string(forKey: "lastPlayedVoiceURL") }
        set { UserDefaults.standard.set(newValue, forKey: "lastPlayedVoiceURL") }
    }

    private var wasPlayed: Bool {
        get { UserDefaults.standard.bool(forKey: "lastPlayedVoicePlayed") }
        set { UserDefaults.standard.set(newValue, forKey: "lastPlayedVoicePlayed") }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.blue)
                Text(parentName)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()

            // Mic Button
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.green.opacity(0.8))
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
        .onAppear {
            startAutoFetch()
        }
        .onDisappear {
            timer?.invalidate()
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

    // MARK: - Fetch
    private func startAutoFetch() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            fetchLatestMessage()
        }
    }

    private func fetchLatestMessage() {
        guard let url = URL(string:
            "https://getvoicemessagesapi-7gq4boqq6a-uc.a.run.app?guardianId=\(guardianId)&childId=\(childId)&limit=1"
        ) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = json.first,
                  let audioURL = latest["audioURL"] as? String,
                  let sender = latest["sender"] as? String,
                  sender == "phone" else { return }

            if self.lastURL == audioURL, self.wasPlayed { return }

            if self.lastURL != audioURL {
                UserDefaults.standard.set(audioURL, forKey: "lastPlayedVoiceURL")
                UserDefaults.standard.set(false, forKey: "lastPlayedVoicePlayed")
            }

            let wasPlayed = UserDefaults.standard.bool(forKey: "lastPlayedVoicePlayed")
            if !wasPlayed {
                UserDefaults.standard.set(true, forKey: "lastPlayedVoicePlayed")
                WKInterfaceDevice.current().play(.notification)
                DispatchQueue.main.async {
                    playAudio(from: audioURL)
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
