//MARK: changed this file's name from "NotificationSettings" into "NotificationsHistory". ‼️
//changed the page's title to better explain the page's purpose. ‼️
//changed the colors for the child leaving safe zones to be yellow. ✅
//changed the add child message to have nil value as the isSafeZone value, this makes the notification have the default gray colors. ✅
//added "NotificationBody" color asset to notification body color to fit light mode. ✅
//Add delete notification button? ❓

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
    var isSafeZone: Bool? //value is optional
}

//MARK: - extensions:
// This extension makes the view code simple and clean, which fixes the compiler error:
extension NotificationItem {
    
    // Determines the color based on the isSafeZone state.
    var indicatorColor: Color {
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
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4) // ✅ شادو خفيف
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top)
                .frame(maxWidth: .infinity)
            }
            .background(Color("BgColor").ignoresSafeArea())
            .navigationTitle("Notifications History")
            .navigationBarTitleDisplayMode(.large) // ✅ رجعناها Large مثل الكود القديم
            .foregroundColor(Color("BlackFont"))
        }
        .onAppear(perform: fetchNotifications)
    }

    //MARK: - Functions:
    //fetch guardians' notification from Firebase:
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
                            // This line handles nil values from Firestore:
                            isSafeZone: data["isSafeZone"] as? Bool
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
