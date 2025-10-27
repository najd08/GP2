//
//  HomeAndChildDetail.swift
//  Atsight
//
//  Updated by Leon on 27/10/2025
//  Simplified: Removed chat and voice message sections, added VoiceChatPhone button only.
//

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore
import AVFoundation

// MARK: - ChildDetailView
struct ChildDetailView: View {
    @State var child: Child
    @Environment(\.presentationMode) var presentationMode
    @State private var guardianID: String = Auth.auth().currentUser?.uid ?? ""
    @State private var viewRefreshToken = UUID()

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var isLinked: Bool {
        UserDefaults.standard.bool(forKey: "linked_\(child.id)")
    }

    private var parentDisplayName: String {
        if let email = Auth.auth().currentUser?.email {
            return email.components(separatedBy: "@").first ?? "Parent"
        }
        return "Parent"
    }

    var body: some View {
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

            // MARK: Not Linked
            if !isLinked {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("Link your child's watch")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))
                        Text("Please link the watch first to enable location and other features.")
                            .font(.footnote)
                            .foregroundColor(Color("ColorGray"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    NavigationLink(
                        destination: ParentLinkView(
                            childId: child.id,
                            childName: child.name,
                            parentName: parentDisplayName
                        )
                    ) {
                        VStack {
                            Image(systemName: "link")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(Color("Blue"))
                            Text("Link Watch")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))
                        }
                        .frame(width: 300, height: 140)
                        .background(Color("BgColor"))
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color("ColorGray"), lineWidth: 1)
                        )
                    }

                    // Debug simulate link
                    Text("Simulate linking for testing")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                        .onTapGesture {
                            UserDefaults.standard.set(true, forKey: "linked_\(child.id)")
                            viewRefreshToken = UUID()
                        }

                    Spacer()
                }
            } else {
                // MARK: Linked Grid (Simplified)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {

                        // 🎙️ Voice Chat button → passes guardianID + childId + childName
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

                        NavigationLink(destination: ChildLocationView(child: child)) {
                            gridButtonContent(icon: "location.fill", title: "View Last Location", color: Color("Blue"))
                        }

                        NavigationLink(destination: EditChildProfile(guardianID: guardianID, child: $child)) {
                            gridButtonContent(icon: "figure.child.circle", title: "Child Profile", color: Color("ColorGreen"))
                        }

                        NavigationLink(destination: LocationHistoryView(childID: child.id)) {
                            gridButtonContent(icon: "clock.arrow.circlepath", title: "Location History", color: Color("ColorPurple"))
                        }

                        NavigationLink(destination: AddZonePage(childID: child.id)) {
                            gridButtonContent(icon: "mappin.and.ellipse", title: "Zones Setup", color: Color("ColorRed"))
                        }

                        NavigationLink(destination: ZoneAlertSimulation(childID: child.id)) {
                            gridButtonContent(icon: "map.circle", title: "Zones Alert Test", color: Color("ColorRed"))
                        }
                    }
                    .padding()
                }
                .background(Color("BgColor"))
                .cornerRadius(15)
                .id(viewRefreshToken)
            }
        }
        .background(Color("BgColor").ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guardianID = Auth.auth().currentUser?.uid ?? ""
            viewRefreshToken = UUID()
        }
    }

    // MARK: - Grid Button
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
        .shadow(radius: 10)
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
                }
            }
            .padding(.horizontal, 10)
            .background(Color("BgColor").ignoresSafeArea())
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
