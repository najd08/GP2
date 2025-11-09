// Edit by Riyam: updated the back button to fit Dark Mode (line 266). ✅
// updated the mappin icon color from blue to black for consistency (line 301). ✅
// Added filter by time (last 24 hours, 7 days, 30 days) ✅

import SwiftUI
import MapKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct LocationHistoryView: View {
    var childID: String
    @State private var locations: [Location] = []
    @State private var selectedLocation: Location?
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = true

    // MARK: - Filter State
    @State private var selectedFilter: TimeFilterOption = .today // Default is 24 Hours
    
    // MARK: - Filter Options Enum
    enum TimeFilterOption: String, CaseIterable {
        case today = "last 24 Hours"
        case week = "last 7 Days"
        case month = "last 30 Days"
    }

    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("BlackFont"))
                        .font(.system(size: 20, weight: .bold))
                }

                Spacer()

                Text("Location History")
                    .font(.title2)
                    .bold()

                Spacer()
            }
            .padding()

            Text("Recent Places")
                .foregroundColor(Color(red: 90/255, green: 90/255, blue: 90/255))
                .bold()
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.top, 40)
                .padding(.bottom, 10)

            // MARK: - Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(TimeFilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 10)
            .onChange(of: selectedFilter) { _ in
                // Re-fetch data when the filter changes
                fetchLocations()
            }

            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        // The 'locations' array is now always filtered
                        ForEach(locations) { location in
                            NavigationLink(
                                destination: MapView(
                                    latitude: location.latitude,
                                    longitude: location.longitude,
                                    locationName: location.name
                                )
                            ) {
                                LocationRow(location: location)
                            }
                        }
                        .padding(.top, 5)

                        // Updated empty state message
                        if locations.isEmpty {
                            Text("No location history found for this filter.")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding(.horizontal, 15)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            fetchLocations()
        }
    }

    // MARK: - Fetch (MODIFIED)
    func fetchLocations() {
        let guardianID = Auth.auth().currentUser?.uid
            ?? UserDefaults.standard.string(forKey: "guardianID")
            ?? ""
        let childID = self.childID

        print("🟡 Fetching locations for guardian=\(guardianID) child=\(childID)")

        guard !guardianID.isEmpty, !childID.isEmpty else {
            print("❌ Missing guardianID or childID")
            isLoading = false
            return
        }

        isLoading = true
        let db = Firestore.firestore()
        
        // --- START OF FILTER LOGIC ---
        // 1. Calculate the start date for the filter
        let now = Date()
        let calendar = Calendar.current
        let startDate: Date
        
        switch selectedFilter {
        case .today:
            startDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        }
        // --- END OF FILTER LOGIC ---
        
        
        // 2. Build the query WITH the filter
        db.collection("guardians")
            .document(guardianID)
            .collection("children")
            .document(childID)
            .collection("locationHistory")
            // This line applies the filter in Firestore
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .order(by: "timestamp", descending: true)
            // Note: Limit is applied *after* the filter
            .limit(to: 30)
            .getDocuments { snapshot, error in
                isLoading = false
                if let error = error {
                    print("❌ Firestore error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents found.")
                    self.locations = [] // Clear list if no docs
                    return
                }

                print("📦 Retrieved \(documents.count) locations")

                self.locations = documents.compactMap { doc in
                    let data = doc.data()

                    // Coordinates as [lat, lon]
                    guard let coord = data["coordinate"] as? [Double], coord.count == 2 else {
                        print("⚠️ Skipped: Missing or malformed coordinates for \(doc.documentID)")
                        return nil
                    }
                    let lat = coord[0]
                    let lng = coord[1]

                    // ✅ Title fallback: streetName → zoneName → placeName → "Unknown"
                    let street   = (data["streetName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let zone     = (data["zoneName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let place    = (data["placeName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let title    = [street, zone, place].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? "Unknown"

                    // Optional extras (most docs ما فيها address/distance)
                    let address  = (data["address"] as? String) ?? (street ?? "—")
                    let distance = (data["distance"] as? String) ?? "—"
                    let isSafe   = (data["isSafeZone"] as? Bool) ?? true

                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let df = DateFormatter()
                    df.dateFormat = "yyyy/MM/dd"
                    let dateStr = df.string(from: ts)
                    df.dateFormat = "h:mm a"
                    let timeStr = df.string(from: ts)

                    return Location(
                        name: title,
                        address: address,
                        date: dateStr,
                        time: timeStr,
                        distance: distance,
                        latitude: lat,
                        longitude: lng,
                        isSafeZone: isSafe
                    )
                }
            }
    }
}

// MARK: - Location Model
struct Location: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let date: String
    let time: String
    let distance: String
    let latitude: Double
    let longitude: Double
    let isSafeZone: Bool
}

// MARK: - Map View
struct MapView: View {
    var latitude: Double
    var longitude: Double
    var locationName: String
    @Environment(\.presentationMode) var presentationMode

    @State private var region: MKCoordinateRegion

    init(latitude: Double, longitude: Double, locationName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName

        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    private func zoomIn() {
        region.span.latitudeDelta /= 2
        region.span.longitudeDelta /= 2
    }

    private func zoomOut() {
        region.span.latitudeDelta *= 2
        region.span.longitudeDelta *= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("BlackFont"))
                        .font(.system(size: 20, weight: .bold))
                        .padding(8)
                }.padding(.leading, -10)
                Spacer()

                Text(locationName)
                    .font(.title).bold()
                    .foregroundColor(Color("Blue"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.leading, -15)

                Spacer()
            }
            .padding()
            .cornerRadius(25)
            .padding(.horizontal)

            Divider().padding(.horizontal)

            // --- Map View ---
            ZStack {
                Map(coordinateRegion: $region, annotationItems: [
                    LocationMarker(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                ]) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.4))
                                .frame(width: 42, height: 42)

                            Image(systemName: "mappin")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.black) //changed from blue to black (by Riyam)
                        }
                    }
                }
                .frame(height: 650)
                .cornerRadius(30)
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: zoomIn) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title2)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }

                    Button(action: zoomOut) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 20)
                .padding(.top, 20)
            }
            .padding(.bottom, -30)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Location Marker
struct LocationMarker: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}

// MARK: - Location Row
struct LocationRow: View {
    let location: Location

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: location.isSafeZone ? "checkmark.shield" : "exclamationmark.triangle")
                .foregroundColor(location.isSafeZone ? .green : .red)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .foregroundColor(location.isSafeZone ? .green : .red)

                Text("\(location.date) \(location.time)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color("navBG"))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
    }
}

struct previews: PreviewProvider {
    static var previews: some View {
        LocationHistoryView(childID: "sample-child-id")
            .environmentObject(AppState())
    }
}
