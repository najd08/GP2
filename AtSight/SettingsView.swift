import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showLogoutPopup = false
    @State private var isLoggedOut = false
    @State private var navigateToLogin = false
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color("BgColor")
                .ignoresSafeArea()
            
            NavigationStack {
                VStack {
                    List {
                        Section(header: Text("Account")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))) {
                                SettingsRow(icon: "person", title: "Edit profile")
                                SettingsRow(icon: "shield", title: "Security")
                                SettingsRow(icon: "lock", title: "Privacy")
                            }
                            .listRowBackground(Color.clear) // ✅ يخلي الخلفية شفافة
                        
                        Section(header: Text("Support & About")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))) {
                                SettingsRow(icon: "questionmark.circle", title: "Help & Support")
                                SettingsRow(icon: "info.circle", title: "Terms and Policies")
                            }
                            .listRowBackground(Color.clear) // ✅
                        
                        Section(header: Text("Actions")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))) {
                                ToggleSettingsRow(icon: "moon.fill", title: "Dark Mode", isOn: $isDarkMode)
                                
                                Button(action: {
                                    showLogoutPopup = true
                                }) {
                                    SettingsRow(icon: "arrow.right.square", title: "Log out")
                                }
                            }
                            .listRowBackground(Color.clear) // ✅
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden) // ✅ يخفي خلفية القائمة الاصلية
                }
                .navigationTitle("Settings")
                .foregroundColor(Color("BlackFont"))
                NavigationLink(destination: ContentView(), isActive: $navigateToLogin) {
                    EmptyView()
                }
            }
            .blur(radius: showLogoutPopup ? 6 : 0)
            .disabled(showLogoutPopup)
            
            // Logout Popup
            if showLogoutPopup {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Text("Logout")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))
                        
                        Text("Are you sure you want to log out?")
                            .font(.system(size: 17))
                            .foregroundColor(Color("ColorGray"))
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                showLogoutPopup = false
                            }) {
                                Text("Cancel")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color("Blue"))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                do {
                                    try Auth.auth().signOut()
                                    
                                    let darkModeEnabled = UserDefaults.standard.bool(forKey: "isDarkMode")
                                    
                                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = scene.windows.first {
                                        window.rootViewController = UIHostingController(
                                            rootView: ContentView()
                                                .environmentObject(AppState())
                                                .preferredColorScheme(darkModeEnabled ? .dark : .light)
                                        )
                                        window.makeKeyAndVisible()
                                    }
                                } catch {
                                    print("Failed to sign out:", error.localizedDescription)
                                }
                            }) {
                                Text("Logout")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color("ColorGray"))
                                    .foregroundColor(Color("BlackFont"))
                                    .cornerRadius(10)
                            }
                        }
                        
                        .transition(.opacity)
                        .animation(.easeInOut, value: showLogoutPopup)
                    }
                    .padding(.vertical, 25)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 320, minHeight: 200)
                    .background(Color("BgColor"))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 10)
                }
                .preferredColorScheme(isDarkMode ? .dark : .light) // ✅ يتحكم في المود
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color("Blue"))
                    .padding(.trailing, 10)
                Text(title)
                    .font(.body)
                    .foregroundColor(Color("BlackFont"))
                Spacer()
            }
            .padding()

            Divider()
                .background(Color("ColorGray"))
        }
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color("ColorGray"), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

// MARK: - Toggle Row

struct ToggleSettingsRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color("Blue"))
                    .padding(.trailing, 10)
                Text(title)
                    .font(.body)
                    .foregroundColor(Color("BlackFont"))
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            .padding()

            Divider()
                .background(Color("ColorGray"))
        }
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color("ColorGray"), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.colorScheme, .light)
            .environmentObject(AppState())
    }
}
