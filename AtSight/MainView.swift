//
//  MainView.swift
//  Atsight
//
//  Created by Najd Alsabi on 22/03/2025.
//
//  Updated by Leon on 28/10/2025: Added AlertPage overlay for continuous zone monitoring. ❌ commented out.
//

// fixed home button on nav bar... ✅
// ZoneAlertZimulation file now runs in the background and monitors the location and sends alerts for all children! ✅✅✅
//merged 🤝

//updated to handle sos alert popup
//EDIT BY RIYAM: Changed alertManager declaration to use @ObservedObject and .shared singleton instance to resolve 'inaccessible initializer' error.
// Updated by Leon on 28/10/2025: Added AlertPage overlay for continuous zone monitoring. ❌ commented out.
//  Updated by User on 2025-11-23: Integrated PairingRequestView for Admin approvals.
//


import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MainView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var selectedTab = 1  // Start with Home tab selected
    @State private var selectedChild: Child? = nil
    @State private var expandedChild: Child? = nil
    @State private var children: [Child] = [] // Store retrieved children

    // MARK: New state variable to force HomeView to reload (from old code)
    @State private var homeViewID = UUID()

    @EnvironmentObject var appState: AppState
    
    // 💥 FIX: Access the global singleton instance using @ObservedObject.
    @ObservedObject private var alertManager = SOSAlertManager.shared
    
    // ✅ NEW: Listener for Pairing Requests (Admin Approval)
    @StateObject private var pairingListener = PairingRequestListener()

    var body: some View {
        ZStack {
            Color("navBG").ignoresSafeArea()
            VStack(spacing: 0) {
                // Content Area
                ZStack {
                    switch selectedTab {
                    case 0:
                        NotificationsHistory()
                    case 1:
                        HomeView(selectedChild: $selectedChild, expandedChild: $expandedChild)
                            .id(homeViewID) // MARK: FIX: Attach the ID here
                    case 2:
                        SettingsView()
                    default:
                        HomeView(selectedChild: $selectedChild, expandedChild: $expandedChild)
                            .id(homeViewID) // MARK: FIX: Attach the ID here
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: This 'if' block now contains the complete, fixed tab bar (from old code)
                if selectedTab == 0 || selectedTab == 1 || selectedTab == 2 {
                    Spacer()

                    // MARK: This ZStack now manages all 3 buttons for a stable layout
                    ZStack(alignment: .bottom) {
                        
                        // MARK: Layer 1: The tab bar background and side buttons
                        HStack {
                            // Notifications Button
                            Button(action: { selectedTab = 0 }) {
                                VStack {
                                    Image(systemName: selectedTab == 0 ? "bell.fill" : "bell")
                                        .font(.system(size: 24))
                                    Text("Notifications")
                                        .font(.caption2)
                                }
                                .foregroundColor(selectedTab == 0 ? Color("Blue") : .gray)
                            }
                            .frame(maxWidth: .infinity)

                            // MARK: This empty space leaves room for the Home button
                            Spacer().frame(width: 70)
                            
                            // Settings Button
                            Button(action: { selectedTab = 2 }) {
                                VStack {
                                    Image(systemName: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                                        .font(.system(size: 24))
                                    Text("Settings")
                                        .font(.caption2)
                                }
                                .foregroundColor(selectedTab == 2 ? Color("Blue") : .gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 70)
                        .background(Color("navBG"))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
                        
                        // MARK: Layer 2: The floating Home Button
                        // (✅ يظهر فقط بالصفحات المحددة)
                        Button(action: {
                            // MARK: FIX: This logic now handles popping to root
                            if selectedTab == 1 {
                                // If we're already on tab 1, force a refresh by changing the ID
                                homeViewID = UUID()
                            } else {
                                // Otherwise, just switch to tab 1
                                selectedTab = 1
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(selectedTab == 1 ? Color("Blue") : .gray.opacity(0.3))
                                    .frame(width: 70, height: 70)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                                Image(systemName: "house.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 30, weight: .bold))
                            }
                        }
                        // MARK: This offset is relative to the ZStack, not the screen center
                        // MARK: This makes it safe for all device sizes.
                        .offset(y: -15)
                    }
                    // MARK: Give the ZStack a fixed height to contain the popped-out button
                    .frame(height: 100)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        
//        // ✅ Overlay running silently in the background (from new code)
//        .overlay(
//                    Group {
//                        // MARK: Loop over all children, not just 'selectedChild'
//                        ForEach(children) { child in
//                            ZoneAlertSimulation(childID: child.id)
//                                .frame(width: 0, height: 0) // hidden but active
//                                .opacity(0)
//                        }
//                    }
//                )
        //MARK: SOS Alert View as a global overlay
        .overlay(
            ZStack {
                if alertManager.isShowingAlert, let alert = alertManager.currentAlert {
                    SOSAlertView(
                        isShowing: $alertManager.isShowingAlert,
                        alert: alert
                    )
                }
            }
            .animation(.easeInOut, value: alertManager.isShowingAlert)
        )
        
        // ✅ NEW: Pairing Request Pop-up Sheet
        // This triggers automatically when pairingListener.activeRequest is set
        .sheet(item: $pairingListener.activeRequest) { request in
            if let uid = Auth.auth().currentUser?.uid {
                PairingRequestView(request: request, guardianId: uid)
            } else {
                Text("Error: User not logged in")
            }
        }
        
        .onAppear {
            fetchChildren()
            
            // Start the SOS listener when MainView appears
            alertManager.startListeningForSOS()
            
            // ✅ NEW: Start listening for Pairing Requests
            if let uid = Auth.auth().currentUser?.uid {
                pairingListener.startListening(guardianId: uid)
            }
        }
        .onDisappear {
            // Stop the listener when the user logs out
            alertManager.stopListening()
            
            // ✅ NEW: Stop pairing listener
            pairingListener.stopListening()
        }
        .preferredColorScheme(isDarkMode ? .dark : .light) // ✅ إضافة تحكم الدارك مود هنا
    }

    // MARK: - Fetch Children Data
    func fetchChildren() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let childrenRef = db.collection("guardians").document(userId).collection("children")

        childrenRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching children: \(error)")
            } else {
                self.children = snapshot?.documents.compactMap { document in
                    let data = document.data()
                    return Child(
                        id: document.documentID,
                        name: data["name"] as? String ?? "",
                        color: data["color"] as? String ?? "blue"
                    )
                } ?? []
            }
        }
    }
}

#Preview {
    MainView().environmentObject(AppState())
}
