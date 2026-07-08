import Foundation
import AppKit
import EventKit

// MARK: - Database

protocol DatabaseServiceProtocol: AnyObject, Sendable {
    func initialize() throws
    func saveMoodCheckIn(_ checkIn: MoodCheckIn) throws
    func fetchMoodCheckIns(limit: Int) throws -> [MoodCheckIn]
    func saveFocusSession(_ session: FocusSession) throws
    func fetchFocusSessions(limit: Int) throws -> [FocusSession]
    func saveActivityRecord(_ record: ActivityRecord) throws
    func saveActivityRecords(_ records: [ActivityRecord]) throws
    func fetchActivityRecords(since: Date?, limit: Int) throws -> [ActivityRecord]
    func deleteActivityRecords(before date: Date) throws
    func saveCoachingAdvice(_ advice: CoachingAdvice) throws
    func fetchActiveAdvice() throws -> [CoachingAdvice]
    func dismissAdvice(id: String) throws
    func saveJournalEntry(_ entry: JournalEntry) throws
    func fetchJournalEntries(limit: Int) throws -> [JournalEntry]
    func deleteAllData() throws
    func vacuum() throws
}

// MARK: - AI

// MARK: - Creative Break

protocol CreativeBreakServiceProtocol: AnyObject, Sendable {
    func randomPrompt() async -> CreativePrompt
    func prompts(for category: CreativeCategory) async -> [CreativePrompt]
}

// MARK: - AI

protocol AIProviderProtocol: AnyObject, Sendable {
    var isAvailable: Bool { get async }
    func initialize() async
    func smartPrompt(system: String, user: String, preferCloud: Bool) async throws -> String
    func smartStructured<T: Decodable & Sendable>(system: String, user: String, type: T.Type) async throws -> T
}

// MARK: - Activity Tracking

protocol ActivityTrackerProtocol: AnyObject, Sendable {
    var allRecords: [ActivityRecord] { get async }
    func start() async
    func stop() async
    func records(in dateRange: ClosedRange<Date>) async -> [ActivityRecord]
}

protocol WindowMonitorProtocol: AnyObject, Sendable {
    var currentApp: (id: String, name: String) { get async }
    var focusChanges: AsyncStream<(id: String, name: String)> { get }
    var isAccessibilityAuthorized: Bool { get }
    func startMonitoring() async
    func stopMonitoring() async
    func requestAccessibilityPermission()
}

// MARK: - Coaching

protocol CoachingServiceProtocol: AnyObject, Sendable {
    func start() async
    func stop() async
    func generateDailyReport() async -> CoachingReport
    func generateRealtimeAdvice() async -> [CoachingAdvice]
    func getContextualSuggestion() async -> String
    func dismissAdvice(_ id: String) async
    var currentAdvice: [CoachingAdvice] { get async }
}

protocol ProactiveNudgeServiceProtocol: AnyObject, Sendable {
    var currentNudges: [ProactiveNudge] { get async }
    func start() async
    func stop() async
    func dismissNudge(_ id: UUID) async
}

protocol WellnessEngineProtocol: AnyObject, Sendable {
    func analyzeCheckIn(_ checkIn: MoodCheckIn) async -> String
    func suggestAction(for checkIn: MoodCheckIn) -> String
    func generateDailyPrompt() async -> StoicPrompt
    func loadCheckIns() async -> [MoodCheckIn]
    func analyzeWeeklyPattern(checkIns: [MoodCheckIn]) async -> String
    func getContextualSuggestion(currentApp: String, activeMinutes: TimeInterval) async -> String
}

// MARK: - Calendar

protocol CalendarServiceProtocol: AnyObject, Sendable {
    var hasAccess: Bool { get async }
    func requestAccess() async -> Bool
    func currentEvents() async -> [EKEvent]
    func upcomingEvent() async -> EKEvent?
    func currentMeeting() async -> EKEvent?
    func meetingsToday() async -> [EKEvent]
    func meetingHoursToday() async -> TimeInterval
    func scheduleFocusBlock(duration: TimeInterval, title: String?) async -> Bool
    func scheduleBreak(length: TimeInterval) async -> Bool
    func isInMeeting() async -> Bool
}

// MARK: - Permissions

protocol PermissionsManagerProtocol: AnyObject, Sendable {
    func currentState() async -> PermissionState
    func requestAccessibility() async
    func requestNotifications() async -> Bool
}

// MARK: - Store

protocol StoreManagerProtocol: AnyObject, Sendable {
    var currentTier: SubscriptionTier { get async }
    func initialize() async
    func purchase(_ product: ProProduct) async throws
    func restorePurchases() async
    func displayPrice(for product: ProProduct) async -> String?
}
