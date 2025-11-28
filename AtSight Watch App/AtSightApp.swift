//
//  AtSightApp.swift
//  AtSight Watch App
//
//  Created by Leena on 01/09/2025.
//  EDIT BY RIYAM:
//  - Logic added to check if guardians exist (linked).
//  - If linked -> HomeView_Watch, Else -> WelcomeView.
//

import SwiftUI

@main
struct AtSight_Watch_AppApp: App {
    // Observe the shared state to react to changes immediately
    @StateObject private var pairingState = PairingState.shared

    var body: some Scene {
        WindowGroup {
            // Check if we have any linked guardians
            if pairingState.linked {
                HomeView_Watch()
            } else {
                WelcomeView()
            }
        }
    }
}
