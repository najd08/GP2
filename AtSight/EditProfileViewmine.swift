/*import SwiftUI

struct EditProfileViewmine: View {
    @State private var name: String = "Melissa Peters"
    @State private var email: String = "melpeters@gmail.com"
    @State private var password: String = "************"
    @State private var dateOfBirth: String = "23/05/1995"
    @State private var country: String = "Nigeria"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray, lineWidth: 2)
                            .frame(width: 100, height: 100)
                        Image(systemName: "person")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            // Profile image selection action
                        }) {
                            Image(systemName: "camera.fill")
                                .padding(6)
                                .background(Color.gray.opacity(0.6))
                                .clipShape(Circle())
                                .foregroundColor(.white)
                                .offset(x: 35, y: 35)
                        }
                    }
                }
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 15) {
                        TextField("Name", text: $name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .keyboardType(.emailAddress)
                        
                        HStack {
                            Text("Country/Region")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(country)
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }
                
                Button(action: {
                    // Save changes action
                }) {
                    Text("Save changes")
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                }
                .disabled(name.isEmpty || email.isEmpty || password.isEmpty)
                .padding(.bottom, 20)
            }
            .navigationTitle("Edit Profile")
        }
    }
}

//struct EditProfileView_Previews: PreviewProvider {
//    static var previews: some View {
//        EditProfileView()
//    }
//}
*/
