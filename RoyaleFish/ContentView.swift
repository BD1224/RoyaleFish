//
//  ContentView.swift
//  FrontendHackathon
//
//
import SwiftUI
import UIKit
import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

// MARK: - Models

struct Shot: Identifiable, Hashable {
    let id = UUID()
    let timestamp: TimeInterval
    let style: ShotStyle

    enum ShotStyle: CaseIterable, Hashable {
        case arenaBlue
        case arenaGold
        case arenaCyan
        case arenaCrimson
        case arenaViolet

        var gradient: LinearGradient {
            switch self {
            case .arenaBlue:
                return LinearGradient(
                    colors: [Color.royalBlueBright.opacity(0.95), Color.royalBlue.opacity(0.65), Color.navyDeep.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .arenaGold:
                return LinearGradient(
                    colors: [Color.goldBright.opacity(0.95), Color.gold.opacity(0.70), Color.navyDeep.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .arenaCyan:
                return LinearGradient(
                    colors: [Color.cyan.opacity(0.85), Color.royalBlue.opacity(0.55), Color.navyDeep.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .arenaCrimson:
                return LinearGradient(
                    colors: [Color.redHot.opacity(0.88), Color.royalBlue.opacity(0.50), Color.navyDeep.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .arenaViolet:
                return LinearGradient(
                    colors: [Color.purple.opacity(0.70), Color.royalBlue.opacity(0.55), Color.navyDeep.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct CoachEvent: Identifiable, Hashable {
    let id = UUID()
    let timestamp: TimeInterval
    let icon: String
    let text: String
}

struct Session: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let grade: String
    let summary: String
    let heroShot: Shot
    let highlights: [Shot]
    let events: [CoachEvent]
    let focusScore: Int
    let record: String
}

extension TimeInterval {
    var mmss: String {
        let total = max(0, Int(self))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
    var hm: String {
        let total = max(0, Int(self))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - ViewModel

@MainActor
final class ScreenCoachViewModel: ObservableObject {
    enum RecordingState: Equatable {
        case off
        case on(startedAt: Date)

        var isOn: Bool {
            if case .on = self { return true }
            return false
        }
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
    @Published var dashboardGrade: String = "B+"
    @Published var dashboardSummary: String = "Slight overcommit after elixir dip."

    @Published var selectedShot: Shot?

    private var timer: Timer?
    private var startDate: Date?
    @Published var elapsed: TimeInterval = 0

    private let feedTemplates: [(String, String)] = [
        ("shield.fill", "Overcommitted on defense"),
        ("hourglass", "Solid elixir patience"),
        ("arrow.triangle.2.circlepath", "Missed cycle window"),
        ("bolt.fill", "Fast punish was clean"),
        ("crown.fill", "Good tower trade timing"),
        ("exclamationmark.triangle.fill", "Risky push into low elixir")
    ]

    private let summaryTemplates: [(String, String)] = [
        ("A-", "Clean tempo with smart pressure."),
        ("B+", "Slight overcommit after elixir dip."),
        ("B", "A few forced defenses lowered tempo."),
        ("C+", "Too many reactive spends.")
    ]

    init() {
        seedMockSessions()
        seedDashboardFromLatest()
    }

    func startRecording() {
        guard !recordingState.isOn else { return }
        let now = Date()
        startDate = now
        recordingState = .on(startedAt: now)
        isAnalyzing = true
        elapsed = 0
        coachFeed = []
        dashboardShots = []
        dashboardGrade = "—"
        dashboardSummary = "Recording live."
        startTimer()
        haptic(.soft)
    }

    func stopRecording() {
        guard recordingState.isOn else { return }
        let duration = elapsed
        startDate = nil
        recordingState = .off
        isAnalyzing = false
        stopTimer()
        haptic(.medium)

        let gradePick = summaryTemplates.randomElement() ?? ("B+", "Slight overcommit after elixir dip.")
        let hero = dashboardShots.first ?? Shot(timestamp: 42, style: .arenaBlue)
        let shots = dashboardShots.isEmpty ? [hero] : dashboardShots
        let events = coachFeed.isEmpty ? [CoachEvent(timestamp: 42, icon: "shield.fill", text: "Solid defense timing")] : coachFeed

        let focus = Int.random(in: 68...94)
        let record = ["3–1", "2–2", "4–0", "1–3"].randomElement() ?? "2–2"

        let new = Session(
            date: Date(),
            duration: duration,
            grade: gradePick.0,
            summary: gradePick.1,
            heroShot: hero,
            highlights: Array(shots.prefix(8)),
            events: Array(events.prefix(10)),
            focusScore: focus,
            record: record
        )
        sessions.insert(new, at: 0)
        seedDashboardFromLatest()
    }

    func simulateNewScreenshot() {
        let t = max(8, Int(elapsed == 0 ? TimeInterval.random(in: 12...160) : elapsed))
        let style = Shot.ShotStyle.allCases.randomElement() ?? .arenaBlue
        let shot = Shot(timestamp: TimeInterval(t), style: style)
        dashboardShots.insert(shot, at: 0)

        if dashboardShots.count > 6 { dashboardShots = Array(dashboardShots.prefix(6)) }

        if dashboardGrade == "—" {
            let pick = summaryTemplates.randomElement() ?? ("B+", "Slight overcommit after elixir dip.")
            dashboardGrade = pick.0
            dashboardSummary = pick.1
        }

        isAnalyzing = recordingState.isOn || !dashboardShots.isEmpty
        haptic(.light)
    }

    func simulateAIUpdate() {
        guard enableCoachFeed else { return }
        let t = max(6, Int(elapsed == 0 ? TimeInterval.random(in: 20...170) : elapsed))
        let pick = feedTemplates.randomElement() ?? ("sparkles", "Good pacing")
        let ev = CoachEvent(timestamp: TimeInterval(t), icon: pick.0, text: pick.1)
        coachFeed.insert(ev, at: 0)
        if coachFeed.count > 8 { coachFeed = Array(coachFeed.prefix(8)) }
        isAnalyzing = true
        haptic(.light)
    }

    func openShot(_ shot: Shot) {
        selectedShot = shot
        haptic(.soft)
    }

    private func seedDashboardFromLatest() {
        if let latest = sessions.first {
            dashboardShots = Array(latest.highlights.prefix(6))
            dashboardGrade = latest.grade
            dashboardSummary = latest.summary
            coachFeed = Array(latest.events.prefix(6))
        } else {
            dashboardShots = [
                Shot(timestamp: 42, style: .arenaBlue),
                Shot(timestamp: 70, style: .arenaGold),
                Shot(timestamp: 95, style: .arenaCyan)
            ]
            coachFeed = [
                CoachEvent(timestamp: 42, icon: "shield.fill", text: "Overcommitted on defense"),
                CoachEvent(timestamp: 70, icon: "hourglass", text: "Solid elixir patience"),
                CoachEvent(timestamp: 95, icon: "arrow.triangle.2.circlepath", text: "Missed cycle window")
            ]
            dashboardGrade = "B+"
            dashboardSummary = "Slight overcommit after elixir dip."
        }
        isAnalyzing = recordingState.isOn
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let start = self.startDate else {
                    self.elapsed = 0
                    return
                }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enableHaptics else { return }
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    private func seedMockSessions() {
        let now = Date()
        let cal = Calendar.current

        func makeSession(daysAgo: Int, duration: TimeInterval, grade: String, summary: String, style: Shot.ShotStyle, focus: Int, record: String) -> Session {
            let d = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let hero = Shot(timestamp: 42, style: style)
            let shots: [Shot] = [
                Shot(timestamp: 42, style: style),
                Shot(timestamp: 70, style: .arenaGold),
                Shot(timestamp: 96, style: .arenaCyan),
                Shot(timestamp: 118, style: .arenaBlue)
            ]
            let evs: [CoachEvent] = [
                CoachEvent(timestamp: 42, icon: "shield.fill", text: "Overcommitted on defense"),
                CoachEvent(timestamp: 70, icon: "hourglass", text: "Solid elixir patience"),
                CoachEvent(timestamp: 96, icon: "arrow.triangle.2.circlepath", text: "Missed cycle window"),
                CoachEvent(timestamp: 118, icon: "bolt.fill", text: "Fast punish was clean")
            ]
            return Session(date: d, duration: duration, grade: grade, summary: summary, heroShot: hero, highlights: shots, events: evs, focusScore: focus, record: record)
        }

        sessions = [
            makeSession(daysAgo: 0, duration: 18*60 + 42, grade: "B+", summary: "Slight overcommit after elixir dip.", style: .arenaBlue, focus: 82, record: "3–1"),
            makeSession(daysAgo: 2, duration: 14*60 + 05, grade: "A-", summary: "Clean tempo with smart pressure.", style: .arenaGold, focus: 91, record: "4–0"),
            makeSession(daysAgo: 5, duration: 22*60 + 16, grade: "B", summary: "A few forced defenses lowered tempo.", style: .arenaCyan, focus: 78, record: "2–2")
        ]
    }
}

// MARK: - Auth

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var firebaseUser: FirebaseAuth.User?
    @Published var lastErrorMessage: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.firebaseUser = user
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    var isSignedIn: Bool { firebaseUser != nil }

    var displayName: String {
        let n = firebaseUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? "Player" : n
    }

    var email: String {
        let e = firebaseUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return e.isEmpty ? "" : e
    }

    var photoURL: URL? { firebaseUser?.photoURL }

    func signInWithGoogle() {
        Task { @MainActor in
            do {
                self.lastErrorMessage = nil

                guard let presentingVC = Self.topMostViewController() else {
                    throw NSError(domain: "ScreenCoachAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller."])
                }

                guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
                    throw NSError(domain: "ScreenCoachAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing Firebase clientID."])
                }

                let config = GIDConfiguration(clientID: clientID)
                GIDSignIn.sharedInstance.configuration = config

                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
                let user = result.user

                guard let idToken = user.idToken?.tokenString else {
                    throw NSError(domain: "ScreenCoachAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token."])
                }
                let accessToken = user.accessToken.tokenString

                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                _ = try await Auth.auth().signIn(with: credential)
            } catch {
                self.lastErrorMessage = (error as NSError).localizedDescription
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = (error as NSError).localizedDescription
        }
    }

    private static func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
        let root = window?.rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
}

struct SettingsAlert: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - Tabs

enum Tab: String, CaseIterable {
    case dashboard = "Dashboard"
    case sessions = "Sessions"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "sparkles.rectangle.stack"
        case .sessions: return "photo.on.rectangle.angled"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var vm = ScreenCoachViewModel()
    @StateObject private var auth = AuthManager()

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 0) {
                ZStack {
                    switch vm.selectedTab {
                    case .dashboard:
                        DashboardView().environmentObject(vm).environmentObject(auth)
                    case .sessions:
                        SessionsRootView().environmentObject(vm).environmentObject(auth)
                    case .settings:
                        SettingsView().environmentObject(vm).environmentObject(auth)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                CustomTabBar(selected: $vm.selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .padding(.top, 10)
            }
        }
        .onOpenURL { url in
            _ = GIDSignIn.sharedInstance.handle(url)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $vm.selectedShot) { shot in
            ShotViewer(shot: shot) { vm.selectedShot = nil }
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject private var vm: ScreenCoachViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                heroHeader
                primaryActionCard
                latestHighlightsCard
                coachFeedCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
    }

    private var heroHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.royalBlueBright.opacity(0.98), Color.royalBlue.opacity(0.72), Color.navyDeep.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                .overlay(
                    HeroGlow()
                        .blendMode(.screen)
                        .opacity(0.82)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Screen Coach")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color.gold.opacity(0.55), radius: 10, x: 0, y: 4)
                }

                HStack(spacing: 10) {
                    recordingCapsule
                    analyzingCapsule
                    Spacer()
                }
            }
            .padding(18)
        }
        .frame(height: 128)
    }

    private var recordingCapsule: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.recordingState.isOn ? Color.redHot : Color.white.opacity(0.22))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(vm.recordingState.isOn ? 0.38 : 0.0), lineWidth: 3)
                        .blur(radius: vm.recordingState.isOn ? 0.6 : 0)
                )
                .shadow(color: Color.redHot.opacity(vm.recordingState.isOn ? 0.7 : 0.0), radius: 12)

            Text(vm.recordingState.isOn ? "Recording ON" : "Recording OFF")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(vm.recordingState.isOn ? 0.98 : 0.72))
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }

    private var analyzingCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.88))

            Text(vm.isAnalyzing ? "Analyzing" : "Idle")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(vm.isAnalyzing ? 0.98 : 0.68))
                .modifier(Shimmer(active: vm.isAnalyzing, speed: 1.15, bandSize: 0.50))
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }

    private var primaryActionCard: some View {
        GlowCard(cornerRadius: 24) {
            VStack(spacing: 14) {
                HStack {
                    Text("Session")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.74))
                    Spacer()
                    Text(vm.recordingState.isOn ? "LIVE" : "READY")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(vm.recordingState.isOn ? Color.white : Color.white.opacity(0.70))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(vm.recordingState.isOn ? Color.redHot.opacity(0.95) : Color.white.opacity(0.08))
                                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(vm.recordingState.isOn ? 0 : 0.12), lineWidth: 1))
                                .shadow(color: Color.redHot.opacity(vm.recordingState.isOn ? 0.55 : 0.0), radius: 12)
                        )
                }

                Text(vm.elapsed.mmss)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: Color.royalBlueBright.opacity(0.20), radius: 18, x: 0, y: 10)

                actionButton
            }
            .padding(18)
        }
    }

    private var actionButton: some View {
        let isOn = vm.recordingState.isOn
        return PressableButton(
            title: isOn ? "Stop Recording" : "Start Recording",
            leadingIcon: isOn ? "stop.fill" : "record.circle",
            style: isOn ? .danger : .primary
        ) {
            if isOn { vm.stopRecording() } else { vm.startRecording() }
        }
    }

    private var latestHighlightsCard: some View {
        GlowCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Latest Highlights")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    GradePill(grade: vm.dashboardGrade)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.dashboardShots.prefix(6)) { shot in
                            Button { vm.openShot(shot) } label: { ShotThumb(shot: shot) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack(spacing: 10) {
                    Pill(label: "Grade \(vm.dashboardGrade)", icon: "sparkles", tint: Color.goldBright.opacity(0.98))
                    Text(vm.dashboardSummary)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                    Spacer()
                }
            }
            .padding(18)
        }
    }

    private var coachFeedCard: some View {
        GlowCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Live Coach Feed")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if !vm.enableCoachFeed {
                        Text("OFF")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            )
                    }
                }

                VStack(spacing: 8) {
                    ForEach(vm.coachFeed.prefix(6)) { ev in
                        CoachFeedRow(event: ev)
                    }
                }
                .padding(.top, 2)

                HStack(spacing: 10) {
                    SmallPillButton(title: "New Screenshot", icon: "camera.fill") { vm.simulateNewScreenshot() }
                    SmallPillButton(title: "AI Update", icon: "sparkles") { vm.simulateAIUpdate() }
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
    }
}

// MARK: - Sessions

struct SessionsRootView: View {
    @EnvironmentObject private var vm: ScreenCoachViewModel

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    header
                    VStack(spacing: 12) {
                        ForEach(vm.sessions) { session in
                            NavigationLink(value: session) { SessionCard(session: session) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .navigationDestination(for: Session.self) { session in
                SessionDetailView(session: session).environmentObject(vm)
            }
        }
    }

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.navyDeep.opacity(0.98), Color.royalBlue.opacity(0.55), Color.navyDeep.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 10)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sessions")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Gallery + Coach notes")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color.gold.opacity(0.50), radius: 12, x: 0, y: 4)
            }
            .padding(16)
        }
        .frame(height: 92)
    }
}

struct SessionCard: View {
    let session: Session

    var body: some View {
        GlowCard(cornerRadius: 24, glow: Color.royalBlueBright.opacity(0.16)) {
            HStack(spacing: 12) {
                ShotThumb(shot: session.heroShot, size: CGSize(width: 74, height: 74))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        GradePill(grade: session.grade)
                    }

                    HStack(spacing: 10) {
                        Pill(label: session.duration.mmss, icon: "clock.fill", tint: Color.cyan.opacity(0.95))
                        Pill(label: session.record, icon: "crown.fill", tint: Color.goldBright.opacity(0.95))
                        Spacer()
                    }

                    Text(session.summary)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(14)
        }
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    @EnvironmentObject private var vm: ScreenCoachViewModel
    let session: Session

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                heroShotCard

                VStack(spacing: 12) {
                    ForEach(Array(zip(session.highlights.indices, session.highlights)), id: \.0) { idx, shot in
                        let note = session.events.indices.contains(idx) ? session.events[idx] : session.events.first!
                        Button { vm.openShot(shot) } label: { ShotNoteRow(shot: shot, note: note) }
                            .buttonStyle(.plain)
                    }
                }

                overallSummaryCard

                minimalStatsRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroShotCard: some View {
        GlowCard(cornerRadius: 24, glow: Color.royalBlueBright.opacity(0.20)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Hero Shot")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    GradePill(grade: session.grade)
                }

                Button { vm.openShot(session.heroShot) } label: {
                    MockScreenshotView(shot: session.heroShot)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 12)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
    }

    private var overallSummaryCard: some View {
        GlowCard(cornerRadius: 24, glow: Color.gold.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Overall Summary")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    GradePill(grade: session.grade)
                }

                Text(session.summary)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .lineLimit(2)
                    .minimumScaleFactor(0.92)
                    .allowsTightening(true)
            }
            .padding(18)
        }
    }

    private var minimalStatsRow: some View {
        HStack(spacing: 12) {
            MiniStat(title: "Focus", value: "\(session.focusScore)%", icon: "sparkles", tint: Color.goldBright.opacity(0.98))
            MiniStat(title: "Record", value: session.record, icon: "crown.fill", tint: Color.cyan.opacity(0.92))
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var vm: ScreenCoachViewModel
    @EnvironmentObject private var auth: AuthManager

    @State private var alertItem: SettingsAlert?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                header

                authSection

                settingGroup(title: "Controls") {
                    ToggleRow(title: "Enable Coach Feed", icon: "sparkles", isOn: $vm.enableCoachFeed)
                    Divider().background(Color.white.opacity(0.08)).padding(.leading, 52)
                    ToggleRow(title: "Haptics", icon: "hand.tap.fill", isOn: $vm.enableHaptics)
                    Divider().background(Color.white.opacity(0.08)).padding(.leading, 52)
                    ToggleRow(title: "Dark Mode", icon: "moon.stars.fill", isOn: $vm.darkMode)
                }

                privacyCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .preferredColorScheme(.dark)
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            GlowCard(cornerRadius: 24, glow: Color.gold.opacity(0.14)) {
                VStack(alignment: .leading, spacing: 12) {
                    if auth.isSignedIn {
                        signedInCard
                    } else {
                        signedOutCard
                    }
                }
                .padding(18)
            }
        }
        .onChange(of: auth.lastErrorMessage) { _, newValue in
            if let msg = newValue, !msg.isEmpty {
                alertItem = SettingsAlert(message: msg)
            }
        }
        .alert(item: $alertItem) { item in
            Alert(title: Text("Sign-In Error"), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private var signedOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.royalBlueBright.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.royalBlueBright.opacity(0.24), lineWidth: 1))
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.goldBright.opacity(0.95))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Sync your coach feed")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.70))
                }
                Spacer()
            }

            PressableButton(
                title: "Continue with Google",
                leadingIcon: "g.circle",
                style: .primary
            ) {
                auth.signInWithGoogle()
            }
        }
    }

    private var signedInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))

                    if let url = auth.photoURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.70))
                            }
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.70))
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.royalBlueBright.opacity(0.20), radius: 14, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(auth.displayName)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)

                    if !auth.email.isEmpty {
                        Text(auth.email)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .allowsTightening(true)
                    }
                }

                Spacer()

                GradePill(grade: "PRO")
            }

            PressableButton(
                title: "Sign Out",
                leadingIcon: "rectangle.portrait.and.arrow.right",
                style: .danger
            ) {
                auth.signOut()
            }
        }
    }

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.navyDeep.opacity(0.98), Color.royalBlue.opacity(0.55), Color.navyDeep.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 10)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Privacy-first controls")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color.gold.opacity(0.50), radius: 12, x: 0, y: 4)
            }
            .padding(16)
        }
        .frame(height: 92)
    }

    private func settingGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.cardDark.opacity(0.92))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                )
                .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
        }
    }

    private var privacyCard: some View {
        GlowCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.gold.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.gold.opacity(0.25), lineWidth: 1))
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .top, endPoint: .bottom))
                            .shadow(color: Color.gold.opacity(0.45), radius: 10, x: 0, y: 4)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("On-device analysis")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.70))
                    }
                    Spacer()
                }

                Label("All analysis stays on-device.", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))

                Label("Recording requires permission.", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(18)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.goldBright.opacity(0.95))
            }
            .frame(width: 36, height: 36)

            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.goldBright.opacity(0.95))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Viewer

struct ShotViewer: View {
    let shot: Shot
    let onClose: () -> Void

    var body: some View {
        ZStack {
            AppBackdrop()
                .overlay(Rectangle().fill(.ultraThinMaterial).opacity(0.18))

            VStack(spacing: 12) {
                HStack {
                    Button(action: onClose) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .heavy))
                            Text("Back")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Pill(label: "\(shot.timestamp.mmss)", icon: "clock.fill", tint: Color.cyan.opacity(0.92))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                MockScreenshotView(shot: shot)
                    .frame(height: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .shadow(color: .black.opacity(0.60), radius: 24, x: 0, y: 16)
                    .padding(.horizontal, 16)

                Spacer(minLength: 8)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selected: Tab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.cardDark.opacity(0.90))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)

            HStack(spacing: 10) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabBarItem(tab: tab, isSelected: selected == tab) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) { selected = tab }
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.prepare()
                        gen.impactOccurred()
                    }
                }
            }
            .padding(10)
        }
        .frame(height: 74)
    }
}

struct TabBarItem: View {
    let tab: Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.navyDeep.opacity(0.95) : Color.white.opacity(0.70))

                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.navyDeep.opacity(0.95))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, isSelected ? 14 : 12)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.gold.opacity(0.38), radius: 14, x: 0, y: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UI Components

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.navyDeep, Color.navyDeep.opacity(0.88), Color.black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            RadialGradient(colors: [Color.royalBlueBright.opacity(0.20), Color.clear],
                           center: .topLeading, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()

            RadialGradient(colors: [Color.gold.opacity(0.12), Color.clear],
                           center: .bottomTrailing, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()

            NoiseOverlay().ignoresSafeArea().opacity(0.10)
        }
    }
}

struct GlowCard<Content: View>: View {
    let cornerRadius: CGFloat
    var glow: Color = Color.royalBlueBright.opacity(0.18)
    var stroke: Color = Color.white.opacity(0.10)
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.cardDark.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(glow, lineWidth: 1)
                .blur(radius: 10)
                .opacity(0.85)

            content()
        }
    }
}

struct GradePill: View {
    let grade: String

    var body: some View {
        Text(grade)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.navyDeep.opacity(0.95))
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: Color.gold.opacity(0.35), radius: 14, x: 0, y: 10)
    }
}

struct Pill: View {
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }
}

struct SmallPillButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var pressed: Bool = false

    var body: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            gen.impactOccurred()

            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) { pressed = false }
                action()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(true)
            }
            .foregroundStyle(Color.white.opacity(0.90))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.985 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: pressed)
    }
}

struct PressableButton: View {
    enum Style {
        case primary
        case danger

        var gradient: LinearGradient {
            switch self {
            case .primary:
                return LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .danger:
                return LinearGradient(colors: [Color.redHot, Color.redHotDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }

        var foreground: Color {
            switch self {
            case .primary: return Color.navyDeep.opacity(0.95)
            case .danger: return .white
            }
        }

        var glow: Color {
            switch self {
            case .primary: return Color.gold.opacity(0.35)
            case .danger: return Color.redHot.opacity(0.38)
            }
        }
    }

    let title: String
    let leadingIcon: String
    let style: Style
    let action: () -> Void

    @State private var pressed: Bool = false

    var body: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()

            withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) { pressed = false }
                action()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
                    Image(systemName: leadingIcon)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(style.foreground.opacity(0.95))
                }
                .frame(width: 52, height: 52)

                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(style.foreground.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(true)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(style.foreground.opacity(0.70))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                style.gradient
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: style.glow, radius: 18, x: 0, y: 12)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: pressed)
    }
}

struct ShotThumb: View {
    let shot: Shot
    var size: CGSize = CGSize(width: 96, height: 72)

    var body: some View {
        MockScreenshotView(shot: shot)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 10)
            .overlay(alignment: .bottomTrailing) {
                Text(shot.timestamp.mmss)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.35))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    )
                    .padding(8)
            }
    }
}

struct CoachFeedRow: View {
    let event: CoachEvent

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                Image(systemName: event.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.goldBright.opacity(0.95))
            }
            .frame(width: 30, height: 30)

            Text(event.timestamp.mmss)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.70))
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)

            Text(event.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)

            Spacer(minLength: 0)
        }
    }
}

struct ShotNoteRow: View {
    let shot: Shot
    let note: CoachEvent

    var body: some View {
        GlowCard(cornerRadius: 22, glow: Color.royalBlueBright.opacity(0.14)) {
            HStack(spacing: 12) {
                ShotThumb(shot: shot, size: CGSize(width: 74, height: 58))

                VStack(alignment: .leading, spacing: 6) {
                    Pill(label: note.timestamp.mmss, icon: "clock.fill", tint: Color.cyan.opacity(0.92))

                    HStack(spacing: 10) {
                        Image(systemName: note.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.goldBright.opacity(0.95))
                        Text(note.text)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                            .allowsTightening(true)
                        Spacer(minLength: 0)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(14)
        }
    }
}

struct MiniStat: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        GlowCard(cornerRadius: 22, glow: tint.opacity(0.18)) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.30), lineWidth: 1))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(tint.opacity(0.95))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(1)
                    Text(value)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }

                Spacer()
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mock Screenshot

struct MockScreenshotView: View {
    let shot: Shot
    @State private var pulse: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(shot.style.gradient)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .overlay(ArenaGrid().opacity(0.20).blendMode(.overlay).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
                .overlay(
                    RadialGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        center: .init(x: 0.25 + 0.05 * sin(pulse), y: 0.20),
                        startRadius: 10,
                        endRadius: 280
                    )
                    .blendMode(.screen)
                    .opacity(0.90)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
                .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(LinearGradient(colors: [Color.gold, Color.goldBright], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color.gold.opacity(0.50), radius: 10, x: 0, y: 4)
                    Spacer()
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.88))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer()

                HStack(spacing: 10) {
                    ArenaChip(label: "Arena", icon: "sparkles", tint: Color.goldBright.opacity(0.95))
                    ArenaChip(label: "Live", icon: "circle.fill", tint: Color.redHot.opacity(0.95))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = 6.28 }
        }
    }
}

struct ArenaChip: View {
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }
}

struct ArenaGrid: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cols = 10
            let rows = 6
            Path { p in
                for c in 1..<cols {
                    let x = CGFloat(c) * (w / CGFloat(cols))
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: h))
                }
                for r in 1..<rows {
                    let y = CGFloat(r) * (h / CGFloat(rows))
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }
}

// MARK: - Effects

struct Shimmer: ViewModifier {
    let active: Bool
    let speed: Double
    let bandSize: Double

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let band = max(0.2, min(0.85, bandSize))
                    LinearGradient(
                        colors: [Color.white.opacity(0.00), Color.white.opacity(0.45), Color.white.opacity(0.00)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .rotationEffect(.degrees(18))
                    .frame(width: w * CGFloat(band), height: h * 2.2)
                    .offset(x: phase * (w * 1.6), y: -h * 0.6)
                    .blendMode(.screen)
                    .onAppear {
                        phase = -1.1
                        withAnimation(.linear(duration: 1.2 / max(0.2, speed)).repeatForever(autoreverses: false)) {
                            phase = 1.2
                        }
                    }
                }
                .mask(content)
            }
        }
    }
}

struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let count = Int((size.width * size.height) / 2200)
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let r = CGFloat.random(in: 0.6...1.8)
                let a = CGFloat.random(in: 0.02...0.06)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(Color.white.opacity(a)))
            }
        }
    }
}

struct HeroGlow: View {
    @State private var t: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RadialGradient(
                    colors: [Color.white.opacity(0.22), Color.clear],
                    center: .init(x: 0.18 + 0.06 * sin(t), y: 0.25),
                    startRadius: 10,
                    endRadius: max(w, h) * 0.72
                )
                RadialGradient(
                    colors: [Color.gold.opacity(0.18), Color.clear],
                    center: .init(x: 0.82 - 0.05 * sin(t * 0.9), y: 0.18 + 0.04 * cos(t)),
                    startRadius: 10,
                    endRadius: max(w, h) * 0.68
                )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { t = 6.28 }
            }
        }
    }
}

// MARK: - Colors

extension Color {
    static let navyDeep = Color(red: 8/255, green: 12/255, blue: 24/255)
    static let cardDark = Color(red: 14/255, green: 18/255, blue: 34/255)

    static let royalBlue = Color(red: 35/255, green: 92/255, blue: 255/255)
    static let royalBlueBright = Color(red: 85/255, green: 165/255, blue: 255/255)

    static let gold = Color(red: 244/255, green: 193/255, blue: 74/255)
    static let goldBright = Color(red: 255/255, green: 222/255, blue: 120/255)

    static let redHot = Color(red: 255/255, green: 68/255, blue: 92/255)
    static let redHotDeep = Color(red: 220/255, green: 36/255, blue: 72/255)
}

// MARK: - Preview

#Preview {
    ContentView()
}
