//
//  AuthorizedGuardians.swift
//  AtSight
//
//  Updated: Checks 'isWatchLinked' status before showing data.
//  Updated: Sorts list to put Admins at the top.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

// MARK: - Authorized Guardian Model
struct AuthorizedGuardian: Identifiable {
    var id: String
    var firstName: String
    var lastName: String
    var isAdmin: Bool
}

struct AuthorizedGuardians: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var child: Child
    
    // MARK: - State Variables
    @State private var guardians: [AuthorizedGuardian] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // ✅ New State for Link Status
    @State private var isWatchLinked: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Page Title
            Text("Authorized Guardians for \(child.name)")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 10)
                .padding(.horizontal)
                .foregroundColor(Color("BlackFont"))
            
            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
                Spacer()
                
            } else if !isWatchLinked {
                // ✅ CASE: Watch Unlinked - Show Empty State
                Spacer()
                VStack(spacing: 15) {
                    Image(systemName: "link.badge.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Watch Not Linked")
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color("BlackFont"))
                    
                    Text("You must be linked to the watch to view Authorized Guardians.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                Spacer()
                
            } else if let error = errorMessage {
                Spacer()
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                Spacer()
                
            } else if guardians.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No authorized guardians found.")
                        .foregroundColor(.gray)
                    Spacer()
                }
                Spacer()
                
            } else {
                // Display the list of guardians
                List {
                    ForEach(guardians) { guardian in
                        HStack {
                            Text("\(guardian.firstName) \(guardian.lastName)")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))
                            
                            Spacer()
                            
                            if guardian.isAdmin {
                                Text("Admin")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(5)
                            } else {
                                Text("Guardian")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden) // Hides default list background to show custom BgColor
            }
        }
        .background(Color("BgColor").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { //navigate back
                self.presentationMode.wrappedValue.dismiss()
            }) {
                //navigate back button styling:
                HStack {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("BlackFont"))
                        .font(.system(size: 20, weight: .bold))
                }
            }
        )
        .onAppear {
            checkLinkAndFetch()
        }
    }
    
    // MARK: - Fetch Logic
    func checkLinkAndFetch() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            self.errorMessage = "User not logged in."
            self.isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // 1. Check if the child is still linked to this guardian
        let childRef = db.collection("guardians")
            .document(currentUserID)
            .collection("children")
            .document(child.id)
            
        childRef.getDocument { doc, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }
            
            // Check 'isWatchLinked' field (Default to true if missing)
            let data = doc?.data() ?? [:]
            self.isWatchLinked = data["isWatchLinked"] as? Bool ?? true
            
            if self.isWatchLinked {
                // 2. If linked, fetch the list
                fetchAuthorizedGuardians(currentUserID: currentUserID)
            } else {
                // Stop here if unlinked
                self.isLoading = false
            }
        }
    }
    
    func fetchAuthorizedGuardians(currentUserID: String) {
        let db = Firestore.firestore()
        let guardiansRef = db.collection("guardians")
            .document(currentUserID)
            .collection("children")
            .document(child.id)
            .collection("AuthorizedGuardians")
        
        guardiansRef.getDocuments { snapshot, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.isLoading = false
                return
            }
            
            let fetchedGuardians = documents.compactMap { doc -> AuthorizedGuardian? in
                let data = doc.data()
                guard let firstName = data["FirstName"] as? String,
                      let lastName = data["LastName"] as? String else {
                    return nil
                }
                let isAdmin = data["isAdmin"] as? Bool ?? false
                
                return AuthorizedGuardian(
                    id: doc.documentID,
                    firstName: firstName,
                    lastName: lastName,
                    isAdmin: isAdmin
                )
            }
            
            // ✅ SORT: Admins first, then alphabetical by first name
            self.guardians = fetchedGuardians.sorted { (g1, g2) -> Bool in
                if g1.isAdmin != g2.isAdmin {
                    return g1.isAdmin // Admin comes before non-Admin
                }
                return g1.firstName < g2.firstName
            }
            
            self.isLoading = false
        }
    }
}

struct AuthorizedGuardians_Previews: PreviewProvider {
    static var previews: some View {
        AuthorizedGuardians(child: .constant(Child(id: "preview-id", name: "sarah", color: "blue", imageName: "penguin")))
    }
}
