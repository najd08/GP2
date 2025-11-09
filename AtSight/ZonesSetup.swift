import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

//MARK: - extensions (commented out because it is already in another file):
// Setting up the user's coordinates to be in Riyadh by default
//extension CLLocationCoordinate2D {
//    static var userLocation: CLLocationCoordinate2D {
//        return .init(latitude: 24.7136, longitude: 46.6753) // Riyadh
//    }
//}
//
//// Setting up the zoom around the user's location
//extension MKCoordinateRegion {
//    static var userRegion: MKCoordinateRegion {
//        return .init(center: .userLocation, latitudinalMeters: 5000, longitudinalMeters: 5000)
//    }
//}
//MARK: -

struct ZonesSetup: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Intitalize ViewModel.
    @StateObject private var viewModel: ZonesViewModel
    
    // Initializer to receive the childID and set up the ViewModel.
    init(childID: String) {
        _viewModel = StateObject(wrappedValue: ZonesViewModel(childID: childID))
    }
    
    // 1. Updated default camera position to use userRegion
    @State private var cameraPosition: MapCameraPosition = .region(.userRegion)
    
    // 2. State to hold the location of the *final* pin
    @State private var pinnedLocation: CLLocationCoordinate2D?
    
    // 3. State to track the map's current center as the user pans
    @State private var mapCenter: CLLocationCoordinate2D = .userLocation // Initialize with default

    var body: some View {
        VStack {
            // MARK: - Title
            Text("Add Zone")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 8)
            
            // 4. Wrap Map in ZStack to allow overlay
            ZStack {
                Map(position: $cameraPosition) {
                    
                    // 5. Add Annotation for the *final* pinned location
                    if let pinnedLocation {
                        Annotation("New Zone Pin", coordinate: pinnedLocation) {
                            Image(systemName: "mappin")
                                .font(.title)
                                .foregroundColor(.red)
                                .shadow(radius: 2)
                        }
                    }
                }
                // 6. Update mapCenter state as the camera moves
                .onMapCameraChange { context in
                    // We use .continuous update policy to track the center
                    // If this is too laggy, you can use .onEnded
                    self.mapCenter = context.region.center
                }
                .frame(height: 500)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.bottom, 10)
                
                // 7. Add a crosshair/pin icon in the center that doesn't move
                Image(systemName: "plus.circle.fill") // You can also use "mappin"
                    .font(.title)
                    .foregroundColor(.blue) // Use a distinct color
                    .shadow(radius: 2)
                    .allowsHitTesting(false) // Ensures map gestures go through
            }
            
            // 8. Add a button to set the pin
            Button(action: {
                // Set the final pin location to the map's current center
                self.pinnedLocation = self.mapCenter
            }) {
                Text("Set Pin Here")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            Spacer() // Pushes the content to the top
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading:
                //navigate back button:
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("BlackFont"))
                            .font(.system(size: 20, weight: .bold))
                    }
                }
            ,
            // MARK: - Navigation Button (Top Right)
            trailing:
                // NOTE: This NavigationLink will need a SavedZonesView struct defined in another file.
                NavigationLink(destination: SavedZonesView(viewModel: viewModel)) {
                    Text("Show Zones").fontWeight(.semibold).foregroundColor(.black).padding(7).background(Color("Buttons")).cornerRadius(10)
                }
        )
    }
}

struct ZonesSetup_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZonesSetup(childID: "test-child-id")
        }
    }
}

