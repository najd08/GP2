//
//  ChildLocationView.swift
//  AtSight
//
//  Shows live location + last 3 history entries
//
//Edit by Riyam: updated the back button to fit Dark Mode. ✅
// ⚠️ there is a bug in displaying the locationDetails sheet, the sheet is empty the first time you click on any location item. however, if you click on another sheet, then the issue will be fixed. ⚠️
// accidantly modified the halt button sheet while trying to fix the bug (it looks nicer like this now so I will not change it lol). ❗️
//we should include the zones in the map.

import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth
import UIKit

struct LocationPin: Identifiable {
    var id = UUID()
    var coordinate: CLLocationCoordinate2D
    var imageName: String?
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

                Text("\(child.name)'s Live Location")
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
                // Map with pin
                ZStack {
                    if let latestCoordinate = latestCoordinate {
                        Map(
                            coordinateRegion: $region,
                            annotationItems: [LocationPin(coordinate: latestCoordinate, imageName: child.imageName)]
                        ) { pin in
                            MapAnnotation(coordinate: pin.coordinate) {
                                if hasAsset(named: pin.imageName) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.4))
                                            .frame(width: 42, height: 42)
                                        Image(pin.imageName!)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 37, height: 37)
                                            .clipShape(Circle())
                                    }
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 42, height: 42)
                                            .shadow(radius: 3)
                                        Image(systemName: "mappin")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(Color("CustomBlue"))
                                            .frame(width: 30, height: 30)
                                    }
                                }
                            }
                        }
                        .frame(height: isMapExpanded ? 600 : 350)
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
                }

                // Zoom buttons
                HStack(spacing: 20) {
                    Button(action: zoomOut) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    Button(action: zoomIn) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title2)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                .padding(.top, -20)

                // HALT button
                HaltButtonView()

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

    // ... (All helper functions remain the same) ...
    // MARK: - Live latest location (Firestore listener)
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
            formatter.dateFormat = "dd MMM yyyy, HH:mm"
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
    @State private var showHaltPopup = false

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
        // MARK: FIX: Present the HaltConfirmSheet as a modal .sheet
        .sheet(isPresented: $showHaltPopup) {
            HaltConfirmSheet(
                isShowing: $showHaltPopup, // Pass the binding
                onSend: {
                    showHaltPopup = false
                    print("HALT triggered")
                }
            )
            // MARK: FIX: Make it look like a popup by setting its height
            .presentationDetents([.height(250)])
            .presentationCornerRadius(20) // Optional: make it look nicer
        }
    }
}

// MARK: - Confirm Sheet (like your SOSConfirmSheet)
struct HaltConfirmSheet: View {
    @Binding var isShowing: Bool
    var onSend: () -> Void

    var body: some View {
        // MARK: FIX: Wrap in a VStack to give it a proper background
        ZStack {
            Color("BgColor").ignoresSafeArea() // Use your app's background color
            
            VStack(spacing: 20) {
                Text("Confirm HALT?")
                    .font(.title2).bold()
                    .foregroundColor(Color("BlackFont")) // Use your app's font color
                    .padding(.top, 30)

                Text("This will send an urgent alert about your child.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    onSend()
                }) {
                    Text("Send HALT")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(12)
                }

                Button("Cancel") {
                    isShowing = false
                }
                .padding(.bottom, 20)
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
