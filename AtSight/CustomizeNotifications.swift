////
////  CustomizeNotifications.swift
////  AtSight
////
////  Final merged version: combines Riyam’s cleanup with legacy features (SoundPlayer, NotificationSettings).
////
//
//import SwiftUI
//import Firebase
//import FirebaseFirestore
//import FirebaseAuth
//import AVFoundation
//import WatchConnectivity
//
//// MARK: - Sound Player
//class SoundPlayer {
//    static let shared = SoundPlayer()
//    private var audioPlayer: AVAudioPlayer?
//
//    func playSound(named soundName: String) {
//        guard let url = Bundle.main.url(forResource: soundName, withExtension: "wav") else {
//            print("❌ Sound file not found:", soundName)
//            return
//        }
//        do {
//            audioPlayer = try AVAudioPlayer(contentsOf: url)
//            audioPlayer?.play()
//        } catch {
//            print("❌ Failed to play sound:", error.localizedDescription)
//        }
//    }
//}
//
//// MARK: - Notification Sound Options
//enum NotificationSound: String, CaseIterable, Identifiable {
//    case defaultSound = "Default"
//    case alert = "Alert"
//    case bell = "Bell"
//    case chime = "Chime"
//    case chirp = "Chirp"
//
//    var id: String { self.rawValue }
//
//    var filename: String {
//        switch self {
//        case .defaultSound: return "default_sound"
//        case .alert: return "alert_sound"
//        case .bell: return "bell_sound"
//        case .chime: return "chime_sound"
//        case .chirp: return "chirp_sound"
//        }
//    }
//
//    static func fromString(_ string: String) -> NotificationSound {
//        return NotificationSound.allCases.first { $0.filename == string } ?? .defaultSound
//    }
//}
//
//// MARK: - Notification Settings Model
//struct NotificationSettings: Codable, Equatable {
//    var safeZoneAlert: Bool = true
//    var unsafeZoneAlert: Bool = true
//    var lowBatteryAlert: Bool = true
//    var watchRemovedAlert: Bool = true
//    var newAuthorAccount: Bool = true
//    var sound: String = "default_sound"
//    var lowBatteryThreshold: Int = 20
//}
//
//// MARK: - CustomizeNotifications View
//struct CustomizeNotifications: View {
//    @Environment(\.presentationMode) var presentationMode
//    @Binding var child: Child
//
//    @State private var safeZoneAlert: Bool
//    @State private var unsafeZoneAlert: Bool
//    @State private var lowBatteryAlert: Bool
//    @State private var watchRemovedAlert: Bool
//    @State private var newAuthorAccount: Bool
//
//    @State private var showSoundPicker = false
//    @State private var selectedSound: NotificationSound
//
//    @State private var isLoading = false
//    @State private var selectedThreshold: Int
//
//    // ✅ Initialize from child’s stored settings
//    init(child: Binding<Child>) {
//        self._child = child
//        let settings = child.wrappedValue.notificationSettings
//        _safeZoneAlert = State(initialValue: settings.safeZoneAlert)
//        _unsafeZoneAlert = State(initialValue: settings.unsafeZoneAlert)
//        _lowBatteryAlert = State(initialValue: settings.lowBatteryAlert)
//        _watchRemovedAlert = State(initialValue: settings.watchRemovedAlert)
//        _newAuthorAccount = State(initialValue: settings.newAuthorAccount)
//        _selectedSound = State(initialValue: NotificationSound.fromString(settings.sound))
//        _selectedThreshold = State(initialValue: settings.lowBatteryThreshold)
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 16) {
//                Text("Customize Notifications")
//                    .font(.system(size: 28, weight: .bold))
//                    .padding(.bottom, 8)
//
//                // Toggles
//                notificationCard(title: "Safe Zone Alert",
//                                 subtitle: "Alert if child exits a safe zone",
//                                 isOn: $safeZoneAlert) { child.notificationSettings.safeZoneAlert = $0 }
//
//                notificationCard(title: "Unsafe Zone Alert",
//                                 subtitle: "Alert if child enters an unsafe zone",
//                                 isOn: $unsafeZoneAlert) { child.notificationSettings.unsafeZoneAlert = $0 }
//
//                notificationCard(title: "Battery Low",
//                                 subtitle: "Alert if child's watch is low on battery",
//                                 isOn: $lowBatteryAlert) { child.notificationSettings.lowBatteryAlert = $0 }
//
//                // Slider for lowBatteryThreshold
//                notificationCard(
//                    title: "Battery Low Threshold",
//                    subtitle: "Set percentage for alerts",
//                    rightView: AnyView(
//                        VStack {
//                            Slider(
//                                value: Binding(
//                                    get: { Double(selectedThreshold) },
//                                    set: { newValue in
//                                        selectedThreshold = Int(newValue)
//                                        child.notificationSettings.lowBatteryThreshold = selectedThreshold
//                                    }
//                                ),
//                                in: 10...50,
//                                step: 1
//                            )
//                            Text("\(selectedThreshold)%")
//                                .font(.footnote)
//                                .foregroundColor(.gray)
//                        }
//                        .frame(width: 180)
//                    )
//                )
//
//                notificationCard(title: "Watch Removed Alert",
//                                 subtitle: "Alert if child removed the watch",
//                                 isOn: $watchRemovedAlert) { child.notificationSettings.watchRemovedAlert = $0 }
//
//                notificationCard(title: "New Author Account",
//                                 subtitle: "Alert if child profile has been accessed",
//                                 isOn: $newAuthorAccount) { child.notificationSettings.newAuthorAccount = $0 }
//
//                // Sound picker
//                notificationCard(title: "Notification Sound",
//                                 subtitle: "Choose sound for all notifications",
//                                 rightView: AnyView(
//                                     Button(action: { showSoundPicker = true }) {
//                                         HStack {
//                                             Text(selectedSound.rawValue)
//                                                 .foregroundColor(.primary)
//                                             Image(systemName: "chevron.right")
//                                                 .foregroundColor(.gray)
//                                         }
//                                         .padding(.horizontal, 12)
//                                         .padding(.vertical, 8)
//                                         .background(Color.gray.opacity(0.1))
//                                         .cornerRadius(8)
//                                     }
//                                 ))
//
//                if isLoading { ProgressView("Updating settings...").padding() }
//                Spacer(minLength: 40)
//            }
//            .padding()
//        }
//        .background(Color("BgColor").ignoresSafeArea())
//        .navigationBarBackButtonHidden(true)
//        .navigationBarItems(
//            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
//                Image(systemName: "chevron.left")
//                    .foregroundColor(Color("BlackFont"))
//                    .font(.system(size: 20, weight: .bold))
//            },
//            trailing: Button(action: { saveAllNotificationSettings() }) {
//                Text("Done")
//                    .foregroundColor(.blue)
//                    .fontWeight(.bold)
//            }
//        )
//        .sheet(isPresented: $showSoundPicker) {
//            NotificationSoundPicker(selectedSound: $selectedSound) { sound in
//                child.notificationSettings.sound = sound.filename
//            }
//        }
//    }
//
//    // MARK: - Save to Firestore
//    private func saveAllNotificationSettings() {
//        isLoading = true
//        let db = Firestore.firestore()
//        guard let guardianID = Auth.auth().currentUser?.uid else {
//            print("❌ No logged-in guardian found")
//            isLoading = false
//            return
//        }
//
//        let childDocID = child.id
//        let notificationDocRef = db.collection("guardians").document(guardianID)
//            .collection("children").document(childDocID)
//            .collection("notifications").document("settings")
//
//        let notificationSettings: [String: Any] = [
//            "safeZoneAlert": safeZoneAlert,
//            "unsafeZoneAlert": unsafeZoneAlert,
//            "lowBatteryAlert": lowBatteryAlert,
//            "watchRemovedAlert": watchRemovedAlert,
//            "newAuthorAccount": newAuthorAccount,
//            "sound": selectedSound.filename,
//            "lowBatteryThreshold": selectedThreshold
//        ]
//
//        // Update local model
//        child.notificationSettings = NotificationSettings(
//            safeZoneAlert: safeZoneAlert,
//            unsafeZoneAlert: unsafeZoneAlert,
//            lowBatteryAlert: lowBatteryAlert,
//            watchRemovedAlert: watchRemovedAlert,
//            newAuthorAccount: newAuthorAccount,
//            sound: selectedSound.filename,
//            lowBatteryThreshold: selectedThreshold
//        )
//
//        notificationDocRef.setData(notificationSettings, merge: true) { error in
//            DispatchQueue.main.async {
//                isLoading = false
//                if let error = error {
//                    print("❌ Error updating notification settings:", error.localizedDescription)
//                } else {
//                    print("✅ Notification settings updated successfully")
//
//                    // Push threshold to Watch
//                    do {
//                        print("📤 Pushing lowBatteryThreshold to Watch:", selectedThreshold)
//                        try WCSession.default.updateApplicationContext([
//                            "lowBatteryThreshold": selectedThreshold
//                        ])
//                    } catch {
//                        print("⚠️ Failed to update app context:", error.localizedDescription)
//                    }
//
//                    self.presentationMode.wrappedValue.dismiss()
//                }
//            }
//        }
//    }
//
//    // MARK: - Card Builder
//    @ViewBuilder
//    private func notificationCard(
//        title: String,
//        subtitle: String,
//        isOn: Binding<Bool>? = nil,
//        rightView: AnyView? = nil,
//        onToggle: ((Bool) -> Void)? = nil
//    ) -> some View {
//        HStack {
//            Image(systemName: "bell")
//                .foregroundColor(Color("BlackFont"))
//                .font(.system(size: 18))
//                .padding(.leading, 10)
//
//            VStack(alignment: .leading, spacing: 4) {
//                Text(title)
//                    .font(.system(size: 16, weight: .semibold))
//                    .foregroundColor(Color("BlackFont"))
//                Text(subtitle)
//                    .font(.system(size: 14))
//                    .foregroundColor(.gray)
//            }
//            Spacer()
//
//            if let toggleBinding = isOn {
//                Toggle("", isOn: toggleBinding)
//                    .labelsHidden()
//                    .onChange(of: toggleBinding.wrappedValue) { newVal in
//                        onToggle?(newVal)
//                    }
//            } else if let right = rightView {
//                right
//            }
//        }
//        .padding()
//        .background(Color("navBG")) // ✅ works with dark mode
//        .cornerRadius(20)
//        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
//    }
//}
//
//// MARK: - Sound Picker
//struct NotificationSoundPicker: View {
//    @Binding var selectedSound: NotificationSound
//    var onSoundSelected: (NotificationSound) -> Void
//    @Environment(\.presentationMode) var presentationMode
//
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(NotificationSound.allCases) { sound in
//                    HStack {
//                        Text(sound.rawValue)
//                        Spacer()
//                        if selectedSound == sound {
//                            Image(systemName: "checkmark")
//                                .foregroundColor(.mint)
//                        }
//                    }
//                    .contentShape(Rectangle())
//                    .onTapGesture {
//                        selectedSound = sound
//                        SoundPlayer.shared.playSound(named: sound.filename)
//                        onSoundSelected(sound)
//                    }
//                    .padding(.vertical, 8)
//                }
//            }
//            .navigationTitle("Select Sound")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
//                }
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") { presentationMode.wrappedValue.dismiss() }
//                }
//            }
//        }
//    }
//}
