//
//  VoiceChatPhone.swift
//  AtSight (Consolidated Pro Version - Final Fix)
//

import SwiftUI
import AVFoundation
import UserNotifications
import FirebaseFirestore
import FirebaseAuth

// MARK: - Message Status

enum MessageStatus {
    case sending
    case sent
    case failed
}

// MARK: - 1. Data Model (Updated for Pre-loading, Status, and Retry Data)

struct VoiceMessage: Identifiable {
    let id: UUID
    let audioURL: String
    let sender: String // "phone" or "watch"
    let duration: Double
    let timestamp: Date
    let waveform: [Double]
    var playerItem: AVPlayerItem? = nil
    
    var status: MessageStatus
    // Temporary storage for local audio data (Base64 string)
    var localAudioBase64: String? = nil
}

// MARK: - 2. Component: RecordingWaveView

struct RecordingWaveView: View {
    @Binding var isRecording: Bool
    let micLevel: CGFloat
    let activeColor: Color
    
    @State private var bars = Array(repeating: CGFloat(2), count: 20)
    
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isRecording ? activeColor : activeColor.opacity(0.4))
                    .frame(width: 3, height: bars[i])
                    .animation(isRecording ? .linear(duration: 0.05) : nil, value: bars[i])
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onChange(of: micLevel) { level in
            updateBars(level: level)
        }
    }
    
    func updateBars(level: CGFloat) {
        let minH: CGFloat = 2
        let maxH: CGFloat = 36
        
        if level <= 0 {
            bars = bars.map { _ in minH }
            return
        }
        
        bars = bars.enumerated().map { index, _ in
            let relative = CGFloat(index % 5) / 5
            let height = minH + (maxH - minH) * level * (0.8 + relative * 0.2)
            return max(minH, min(maxH, height))
        }
        
        if isRecording {
            bars.append(bars.removeFirst())
        }
    }
}


// MARK: - 3. Component: StaticWaveformView

struct StaticWaveformView: View {
    let waveData: [CGFloat]
    let waveColor: Color
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(waveData.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(waveColor)
                    .frame(width: 3, height: waveData[i])
            }
        }.frame(height: 32)
    }
}


// MARK: - 4. Component: VoiceMessageCell (UPDATED FOR FAILED UI)

struct VoiceMessageCell: View {
    let message: VoiceMessage
    let isCurrentUser: Bool
    let playAction: () -> Void
    let retryAction: () -> Void
    
    private let chatColor = Color("Blue")
    private let watchColor = Color.orange
    
    @State private var isPlaying = false
    
    private func formatTime(_ t: Double) -> String {
        let s = Int(t.rounded()) % 60
        let m = Int(t.rounded()) / 60
        return String(format: "%01d:%02d", m, s)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 60) }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                
                // --- Message Capsule ---
                HStack(spacing: 12) {
                    
                    if message.status == .sending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(width: 24, height: 24)
                    } else if message.status == .sent {
                        Button { playAction() } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    } else { // Failed
                        // ✅ FIX: Inside capsule: Red round arrow button for retry
                        Button(action: retryAction) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                        }
                    }
                    
                    StaticWaveformView(
                        waveData: message.waveform.map { CGFloat($0) },
                        waveColor: message.status == .failed ? .white.opacity(0.4) : .white.opacity(0.8)
                    )
                    
                    Text(formatTime(message.duration))
                        .font(.callout)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(backgroundColor)
                )
                
                // --- Status and Retry Label ---
                HStack(spacing: 4) {
                    
                    if message.status == .failed {
                        Text("Failed to send")
                            .font(.caption2)
                            .foregroundColor(.red)
                        
                        // ✅ FIX: Under capsule: Exclamation mark icon
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        if isCurrentUser && message.status == .sent {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(chatColor)
                        }
                        Text(formatTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
    
    private var backgroundColor: Color {
        if message.status == .failed {
            return .gray.opacity(0.5)
        } else if isCurrentUser {
            return chatColor
        } else {
            return watchColor
        }
    }
}

// MARK: - 5. Main View: VoiceChatPhone

struct VoiceChatPhone: View {
    
    let guardianId: String
    let childId: String
    let childName: String
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var messages: [VoiceMessage] = []
    @State private var recorder: AVAudioRecorder?
    @State private var player: AVPlayer?
    @State private var waveTimer: Timer?
    @State private var timeTimer: Timer?
    @State private var autoRefreshTimer: Timer?
    
    @State private var isRecording = false
    @State private var recordedURL: URL? = nil
    @State private var recordedDuration: Double = 0
    @State private var recordedTime: Double = 0
    @State private var isPreviewing = false
    @State private var isUploading = false
    @State private var currentMicLevel: CGFloat = 0
    @State private var previewBars: [CGFloat] = Array(repeating: 4, count: 20)
    
    @State private var tempMessageId: UUID?
    
    @AppStorage("lastVoiceNotifiedURL") private var sharedLastNotifiedURL: String = ""
    
    private let uploadURL = URL(string: "https://uploadvoicemessageapi-7gq4boqq6a-uc.a.run.app")!
    private let fetchURL = URL(string: "https://getvoicemessagesapi-7gq4boqq6a-uc.a.run.app")!

    var body: some View {
        
        VStack(spacing: 0) {
            
            // ========================
            // FIXED TOP BAR
            // ========================
            HStack(alignment: .center) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color("BlackFont"))
                }
                
                Spacer()
                
                Text(childName).font(.headline).lineLimit(1)
                
                Spacer()
                
                Circle().frame(width: 32, height: 32)
                    .foregroundColor(Color("Blue").opacity(0.8))
                    .overlay(Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    )
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .shadow(color: .gray.opacity(0.15), radius: 2, y: 1)
            
            
            // ========================
            // CHAT LIST
            // ========================
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { msg in
                            VoiceMessageCell(
                                message: msg,
                                isCurrentUser: msg.sender == "phone",
                                playAction: {
                                    if let item = msg.playerItem {
                                        playAudio(from: item)
                                    } else {
                                        playAudioFallback(from: msg.audioURL)
                                    }
                                },
                                retryAction: {
                                    retryUpload(message: msg)
                                }
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                }
                .onAppear {
                    requestNotificationPermission()
                    startAutoRefresh()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            Divider()
            
            
            // ========================
            // RECORDING INTERFACE
            // ========================
            VStack(spacing: 12) {
                if isRecording {
                    recordingActiveView

                } else if isPreviewing, recordedURL != nil {
                    previewSendView

                } else {
                    tapToRecordView
                }
            }
            .frame(height: 120)        // ← توحيد الارتفاع ومنع الحركة
            .padding(.horizontal, 10)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))

        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onDisappear { cleanupTimers() }
    }
    
    // MARK: - Sub-Views (omitted for brevity)

    var recordingActiveView: some View {
        HStack {
            Text(formatTime(recordedTime))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.red)
            
            Spacer()
            
            RecordingWaveView(
                isRecording: $isRecording,
                micLevel: currentMicLevel,
                activeColor: .red
            )
            .frame(width: 120, height: 36)
            
            Spacer()
            
            Button { stopRecordingAndEnterPreview() } label: {
                Image(systemName: "stop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .foregroundColor(Color("button"))


            }
        }
        .padding(.horizontal, 10)
    }

    var previewSendView: some View {
        HStack {
            Button { cancelRecording() } label: {
                Image(systemName: "trash.circle.fill")
                       .resizable()
                       .scaledToFit()
                       .frame(width: 46, height: 46)
                       .foregroundColor(.red)
            }
            
            Spacer(minLength: 15)
            
            HStack(spacing: 10) {
                Button {
                    if let url = recordedURL { playAudioFallback(from: url.absoluteString) }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color("BlackFont"))
                }
                
                StaticWaveformView(
                    waveData: previewBars,
                    waveColor: Color.gray.opacity(0.6)
                )
                
                Text(formatTime(recordedDuration))
                    .foregroundColor(Color("BlackFont"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(radius: 1)
            )
            
            Spacer()
            
            Button {
                if let url = recordedURL { uploadToAPI(fileURL: url) }
            } label: {
                Circle()
                    .fill(Color("button"))   // ← نفس لون زر المايك
                    .frame(width: 46, height: 46)   // ←統一 الحجم
                    .overlay(
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    )
            }

        }
    }

    var tapToRecordView: some View {
        VStack(spacing: 10) {

            Button { startRecording() } label: {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                .frame(width: 150, height: 55) // أعرض
                .background(
                    Capsule()
                        .fill(Color("button"))
                )
                .shadow(radius: 5, y: 3)
            }
            .padding(.top, 14) // علشان مايلصق بالخط الرمادي

            Text("Tap to record")
                .foregroundColor(Color("button"))
                .font(.system(size: 16, weight: .medium))
        }
    }

    // MARK: - Recording Logic (AVFoundation)

    func normalize(_ db: Float) -> CGFloat {
        if db < -60 { return 0 }
        return CGFloat((db + 60) / 60)
    }

    private func startRecording() {
        // ... (omitted setup code)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true)
            
            let url = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("record_\(UUID().uuidString).m4a")
            
            let settings: [String : Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            
            recordedURL = url
            isRecording = true
            recordedTime = 0
            
            timeTimer?.invalidate()
            timeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordedTime += 0.1
            }
            
            waveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                if let rec = recorder, isRecording {
                    rec.updateMeters()
                    currentMicLevel = normalize(rec.peakPower(forChannel: 0))
                }
            }
            
        } catch {
            print("Recorder error:", error.localizedDescription)
        }
    }

    private func stopRecordingAndEnterPreview() {
        isRecording = false

        waveTimer?.invalidate()
        timeTimer?.invalidate()

        let finalDuration = recordedTime
        
        recorder?.stop()

        recordedDuration = finalDuration
        isPreviewing = true
        
        print("✅ Recording stopped (\(recordedDuration)s)")
        
        if let url = recordedURL {
            generatePreviewWaveform(url: url)
        }
    }

    private func cancelRecording() {
        waveTimer?.invalidate()
        timeTimer?.invalidate()
        recorder?.stop()
        
        isRecording = false
        isPreviewing = false
        recordedTime = 0
    }
    
    // MARK: - Playback 1: Optimized for Pre-loaded Items
    
    private func playAudio(from item: AVPlayerItem) {
        player?.pause()
        
        if player?.currentItem == item {
            player?.seek(to: .zero)
        } else {
            player = AVPlayer(playerItem: item)
        }
        
        print("▶️ Playing pre-loaded item")
        player?.play()
    }

    // MARK: - Playback 2: Fallback/Local Audio
    
    private func playAudioFallback(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL:", urlString)
            return
        }

        print("▶️ Playing Fallback/Local:", url.absoluteString)
        player?.pause()
        player = AVPlayer(url: url)
        player?.play()
    }


    // MARK: - Waveform (omitted for brevity)

    func generatePreviewWaveform(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: UInt32(file.length)
            )!
            try file.read(into: buffer)
            
            let channel = buffer.floatChannelData![0]
            let totalSamples = Int(buffer.frameLength)
            
            let steps = 20
            let jump = max(1, totalSamples / steps)
            
            previewBars = (0..<steps).map { i in
                let amp = abs(channel[i * jump])
                return max(3, min(28, CGFloat(amp) * 160))
            }
            
        } catch {
            print("Waveform error:", error.localizedDescription)
        }
    }
    
    // MARK: - Optimistic Insertion Logic
    
    private func insertSendingMessage(duration: Double, waveform: [Double], base64: String) {
        let tempID = UUID()
        let tempMessage = VoiceMessage(
            id: tempID,
            audioURL: "",
            sender: "phone",
            duration: duration,
            timestamp: Date(),
            waveform: waveform,
            playerItem: nil,
            status: .sending,
            localAudioBase64: base64
        )
        
        messages.append(tempMessage)
        tempMessageId = tempID
    }

    // MARK: - Upload API (Initial Upload)

    private func uploadToAPI(fileURL: URL) {
        guard !isUploading else { return }
        isUploading = true
        isPreviewing = false
        
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let base64 = data.base64EncodedString()
        
        let waveformData = previewBars.map { Double($0) }
        
        // 1. Insert the message immediately before the network request
        insertSendingMessage(duration: recordedDuration, waveform: waveformData, base64: base64)
        
        // 2. Start the actual upload process
        performUpload(base64: base64, duration: recordedDuration, waveform: waveformData, tempMessageId: tempMessageId!)
    }

    // MARK: - Retry Upload Logic
    
    private func retryUpload(message: VoiceMessage) {
        guard message.status == .failed,
              let base64 = message.localAudioBase64,
              let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

        // 1. Change the status back to sending
        messages[index].status = .sending
        tempMessageId = message.id
        
        // 2. Start the upload using the stored Base64 data
        performUpload(base64: base64, duration: message.duration, waveform: message.waveform, tempMessageId: message.id)
    }
    
    // MARK: - Consolidated Upload Function (Initial & Retry)
    
    private func performUpload(base64: String, duration: Double, waveform: [Double], tempMessageId: UUID) {
        
        let body: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "sender": "phone",
            "audioBase64": base64,
            "duration": duration,
            "ts": Date().timeIntervalSince1970,
            "waveform": waveform
        ]
        
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { _, resp, err in
            DispatchQueue.main.async {
                isUploading = false
                
                guard let index = messages.firstIndex(where: { $0.id == tempMessageId }) else { return }

                // Check for network error or non-200 status code
                if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                    print("❌ Upload failed.")
                    // Failure: Set status back to 'failed'
                    messages[index].status = .failed
                    return
                }
                
                // Success: Remove local failed/sending copy and fetch definitive list
                messages.remove(at: index)
                fetchMessages()
            }
        }.resume()
    }

    // MARK: - Fetch Messages (Updated for Pre-loading)

    private func fetchMessages() {
        var comps = URLComponents(url: fetchURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "guardianId", value: guardianId),
            .init(name: "childId", value: childId),
            .init(name: "limit", value: "20")
        ]
        
        URLSession.shared.dataTask(with: comps.url!) { data, _, _ in
            guard let data else { return }
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                DispatchQueue.main.async {
                    messages = arr.compactMap { d in
                        
                        let urlString = d["audioURL"] as? String ?? ""
                        let waveformData = d["waveform"] as? [Double] ?? Array(repeating: 4.0, count: 20)
                        
                        guard let url = URL(string: urlString) else { return nil }
                        
                        // Create the AVPlayerItem here to start buffering in the background
                        let item = AVPlayerItem(url: url)
                        
                        return VoiceMessage(
                            id: UUID(),
                            audioURL: urlString,
                            sender: d["sender"] as? String ?? "",
                            duration: d["duration"] as? Double ?? 0,
                            timestamp: Date(timeIntervalSince1970: d["ts"] as? Double ?? 0),
                            waveform: waveformData,
                            playerItem: item,
                            status: .sent
                        )
                    }
                    
                    messages.sort(by: { $0.timestamp < $1.timestamp })
                }
            }
        }.resume()
    }

    // MARK: - Helpers & Cleanup (omitted for brevity)

    private func startAutoRefresh() {
        fetchMessages()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            fetchMessages()
        }
    }

    private func cleanupTimers() {
        recorder?.stop()
        player?.pause()
        waveTimer?.invalidate()
        timeTimer?.invalidate()
        autoRefreshTimer?.invalidate()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied:", error?.localizedDescription ?? "")
            }
        }
    }


    private func formatTime(_ t: Double) -> String {
        let s = Int(t.rounded()) % 60
        let m = Int(t.rounded()) / 60
        return String(format: "%01d:%02d", m, s)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    private func showAndSaveNotificationOnce(for audioURL: String, childName: String) {
        guard sharedLastNotifiedURL != audioURL else { return }
        sharedLastNotifiedURL = audioURL
    }
}
