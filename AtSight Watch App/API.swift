//
//  API.swift
//  AtSight (watchOS target)
//
//  Created by Leena on 22/10/2025.
//

import Foundation
enum API {
    static let baseURL = "https://us-central1-atsight.cloudfunctions.net"

    static var uploadLocation: String { "https://uploadlivelocation-7gq4boqq6a-uc.a.run.app" }
    static var uploadBattery: String { "https://uploadbattery-7gq4boqq6a-uc.a.run.app" }
    static var uploadHeartRate: String { "https://us-central1-atsight.cloudfunctions.net/uploadHeartRate" }
    static var triggerSOS: String { "https://triggersos-7gq4boqq6a-uc.a.run.app" }
}

