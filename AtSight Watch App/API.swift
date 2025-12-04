import Foundation

enum API {
    static let baseURL = "https://us-central1-atsight.cloudfunctions.net"

    static var uploadLocation: String { "https://uploadlivelocation-7gq4boqq6a-uc.a.run.app" }
    static var uploadBattery: String { "https://uploadbattery-7gq4boqq6a-uc.a.run.app" }
    static var uploadHeartRate: String { "https://us-central1-atsight.cloudfunctions.net/uploadHeartRate" }
    static var triggerSOS: String { "https://triggersos-7gq4boqq6a-uc.a.run.app" }
    static var uploadVoice: String { "https://uploadvoicemessageapi-7gq4boqq6a-uc.a.run.app" }
    static var getVoice: String { "https://getvoicemessagesapi-7gq4boqq6a-uc.a.run.app" }
    static var checkPairingCode: String { "https://checkpairingcode-7gq4boqq6a-uc.a.run.app" }
    static var checkHaltStatus: String { "https://checkhaltstatus-7gq4boqq6a-uc.a.run.app" }
    // ✅ NEW ENDPOINTS
    static var checkLinkStatus: String { "https://checklinkstatus-7gq4boqq6a-uc.a.run.app" }
    static var syncAuthorizedGuardians: String { "https://syncauthorizedguardians-7gq4boqq6a-uc.a.run.app" }
    // ✅ NEW: QR Code Generation API
    static var generateQR: String { "https://generateqr-7gq4boqq6a-uc.a.run.app" }
}
