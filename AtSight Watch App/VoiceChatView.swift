//
//  VoiceChatView.swift
//  AtSight (WatchKit Extension)
//
//  Updated by Leon on 28/10/2025
//  ✅ Prevents replaying the same voice message twice (shared memory with HomeView)
//  ✅ Fixed @State property wrapper errors
//

import SwiftUI
import AVFoundation
import WatchKit

struct VoiceChatView: View {
    @State private var recorder: AVAudioRecorder?
    @State private var player: AVPlayer?
    @State private var isRecording = false
    @State private var audioURL: URL?
    @State private var timer: Timer?
    @State private var isPlaying = false

    // ✅ IDs
    @State private var guardianId: String = ""
    @State private var childId: String = ""
    @State private var childName: String = ""
    @State private var parentName: String = ""

    // ✅ Shared playback tracking (no @State needed)
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
            // MARK: - Header
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.blue)
                Text(parentName.isEmpty ? "Parent" : parentName)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()

            // MARK: - Mic Button
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
            fetchIDsFromDefaults()
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
                guard granted else {
                    print("🚫 Mic permission denied")
                    return
                }

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
                    DispatchQueue.main.async {
                        isRecording = true
                    }
                    print("🎙️ Recording started")
                } catch {
                    print("❌ Recorder error:", error.localizedDescription)
                }
            }
        } catch {
            print("❌ Audio session error:", error.localizedDescription)
        }
    }

    // MARK: - Stop Recording
    private func stopRecording() {
        recorder?.stop()
        isRecording = false
        guard let url = audioURL else { return }
        print("✅ Recording stopped, uploading…")
        uploadToAPI(fileURL: url)
    }

    // MARK: - Upload Voice
    private func uploadToAPI(fileURL: URL, retryCount: Int = 0) {
        guard !guardianId.isEmpty, !childId.isEmpty else {
            print("⚠️ Missing guardianId or childId — cannot upload")
            return
        }

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

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                print("❌ Upload failed:", err.localizedDescription)
                return
            }

            if let http = resp as? HTTPURLResponse {
                print("✅ Uploaded with status:", http.statusCode)
            }
        }.resume()
    }

    // MARK: - Auto Fetch + Prevent Repeat
    private func startAutoFetch() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            fetchLatestMessage()
        }
    }

    private func fetchLatestMessage() {
        guard !guardianId.isEmpty, !childId.isEmpty else { return }

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
                print("🎧 New message detected → playing…")
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

    // MARK: - IDs
    private func fetchIDsFromDefaults() {
        guardianId = UserDefaults.standard.string(forKey: "guardianId") ?? ""
        childId = UserDefaults.standard.string(forKey: "currentChildId") ?? ""
        childName = UserDefaults.standard.string(forKey: "childDisplayName") ?? ""
        parentName = UserDefaults.standard.string(forKey: "parentDisplayName") ?? ""
        print("⌚️ [VoiceChatView] Loaded IDs → guardianId: \(guardianId), childId: \(childId)")
    }
}

#Preview { VoiceChatView() }
