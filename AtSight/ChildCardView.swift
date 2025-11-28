//
//  ChildCardView.swift
//  AtSightSprint0Test
//
//  Created by Najd Alsabi on 13/02/2025.
//

import SwiftUI

struct ChildCardView: View {
    var child: Child
    @Binding var expandedChild: Child?  // Expect a Binding<Child?>
    @State private var showEditProfile = false

    private func getColor(from colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue      //fixed "Blue" to "blue"
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink      //fixed "Pink" to "pink"
        case "brown": return .brown
        case "gray": return .gray
        case "bluecolor": return Color("Blue")
        case "pinkcolor": return Color("Pink")
        default: return .gray
        }
    }

    // Get the displayed image based on the child's imageName or fallback to the default system image
    private var displayedImage: Image {
        if let avatarName = child.imageName, !avatarName.isEmpty {
            return Image(avatarName) // Show the selected avatar image
        } else {
            return Image(systemName: "figure.child") // Fallback to system image if no avatar is set
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Display the avatar or default system image
                displayedImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(getColor(from: child.color).opacity(0.9))

                VStack(alignment: .leading) {
                    Text(child.name)
                        .bold()
                        .foregroundColor(Color("BlackFont"))
                        .padding(.leading, 10)
                }
                Spacer()
                Spacer()

                   Image(systemName: "arrow.forward")
                       .foregroundColor(.gray)
                       .padding(.trailing, 10)
            }
            .padding()
            .background(getColor(from: child.color).opacity(0.1))
            .cornerRadius(35)
            .overlay(
                RoundedRectangle(cornerRadius: 35)
                    .stroke(getColor(from: child.color), lineWidth: 2).opacity(0.5)
            )
            .shadow(radius: 4)
            .padding(.horizontal, 3)
        }
    }
}




