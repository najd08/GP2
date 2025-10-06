//
//  ContentView.swift
//  Atsight
//
//  Created by lona on 28/01/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color("CustomBackground")
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 340)
                        .padding()

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Full-screen transparent button to navigate\
                NavigationLink(destination: WelcomePage1()) {
                    Color.clear
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}


#Preview {
    ContentView()
}
