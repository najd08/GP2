//
//  WatchLocationManager.swift
//  AtSight (watchOS target)
//
//  Created by Leena on 07/09/2025.
//  Updated on 22/10/2025: sends streetName + zoneName with coordinate array
//  EDIT BY RIYAM:
//  - Updated sendLocationToAPI to iterate through PairingState.shared.linkedGuardianIDs.
//  - Sends Location to ALL linked guardians.
//  - Added specific handling for kCLErrorDomain error 0 (Location Unknown) to retry gracefully.
//  - FIXED MainActor isolation error by wrapping PairingState access in Task { @MainActor }.
//

import Foundation
import CoreLocation

final class WatchLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = WatchLocationManager()
    
    private let manager = CLLocationManager()
    private var onceHandler: ((CLLocation?) -> Void)?
    private var timer: Timer?
    private let geocoder = CLGeocoder()
    
    // Retry state
    private var retryCount = 0
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 10
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }
    
    // MARK: - One-shot location (with retry)
    func requestOnce(_ handler: @escaping (CLLocation?) -> Void) {
        onceHandler = handler
        retryCount = 0
        evaluateAuthAndRequest()
    }
    
    private func evaluateAuthAndRequest() {
        switch manager.authorizationStatus {
        case .notDetermined:
            print("ℹ️ [WLM] requesting location auth (.always)")
            manager.requestAlwaysAuthorization()
        case .restricted, .denied:
            print("❌ [WLM] location permission denied/restricted")
            completeOnce(nil)
        default:
            print("✅ [WLM] authorized → startUpdatingLocation()")
            manager.startUpdatingLocation()
        }
    }
    
    private func scheduleRetry(_ reason: String) {
        guard retryCount < maxRetries else {
            print("🛑 [WLM] giving up after \(retryCount) retries (\(reason))")
            completeOnce(nil)
            return
        }
        let delay = baseRetryDelay * pow(2.0, Double(retryCount))
        retryCount += 1
        print("⏳ [WLM] retry #\(retryCount) in \(Int(delay))s (\(reason))")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.manager.startUpdatingLocation()
        }
    }
    
    private func completeOnce(_ loc: CLLocation?) {
        let h = onceHandler
        onceHandler = nil
        retryCount = 0
        h?(loc)
    }
    
    // MARK: - Live updates (every 5 min)
    func startLiveUpdates(interval: TimeInterval = 300) {
        stopLiveUpdates()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.requestOnce { loc in
                guard let loc = loc else {
                    print("⚠️ [WLM] no location in live tick")
                    return
                }
                self?.sendLocationToAPI(loc)
            }
        }
        
        timer?.fire() // fire immediately
        print("🚀 [WLM] startLiveUpdates(interval=\(Int(interval))s)")
    }
    
    func stopLiveUpdates() {
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
        print("🛑 [WLM] stopLiveUpdates()")
    }
    
    // MARK: - Send location via API
    private func sendLocationToAPI(_ loc: CLLocation) {
        // EDIT BY RIYAM: Task { @MainActor } fixes the concurrency error
        Task { @MainActor in
            // EDIT BY RIYAM: Get all linked guardians
            let guardians = PairingState.shared.linkedGuardianIDs
            
            if guardians.isEmpty {
                print("⚠️ [WLM] No linked guardians found. Cannot send location.")
                return
            }
            
            // 🔹 نجيب اسم الشارع باستخدام CLGeocoder
            self.geocoder.reverseGeocodeLocation(loc) { placemarks, error in
                var streetName = "Unknown"
                if let placemark = placemarks?.first {
                    streetName = placemark.thoroughfare ?? placemark.name ?? "Unknown"
                }
                
                // EDIT BY RIYAM: Loop through all guardians
                // NOTE: We are inside the geocoder closure, but we captured 'guardians' from the MainActor block above.
                // However, to be safe when accessing PairingState again (for childID), we should be careful.
                // Since we need guardianChildIDs map, we should grab it upfront or inside another MainActor task.
                
                // Safe approach: Grab IDs before the closure or re-enter MainActor
                Task { @MainActor in
                    let childMap = PairingState.shared.guardianChildIDs
                    
                    for guardianId in guardians {
                        let childId = childMap[guardianId] ?? "unknown"
                        
                        let payload: [String: Any] = [
                            "guardianId": guardianId,
                            "childId": childId,
                            "coordinate": [loc.coordinate.latitude, loc.coordinate.longitude],
                            "isSafeZone": true,
                            "timestamp": loc.timestamp.timeIntervalSince1970,
                            "zoneName": "Initial",
                            "streetName": streetName
                        ]
                        
                        APIHelper.shared.post(to: API.uploadLocation, body: payload)
                        print("📤 [WLM] Sent live location to guardian \(guardianId):", payload)
                    }
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ [WLM] authorization granted")
            if onceHandler != nil {
                manager.startUpdatingLocation()
            }
        case .denied, .restricted:
            print("❌ [WLM] denied/restricted")
            completeOnce(nil)
        case .notDetermined:
            print("ℹ️ [WLM] notDetermined")
        @unknown default:
            print("⚠️ [WLM] unknown auth status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            print("📍 [WLM] got location: \(loc.coordinate.latitude), \(loc.coordinate.longitude) ±\(loc.horizontalAccuracy)m")
            completeOnce(loc)
            manager.stopUpdatingLocation()
        } else {
            print("⚠️ [WLM] didUpdateLocations empty")
            scheduleRetry("empty locations")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsErr = error as NSError
        
        // EDIT BY RIYAM: Specific handling for kCLErrorDomain error 0
        if nsErr.domain == kCLErrorDomain && nsErr.code == 0 {
            print("⚠️ [WLM] Location Unknown (temporary error). Retrying...")
            scheduleRetry("Location Unknown (Error 0)")
        } else {
            print("❌ [WLM] location error:", nsErr.localizedDescription, "(code=\(nsErr.code))")
            scheduleRetry("error code \(nsErr.code)")
        }
    }
}
