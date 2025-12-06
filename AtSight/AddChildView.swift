//
//  AddChildView.swift
//  Atsight
//
//  Created by Najd Alsabi on 22/03/2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AddChildView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedGender: String? = nil
    @State private var showNamePage = false
    var fetchChildrenCallback: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Back Button (to go back from AddChildView)
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("BlackFont"))
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
            }
            .padding()

            // Title
            Text("What is your child's gender?")
                .font(.title)
                .bold()
                .padding(.horizontal, 5)
                .padding(.leading, 10)

            // Gender Selection
            VStack(spacing: 70) {
                GenderOptionView(
                    gender: "Boy",
                    color: .blue,
                    isSelected: selectedGender == "Boy"
                ) {
                    selectedGender = "Boy"
                }

                GenderOptionView(
                    gender: "Girl",
                    color: .pink,
                    isSelected: selectedGender == "Girl"
                ) {
                    selectedGender = "Girl"
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, 60)

            Spacer()

            // Next Button
            HStack {
                Spacer()
                Button(action: { showNamePage = true }) {
                    Text("Next")
                        .frame(width: 190)
                        .padding()
                        .background(selectedGender != nil ? Color("Blue") : .gray)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .shadow(radius: 5)
                }
                .disabled(selectedGender == nil)
                Spacer()
            }
            .padding(.bottom, 30)
            .fullScreenCover(isPresented: $showNamePage) {
                AddChildNameView(
                    isPresented: $showNamePage,             // 🔹 Binding to control the sheet
                    selectedGender: selectedGender ?? "",
                    fetchChildrenCallback: fetchChildrenCallback,
                    onFinish: { dismiss() }                 // 🔹 Close AddChildView → back to Home
                )
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Gender Option View
struct GenderOptionView: View {
    let gender: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(color.opacity(0.07))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.green : Color.clear,
                                    lineWidth: 3)
                    )

                Image(gender)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .bold))
                        .padding(4)
                        .background(Circle().fill(Color.green))
                        .offset(x: 29, y: -39)
                }
            }
            .onTapGesture(perform: onTap)

            Text(gender)
                .font(.title3)
                .foregroundColor(Color("BlackFont"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Child Name View
struct AddChildNameView: View {
    @Binding var isPresented: Bool
    let selectedGender: String
    var fetchChildrenCallback: (() -> Void)?
    var onFinish: (() -> Void)?

    @State private var childName = ""
    @State private var isLoading = false

    // Popup states
    @State private var showSuccessMessage = false
    @State private var showDuplicateMessage = false

    var body: some View {
        ZStack {
            BubbleBackground(color: selectedGender == "Boy" ? .blue : .pink)

            VStack(alignment: .leading, spacing: 30) {
                // Back Button (to go back to gender selection)
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .font(.system(size: 22, weight: .medium))
                            .padding(8)
                    }
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 10)

                // Title
                Text("What is your child's name?")
                    .font(.title)
                    .bold()
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    .padding(.leading, 10)

                // Text Field
                TextField("Enter name", text: $childName)
                    .padding()
                    .background(Color("TextFieldBg").opacity(0.5))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                selectedGender == "Boy"
                                ? Color.blue.opacity(0.5)
                                : Color.pink.opacity(0.5),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .gray.opacity(0.15),
                            radius: 3, x: 0, y: 2)
                    .padding(.horizontal, 40)

                Spacer()

                // Submit Button
                HStack {
                    Spacer()
                    Button(action: handleSubmit) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: .white)
                                )
                                .frame(width: 190, height: 44)
                        } else {
                            Text("Submit")
                                .frame(width: 190)
                                .padding()
                                .background(childName.isEmpty ? .gray : Color("Blue"))
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .semibold))
                                .cornerRadius(30)
                                .shadow(color: .gray.opacity(0.4),
                                        radius: 5, x: 0, y: 3)
                                .opacity(childName.isEmpty ? 0.5 : 1.0)
                        }
                    }
                    .disabled(childName.isEmpty || isLoading)
                    Spacer()
                }
                .padding(.bottom, 63)
            }

            // MARK: - Duplicate Name Popup
            if showDuplicateMessage {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()

                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)

                        Text("Duplicate name")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))

                        Text("You already have a child with this name.")
                            .font(.subheadline)
                            .foregroundColor(Color("ColorGray"))
                            .multilineTextAlignment(.center)
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
                .animation(.easeInOut(duration: 0.25), value: showDuplicateMessage)
            }

            // MARK: - Success Popup
            if showSuccessMessage {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()

                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        Text("Child added")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))

                        Text("\(childName) has been successfully added.")
                            .font(.subheadline)
                            .foregroundColor(Color("ColorGray"))
                            .multilineTextAlignment(.center)
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
                .animation(.easeInOut(duration: 0.25), value: showSuccessMessage)
            }

            if isLoading {
                ZStack {
                    Color.black.opacity(0.05).ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - Firestore Logic
    func handleSubmit() {
        isLoading = true
        guard let guardianID = Auth.auth().currentUser?.uid else {
            print("No guardian logged in")
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        let childrenRef = db.collection("guardians")
            .document(guardianID)
            .collection("children")

        // Step 1: Check for duplicate name
        childrenRef.whereField("name", isEqualTo: childName)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking duplicates: \(error.localizedDescription)")
                    DispatchQueue.main.async { isLoading = false }
                    return
                }

                if let documents = snapshot?.documents, !documents.isEmpty {
                    DispatchQueue.main.async {
                        withAnimation {
                            showDuplicateMessage = true
                        }
                        // Auto-hide duplicate popup after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showDuplicateMessage = false
                            }
                        }
                        isLoading = false
                    }
                    return
                }

                // Step 2: Save new child
                let child = Child(
                    id: UUID().uuidString,
                    name: childName,
                    color: selectedGender == "Boy" ? "blue" : "pink",
                    imageData: nil,
                    imageName: nil
                )

                saveChildToFirestore(guardianID: guardianID, child: child) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            // Update local child list
                            fetchChildrenCallback?()

                            // Create a notification in Firestore
                            let notificationData: [String: Any] = [
                                "title": "New Child Added",
                                "body": "\(child.name) has been successfully added.",
                                "timestamp": Timestamp(date: Date()),
                                "event": "child_added"
                            ]

                            db.collection("guardians")
                                .document(guardianID)
                                .collection("notifications")
                                .addDocument(data: notificationData) { error in
                                    if let error = error {
                                        print("Error adding notification: \(error.localizedDescription)")
                                    } else {
                                        print("Notification added successfully.")
                                    }
                                }

                            // Show success popup
                            withAnimation {
                                showSuccessMessage = true
                            }

                            // Auto-dismiss popup, then close screens
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation {
                                    showSuccessMessage = false
                                }
                                isPresented = false
                                onFinish?()
                            }

                        case .failure(let error):
                            print("Error saving child: \(error.localizedDescription)")
                        }
                        isLoading = false
                    }
                }
            }
    }

    // MARK: - Save Helper
    func saveChildToFirestore(
        guardianID: String,
        child: Child,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "name": child.name,
            "color": child.color,
            "createdAt": Timestamp(date: Date())
        ]

        db.collection("guardians").document(guardianID)
            .collection("children")
            .document(child.id)
            .setData(data) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}


// MARK: - Bubble Background
struct BubbleBackground: View {
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<12, id: \.self) { _ in
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: CGFloat.random(in: 40...100))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
            }
        }
    }
}

#Preview {
    AddChildView()
}
