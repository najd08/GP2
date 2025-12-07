import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

//MARK: - NotificationItem Struct:
struct NotificationItem: Identifiable {
    var id: String
    var title: String
    var body: String
    var timestamp: Timestamp
    var isSafeZone: Bool? // value is optional
    var event: String?    // event type: watch_removed, battery_low, sos_alert, etc.
    
    // Optional metadata (if you ever save them in Firestore for notifications)
    var childName: String?
    var zoneName: String?
}

//MARK: - extensions:
extension NotificationItem {
    
    // MARK: Helpers
    
    // Voice message detector
    private var isVoiceMessage: Bool {
        if let event = event,
           event == "voice_message" || event == "voice" || event == "new_voice_message" {
            return true
        }
        let lower = title.lowercased()
        return lower.contains("voice message") || lower.contains("new voice")
    }
    
    // Zone alert detector (geofence events written earlier)
    var isZoneAlert: Bool {
        return isSafeZone != nil && (event == nil || event == "zone_alert")
    }
    
    // MARK: Colors & Icons
    
    var indicatorColor: Color {
        // 🔊 Voice message (info, not danger)
        if isVoiceMessage {
            return Color("ColorBlue")
        }
        
        if let event = event {
            switch event {
            case "watch_removed":
                return Color("ColorRed")          // watch off wrist = danger
            case "battery_low":
                return Color("ColorOrange")       // low battery
            case "sos_alert":
                return Color("ColorRed")          // SOS = strong danger
            case "halt_alert":
                return Color("ColorYellow")       // HALT = important attention
            case "connection_request":
                return Color("ColorBlue")         // connection/relationship type
            default:
                break
            }
        }
        
        // Fallback to zone-based logic if event not set
        if let isSafe = isSafeZone {
            // Yellow for safe zone exits (true), Red for danger zone entries (false).
            return isSafe ? Color("ColorYellow") : Color("ColorRed")
        }
        
        // Neutral but NOT gray (for generic notifications)
        return Color("ColorBlue")
    }
    
    // Kept in case you want it; not used directly in row now.
    var backgroundColor: Color {
        indicatorColor.opacity(0.1)
    }
    
    var iconName: String {
        // 🔊 Voice message icon
        if isVoiceMessage {
            return "waveform"
        }
        
        if let event = event {
            switch event {
            case "watch_removed":
                return "heart.slash"
            case "battery_low":
                return "battery.25"
            case "sos_alert":
                return "sos"
            case "halt_alert":
                return "hand.raised.fill"
            case "connection_request":
                return "person.2.wave.2.fill"
            default:
                break
            }
        }
        
        if isSafeZone == nil {
            return "person.badge.plus"
        }
        return "exclamationmark.triangle"
    }
}


//MARK: - Page view:
struct NotificationsHistory: View {
    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true

    // DATE FORMATTER
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter
    }()

    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    if isLoading {
                        ProgressView("Loading...")
                            .padding(.top, 50)
                            .foregroundColor(Color("BlackFont"))
                    } else if notifications.isEmpty {
                        Text("No notifications available.")
                            .foregroundColor(Color("NotificationBody"))
                            .padding(.top, 50)
                    } else {
                        ForEach(notifications) { notification in
                            NotificationRow(
                                notification: notification,
                                dateText: dateFormatter.string(from: notification.timestamp.dateValue())
                            )
                        }
                    }
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity)
            }
            .background(Color("BgColor").ignoresSafeArea())
            .navigationTitle("Notifications History")
            .navigationBarTitleDisplayMode(.large)
            .foregroundColor(Color("BlackFont"))
        }
        .onAppear(perform: fetchNotifications)
    }

    //MARK: - Functions:
    func fetchNotifications() {
        guard let guardianID = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }

        let db = Firestore.firestore()
        db.collection("guardians")
            .document(guardianID)
            .collection("notifications")
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching notifications: \(error.localizedDescription)")
                    self.isLoading = false
                } else {
                    self.notifications = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        return NotificationItem(
                            id: doc.documentID,
                            title: data["title"] as? String ?? "Untitled",
                            body: data["body"] as? String ?? "",
                            timestamp: data["timestamp"] as? Timestamp ?? Timestamp(date: Date()),
                            isSafeZone: data["isSafeZone"] as? Bool,
                            event: data["event"] as? String,
                            childName: data["childName"] as? String,
                            zoneName: data["zoneName"] as? String
                        )
                    } ?? []
                    self.isLoading = false
                }
            }
    }
}

// MARK: - Single Row (modern tinted card)
struct NotificationRow: View {
    let notification: NotificationItem
    let dateText: String

    var body: some View {
        HStack {
            ZStack {
                // Card background – subtle tinted
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(notification.indicatorColor.opacity(0.10))

                // Very light border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(notification.indicatorColor.opacity(0.45), lineWidth: 1)

                HStack(alignment: .top, spacing: 14) {

                    // Icon (bigger & more relaxed)
                    ZStack {
                        Circle()
                            .fill(notification.indicatorColor)
                            .frame(width: 40, height: 40)

                        Image(systemName: notification.iconName)
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .padding(.top, 2)

                    // Texts
                    VStack(alignment: .leading, spacing: 6) {

                        // Title + Date on right
                        HStack(alignment: .firstTextBaseline) {
                            Text(notification.title) // ✅ Using raw DB title
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("BlackFont"))
                                // Removed .lineLimit(2) to show full text
                                .fixedSize(horizontal: false, vertical: true) // Ensures text expands vertically

                            Spacer(minLength: 6)

                            Text(dateText)
                                .font(.system(size: 13))
                                .foregroundColor(Color("NotificationBody"))
                                .lineLimit(1)
                        }

                        Text(notification.body) // ✅ Using raw DB body
                            .font(.system(size: 14))
                            .foregroundColor(Color("NotificationBody"))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(1.5)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6) // <- more space between cards
    }
}

#Preview {
    NotificationsHistory()
}
