

import Foundation
import SwiftUICore

struct Child: Identifiable{
    var id: String // This will store the Firestore document ID
    var name: String
    var color: String // Store color as a String
    var imageData: Data? // Added for the profile picture data (local/temporary)
    var imageName: String? // Added to store the download URL from Firebase Storage
    var zones: [Zone] = [] // Assuming zones are stored as an array within the child document
    var notificationSettings: NotificationSettings = NotificationSettings()

    // Helper computed property to convert the stored color string to SwiftUI Color for display
    var uiColor: Color {
         // Map the string color name back to SwiftUI Color
         switch color.lowercased() {
         case "red": return .red
         case "green": return .green
         case "blue": return .blue
         case "yellow": return .yellow
         case "orange": return .orange
         case "purple": return .purple
         case "pink": return .pink
         case "brown": return .brown
         case "gray": return .gray
         case "bluecolor": return Color("Blue") // If using custom asset names
         case "pinkcolor": return Color("Pink") // If using custom asset names
         default:
              print("Warning: Unknown color string '\(color)' found for child \(name). Using default.")
              return .gray // Fallback for unknown strings
         }
    }

   
    
}

// Add an extension to convert SwiftUI Color to String for saving to Firestore
extension Color {
    func toString() -> String {
        // Map SwiftUI Color back to your chosen string representation
        switch self {
        case .red: return "red"
        case .green: return "green"
        case .blue: return "blue"
        case .yellow: return "yellow"
        case .orange: return "orange"
        case .purple: return "purple"
        case .pink: return "pink"
        case .brown: return "brown"
        case .gray: return "gray"
        // Handle your custom colors - needs a way to get the asset name if applicable
        case Color("Blue"): return "bluecolor" // Example mapping for custom asset
        case Color("Pink"): return "pinkcolor" // Example mapping for custom asset
        default:
             // Attempt a description or fallback
             print("Warning: Could not convert Color to known string.")
             return "unknown"
        }
    }
}


