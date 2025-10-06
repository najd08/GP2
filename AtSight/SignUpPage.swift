import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpPage: View {
    @State private var isTermsAccepted = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""   // 🔑 Confirm password
    @State private var errorMessage = ""
    @State private var isRegistered = false
    
    // MARK: - Validation Computed Properties
    private var isEmailValid: Bool {
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailFormat)
        return emailPredicate.evaluate(with: email)
    }
    
    private var passwordRequirements: [String] {
        var reqs: [String] = []
        if password.count < 8 {
            reqs.append("At least 8 characters")
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            reqs.append("At least 1 uppercase letter")
        }
        if password.rangeOfCharacter(from: .lowercaseLetters) == nil {
            reqs.append("At least 1 lowercase letter")
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            reqs.append("At least 1 number")
        }
        return reqs
    }
    
    private var isPasswordValid: Bool {
        passwordRequirements.isEmpty
    }
    
    private var doPasswordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        isEmailValid &&
        isPasswordValid &&
        doPasswordsMatch
    }
    
    var body: some View {
        VStack(spacing: 10) {
            
            VStack(spacing: 5) {
                Image("logoPin")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                Text("Get Started")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("FontColor"))
                Text("By Creating an account")
                    .font(.subheadline)
                    .foregroundColor(Color("ColorGray"))
            }
            
            VStack(spacing: 15) {
                // First name
                TextField("First Name", text: $firstName)
                    .padding()
                    .background(Color("ColorGray").opacity(0.2))
                    .cornerRadius(50)
                
                // Last name
                TextField("Last Name", text: $lastName)
                    .padding()
                    .background(Color("ColorGray").opacity(0.2))
                    .cornerRadius(50)
                
                // Email
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Valid email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color("ColorGray").opacity(0.2))
                        .cornerRadius(50)
                    
                    if !email.isEmpty && !isEmailValid {
                        Text("Invalid email format")
                            .font(.caption)
                            .foregroundColor(Color("ColorRed"))
                    }
                }
                
                // Password
                VStack(alignment: .leading, spacing: 5) {
                    SecureField("Strong Password", text: $password)
                        .padding()
                        .background(Color("ColorGray").opacity(0.2))
                        .cornerRadius(50)
                    
                    if !password.isEmpty && !isPasswordValid {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(passwordRequirements, id: \.self) { requirement in
                                Text("• \(requirement)")
                                    .font(.caption)
                                    .foregroundColor(Color("ColorRed"))
                            }
                        }
                    }
                }
                
                // Confirm password
                VStack(alignment: .leading, spacing: 5) {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color("ColorGray").opacity(0.2))
                        .cornerRadius(50)
                    
                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(Color("ColorRed"))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Error message from Firebase
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(Color("ColorRed"))
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color("ColorRed").opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
            }
            
            // Sign Up button
            Button(action: {
                register()
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(Color("whiteFont"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color("button") : Color("button"))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .disabled(!isFormValid)
            
            // Navigation to login
            HStack {
                Text("Do you have an account?")
                NavigationLink(destination: LoginPage()) {
                    Text("Sign In")
                        .foregroundColor(Color("Blue"))
                        .underline()
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color("CustomBackground").edgesIgnoringSafeArea(.all))
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $isRegistered) {
            MainView()
        }
    }
    
    // MARK: - Register
    func register() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else if let userId = result?.user.uid {
                let db = Firestore.firestore()
                db.collection("guardians").document(userId).setData([
                    "FirstName": firstName,
                    "LastName": lastName,
                    "email": email,
                    "password": password,
                    "phonenum": "",
                    "region": [0.0, 0.0]
                ]) { error in
                    if let error = error {
                        errorMessage = "Failed to save user data: \(error.localizedDescription)"
                    } else {
                        isRegistered = true
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SignUpPage()
    }
}
