//MARK: This class is used for notifications and alerts managment:
//Merge Edit: added "lowBatteryThreshold" to "NotificationSettings" struct 🤝

import Foundation
import UserNotifications
import AVFoundation

// MARK: - Sound Player class
// This class is used to play sound effects using AVAudioPlayer:
class SoundPlayer {
    static let shared = SoundPlayer()
    private var audioPlayer: AVAudioPlayer?

    // Plays a sound file with the given name (needs a .wav extension).
    func playSound(named soundName: String) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "wav") else {
            print("Sound file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }
}

// MARK: - Notification Sound Options
// Defines the available notification sound options and their corresponding filenames.
enum NotificationSound: String, CaseIterable, Identifiable {
    case defaultSound = "Default"
    case alert = "Alert"
    case bell = "Bell"
    case chime = "Chime"
    case chirp = "Chirp"

    var id: String { self.rawValue }

    var filename: String {
        switch self {
        case .defaultSound: return "default_sound"
        case .alert: return "alert_sound"
        case .bell: return "bell_sound"
        case .chime: return "chime_sound"
        case .chirp: return "chirp_sound"
        }
    }

    // Converts a filename string back into a NotificationSound enum case.
    static func fromString(_ string: String) -> NotificationSound {
        return NotificationSound.allCases.first { $0.filename == string } ?? .defaultSound
    }
}

// MARK: - NotificationSettings Struct:
// A data model for storing all of a user's notification preferences.
struct NotificationSettings: Codable, Equatable {
    var safeZoneAlert: Bool = true
    var unsafeZoneAlert: Bool = true
    var lowBatteryAlert: Bool = true
    var watchRemovedAlert: Bool = true
    var newAuthorAccount: Bool = true
    var sound: String = "default_sound"
    var lowBatteryThreshold: Int = 20 //for watch low battery alerts
}

//MARK: NotificationManager class:
// A class used to manage all push notification interactions.
class NotificationManager {
    
    // Provides a globally accessible shared instance of the NotificationManager.
    static let instance = NotificationManager()
    
    // Asks the user for permission to send alerts, sounds, and badges.
    func requestAuthorization() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (success, error) in
            if let error = error {
                print("ERROR: \(error.localizedDescription)")
            } else {
                print("SUCCESS: Notification permission granted.")
            }
        }
    }

    // Creates and schedules a local notification with a specific title, body, and sound.
    func scheduleNotification(title: String, body: String, soundName: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = body
        // Create the sound object from the filename. Must include the extension.
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
