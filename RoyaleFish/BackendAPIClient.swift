//
//  BackendAPIClient.swift
//  RoyaleFish
//
//  Created by Benjamin Duboshinsky on 2/21/26.
//

import Foundation
import UIKit

final class BackendAPIClient {
    static let shared = BackendAPIClient()

    // Simulator: localhost works
    // Real iPhone: change to http://<your-mac-ip>:8000
    var baseURL: URL = URL(string: "http://172.30.203.178:8000/docs:")!

    private init() {}

    func uploadFrame(
        matchId: String?,
        timestamp: Double,
        jpegData: Data
    ) async throws -> UploadFrameResponse {
        let url = baseURL.appendingPathComponent("/upload_frame")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // match_id (optional)
        if let matchId = matchId {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"match_id\"\r\n\r\n")
            body.appendString("\(matchId)\r\n")
        }

        // timestamp
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n")
        body.appendString("\(timestamp)\r\n")

        // file
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"frame.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        body.appendString("\r\n")

        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? "unknown"
            throw NSError(domain: "BackendAPIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "upload_frame failed: \(s)"])
        }

        return try JSONDecoder().decode(UploadFrameResponse.self, from: data)
    }

    func getAnalysis(matchId: String) async throws -> AnalysisResponse {
        let url = baseURL.appendingPathComponent("/analysis/\(matchId)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? "unknown"
            throw NSError(domain: "BackendAPIClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "analysis failed: \(s)"])
        }
        return try JSONDecoder().decode(AnalysisResponse.self, from: data)
    }
}

private extension Data {
    mutating func appendString(_ s: String) {
        if let d = s.data(using: .utf8) { append(d) }
    }
}
