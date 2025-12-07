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
    @State private var realParentName: String = ""

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color("BgColor").ignoresSafeArea()

            VStack(spacing: 0) {

                // ====== BACK BUTTON ======
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color("BlackFont"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // ====== CURVED HEADER (Clickable) ======
                NavigationLink(
                    destination: EditChildProfile(guardianID: guardianID, child: $child)
                ) {
                    ZStack {
                        VStack(spacing: 12) {

                            // ===== AVATAR CIRCLE =====
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 130, height: 130)

                                Circle()
                                    .stroke(Color("button"), lineWidth: 4)
                                    .frame(width: 120, height: 120)

                                // ===== AVATAR LOGIC =====
                                if let avatar = child.imageName, !avatar.isEmpty {
                                    Image(avatar)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 55, height: 55)
                                        .foregroundColor(Color("button"))
                                }
                            }
                            .padding(.top, 30)

                            Text(child.name)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color("BlackFont"))
                                .padding(.bottom, 50)
                            Text("Tap to Edit profile") .font(.caption) .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                ScrollView {

                    // ===============================
                    // MARK: SHOW LINK BUTTON ONLY IF NOT LINKED
                    // ===============================
                    if !isLinked {
                        linkWatchButton()
                            .padding(.horizontal)
                            .padding(.top, 10)
                    }

                    // ===============================
                    // MARK: SHOW GRID ONLY IF LINKED
                    // ===============================
                    if isLinked {
                        LazyVGrid(columns: columns, spacing: 20) {

                            // View Last Location
                            NavigationLink(destination: ChildLocationView(child: child)) {
                                gridButtonContent(icon: "location.fill", title: "View Last Location", color: Color("Blue"))
                            }

                            // Voice Chat
                            NavigationLink(destination: VoiceChatPhone(
                                guardianId: guardianID,
                                childId: child.id,
                                childName: child.name
                            )) {
                                gridButtonContent(icon: "waveform.circle.fill", title: "Voice Chat", color: Color("ColorPurple"))
                            }

                            // Zones Setup
                            NavigationLink(destination: AddZonePage(childID: child.id)) {
                                gridButtonContent(icon: "mappin.and.ellipse", title: "Zones Setup", color: Color("ColorRed"))
                            }

                            // Location History
                            NavigationLink(destination: LocationHistoryView(childID: child.id)) {
                                gridButtonContent(icon: "clock.arrow.circlepath", title: "Location History", color: Color("ColorPurple"))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                }
                .id(viewRefreshToken)
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
        .onAppear {
            guardianID = Auth.auth().currentUser?.uid ?? ""
            isLinked = UserDefaults.standard.bool(forKey: "linked_\(child.id)")
            viewRefreshToken = UUID()
            fetchParentName()
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }


    // ===========================
    // MARK: - HELPERS
    // ===========================

    private func fetchParentName() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("guardians").document(uid).getDocument { snapshot, _ in
            if let data = snapshot?.data(),
               let name = data["FirstName"] as? String {
                self.realParentName = name
            } else {
                self.realParentName = "Parent"
            }
        }
    }

    private func triggerLinkWarning() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showLinkWarning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showLinkWarning = false
            }
        }
    }

    @ViewBuilder
    private func linkWatchButton() -> some View {
        VStack(spacing: 16) {

            // ----- Text above button -----
            Text("Connect to your child's watch")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color("BlackFont"))
                .multilineTextAlignment(.center)

            // ----- OLD ORIGINAL BUTTON (unchanged) -----
            NavigationLink(
                destination: ParentLinkView(
                    childId: child.id,
                    childName: child.name,
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
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 10)
            }
        }
        .padding(.horizontal)
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
        }
        .frame(width: (UIScreen.main.bounds.width / 2) - 30, height: 140)
        .background(Color.white)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.1), radius: 8)
    }
}



// MARK: - HomeView

struct HomeView: View {

    @Binding var selectedChild: Child?
    @Binding var expandedChild: Child?

    @State private var firstName: String = "Guest"
    @State private var children: [Child] = []
    @State private var showAddChildGuide: Bool = true   // <— Spotlight

    var body: some View {
        NavigationStack {
            ZStack {

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
                        }

                        // ===========================
                        // ADD CHILD BUTTON
                        // ===========================
                        HStack {
                            Spacer()
                            NavigationLink(destination: AddChildView(fetchChildrenCallback: fetchChildrenFromFirestore)) {
                                Text("Add child")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .foregroundColor(Color("Blue"))
                                    .background(Color.white)
                                    .cornerRadius(25)
                                    .shadow(color: .black.opacity(0.15), radius: 4)
                            }
                        }
                        .padding(.trailing, 20)

                        // ===========================
                        // CHILD LIST
                        // ===========================
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
                        }
                    }
                }
                .padding(.horizontal, 10)
                .background(Color("BgColor").ignoresSafeArea())


                // ================================================
                // SPOTLIGHT OVERLAY — Highlight Add Child Button
                // ================================================
             
                if showAddChildGuide && children.isEmpty {

                    GeometryReader { geo in
                        ZStack {

                            // Dark Background
                            Color.black.opacity(0.55)
                                .ignoresSafeArea()

                            // Spotlight Cutout Circle
                            Circle()
                                .frame(width: 140, height: 140)
                                .position(
                                    x: geo.size.width - 80,
                                    y: 330
                                )
                                .blendMode(.destinationOut)

                            VStack(spacing: 14) {

                                Spacer().frame(height: 320)
                                Text("Tap here to add your first child.")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)

                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .compositingGroup()
                        .onTapGesture { showAddChildGuide = false }
                    }
                }
            }
        }
    }

    // ===================================================
    // MARK: - Firestore Calls
    // ===================================================

    func fetchChildrenFromFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("guardians").document(userId).collection("children")
            .getDocuments { snapshot, error in

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
            db.collection("guardians").document(userId)
                .getDocument { document, _ in
                    if let document = document, document.exists {
                        firstName = document.data()?["FirstName"] as? String ?? "Guest"
                    }
                }
        }
    }
}



#Preview("Home") {
    HomeView(selectedChild: .constant(nil), expandedChild: .constant(nil)).environmentObject(AppState())
}
