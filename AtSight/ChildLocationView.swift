//  MARK: This Page Shows the curent child's last 3 location history entries
//
//Edits by Riyam:
// ⚠️ there is a bug in displaying the locationDetails sheet, the sheet is empty the first time you click on any location item. however, if you click on another sheet, then the issue will be fixed. ⚠️
//changed the title from "\(child.name)'s Live Location" to "Last Location". ✅
//modified time format. ✅
//added zones to the map view. ✅

import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth
import UIKit

// ✅ 1. Create a Unified Model to hold either a Child Pin or a Zone
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    
    enum AnnotationType {
        case child(String?) // Holds imageName
        case zone(Zone)     // Holds the Zone object
    }
}

struct ChildLocationView: View {
    var child: Child

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 23.8859, longitude: 45.0792),
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )
    @State private var isMapExpanded = false
    @Environment(\.presentationMode) var presentationMode
    
    @State private var latestCoordinate: CLLocationCoordinate2D? = nil
    @State private var recentLocations: [[String: Any]] = []
    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var selectedLocationName: String? = nil
    @State private var showLocationDetail = false
    
    // ✅ 2. State to hold fetched zones
    @State private var zones: [Zone] = []

    // 🔁 Firestore listener tokens
    @State private var latestListener: ListenerRegistration?
    @State private var latestDocListener: ListenerRegistration?

    private func zoomIn() {
        region.span.latitudeDelta /= 2
        region.span.longitudeDelta /= 2
    }
    private func zoomOut() {
        region.span.latitudeDelta *= 2
        region.span.longitudeDelta *= 2
    }
    
    // ✅ 3. Computed Property to combine Child Location + Zones
    private var mapAnnotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        
        // Add Zones first (so they appear behind the child if overlapping)
        for zone in zones {
            items.append(MapAnnotationItem(coordinate: zone.coordinate, type: .zone(zone)))
        }
        
        // Add Child Location
        if let latestCoordinate = latestCoordinate {
            items.append(MapAnnotationItem(coordinate: latestCoordinate, type: .child(child.imageName)))
        }
        
        return items
    }
    
    // ✅ Helper to get current map height
    private var currentMapHeight: CGFloat {
        isMapExpanded ? 600 : 350
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("BlackFont"))
                        .font(.system(size: 20, weight: .bold))
                        .padding(8)
                }.padding(.leading, -10)
                
                Spacer()

                Text("\(child.name)'s Last Location")
                    .font(.title).bold()
                    .foregroundColor(Color("Blue"))
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding()
            .cornerRadius(25)
            .padding(.horizontal)

            Divider().padding(.horizontal)

            ScrollView {
                // Map with pin AND Zones
                ZStack {
                    if latestCoordinate != nil { // Check if we have location data
                        Map(
                            coordinateRegion: $region,
                            annotationItems: mapAnnotations // ✅ Use combined items
                        ) { item in
                            MapAnnotation(coordinate: item.coordinate) {
                                switch item.type {
                                case .child(let imageName):
                                    // --- RENDER CHILD PIN ---
                                    if hasAsset(named: imageName) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.5))
                                                .frame(width: 42, height: 42)
                                            Image(imageName!)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 37, height: 37)
                                                .clipShape(Circle())
                                        }
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color.green.opacity(0.4))
                                                .frame(width: 42, height: 42)
                                                .shadow(radius: 3)
                                            Image(systemName: "mappin")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundColor(Color("CustomBlue"))
                                                .frame(width: 30, height: 30)
                                        }
                                    }
                                    
                                case .zone(let zone):
                                    // --- RENDER ZONE ---
                                    // Reuse ZoneAnnotationView (assumed available globally)
                                    // ✅ Pass currentMapHeight to calculate correct size relative to view
                                    ZoneAnnotationView(zone: zone, isTemp: false)
                                        .frame(
                                            width: calculateZoneFrame(zoneSize: zone.zoneSize, mapHeight: currentMapHeight),
                                            height: calculateZoneFrame(zoneSize: zone.zoneSize, mapHeight: currentMapHeight)
                                        )
                                }
                            }
                        }
                        .frame(height: currentMapHeight) // ✅ Use consistent height variable
                        .cornerRadius(30)
                        .padding(.horizontal)
                        .animation(.spring(), value: isMapExpanded)
                        .onTapGesture { isMapExpanded.toggle() }
                    } else {
                        Text("Loading map...")
                            .frame(height: 350)
                    }
                }
                .padding(.bottom, isMapExpanded ? 0 : -40)
                .onAppear {
                    startLatestLocationListener()
                    fetchRecentLocationHistory()
                    fetchZones() // ✅ Fetch zones on load
                }

                // Zoom buttons
                HStack(spacing: 20) {
                    Button(action: zoomOut) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                            .padding(10)
                            .background(Color("TextFieldBg"))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    Button(action: zoomIn) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title2)
                            .padding(10)
                            .background(Color("TextFieldBg"))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                .padding(.top, -20)

                // HALT button
                HaltButtonView(child: child)

                // Last 3 locations
                if !recentLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Last 3 Locations:")
                            .font(.title3).bold()
                            .padding(.leading)

                        ForEach(Array(recentLocations.prefix(3).enumerated()), id: \.offset) { _, location in
                            let coords = location["coordinate"] as? [Double] ?? []
                            let title = displayName(from: location)

                            TimelineItem(
                                icon: location["isSafeZone"] as? Bool == true ? "checkmark.shield" : "exclamationmark.triangle",
                                color: location["isSafeZone"] as? Bool == true ? .green : .red,
                                title: title,
                                time: formattedDate(location["timestamp"]),
                                isSafeZone: location["isSafeZone"] as? Bool
                            )
                            .onTapGesture {
                                if coords.count == 2 {
                                    selectedLocation = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
                                    selectedLocationName = title
                                    showLocationDetail = true
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 10)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                            .font(.footnote)
                            .padding(.bottom, 20)
                        Text("To view all location history, go to the Location History tab.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                }

                Spacer()
            }
            .background(Color("BgColor").edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
        .onDisappear {
            latestListener?.remove()
            latestListener = nil
            latestDocListener?.remove()
            latestDocListener = nil
        }
        .sheet(isPresented: $showLocationDetail) {
            if let coord = selectedLocation, let name = selectedLocationName {
                LocationDetailView(coordinate: coord, locationName: name)
            }
        }
    }
    
    // MARK: - ✅ Zone Fetching Functions
    func fetchZones() {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let childRef = db.collection("guardians").document(guardianID).collection("children").document(child.id)
        
        let group = DispatchGroup()
        var fetchedZones: [Zone] = []
        
        for collection in ["safeZone", "unSafeZone"] {
            group.enter()
            childRef.collection(collection).getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for doc in documents {
                        let data = doc.data()
                        if let geo = data["coordinate"] as? GeoPoint,
                           let name = data["zoneName"] as? String,
                           let isSafe = data["isSafeZone"] as? Bool,
                           let size = data["zoneSize"] as? Double {
                            let zone = Zone(
                                coordinate: CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude),
                                zoneName: name,
                                isSafeZone: isSafe,
                                zoneSize: size
                            )
                            fetchedZones.append(zone)
                        }
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.zones = fetchedZones
        }
    }
    
    // ✅ Calculate circle size adjusted for the current map frame height
    private func calculateZoneFrame(zoneSize: Double, mapHeight: CGFloat) -> CGFloat {
        let metersPerPoint = region.span.latitudeDelta * 111000
        guard metersPerPoint > 0 else { return 0 }
        
        // Original constant (5000) was tuned for a full screen map (~850pts)
        // We scale it based on the current map height to maintain visual proportion
        let referenceScreenHeight: CGFloat = UIScreen.main.bounds.height
        let adjustedConstant = 5000 * (mapHeight / referenceScreenHeight)
        
        let zoomFactor = CGFloat(metersPerPoint)
        return CGFloat(zoneSize * 2) / zoomFactor * adjustedConstant
    }

    // MARK: - Latest location (Firestore listener)
    private func startLatestLocationListener() {
        latestListener?.remove()
        latestDocListener?.remove()
        guard let guardianID = Auth.auth().currentUser?.uid else { return }

        let base = Firestore.firestore()
            .collection("guardians").document(guardianID)
            .collection("children").document(child.id)
            .collection("liveLocation")

        // 1) Prefer a stable doc: liveLocation/latest
        latestDocListener = base.document("latest").addSnapshotListener { doc, err in
            if let err = err {
                print("❌ Error listening latest doc: \(err.localizedDescription)")
                return
            }
            if let data = doc?.data(), let c = extractCoordinate(from: data) {
                apply(coord: c)
                return
            }
            // If latest doc missing/invalid, fall back to a query
            startQueryFallback(on: base)
        }
    }

    // 2) Fallback to a query if there is no `latest` document
    private func startQueryFallback(on base: CollectionReference) {
        latestListener?.remove()

        // Try `timestamp` first, then try `ts` if needed
        latestListener = base
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snap, err in
                if let err = err {
                    print("ℹ️ Fallback(timestamp) error: \(err.localizedDescription). Trying ts…")
                    // Try ts
                    self.latestListener = base
                        .order(by: "ts", descending: true)
                        .limit(to: 1)
                        .addSnapshotListener { snap2, err2 in
                            if let err2 = err2 {
                                print("❌ Fallback(ts) failed: \(err2.localizedDescription)")
                                return
                            }
                            guard let doc = snap2?.documents.first else { return }
                            if let c = extractCoordinate(from: doc.data()) { apply(coord: c) }
                        }
                    return
                }
                guard let doc = snap?.documents.first else {
                    print("ℹ️ No liveLocation docs yet.")
                    return
                }
                if let c = extractCoordinate(from: doc.data()) { apply(coord: c) }
            }
    }

    // MARK: - Helpers (parsing & apply)
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

    private func apply(coord: CLLocationCoordinate2D) {
        latestCoordinate = coord
        region.center = coord
        region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    }

    // MARK: - Recent history (top 3)
    private func fetchRecentLocationHistory() {
        guard let guardianID = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("guardians").document(guardianID)
            .collection("children").document(child.id)
            .collection("locationHistory")
            .order(by: "timestamp", descending: true)
            .limit(to: 3)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching history: \(error.localizedDescription)")
                    return
                }
                self.recentLocations = snapshot?.documents.map { $0.data() } ?? []
            }
    }

    // MARK: - Formatters & small helpers
    private func formattedDate(_ timestamp: Any?) -> String {
        if let ts = timestamp as? Timestamp {
            let date = ts.dateValue()
            let formatter = DateFormatter()
            // ✅ 12-hour format with AM/PM
            formatter.dateFormat = "dd MMM yyyy, h:mm a"
            return formatter.string(from: date)
        }
        return "Unknown Time"
    }

    private func hasAsset(named name: String?) -> Bool {
        guard let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return false }
        return UIImage(named: n) != nil
    }

    private func displayName(from data: [String: Any]) -> String {
        let street = (data["streetName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let zone   = (data["zoneName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let place  = (data["placeName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [street, zone, place].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? "Unknown"
    }
}

// MARK: - Halt button
struct HaltButtonView: View {
    var child: Child
    @State private var showHaltPopup = false
    @State private var isSendingHalt = false
    @State private var haltAlertMessage: String?
    @State private var haltAlertTitle: String = ""

    var body: some View {
        VStack {
            Button(action: { showHaltPopup = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("HALT")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.98, green: 0.28, blue: 0.26),
                                Color(red: 0.82, green: 0.00, blue: 0.00)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: Color.red.opacity(0.28), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)
        }
        .sheet(isPresented: $showHaltPopup) {
            HaltConfirmSheet(
                isShowing: $showHaltPopup,
                isSending: $isSendingHalt,
                onSend: {
                    isSendingHalt = true
                    HaltManager.shared.sendHaltSignal(childId: child.id, childName: child.name) { success, message in
                        isSendingHalt = false
                        showHaltPopup = false
                        haltAlertTitle = success ? "HALT Signal Sent" : "Error"
                        haltAlertMessage = message
                    }
                }
            )
            .presentationDetents([.height(250)])
            .presentationCornerRadius(20)
        }
        .alert(haltAlertTitle, isPresented: .constant(haltAlertMessage != nil), actions: {
            Button("OK") {
                haltAlertMessage = nil
            }
        }, message: {
            Text(haltAlertMessage ?? "")
        })
    }
}

// MARK: - Confirm Sheet
struct HaltConfirmSheet: View {
    @Binding var isShowing: Bool
    @Binding var isSending: Bool
    var onSend: () -> Void

    var body: some View {
        ZStack {
            Color("BgColor").ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Confirm HALT?")
                    .font(.title2).bold()
                    .foregroundColor(Color("BlackFont"))
                    .padding(.top, 30)

                Text("This will send an urgent alert about your child.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    if !isSending {
                        onSend()
                    }
                }) {
                    ZStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send HALT")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isSending)

                Button("Cancel") {
                    if !isSending {
                        isShowing = false
                    }
                }
                .padding(.bottom, 20)
                .disabled(isSending)
            }
            .padding()
        }
    }
}

// MARK: - Timeline item
struct TimelineItem: View {
    var icon: String
    var color: Color
    var title: String
    var time: String
    var isSafeZone: Bool?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .padding(8)
                .background(color.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(time).font(.caption).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
