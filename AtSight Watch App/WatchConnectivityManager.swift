//  WatchConnectivityManager-merged.swift
//  AtSight (WatchKit Extension)
//  Merged to keep BOTH features:
//  - Battery threshold sync via ApplicationContext
//  - One-time GPS fix sent to iPhone on successful link
//  - ✅ Store childId/parent/child names for later live location sends

import WatchConnectivity
import Combine
import CoreLocation

final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    // MARK: - Activate
    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        print("🔗 [WCM] WCSession activated on watch")
    }

    // MARK: - WCSessionDelegate (watchOS)
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("⌚️ [WCM] activation:", activationState.rawValue, error?.localizedDescription ?? "ok")
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("⌚️ [WCM] reachable?", session.isReachable)
    }

    // Receive WITHOUT reply
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handle(message, reply: nil)
    }

    // Receive WITH reply
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        handle(message, reply: replyHandler)
    }

    // ✅ Battery threshold sync via ApplicationContext
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let threshold = applicationContext["lowBatteryThreshold"] as? Int {
            BatteryMonitor.shared.updateThreshold(threshold)   // تأكد أن هالدالة موجودة في BatteryMonitor
            print("🔋 [WCM] Updated lowBatteryThreshold on watch:", threshold)
        } else {
            print("ℹ️ [WCM] applicationContext without threshold:", applicationContext)
        }
    }

    // MARK: - Unified handler
    private func handle(_ message: [String: Any],
                        reply: (([String: Any]) -> Void)?) {
        guard let type = message["type"] as? String else {
            reply?("bad_request".asReply())
            return
        }

        switch type {
        case "link":
            let incomingPIN = message["pin"] as? String
            let childName   = message["childName"] as? String ?? ""
            let parentName  = message["parentName"] as? String ?? ""
            let childId     = message["childId"] as? String ?? "" // قد يكون فاضي

            Task { @MainActor in
                let currentPIN = PairingState.shared.pin
                print("⌚️ [WCM] link req. incomingPIN=\(incomingPIN ?? "nil") currentPIN=\(currentPIN)")

                guard let pin = incomingPIN else {
                    reply?("missing_pin".asReply())
                    return
                }

                if pin == currentPIN {
                    // 1) Reply first
                    reply?("linked".asReply())

                    // 2) Update UI state
                    PairingState.shared.childName  = childName
                    PairingState.shared.parentName = parentName
                    PairingState.shared.linked     = true

                    // 3) ✅ Persist identifiers for later (live location, UI)
                    if !childId.isEmpty {
                        UserDefaults.standard.set(childId, forKey: "currentChildId")
                    }
                    if !parentName.isEmpty {
                        UserDefaults.standard.set(parentName, forKey: "parentDisplayName")
                    }
                    if !childName.isEmpty {
                        UserDefaults.standard.set(childName, forKey: "childDisplayName")
                    }

                    // 4) One-time GPS fix and send to iPhone
                    WatchLocationManager.shared.requestOnce { loc in
                        var payload: [String: Any] = ["type": "watch_location"]
                        if !childId.isEmpty { payload["childId"] = childId }
                        if let loc = loc {
                            payload["lat"] = loc.coordinate.latitude
                            payload["lon"] = loc.coordinate.longitude
                            payload["acc"] = loc.horizontalAccuracy
                            payload["ts"]  = loc.timestamp.timeIntervalSince1970
                        } else {
                            payload["error"] = "no_location"
                        }

                        let s = WCSession.default
                        if s.isReachable {
                            s.sendMessage(payload, replyHandler: nil) {
                                print("⚠️ [WCM] sendMessage error:", $0.localizedDescription)
                                s.transferUserInfo(payload) // fallback
                            }
                        } else {
                            s.transferUserInfo(payload) // will deliver later
                        }
                        print("📤 [WCM] sent initial fix:", payload)
                    }

                    // ملاحظة: تشغيل live updates يتم عادة من HomeView_Watch.onAppear()
                    // WatchLocationManager.shared.startLiveUpdates()

                } else {
                    reply?("wrong_pin".asReply())
                }
            }

        default:
            reply?("unknown_type".asReply())
        }
    }
}

private extension String {
    func asReply() -> [String: Any] { ["status": self] }
}
