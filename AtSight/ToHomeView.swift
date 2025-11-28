//
//  ToHomeView.swift
//  Atsight
//
//  Created by Najd Alsabi on 12/03/2025.
//

import SwiftUI
import FirebaseAuth

struct ToHomeView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var selectedChild: Child? = nil
    @State private var expandedChild: Child? = nil

    var body: some View {
        VStack {
            if isLoggedIn {
                HomeView(selectedChild: $selectedChild, expandedChild: $expandedChild)
                    .navigationBarHidden(true)
                    .fullScreenCover(item: $selectedChild) { child in
                        ChildLocationView(child: child)
                    }
            } else {
                LoginPage() // If not logged in, navigate to LoginPage
            }
        }
        .onAppear {
            // ✅ Check Firebase Auth state
            if Auth.auth().currentUser != nil {
                isLoggedIn = true
            }
        }
    }
}

#Preview {
    ToHomeView()
}
