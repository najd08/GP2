//
//  AtsightApp.swift
//  Atsight
//
//  Created by lona on 28/01/2025.
//
//  Merged version: Firebase, AppState, Dark Mode, Notifications, Connectivity
//  + FCM push notifications integration
//

import SwiftUI
import FirebaseCore
import Firebase
import FirebaseMessaging
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

@main
struct AtsightApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // Keep AppState alive across app lifetime
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .id(appState.isLoggedIn) // refresh view when login state changes
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAuthScreen = false

    var body: some View {
        MainView()
            .onChange(of: appState.isLoggedIn) { oldValue, newValue in
                showAuthScreen = !newValue
            }
            .fullScreenCover(isPresented: $showAuthScreen) {
                ContentView()
                    .environmentObject(appState)
            }
            .onAppear {
                showAuthScreen = !appState.isLoggedIn
            }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject,
                   UIApplicationDelegate,
                   UNUserNotificationCenterDelegate,
                   MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        print("✅ Firebase configured")
        
        // ✅ FCM delegate
        Messaging.messaging().delegate = self
        
        // ✅ Keep BatteryReceiver as the sole WCSession delegate (pairing works)
        PhoneConnectivity.shared.activate()   // default = .batteryReceiver
        _ = BatteryReceiver.shared
        
        // Push last saved battery threshold to watch if available
        let lastThreshold = UserDefaults.standard.integer(forKey: "lowBatteryThreshold_last")
        if lastThreshold > 0 {
            BatteryReceiver.shared.pushThresholdToWatch(lastThreshold)
        }
        
        // Register for notifications (local + push)
        UNUserNotificationCenter.current().delegate = self
        
        // Ask user for notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            } else {
                print("🔔 Notification permission granted: \(granted)")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        // ✅ Register custom notification category for "Watch Removed"
        let okAction = UNNotificationAction(
            identifier: "ACK_WATCH_REMOVED",
            title: "OK",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "WATCH_REMOVED_CATEGORY",
            actions: [okAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        return true
    }
    
    // MARK: - APNs registration callbacks
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass APNs token to FCM
        Messaging.messaging().apnsToken = deviceToken
        print("📱 APNs token registered")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - FCM token updates
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("📡 FCM registration token: \(token)")
        
        // Try to save token under current guardian
        if let uid = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("guardians")
                .document(uid)
                .collection("deviceTokens")
                .document(token)
                .setData([
                    "createdAt": Date()
                ], merge: true) { error in
                    if let error = error {
                        print("❌ Failed to save FCM token: \(error.localizedDescription)")
                    } else {
                        print("✅ FCM token saved for guardian \(uid)")
                    }
                }
        } else {
            // If user not logged in yet, you could store it in UserDefaults
            // and upload after login if you want.
            print("ℹ️ No logged-in user when FCM token was received")
        }
    }
    
    // MARK: - Foreground notification behavior
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + play sound even when app is open
        completionHandler([.banner, .sound])
    }
    
    // ✅ Handle when user taps "OK" on the Watch Removed alert
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        
        if response.actionIdentifier == "ACK_WATCH_REMOVED" {
            UserDefaults.standard.set(true, forKey: "stopHeartRateMonitoring")
            print("✅ Parent tapped OK — stopHeartRateMonitoring flag set")
        }
        
        completionHandler()
    }
}
