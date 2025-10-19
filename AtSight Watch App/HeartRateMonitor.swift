//
//  HeartRateMonitor.swift
//  AtSight
//
//  Created by Najd Alsabi on 19/10/2025.
//

import Foundation
import HealthKit
import WatchConnectivity

final class HeartRateMonitor: NSObject {
    static let shared = HeartRateMonitor()
    private let healthStore = HKHealthStore()
    private var query: HKObserverQuery?
    private var lastBPM: Double = 0
    private var timer: Timer?
    private var lastUpdateTime: TimeInterval = 0
    private var lastAlertTime: TimeInterval = 0 // ✅ added to avoid spamming

    private override init() {}

    // MARK: - Start
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

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if let q = query { healthStore.stop(q) }
        print("🛑 HeartRateMonitor stopped")
    }

    // MARK: - Query
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

        // Safety timer → if no updates for 2 min, assume watch removed
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date().timeIntervalSince1970

            // Stop sending if parent acknowledged alert
            if UserDefaults.standard.bool(forKey: "stopHeartRateMonitoring") {
                print("🧩 [HRM] Parent acknowledged, skipping alerts")
                return
            }

            // No HR updates → likely removed
            if now - self.lastUpdateTime > 120 {
                self.notifyWatchRemoved(childName: childName)
            }
        }

        print("❤️ HeartRateMonitor started for \(childName)")
    }

    // MARK: - Fetch latest
    private func fetchLatestHeartRate(for type: HKQuantityType, childName: String) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let hrSample = samples?.first as? HKQuantitySample {
                let bpm = hrSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                self.lastBPM = bpm
                self.lastUpdateTime = Date().timeIntervalSince1970
                print("❤️ Current BPM: \(bpm)")

                // Forward to iPhone
                self.sendHeartRateToPhone(bpm: bpm, childName: childName)

                if bpm < 20 {
                    // Send alert every 2 minutes until acknowledged
                    let now = Date().timeIntervalSince1970
                    if now - self.lastAlertTime > 120 {
                        self.lastAlertTime = now
                        self.notifyWatchRemoved(childName: childName)
                    }
                } else {
                    // ✅ Watch worn again → reset stop flag
                    UserDefaults.standard.set(false, forKey: "stopHeartRateMonitoring")
                    print("✅ Watch worn again — monitoring resumed")
                }
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Send to iPhone
    private func sendHeartRateToPhone(bpm: Double, childName: String) {
        guard WCSession.default.isReachable else { return }
        let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? ""
        let msg: [String: Any] = [
            "type": "heart_rate",
            "childId": childId,
            "childName": childName,
            "bpm": bpm,
            "ts": Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        print("📤 [HRM] sent heart rate:", msg)
    }

    // MARK: - Watch removed notifier
    private func notifyWatchRemoved(childName: String) {
        guard WCSession.default.isReachable else { return }

        // Stop if parent tapped OK
        if UserDefaults.standard.bool(forKey: "stopHeartRateMonitoring") {
            print("🚫 [HRM] Parent acknowledged, not sending duplicate alert")
            return
        }

        let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? ""
        let msg: [String: Any] = [
            "type": "watch_removed",
            "childId": childId,
            "childName": childName,
            "ts": Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        print("🚨 [HRM] Watch likely removed for \(childName)")
    }
}
