//fixed zones fetching by changing firebase rules! ✅
//removed the need for tap gesture due to a conflict from the new update. now you should be able to move the pin anywhere you want then add the zone, no tapping on screen needed. ✅

import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

//MARK: - extensions:
// Setting up the user's coordinates to be in Riyadh by default
extension CLLocationCoordinate2D {
    static var userLocation: CLLocationCoordinate2D {
        return .init(latitude: 24.7136, longitude: 46.6753)
    }
}

// Setting up the zoom around the user's location
extension MKCoordinateRegion {
    static var userRegion: MKCoordinateRegion {
        return .init(center: .userLocation, latitudinalMeters: 5000, longitudinalMeters: 5000)
    }
}

//MARK: - Variables:
struct AddZonePage: View {
    @Environment(\.presentationMode) var presentationMode
    
    // The ViewModel is now the single source of truth for zone data.
    @StateObject private var viewModel: ZonesViewModel
    
    // Define the camera's position
    @State private var cameraPosition = MKCoordinateRegion.userRegion
    
    //temporary zone values that the user can adjust before saving the zone
    @State private var tempZoneCoordinates = CLLocationCoordinate2D.userLocation
    @State private var tempZoneSize: Double = 25 // Default radius in meters
    @State private var tempIsSafeZone = true
    @State private var tempZoneName = ""
    
    // State for location permission alerts
    @State private var showLocationAlert = false
    @State private var locationAlertMessage = ""
    @State private var hasCenteredOnUser = false
    
    // State to track keyboard visibility.
    @State private var isKeyboardVisible = false
    
    // State to fix initial zone size bug
    @State private var mapIsReady = false
    
    // Conversion factor - explicitly defining meters per unit
    let metersPerUnit: Double = 1.0 // 1 unit = 1 meter for radius
    
    // Navigation bar offset values - adjust these as needed
    let navigationBarYOffset: CGFloat = 30.0  // Vertical offset to compensate for navigation bar
    
    // Create a temporary zone for display
    var tempZone: Zone {
        return Zone(coordinate: tempZoneCoordinates, zoneName: "", isSafeZone: tempIsSafeZone, zoneSize: tempZoneSize)
    }
    
    // Calculate actual radius and diameter in meters
    var radiusInMeters: Double {
        return tempZoneSize * metersPerUnit
    }
    
    var diameterInMeters: Double {
        return radiusInMeters * 2
    }

    // Initializer to receive the childID and set up the ViewModel.
    init(childID: String) {
        _viewModel = StateObject(wrappedValue: ZonesViewModel(childID: childID))
    }
    
    //MARK: - Main View:
    var body: some View {
        ZStack {
            // Show both the saved zones from the ViewModel and the temporary zone
            Map(coordinateRegion: $cameraPosition,
                interactionModes: [.all],
                showsUserLocation: true,
                // Only show tempZone when mapIsReady to prevent size bug
                annotationItems: mapIsReady ? (viewModel.zones + [tempZone]) : []) { zone in                MapAnnotation(coordinate: zone.coordinate) {
                    ZoneAnnotationView(zone: zone, isTemp: zone.id == tempZone.id)
                        .frame(width: calculateZoneSize(zone.zoneSize),
                               height: calculateZoneSize(zone.zoneSize))
                }
            }
            .onAppear {
                viewModel.fetchZones() //fetch zones when the map loads
                viewModel.requestLocationPermission() // Ask for location permission
                updateOffsetPinPosition() // Set initial pin position
            }
            // Convert the tap location to map coordinates wherever the user presses:
            .onTapGesture { location in
                self.hideKeyboard() // Hide keyboard on tap
                // Removed conflicting logic that set pin on tap
            }
            // React to user location updates to center the map once.
            .onReceive(viewModel.$userLocation) { userLocation in
                if let userLocation = userLocation, !hasCenteredOnUser {
                    updateCameraPositionWithOffset(to: userLocation, zoom: true)
                    hasCenteredOnUser = true
                }
            }
            // React to location authorization changes
            .onReceive(viewModel.$authorizationStatus) { status in
                handleLocationAuthorizationStatus(status)
            }
            .ignoresSafeArea()
            
            // Zoom buttons positioned above the overlay
            VStack {
                Spacer().allowsHitTesting(false) // <-- THIS IS THE FIX
                
                // Zoom control buttons
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // MARK: - RECENTER BUTTON ADDED
                        Button(action: {
                            if let userLocation = viewModel.userLocation {
                                updateCameraPositionWithOffset(to: userLocation, zoom: true)
                            } else {
                                // This will either ask for permission or re-trigger location update
                                viewModel.requestLocationPermission()
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.title2).padding(10).background(Color.white).clipShape(Circle()).shadow(radius: 2)
                        }
                        
                        // Zoom in button
                        Button(action: { zoomIn() }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.title2).padding(10).background(Color.white).clipShape(Circle()).shadow(radius: 2)
                        }
                        // Zoom out button
                        Button(action: { zoomOut() }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.title2).padding(10).background(Color.white).clipShape(Circle()).shadow(radius: 2)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 20)
                
                ZoneControlsOverlay(
                    tempZoneName: $tempZoneName,
                    tempIsSafeZone: $tempIsSafeZone,
                    tempZoneSize: $tempZoneSize,
                    radiusInMeters: radiusInMeters
                ) {
                    // Call the ViewModel's addZone function
                    viewModel.addZone(coordinates: tempZoneCoordinates,
                                      size: tempZoneSize,
                                      isSafe: tempIsSafeZone,
                                      name: tempZoneName)
                    // Reset the text field after adding a zone
                    tempZoneName = ""
                }
            }
            
            // MARK: - MODIFICATION HERE
             // Sync the temp zone's coordinates with the map's center
             .onChange(of: cameraPosition.center.latitude) { _ in
                 updateOffsetPinPosition()
                 self.hideKeyboard()
             }
             .onChange(of: cameraPosition.center.longitude) { _ in
                 updateOffsetPinPosition()
                 self.hideKeyboard()
             }
             // Add listener for zoom to scale offset and fix size bug
             .onChange(of: cameraPosition.span.latitudeDelta) { _ in
                 updateOffsetPinPosition()
                 if !mapIsReady {
                     mapIsReady = true // Mark map as ready on first span update
                 }
             }
             // MARK: - END MODIFICATION

        }//end zstack
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { //navigate back
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Color("BlackFont"))
                    .font(.system(size: 20, weight: .bold))
            }
        )
        .toolbar {
            // add page title + "Show Zones" button:
            ToolbarItem(placement: .principal) {
                Text("Add Zone").font(.system(size: 24, weight: .bold))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                // Pass the existing viewModel instance to SavedZonesView
                NavigationLink(destination: SavedZonesView(viewModel: viewModel)) {
                    Text("Show Zones").fontWeight(.semibold).foregroundColor(.black).padding(7).background(Color("Buttons")).cornerRadius(10)
                }
            }
        } //end toolbar
        // Alert for location permission status
        .alert("Location Access", isPresented: $showLocationAlert) {
            Button("OK") {}
            // Only show settings button if permission is denied or restricted
            if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted {
                Button("Settings") { viewModel.openSettings() }
            }
        } message: { Text(locationAlertMessage) }
    } //end body
    
    
    //MARK: - Functions & Struct:
    
    /// Calculates the new coordinates for the temp zone, offset slightly above the map's center.
    private func updateOffsetPinPosition() {
        // Calculate a latitude offset (10% of the map's current visible height)
        let latitudeOffset = cameraPosition.span.latitudeDelta * 0.1
        // Apply the offset (add to latitude to move *north* or "up" on the map)
        tempZoneCoordinates = CLLocationCoordinate2D(
            latitude: cameraPosition.center.latitude + latitudeOffset,
            longitude: cameraPosition.center.longitude
        )
    }
    
    //updates camera position with an offset to account for the bottom UI.
    private func updateCameraPositionWithOffset(to coordinate: CLLocationCoordinate2D, zoom: Bool = false) {
        withAnimation(.easeInOut) {
            let newSpan = zoom ? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) : cameraPosition.span
            let offset = newSpan.latitudeDelta * 0.25
            let adjustedCenter = CLLocationCoordinate2D(latitude: coordinate.latitude - offset, longitude: coordinate.longitude)
            cameraPosition = MKCoordinateRegion(center: adjustedCenter, span: newSpan)
        }
    }
    
    //updates camera position and optionally zooms in
    private func updateCameraPosition(to coordinate: CLLocationCoordinate2D, zoom: Bool = false) {
        withAnimation(.easeInOut) {
            let newSpan = zoom ? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) : cameraPosition.span
            cameraPosition = MKCoordinateRegion(center: coordinate, span: newSpan)
        }
    }

    //alerts to be shown if the user denies access to his location:
    private func handleLocationAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied:
            locationAlertMessage = "Location access has been denied. To see your current location on the map, please enable it in Settings."
            showLocationAlert = true
        case .restricted:
            locationAlertMessage = "Location access is restricted on this device."
            showLocationAlert = true
        default:
            break
        }
    }
    
    //function to adjust the zone's circle size when zooming:
    func calculateZoneSize(_ zoneSize: Double) -> CGFloat {
        let metersPerPoint = cameraPosition.span.latitudeDelta * 111000
        // Guard against division by zero on first load
        guard metersPerPoint > 0 else { return 0 }
        let zoomFactor = CGFloat(metersPerPoint)
        let baseSize: CGFloat = CGFloat(zoneSize * 2)
        return baseSize / zoomFactor * 5000
    }
    
    // Convert a tap location on screen to map coordinates with navigation bar offset
    func convertToCoordinate(location: CGPoint) -> CLLocationCoordinate2D {
        let mapSize = UIScreen.main.bounds.size
        // Apply the navigation bar offset to get the adjusted center point
        let adjustedYPosition = mapSize.height / 2 + navigationBarYOffset
        let centerPoint = CGPoint(x: mapSize.width / 2, y: adjustedYPosition)
        // Calculate the difference between tap location and adjusted center
        let xDelta = (location.x - centerPoint.x) / mapSize.width
        let yDelta = (location.y - centerPoint.y) / mapSize.height
        // Convert the screen deltas to coordinate deltas
        let latitudeDelta = cameraPosition.span.latitudeDelta * Double(-yDelta)
        let longitudeDelta = cameraPosition.span.longitudeDelta * Double(xDelta)
        // Apply the deltas to the center coordinate
        let newLatitude = cameraPosition.center.latitude + latitudeDelta
        let newLongitude = cameraPosition.center.longitude + longitudeDelta
        return CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
    }
    
    // Function to zoom in the map
    func zoomIn() {
        var newRegion = cameraPosition
        newRegion.span.latitudeDelta /= 2.0
        newRegion.span.longitudeDelta /= 2.0
        cameraPosition = newRegion
    }
    
    // Function to zoom out the map
    func zoomOut() {
        var newRegion = cameraPosition
        newRegion.span.latitudeDelta *= 2.0
        newRegion.span.longitudeDelta *= 2.0
        cameraPosition = newRegion
    }
} // end AddZonePage struct

// MARK: - Annotation Subview
struct ZoneAnnotationView: View {
    let zone: Zone
    let isTemp: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(zone.isSafeZone ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
            Image(systemName: "mappin")
                .foregroundColor(isTemp ? .red : .black)
                .font(.title)
            Text(zone.zoneName)
                .font(.system(size: 24)).bold().foregroundColor(Color("BlackFont"))
                .offset(y: -30)
                .shadow(color: .white, radius: 2, x: 2, y: 2)
        }
    }
}

// MARK: - Zone Controls Overlay Subview
struct ZoneControlsOverlay: View {
    @Binding var tempZoneName: String
    @Binding var tempIsSafeZone: Bool
    @Binding var tempZoneSize: Double
    var radiusInMeters: Double
    var addZoneAction: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Color.clear
                .frame(height: UIScreen.main.bounds.height / 3)
                .cornerRadius(20).shadow(radius: 10)
                .overlay(
                    VStack {
                        // Zone name text field
                        TextField("Enter your zone's name", text: $tempZoneName)
                            .padding().background(Color("TextFieldBg")).cornerRadius(20).padding([.horizontal, .top])
                        // Safe / Unsafe buttons:
                        HStack {
                            Button { tempIsSafeZone = true } label: {
                                Text("Safe").fontWeight(.bold).frame(maxWidth: .infinity).padding(10)
                                    .background(tempIsSafeZone ? Color.green : Color.gray.opacity(0.3))
                                    .foregroundColor(tempIsSafeZone ? .white : .black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.padding([.leading, .bottom])
                            Button { tempIsSafeZone = false } label: {
                                Text("Unsafe").fontWeight(.bold).frame(maxWidth: .infinity).padding(10)
                                    .background(tempIsSafeZone ? Color.gray.opacity(0.3) : Color.red)
                                    .foregroundColor(tempIsSafeZone ? .black : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.padding([.trailing, .bottom])
                        }
                        // Slider to adjust zone's size:
                        Text("Zone size: \(Int(tempZoneSize))").fontWeight(.semibold)
                        Slider(value: $tempZoneSize, in: 1...150).accentColor(.black).padding([.horizontal, .bottom], 20)
                        // Zone size hint for user:
                        Text("Hint: This zone equals \(Int(Double.pi * radiusInMeters * radiusInMeters)) sq. meters.")
                            .italic().font(.system(size: 14)).foregroundColor(.black).padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.7))
                            .cornerRadius(8).padding(.horizontal).padding(.bottom)
                    }
                        .background(Color.mint.opacity(0.25)).border(Color.green).cornerRadius(10).padding().padding(.bottom, -20)
                )
            // Add Zone button:
            Button(action: addZoneAction) {
                Text("Add").font(.title2).fontWeight(.bold).foregroundColor(.white)
                    .padding(.horizontal, 20).padding()
            }
            .background(Color("Blue")).cornerRadius(30).padding(.bottom)
        }
    }
}
