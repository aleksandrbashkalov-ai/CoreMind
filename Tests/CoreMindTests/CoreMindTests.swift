import XCTest
import GRDB
import EventKit
@testable import CoreMind

final class CoreMindTests: XCTestCase {
    var db: DatabaseService!

    override func setUp() async throws {
        let dbQueue = try DatabaseQueue()
        db = try DatabaseService(dbWriter: dbQueue)
    }

    // MARK: - Mood Check-In Tests

    func testSaveAndFetchMoodCheckIns() throws {
        let checkIn = MoodCheckIn(mood: .good, energy: .high, focus: 8, notes: "Feeling productive")
        try db.saveMoodCheckIn(checkIn)

        let fetched = try db.fetchMoodCheckIns()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].mood, .good)
        XCTAssertEqual(fetched[0].energy, .high)
        XCTAssertEqual(fetched[0].focus, 8)
        XCTAssertEqual(fetched[0].notes, "Feeling productive")
    }

    func testSaveAndFetchMoodCheckInsWithReflection() throws {
        var checkIn = MoodCheckIn(mood: .terrible, energy: .low, focus: 2)
        checkIn.aiReflection = "This feeling is temporary."
        try db.saveMoodCheckIn(checkIn)

        let fetched = try db.fetchMoodCheckIns()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].aiReflection, "This feeling is temporary.")
    }

    func testFetchMoodCheckInsLimit() throws {
        for i in 1...10 {
            let checkIn = MoodCheckIn(mood: .okay, energy: .moderate, focus: i)
            try db.saveMoodCheckIn(checkIn)
        }

        let fetched = try db.fetchMoodCheckIns(limit: 3)
        XCTAssertEqual(fetched.count, 3)
    }

    func testFetchMoodCheckInsEmpty() throws {
        let fetched = try db.fetchMoodCheckIns()
        XCTAssertTrue(fetched.isEmpty)
    }

    func testMoodCheckInRoundTripPreservesIdAndTimestamp() throws {
        let checkIn = MoodCheckIn(mood: .great, energy: .full, focus: 10)
        let originalId = checkIn.id
        let originalTimestamp = checkIn.timestamp
        try db.saveMoodCheckIn(checkIn)

        let fetched = try db.fetchMoodCheckIns(limit: 1)
        XCTAssertEqual(fetched[0].id, originalId)
        XCTAssertEqual(fetched[0].timestamp.timeIntervalSinceReferenceDate, originalTimestamp.timeIntervalSinceReferenceDate, accuracy: 0.1)
    }

    // MARK: - Focus Session Tests

    func testSaveAndFetchFocusSessions() throws {
        let session = FocusSession(
            startTime: Date(),
            duration: 1500,
            type: .pomodoro,
            state: .completed,
            interruptions: 2,
            focusScore: 0.8,
            activitySummary: "Good session"
        )
        try db.saveFocusSession(session)

        let fetched = try db.fetchFocusSessions()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].type, .pomodoro)
        XCTAssertEqual(fetched[0].state, .completed)
        XCTAssertEqual(fetched[0].interruptions, 2)
        XCTAssertEqual(fetched[0].focusScore, 0.8, accuracy: 0.01)
        XCTAssertEqual(fetched[0].activitySummary, "Good session")
    }

    func testSaveAndFetchFocusSessionWithEndTime() throws {
        let start = Date()
        let end = start.addingTimeInterval(1500)
        let session = FocusSession(
            startTime: start,
            endTime: end,
            duration: 1500,
            type: .deepWork,
            state: .completed,
            interruptions: 0,
            focusScore: 0.9
        )
        try db.saveFocusSession(session)

        let fetched = try db.fetchFocusSessions()
        let endTime = try XCTUnwrap(fetched[0].endTime)
        XCTAssertEqual(endTime.timeIntervalSinceReferenceDate, end.timeIntervalSinceReferenceDate, accuracy: 0.1)
    }

    func testFetchFocusSessionsOrderedByStartTime() throws {
        let later = FocusSession(startTime: Date(), duration: 1500, type: .pomodoro, state: .completed, interruptions: 0, focusScore: 1.0)
        try db.saveFocusSession(later)

        let earlier = FocusSession(startTime: Date().addingTimeInterval(-3600), duration: 1500, type: .deepWork, state: .completed, interruptions: 0, focusScore: 1.0)
        try db.saveFocusSession(earlier)

        let fetched = try db.fetchFocusSessions()
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(fetched[0].startTime >= fetched[1].startTime)
    }

    func testFocusSessionEmpty() throws {
        let fetched = try db.fetchFocusSessions()
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: - Activity Record Tests

    func testSaveAndFetchActivityRecords() throws {
        let record = ActivityRecord(
            id: "test-id-1",
            timestamp: Date(),
            activityType: .coding,
            appBundleID: "com.apple.dt.xcode",
            appName: "Xcode",
            windowTitle: "CoreMind.swift",
            duration: 3600,
            confidence: 0.95
        )
        try db.saveActivityRecord(record)

        let fetched = try db.fetchActivityRecords()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].activityType, .coding)
        XCTAssertEqual(fetched[0].appName, "Xcode")
        XCTAssertEqual(fetched[0].windowTitle, "CoreMind.swift")
        XCTAssertEqual(fetched[0].confidence, 0.95, accuracy: 0.01)
    }

    func testSaveMultipleActivityRecords() throws {
        let records = (1...5).map { i in
            ActivityRecord(
                id: "id-\(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i)),
                activityType: .coding,
                appBundleID: "com.test.app",
                appName: "TestApp",
                duration: Double(i * 100),
                confidence: 0.8
            )
        }
        try db.saveActivityRecords(records)

        let fetched = try db.fetchActivityRecords(limit: 10)
        XCTAssertEqual(fetched.count, 5)
    }

    func testSaveActivityRecordsReplaceOnConflict() throws {
        let record = ActivityRecord(
            id: "dup-id",
            timestamp: Date(),
            activityType: .coding,
            appBundleID: "com.apple.dt.xcode",
            appName: "Xcode",
            duration: 100,
            confidence: 0.8
        )
        try db.saveActivityRecord(record)

        let updated = ActivityRecord(
            id: "dup-id",
            timestamp: Date(),
            activityType: .meeting,
            appBundleID: "com.zoom.us",
            appName: "Zoom",
            duration: 200,
            confidence: 0.9
        )
        try db.saveActivityRecords([updated])

        let fetched = try db.fetchActivityRecords()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].activityType, .meeting)
    }

    func testFetchActivityRecordsSince() throws {
        let old = ActivityRecord(
            id: "old", timestamp: Date().addingTimeInterval(-86400),
            activityType: .other, appBundleID: "", appName: "", duration: 0, confidence: 0
        )
        let recent = ActivityRecord(
            id: "recent", timestamp: Date(),
            activityType: .other, appBundleID: "", appName: "", duration: 0, confidence: 0
        )
        try db.saveActivityRecords([old, recent])

        let since = Date().addingTimeInterval(-3600)
        let fetched = try db.fetchActivityRecords(since: since)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, "recent")
    }

    func testDeleteActivityRecordsBefore() throws {
        let old = ActivityRecord(
            id: "old", timestamp: Date().addingTimeInterval(-86400 * 2),
            activityType: .other, appBundleID: "", appName: "", duration: 0, confidence: 0
        )
        let recent = ActivityRecord(
            id: "recent", timestamp: Date(),
            activityType: .other, appBundleID: "", appName: "", duration: 0, confidence: 0
        )
        try db.saveActivityRecords([old, recent])

        let cutoff = Date().addingTimeInterval(-86400)
        try db.deleteActivityRecords(before: cutoff)

        let fetched = try db.fetchActivityRecords()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, "recent")
    }

    // MARK: - Coaching Advice Tests

    func testSaveAndFetchActiveAdvice() throws {
        let advice = CoachingAdvice(
            type: .focus,
            title: "Deep Work Deficit",
            description: "Try a 25-minute focus session",
            priority: .high,
            actionItem: "Start now"
        )
        try db.saveCoachingAdvice(advice)

        let fetched = try db.fetchActiveAdvice()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Deep Work Deficit")
        XCTAssertEqual(fetched[0].priority, .high)
        XCTAssertEqual(fetched[0].actionItem, "Start now")
    }

    func testFetchActiveAdviceExcludesDismissed() throws {
        let active = CoachingAdvice(type: .focus, title: "Active", description: "", priority: .medium)
        try db.saveCoachingAdvice(active)

        var dismissed = CoachingAdvice(type: .wellbeing, title: "Dismissed", description: "", priority: .low)
        dismissed.isDismissed = true
        try db.saveCoachingAdvice(dismissed)

        let fetched = try db.fetchActiveAdvice()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Active")
    }

    func testDismissAdvice() throws {
        let advice = CoachingAdvice(type: .productivity, title: "Test", description: "", priority: .medium)
        try db.saveCoachingAdvice(advice)

        try db.dismissAdvice(id: advice.id)

        let fetched = try db.fetchActiveAdvice()
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: - Journal Entry Tests

    func testSaveAndFetchJournalEntries() throws {
        let entry = JournalEntry(prompt: "Morning Reflection", content: "Feeling great today", title: "Good Morning", tags: ["morning", "grateful"])
        try db.saveJournalEntry(entry)

        let fetched = try db.fetchJournalEntries()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Good Morning")
        XCTAssertEqual(fetched[0].tags, ["morning", "grateful"])
    }

    func testJournalEntryWithAISummary() throws {
        var entry = JournalEntry(prompt: "Stoic", content: "Reflection text", title: "Stoic Thought")
        entry.aiSummary = "A deep insight about resilience."
        try db.saveJournalEntry(entry)

        let fetched = try db.fetchJournalEntries()
        XCTAssertEqual(fetched[0].aiSummary, "A deep insight about resilience.")
    }

    func testJournalEntryIsFavorite() throws {
        var entry = JournalEntry(prompt: "Test", content: "Content", title: "Title")
        entry.isFavorite = true
        try db.saveJournalEntry(entry)

        let fetched = try db.fetchJournalEntries()
        XCTAssertTrue(fetched[0].isFavorite)
    }

    func testJournalEntryEmptyTags() throws {
        let entry = JournalEntry(prompt: "Test", content: "Content", title: "Title", tags: [])
        try db.saveJournalEntry(entry)

        let fetched = try db.fetchJournalEntries()
        XCTAssertTrue(fetched[0].tags.isEmpty)
    }

    func testJournalEntryUpdateRoundTrip() throws {
        var entry = JournalEntry(prompt: "Morning", content: "First draft", title: "Draft")
        try db.saveJournalEntry(entry)

        // Update — same ID, new values (simulates toggleFavorite / generateAISummary)
        entry.isFavorite = true
        entry.aiSummary = "Deep insight"
        entry.content = "Revised content"
        try db.saveJournalEntry(entry)  // must not throw on duplicate PK

        let fetched = try db.fetchJournalEntries()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, entry.id)
        XCTAssertTrue(fetched[0].isFavorite)
        XCTAssertEqual(fetched[0].aiSummary, "Deep insight")
        XCTAssertEqual(fetched[0].content, "Revised content")
    }

    func testFocusSessionUpdateStateRoundTrip() throws {
        var session = FocusSession(
            startTime: Date(),
            duration: 1500,
            type: .pomodoro,
            state: .focusing,
            interruptions: 0,
            focusScore: 0
        )
        try db.saveFocusSession(session)

        // Simulate completing the session — same id, updated state
        session.state = .completed
        session.endTime = Date().addingTimeInterval(1500)
        session.interruptions = 1
        session.focusScore = 0.85
        try db.saveFocusSession(session)

        let fetched = try db.fetchFocusSessions()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, session.id)
        XCTAssertEqual(fetched[0].state, .completed)
        XCTAssertEqual(fetched[0].interruptions, 1)
        XCTAssertEqual(fetched[0].focusScore, 0.85, accuracy: 0.01)
    }

    func testFocusSessionInterruptedRoundTrip() throws {
        var session = FocusSession(
            startTime: Date(),
            duration: 3600,
            type: .deepWork,
            state: .focusing,
            interruptions: 0,
            focusScore: 0
        )
        try db.saveFocusSession(session)

        // Mark as interrupted
        session.state = .interrupted
        session.interruptions = 3
        session.endTime = Date().addingTimeInterval(1200)
        try db.saveFocusSession(session)

        let fetched = try db.fetchFocusSessions()
        XCTAssertEqual(fetched[0].state, .interrupted)
        XCTAssertEqual(fetched[0].interruptions, 3)
    }

    func testMoodCheckInUpdateReflectionRoundTrip() throws {
        var checkIn = MoodCheckIn(mood: .okay, energy: .moderate, focus: 5, notes: "Initial")
        let originalId = checkIn.id
        try db.saveMoodCheckIn(checkIn)

        // Update with AI reflection — same id
        checkIn.aiReflection = "A thoughtful reflection."
        checkIn.notes = "Updated notes"
        try db.saveMoodCheckIn(checkIn)

        let fetched = try db.fetchMoodCheckIns(limit: 1)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, originalId)
        XCTAssertEqual(fetched[0].aiReflection, "A thoughtful reflection.")
        XCTAssertEqual(fetched[0].notes, "Updated notes")
    }

    func testFocusSessionWithNoteAndSummaryRoundTrip() throws {
        var session = FocusSession(
            startTime: Date(),
            duration: 1800,
            type: .adaptive,
            state: .completed,
            interruptions: 2,
            focusScore: 0.75
        )
        session.note = "Felt productive"
        session.activitySummary = "Deep work on project X"
        try db.saveFocusSession(session)

        let fetched = try db.fetchFocusSessions()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].note, "Felt productive")
        XCTAssertEqual(fetched[0].activitySummary, "Deep work on project X")
    }

    func testMultipleCheckInsOrderedByTimestamp() throws {
        var earlier = MoodCheckIn(mood: .bad, energy: .low, focus: 2, notes: "Morning")
        earlier.timestamp = Date().addingTimeInterval(-3600) // 1 hour ago
        try db.saveMoodCheckIn(earlier)

        var later = MoodCheckIn(mood: .good, energy: .high, focus: 8, notes: "Afternoon")
        later.timestamp = Date() // now
        try db.saveMoodCheckIn(later)

        let fetched = try db.fetchMoodCheckIns()
        XCTAssertEqual(fetched.count, 2)
        // Most recent first (ORDER BY timestamp DESC)
        XCTAssertEqual(fetched[0].mood, Mood.good)
        XCTAssertEqual(fetched[1].mood, Mood.bad)
    }

    // MARK: - Vacuum

    func testVacuum() throws {
        let entry = JournalEntry(prompt: "Test", content: "Content", title: "Title")
        try db.saveJournalEntry(entry)
        XCTAssertNoThrow(try db.vacuum())
    }

    // MARK: - Model Tests (existing)

    func testMoodScore() {
        XCTAssertEqual(Mood.terrible.score, 1)
        XCTAssertEqual(Mood.bad.score, 2)
        XCTAssertEqual(Mood.okay.score, 3)
        XCTAssertEqual(Mood.good.score, 4)
        XCTAssertEqual(Mood.great.score, 5)
    }

    func testMoodEmoji() {
        XCTAssertEqual(Mood.terrible.emoji, "😫")
        XCTAssertEqual(Mood.great.emoji, "😌")
    }

    func testEnergyScore() {
        XCTAssertEqual(EnergyLevel.exhausted.score, 1)
        XCTAssertEqual(EnergyLevel.full.score, 5)
    }

    func testFocusSessionDefaultDurations() {
        XCTAssertEqual(FocusSessionType.pomodoro.defaultDuration, 1500)
        XCTAssertEqual(FocusSessionType.deepWork.defaultDuration, 3600)
        XCTAssertEqual(FocusSessionType.pomodoro.breakDuration, 300)
        XCTAssertEqual(FocusSessionType.deepWork.breakDuration, 600)
    }

    func testAdvicePriorityScore() {
        XCTAssertEqual(AdvicePriority.critical.score, 4)
        XCTAssertEqual(AdvicePriority.high.score, 3)
        XCTAssertEqual(AdvicePriority.medium.score, 2)
        XCTAssertEqual(AdvicePriority.low.score, 1)
    }

    func testBoxBreathing() {
        let exercise = BreathingExercise.boxBreathing
        XCTAssertEqual(exercise.name, "Box Breathing")
        XCTAssertEqual(exercise.inhale, 4)
        XCTAssertEqual(exercise.hold, 4)
        XCTAssertEqual(exercise.exhale, 4)
        XCTAssertEqual(exercise.holdAfterExhale, 4)
        XCTAssertEqual(exercise.cycles, 8)
    }

    func testAllBreathingExercises() {
        XCTAssertEqual(BreathingExercise.all.count, 4)
    }

    func testBurnoutRiskScore() {
        XCTAssertEqual(BurnoutRiskLevel.low.score, 0)
        XCTAssertEqual(BurnoutRiskLevel.moderate.score, 1)
        XCTAssertEqual(BurnoutRiskLevel.high.score, 2)
        XCTAssertEqual(BurnoutRiskLevel.critical.score, 3)
    }

    func testSubscriptionTierAllFeatures() {
        let free = SubscriptionTier.free
        XCTAssertFalse(free.allowsUnlimitedJournaling)
        XCTAssertFalse(free.allowsDeepAnalysis)
        XCTAssertFalse(free.allowsWeeklyReports)
        XCTAssertFalse(free.allowsImagePlayground)
        XCTAssertFalse(free.allowsFocusModes)
        XCTAssertFalse(free.allowsCalendarIntegration)

        let pro = SubscriptionTier.pro
        XCTAssertTrue(pro.allowsUnlimitedJournaling)
        XCTAssertTrue(pro.allowsDeepAnalysis)
        XCTAssertTrue(pro.allowsWeeklyReports)
        XCTAssertTrue(pro.allowsImagePlayground)
        XCTAssertTrue(pro.allowsFocusModes)
        XCTAssertTrue(pro.allowsCalendarIntegration)
    }

    func testProProductLabels() {
        XCTAssertEqual(ProProduct.monthly.label, "Monthly")
        XCTAssertEqual(ProProduct.yearly.label, "Yearly")
        XCTAssertEqual(ProProduct.lifetime.label, "Lifetime")
    }

    func testProProductDisplayPrice() {
        XCTAssertNotNil(ProProduct.monthly.displayPrice)
        XCTAssertNotNil(ProProduct.yearly.displayPrice)
        XCTAssertNotNil(ProProduct.lifetime.displayPrice)
    }

    func testProProductAllCases() {
        XCTAssertEqual(ProProduct.allCases.count, 3)
    }

    func testProProductSavingsNote() {
        XCTAssertNil(ProProduct.monthly.savingsNote)
        XCTAssertEqual(ProProduct.yearly.savingsNote, "Save 30% vs monthly")
        XCTAssertEqual(ProProduct.lifetime.savingsNote, "One-time payment")
    }

    // MARK: - StoreManager Logic Tests

    func testStoreManagerCurrentTierFreeByDefault() async {
        let store = StoreManager()
        let tier = await store.currentTier
        XCTAssertEqual(tier, .free)
    }

    func testStoreManagerCurrentTierProWithMonthly() async {
        let store = StoreManager()
        await store.testing_setPurchased(id: ProProduct.monthly.rawValue)
        let tier = await store.currentTier
        XCTAssertEqual(tier, .pro)
    }

    func testStoreManagerCurrentTierProWithYearly() async {
        let store = StoreManager()
        await store.testing_setPurchased(id: ProProduct.yearly.rawValue)
        let tier = await store.currentTier
        XCTAssertEqual(tier, .pro)
    }

    func testStoreManagerCurrentTierProWithLifetime() async {
        let store = StoreManager()
        await store.testing_setPurchased(id: ProProduct.lifetime.rawValue)
        let tier = await store.currentTier
        XCTAssertEqual(tier, .pro)
    }

    func testStoreManagerCurrentTierProWithAllProducts() async {
        let store = StoreManager()
        await store.testing_setPurchased(id: ProProduct.monthly.rawValue)
        await store.testing_setPurchased(id: ProProduct.yearly.rawValue)
        await store.testing_setPurchased(id: ProProduct.lifetime.rawValue)
        let tier = await store.currentTier
        XCTAssertEqual(tier, .pro)
    }

    func testStoreManagerCurrentTierFreeWithUnknownID() async {
        let store = StoreManager()
        await store.testing_setPurchased(id: "com.coremind.unknown")
        let tier = await store.currentTier
        XCTAssertEqual(tier, .free)
    }

    func testStoreManagerCurrentTierFreeAfterRemovingProduct() async {
        let store = StoreManager()
        await store.testing_setPurchased(id: ProProduct.monthly.rawValue)
        var tier = await store.currentTier
        XCTAssertEqual(tier, .pro)

        await store.testing_removePurchased(id: ProProduct.monthly.rawValue)
        tier = await store.currentTier
        XCTAssertEqual(tier, .free)
    }

    func testNudgeTypePriority() {
        XCTAssertEqual(NudgeType.burnout.priorityScore, 10)
        XCTAssertEqual(NudgeType.streak.priorityScore, 2)
        XCTAssertTrue(NudgeType.burnout.priorityScore > NudgeType.streak.priorityScore)
    }

    func testNudgeTypeIcon() {
        XCTAssertEqual(NudgeType.breathing.icon, "wind")
        XCTAssertEqual(NudgeType.burnout.icon, "exclamationmark.triangle")
    }

    func testStoicPromptInit() {
        let prompt = StoicPrompt(
            date: Date(),
            text: "The happiness of your life depends upon the quality of your thoughts.",
            author: "Marcus Aurelius",
            reflection: "A powerful reminder.",
            followUp: "What thoughts will you cultivate?"
        )
        XCTAssertEqual(prompt.author, "Marcus Aurelius")
        XCTAssertEqual(prompt.reflection, "A powerful reminder.")
    }

    func testPromptTypeAllCases() {
        XCTAssertEqual(PromptType.allCases.count, 6)
    }

    func testFocusStateAllCases() {
        XCTAssertEqual(FocusState.idle.rawValue, "idle")
        XCTAssertEqual(FocusState.focusing.rawValue, "focusing")
        XCTAssertEqual(FocusState.break_.rawValue, "break_")
        XCTAssertEqual(FocusState.completed.rawValue, "completed")
        XCTAssertEqual(FocusState.interrupted.rawValue, "interrupted")
    }

    func testActivityTypeAllCasesCount() {
        XCTAssertEqual(ActivityType.allCases.count, 9)
    }

    func testActivityTypeRawValues() {
        XCTAssertEqual(ActivityType.reading.rawValue, "Reading")
        XCTAssertEqual(ActivityType.coding.rawValue, "Coding")
        XCTAssertEqual(ActivityType.meeting.rawValue, "Meeting")
        XCTAssertEqual(ActivityType.browsing.rawValue, "Browsing")
        XCTAssertEqual(ActivityType.email.rawValue, "Email")
        XCTAssertEqual(ActivityType.media.rawValue, "Media")
    }

    func testFocusSessionTypesCount() {
        XCTAssertEqual(FocusSessionType.allCases.count, 4)
    }

    func testFocusSessionCustomDefaultDuration() {
        XCTAssertEqual(FocusSessionType.custom.defaultDuration, 1800)
        XCTAssertEqual(FocusSessionType.custom.breakDuration, 300)
    }

    func testFocusSessionAdaptiveDefaultDuration() {
        XCTAssertEqual(FocusSessionType.adaptive.defaultDuration, 1500)
        XCTAssertEqual(FocusSessionType.adaptive.breakDuration, 300)
    }

    func testFocusMetricsInit() {
        let metrics = FocusMetrics(
            totalFocusToday: 7200,
            sessionsCompleted: 3,
            averageSessionLength: 2400,
            bestFocusHour: 10,
            distractionTime: 600,
            focusScore: 0.85
        )
        XCTAssertEqual(metrics.totalFocusToday, 7200)
        XCTAssertEqual(metrics.sessionsCompleted, 3)
        XCTAssertEqual(metrics.averageSessionLength, 2400)
        XCTAssertEqual(metrics.bestFocusHour, 10)
        XCTAssertEqual(metrics.distractionTime, 600)
        XCTAssertEqual(metrics.focusScore, 0.85)
    }

    func testDeepWorkSessionInit() {
        let now = Date()
        let session = DeepWorkSession(
            startTime: now,
            endTime: now.addingTimeInterval(3600),
            duration: 3600,
            activityType: .coding,
            appName: "Xcode",
            interruptions: 2,
            focusScore: 0.9
        )
        XCTAssertEqual(session.duration, 3600)
        XCTAssertEqual(session.activityType, .coding)
        XCTAssertEqual(session.appName, "Xcode")
        XCTAssertEqual(session.interruptions, 2)
        XCTAssertEqual(session.focusScore, 0.9)
    }

    func testDeepWorkSessionDefaultEndTime() {
        let session = DeepWorkSession(
            startTime: Date(), duration: 1800,
            activityType: .writing, interruptions: 0, focusScore: 0.7
        )
        XCTAssertNil(session.endTime)
        XCTAssertNil(session.appName)
    }

    func testBurnoutSignalsCriticalRisk() {
        let signals = BurnoutSignals(
            overtimeHoursToday: 4,
            nightWorkHoursThisWeek: 16,
            weekendWorkHoursThisWeek: 12,
            meetingOverloadRatio: 0.8,
            contextSwitchesPerHour: 15,
            averageWorkdayDuration: 14 * 3600,
            daysWorkedThisWeek: 7,
            riskLevel: .critical,
            wellbeingScore: 0.25,
            wellbeingTrend: .declining
        )
        XCTAssertEqual(signals.riskLevel, .critical)
        XCTAssertEqual(signals.wellbeingScore, 0.25, accuracy: 0.01)
        XCTAssertEqual(signals.wellbeingTrend, .declining)
        XCTAssertEqual(signals.contextSwitchesPerHour, 15)
    }

    func testBurnoutSignalsHighRisk() {
        let signals = BurnoutSignals(
            overtimeHoursToday: 2,
            nightWorkHoursThisWeek: 8,
            weekendWorkHoursThisWeek: 4,
            meetingOverloadRatio: 0.5,
            contextSwitchesPerHour: 8,
            averageWorkdayDuration: 10 * 3600,
            daysWorkedThisWeek: 6,
            riskLevel: .high,
            wellbeingScore: 0.5,
            wellbeingTrend: .declining
        )
        XCTAssertEqual(signals.riskLevel, .high)
        XCTAssertEqual(signals.wellbeingTrend, .declining)
    }

    func testBurnoutSignalsLowRisk() {
        let signals = BurnoutSignals(
            overtimeHoursToday: 0,
            nightWorkHoursThisWeek: 0,
            weekendWorkHoursThisWeek: 0,
            meetingOverloadRatio: 0.1,
            contextSwitchesPerHour: 2,
            averageWorkdayDuration: 8 * 3600,
            daysWorkedThisWeek: 5,
            riskLevel: .low,
            wellbeingScore: 0.9,
            wellbeingTrend: .improving
        )
        XCTAssertEqual(signals.riskLevel, .low)
        XCTAssertEqual(signals.wellbeingScore, 0.9, accuracy: 0.01)
        XCTAssertEqual(signals.wellbeingTrend, .improving)
        XCTAssertEqual(signals.daysWorkedThisWeek, 5)
    }

    func testWellbeingTrendAllCases() {
        XCTAssertEqual(WellbeingTrend.improving.rawValue, "Improving")
        XCTAssertEqual(WellbeingTrend.stable.rawValue, "Stable")
        XCTAssertEqual(WellbeingTrend.declining.rawValue, "Declining")
    }

    func testCoachingReportTypeInit() {
        let daily = CoachingReport(date: Date(), type: .daily, summary: "Good day", topAdvice: [], aiGenerated: false)
        XCTAssertEqual(daily.type, CoachingReportType.daily)
        XCTAssertFalse(daily.aiGenerated)

        let weekly = CoachingReport(date: Date(), type: .weekly, summary: "Weekly summary", topAdvice: [], aiGenerated: true)
        XCTAssertEqual(weekly.type, CoachingReportType.weekly)
        XCTAssertTrue(weekly.aiGenerated)
    }

    func testCoachingReportTypes() {
        XCTAssertEqual(CoachingReportType.daily.rawValue, "Daily")
        XCTAssertEqual(CoachingReportType.weekly.rawValue, "Weekly")
        XCTAssertEqual(CoachingReportType.realtime.rawValue, "Realtime")
    }

    // MARK: - Service Tests with Mocks

    func testCoachingServiceGenerateDailyReport() async {
        let mockDB = MockDatabaseService()
        let mockTracker = MockActivityTracker()
        let mockWellness = MockWellnessEngine()
        let mockWindow = MockWindowMonitor()

        let service = CoachingService(
            wellness: mockWellness,
            database: mockDB,
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )

        let report = await service.generateDailyReport()
        XCTAssertEqual(report.type, .daily)
        XCTAssertTrue(report.aiGenerated)
        XCTAssertFalse(report.summary.isEmpty)
    }

    func testCoachingServiceCurrentAdvice() async {
        let mockDB = MockDatabaseService()
        let mockTracker = MockActivityTracker()
        let mockWellness = MockWellnessEngine()
        let mockWindow = MockWindowMonitor()

        let service = CoachingService(
            wellness: mockWellness,
            database: mockDB,
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )

        let advice = await service.currentAdvice
        XCTAssertTrue(advice.isEmpty)
    }

    func testCoachingServiceDismissAdvice() async {
        let mockDB = MockDatabaseService()
        let mockTracker = MockActivityTracker()
        let mockWellness = MockWellnessEngine()
        let mockWindow = MockWindowMonitor()

        let service = CoachingService(
            wellness: mockWellness,
            database: mockDB,
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )

        await service.dismissAdvice("nonexistent")
        let advice = await service.currentAdvice
        XCTAssertTrue(advice.isEmpty)
    }

    // MARK: - ActivityTracker classifyActivity Tests

    func testActivityTrackerClassifyCoding() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let types: [(String, String)] = [
            ("com.apple.dt.xcode", "Xcode"),
            ("com.microsoft.vscode", "Visual Studio Code"),
            ("com.apple.Terminal", "Terminal"),
        ]
        for (id, name) in types {
            let result = await tracker.classifyActivity(appID: id, appName: name)
            XCTAssertEqual(result, .coding, "Expected .coding for \(name), got \(result)")
        }
    }

    func testActivityTrackerClassifyBrowsing() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let types: [(String, String)] = [
            ("com.apple.Safari", "Safari"),
            ("com.google.Chrome", "Chrome"),
            ("org.mozilla.firefox", "Firefox"),
            ("company.thebrowser.BrowserArc", "Arc"),
            ("com.microsoft.edgemac", "Edge"),
        ]
        for (id, name) in types {
            let result = await tracker.classifyActivity(appID: id, appName: name)
            XCTAssertEqual(result, .browsing, "Expected .browsing for \(name), got \(result)")
        }
    }

    func testActivityTrackerClassifyDesign() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let types: [(String, String)] = [
            ("com.figma.Desktop", "Figma"),
            ("com.adobe.Photoshop", "Photoshop"),
            ("com.bohemiancoding.sketch3", "Sketch"),
            ("com.adobe.Illustrator", "Illustrator"),
            ("com.seriflabs.affinitydesigner2", "Affinity Designer"),
        ]
        for (id, name) in types {
            let result = await tracker.classifyActivity(appID: id, appName: name)
            XCTAssertEqual(result, .design, "Expected .design for \(name), got \(result)")
        }
    }

    func testActivityTrackerClassifyEmail() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let types: [(String, String)] = [
            ("com.apple.mail", "Mail"),
            ("com.microsoft.Outlook", "Outlook"),
            ("com.readdle.smartemail", "Spark"),
            ("com.superhuman.mail", "Superhuman"),
        ]
        for (id, name) in types {
            let result = await tracker.classifyActivity(appID: id, appName: name)
            XCTAssertEqual(result, .email, "Expected .email for \(name), got \(result)")
        }
    }

    func testActivityTrackerClassifyMeeting() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let types: [(String, String)] = [
            ("zoom.us", "zoom.us"),
            ("com.microsoft.teams2", "Microsoft Teams"),
            ("com.apple.facetime", "FaceTime"),
            ("com.cisco.webex", "Webex"),
            ("com.tinyspeck.slackmacos", "Slack"),
        ]
        for (id, name) in types {
            let result = await tracker.classifyActivity(appID: id, appName: name)
            XCTAssertEqual(result, .meeting, "Expected .meeting for \(name), got \(result)")
        }
    }

    func testActivityTrackerClassifyMedia() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let types: [(String, String)] = [
            ("com.spotify.client", "Spotify"),
            ("com.apple.music", "Music"),
        ]
        for (id, name) in types {
            let result = await tracker.classifyActivity(appID: id, appName: name)
            XCTAssertEqual(result, .media, "Expected .media for \(name), got \(result)")
        }
    }

    func testActivityTrackerClassifyWriting() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let types: [(String, String)] = [
            ("com.apple.Notes", "Notes"),
            ("com.apple.iWork.Pages", "Pages"),
            ("com.microsoft.Word", "Microsoft Word"),
            ("md.obsidian", "Obsidian"),
            ("com.notion.notion", "Notion"),
            ("com.shinyfrog.bear", "Bear"),
        ]
        for (id, name) in types {
            let result = await tracker.classifyActivity(appID: id, appName: name)
            XCTAssertEqual(result, .writing, "Expected .writing for \(name), got \(result)")
        }
    }

    func testActivityTrackerClassifyOther() async {
        let tracker = ActivityTracker(database: MockDatabaseService())
        let result = await tracker.classifyActivity(appID: "com.apple.finder", appName: "Finder")
        XCTAssertEqual(result, .other)
    }

    // MARK: - ProactiveNudgeService Tests

    func testProactiveNudgeCanNudgeInitial() async {
        let mockTracker = MockActivityTracker()
        let mockWindow = MockWindowMonitor()
        let service = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )
        let canNudge = await service.canNudge(.breakReminder)
        XCTAssertTrue(canNudge, "First nudge of a type should always be allowed")
    }

    func testProactiveNudgeCategorizeCodeApp() async {
        let mockTracker = MockActivityTracker()
        let mockWindow = MockWindowMonitor()
        let service = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )
        let result = await service.categorizeApp("Xcode")
        XCTAssertEqual(result, .code)
    }

    func testProactiveNudgeCategorizeCreativeApp() async {
        let mockTracker = MockActivityTracker()
        let mockWindow = MockWindowMonitor()
        let service = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )
        let result = await service.categorizeApp("Figma")
        XCTAssertEqual(result, .creative)
    }

    func testProactiveNudgeCategorizeMeetingApp() async {
        let mockTracker = MockActivityTracker()
        let mockWindow = MockWindowMonitor()
        let service = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )
        let result = await service.categorizeApp("Zoom")
        XCTAssertEqual(result, .meeting)
    }

    func testProactiveNudgeCategorizeBrowsingApp() async {
        let mockTracker = MockActivityTracker()
        let mockWindow = MockWindowMonitor()
        let service = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )
        let result = await service.categorizeApp("Safari")
        XCTAssertEqual(result, .browsing)
    }

    func testProactiveNudgeCategorizeOtherApp() async {
        let mockTracker = MockActivityTracker()
        let mockWindow = MockWindowMonitor()
        let service = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )
        let result = await service.categorizeApp("Finder")
        XCTAssertEqual(result, .other)
    }

    func testProactiveNudgeDismiss() async {
        let mockTracker = MockActivityTracker()
        let mockWindow = MockWindowMonitor()
        let service = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )

        let nudges = await service.currentNudges
        XCTAssertTrue(nudges.isEmpty)

        let id = UUID()
        await service.dismissNudge(id)
        let after = await service.currentNudges
        XCTAssertTrue(after.isEmpty)
    }

    @MainActor
    func testAppDependenciesInit() async {
        let mockDB = MockDatabaseService()
        let mockTracker = MockActivityTracker()
        let mockWellness = MockWellnessEngine()
        let mockWindow = MockWindowMonitor()
        let mockCalendar = MockCalendarService()
        let mockPermissions = MockPermissionsManager()
        let mockStore = MockStoreManager()
        let mockAI = MockAIProvider()

        let coachingService = CoachingService(
            wellness: mockWellness,
            database: mockDB,
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )
        let nudgeService = ProactiveNudgeService(
            activityTracker: mockTracker,
            windowMonitor: mockWindow
        )

        let mockCreative = MockCreativeBreakService()
        let deps = AppDependencies(
            database: mockDB,
            windowMonitor: mockWindow,
            activityTracker: mockTracker,
            coachingService: coachingService,
            proactiveNudgeService: nudgeService,
            wellnessEngine: mockWellness,
            calendarService: mockCalendar,
            permissionsManager: mockPermissions,
            storeManager: mockStore,
            creativeBreakService: mockCreative,
            aiOrchestrator: mockAI
        )

        await deps.initialize()
        XCTAssertTrue(true, "AppDependencies initialized without error")
    }

    @MainActor
    func testAppDependenciesConvenienceInit() async {
        let deps = AppDependencies()
        await deps.initialize()
        let tier = await deps.storeManager.currentTier
        XCTAssertEqual(tier, .free)
    }

    // MARK: - WellnessEngine Tests

    func testWellnessEngineAnalyzeCheckInUsesAI() async {
        let mockAI = MockAIProvider()
        mockAI.mockResponse = "You're doing great."
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let checkIn = MoodCheckIn(mood: .good, energy: .high, focus: 8, notes: "Good day")
        let result = await engine.analyzeCheckIn(checkIn)
        XCTAssertEqual(result, "You're doing great.")
    }

    func testWellnessEngineAnalyzeCheckInFallback() async {
        let mockAI = FailingAIProvider()
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let checkIn = MoodCheckIn(mood: .terrible, energy: .low, focus: 2)
        let result = await engine.analyzeCheckIn(checkIn)
        XCTAssertEqual(result, "This feeling is valid. Be gentle with yourself today. Sometimes the bravest thing you can do is rest.")
    }

    func testWellnessEngineLoadCheckInsFromDB() async {
        let mockDB = MockDatabaseService()
        let engine = WellnessEngine(ai: MockAIProvider(), database: mockDB)
        let checkIns = await engine.loadCheckIns()
        XCTAssertTrue(checkIns.isEmpty)
    }

    func testWellnessEngineContextualSuggestion() async {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        let result = await engine.getContextualSuggestion(currentApp: "Xcode", activeMinutes: 30)
        XCTAssertTrue(result.contains("focus"))
    }

    func testWellnessEngineContextualSuggestionBreak() async {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        let result = await engine.getContextualSuggestion(currentApp: "Finder", activeMinutes: 7500)
        XCTAssertTrue(result.contains("break"))
    }

    func testWellnessEngineAnalyzeWeeklyPatternEmpty() async {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        let result = await engine.analyzeWeeklyPattern(checkIns: [])
        XCTAssertEqual(result, "Not enough data yet. Keep checking in daily.")
    }

    func testWellnessEngineGenerateDailyPromptFallback() async {
        let mockAI = FailingAIProvider()
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let prompt = await engine.generateDailyPrompt()
        XCTAssertFalse(prompt.text.isEmpty)
        XCTAssertFalse(prompt.author.isEmpty)
    }

    func testWellnessEngineGenerateDailyPromptSuccess() async {
        let mockAI = MockAIProvider()
        mockAI.mockResponse = "What seeds will you plant today?\n— Marcus Aurelius"
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let prompt = await engine.generateDailyPrompt()
        XCTAssertEqual(prompt.text, "What seeds will you plant today?")
        XCTAssertEqual(prompt.author, "Marcus Aurelius")
    }

    func testWellnessEngineAnalyzeCheckInFallbackGoodMood() async {
        let mockAI = FailingAIProvider()
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let checkIn = MoodCheckIn(mood: .great, energy: .high, focus: 9)
        let result = await engine.analyzeCheckIn(checkIn)
        XCTAssertEqual(result, "Savor this moment. Notice what's working and carry it forward.")
    }

    func testWellnessEngineAnalyzeCheckInFallbackNeutralMood() async {
        let mockAI = FailingAIProvider()
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let checkIn = MoodCheckIn(mood: .okay, energy: .low, focus: 5)
        let result = await engine.analyzeCheckIn(checkIn)
        XCTAssertEqual(result, "You are exactly where you need to be. Breathe, and take the next small step.")
    }

    func testWellnessEngineContextualSuggestionFigma() async {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        let result = await engine.getContextualSuggestion(currentApp: "Figma", activeMinutes: 45)
        XCTAssertTrue(result.contains("Creative") || result.contains("bigger picture"))
    }

    func testWellnessEngineContextualSuggestionDefault() async {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        let result = await engine.getContextualSuggestion(currentApp: "Calendar", activeMinutes: 10)
        XCTAssertEqual(result, "Stay present. You are exactly where you need to be.")
    }

    func testWellnessEngineAnalyzeWeeklyPatternWithData() async {
        let mockAI = MockAIProvider()
        mockAI.mockResponse = "Your energy is stable this week."
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let checkIns = [
            MoodCheckIn(mood: .good, energy: .high, focus: 8),
            MoodCheckIn(mood: .good, energy: .low, focus: 7),
            MoodCheckIn(mood: .okay, energy: .low, focus: 6),
        ]
        let result = await engine.analyzeWeeklyPattern(checkIns: checkIns)
        XCTAssertEqual(result, "Your energy is stable this week.")
    }

    func testWellnessEngineAnalyzeWeeklyPatternFallbackLowMood() async {
        let mockAI = FailingAIProvider()
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let checkIns = [
            MoodCheckIn(mood: .bad, energy: .low, focus: 2),
            MoodCheckIn(mood: .terrible, energy: .low, focus: 1),
            MoodCheckIn(mood: .bad, energy: .low, focus: 3),
        ]
        let result = await engine.analyzeWeeklyPattern(checkIns: checkIns)
        XCTAssertTrue(result.contains("low"))
    }

    func testWellnessEngineAnalyzeWeeklyPatternFallbackHighMood() async {
        let mockAI = FailingAIProvider()
        let engine = WellnessEngine(ai: mockAI, database: MockDatabaseService())
        let checkIns = [
            MoodCheckIn(mood: .great, energy: .high, focus: 10),
            MoodCheckIn(mood: .great, energy: .high, focus: 9),
        ]
        let result = await engine.analyzeWeeklyPattern(checkIns: checkIns)
        XCTAssertTrue(result.contains("thriving"))
    }

    // MARK: - WellnessEngine suggestAction Tests

    func testSuggestActionTerribleMood() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        for energy in [EnergyLevel.exhausted, .low, .moderate, .high, .full] {
            let checkIn = MoodCheckIn(mood: .terrible, energy: energy, focus: 1)
            let action = engine.suggestAction(for: checkIn)
            XCTAssertEqual(action, "Try a 2-minute breathing exercise", "Failed for energy: \(energy)")
        }
    }

    func testSuggestActionBadWithLowEnergy() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        for energy in [EnergyLevel.exhausted, .low] {
            let checkIn = MoodCheckIn(mood: .bad, energy: energy, focus: 3)
            let action = engine.suggestAction(for: checkIn)
            XCTAssertEqual(action, "Try a 2-minute breathing exercise", "Failed for energy: \(energy)")
        }
    }

    func testSuggestActionBadWithModerateOrHighEnergy() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        for energy in [EnergyLevel.moderate, .high, .full] {
            let checkIn = MoodCheckIn(mood: .bad, energy: energy, focus: 3)
            let action = engine.suggestAction(for: checkIn)
            XCTAssertEqual(action, "Journal about what's weighing on you", "Failed for energy: \(energy)")
        }
    }

    func testSuggestActionOkayWithExhausted() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        let checkIn = MoodCheckIn(mood: .okay, energy: .exhausted, focus: 4)
        let action = engine.suggestAction(for: checkIn)
        XCTAssertEqual(action, "Journal about what's weighing on you")
    }

    func testSuggestActionOkayWithModerateOrHighEnergy() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        for energy in [EnergyLevel.low, .moderate, .high] {
            let checkIn = MoodCheckIn(mood: .okay, energy: energy, focus: 4)
            let action = engine.suggestAction(for: checkIn)
            XCTAssertEqual(action, "Take a short walk or stretch break", "Failed for energy: \(energy)")
        }
    }

    func testSuggestActionGoodGreatWithHighFullEnergy() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        let combos: [(Mood, EnergyLevel)] = [
            (.good, .high), (.good, .full),
            (.great, .exhausted), (.great, .low), (.great, .moderate), (.great, .high), (.great, .full),
        ]
        for (mood, energy) in combos {
            let checkIn = MoodCheckIn(mood: mood, energy: energy, focus: 8)
            let action = engine.suggestAction(for: checkIn)
            XCTAssertEqual(action, "Capture this energy — write down three things you're grateful for", "Failed for mood: \(mood), energy: \(energy)")
        }
    }

    func testSuggestActionGoodWithModerateEnergy() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        for energy in [EnergyLevel.exhausted, .low, .moderate] {
            let checkIn = MoodCheckIn(mood: .good, energy: energy, focus: 7)
            let action = engine.suggestAction(for: checkIn)
            // .good with exhausted/low/moderate → no match → default
            XCTAssertEqual(action, "Close your eyes and take three deep breaths", "Failed for energy: \(energy)")
        }
    }

    func testSuggestActionHighEnergyNonGood() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        // (okay, .full) → caught by (.okay, _) → "Take a short walk or stretch break"
        let checkIn = MoodCheckIn(mood: .okay, energy: .full, focus: 6)
        let action = engine.suggestAction(for: checkIn)
        XCTAssertEqual(action, "Take a short walk or stretch break")
    }

    func testSuggestActionDefault() {
        let engine = WellnessEngine(ai: MockAIProvider(), database: MockDatabaseService())
        // (.good, .exhausted) → no match → default
        let checkIn = MoodCheckIn(mood: .good, energy: .exhausted, focus: 7)
        let action = engine.suggestAction(for: checkIn)
        XCTAssertEqual(action, "Close your eyes and take three deep breaths")
    }

    // MARK: - WellnessEngine analyzeCheckIn Save Tests

    func testAnalyzeCheckInSavesReflectionToDB() async {
        let mockAI = MockAIProvider()
        mockAI.mockResponse = "You're doing great. Keep it up!"
        let mockDB = MockDatabaseService()
        let engine = WellnessEngine(ai: mockAI, database: mockDB)

        let checkIn = MoodCheckIn(mood: .good, energy: .high, focus: 8, notes: "Testing")
        let reflection = await engine.analyzeCheckIn(checkIn)
        XCTAssertEqual(reflection, "You're doing great. Keep it up!")

        // Verify reflection was saved — fetch from DB should include it
        let saved: [MoodCheckIn]
        do {
            saved = try mockDB.fetchMoodCheckIns()
        } catch {
            XCTFail("Failed to fetch check-ins: \(error)")
            return
        }
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].aiReflection, "You're doing great. Keep it up!")
        XCTAssertEqual(saved[0].notes, "Testing")
    }

    // MARK: - CalendarService Tests

    func testCalendarRoundToNextHourOnTheHour() async {
        let calendar = Calendar.current
        let dc = DateComponents(year: 2026, month: 7, day: 7, hour: 14, minute: 0, second: 0)
        let date = calendar.date(from: dc)!
        let rounded = await CalendarService.shared.roundToNextHour(date)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rounded)
        XCTAssertEqual(comps.hour, 15)
        XCTAssertEqual(comps.minute, 0)
    }

    func testCalendarRoundToNextHourMidHour() async {
        let calendar = Calendar.current
        let dc = DateComponents(year: 2026, month: 7, day: 7, hour: 10, minute: 23, second: 45)
        let date = calendar.date(from: dc)!
        let rounded = await CalendarService.shared.roundToNextHour(date)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rounded)
        XCTAssertEqual(comps.hour, 11)
        XCTAssertEqual(comps.minute, 0)
    }

    func testCalendarRoundToNextHourEndOfDay() async {
        let calendar = Calendar.current
        let dc = DateComponents(year: 2026, month: 7, day: 7, hour: 23, minute: 45, second: 0)
        let date = calendar.date(from: dc)!
        let rounded = await CalendarService.shared.roundToNextHour(date)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rounded)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.day, 8) // next day
    }

    func testCalendarMockRequestAccess() async {
        let mock = MockCalendarService()
        mock._requestAccessResult = true
        let result = await mock.requestAccess()
        XCTAssertTrue(result)
    }

    func testCalendarMockHasAccess() {
        let mock = MockCalendarService()
        XCTAssertFalse(mock.hasAccess)
        mock._hasAccess = true
        XCTAssertTrue(mock.hasAccess)
    }

    func testCalendarMockIsInMeeting() async {
        let mock = MockCalendarService()
        mock._isInMeeting = true
        let result = await mock.isInMeeting()
        XCTAssertTrue(result)
    }

    func testCalendarMockUpcomingEvent() async {
        let mock = MockCalendarService()
        let event = await mock.upcomingEvent()
        XCTAssertNil(event)
    }

    func testCalendarMockMeetingsHours() async {
        let mock = MockCalendarService()
        mock._meetingHoursToday = 3600
        let hours = await mock.meetingHoursToday()
        XCTAssertEqual(hours, 3600)
    }

    func testCalendarMockScheduleFocusBlock() async {
        let mock = MockCalendarService()
        mock._scheduleFocusBlockResult = true
        let result = await mock.scheduleFocusBlock(duration: 1800, title: "Deep Work")
        XCTAssertTrue(result)
    }

    func testCalendarMockScheduleBreak() async {
        let mock = MockCalendarService()
        mock._scheduleBreakResult = true
        let result = await mock.scheduleBreak(length: 300)
        XCTAssertTrue(result)
    }

    func testDeleteAllData() throws {
        // Save data to every table
        let checkIn = MoodCheckIn(mood: .good, energy: .moderate, focus: 7)
        try db.saveMoodCheckIn(checkIn)

        let session = FocusSession(startTime: Date(), duration: 1800, type: .deepWork, state: .completed, interruptions: 0, focusScore: 1.0)
        try db.saveFocusSession(session)

        let record = ActivityRecord(id: "del-test-1", timestamp: Date(), activityType: .coding, appBundleID: "com.test", appName: "Test", duration: 120, confidence: 0.9)
        try db.saveActivityRecord(record)

        let advice = CoachingAdvice(type: .focus, title: "Test", description: "", priority: .medium)
        try db.saveCoachingAdvice(advice)

        let entry = JournalEntry(prompt: "Prompt", content: "Content", title: "Title")
        try db.saveJournalEntry(entry)

        // Verify everything is saved
        XCTAssertEqual(try db.fetchMoodCheckIns(limit: 100).count, 1)
        XCTAssertEqual(try db.fetchFocusSessions(limit: 100).count, 1)
        let records = try db.fetchActivityRecords(since: Date.distantPast, limit: 100)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(try db.fetchActiveAdvice().count, 1)
        XCTAssertEqual(try db.fetchJournalEntries(limit: 100).count, 1)

        // Delete all data
        try db.deleteAllData()

        // Verify everything is gone
        XCTAssertEqual(try db.fetchMoodCheckIns(limit: 100).count, 0)
        XCTAssertEqual(try db.fetchFocusSessions(limit: 100).count, 0)
        let remaining = try db.fetchActivityRecords(since: Date.distantPast, limit: 100)
        XCTAssertEqual(remaining.count, 0)
        XCTAssertEqual(try db.fetchActiveAdvice().count, 0)
        XCTAssertEqual(try db.fetchJournalEntries(limit: 100).count, 0)
    }

    // MARK: - Performance Tests

    func testPerformanceLargeDatasetMoodCheckIns() throws {
        // Insert 1000 mood check-ins with varied data
        for i in 0..<1000 {
            let moods: [Mood] = [.great, .good, .okay, .bad, .terrible]
            let energies: [EnergyLevel] = [.full, .high, .moderate, .low, .exhausted]
            var checkIn = MoodCheckIn(
                mood: moods[i % moods.count],
                energy: energies[i % energies.count],
                focus: (i % 10) + 1,
                notes: "Bulk entry \(i)"
            )
            checkIn.timestamp = Date().addingTimeInterval(-Double(i) * 3600)
            if i % 3 == 0 {
                checkIn.aiReflection = "AI reflection for entry \(i)"
            }
            try db.saveMoodCheckIn(checkIn)
        }

        // Verify all 1000 were saved
        let fetched = try db.fetchMoodCheckIns(limit: 2000)
        XCTAssertEqual(fetched.count, 1000)

        // Verify descending timestamp order
        XCTAssertGreaterThan(fetched[0].timestamp, fetched[999].timestamp)

        // Verify varied mood values are preserved
        let uniqueMoods = Set(fetched.map(\.mood))
        XCTAssertEqual(uniqueMoods.count, 5) // great, good, okay, bad, terrible

        // Verify AI reflections on every 3rd entry
        let withReflection = fetched.filter { $0.aiReflection != nil }
        XCTAssertEqual(withReflection.count, 334)
    }

    func testPerformanceLargeDatasetFocusSessions() throws {
        // Insert 500 focus sessions
        for i in 0..<500 {
            let states: [FocusState] = [.completed, .interrupted, .completed, .focusing, .completed]
            let types: [FocusSessionType] = [.pomodoro, .deepWork, .adaptive, .custom]
            let session = FocusSession(
                startTime: Date().addingTimeInterval(-Double(i) * 7200),
                duration: Double(1500 + (i % 10) * 100),
                type: types[i % types.count],
                state: states[i % states.count],
                interruptions: i % 5,
                focusScore: Double(i % 100) / 100.0
            )
            try db.saveFocusSession(session)
        }

        let sessions = try db.fetchFocusSessions(limit: 1000)
        XCTAssertEqual(sessions.count, 500)

        // Verify descending startTime order
        XCTAssertGreaterThan(sessions[0].startTime, sessions[499].startTime)

        // Verify data integrity across all sessions
        let completedCount = sessions.filter { $0.state == .completed }.count
        let pomodoroCount = sessions.filter { $0.type == .pomodoro }.count
        XCTAssertEqual(completedCount, 300)  // 3 out of 5 states are completed
        XCTAssertEqual(pomodoroCount, 125)   // 1 out of 4 types is pomodoro
    }

    func testPerformanceMixedReadWrite() throws {
        // Simulate real usage: interleaved writes and reads
        for i in 0..<200 {
            var checkIn = MoodCheckIn(mood: .okay, energy: .moderate, focus: 5, notes: "Mixed \(i)")
            checkIn.timestamp = Date().addingTimeInterval(-Double(i) * 60)
            try db.saveMoodCheckIn(checkIn)

            // Read after every write to simulate app behavior
            if i % 50 == 0 {
                _ = try db.fetchMoodCheckIns(limit: 100)
                let sessions = try db.fetchFocusSessions(limit: 20)
                XCTAssertLessThanOrEqual(sessions.count, i < 50 ? 0 : 25)
            }
        }

        // Final validation
        let all = try db.fetchMoodCheckIns(limit: 500)
        XCTAssertEqual(all.count, 200)
    }
}

// MARK: - Additional Mock Implementations

final class FailingAIProvider: AIProviderProtocol {
    var isAvailable: Bool { false }
    func initialize() async {}
    func smartPrompt(system: String, user: String, preferCloud: Bool) async throws -> String {
        throw NSError(domain: "mock", code: -1)
    }
    func smartStructured<T: Decodable & Sendable>(system: String, user: String, type: T.Type) async throws -> T {
        throw NSError(domain: "mock", code: -1)
    }
}

// MARK: - Mock Implementations

final class MockDatabaseService: DatabaseServiceProtocol {
    private var advice: [CoachingAdvice] = []
    private var checkIns: [MoodCheckIn] = []

    func initialize() throws {}
    func saveMoodCheckIn(_ checkIn: MoodCheckIn) throws { checkIns.append(checkIn) }
    func fetchMoodCheckIns(limit: Int = 100) throws -> [MoodCheckIn] { Array(checkIns.suffix(limit)) }
    func saveFocusSession(_ session: FocusSession) throws {}
    func fetchFocusSessions(limit: Int) throws -> [FocusSession] { [] }
    func saveActivityRecord(_ record: ActivityRecord) throws {}
    func saveActivityRecords(_ records: [ActivityRecord]) throws {}
    func fetchActivityRecords(since: Date?, limit: Int) throws -> [ActivityRecord] { [] }
    func deleteActivityRecords(before date: Date) throws {}
    func saveCoachingAdvice(_ advice: CoachingAdvice) throws { self.advice.append(advice) }
    func fetchActiveAdvice() throws -> [CoachingAdvice] { advice.filter { !$0.isDismissed } }
    func dismissAdvice(id: String) throws {
        if let i = advice.firstIndex(where: { $0.id == id }) {
            advice[i].isDismissed = true
        }
    }
    func saveJournalEntry(_ entry: JournalEntry) throws {}
    func fetchJournalEntries(limit: Int) throws -> [JournalEntry] { [] }
    func deleteAllData() throws {
        advice.removeAll()
        checkIns.removeAll()
    }
    func vacuum() throws {}
}

final class MockActivityTracker: ActivityTrackerProtocol {
    var allRecords: [ActivityRecord] { [] }
    func start() async {}
    func stop() async {}
    func records(in dateRange: ClosedRange<Date>) async -> [ActivityRecord] { [] }
}

final class MockWindowMonitor: WindowMonitorProtocol {
    var currentApp: (id: String, name: String) { ("com.apple.finder", "Finder") }
    var focusChanges: AsyncStream<(id: String, name: String)> {
        AsyncStream { $0.finish() }
    }
    var isAccessibilityAuthorized: Bool { false }
    func startMonitoring() async {}
    func stopMonitoring() async {}
    func requestAccessibilityPermission() {}
}

final class MockWellnessEngine: WellnessEngineProtocol {
    func analyzeCheckIn(_ checkIn: MoodCheckIn) async -> String { "Keep going." }
    func suggestAction(for checkIn: MoodCheckIn) -> String { "Take a deep breath." }
    func generateDailyPrompt() async -> StoicPrompt {
        StoicPrompt(date: Date(), text: "Test", author: "Test", reflection: "OK", followUp: "?")
    }
    func loadCheckIns() async -> [MoodCheckIn] { [] }
    func analyzeWeeklyPattern(checkIns: [MoodCheckIn]) async -> String { "Stable." }
    func getContextualSuggestion(currentApp: String, activeMinutes: TimeInterval) async -> String { "Keep focused." }
}

final class MockCalendarService: CalendarServiceProtocol {
    var _hasAccess: Bool = false
    var _requestAccessResult: Bool = false
    var _currentEvents: [EKEvent] = []
    var _upcomingEvent: EKEvent? = nil
    var _currentMeeting: EKEvent? = nil
    var _meetingsToday: [EKEvent] = []
    var _meetingHoursToday: TimeInterval = 0
    var _scheduleFocusBlockResult: Bool = false
    var _scheduleBreakResult: Bool = false
    var _isInMeeting: Bool = false

    var hasAccess: Bool { _hasAccess }
    func requestAccess() async -> Bool { _requestAccessResult }
    func currentEvents() async -> [EKEvent] { _currentEvents }
    func upcomingEvent() async -> EKEvent? { _upcomingEvent }
    func currentMeeting() async -> EKEvent? { _currentMeeting }
    func meetingsToday() async -> [EKEvent] { _meetingsToday }
    func meetingHoursToday() async -> TimeInterval { _meetingHoursToday }
    func scheduleFocusBlock(duration: TimeInterval, title: String?) async -> Bool { _scheduleFocusBlockResult }
    func scheduleBreak(length: TimeInterval) async -> Bool { _scheduleBreakResult }
    func isInMeeting() async -> Bool { _isInMeeting }
}

final class MockPermissionsManager: PermissionsManagerProtocol {
    func currentState() async -> PermissionState {
        PermissionState(accessibility: false, notifications: false)
    }
    func requestAccessibility() async {}
    func requestNotifications() async -> Bool { false }
}

final class MockStoreManager: StoreManagerProtocol {
    var currentTier: SubscriptionTier { .free }
    func initialize() async {}
    func purchase(_ product: ProProduct) async throws {}
    func restorePurchases() async {}
    func displayPrice(for product: ProProduct) async -> String? { product.displayPrice }
}

final class MockCreativeBreakService: CreativeBreakServiceProtocol {
    func randomPrompt() async -> CreativePrompt {
        CreativePrompt(title: "Test", description: "Test", suggestion: "Test", category: .visual)
    }
    func prompts(for category: CreativeCategory) async -> [CreativePrompt] { [] }
}

final class MockAIProvider: AIProviderProtocol {
    var isAvailable: Bool { false }
    var mockResponse: String = "AI response"
    func initialize() async {}
    func smartPrompt(system: String, user: String, preferCloud: Bool) async throws -> String { mockResponse }
    func smartStructured<T: Decodable & Sendable>(system: String, user: String, type: T.Type) async throws -> T {
        throw NSError(domain: "mock", code: -1)
    }
}

// MARK: - AIOrchestrator Mock & Tests

/// Mock LocalAI provider that conforms to the internal `AIProvider` protocol.
/// Used to inject into `AIOrchestrator(localProvider:)` for testing.
final class MockLocalProvider: AIProvider {
    let tier: AIModelTier = .onDevice
    var isAvailable: Bool = true
    var mockResponse: String = "mock response"
    var shouldFail: Bool = false
    var structuredResult: String?

    func generateResponse(systemPrompt: String, userMessage: String) async throws -> String {
        if shouldFail { throw AIError.generationFailed("mock fail") }
        return mockResponse
    }

    func generateStructured<T: Decodable & Sendable>(
        systemPrompt: String, userMessage: String, type: T.Type
    ) async throws -> T {
        if shouldFail { throw AIError.generationFailed("mock fail") }

        if let result = structuredResult, let data = result.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }

        // Try empty object fallback
        if let data = "{}".data(using: .utf8),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }

        throw AIError.generationFailed("mock cannot produce \(T.self)")
    }
}

// MARK: - AIOrchestrator Tests

final class AIOrchestratorTests: XCTestCase {

    // MARK: - smartStructured

    func testSmartStructuredReturnsDecodedObject() async throws {
        let mock = MockLocalProvider()
        mock.structuredResult = #"{"value": "hello"}"#

        let orchestrator = AIOrchestrator(localProvider: mock)
        let result: SimpleCodable = try await orchestrator.smartStructured(
            system: "test", user: "test", type: SimpleCodable.self
        )
        XCTAssertEqual(result.value, "hello")
    }

    func testSmartStructuredPropagatesProviderError() async {
        let mock = MockLocalProvider()
        mock.shouldFail = true
        mock.isAvailable = false

        let orchestrator = AIOrchestrator(localProvider: mock)
        do {
            let _: SimpleCodable = try await orchestrator.smartStructured(
                system: "test", user: "test", type: SimpleCodable.self
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSmartStructuredBeforeInitThrowsModelUnavailable() async {
        // Orchestrator with no provider (nil) and no initialize() call
        let orchestrator = AIOrchestrator(localProvider: nil)
        do {
            let _: SimpleCodable = try await orchestrator.smartStructured(
                system: "test", user: "test", type: SimpleCodable.self
            )
            XCTFail("Expected modelUnavailable error")
        } catch AIError.modelUnavailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSmartStructuredWithEmptyObjectFallback() async throws {
        let mock = MockLocalProvider()
        // No structuredResult set → falls through to "{}" decode

        let orchestrator = AIOrchestrator(localProvider: mock)
        let result: SimpleCodable = try await orchestrator.smartStructured(
            system: "test", user: "test", type: SimpleCodable.self
        )
        XCTAssertNil(result.value)
    }

    // MARK: - smartPrompt

    func testSmartPromptReturnsResponse() async throws {
        let mock = MockLocalProvider()
        mock.mockResponse = "hello from mock"

        let orchestrator = AIOrchestrator(localProvider: mock)
        let result = try await orchestrator.smartPrompt(system: "test", user: "test")
        XCTAssertEqual(result, "hello from mock")
    }

    func testSmartPromptPropagatesError() async {
        let mock = MockLocalProvider()
        mock.shouldFail = true

        let orchestrator = AIOrchestrator(localProvider: mock)
        do {
            _ = try await orchestrator.smartPrompt(system: "test", user: "test")
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSmartPromptBeforeInitThrowsModelUnavailable() async {
        let orchestrator = AIOrchestrator(localProvider: nil)
        do {
            _ = try await orchestrator.smartPrompt(system: "test", user: "test")
            XCTFail("Expected modelUnavailable error")
        } catch AIError.modelUnavailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSmartPromptPreferCloudDoesNotCrash() async throws {
        // preferCloud should work the same as default when FM is unavailable
        let mock = MockLocalProvider()
        mock.mockResponse = "cloud response"

        let orchestrator = AIOrchestrator(localProvider: mock)
        let result = try await orchestrator.smartPrompt(system: "test", user: "test", preferCloud: true)
        XCTAssertEqual(result, "cloud response")
    }

    // MARK: - isAvailable

    func testIsAvailableFalseWhenNoProvider() async {
        let orchestrator = AIOrchestrator(localProvider: nil)
        let available = await orchestrator.isAvailable
        XCTAssertFalse(available)
    }

    func testIsAvailableTrueWhenProviderAvailable() async {
        let mock = MockLocalProvider()
        mock.isAvailable = true

        let orchestrator = AIOrchestrator(localProvider: mock)
        let available = await orchestrator.isAvailable
        XCTAssertTrue(available)
    }

    func testIsAvailableReflectsProviderState() async {
        let mock = MockLocalProvider()
        let orchestrator = AIOrchestrator(localProvider: mock)

        mock.isAvailable = true
        var available = await orchestrator.isAvailable
        XCTAssertTrue(available)

        mock.isAvailable = false
        available = await orchestrator.isAvailable
        XCTAssertFalse(available)
    }

    // MARK: - initialize

    func testInitializeDoesNotReplaceInjectedProvider() async {
        let mock = MockLocalProvider()
        let orchestrator = AIOrchestrator(localProvider: mock)

        await orchestrator.initialize()
        let available = await orchestrator.isAvailable
        XCTAssertTrue(available)
    }

}

/// Simple codable struct for testing structured output.
private struct SimpleCodable: Decodable, Sendable {
    var value: String?
}
