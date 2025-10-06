import Foundation
import Combine

@MainActor
final class PairingState: ObservableObject {
static let shared = PairingState()

@Published var pin: String {
didSet { UserDefaults.standard.set(pin, forKey: "pairPIN") }
}
@Published var linked = false
@Published var childName: String = ""
@Published var parentName: String = ""

private init() {
if let saved = UserDefaults.standard.string(forKey: "pairPIN") {
self.pin = saved
} else {
let new = String(format: "%06d", Int.random(in: 0..<1_000_000))
self.pin = new
UserDefaults.standard.set(new, forKey: "pairPIN")
}
}

func regenerate() {
guard !linked else { return }
pin = String(format: "%06d", Int.random(in: 0..<1_000_000))
}
}
