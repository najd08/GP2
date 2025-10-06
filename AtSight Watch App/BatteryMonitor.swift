//
//  BatteryMonitor.swift
//  AtSight
//
//  Created by Najd Alsabi on 07/09/2025.
//

import WatchKit
import WatchConnectivity

final class BatteryMonitor: NSObject {
    static let shared = BatteryMonitor()           // singleton
    private let session = WCSession.default
    private var timer: Timer?
    private var lastSentPercentage: Int?
    
    private var currentChildName: String?
    private var thresholdPercentage: Int = 20
    private let pollInterval: TimeInterval = 600   // 10 minutes

    private override init() {
        super.init()
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
    }

    func startMonitoring(for childName: String) {
        print("🚀 startMonitoring called for child:", childName)
        currentChildName = childName

        timer?.invalidate()
        checkBattery()   // immediate check
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            print("⏱ Timer fired, checking battery again")
            self?.checkBattery()
        }
    }


    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        currentChildName = nil
    }

    func updateThreshold(_ newValue: Int) {
        thresholdPercentage = newValue
        print("🔋 Threshold updated to \(newValue)%")
    }

    private func checkBattery() {
        let level = WKInterfaceDevice.current().batteryLevel
        print("🔋 checkBattery() called. Raw level:", level)

        guard level >= 0.0 else {
            print("⚠️ Battery level unavailable.")
            return
        }

        let percentage = Int(level * 100)
        print("🔋 Converted to percentage:", percentage)

        if let last = lastSentPercentage, last == percentage {
            print("⏩ Skipping, same as lastSentPercentage")
            return
        }
        lastSentPercentage = percentage

        print("🔍 Comparing \(percentage)% <= \(thresholdPercentage)% ?")
        if percentage <= thresholdPercentage {
            print("📤 Sending low battery alert")
            sendBattery(percentage: percentage)
        }
    }


    private func sendBattery(percentage: Int) {
        guard let childName = currentChildName else { return }

        let payload: [String: Any] = [
            "type": "lowBattery",
            "batteryLevel": percentage,
            "childName": childName,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Watch: sendMessage error:", error.localizedDescription)
                self.fallbackTransfer(payload: payload)
            }
        } else {
            fallbackTransfer(payload: payload)
        }
    }

    private func fallbackTransfer(payload: [String: Any]) {
        if WCSession.default.activationState == .activated {
            WCSession.default.transferUserInfo(payload)
        } else {
            do {
                try WCSession.default.updateApplicationContext(["lastBattery": payload])
            } catch {
                print("Watch: updateApplicationContext failed", error.localizedDescription)
            }
        }
    }

    deinit { stopMonitoring() }
}
