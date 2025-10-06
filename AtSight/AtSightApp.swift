//
//  AtsightApp.swift
//  Atsight
//
//  Merged version: Firebase, AppState, Dark Mode, Notifications, Connectivity
//

import SwiftUI
import FirebaseCore
import Firebase
import UserNotifications

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
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        print("✅ Firebase configured")
        
        // ✅ Keep BatteryReceiver as the sole WCSession delegate (pairing works)
        PhoneConnectivity.shared.activate()   // default = .batteryReceiver
        _ = BatteryReceiver.shared
        
        // Push last saved battery threshold to watch if available
        let lastThreshold = UserDefaults.standard.integer(forKey: "lowBatteryThreshold_last")
        if lastThreshold > 0 {
            BatteryReceiver.shared.pushThresholdToWatch(lastThreshold)
        }
        
        // Register for notifications
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Handle notifications in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Show banner + play sound even when app is open
        completionHandler([.banner, .sound])
    }
}
