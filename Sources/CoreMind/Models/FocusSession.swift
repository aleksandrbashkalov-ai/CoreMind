import Foundation

enum FocusState: String, Codable, Sendable {
    case idle
    case focusing
    case break_
    case completed
    case interrupted
}

struct FocusSession: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var type: FocusSessionType
    var state: FocusState
    var interruptions: Int
    var focusScore: Double
    var activitySummary: String?
    var note: String?
}

enum FocusSessionType: String, Codable, Sendable, CaseIterable {
    case pomodoro = "Pomodoro"
    case deepWork = "Deep Work"
    case adaptive = "Adaptive"
    case custom = "Custom"

    var defaultDuration: TimeInterval {
        switch self {
        case .pomodoro: return 1500
        case .deepWork: return 3600
        case .adaptive: return 1500
        case .custom: return 1800
        }
    }

    var breakDuration: TimeInterval {
        switch self {
        case .pomodoro: return 300
        case .deepWork: return 600
        case .adaptive: return 300
        case .custom: return 300
        }
    }
}

struct FocusMetrics: Codable, Sendable {
    var totalFocusToday: TimeInterval
    var sessionsCompleted: Int
    var averageSessionLength: TimeInterval
    var bestFocusHour: Int
    var distractionTime: TimeInterval
    var focusScore: Double
}
