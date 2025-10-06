//Edit by Riyam: modified line 24 for page navigation.

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MainView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var selectedTab = 1  // Start with Home tab selected
    @State private var selectedChild: Child? = nil
    @State private var expandedChild: Child? = nil
    @State private var children: [Child] = [] // Store retrieved children

    @EnvironmentObject var appState: AppState

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
                    case 2:
                        SettingsView()
                    default:
                        HomeView(selectedChild: $selectedChild, expandedChild: $expandedChild)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                 if selectedTab == 0 || selectedTab == 1 || selectedTab == 2 {
                    Spacer()

                    // Custom Tab Bar
                    HStack {
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
                }
            }

            // Enlarged Home Tab on Top (✅ يظهر فقط بالصفحات المحددة)
            if selectedTab == 0 || selectedTab == 1 || selectedTab == 2 {
                Button(action: { selectedTab = 1 }) {
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
                .offset(y: 360)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            fetchChildren()
        }
        .preferredColorScheme(isDarkMode ? .dark : .light) // ✅ إضافة تحكم الدارك مود هنا
    }

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
