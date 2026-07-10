import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    var trackActivity: Bool {
        didSet { UserDefaults.standard.set(trackActivity, forKey: "trackActivity") }
    }
    var dailyGoalMinutes: Double {
        didSet { UserDefaults.standard.set(dailyGoalMinutes, forKey: Constants.UserDefaultsKeys.dailyGoalMinutes) }
    }
    var breakInterval: TimeInterval {
        didSet { UserDefaults.standard.set(breakInterval, forKey: Constants.UserDefaultsKeys.breakInterval) }
    }
    var oneThing: String {
        didSet { UserDefaults.standard.set(oneThing, forKey: Constants.UserDefaultsKeys.oneThing) }
    }
    var useAI: Bool {
        didSet { UserDefaults.standard.set(useAI, forKey: Constants.UserDefaultsKeys.useAI) }
    }
    var breathingPreference: String {
        didSet { UserDefaults.standard.set(breathingPreference, forKey: Constants.UserDefaultsKeys.breathingPreference) }
    }
    var moodReminderInterval: TimeInterval {
        didSet { UserDefaults.standard.set(moodReminderInterval, forKey: Constants.UserDefaultsKeys.moodReminderInterval) }
    }
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.trackActivity = defaults.object(forKey: "trackActivity") as? Bool ?? false
        self.dailyGoalMinutes = defaults.object(forKey: Constants.UserDefaultsKeys.dailyGoalMinutes) as? Double ?? Constants.Defaults.dailyGoalMinutes
        self.breakInterval = defaults.object(forKey: Constants.UserDefaultsKeys.breakInterval) as? TimeInterval ?? Constants.Defaults.breakInterval
        self.oneThing = defaults.object(forKey: Constants.UserDefaultsKeys.oneThing) as? String ?? ""
        self.useAI = defaults.object(forKey: Constants.UserDefaultsKeys.useAI) as? Bool ?? true
        self.breathingPreference = defaults.object(forKey: Constants.UserDefaultsKeys.breathingPreference) as? String ?? "box"
        self.moodReminderInterval = defaults.object(forKey: Constants.UserDefaultsKeys.moodReminderInterval) as? TimeInterval ?? Constants.Defaults.moodReminderInterval
        self.hasCompletedOnboarding = defaults.object(forKey: "hasCompletedOnboarding") as? Bool ?? false
    }
}

// MARK: - Environment

struct SettingsStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = SettingsStore.shared
}

extension EnvironmentValues {
    var settings: SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }
}
