//Modified some texts an changed newAuthorAccount to newConnectionRequest.

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import AVFoundation
import WatchConnectivity // Added for watch communication

struct CustomizeNotifications: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var child: Child

    // MARK: - Notification toggle states
    @State private var safeZoneAlert: Bool = true
    @State private var unsafeZoneAlert: Bool = true
    @State private var lowBatteryAlert: Bool = true
    @State private var watchRemovedAlert: Bool = true
    @State private var newConnectionRequest: Bool = true

    @State private var showSoundPicker = false
    @State private var selectedSound: NotificationSound = .defaultSound

    @State private var isLoading = false
    
    @State private var selectedThreshold: Int = 20     // used for low watch battery alert

    // MARK: - Init
    init(child: Binding<Child>) {
        self._child = child
        // Initializing with Firestore defaults; actual values will load onAppear
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Customize Notifications")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 8)

                // MARK: - Notification Cards:
                notificationCard(title: "Safe Zone Alert",
                                 subtitle: "Alert if child exits a safe zone",
                                 isOn: $safeZoneAlert) { child.notificationSettings.safeZoneAlert = $0 }

                notificationCard(title: "Unsafe Zone Alert",
                                 subtitle: "Alert if child enters an unsafe zone",
                                 isOn: $unsafeZoneAlert) { child.notificationSettings.unsafeZoneAlert = $0 }

                notificationCard(title: "Low Battery Alert",
                                 subtitle: "Alert if child's watch is low on battery",
                                 isOn: $lowBatteryAlert) { child.notificationSettings.lowBatteryAlert = $0 }

                // MARK: - Battery Threshold Slider (from merged file)
                notificationCard(
                    title: "Low Battery Threshold",
                    subtitle: "Set percentage for Low Battery alerts",
                    rightView: AnyView(
                        VStack {
                            Slider(
                                value: Binding(
                                    get: { Double(selectedThreshold) },
                                    set: { newValue in
                                        selectedThreshold = Int(newValue)
                                        child.notificationSettings.lowBatteryThreshold = selectedThreshold
                                    }
                                ),
                                in: 10...50,
                                step: 1
                            )
                            Text("\(selectedThreshold)%")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 180)
                    )
                )

                // MARK: - Rest of Notification Cards:
                notificationCard(title: "Watch Removed Alert",
                                 subtitle: "Alert if child removed the watch",
                                 isOn: $watchRemovedAlert) { child.notificationSettings.watchRemovedAlert = $0 }

                notificationCard(title: "New Conncetion Request",
                                 subtitle: "Alert when someone tries to connect to child watch",
                                 isOn: $newConnectionRequest) { child.notificationSettings.newConnectionRequest = $0 }

                notificationCard(title: "Notification Sound",
                                 subtitle: "Choose sound for all notifications",
                                 rightView: AnyView(
                                     Button(action: { showSoundPicker = true }) {
                                         HStack {
                                             Text(selectedSound.rawValue)
                                                 .foregroundColor(.primary)
                                             Image(systemName: "chevron.right")
                                                 .foregroundColor(.gray)
                                         }
                                         .padding(.horizontal, 12)
                                         .padding(.vertical, 8)
                                         .background(Color.gray.opacity(0.1))
                                         .cornerRadius(8)
                                     }
                                 ))

                if isLoading {
                    ProgressView("Updating settings...")
                        .padding()
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color("BgColor").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Color("BlackFont"))
                    .font(.system(size: 20, weight: .bold))
            },
            trailing: Button(action: { saveAllNotificationSettings() }) {
                Text("Done")
                    .foregroundColor(.blue)
                    .fontWeight(.bold)
            }
        )
        .sheet(isPresented: $showSoundPicker) {
            NotificationSoundPicker(selectedSound: $selectedSound, onSoundSelected: { sound in
                child.notificationSettings.sound = sound.filename
            })
        }
        .onAppear {
            //Load actual notification settings from Firestore when the page loads
            loadNotificationSettings()
        }
    }

    
    //MARK: - Functions:
    // Load Notification Settings
    private func loadNotificationSettings() {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let settingsDoc = db.collection("guardians")
            .document(guardianID)
            .collection("children")
            .document(child.id)
            .collection("notifications")
            .document("settings")

        settingsDoc.getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching notification settings: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data() else { return }

            //Update states based on fetched data
            safeZoneAlert = data["safeZoneAlert"] as? Bool ?? true
            unsafeZoneAlert = data["unsafeZoneAlert"] as? Bool ?? true
            lowBatteryAlert = data["lowBatteryAlert"] as? Bool ?? true
            watchRemovedAlert = data["watchRemovedAlert"] as? Bool ?? true
            newConnectionRequest = data["newConnectionRequest"] as? Bool ?? true
            if let sound = data["sound"] as? String {
                selectedSound = NotificationSound.fromString(sound)
            }
            // Load threshold (from merged file)
            selectedThreshold = data["lowBatteryThreshold"] as? Int ?? 20
        }
    }

    //Save Notification Settings to Firestore:
    private func saveAllNotificationSettings() {
        isLoading = true
        let db = Firestore.firestore()
        guard let guardianID = Auth.auth().currentUser?.uid else {
            print("❌ No logged-in guardian found")
            isLoading = false
            return
        }

        let childDocID = child.id
        // Use a fixed document "settings" instead of hardcoding random IDs
        // This way, each child has exactly one notification settings document
        let notificationDocRef = db.collection("guardians").document(guardianID)
            .collection("children").document(childDocID)
            .collection("notifications").document("settings")

        let notificationSettings: [String: Any] = [
            "safeZoneAlert": safeZoneAlert,
            "unsafeZoneAlert": unsafeZoneAlert,
            "lowBatteryAlert": lowBatteryAlert,
            "watchRemovedAlert": watchRemovedAlert,
            "newConnectionRequest": newConnectionRequest,
            "sound": selectedSound.filename,
            "lowBatteryThreshold": selectedThreshold // Added from merged file
        ]
        
        // This local update now requires the `lowBatteryThreshold` property
        child.notificationSettings = NotificationSettings(
            safeZoneAlert: safeZoneAlert,
            unsafeZoneAlert: unsafeZoneAlert,
            lowBatteryAlert: lowBatteryAlert,
            watchRemovedAlert: watchRemovedAlert,
            newConnectionRequest: newConnectionRequest,
            sound: selectedSound.filename,
            lowBatteryThreshold: selectedThreshold
        )

        // Push updates to Firestore
        notificationDocRef.setData(notificationSettings, merge: true) { error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("❌ Error updating notification settings: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully updated all notification settings")
                    
                    // Push threshold to Watch (from merged file)
                    do {
                        print("📤 Pushing lowBatteryThreshold to Watch:", selectedThreshold)
                        try WCSession.default.updateApplicationContext([
                            "lowBatteryThreshold": selectedThreshold
                        ])
                    } catch {
                        print("⚠️ Failed to update app context:", error.localizedDescription)
                    }
                    
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }


    // MARK: - Notification Card View Builder
    @ViewBuilder
    private func notificationCard(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>? = nil,
        rightView: AnyView? = nil,
        onToggle: ((Bool) -> Void)? = nil
    ) -> some View {
        HStack {
            Image(systemName: "bell")
                .foregroundColor(Color("BlackFont"))
                .font(.system(size: 18))
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("BlackFont"))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            Spacer()

            if let toggleBinding = isOn {
                Toggle("", isOn: toggleBinding)
                    .labelsHidden()
                    .onChange(of: toggleBinding.wrappedValue) { newVal in
                        onToggle?(newVal)
                    }
            } else if let right = rightView {
                right
            }
        }
        .padding()
        .background(Color("navBG")) // instead of Color.white to help appeal in dark mode.
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Sound Picker
//This is the sheet that is displayed to the user to pick a specific alert sound for his child.
struct NotificationSoundPicker: View {
    @Binding var selectedSound: NotificationSound
    var onSoundSelected: (NotificationSound) -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(NotificationSound.allCases) { sound in
                    HStack {
                        Text(sound.rawValue)
                        Spacer()
                        if selectedSound == sound {
                            Image(systemName: "checkmark")
                                .foregroundColor(.mint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSound = sound
                        SoundPlayer.shared.playSound(named: sound.filename)
                        onSoundSelected(sound)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Select Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
