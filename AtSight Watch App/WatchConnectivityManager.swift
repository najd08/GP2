// EDIT BY RIYAM: Updated "link" handler to include a console indicator for Admin status.
// - Checks if guardian list is empty.
// - If empty -> isAdmin = true, update child's name, PRINT ADMIN MESSAGE with parent name.
// - If not empty -> isAdmin = false, do NOT update child's name.
// - Sends isAdmin flag back to iOS.
// - Fixed missing 'isAdmin' argument error in addGuardian call.
// - Fixed wrong variable passed to childId (was passing childName).

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

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let threshold = applicationContext["lowBatteryThreshold"] as? Int {
            BatteryMonitor.shared.updateThreshold(threshold)
            print("🔋 [WCM] Updated lowBatteryThreshold on watch:", threshold)
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
            let childId     = message["childId"] as? String ?? ""
            let guardianId  = message["guardianId"] as? String ?? ""

            Task { @MainActor in
                let currentPIN = PairingState.shared.pin
                print("⌚️ [WCM] link req. incomingPIN=\(incomingPIN ?? "nil") currentPIN=\(currentPIN)")

                guard let pin = incomingPIN else {
                    reply?("missing_pin".asReply())
                    return
                }

                if pin == currentPIN {
                    // ✅ Check if this is the first guardian (list empty)
                    let isFirstGuardian = PairingState.shared.linkedGuardianIDs.isEmpty
                    let isAdmin = isFirstGuardian

                    let replyData: [String: Any] = [
                        "status": "linked",
                        "isAdmin": isAdmin
                    ]
                    reply?(replyData)

                    // ✅ Logic: Only update child name if Admin (first guardian)
                    if isFirstGuardian {
                        PairingState.shared.childName = childName
                        if !childName.isEmpty {
                            UserDefaults.standard.set(childName, forKey: "childDisplayName")
                        }
                        print("👑 Admin Access Granted: \(parentName) is the Admin. Child name set to \(childName).")
                    } else {
                        print("👥 Subsequent guardian linked: \(parentName). Not Admin. Keeping existing child name: \(PairingState.shared.childName)")
                    }
                   
                    // ✅ Add guardian to list WITH NAME and ADMIN FLAG
                    if !guardianId.isEmpty {
                        // Fixed: Passed 'childId' variable correctly and added 'isAdmin'
                        PairingState.shared.addGuardian(id: guardianId, name: parentName, childId: childId, isAdmin: isAdmin)
                        UserDefaults.standard.set(guardianId, forKey: "guardianId") // Last connected
                    }

                    if !childId.isEmpty {
                        UserDefaults.standard.set(childId, forKey: "currentChildId")
                    }

                    // Send GPS fix
                    WatchLocationManager.shared.requestOnce { loc in
                        var payload: [String: Any] = ["type": "watch_location"]
                        if !childId.isEmpty { payload["childId"] = childId }
                        if let loc = loc {
                            payload["lat"] = loc.coordinate.latitude
                            payload["lon"] = loc.coordinate.longitude
                            payload["acc"] = loc.horizontalAccuracy
                            payload["ts"]  = loc.timestamp.timeIntervalSince1970
                        }
                        WCSession.default.sendMessage(payload, replyHandler: nil)
                    }
                } else {
                    reply?("wrong_pin".asReply())
                }
            }
           
        case "unlink":
            if let guardianId = message["guardianId"] as? String {
                print("⌚️ [WCM] Received unlink request for guardian: \(guardianId)")
                Task { @MainActor in
                    PairingState.shared.removeGuardian(guardianId)
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
