//
//  HeartRateMonitor.swift
//  AtSight Watch App
//
//  Created by Leena on 22/10/2025.
//  Updated: Added guardianId + field alignment with API
//

import Foundation
import HealthKit

final class HeartRateMonitor: NSObject {
    static let shared = HeartRateMonitor()
    private let healthStore = HKHealthStore()
    private var query: HKObserverQuery?
    private var lastBPM: Double = 0
    private var timer: Timer?
    private var lastUpdateTime: TimeInterval = 0
    private var lastAlertTime: TimeInterval = 0

    private override init() {}

    // MARK: - Start Monitoring
    func startMonitoring(for childName: String) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❤️ Health data not available on this device")
            return
        }

        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: nil, read: [type]) { success, error in
            if success {
                DispatchQueue.main.async {
                    self.startQuery(type: type, childName: childName)
                }
            } else {
                print("❌ HeartRate authorization failed:", error?.localizedDescription ?? "unknown")
            }
        }
    }

    // MARK: - Stop Monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if let q = query { healthStore.stop(q) }
        print("🛑 HeartRateMonitor stopped")
    }

    // MARK: - Query setup
    private func startQuery(type: HKQuantityType, childName: String) {
        query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ HeartRate observer error:", error.localizedDescription)
                return
            }
            self.fetchLatestHeartRate(for: type, childName: childName)
            completion()
        }
        if let q = query { healthStore.execute(q) }

        // Timer → if no updates for 2 min, assume watch removed
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date().timeIntervalSince1970

            if UserDefaults.standard.bool(forKey: "stopHeartRateMonitoring") {
                print("🧩 [HRM] Parent acknowledged, skipping alerts")
                return
            }

            if now - self.lastUpdateTime > 120 {
                self.notifyWatchRemoved(childName: childName)
            }
        }

        print("❤️ HeartRateMonitor started for \(childName)")
    }

    // MARK: - Fetch latest sample
    private func fetchLatestHeartRate(for type: HKQuantityType, childName: String) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let hrSample = samples?.first as? HKQuantitySample {
                let bpm = hrSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                self.lastBPM = bpm
                self.lastUpdateTime = Date().timeIntervalSince1970
                print("❤️ Current BPM: \(bpm)")

                self.sendHeartRateToAPI(bpm: bpm, childName: childName)

                if bpm < 20 {
                    let now = Date().timeIntervalSince1970
                    if now - self.lastAlertTime > 120 {
                        self.lastAlertTime = now
                        self.notifyWatchRemoved(childName: childName)
                    }
                } else {
                    UserDefaults.standard.set(false, forKey: "stopHeartRateMonitoring")
                    print("✅ Watch worn again — monitoring resumed")
                }
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Send to API
    private func sendHeartRateToAPI(bpm: Double, childName: String) {
        let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? "unknown"
        let guardianId = UserDefaults.standard.string(forKey: "guardianId") ?? "unknown"

        let payload: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "childName": childName,
            "bpm": bpm,
            "ts": Date().timeIntervalSince1970
        ]

        APIHelper.shared.post(to: API.uploadHeartRate, body: payload)
        print("📤 [HRM] Sent heart rate via API:", payload)
    }

    // MARK: - Watch removed notifier (API)
    private func notifyWatchRemoved(childName: String) {
        if UserDefaults.standard.bool(forKey: "stopHeartRateMonitoring") {
            print("🚫 [HRM] Parent acknowledged, not sending duplicate alert")
            return
        }

        let guardianId = UserDefaults.standard.string(forKey: "currentGuardianId") ?? "unknown"
        let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? "unknown"

        let payload: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "event": "watch_removed",
            "ts": Date().timeIntervalSince1970
        ]

        APIHelper.shared.post(to: API.uploadHeartRate, body: payload)
        print("🚨 [HRM] Watch likely removed — sent via API:", payload)
    }
}
