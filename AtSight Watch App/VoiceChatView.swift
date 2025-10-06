//
//  VoiceChatView.swift
//  AtSight (WatchKit Extension)
//

import SwiftUI
import AVFoundation
import WatchConnectivity

// MARK: - Model لعرض الفويسات محليًا
struct VoiceMessage: Identifiable, Equatable {
    let id = UUID()
    let isSender: Bool
    let timestamp: Date
    let localURL: URL?
    let duration: TimeInterval
}

// MARK: - الصفحة (مفعّلة بالتسجيل والإرسال)
struct VoiceChatView: View {
    @StateObject private var recorder = WatchAudioRecorder()
    @StateObject private var player   = SimpleAudioPlayer()
    @StateObject private var outbox   = WatchConnectivityOutbox()

    @State private var isRecording = false
    @State private var goHome = false
    @State private var messages: [VoiceMessage] = []

    // بدّلي هذي القيم حسب نظامك (PairingState/UserDefaults)
    private let parentName: String = (UserDefaults.standard.string(forKey: "parentDisplayName") ?? "Mom")
    private let childId: String    = (UserDefaults.standard.string(forKey: "currentChildId") ?? "unknownChild")

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .onTapGesture { goHome = true }

                        Spacer()

                        HStack(spacing: 4) {
                            Text(parentName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)

                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)

                    // الرسائل الصوتية (محلية لعرض آخر ما سُجّل)
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(messages) { msg in
                                VoiceMessageBubble(
                                    isSender: msg.isSender,
                                    timestamp: timeText(msg.timestamp),
                                    durationText: durationText(msg.duration),
                                    playAction: {
                                        if let url = msg.localURL { player.play(url: url) }
                                    },
                                    isPlaying: player.isPlaying
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }

                    Spacer()

                    // زر التسجيل (ضغط مطوّل يبدأ/ينهي)
                    HStack {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color("button"))
                                .frame(width: isRecording ? 60 : 40,
                                       height: isRecording ? 60 : 40)
                                .shadow(color: (isRecording ? Color.red : Color("button")).opacity(0.4),
                                        radius: isRecording ? 10 : 0)

                            Image(systemName: "mic.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                        }
                        .offset(y: isRecording ? -10 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                        .gesture(
                            LongPressGesture(minimumDuration: 0.1)
                                .onChanged { _ in
                                    guard !isRecording else { return }
                                    isRecording = true
                                    recorder.start(childId: childId) { ok, err in
                                        if !ok { print("❌ Start record error:", err ?? "unknown") }
                                    }
                                }
                                .onEnded { _ in
                                    guard isRecording else { return }
                                    isRecording = false
                                    recorder.stop { url, dur in
                                        guard let url = url, dur > 0.1 else { return }

                                        // أضف رسالة للواجهة
                                        messages.append(
                                            VoiceMessage(isSender: true,
                                                         timestamp: Date(),
                                                         localURL: url,
                                                         duration: dur)
                                        )

                                        // أرسل الملف للآيفون مع بيانات بسيطة
                                        outbox.sendVoiceMessage(fileURL: url, metadata: [
                                            "type": "voice",
                                            "childId": childId,
                                            "sender": "watch",
                                            "duration": "\(dur)",
                                            "timestamp": "\(Date().timeIntervalSince1970)"
                                        ])
                                    }
                                }
                        )

                        Spacer()
                    }
                    .padding(.bottom, 24)

                    // الرجوع
                    NavigationLink(destination: HomeView_Watch(), isActive: $goHome) {
                        EmptyView()
                    }
                    .hidden()
                }
                .frame(width: geometry.size.width,
                       height: geometry.size.height,
                       alignment: .top)
            }
        }
        .onAppear { outbox.activate() } // تفعيل اتصال الساعة بالآيفون
        .navigationBarBackButtonHidden(true)
    }

    // MARK: Helpers
    private func durationText(_ sec: TimeInterval) -> String {
        let s = Int(sec.rounded())
        return String(format: "%02d:%02d", s/60, s%60)
    }
    private func timeText(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - فقاعة رسالة صوتية مع زر تشغيل
struct VoiceMessageBubble: View {
    var isSender: Bool
    var timestamp: String
    var durationText: String
    var playAction: () -> Void
    var isPlaying: Bool

    var body: some View {
        VStack(alignment: isSender ? .trailing : .leading, spacing: 2) {
            HStack {
                if isSender { Spacer() }

                HStack(spacing: 6) {
                    Button(action: playAction) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(isSender ? .white : .gray)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "waveform")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 14)
                        .foregroundColor(isSender ? .white : .gray)

                    Text(durationText)
                        .font(.system(size: 10))
                        .foregroundColor(isSender ? .white : .gray)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSender ? Color.blue : Color.gray.opacity(0.2))
                )
                .frame(maxWidth: 110)

                if !isSender { Spacer() }
            }

            Text(timestamp)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .padding(isSender ? .trailing : .leading, 12)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Recorder (watchOS)
final class WatchAudioRecorder: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var currentDuration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start(childId: String, completion: @escaping (Bool, String?) -> Void) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = Self.newFileURL(childId: childId)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            let ok = recorder?.record() ?? false
            isRecording = ok
            currentDuration = 0

            if ok {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                    self?.currentDuration = self?.recorder?.currentTime ?? 0
                }
                completion(true, nil)
            } else {
                completion(false, "Failed to start recording")
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func stop(completion: @escaping (URL?, TimeInterval) -> Void) {
        timer?.invalidate()
        timer = nil

        guard let recorder = recorder else {
            isRecording = false
            completion(nil, 0)
            return
        }

        recorder.stop()
        let url = recorder.url
        let dur = recorder.currentTime

        self.recorder = nil
        isRecording = false
        completion(url, dur)
    }

    private static func newFileURL(childId: String) -> URL {
        let ts = Int(Date().timeIntervalSince1970)
        let fn = "voice_\(childId)_\(ts).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fn)
    }
}

// MARK: - Player بسيط
final class SimpleAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    private var player: AVAudioPlayer?

    func play(url: URL) {
        if isPlaying { stop() }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            print("❌ audio play error:", error.localizedDescription)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}

// MARK: - WatchConnectivity (إرسال الملف للآيفون)
final class WatchConnectivityOutbox: NSObject, ObservableObject, WCSessionDelegate {
    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    func sendVoiceMessage(fileURL: URL, metadata: [String: Any]) {
        // ✅ Fix: isPaired is unavailable on watchOS; use conditional compilation.
        #if os(iOS)
        guard WCSession.default.isPaired else {
            print("⚠️ iPhone not paired")
            return
        }
        #elseif os(watchOS)
        guard WCSession.default.activationState == .activated else {
            print("⚠️ WCSession not activated")
            return
        }
        guard WCSession.default.isReachable else {
            print("⚠️ iPhone not reachable")
            return
        }
        #endif

        WCSession.default.transferFile(fileURL, metadata: metadata)
        print("📤 sent file:", fileURL.lastPathComponent, "meta:", metadata)
    }

    // MARK: WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let e = error { print("WC activate error:", e.localizedDescription) }
    }
}
 
// ✅ Live Preview
#Preview {
    NavigationStack {
        VoiceChatView()
    }
}
