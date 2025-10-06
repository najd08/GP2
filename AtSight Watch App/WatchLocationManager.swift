//
//  WatchLocationManager.swift
//  AtSight (watchOS target)
//
//  Created by Leena on 07/09/2025.
//

import Foundation
import CoreLocation
import WatchConnectivity

final class WatchLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = WatchLocationManager()
    
    private let manager = CLLocationManager()
    private var onceHandler: ((CLLocation?) -> Void)?
    private var timer: Timer?
    
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
                
                let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? ""
                var payload: [String: Any] = [
                    "type": "watch_location",
                    "lat": loc.coordinate.latitude,
                    "lon": loc.coordinate.longitude,
                    "acc": loc.horizontalAccuracy,
                    "ts": loc.timestamp.timeIntervalSince1970
                ]
                if !childId.isEmpty {
                    payload["childId"] = childId
                }
                self?.sendLocationPayload(payload)
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
    
    // MARK: - Send helper
    private func sendLocationPayload(_ payload: [String: Any]) {
        let s = WCSession.default
        if s.activationState == .activated, s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { err in
                print("⚠️ [WLM] sendMessage error:", err.localizedDescription, "→ fallback to transferUserInfo")
                s.transferUserInfo(payload)
            }
        } else {
            s.transferUserInfo(payload)
        }
        print("📤 [WLM] sent live location:", payload)
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
            print("📍 [WLM] got location: \(loc.coordinate.latitude),\(loc.coordinate.longitude) ±\(loc.horizontalAccuracy)m")
            completeOnce(loc)
            manager.stopUpdatingLocation()
        } else {
            print("⚠️ [WLM] didUpdateLocations empty")
            scheduleRetry("empty locations")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsErr = error as NSError
        print("❌ [WLM] location error:", nsErr.localizedDescription, "(code=\(nsErr.code))")
        scheduleRetry("error code \(nsErr.code)")
    }
}
