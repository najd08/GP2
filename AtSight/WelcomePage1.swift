import SwiftUI

struct WelcomePage1: View {
    @State private var currentPage = 0 // Track the current slide

    let slides = [
        ("slide1", "Ensure your Child’s Safety"),
        ("slide2", "Get your Child real-time location updates"),
        ("slide3", "Emergency SOS button for your Child")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo at the top
                Image("logo2")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 240) // Adjust size of the logo
                    .padding(.bottom, 30)

                // Image slider with text
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        VStack {
                            Image(slides[index].0) // Slide image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 350)
                            

                            Text(slides[index].1) // Slide text
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.top, 10)
                        }
                        .tag(index) // Each slide has a unique tag
                    }
                    
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Disables default dots
                .frame(height: 400)
                .padding(.top, -90)

                // Custom dots
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.black : Color.gray) // Highlight current dot
                            .frame(width: 10, height: 10) // Size of the dots
                    }
                }
                .padding(.bottom, 10)

                Spacer()

                // Get Started Button
                NavigationLink(destination: SignUpPage()) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(Color("BlackFont"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("button"))
                        .cornerRadius(10)
                        .padding(.horizontal, 30)
                }

                // Already have an account?
                HStack {
                    Text("Already have an Account?")
                        .font(.footnote)

                    NavigationLink(destination: LoginPage()) {
                        Text("Log In")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .padding(.bottom,70)
                Spacer()
            }.navigationBarBackButtonHidden(true)

            .padding()
            .background(Color("CustomBackground").edgesIgnoringSafeArea(.all)) // 
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Optimized for all devices
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    WelcomePage1()
}
