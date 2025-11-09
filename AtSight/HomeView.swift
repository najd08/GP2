//removed the "bypass linking" section ✅
//we should let the parent access some of child's stuff without enforcing the watch link process! ✅
//we should add "unlink watch" option. ✅
//add shadows for dark mode for better UI. ✅
//add icon to unlink watch button (it is bad, i know...) ✅
//locked some features (voice messaging, view last location, and location history) behind the watch linking process and added a pop up message to inform user about it. ✅
//link and unlink buttons are now bigger, indicating their importance. ✅
//fix unlink and make it work properly, and make the child force quit from his parent screen if he has been unlinked.
// ⚠️ Line 159: you can comment that section out since it is meant for debugging, it will not be included in the final release. ⚠️

//merged codes 🤝

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - ChildDetailView
struct ChildDetailView: View {
    @State var child: Child
    @Environment(\.presentationMode) var presentationMode
    @State private var guardianID: String = Auth.auth().currentUser?.uid ?? ""
    @State private var viewRefreshToken = UUID() // MARK: New state variable to refresh the view

    // MARK: Changed 'isLinked' from a computed property to a @State variable
    // This allows us to update the UI instantly when unlinking.
    @State private var isLinked: Bool = false
    
    @State private var showLinkWarning: Bool = false

    // MARK: This is still a computed property, which is fine.
    private var parentDisplayName: String {
        if let email = Auth.auth().currentUser?.email {
            return email.components(separatedBy: "@").first ?? "Parent"
        }
        return "Parent"
    }

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

                    // Header updated to include the 'isLinked' icon
                    HStack(spacing: 6) {
                        Text(child.name)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(Color("BlackFont"))

                        // This now reads from the @State variable
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

                // MARK: The grid is now always visible even when child is not linked to a watch.
                ScrollView {
                    
                    linkButton()
                        .padding(.horizontal) // Match grid's horizontal padding
                        .padding(.top)        // Match grid's top padding

                    LazyVGrid(columns: columns, spacing: 20) {
                            
                        // 🎙️ Voice Chat button → passes guardianID + childId + childName
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
                            .buttonStyle(PlainButtonStyle()) // Makes button act like a plain view
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
                        
                        // MARK: - Added this section for debugging sprint3 & 4 features:
                        NavigationLink(destination: ZoneAlertSimulation(childID: child.id)) {
                            gridButtonContent(icon: "map.circle", title: "Zones Alert Test", color: Color("ColorYellow"))
                        }
                        //MARK: - you can comment this previous section for the final release!
                        
                        
                    }
                    .padding()
                }
                .background(Color("BgColor"))
                .cornerRadius(15)
                .id(viewRefreshToken) // MARK: New state variable to refresh the view
            }
            .background(Color("BgColor").ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                guardianID = Auth.auth().currentUser?.uid ?? ""
                // MARK: Load the link status from UserDefaults into the @State variable
                isLinked = UserDefaults.standard.bool(forKey: "linked_\(child.id)")
                viewRefreshToken = UUID()
            }
            
            if showLinkWarning {
                Text("This feature requires linking a watch.")
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding()
                    .background(Color.black.opacity(0.8)) // Use 0.8 opacity for better visibility
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.85))) // Animate scale and opacity
                    .zIndex(10) // Ensure it's on top of all other content
            }
        }
    }
    
    private func triggerLinkWarning() {

        // Animate the pop-up appearing
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showLinkWarning = true
        }
        
        // Set a timer to hide it
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // 2 second duration
            withAnimation(.easeOut(duration: 0.4)) { // Fade out
                showLinkWarning = false
            }
        }
    }
    
    @ViewBuilder
    private func linkButton() -> some View {
        if isLinked {
            // MARK: This is the new "Unlink Watch" button
            Button(action: {
                // Update UserDefaults
                UserDefaults.standard.set(false, forKey: "linked_\(child.id)")
                // Update the local @State variable to refresh the UI instantly
                isLinked = false
            }) {
                // MARK: New wide layout
                VStack {
                    Image(systemName: "square.slash") // Changed icon
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
                .frame(maxWidth: .infinity) // Spans full width
                .background(Color("BgColor"))
                .cornerRadius(20)
                .shadow(color: Color("BlackFont").opacity(0.3), radius: 10)
            }
        } else {
            // MARK: This is the "Link Watch" button
            NavigationLink(
                destination: ParentLinkView(
                    childId: child.id,
                    childName: child.name,
                    parentName: parentDisplayName
                )
            ) {
                // MARK: New wide layout
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
                .frame(maxWidth: .infinity) // Spans full width
                .background(Color("BgColor"))
                .cornerRadius(20)
                .shadow(color: Color("BlackFont").opacity(0.3), radius: 10)
            }
        }
    }

    // MARK: Helper for Button Layout
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
        // 30 comes from horizontal padding and spacing between columns
        .background(Color("BgColor"))
        .cornerRadius(20)
        .shadow(color: Color("BlackFont").opacity(0.3), radius: 10) //MARK: added shadow color for dark mode.
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
                    
                    // MARK: Original print statements from old code preserved
                    print("🔑 Logged in UID:", Auth.auth().currentUser?.uid ?? "No user")
                    print("🟢 Stored guardianID:", UserDefaults.standard.string(forKey: "guardianID") ?? "❌ none")
                }

            }
            .padding(.horizontal, 10)
            .background(Color("BgColor").ignoresSafeArea()) // ✅ خلفية الصفحة كاملة
        }
    }

    // MARK: Firestore
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
