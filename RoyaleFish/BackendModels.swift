//
//  BackendModels.swift
//  RoyaleFish
//
//  Created by Benjamin Duboshinsky on 2/21/26.
//


import Foundation

struct UploadFrameResponse: Decodable {
    let match_id: String
    let status: String
}

struct MoveAnalysis: Decodable, Identifiable {
    // Use timestamp as stable-ish id for UI
    var id: String { "\(move_timestamp)-\(card_played)" }

    let move_timestamp: Double
    let card_played: String
    let grade: String
    let win_probability_before: Double
    let win_probability_after: Double
    let elixir_diff: Double
    let explanation: String
}

struct AnalysisResponse: Decodable {
    let match_id: String
    let finalized: Bool
    let moves: [MoveAnalysis]
    let game_state: [String: AnyDecodable]
}

// Simple AnyDecodable for game_state dict
struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { value = v; return }
        if let v = try? c.decode(Int.self) { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        if let v = try? c.decode([String: AnyDecodable].self) { value = v; return }
        if let v = try? c.decode([AnyDecodable].self) { value = v; return }
        value = NSNull()
    }
}

