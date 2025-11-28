
//Added low battery alert event handle ✅

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
    var event: String? // ✅ added to handle "watch_removed" type
}

//MARK: - extensions:
extension NotificationItem {
    
    // Determines the color based on the isSafeZone state or event type.
    var indicatorColor: Color {
        // EDIT BY RIYAM: Added 'battery_low' to red color condition
        if event == "watch_removed" || event == "battery_low" {
            return Color("ColorRed") // ✅ red for lost heart rate or low battery
        }
        // Handle SOS Alert event
        if event == "sos_alert" {
            return Color("ColorRed")
        }
        guard let isSafe = isSafeZone else {
            // This is the color for neutral notifications (isSafeZone is nil).
            return Color("ColorGray")
        }
        // Yellow for safe zone exits (true), Red for danger zone entries (false).
        return isSafe ? Color("ColorYellow") : Color("ColorRed")
    }
    
    // Determines the background color.
    var backgroundColor: Color {
        return indicatorColor.opacity(0.1)
    }
    
    // Determines which icon to show.
    var iconName: String {
        if event == "watch_removed" {
            return "heart.slash" // ✅ distinct icon for watch removed
        }
        // EDIT BY RIYAM: Added specific icon for low battery
        if event == "battery_low" {
            return "exclamationmark.triangle"
        }
        guard isSafeZone != nil else {
            // A neutral icon for adding a child or other non-zone alerts.
            return "person.badge.plus"
        }
        // The alert icon for zone-related notifications.
        return "exclamationmark.triangle"
    }
}

//MARK: - Page view:
struct NotificationsHistory: View {
    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true

    // DATE FORMATTER
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("Loading...")
                            .padding(.top, 50)
                            .foregroundColor(Color("BlackFont"))
                    } else if notifications.isEmpty {
                        Text("No notifications available.")
                            .foregroundColor(Color("ColorGray"))
                            .padding(.top, 50)
                    } else {
                        ForEach(notifications) { notification in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(Color("BlackFont"))
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(notification.title)
                                        .font(.headline)
                                        .foregroundColor(Color("BlackFont"))

                                    Text(notification.body)
                                        .font(.subheadline)
                                        .foregroundColor(Color("NotificationBody"))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    // Display notification date and time.
                                        Text(dateFormatter.string(from: notification.timestamp.dateValue()))
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .padding(.top, 2) // Add a little space
                                }

                                Spacer()

                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(notification.indicatorColor, lineWidth: 2)
                                        .frame(width: 34, height: 34)

                                    Image(systemName: notification.iconName)
                                        .foregroundColor(notification.indicatorColor)
                                        .font(.system(size: 18))
                                }
                            }
                            .padding()
                            .background(notification.backgroundColor)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(notification.indicatorColor, lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top)
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
                            event: data["event"] as? String // ✅ safely map new field
                        )
                    } ?? []
                    self.isLoading = false
                }
            }
    }
}

#Preview {
    NotificationsHistory()
}
