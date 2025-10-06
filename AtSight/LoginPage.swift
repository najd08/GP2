import SwiftUI
import Firebase
import FirebaseAuth

struct LoginPage: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showResetPasswordAlert = false
    @State private var resetPasswordMessage = ""
    @State private var isLoggedIn = false
    @State private var loginErrorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                HStack {
                  /*  Image("logotext")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100)*/
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, -20)
                VStack(spacing: 5) {
                    Image("logoPin")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 230)      .padding(.top, 80)

                    Text("Welcome back")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color("FontColor"))

                    Text("Sign in to access your account")
                        .font(.subheadline)
                        .foregroundColor(Color("ColorGray"))
                }

                VStack(spacing: 15) {
                    TextField("Enter your email", text: $email)
                        .padding()
                        .background(Color("ColorGray").opacity(0.2))
                        .cornerRadius(50)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color("ColorGray").opacity(0.2))
                        .cornerRadius(50)

                    Button(action: {
                        resetPassword()
                    }) {
                        Text("Forget Password?")
                            .font(.footnote)
                            .foregroundColor(Color("ColorGray"))
                    }
                }
                .padding(.horizontal, 20)

                // Show error message if needed
                if !loginErrorMessage.isEmpty {
                    Text(loginErrorMessage)
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

                Button(action: {
                    login()
                }) {
                    Text("Log in")
                        .font(.headline)
                        .foregroundColor(Color("whiteFont"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("button"))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)

                HStack {
                    Text("New Member?").foregroundColor(Color("BlackFont"))
                    NavigationLink(destination: SignUpPage()) {
                        Text("Register Now")
                            .foregroundColor(Color("Blue"))
                            .underline()
                    }
                }

                Spacer()
            }
            .background(Color("CustomBackground").edgesIgnoringSafeArea(.all))
            .alert(isPresented: $showResetPasswordAlert) {
                Alert(title: Text("Password Reset"), message: Text(resetPasswordMessage), dismissButton: .default(Text("OK")))
            }
            .fullScreenCover(isPresented: $isLoggedIn) {
                MainView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarBackButtonHidden(true)
    }

    func login() {
        loginErrorMessage = ""

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            loginErrorMessage = "Please enter your email."
            return
        }

        guard !password.isEmpty else {
            loginErrorMessage = "Please enter your password."
            return
        }

        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { result, error in
            if let error = error {
                let lowerError = error.localizedDescription.lowercased()

                if lowerError.contains("password") ||
                    lowerError.contains("no user") ||
                    lowerError.contains("invalid") ||
                    lowerError.contains("malformed") ||
                    lowerError.contains("expired") {
                    loginErrorMessage = "The email or password you entered is incorrect. Please try again."
                } else {
                    loginErrorMessage = error.localizedDescription
                }
            } else {
                isLoggedIn = true
            }
        }
    }

    func resetPassword() {
        guard !email.isEmpty else {
            resetPasswordMessage = "Please enter your email address first."
            showResetPasswordAlert = true
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                resetPasswordMessage = error.localizedDescription
            } else {
                resetPasswordMessage = "A password reset link has been sent to your email."
            }
            showResetPasswordAlert = true
        }
    }
}

#Preview {
    LoginPage()
}
