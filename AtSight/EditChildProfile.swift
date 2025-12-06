//
//  EditChildProfile.swift
//  Atsight
//
//  Created by Najd Alsabi on 21/04/2025.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

struct EditChildProfile: View {
    @Environment(\.dismiss) var dismiss
    var guardianID: String
    @Binding var child: Child
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showingColorPicker = false
    @State private var isSaving = false
    @State private var showSuccessMessage = false
    @State private var showDeleteSuccessMessage = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var goToLocationHistory = false
    @State private var isAvatarSelectionVisible = false
    
    // Delete states
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    // Original values to detect changes
    @State private var originalName: String = ""
    @State private var originalColor: String = ""
    @State private var originalImageName: String = ""
    
    let colors: [Color] = [.red, .green, .blue, .yellow, .orange, .purple, .pink, .brown, .gray]
    let animalIcons = ["penguin", "giraffe", "butterfly", "fox", "deer", "tiger", "whale", "turtle", "owl", "elephant", "frog", "hamster"]
    
    private var canSave: Bool {
        if isSaving || isDeleting { return false }
        
        let trimmedName = child.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        
        let originalTrimmed = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = trimmedName != originalTrimmed
        let colorChanged = child.color != originalColor
        let imageChanged = (child.imageName ?? "") != originalImageName
        
        return nameChanged || colorChanged || imageChanged
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileImageSection
                nameField
                colorPickerSection
                navigationLinksSection
                saveButton
                deleteButton
            }
            .padding()
            .foregroundColor(Color("BlackFont"))
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Child Profile")
                    .font(.headline)
            }
        }
        .overlay(
            Group {
                if showSuccessMessage || showDeleteSuccessMessage {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            
                            Text(showDeleteSuccessMessage ? "Child deleted" : "Changes saved")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))
                            
                            Text(
                                showDeleteSuccessMessage
                                ? "The child profile has been removed."
                                : "Your changes have been saved."
                            )
                            .font(.subheadline)
                            .foregroundColor(Color("ColorGray"))
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color("BgColor"))
                                .shadow(color: .black.opacity(0.2),
                                        radius: 10, x: 0, y: 4)
                        )
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25),
                               value: showSuccessMessage || showDeleteSuccessMessage)
                }
            }
        )
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error Saving Profile"),
                message: Text(errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        // Confirm delete
        .alert("Delete this child?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteChild() }
        } message: {
            Text("This will remove the child and all related data (live location, history, voice files). This action cannot be undone.")
        }
        // Delete error
        .alert("Delete failed", isPresented: .constant(deleteError != nil), actions: {
            Button("OK") { deleteError = nil }
        }, message: {
            Text(deleteError ?? "")
        })
        // Delete overlay (while deleting)
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Deleting…")
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
                    )
                }
            }
        }
        // Capture original values once
        .onAppear {
            originalName = child.name
            originalColor = child.color
            originalImageName = child.imageName ?? ""
        }
    }
    
    // MARK: - Profile Image
    var displayedImage: Image {
        if let name = child.imageName, !name.isEmpty, animalIcons.contains(name) {
            return Image(name)
        } else {
            return Image(systemName: "figure.child")
        }
    }
    
    var profileImageSection: some View {
        VStack(alignment: .center, spacing: 8) {
            displayedImage
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .padding(10)
                .onTapGesture { isAvatarSelectionVisible.toggle() }
            
            Text("Tap to change avatar")
                .font(.caption)
                .foregroundColor(.gray)
            
            if isAvatarSelectionVisible {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(animalIcons, id: \.self) { iconName in
                            Image(iconName)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle().fill(child.imageName == iconName ? Color.blue.opacity(0.2) : Color.clear)
                                )
                                .padding(5)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(child.imageName == iconName ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2))
                                .onTapGesture {
                                    child.imageName = iconName
                                    isAvatarSelectionVisible = false
                                }
                        }
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Name Field
    var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.caption)
                .foregroundColor(.gray)
            TextField("Enter name", text: $child.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isSaving || isDeleting)
        }
    }
    
    // MARK: - Color Picker
    var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Rectangle()
                    .fill(colorFromString(child.color).opacity(0.8))
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.5)))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isSaving && !isDeleting {
                    withAnimation { showingColorPicker.toggle() }
                }
            }
            
            if showingColorPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                .shadow(radius: 1)
                                .onTapGesture {
                                    child.color = colorToString(color)
                                    withAnimation { showingColorPicker = false }
                                }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Navigation Links
    var navigationLinksSection: some View {
        VStack(spacing: 10) {
            navigationBox(title: "Authorized Guardians", systemImage: "person.2.fill", destination: AuthorizedGuardians(child: $child))
            navigationBox(title: "Customize Notifications", systemImage: "bell.badge", destination: CustomizeNotifications(child: $child))
        }
        .padding(.top)
        .opacity(isSaving ? 0.6 : 1.0)
    }
    
    // MARK: - Save Button (consistent with EditProfileView)
    var saveButton: some View {
        Button(action: saveChild) {
            Text(isSaving ? "Saving..." : "Save Changes")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSave ? Color("Blue") : Color("Blue").opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .disabled(!canSave)
    }
    
    // MARK: - Delete Button
    var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text("Delete Child")
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(isSaving || isDeleting)
    }
    
    // MARK: - Back Button
    var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .foregroundColor(Color("BlackFont"))
        }
    }
    
    // MARK: - Save Child
    func saveChild() {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        
        let db = Firestore.firestore()
        db.collection("guardians")
            .document(guardianID)
            .collection("children")
            .document(child.id)
            .updateData([
                "name": child.name,
                "color": child.color,
                "imageName": child.imageName ?? ""
            ]) { error in
                isSaving = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                } else {
                    // ✅ Update original values (now “no change” state)
                    originalName = child.name
                    originalColor = child.color
                    originalImageName = child.imageName ?? ""
                    
                    withAnimation {
                        showSuccessMessage = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            showSuccessMessage = false
                        }
                    }
                }
            }
    }
    
    // MARK: - Delete Child (with centered success message)
    func deleteChild() {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        
        let childIDToDelete = child.id
        let childName = child.name
        
        isDeleting = true
        
        let db = Firestore.firestore()
        let childRef = db.collection("guardians")
            .document(guardianID)
            .collection("children")
            .document(childIDToDelete)
        
        childRef.delete { error in
            if let error = error {
                isDeleting = false
                deleteError = error.localizedDescription
            } else {
                let notificationData: [String: Any] = [
                    "title": "Child Removed",
                    "body": "\(childName) has been successfully deleted.",
                    "timestamp": Timestamp(date: Date()),
                    "event": "child_deleted"
                ]
                
                db.collection("guardians")
                    .document(guardianID)
                    .collection("notifications")
                    .addDocument(data: notificationData) { error in
                        if let error = error {
                            print("Error adding delete notification: \(error.localizedDescription)")
                        } else {
                            print("Delete notification added successfully.")
                        }
                    }
                
                // ✅ Show delete success message, then dismiss
                isDeleting = false
                withAnimation {
                    showDeleteSuccessMessage = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showDeleteSuccessMessage = false
                    }
                    dismiss()
                }
            }
        }
    }
}


// MARK: These color functions are the simplified versions from the new code
// MARK: - Color Conversion
func colorFromString(_ string: String) -> Color {
    switch string {
    case "red": return .red
    case "green": return .green
    case "blue": return .blue
    case "yellow": return .yellow
    case "orange": return .orange
    case "purple": return .purple
    case "pink": return .pink
    case "brown": return .brown
    case "gray": return .gray
    default: return .gray
    }
}

func colorToString(_ color: Color) -> String {
    if color == .red { return "red" }
    if color == .green { return "green" }
    if color == .blue { return "blue" }
    if color == .yellow { return "yellow" }
    if color == .orange { return "orange" }
    if color == .purple { return "purple" }
    if color == .pink { return "pink" }
    if color == .brown { return "brown" }
    if color == .gray { return "gray" }
    return "gray"
}

// MARK: This ImagePicker struct was in the old code but removed from the new one.
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            picker.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// MARK: This 'update' function was used by the old save button.
func updateChildProfile(child: Child, guardianID: String,
                        completion: @escaping (Bool, Error?) -> Void) {
    let childID = child.id

    if let avatarName = child.imageName, !avatarName.isEmpty {
        saveToFirestore(childID: childID, avatarName: avatarName, child: child, guardianID: guardianID, completion: completion)
    } else {
        saveToFirestore(childID: childID, avatarName: nil, child: child, guardianID: guardianID, completion: completion)
    }
}

// MARK: This 'save' function was used by the old 'updateChildProfile' function.
func saveToFirestore(childID: String, avatarName: String?, child: Child, guardianID: String,
                     completion: @escaping (Bool, Error?) -> Void) {
    let db = Firestore.firestore()
    let childRef = db.collection("guardians").document(guardianID).collection("children").document(childID)

    var data: [String: Any] = [
        "name": child.name,
        "color": colorToString(colorFromString(child.color)) // Note: This calls the new colorToString
    ]

    if let avatarName = avatarName {
        data["imageName"] = avatarName
    }

    childRef.updateData(data) { error in
        DispatchQueue.main.async {
            if let error = error {
                print("❌ Error updating profile: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("✅ Profile updated successfully.")
                completion(true, nil)
            }
        }
    }
}

// MARK: These navigation helpers were in the old code but replaced in the new one.
@ViewBuilder
func navigationCard<Destination: View>(title: String, systemImage: String, destination: Destination) -> some View {
    NavigationLink(destination: destination) {
        HStack {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundColor(Color("Blue"))
                .frame(width: 30)

            Text(title)
                .foregroundColor(.primary)
                .font(.subheadline)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

@ViewBuilder
func navigationBox<Destination: View>(title: String, systemImage: String, destination: Destination) -> some View {
    NavigationLink(destination: destination) {
        HStack {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(Color("Blue"))
                .padding(.leading, 10)

            Spacer()

            Text(title)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.trailing, 10)
        }
        .frame(height: 60)
        .background(Color("navBG"))
        .cornerRadius(20)
        .shadow(color: Color("ColorGray").opacity(0.3), radius: 5, x: 0, y: 4)
    }
}
