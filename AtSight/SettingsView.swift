import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showLogoutPopup = false

    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color("BgColor")
                .ignoresSafeArea()

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {

                        // MARK: - Account
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))

                            VStack(spacing: 16) {
                                NavigationLink(destination: EditProfileView()) {
                                    SettingsRow(icon: "person", title: "Edit profile")
                                }
                            }
                        }

                        // MARK: - Support
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Support")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))

                            VStack(spacing: 16) {
                                NavigationLink(destination: HelpSupportView()) {
                                    SettingsRow(icon: "questionmark.circle", title: "Help & Support")
                                }
                            }
                        }

                        // MARK: - Actions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actions")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))

                            VStack(spacing: 16) {
                                ToggleSettingsRow(icon: "moon.fill",
                                                  title: "Dark Mode",
                                                  isOn: $isDarkMode)

                                Button(action: { showLogoutPopup = true }) {
                                    SettingsRow(icon: "arrow.right.square", title: "Log out")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .navigationTitle("Settings")
                .foregroundColor(Color("BlackFont"))
            }
            .blur(radius: showLogoutPopup ? 6 : 0)
            .disabled(showLogoutPopup)

            // MARK: - Logout Popup
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
                                    showLogoutPopup = false

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
                .preferredColorScheme(isDarkMode ? .dark : .light)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color("Blue"))
                .padding(.leading, 4)
                .padding(.trailing, 10)

            Text(title)
                .font(.body)
                .foregroundColor(Color("BlackFont"))

            Spacer()

            Image(systemName: "arrow.forward")
                .foregroundColor(.gray)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color("ColorGray"), lineWidth: 1)
        )
    }
}

// MARK: - Toggle Row

struct ToggleSettingsRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color("Blue"))
                .padding(.leading, 4)
                .padding(.trailing, 1)

            Text(title)
                .font(.body)
                .foregroundColor(Color("BlackFont"))

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color("ColorGray"), lineWidth: 1)
        )
    }
}

// MARK: - Edit Profile (unchanged from your version)

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    @State private var displayName: String = ""
    @State private var originalName: String = ""          // To detect changes
    @State private var isSaving = false
    
    @State private var showSuccessMessage = false         // Center success card
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    private var canSave: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalTrimmed = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return false }
        guard trimmed != originalTrimmed else { return false }
        return !isSaving
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("BlackFont"))
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(Color("BlackFont"))
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                // MARK: - Main Content
                VStack(spacing: 16) {
                    List {
                        Section(
                            header: Text("Profile")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))
                        ) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color("Blue"))
                                
                                TextField("Your name", text: $displayName)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                                    .foregroundColor(Color("BlackFont"))
                                    .disabled(isSaving)
                            }
                        }
                        .listRowBackground(Color.clear)
                        
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    Text("This name will be shown on your child's watch.")
                                        .foregroundColor(Color("BlackFont"))
                                        .font(.subheadline)
                                }
                                Text("Choose a name your child will recognize. Changes may take a moment to sync to the watch.")
                                    .foregroundColor(Color("ColorGray"))
                                    .font(.footnote)
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    
                    VStack(spacing: 8) {
                        Button(action: saveDisplayName) {
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canSave ? Color("Blue") : Color("Blue").opacity(0.4))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!canSave)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear(perform: loadCurrentName)
            .background(Color("BgColor").ignoresSafeArea())
            
            // MARK: - Success Overlay
            if showSuccessMessage {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("Profile updated")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))
                        
                        Text("Your changes have been saved.")
                            .font(.subheadline)
                            .foregroundColor(Color("ColorGray"))
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color("BgColor"))
                            .shadow(color: .black.opacity(0.2),
                                    radius: 10, x: 0, y: 4)
                    )
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: showSuccessMessage)
            }
            
            // MARK: - Loading Overlay
            if isSaving {
                ZStack {
                    Color.black.opacity(0.05).ignoresSafeArea()
                }
            }
        }
        .alert("Error Saving Profile",
               isPresented: $showErrorAlert,
               actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(errorMessage ?? "An unknown error occurred.")
        })
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)   // hide system nav bar
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: - Firestore Logic
    
    private func loadCurrentName() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No authenticated user")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("guardians").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Failed to load name: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data(),
               let firstName = data["FirstName"] as? String {
                DispatchQueue.main.async {
                    self.displayName = firstName
                    self.originalName = firstName
                }
            }
        }
    }
    
    private func saveDisplayName() {
        errorMessage = nil
        showErrorAlert = false
        isSaving = true
        
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No authenticated user."
            showErrorAlert = true
            isSaving = false
            return
        }
        
        let db = Firestore.firestore()
        let uid = user.uid
        
        db.collection("guardians").document(uid).updateData([
            "FirstName": trimmed
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to save: \(error.localizedDescription)"
                    self.showErrorAlert = true
                } else {
                    self.originalName = trimmed
                    withAnimation {
                        self.showSuccessMessage = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            self.showSuccessMessage = false
                        }
                    }
                }
                self.isSaving = false
            }
        }
    }
}



// MARK: - Help & Support

struct HelpSupportView: View {
    @Environment(\.openURL) var openURL
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.dismiss) var dismiss
    
    private let supportEmail = "atsightgp@gmail.com"
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Custom Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("BlackFont"))
                        .font(.system(size: 20, weight: .bold))
                }
                
                Spacer()
                
                Text("Help & Support")
                    .font(.headline)
                    .foregroundColor(Color("BlackFont"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Main Card
                    VStack(spacing: 20) {
                        // Centered top section (icon + texts)
                        VStack(spacing: 12) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 110)) // 🔹 bigger question mark
                                .foregroundColor(Color("Blue"))
                            
                            Text("Need help?")
                                .font(.title3.weight(.bold))
                                .foregroundColor(Color("BlackFont"))
                            
                            Text("If you face any issues or have questions, we’re here to help.")
                                .font(.subheadline)
                                .foregroundColor(Color("ColorGray"))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity) // 🔹 center in the card
                        
                        // Contact Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contact us")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color("BlackFont"))
                            
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(Color("Blue"))
                                    .font(.system(size: 20))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Email")
                                        .font(.caption)
                                        .foregroundColor(Color("ColorGray"))
                                    
                                    Text(supportEmail)
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(Color("BlackFont"))
                                        .textSelection(.enabled)
                                }
                                
                                Spacer()
                            }
                            
                            Button {
                                openMail()
                            } label: {
                                Text("Send email")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color("Blue"))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom,6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("ColorGray"), lineWidth: 1)
                    )
                    
                    // Bottom message
                    Text("We’ll get back to you as soon as possible.")
                        .font(.footnote)
                        .foregroundColor(Color("ColorGray"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 23)
                .padding(.top, 50)
            }
        }
        .background(Color("BgColor").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)   // 🔹 hide system nav bar so your bar is at the very top
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    private func openMail() {
        if let url = URL(string: "mailto:\(supportEmail)") {
            openURL(url)
        }
    }
}



// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
           
    }
}
