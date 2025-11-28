//
//  LocationDetailView.swift
//  Atsight
//
//  Created by lona on 23/04/2025.
//

import SwiftUI
import MapKit

struct LocationDetailView: View {
    var coordinate: CLLocationCoordinate2D
    var locationName: String

    var body: some View {
        VStack(spacing: 0) {
            Text(locationName)
                .font(.title2).bold()
                .padding()

            Map(
                coordinateRegion: .constant(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                ),
                annotationItems: [IdentifiableCoordinate(coordinate: coordinate)]
            ) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                        .shadow(radius: 4)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}
