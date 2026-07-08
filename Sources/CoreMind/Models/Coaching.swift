import Foundation

enum AdviceType: String, Codable, Sendable, CaseIterable {
    case mindfulness = "Mindfulness"
    case focus = "Focus"
    case wellbeing = "Wellbeing"
    case productivity = "Productivity"
    case stoic = "Stoic Wisdom"
}

enum AdvicePriority: String, Codable, Sendable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var score: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

struct CoachingAdvice: Codable, Sendable, Identifiable, Equatable {
    var id = UUID().uuidString
    var type: AdviceType
    var title: String
    var description: String
    var priority: AdvicePriority
    var actionItem: String?
    var timestamp: Date = Date()
    var isRead: Bool = false
    var isDismissed: Bool = false
}

struct CoachingReport: Codable, Sendable, Identifiable {
    var id = UUID().uuidString
    var date: Date
    var type: CoachingReportType
    var summary: String
    var moodTrend: String?
    var topAdvice: [CoachingAdvice]
    var focusMetrics: FocusMetrics?
    var aiGenerated: Bool
}

enum CoachingReportType: String, Codable, Sendable {
    case daily = "Daily"
    case weekly = "Weekly"
    case realtime = "Realtime"
}

struct BreathingExercise: Codable, Sendable, Identifiable {
    var id = UUID()
    var name: String
    var description: String
    var inhale: TimeInterval
    var hold: TimeInterval
    var exhale: TimeInterval
    var holdAfterExhale: TimeInterval
    var cycles: Int
    var emoji: String

    static let boxBreathing = BreathingExercise(
        name: "Box Breathing",
        description: "Inhale, hold, exhale, hold — equal parts. Calms the nervous system.",
        inhale: 4, hold: 4, exhale: 4, holdAfterExhale: 4,
        cycles: 8, emoji: "🟦"
    )

    static let fourSevenEight = BreathingExercise(
        name: "4-7-8 Breathing",
        description: "Inhale 4, hold 7, exhale 8. The 'relaxing breath' technique.",
        inhale: 4, hold: 7, exhale: 8, holdAfterExhale: 0,
        cycles: 6, emoji: "🟣"
    )

    static let coherentBreathing = BreathingExercise(
        name: "Coherent Breathing",
        description: "Slow, even breaths. Optimizes heart rate variability.",
        inhale: 5, hold: 0, exhale: 5, holdAfterExhale: 0,
        cycles: 12, emoji: "🟢"
    )

    static let physiologicalSigh = BreathingExercise(
        name: "Physiological Sigh",
        description: "Two sharp inhales, one long exhale. Instant stress relief.",
        inhale: 2, hold: 0, exhale: 6, holdAfterExhale: 0,
        cycles: 5, emoji: "🌊"
    )

    static let all: [BreathingExercise] = [
        .boxBreathing, .fourSevenEight, .coherentBreathing, .physiologicalSigh
    ]
}
