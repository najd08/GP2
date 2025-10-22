//
//  BatteryMonitor.swift
//  AtSight Watch App
//
//  Created by Leena on 07/09/2025.
//  Updated on 22/10/2025: Added guardianId + field name alignment with API
//

import WatchKit
import Foundation

final class BatteryMonitor: NSObject {
    static let shared = BatteryMonitor()
    
    private var timer: Timer?
    private var lastSentPercentage: Int?
    
    private var currentChildName: String?
    private var thresholdPercentage: Int = 20
    private let pollInterval: TimeInterval = 600   // 10 minutes

    private override init() {
        super.init()
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
    }

    // MARK: - Start monitoring
    func startMonitoring(for childName: String) {
        print("🚀 startMonitoring called for child:", childName)
        currentChildName = childName

        timer?.invalidate()
        checkBattery()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
    }

    // MARK: - Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        currentChildName = nil
    }

    // MARK: - Update threshold
    func updateThreshold(_ newValue: Int) {
        thresholdPercentage = newValue
        print("🔋 Threshold updated to \(newValue)%")
    }

    // MARK: - Check battery level
    private func checkBattery() {
        let level = WKInterfaceDevice.current().batteryLevel
        print("🔋 checkBattery() called. Raw level:", level)

        guard level >= 0.0 else {
            print("⚠️ Battery level unavailable.")
            return
        }

        let percentage = Int(level * 100)
        if let last = lastSentPercentage, last == percentage {
            print("⏩ Skipping, same as lastSentPercentage")
            return
        }
        lastSentPercentage = percentage

        // Always send, not only when low — optional
        sendBattery(percentage: percentage)
    }

    // MARK: - Send battery data through API
    private func sendBattery(percentage: Int) {
        guard let childName = currentChildName else { return }

        let childId = UserDefaults.standard.string(forKey: "currentChildId") ?? "unknown"
        let guardianId = UserDefaults.standard.string(forKey: "guardianId") ?? "unknown"

        let payload: [String: Any] = [
            "guardianId": guardianId,
            "childId": childId,
            "childName": childName,
            "battery": percentage,
            "ts": Date().timeIntervalSince1970
        ]

        APIHelper.shared.post(to: API.uploadBattery, body: payload)
        print("📤 [BatteryMonitor] Sent via API:", payload)
    }

    deinit { stopMonitoring() }
}
