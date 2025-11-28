//
//  APIHelper.swift
//  AtSight
//
//  EDIT BY RIYAM: Created this file to define API endpoints and provide a helper
//  class for sending API requests from the parent (iOS) app.
//

import Foundation

// MARK: - API Endpoint Definitions

/**
 * Defines the API endpoints for the AtSight application.
 */
enum API {
    // Base URL for cloud functions
    static let baseURL = "https://us-central1-atsight.cloudfunctions.net"

    /**
     * URL for the 'triggerHalt' cloud function.
     * This is called by the parent to send a HALT signal to the watch.
     */
    static var triggerHalt: String { "https://us-central1-atsight.cloudfunctions.net/triggerHalt" }
    
    // NOTE: Other API endpoints can be added here.
}

// MARK: - API Helper Class

/**
 * A singleton helper class for making API requests.
 */
final class APIHelper {
    
    static let shared = APIHelper()
    private init() {}

    /**
     * Performs a generic POST request to a given URL.
     * - Parameters:
     * - url: The full endpoint URL string.
     * - body: A dictionary of [String: Any] to be sent as the JSON body.
     * - completion: A completion handler that returns on the main thread.
     */
    func post(to url: String, body: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        guard let endpoint = URL(string: url) else {
            print("❌ [APIHelper] Invalid URL:", url)
            DispatchQueue.main.async {
                completion(false, NSError(domain: "APIHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            }
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ [APIHelper] JSON encode error:", error.localizedDescription)
            DispatchQueue.main.async {
                completion(false, error)
            }
            return
        }

        print("📡 [APIHelper] Sending POST to \(url) with body: \(body)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [APIHelper] API POST error:", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [APIHelper] Invalid response from server.")
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "APIHelper", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                }
                return
            }
            
            print("✅ [APIHelper] API Response Status Code: \(httpResponse.statusCode)")

            if (200...299).contains(httpResponse.statusCode) {
                // Success
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                // Server-side error
                var errorMessage = "Server returned status \(httpResponse.statusCode)."
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("❌ [APIHelper] Server error body: \(responseBody)")
                    errorMessage = responseBody
                }
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "APIHelper", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                }
            }
        }.resume()
    }
}
