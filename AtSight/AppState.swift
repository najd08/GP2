//
//  AppState.swift
//  Atsight
//
//  Created by Najd Alsabi on 23/04/2025.
//

import Foundation
import FirebaseAuth

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = Auth.auth().currentUser != nil

    // Add a method to handle the logout process
    func logout() {
        do {
            try Auth.auth().signOut()
            print("Firebase sign out successful (from AppState).")
            DispatchQueue.main.async {
                self.isLoggedIn = false
            }
        } catch let signOutError as NSError {
            print("Error signing out (from AppState): %@", signOutError)
        }
    }
}
