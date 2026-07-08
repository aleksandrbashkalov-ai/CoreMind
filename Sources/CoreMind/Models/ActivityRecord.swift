import Foundation

enum ActivityType: String, Codable, Sendable, CaseIterable {
    case reading = "Reading"
    case writing = "Writing"
    case coding = "Coding"
    case meeting = "Meeting"
    case design = "Design"
    case browsing = "Browsing"
    case email = "Email"
    case media = "Media"
    case other = "Other"
}

struct ActivityRecord: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var timestamp: Date
    var activityType: ActivityType
    var appBundleID: String
    var appName: String
    var windowTitle: String?
    var duration: TimeInterval
    var confidence: Double
    var metadataJSON: String?
}

struct DeepWorkSession: Codable, Sendable {
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var activityType: ActivityType
    var appName: String?
    var interruptions: Int
    var focusScore: Double
}

struct BurnoutSignals: Codable, Sendable {
    var overtimeHoursToday: TimeInterval
    var nightWorkHoursThisWeek: TimeInterval
    var weekendWorkHoursThisWeek: TimeInterval
    var meetingOverloadRatio: Double
    var contextSwitchesPerHour: Double
    var averageWorkdayDuration: TimeInterval
    var daysWorkedThisWeek: Int
    var riskLevel: BurnoutRiskLevel
    var wellbeingScore: Double
    var wellbeingTrend: WellbeingTrend
}

enum BurnoutRiskLevel: String, Codable, Sendable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"

    var score: Int {
        switch self {
        case .low: return 0
        case .moderate: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

enum WellbeingTrend: String, Codable, Sendable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}
