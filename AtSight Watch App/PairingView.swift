//
//  PairingView.swift
//  AtSight (WatchKit Extension)
//

import SwiftUI

struct PairingView: View {
    @StateObject private var state = PairingState.shared
    @State private var goHome = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text(state.linked ? "Linked ✓" : "Pair Code")
                    .font(.headline)

                if state.linked {
                    Text("Connected to \(state.parentName.isEmpty ? "Parent" : state.parentName)")
                        .font(.footnote)
                        .opacity(0.6)

                    // Hidden navigation triggered when linked
                    NavigationLink(destination: HomeView_Watch(), isActive: $goHome) {
                        EmptyView()
                    }
                    .hidden()

                } else {
                    Text(state.pin)
                        .font(.largeTitle)
                        .monospacedDigit()

                    Button("Regenerate") {
                        state.regenerate()
                    }
                    .font(.footnote)
                }
            }
            .padding()
            .onAppear {
                WatchConnectivityManager.shared.activate()
                if state.linked { goHome = true }
            }
            .onChange(of: state.linked) { linked in
                if linked { goHome = true }
            }
        }
    }
}
