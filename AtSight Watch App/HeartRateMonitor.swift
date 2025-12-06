//
//  HeartRateMonitor.swift
//  AtSight Watch App
//
//  Created by Leena on 22/10/2025.
//  Simplified: motion + missing-HR off-wrist heuristic, stale filtering, clean IDs
//

import Foundation
import HealthKit
import CoreMotion
import Combine

final class HeartRateMonitor: NSObject, ObservableObject {
    static let shared = HeartRateMonitor()

    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()

    private var query: HKObserverQuery?
    private var timer: Timer?
    // ✅ NEW: Timer for the child's response timeout
    private var promptResponseTimer: Timer?

    // Last known heart rate + time
    private var lastBPM: Double = 0
    private var lastUpdateTime: TimeInterval = 0

    // Motion + alert throttling
    private var lastSignificantMotionTime: TimeInterval = 0
    private var lastAlertTime: TimeInterval = 0

    // Off-wrist / back-on state
    private var isLikelyOffWrist = false
    private var backOnCandidateCount = 0

    // Heuristic thresholds
    private let maxSampleAge: TimeInterval = 15          // ignore HR older than this (seconds)
    private let noHRThreshold: TimeInterval = 120         // no HR for ≥ 2 min
    private let motionQuietThreshold: TimeInterval = 300 // no motion for ≥ 5 min (strong case)
    private let longMotionQuietThreshold: TimeInterval = 60 // no motion for ≥ 1 min (fallback / debug)
    private let alertCooldown: TimeInterval = 120         // don’t spam alerts more than once per 2 min

    // Back-on heuristics
    private let backOnRequiredSamples = 3                 // how many good samples in a row
    private let backOnMaxSampleAge: TimeInterval = 8      // HR sample must be this fresh
    private let backOnMotionWindow: TimeInterval = 20     // motion must be recent within this window (seconds)

    // ✅ NEW: Duration for the child to respond before auto-sending "removed" notification
    private let promptTimeoutDuration: TimeInterval = 15 // Set to 15 seconds (adjust as needed)

    // MARK: - Child popup state (for SwiftUI)
    @Published var showOffWristPrompt: Bool = false

    // We remember which child name to use when sending "watch_removed"
    private var pendingChildNameForPrompt: String?

    private override init() {}

    // MARK: - ID helpers

    private func currentGuardianId() -> String {
        // Use ONE canonical key for guardian ID everywhere
        return UserDefaults.standard.string(forKey: "guardianId") ?? "unknown"
    }

    private func currentChildId() -> String {
        return UserDefaults.standard.string(forKey: "currentChildId") ?? "unknown"
    }

    // MARK: - Start / Stop

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
                    self.startMotionUpdates()
                }
            } else {
                print("❌ HeartRate authorization failed:", error?.localizedDescription ?? "unknown")
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        // ✅ Stop the prompt timer
        promptResponseTimer?.invalidate()
        promptResponseTimer = nil

        if let q = query {
            healthStore.stop(q)
        }

        motionManager.stopAccelerometerUpdates()

        // Reset state
        isLikelyOffWrist = false
        backOnCandidateCount = 0
        lastBPM = 0
        lastUpdateTime = 0
        showOffWristPrompt = false
        pendingChildNameForPrompt = nil

        print("🛑 HeartRateMonitor stopped")
    }

    // MARK: - Query setup

    private func startQuery(type: HKQuantityType, childName: String) {
        query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            guard let self = self else {
                completion()
                return
            }

            if let error = error {
                print("❌ HeartRate observer error:", error.localizedDescription)
                completion()
                return
            }

            self.fetchLatestHeartRate(for: type, childName: childName)
            completion()
        }

        if let q = query {
            healthStore.execute(q)
        }

        // Periodically check for off-wrist based on motion + HR recency
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.evaluateOffWristIfNeeded(now: Date(), childName: childName)
        }

        // Initialize so we don’t immediately think it's quiet
        let nowTs = Date().timeIntervalSince1970
        lastSignificantMotionTime = nowTs
        lastUpdateTime = 0 // no sample yet
        isLikelyOffWrist = false
        backOnCandidateCount = 0

        print("❤️ HeartRateMonitor started for \(childName)")
    }

    // MARK: - Motion tracking

    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else {
            print("⚠️ Accelerometer not available, motion-based off-wrist detection disabled")
            return
        }

        motionManager.accelerometerUpdateInterval = 1.0 // 1 Hz is enough

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Accelerometer error:", error.localizedDescription)
                return
            }

            guard let accel = data?.acceleration else { return }

            // Magnitude of acceleration vector
            let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)

            // Around 1.0 when stationary. Deviation indicates movement.
            let deltaFrom1g = fabs(magnitude - 1.0)

            if deltaFrom1g > 0.1 {
                lastSignificantMotionTime = Date().timeIntervalSince1970
            }
        }

        print("📡 Motion monitoring started for off-wrist heuristic")
    }

    // MARK: - Fetch latest HR sample

    private func fetchLatestHeartRate(for type: HKQuantityType, childName: String) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ HeartRate sample query error:", error.localizedDescription)
                return
            }

            guard let hrSample = samples?.first as? HKQuantitySample else { return }

            let now = Date()
            let sampleAge = now.timeIntervalSince(hrSample.endDate)

            // Ignore very old samples
            guard sampleAge < self.maxSampleAge else {
                print("⚠️ Ignoring stale HR sample (age: \(sampleAge)s)")
                return
            }

            let bpm = hrSample.quantity.doubleValue(for: HKUnit(from: "count/min"))

            // Very basic sanity check
            guard bpm > 0, bpm < 240 else {
                print("⚠️ Ignoring implausible BPM:", bpm)
                return
            }

            self.lastBPM = bpm
            self.lastUpdateTime = now.timeIntervalSince1970

            print("❤️ Current BPM: \(bpm) (age: \(sampleAge)s)")
            self.sendHeartRateToAPI(bpm: bpm, childName: childName)

            // Evaluate if this HR + motion combo suggests the watch is back on wrist
            self.evaluateBackOnIfNeeded(sampleAge: sampleAge, now: now, childName: childName)
        }

        healthStore.execute(query)
    }

    // MARK: - Off-wrist heuristic (simple & explainable)

    private func evaluateOffWristIfNeeded(now: Date, childName: String) {
        if UserDefaults.standard.bool(forKey: "stopHeartRateMonitoring") {
            print("🧩 [HRM] Parent acknowledged, skipping off-wrist alerts")
            return
        }

        let nowTs = now.timeIntervalSince1970

        // If we never received a valid HR sample yet, do nothing
        guard lastUpdateTime > 0 else {
            print("🧪 [HRM] No HR yet, skip off-wrist check")
            return
        }

        let secondsSinceHR = nowTs - lastUpdateTime
        let secondsSinceMotion = nowTs - lastSignificantMotionTime

        // Strong case: no HR + no motion
        let hrIsStale = secondsSinceHR > noHRThreshold         // e.g. > 2 min
        let motionIsVeryLow = secondsSinceMotion > motionQuietThreshold  // e.g. > 5 min

        // Fallback: long period with no motion, even if HR keeps coming
        let longMotionQuiet = secondsSinceMotion > longMotionQuietThreshold // e.g. > 1 min

        print("🧪 [HRM] Off-wrist check → sinceHR=\(secondsSinceHR)s, sinceMotion=\(secondsSinceMotion)s, hrIsStale=\(hrIsStale), motionLow=\(motionIsVeryLow), longQuiet=\(longMotionQuiet)")

        let shouldTrigger =
            (hrIsStale && motionIsVeryLow) || // strong case
            longMotionQuiet                  // fallback case

        guard shouldTrigger else { return }

        // Throttle alerts
        if nowTs - lastAlertTime < alertCooldown {
            print("⏱ [HRM] Off-wrist condition met but in cooldown")
            return
        }

        // Only trigger once: now we show a popup to the child instead of
        // immediately notifying the parent.
        if !isLikelyOffWrist {
            isLikelyOffWrist = true
            backOnCandidateCount = 0
            lastAlertTime = nowTs
            pendingChildNameForPrompt = childName

            print("🚨 [HRM] Off-wrist condition met → asking child: Are you still here?")
            DispatchQueue.main.async {
                self.showOffWristPrompt = true
            }
        } else {
            print("🔁 [HRM] Still off-wrist, not re-showing prompt (cooldown active)")
        }
    }

    // MARK: - Back-on heuristic

    private func evaluateBackOnIfNeeded(sampleAge: TimeInterval, now: Date, childName: String) {
        // Only care if we previously decided it's off-wrist
        guard isLikelyOffWrist else { return }

        let nowTs = now.timeIntervalSince1970
        let secondsSinceMotion = nowTs - lastSignificantMotionTime

        let hasRecentMotion = secondsSinceMotion < backOnMotionWindow
        let sampleIsFresh = sampleAge < backOnMaxSampleAge

        if hasRecentMotion && sampleIsFresh {
            backOnCandidateCount += 1
            print("🧪 [HRM] Back-on candidate \(backOnCandidateCount)/\(backOnRequiredSamples) (motion \(secondsSinceMotion)s ago)")
        } else {
            if backOnCandidateCount != 0 {
                print("↩️ [HRM] Back-on candidate reset (motion or sample age not good enough)")
            }
            backOnCandidateCount = 0
        }

        guard backOnCandidateCount >= backOnRequiredSamples else { return }

        // Confirmed: watch is likely back on wrist
        isLikelyOffWrist = false
        backOnCandidateCount = 0

        print("✅ [HRM] Watch likely back on wrist (HR + motion stable)")
        notifyWatchBackOn(childName: childName)
    }

    // MARK: - Send HR to API

    private func sendHeartRateToAPI(bpm: Double, childName: String) {
        let childId = currentChildId()
        let guardianId = currentGuardianId()

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

    // MARK: - Child popup responses

    /// Child taps "Yes" (Still Here) OR timeout occurs (Still Here).
    func childConfirmedStillHere() {
        print("✅ [HRM] Child confirmed watch is still on (or prompt timed out successfully).")
        // ✅ Stop the prompt timeout timer
        promptResponseTimer?.invalidate()
        promptResponseTimer = nil
        
        isLikelyOffWrist = false
        backOnCandidateCount = 0
        pendingChildNameForPrompt = nil

        DispatchQueue.main.async {
            self.showOffWristPrompt = false
        }
    }
    
    // ✅ NEW: Logic when the prompt times out and we assume the watch is off.
    func promptTimeoutAction() {
        let name = pendingChildNameForPrompt ?? "Child"
        print("🚨 [HRM] Prompt timed out (No response) → assuming watch is OFF → notifying parent.")
        
        // Ensure state is reset
        isLikelyOffWrist = true // Keep this true until we see good samples again
        pendingChildNameForPrompt = nil
        
        // 1. Send Parent notification
        notifyWatchRemoved(childName: name)

        // 2. Hide the prompt
        DispatchQueue.main.async {
            self.showOffWristPrompt = false
        }
    }

    /// Removed the `childConfirmedOff()` function as only the timeout should trigger the "No" scenario.

    // MARK: - Watch removed notifier

    private func notifyWatchRemoved(childName: String) {
        if UserDefaults.standard.bool(forKey: "stopHeartRateMonitoring") {
            print("🚫 [HRM] Parent acknowledged, not sending duplicate alert")
            return
        }

        let guardianId = currentGuardianId()
        let childId = currentChildId()

        let payload: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "childName": childName,
            "event": "watch_removed",
            "ts": Date().timeIntervalSince1970
        ]

        APIHelper.shared.post(to: API.uploadHeartRate, body: payload)
        print("🚨 [HRM] Watch likely removed — sent via API:", payload)
    }

    // MARK: - Watch back-on notifier (optional for parent app)

    private func notifyWatchBackOn(childName: String) {
        if UserDefaults.standard.bool(forKey: "stopHeartRateMonitoring") {
            print("🚫 [HRM] Parent acknowledged, skipping watch_back_on event")
            return
        }

        let guardianId = currentGuardianId()
        let childId = currentChildId()

        let payload: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "childName": childName,
            "event": "watch_back_on",
            "ts": Date().timeIntervalSince1970
        ]

        APIHelper.shared.post(to: API.uploadHeartRate, body: payload)
        print("✅ [HRM] Watch likely back on — sent via API:", payload)
    }
}
