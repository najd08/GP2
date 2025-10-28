//
//  VoiceChatPhone.swift
//  AtSight
//
//  Updated by Leon on 29/10/2025
//  ✅ Shows and saves notification only once (shared between Main & Chat)
//  ✅ Syncs Firestore notifications with local ones
//

import SwiftUI
import AVFoundation
import UserNotifications
import FirebaseFirestore

struct VoiceChatPhone: View {
    let guardianId: String
    let childId: String
    let childName: String

    @State private var messages: [VoiceMessage] = []
    @State private var recorder: AVAudioRecorder?
    @State private var player: AVPlayer?
    @State private var isRecording = false
    @State private var recordedURL: URL? = nil
    @State private var recordedDuration: Double = 0
    @State private var isPreviewing = false
    @State private var isUploading = false
    @State private var timer: Timer?

    // ✅ Shared flag across all views (prevents duplicates globally)
    @AppStorage("lastVoiceNotifiedURL") private var sharedLastNotifiedURL: String = ""

    private let uploadURL = URL(string: "https://uploadvoicemessageapi-7gq4boqq6a-uc.a.run.app")!
    private let fetchURL = URL(string: "https://getvoicemessagesapi-7gq4boqq6a-uc.a.run.app")!

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 34, height: 34)
                        .foregroundColor(.gray)
                    Text(childName)
                        .font(.headline)
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: fetchMessages) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.95))
                .shadow(radius: 1)

                // MARK: Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(messages) { msg in
                                HStack {
                                    if msg.sender == "phone" { Spacer() }

                                    VStack(alignment: msg.sender == "phone" ? .trailing : .leading, spacing: 6) {
                                        Button(action: { playAudio(from: msg.audioURL) }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "play.circle.fill")
                                                if msg.duration > 1 {
                                                    Text("\(Int(msg.duration))s")
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .foregroundColor(.white)
                                            .background(msg.sender == "phone" ? Color.blue : Color.gray.opacity(0.7))
                                            .cornerRadius(20)
                                        }

                                        Text(formatTimestamp(msg.timestamp))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }

                                    if msg.sender == "watch" { Spacer() }
                                }
                                .padding(.horizontal)
                                .id(msg.id)
                            }
                        }
                    }
                    .onAppear {
                        startAutoRefresh()
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // MARK: - Recording Controls
                VStack(spacing: 10) {
                    if isPreviewing, recordedURL != nil {
                        VStack {
                            Text("Preview your recording")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            HStack(spacing: 20) {
                                if let url = recordedURL {
                                    Button {
                                        playAudio(from: url.absoluteString)
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Button {
                                        uploadToAPI(fileURL: url)
                                    } label: {
                                        Label("Send", systemImage: "paperplane.fill")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                }

                                Button {
                                    recordedURL = nil
                                    isPreviewing = false
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                        .padding(.bottom, 8)
                    } else {
                        Button {
                            isRecording ? stopRecording() : startRecording()
                        } label: {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .resizable()
                                .frame(width: 90, height: 90)
                                .foregroundColor(isRecording ? .red : Color(red: 0.71, green: 0.85, blue: 0.64))
                                .shadow(radius: 4)
                        }
                    }

                    if isUploading {
                        ProgressView("Uploading...")
                            .padding(.bottom)
                    }
                }
                .padding(.bottom, 16)
                .background(Color.white)
            }
        }
        .onAppear {
            requestNotificationPermission()
        }
        .onDisappear {
            recorder?.stop()
            player?.pause()
            stopAutoRefresh()
        }
    }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied:", error?.localizedDescription ?? "")
            }
        }
    }

    /// ✅ Shows and saves notification once per message globally
    private func showAndSaveNotificationOnce(for audioURL: String, childName: String) {
        guard sharedLastNotifiedURL != audioURL else {
            print("🚫 Skipping duplicate notification for \(childName)")
            return
        }

        sharedLastNotifiedURL = audioURL

        // 🔔 Show local notification
        let content = UNMutableNotificationContent()
        content.title = "New voice message from \(childName)"
        content.body = "🎙️ \(childName) sent you a new voice message."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)

        print("🔔 Notification displayed once for \(childName)")

        // 🧾 Save notification to Firestore
        let db = Firestore.firestore()
        let notifRef = db
            .collection("guardians")
            .document(guardianId)
            .collection("notifications")
            .document()

        let data: [String: Any] = [
            "title": "New Voice Message",
            "body": "\(childName) sent a new voice message 🎙️",
            "audioURL": audioURL,
            "timestamp": Timestamp(date: Date())
        ]

        notifRef.setData(data) { error in
            if let error = error {
                print("❌ Failed to save notification:", error.localizedDescription)
            } else {
                print("✅ Notification saved in Firestore for \(childName)")
            }
        }
    }

    // MARK: - Auto Refresh
    private func startAutoRefresh() {
        fetchMessages()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            fetchMessages()
        }
    }

    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Fetch Messages
    private func fetchMessages() {
        var comps = URLComponents(url: fetchURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "guardianId", value: guardianId),
            URLQueryItem(name: "childId", value: childId),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = comps.url else { return }

        let oldMessages = self.messages

        URLSession.shared.dataTask(with: url) { data, _, err in
            guard let data, err == nil else { return }
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                DispatchQueue.main.async {
                    self.messages = arr.compactMap { d in
                        guard let url = d["audioURL"] as? String else { return nil }
                        return VoiceMessage(
                            id: UUID(),
                            audioURL: url,
                            sender: d["sender"] as? String ?? "parent",
                            duration: d["duration"] as? Double ?? 0,
                            timestamp: Date(timeIntervalSince1970: d["ts"] as? Double ?? 0)
                        )
                    }.sorted(by: { $0.timestamp < $1.timestamp })

                    // ✅ If new message arrived → show + save once globally
                    if let latest = self.messages.last,
                       latest.sender == "watch",
                       oldMessages.last?.audioURL != latest.audioURL {
                        showAndSaveNotificationOnce(for: latest.audioURL, childName: childName)
                    }
                }
            }
        }.resume()
    }

    // MARK: - Recording Logic
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("record_\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            recordedURL = url
            isRecording = true
            print("🎙️ Recording started")
        } catch {
            print("❌ Recorder error:", error.localizedDescription)
        }
    }

    private func stopRecording() {
        recorder?.stop()
        recordedDuration = recorder?.currentTime ?? 0
        isRecording = false
        isPreviewing = true
        print("✅ Recording stopped (\(recordedDuration)s)")
    }

    // MARK: - Upload Logic
    private func uploadToAPI(fileURL: URL) {
        guard !isUploading else { return }
        isUploading = true

        guard let data = try? Data(contentsOf: fileURL) else { return }
        let base64 = data.base64EncodedString()

        let body: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "sender": "phone",
            "audioBase64": base64,
            "duration": recordedDuration,
            "ts": Date().timeIntervalSince1970
        ]

        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { _, resp, err in
            DispatchQueue.main.async {
                isUploading = false
            }
            if let err = err {
                print("❌ Upload error:", err.localizedDescription)
                return
            }
            if let http = resp as? HTTPURLResponse {
                print("✅ Uploaded (status \(http.statusCode))")
                fetchMessages()
                isPreviewing = false
            }
        }.resume()
    }

    // MARK: - Play
    private func playAudio(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        player = AVPlayer(url: url)
        player?.play()
    }

    // MARK: - Timestamp Formatter
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Model
struct VoiceMessage: Identifiable {
    let id: UUID
    let audioURL: String
    let sender: String
    let duration: Double
    let timestamp: Date
}

#Preview {
    VoiceChatPhone(
        guardianId: "ue1vLwRTSiMi851RyQSCT8IOEcv1",
        childId: "05FB60F1-E1D7-424E-98B1-AEA6878DEACE",
        childName: "Sarah"
    )
}
