import AppKit
import Foundation
import UserNotifications

enum NudgeType: String, Sendable {
    case breakReminder = "break"
    case deepWork = "deepWork"
    case distraction = "distraction"
    case creativeBreak = "creativeBreak"
    case breathing = "breathing"
    case movement = "movement"
    case focusSession = "focusSession"
    case burnout = "burnout"
    case streak = "streak"

    var icon: String {
        switch self {
        case .breakReminder: return "cup.and.saucer"
        case .deepWork: return "brain"
        case .distraction: return "eyes"
        case .creativeBreak: return "paintpalette"
        case .breathing: return "wind"
        case .movement: return "figure.walk"
        case .focusSession: return "target"
        case .burnout: return "exclamationmark.triangle"
        case .streak: return "flame"
        }
    }
}

struct ProactiveNudge: Sendable, Identifiable {
    let id = UUID()
    let type: NudgeType
    let title: String
    let message: String
    let actionTitle: String?
    let priority: Int
    let timestamp: Date
}

actor ProactiveNudgeService: ProactiveNudgeServiceProtocol {
    static let shared = ProactiveNudgeService()

    private let activityTracker: ActivityTrackerProtocol
    private let windowMonitor: WindowMonitorProtocol
    private var monitoringTask: Task<Void, Never>?
    private var lastNudgeTime: [NudgeType: Date] = [:]
    private var cooldowns: [NudgeType: TimeInterval] = [
        .breakReminder: 3600,
        .deepWork: 7200,
        .distraction: 1800,
        .creativeBreak: 5400,
        .breathing: 3600,
        .movement: 7200,
        .focusSession: 7200,
        .burnout: 86400,
        .streak: 86400
    ]
    private var recentNudges: [ProactiveNudge] = []
    private let maxStoredNudges = 20

    init(
        activityTracker: ActivityTrackerProtocol = ActivityTracker.shared,
        windowMonitor: WindowMonitorProtocol = WindowMonitor.shared
    ) {
        self.activityTracker = activityTracker
        self.windowMonitor = windowMonitor
    }

    func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled, let self = self {
                await self.evaluateNudges()
                try? await Task.sleep(nanoseconds: 120_000_000_000)
            }
        }
        Log.info("ProactiveNudgeService started")
    }

    func stop() async {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    var currentNudges: [ProactiveNudge] {
        recentNudges.sorted { $0.priority > $1.priority }
    }

    // MARK: - Nudge Evaluation

    private func evaluateNudges() async {
        let records = await activityTracker.allRecords
        let activeApp = await windowMonitor.currentApp

        let totalActive = records.reduce(0) { $0 + $1.duration }
        let continuousMinutes = await calculateContinuousWork()
        let distractionCount = countDistractions(in: records)
        let appCategory = categorizeApp(activeApp.name)

        if continuousMinutes > 120 && canNudge(.breakReminder) {
            await fireNudge(.breakReminder, title: "Time for a break",
                message: "You've been working for \(continuousMinutes) minutes. Your brain needs rest to stay sharp.",
                actionTitle: "Breathe for 2 min")
        }

        if continuousMinutes > 240 && canNudge(.burnout) {
            await fireNudge(.burnout, title: "Extended work detected",
                message: "Over 4 hours of continuous work. Take a real break — step away from the screen.",
                actionTitle: "Start break")
        }

        if distractionCount >= 5 && canNudge(.distraction) {
            await fireNudge(.distraction, title: "Frequent switching",
                message: "You've switched tasks \(distractionCount) times recently. Try a focus session.",
                actionTitle: "Start Focus")
        }

        if appCategory == .creative && continuousMinutes > 90 && canNudge(.creativeBreak) {
            await fireNudge(.creativeBreak, title: "Creative flow detected",
                message: "You're deep in creative work. A short break can reset your perspective.",
                actionTitle: "Creative pause")
        }

        if appCategory == .meeting && continuousMinutes > 60 && canNudge(.movement) {
            await fireNudge(.movement, title: "Meeting marathon",
                message: "Back-to-back meetings reduce cognitive performance. Stand up and stretch.",
                actionTitle: "Stretch")
        }

        if totalActive < 3600 && Calendar.current.component(.hour, from: Date()) >= 10
            && canNudge(.focusSession) {
            await fireNudge(.focusSession, title: "Shallow work morning",
                message: "Less than 1 hour of focused work today. Start a deep work session.",
                actionTitle: "Start now")
        }
    }

    // MARK: - Cooldown

    // Internal for testability via @testable import
    func canNudge(_ type: NudgeType) -> Bool {
        guard let cooldown = cooldowns[type],
              let lastTime = lastNudgeTime[type] else { return true }
        return Date().timeIntervalSince(lastTime) >= cooldown
    }

    private func fireNudge(_ type: NudgeType, title: String, message: String, actionTitle: String?) async {
        lastNudgeTime[type] = Date()

        let nudge = ProactiveNudge(
            type: type,
            title: title,
            message: message,
            actionTitle: actionTitle,
            priority: type.priorityScore,
            timestamp: Date()
        )

        recentNudges.append(nudge)
        if recentNudges.count > maxStoredNudges {
            recentNudges.removeFirst(recentNudges.count - maxStoredNudges)
        }

        await showNotification(nudge)
    }

    // MARK: - Notification

    private func showNotification(_ nudge: ProactiveNudge) async {
        guard NSClassFromString("XCTestCase") == nil else { return }
        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.body = nudge.message
        content.sound = .default
        if let action = nudge.actionTitle {
            content.userInfo = ["action": action, "type": nudge.type.rawValue]
        }

        let request = UNNotificationRequest(
            identifier: nudge.id.uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Log.warning("Nudge notification failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Analysis

    private func calculateContinuousWork() async -> Int {
        let records = await activityTracker.allRecords
        let recent = records.suffix(20)
        guard let last = recent.last else { return 0 }
        let threshold = Date().timeIntervalSince(last.timestamp) > 300
        if threshold { return 0 }
        let breakTypes: Set<ActivityType> = [.browsing, .media, .other]
        let workMinutes = recent.filter { !breakTypes.contains($0.activityType) }
            .reduce(0) { $0 + $1.duration } / 60
        return Int(workMinutes)
    }

    private func countDistractions(in records: [ActivityRecord]) -> Int {
        let recent = records.suffix(30)
        let switches = zip(recent, recent.dropFirst())
            .filter { $0.appBundleID != $1.appBundleID }
            .count
        return switches / 2
    }

    enum AppCategory: Sendable { case code, creative, meeting, reading, browsing, other }

    // Internal for testability via @testable import
    func categorizeApp(_ name: String) -> AppCategory {
        let lower = name.lowercased()
        if lower.contains("xcode") || lower.contains("code") || lower.contains("terminal") { return .code }
        if lower.contains("figma") || lower.contains("photoshop") || lower.contains("affinity")
            || lower.contains("illustrator") || lower.contains("final cut") { return .creative }
        if lower.contains("zoom") || lower.contains("teams") || lower.contains("meet")
            || lower.contains("facetime") || lower.contains("webex") { return .meeting }
        if lower.contains("safari") || lower.contains("chrome") || lower.contains("firefox") { return .browsing }
        return .other
    }

    func dismissNudge(_ id: UUID) async {
        recentNudges.removeAll { $0.id == id }
    }
}

extension NudgeType {
    var priorityScore: Int {
        switch self {
        case .burnout: return 10
        case .distraction: return 8
        case .breakReminder: return 7
        case .movement: return 6
        case .creativeBreak: return 5
        case .focusSession: return 5
        case .breathing: return 4
        case .deepWork: return 3
        case .streak: return 2
        }
    }
}
