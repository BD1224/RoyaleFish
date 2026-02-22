//
//  ScreenCoachBackendViewModel.swift
//  RoyaleFish
//
//  Created by Benjamin Duboshinsky on 2/21/26.
//

import SwiftUI
import Combine
import UIKit

@MainActor
final class ScreenCoachViewModel: ObservableObject {
    enum RecordingState: Equatable {
        case off
        case on(startedAt: Date)
        var isOn: Bool { if case .on = self { return true } else { return false } }
    }

    @Published var selectedTab: Tab = .dashboard
    @Published var recordingState: RecordingState = .off
    @Published var isAnalyzing: Bool = false

    @Published var enableCoachFeed: Bool = true
    @Published var enableHaptics: Bool = true
    @Published var darkMode: Bool = true

    @Published var sessions: [Session] = []

    @Published var dashboardShots: [Shot] = []
    @Published var coachFeed: [CoachEvent] = []
    @Published var dashboardGrade: String = "—"
    @Published var dashboardSummary: String = "Idle."
    @Published var selectedShot: Shot?

    @Published var elapsed: TimeInterval = 0

    // Backend state
    private var matchId: String?
    private var analysisPollTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?

    private let api = BackendAPIClient.shared
    private let capture = ReplayCaptureService()

    private var timer: Timer?
    private var startDate: Date?

    // Track seen moves to only append new ones
    private var seenMoveIDs = Set<String>()

    // Tuning
    private let framesPerMinute: Double = 60
    private let pollEverySeconds: Double = 1.0

    func startRecording() {
        print("startRecording Initiated")
        guard !recordingState.isOn else { return }

        let now = Date()
        startDate = now
        elapsed = 0
        recordingState = .on(startedAt: now)

        isAnalyzing = true
        dashboardGrade = "—"
        dashboardSummary = "Connecting…"
        coachFeed = []
        dashboardShots = []
        matchId = nil
        seenMoveIDs.removeAll()

        startTimer()

        captureTask?.cancel()
        captureTask = Task {
            do {
                try await capture.startCapture(framesPerMinute: framesPerMinute) { [weak self] jpeg, ts in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.sendFrame(jpeg: jpeg, ts: ts)
                    }
                }
            } catch {
                self.dashboardSummary = "ReplayKit error: \(error.localizedDescription)"
                self.isAnalyzing = false
                self.recordingState = .off
                self.stopTimer()
            }
        }

        analysisPollTask?.cancel()
        analysisPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollEverySeconds * 1_000_000_000))
                await pollAnalysis()
            }
        }
        print("startRecording Finished")
    }

    func stopRecording() {
        guard recordingState.isOn else { return }
        recordingState = .off
        isAnalyzing = false
        stopTimer()

        Task { await capture.stopCapture() }
        captureTask?.cancel()
        analysisPollTask?.cancel()

        // Create a simple “session” from current feed
        let duration = elapsed
        let hero = dashboardShots.first ?? Shot(timestamp: 0, style: .arenaBlue)
        let highlights = dashboardShots.isEmpty ? [hero] : dashboardShots
        let events = coachFeed.isEmpty ? [CoachEvent(timestamp: 0, icon: "sparkles", text: "No events")] : coachFeed

        let new = Session(
            date: Date(),
            duration: duration,
            grade: dashboardGrade == "—" ? "—" : dashboardGrade,
            summary: dashboardSummary,
            heroShot: hero,
            highlights: Array(highlights.prefix(8)),
            events: Array(events.prefix(10)),
            focusScore: Int.random(in: 70...95),
            record: "—"
        )
        sessions.insert(new, at: 0)
    }

    func openShot(_ shot: Shot) { selectedShot = shot }

    private func sendFrame(jpeg: Data, ts: Double) async {
        do {
            let resp = try await api.uploadFrame(matchId: matchId, timestamp: ts, jpegData: jpeg)
            if matchId == nil { matchId = resp.match_id }
            dashboardSummary = "Live capture…"
        } catch {
            dashboardSummary = "Upload failed: \(error.localizedDescription)"
        }
    }

    private func pollAnalysis() async {
        guard let matchId else { return }
        do {
            let analysis = try await api.getAnalysis(matchId: matchId)
            apply(analysis: analysis)
        } catch {
            // keep quiet during polling
        }
    }

    private func apply(analysis: AnalysisResponse) {
        guard enableCoachFeed else { return }

        // Add new moves to feed
        let newMoves = analysis.moves.filter { !seenMoveIDs.contains($0.id) }
        if newMoves.isEmpty { return }

        for m in newMoves.reversed() { // chronological-ish
            seenMoveIDs.insert(m.id)

            // Feed row
            let icon = iconForGrade(m.grade)
            coachFeed.insert(CoachEvent(timestamp: m.move_timestamp, icon: icon, text: m.explanation), at: 0)
            if coachFeed.count > 8 { coachFeed = Array(coachFeed.prefix(8)) }

            // “Highlight” shot placeholder (still using your mock screenshot styling)
            dashboardShots.insert(Shot(timestamp: m.move_timestamp, style: styleForGrade(m.grade)), at: 0)
            if dashboardShots.count > 6 { dashboardShots = Array(dashboardShots.prefix(6)) }

            // Grade + summary
            dashboardGrade = gradeLetter(m.grade)
            dashboardSummary = m.explanation
        }
    }

    private func gradeLetter(_ g: String) -> String {
        switch g {
        case "PERFECT": return "A+"
        case "EXCELLENT": return "A"
        case "GOOD": return "B+"
        case "NOT_IDEAL": return "B"
        case "BAD": return "C"
        case "BLUNDER": return "D"
        default: return "—"
        }
    }

    private func iconForGrade(_ g: String) -> String {
        switch g {
        case "PERFECT": return "crown.fill"
        case "EXCELLENT": return "sparkles"
        case "GOOD": return "bolt.fill"
        case "NOT_IDEAL": return "hourglass"
        case "BAD": return "exclamationmark.triangle.fill"
        case "BLUNDER": return "xmark.octagon.fill"
        default: return "sparkles"
        }
    }

    private func styleForGrade(_ g: String) -> Shot.ShotStyle {
        switch g {
        case "PERFECT": return .arenaGold
        case "EXCELLENT": return .arenaCyan
        case "GOOD": return .arenaBlue
        case "NOT_IDEAL": return .arenaViolet
        case "BAD": return .arenaCrimson
        case "BLUNDER": return .arenaCrimson
        default: return .arenaBlue
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let start = self.startDate else { self.elapsed = 0; return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startDate = nil
    }
}
