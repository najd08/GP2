//
//  APIHelper.swift
//  AtSight Watch App
//
//  Created by Leena on 22/10/2025.
//

import Foundation

final class APIHelper {
    static let shared = APIHelper()
    private init() {}

    func post(to url: String, body: [String: Any]) {
        guard let endpoint = URL(string: url) else {
            print("❌ Invalid URL:", url)
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ JSON encode error:", error.localizedDescription)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ API POST error:", error.localizedDescription)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response:", httpResponse.statusCode)
            }

            if let data = data,
               let text = String(data: data, encoding: .utf8),
               !text.isEmpty {
                print("📩 API Response Body:", text)
            }
        }.resume()
    }
}
