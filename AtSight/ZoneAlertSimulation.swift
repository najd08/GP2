//MARK: this page is meant for debugging, but it now supports the child's real coordinates and displays them on the map (Sprint4 compleated) ✅✅✅
//TO DO:
//get current child's location coordinates from db (liveLocation). ✅
//place these coordinates in the simulatedLatitude and simulatedLongitude variables ✅
//every 2 and a half minutes, check if the current location has changed, if yes, then store the old one in the lastKnownChildLocation variable and update the current child location. ✅

import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

//MARK: - ZoneAlertSimulation View
struct ZoneAlertSimulation: View {
    // MARK: Environment & StateObject
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: ZonesViewModel // Manages all zone and location data

    // MARK: State
    @State private var cameraPosition = MKCoordinateRegion.userRegion

    //MARK: - Simulation Cords variables:
    @State private var simulatedLatitude: String = "24.77151"
    @State private var simulatedLongitude: String = "46.64214"
    // store the last time an alert was sent:
    @State private var zoneAlertTimestamps: [String: Date] = [:]

    // MARK: - Simulated Annotation
    @State private var simulatedAnnotation: Zone?
    @State private var lastKnownChildLocation: CLLocationCoordinate2D?
    @State private var currentChildLocation: CLLocationCoordinate2D?
    @State private var locationListener: ListenerRegistration? // For live location

    // Child Name for Display... Initial value changed to empty, awaiting fetch from DB.
    @State private var childName: String = ""
    
    // Initializer to set up the ViewModel with the correct childID
    init(childID: String) {
        _viewModel = StateObject(wrappedValue: ZonesViewModel(childID: childID))
    }

    // MARK: - Main Body
    var body: some View {
        VStack {
            Map(coordinateRegion: $cameraPosition,
                interactionModes: [.all],
                annotationItems: combinedZones) { zone in

                MapAnnotation(coordinate: zone.coordinate) {
                    if zone.isSimulated {
                        VStack(spacing: 0) {
                            Text(zone.zoneName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)

                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                                .shadow(radius: 2)
                        }
                    } else {
                        ZoneAnnotationView(zone: zone, isTemp: false)
                            .frame(width: calculateZoneFrame(zoneSize: zone.zoneSize),
                                   height: calculateZoneFrame(zoneSize: zone.zoneSize))
                    }
                }
            }
            // Fetches initial data when the view appears.
            .onAppear {
                NotificationManager.instance.requestAuthorization() // Ask for notification permission
                viewModel.fetchZones()
                fetchChildName()
                startLiveLocationListener() // Fulfills TO-DO #1
            }
            .ignoresSafeArea()

            //MARK: - Textfields for simulating entered cords:
            HStack {
                TextField("Latitude", text: $simulatedLatitude)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $simulatedLongitude)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Button("Simulate") {
                    submitSimulationCords()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)

            //MARK: - Buttons for simulating fixed cords (for testing only):
            Button("Simulate danger zone entry") {
                simulatedLatitude = "24.7605973"
                simulatedLongitude = "46.6485463"
                submitSimulationCords()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)

            Button("Simulate safe zone exit") {
                simulatedLatitude = "24.77081"
                simulatedLongitude = "46.68994"
                submitSimulationCords()
                // wait 2 seconds then update location to be outside tested zone:
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    simulatedLatitude = "24.77333"
                    simulatedLongitude = "46.68333"
                    submitSimulationCords()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.black)
            .cornerRadius(8)
        }
        .onTapGesture {
            self.hideKeyboard() //hides keyboard when clicking away from it.
        }

        //MARK: - rest of code:
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
            Image(systemName: "chevron.left")
                .foregroundColor(Color("BlackFont"))
                .font(.system(size: 20, weight: .bold))
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Child Zones").font(.system(size: 24, weight: .bold))
            }
        }
        .onDisappear {
            locationListener?.remove() // Stop listening when view closes
        }
    }

    // MARK: - Computed Property
    private var combinedZones: [Zone] {
        if let simulated = simulatedAnnotation {
            return viewModel.zones + [simulated]
        } else {
            return viewModel.zones
        }
    }

    // MARK: - Helper Functions
    
    // Updates camera position for the simulation
    private func updateCameraPosition(to coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 1)) {
            cameraPosition = MKCoordinateRegion(center: coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
    }
    
    //Fetch the child's name from Firestore and use it in alert messages:
    func fetchChildName() {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("guardians").document(guardianID).collection("children").document(viewModel.childID).getDocument { document, error in
            if let document = document, document.exists {
                if let name = document.data()?["name"] as? String {
                    self.childName = name
                }
            }
        }
    }
    
    // MARK: - Calculate frame for zone overlay
    private func calculateZoneFrame(zoneSize: Double) -> CGFloat {
        let metersPerPoint = cameraPosition.span.latitudeDelta * 111000
        let zoomFactor = CGFloat(metersPerPoint)
        return CGFloat(zoneSize * 2) / zoomFactor * 5000
    }
    
    // MARK: - Simulation function:
    private func submitSimulationCords() {
        self.hideKeyboard()
        
        guard let lat = Double(simulatedLatitude), let lon = Double(simulatedLongitude) else {
            print("Invalid coordinates entered.")
            self.simulatedAnnotation = nil
            return
        }
        
        let newLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        // This logic is now also triggered by the timer
        self.lastKnownChildLocation = self.currentChildLocation
        self.currentChildLocation = newLocation
        
        // Run the checks
        runZoneChecks(with: newLocation)
    }
    
    // This function contains the logic moved from submitSimulationCords
    private func runZoneChecks(with newLocation: CLLocationCoordinate2D) {
        let simulatedZone = Zone(coordinate: newLocation, zoneName: "Simulated Location", isSafeZone: true, zoneSize: 0)
        self.simulatedAnnotation = simulatedZone
        updateCameraPosition(to: simulatedZone.coordinate)
        print("Simulated location set at: \(newLocation.latitude), \(newLocation.longitude)")
        
        // Fetch child's notification settings before checking zones:
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Path to the child's specific notification settings document
        db.collection("guardians").document(guardianID)
            .collection("children").document(viewModel.childID)
            .collection("notifications").document("settings")
            .getDocument { document, error in
                
                // Use fetched settings, or default settings if none exist
                var settings = NotificationSettings() // Default: all alerts on
                
                if let document = document, document.exists, let data = document.data() {
                    settings.safeZoneAlert = data["safeZoneAlert"] as? Bool ?? true
                    settings.unsafeZoneAlert = data["unsafeZoneAlert"] as? Bool ?? true
                    settings.lowBatteryAlert = data["lowBatteryAlert"] as? Bool ?? true
                    settings.watchRemovedAlert = data["watchRemovedAlert"] as? Bool ?? true
                    settings.newConnectionRequest = data["newConnectionRequest"] as? Bool ?? true
                    settings.sound = data["sound"] as? String ?? "default_sound"
                    print("✅ Successfully fetched notification settings for child.")
                } else {
                    print("⚠️ Could not fetch settings. Using default settings.")
                }
                
                let updatedTimestamps = ZoneAlertManager.checkForDangerZones(
                    simulatedLocation: newLocation,
                    zones: self.viewModel.zones,
                    childName: self.childName,
                    cameraPosition: self.cameraPosition,
                    settings: settings,
                    timestamps: self.zoneAlertTimestamps
                )
                self.zoneAlertTimestamps = updatedTimestamps
                
                ZoneAlertManager.checkForSafeZoneExit(
                    lastLocation: self.lastKnownChildLocation,
                    currentLocation: newLocation,
                    zones: self.viewModel.zones,
                    childName: self.childName,
                    cameraPosition: self.cameraPosition,
                    settings: settings
                )
            }
    }
    
    // MARK: - Firestore Live Location Listener
    private func startLiveLocationListener() {
        // TO-DO #1: get current child's location coordinates from db (liveLocation).
        locationListener?.remove()
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let docRef = db.collection("guardians").document(guardianID)
                      .collection("children").document(viewModel.childID)
                      .collection("liveLocation").document("latest")

        locationListener = docRef.addSnapshotListener { doc, err in
            if let err = err {
                print("Error listening to live location: \(err.localizedDescription)")
                return
            }
            
            if let data = doc?.data(), let c = extractCoordinate(from: data) {
                // Check if it's different from the last location we *checked*
                if c.latitude != self.currentChildLocation?.latitude ||
                   c.longitude != self.currentChildLocation?.longitude {
                    
                    print("LiveListener: Detected location change, running checks...")
                    
                    // TO-DO #2: place these coordinates in the simulatedLatitude and simulatedLongitude variables
                    self.simulatedLatitude = String(c.latitude)
                    self.simulatedLongitude = String(c.longitude)
                    
                    // TO-DO #3: store the old one
                    self.lastKnownChildLocation = self.currentChildLocation
                    // TO-DO #3: update the current one
                    self.currentChildLocation = c
                    
                    // Run the full check logic
                    runZoneChecks(with: c)
                } else {
                    // Optional: print for debugging
                    // print("LiveListener: Location unchanged, skipping check.")
                }
            }
        }
    }
    
    // Helper function (from ChildLocationView) to parse coordinates
    private func extractCoordinate(from data: [String: Any]) -> CLLocationCoordinate2D? {
        if let coords = data["coordinate"] as? [Double], coords.count == 2 {
            return CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
        }
        if let lat = data["lat"] as? CLLocationDegrees,
           let lon = data["lon"] as? CLLocationDegrees {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let latStr = data["lat"] as? String,
           let lonStr = data["lon"] as? String,
           let lat = CLLocationDegrees(latStr),
           let lon = CLLocationDegrees(lonStr) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
}//end struct


// MARK: - LocationService struct:
struct ZoneAlertManager {
    
    // MARK: - Check for Danger Zones using calculateZoneFrame:
    static func checkForDangerZones(simulatedLocation: CLLocationCoordinate2D, zones: [Zone], childName: String, cameraPosition: MKCoordinateRegion, settings: NotificationSettings, timestamps: [String: Date]) -> [String: Date] {
        
        var updatedTimestamps = timestamps
        let simulatedCLLocation = CLLocation(latitude: simulatedLocation.latitude, longitude: simulatedLocation.longitude)
        let dangerZones = zones.filter { !$0.isSafeZone }
        var alertTriggeredInThisCheck = false

        for zone in dangerZones {
            let zoneCLLocation = CLLocation(latitude: zone.coordinate.latitude, longitude: zone.coordinate.longitude)
            let distanceInMeters = simulatedCLLocation.distance(from: zoneCLLocation)
            let scalingFactor: CGFloat = 11000.0
            let metersPerPoint = cameraPosition.span.latitudeDelta * 111000
            let zoomFactor = CGFloat(metersPerPoint)
            let visualRadius = CGFloat(zone.zoneSize) / zoomFactor * scalingFactor
            let isInsideZone = distanceInMeters <= Double(visualRadius)
            
            if isInsideZone && !alertTriggeredInThisCheck {
                let lastAlertTime = updatedTimestamps[zone.zoneName]
                let cooldown: TimeInterval = 120

                if let lastAlertTime = lastAlertTime {
                    if Date().timeIntervalSince(lastAlertTime) >= cooldown {
                        let alertTitle = "Alert! Child '\(childName)' is still in the danger zone: '\(zone.zoneName)'!"
                        let depthInMeters = Double(visualRadius) - distanceInMeters
                        let alertBody = "They have remained in the zone for over 2 minutes! They are approximately \(Int(depthInMeters)) meters deep inside the danger zone!"
                        
                        sendZoneAlert(title: alertTitle, body: alertBody, isSafeZoneRelated: false, settings: settings)
                        updatedTimestamps[zone.zoneName] = Date()
                        alertTriggeredInThisCheck = true
                    }
                } else {
                    let alertTitle = "Alert! Child '\(childName)' has entered the danger zone: '\(zone.zoneName)'!"
                    let depthInMeters = Double(visualRadius) - distanceInMeters
                    let alertBody = "Info: They are approximately \(Int(depthInMeters)) meters deep inside the danger zone!"

                    sendZoneAlert(title: alertTitle, body: alertBody, isSafeZoneRelated: false, settings: settings)
                    updatedTimestamps[zone.zoneName] = Date()
                    alertTriggeredInThisCheck = true
                }
            } else if !isInsideZone {
                updatedTimestamps[zone.zoneName] = nil
            }
        }
        return updatedTimestamps
    }
    
    // MARK: - Check for Safe Zone Exits using calculateZoneFrame:
    static func checkForSafeZoneExit(lastLocation: CLLocationCoordinate2D?, currentLocation: CLLocationCoordinate2D, zones: [Zone], childName: String, cameraPosition: MKCoordinateRegion, settings: NotificationSettings) {
        let safeZones = zones.filter { $0.isSafeZone }
        
        for zone in safeZones {
            let isLocationInside = { (location: CLLocationCoordinate2D?) -> Bool in
                guard let location = location else { return false }
                let pointLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let zoneCenterLocation = CLLocation(latitude: zone.coordinate.latitude, longitude: zone.coordinate.longitude)
                let distanceInMeters = pointLocation.distance(from: zoneCenterLocation)
                let scalingFactor: CGFloat = 11000.0
                let metersPerPoint = cameraPosition.span.latitudeDelta * 111000
                let zoomFactor = CGFloat(metersPerPoint)
                let visualRadius = CGFloat(zone.zoneSize) / zoomFactor * scalingFactor
                return distanceInMeters <= Double(visualRadius)
            }
            
            let wasInside = isLocationInside(lastLocation)
            let isNowOutside = !isLocationInside(currentLocation)
            
            if wasInside && isNowOutside {
                let alertTitle = "Alert! Child '\(childName)' has exited the safe zone: '\(zone.zoneName)'!"
                let pointLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                let zoneCenterLocation = CLLocation(latitude: zone.coordinate.latitude, longitude: zone.coordinate.longitude)
                let distanceInMeters = pointLocation.distance(from: zoneCenterLocation)
                let distanceOutside = distanceInMeters - zone.zoneSize
                var alertBody = ""
                if distanceOutside > 0 {
                    alertBody = "Info: They are now approx. \(Int(distanceOutside)) meters outside the zone's border!"
                }
                
                sendZoneAlert(title: alertTitle, body: alertBody, isSafeZoneRelated: true, settings: settings)
                break
            }
        }
    }
    
    //MARK: - function to send an alert to guardian's notification collection in firebase:
    static func sendZoneAlert(title: String, body: String, isSafeZoneRelated: Bool, settings: NotificationSettings) {
        
        if isSafeZoneRelated {
            guard settings.safeZoneAlert else {
                print("🚫 Safe zone alert is disabled for this child. Notification not sent.")
                return
            }
        } else {
            guard settings.unsafeZoneAlert else {
                print("🚫 Unsafe zone alert is disabled for this child. Notification not sent.")
                return
            }
        }
        
        NotificationManager.instance.scheduleNotification(
            title: title,
            body: body,
            soundName: "\(settings.sound).wav"
        )
        
        guard let guardianID = Auth.auth().currentUser?.uid else {
            print("Error: Guardian not signed in. Cannot send notification.")
            return
        }
        
        let db = Firestore.firestore()
        let notificationRef = db.collection("guardians").document(guardianID).collection("notifications")
        
        let notificationData: [String: Any] = [
            "title": title,
            "body": body,
            "timestamp": Timestamp(date: Date()),
            "isSafeZone": isSafeZoneRelated
        ]
        
        notificationRef.addDocument(data: notificationData) { error in
            if let error = error {
                print("Error adding notification to Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully saved notification to Firestore.")
            }
        }
    }
}//end struct

// MARK: - Zone Struct Extension:
extension Zone {
    var isSimulated: Bool {
        zoneName == "Simulated Location"
    }
}

// MARK: - Preview
struct ZoneAlertSimulation_Previews: PreviewProvider {
    static var previews: some View {
        ZoneAlertSimulation(childID: "sampleChildID")
    }
}
