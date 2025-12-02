// EDIT BY RIYAM: Updated 'linkButton' to toggle the 'isWatchLinked' field in Firestore instead of deleting the entire child document.
// This preserves the child in the iOS list while signaling the watch (via API polling) to unlink.

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - ChildDetailView
struct ChildDetailView: View {
    @State var child: Child
    @Environment(\.presentationMode) var presentationMode
    @State private var guardianID: String = Auth.auth().currentUser?.uid ?? ""
    @State private var viewRefreshToken = UUID()

    @State private var isLinked: Bool = false
    @State private var showLinkWarning: Bool = false
    
    // ✅ New state to hold the fetched name
    @State private var realParentName: String = ""

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            VStack {
                // MARK: Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("BlackFont"))
                            .font(.system(size: 20, weight: .bold))
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(child.name)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(Color("BlackFont"))

                        if isLinked {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(Color("Blue"))
                                .font(.title3)
                                .accessibilityLabel("Linked")
                        }
                    }

                    Spacer()
                    Spacer().frame(width: 24)
                }
                .padding()
                .padding(.top, -10)

                ScrollView {
                    
                    linkButton()
                        .padding(.horizontal)
                        .padding(.top)

                    LazyVGrid(columns: columns, spacing: 20) {
                            
                        if isLinked {
                            NavigationLink(
                                destination: VoiceChatPhone(
                                    guardianId: guardianID,
                                    childId: child.id,
                                    childName: child.name
                                )
                            ) {
                                gridButtonContent(
                                    icon: "waveform.circle.fill",
                                    title: "Voice Chat",
                                    color: Color("ColorPurple")
                                )
                            }
                        } else {
                            Button(action: triggerLinkWarning) {
                                gridButtonContent(
                                    icon: "waveform.circle.fill",
                                    title: "Voice Chat",
                                    color: Color("ColorGray")
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if isLinked {
                            NavigationLink(destination: ChildLocationView(child: child)) {
                                gridButtonContent(
                                    icon: "location.fill",
                                    title: "View Last Location",
                                    color: Color("Blue")
                                )
                            }
                        } else {
                            Button(action: triggerLinkWarning) {
                                gridButtonContent(
                                    icon: "location.fill",
                                    title: "View Last Location",
                                    color: Color("ColorGray")
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        NavigationLink(destination: EditChildProfile(guardianID: guardianID, child: $child)) {
                            gridButtonContent(icon: "figure.child.circle", title: "Child Profile", color: Color("ColorGreen"))
                        }

                        if isLinked {
                            NavigationLink(destination: LocationHistoryView(childID: child.id)) {
                                gridButtonContent(
                                    icon: "clock.arrow.circlepath",
                                    title: "Location History",
                                    color: Color("ColorPurple")
                                )
                            }
                        } else {
                            Button(action: triggerLinkWarning) {
                                gridButtonContent(
                                    icon: "clock.arrow.circlepath",
                                    title: "Location History",
                                    color: Color("ColorGray")
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        NavigationLink(destination: AddZonePage(childID: child.id)) {
                            gridButtonContent(icon: "mappin.and.ellipse", title: "Zones Setup", color: Color("ColorRed"))
                        }
                        
                       
                    }
                    .padding()
                }
                .background(Color("BgColor"))
                .cornerRadius(15)
                .id(viewRefreshToken)
            }
            .background(Color("BgColor").ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                guardianID = Auth.auth().currentUser?.uid ?? ""
                isLinked = UserDefaults.standard.bool(forKey: "linked_\(child.id)")
                viewRefreshToken = UUID()
                
                // ✅ Fetch the real parent name immediately
                fetchParentName()
            }
            
            if showLinkWarning {
                Text("This feature requires linking a watch.")
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .zIndex(10)
            }
        }
    }
    
    // ✅ Helper to fetch name from Firestore
    private func fetchParentName() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("guardians").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data(), let name = data["FirstName"] as? String {
                self.realParentName = name
                print("✅ Fetched parent name: \(name)")
            } else {
                // Fallback if name is missing
                self.realParentName = "Parent"
            }
        }
    }
    
    private func triggerLinkWarning() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showLinkWarning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showLinkWarning = false
            }
        }
    }
    
    @ViewBuilder
    private func linkButton() -> some View {
        if isLinked {
            Button(action: {
                guard let uid = Auth.auth().currentUser?.uid else { return }
                let db = Firestore.firestore()
                
                print("🔓 Unlinking watch for child: \(child.name) (ID: \(child.id))")
                
                // 1. Update the child document to set isWatchLinked = false
                // This tells the API polling on the watch that the link is invalid without deleting the child.
                db.collection("guardians").document(uid).collection("children").document(child.id).updateData(["isWatchLinked": false]) { error in
                    if let error = error {
                        print("❌ Error unlinking: \(error.localizedDescription)")
                    } else {
                        print("✅ Unlink successful. isWatchLinked set to false.")
                    }
                }
                
                // 2. Update Local State
                UserDefaults.standard.set(false, forKey: "linked_\(child.id)")
                isLinked = false
                
            }) {
                VStack {
                    Image(systemName: "square.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                    Text("Unlink Watch")
                        .font(.headline)
                        .foregroundColor(Color("BlackFont"))
                        .multilineTextAlignment(.center)
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(Color("BgColor"))
                .cornerRadius(20)
                .shadow(color: Color("BlackFont").opacity(0.3), radius: 10)
            }
        } else {
            NavigationLink(
                destination: ParentLinkView(
                    childId: child.id,
                    childName: child.name,
                    // ✅ Use the real fetched name, or fallback to "Parent" if still loading
                    parentName: realParentName.isEmpty ? "Parent" : realParentName
                )
            ) {
                VStack {
                    Image(systemName: "link")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(Color("Blue"))
                    Text("Link Watch")
                        .font(.headline)
                        .foregroundColor(Color("BlackFont"))
                        .multilineTextAlignment(.center)
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(Color("BgColor"))
                .cornerRadius(20)
                .shadow(color: Color("BlackFont").opacity(0.3), radius: 10)
            }
        }
    }

    @ViewBuilder
    private func gridButtonContent(icon: String, title: String, color: Color) -> some View {
        VStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(Color("BlackFont"))
                .multilineTextAlignment(.center)
        }
        .frame(width: (UIScreen.main.bounds.width / 2) - 30, height: 140)
        .background(Color("BgColor"))
        .cornerRadius(20)
        .shadow(color: Color("BlackFont").opacity(0.3), radius: 10)
    }
}


// MARK: - HomeView
struct HomeView: View {
    @Binding var selectedChild: Child?
    @Binding var expandedChild: Child?
    @State private var firstName: String = "Guest"
    @State private var children: [Child] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Image("Image 1")
                        .resizable()
                        .frame(width: 140, height: 130)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.top)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Hello \(firstName)")
                        .font(.largeTitle).bold()
                        .foregroundColor(Color("Blue"))
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("View your kids' locations.")
                            .font(.title3)
                            .foregroundColor(Color("BlackFont"))
                            .fontWeight(.medium)

                        Text("Stay connected and informed about their well-being.")
                            .font(.body)
                            .foregroundColor(Color("ColorGray"))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        NavigationLink(destination: AddChildView(fetchChildrenCallback: fetchChildrenFromFirestore)) {
                            Text("Add child")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .foregroundColor(Color("Blue"))
                                .background(Color("BgColor"))
                                .cornerRadius(25)
                                .shadow(radius: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color("ColorGray"), lineWidth: 1)
                                )
                        }
                        .padding(.leading, 250)
                    }

                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(children) { child in
                                NavigationLink(destination: ChildDetailView(child: child)) {
                                    ChildCardView(child: child, expandedChild: $expandedChild)
                                        .padding(.top)
                                }
                                .onDisappear {
                                    fetchChildrenFromFirestore()
                                }
                            }
                        }
                    }
                    .padding(.top, 3)
                }
                .onAppear {
                    fetchUserName()
                    fetchChildrenFromFirestore()

                    if let uid = Auth.auth().currentUser?.uid {
                        UserDefaults.standard.set(uid, forKey: "guardianID")
                        print("✅ Updated guardianID in UserDefaults: \(uid)")
                    }
                    
                    print("🔑 Logged in UID:", Auth.auth().currentUser?.uid ?? "No user")
                    print("🟢 Stored guardianID:", UserDefaults.standard.string(forKey: "guardianID") ?? "❌ none")
                }

            }
            .padding(.horizontal, 10)
            .background(Color("BgColor").ignoresSafeArea())
        }
    }

    func fetchChildrenFromFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("guardians").document(userId).collection("children").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching children: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.children = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        return Child(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "Unknown",
                            color: data["color"] as? String ?? "gray",
                            imageName: data["imageName"] as? String
                        )
                    } ?? []
                }
            }
        }
    }

    func fetchUserName() {
        if let userId = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("guardians").document(userId).getDocument { document, _ in
                if let document = document, document.exists {
                    if let fetchedFirstName = document.data()?["FirstName"] as? String {
                        firstName = fetchedFirstName
                    }
                }
            }
        }
    }
}

#Preview("Home") {
    HomeView(selectedChild: .constant(nil), expandedChild: .constant(nil)).environmentObject(AppState())
}
