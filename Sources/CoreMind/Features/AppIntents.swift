import AppIntents
import Foundation

@available(macOS 14, *)
struct StartFocusSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus Session"
    static let description: IntentDescription = "Begin a focus or pomodoro session"

    @Parameter(title: "Minutes", default: 25, inclusiveRange: (1, 240))
    var minutes: Int

    @Parameter(title: "Session Type", default: "Pomodoro")
    var sessionType: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let type = FocusSessionType(rawValue: sessionType) ?? .pomodoro
        let duration = TimeInterval(minutes * 60)
        let session = FocusSession(
            startTime: Date(),
            duration: duration,
            type: type,
            state: .focusing,
            interruptions: 0,
            focusScore: 0
        )
        try DatabaseService.shared.saveFocusSession(session)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let time = formatter.string(from: Date().addingTimeInterval(duration))
        let finishMsg = "\(type.rawValue) started. Finishes at \(time)."
        return .result(dialog: IntentDialog(stringLiteral: finishMsg))
    }
}

@available(macOS 14, *)
struct LogMoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Mood Check-In"
    static let description: IntentDescription = "Record how you're feeling"

    @Parameter(title: "Mood", default: "Okay")
    var mood: String

    @Parameter(title: "Energy", default: "Moderate")
    var energy: String

    @Parameter(title: "Focus level", default: 5, inclusiveRange: (1, 10))
    var focus: Int

    @Parameter(title: "Notes")
    var notes: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let moodValue = Mood(rawValue: mood) ?? .okay
        let energyValue = EnergyLevel(rawValue: energy) ?? .moderate
        let checkIn = MoodCheckIn(
            mood: moodValue,
            energy: energyValue,
            focus: focus,
            notes: notes ?? ""
        )
        try DatabaseService.shared.saveMoodCheckIn(checkIn)
        let msg = "Logged: \(moodValue.emoji) \(moodValue.rawValue), \(energyValue.emoji) \(energyValue.rawValue)"
        return .result(dialog: IntentDialog(stringLiteral: msg))
    }
}

@available(macOS 14, *)
struct StartBreathingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Breathing Exercise"
    static let description: IntentDescription = "Begin a guided breathing session"

    @Parameter(title: "Exercise", default: "Box Breathing")
    var exercise: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ex = BreathingExercise.all.first(where: { $0.name == exercise }) ?? .boxBreathing
        let msg = "Starting \(ex.name). Breathe in for \(Int(ex.inhale)) seconds."
        return .result(dialog: IntentDialog(stringLiteral: msg))
    }
}

@available(macOS 14, *)
struct GetDailyInsightIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Daily Insight"
    static let description: IntentDescription = "See your focus and wellness summary"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let checkIns = (try? DatabaseService.shared.fetchMoodCheckIns(limit: 7)) ?? []
        let sessions = (try? DatabaseService.shared.fetchFocusSessions(limit: 5)) ?? []

        var parts: [String] = []
        if !sessions.isEmpty {
            let total = sessions.reduce(0) { $0 + $1.duration }
            parts.append("\(Int(total / 60)) min focus today")
        }
        if let last = checkIns.first {
            parts.append("Last check-in: \(last.mood.emoji)")
        }
        if parts.isEmpty {
            parts.append("No data yet. Start with a check-in or focus session.")
        }
        let summary = parts.joined(separator: ". ")
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}
