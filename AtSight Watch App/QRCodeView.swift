import SwiftUI

struct QRCodeView: View {
    @State private var showConnectedMessage = false
    @State private var navigateToHome = false // Trigger for navigation

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    Spacer()

                    ZStack {
                        Image("QR")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 80, height: 80)

                        QRCornerOverlay(cornerLength: 10, lineWidth: 2, color: Color("button"))
                            .frame(width: 100, height: 100)
                    }

                    Text("Scan the QR code using the app to connect to the watch.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color("Blue"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    Spacer()
                }
                .padding(.bottom, 8)
                .onTapGesture {
                    showConnectedMessage = true
                }

                // Connected popup
                if showConnectedMessage {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 10) {
                        Text("connected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("button"))

                        Text("The watch has been\nsuccessfully connected.")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            navigateToHome = true // Trigger navigation
                        }) {
                            Text("Done")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 6)
                                .background(Color("button"))
                                .cornerRadius(20)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 5)
                }

                // NavigationLink outside the popup, always active
                NavigationLink(destination: HomeView_Watch(), isActive: $navigateToHome) {
                    EmptyView()
                }                .hidden()

            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Corner Overlay View

struct QRCornerOverlay: View {
    let cornerLength: CGFloat
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))
                }
                .stroke(color, lineWidth: lineWidth)

                Path { path in
                    path.move(to: CGPoint(x: w, y: cornerLength))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w - cornerLength, y: 0))
                }
                .stroke(color, lineWidth: lineWidth)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h - cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: cornerLength, y: h))
                }
                .stroke(color, lineWidth: lineWidth)

                Path { path in
                    path.move(to: CGPoint(x: w, y: h - cornerLength))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w - cornerLength, y: h))
                }
                .stroke(color, lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QRCodeView()
}
