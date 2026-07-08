import Foundation

enum Mood: String, Codable, Sendable, CaseIterable {
    case terrible = "Terrible"
    case bad = "Bad"
    case okay = "Okay"
    case good = "Good"
    case great = "Great"

    var score: Double {
        switch self {
        case .terrible: return 1
        case .bad: return 2
        case .okay: return 3
        case .good: return 4
        case .great: return 5
        }
    }

    var emoji: String {
        switch self {
        case .terrible: return "😫"
        case .bad: return "😟"
        case .okay: return "😐"
        case .good: return "😊"
        case .great: return "😌"
        }
    }
}

enum EnergyLevel: String, Codable, Sendable, CaseIterable {
    case exhausted = "Exhausted"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case full = "Full"

    var score: Double {
        switch self {
        case .exhausted: return 1
        case .low: return 2
        case .moderate: return 3
        case .high: return 4
        case .full: return 5
        }
    }

    var emoji: String {
        switch self {
        case .exhausted: return "🫠"
        case .low: return "😴"
        case .moderate: return "🙂"
        case .high: return "⚡"
        case .full: return "🔥"
        }
    }
}

struct MoodCheckIn: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var timestamp: Date
    var mood: Mood
    var energy: EnergyLevel
    var focus: Int
    var notes: String
    var aiReflection: String?

    init(mood: Mood, energy: EnergyLevel, focus: Int, notes: String = "") {
        self.timestamp = Date()
        self.mood = mood
        self.energy = energy
        self.focus = focus
        self.notes = notes
    }
}

struct MoodTrend: Codable, Sendable {
    var averageMood: Double
    var averageEnergy: Double
    var averageFocus: Int
    var dominantMood: Mood
    var streak: Int
    var weeklyPattern: String?
}
