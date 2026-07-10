import Foundation

enum Constants {
    static let appName = "CoreMind"
    static let appBundleID = "com.coremind.app"
    static let appVersion = Version.version
    /// GitHub repository for auto-updates (owner/repo)
    static let githubRepo = "aleksandrbashkalov-ai/CoreMind"

    enum UserDefaultsKeys {
        static let useAI = "useAI"
        static let aiProvider = "aiProvider"
        static let oneThing = "oneThing"
        static let dailyGoalMinutes = "dailyGoalMinutes"
        static let breakInterval = "breakInterval"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let breathingPreference = "breathingPreference"
        static let moodReminderInterval = "moodReminderInterval"
    }

    enum Defaults {
        static let dailyGoalMinutes: Double = 120
        static let breakInterval: TimeInterval = 3600
        static let moodReminderInterval: TimeInterval = 7200
        static let pollingInterval: TimeInterval = 2.0
        static let dataRetentionDays: Int = 30
    }
}
