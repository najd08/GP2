//
//  ProfileView.swift
//  Atsight
//
//  Created by Najd Alsabi on 22/03/2025.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .bold()
                .padding()

            Spacer()

            Image(systemName: "person.circle")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding()

            Text("Welcome to your profile")
                .font(.title3)
                .foregroundColor(.gray)
                .padding(.bottom, 30)

            Button(action: {
                print("Edit Profile tapped")
            }) {
                Text("Edit Profile")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview {
    ProfileView()
}
