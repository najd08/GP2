import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 8) {
                    // App name top-left
                    HStack {
                        Text("AtSight")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color("Blue"))
                            .padding(.leading, 10)
                        Spacer()
                    }

                    // Logo
                    Image("locationMarkLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)

                    // Welcome text
                    Text("Welcome")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("Blue"))

                    // Navigation Button QRCodeView
                    NavigationLink(destination: PairingView()) {
                        Text("Get Started")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 160, height: 35)
                            .background(Color("button"))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 10)
            }
        }.navigationBarBackButtonHidden(true)

    }
}

#Preview {
    WelcomeView()
}
