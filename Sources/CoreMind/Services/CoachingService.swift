import Foundation

actor CoachingService: CoachingServiceProtocol {
    static let shared = CoachingService()

    private let wellness: WellnessEngineProtocol
    private let database: DatabaseServiceProtocol
    private let activityTracker: ActivityTrackerProtocol
    private let windowMonitor: WindowMonitorProtocol
    private var recentAdvice: [CoachingAdvice] = []
    private var monitoringTask: Task<Void, Never>?

    init(
        wellness: WellnessEngineProtocol = WellnessEngine.shared,
        database: DatabaseServiceProtocol = DatabaseService.shared,
        activityTracker: ActivityTrackerProtocol = ActivityTracker.shared,
        windowMonitor: WindowMonitorProtocol = WindowMonitor.shared
    ) {
        self.wellness = wellness
        self.database = database
        self.activityTracker = activityTracker
        self.windowMonitor = windowMonitor
    }

    func start() async {
        guard monitoringTask == nil else { return }
        recentAdvice = (try? database.fetchActiveAdvice()) ?? []
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkForRealtimeAdvice()
                try? await Task.sleep(nanoseconds: 300_000_000_000)
            }
        }
        Log.info("CoachingService started")
    }

    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
        Log.info("CoachingService stopped")
    }

    // MARK: - Daily Report

    func generateDailyReport() async -> CoachingReport {
        let advice = await generateAdvice()

        let summary: String
        if let first = advice.first {
            summary = "\(first.title): \(first.description)"
        } else {
            summary = "No significant signals today. You're doing well."
        }

        let report = CoachingReport(
            date: Date(),
            type: .daily,
            summary: summary,
            topAdvice: advice,
            aiGenerated: true
        )

        recentAdvice = advice
        return report
    }

    // MARK: - Realtime Advice

    func generateRealtimeAdvice() async -> [CoachingAdvice] {
        let advice = await generateAdvice()
        recentAdvice = advice
        return advice
    }

    // MARK: - Analysis

    // swiftlint:disable:next large_tuple
    private func analyzeDeepWork() async -> (total: TimeInterval, sessions: Int, score: Double) {
        let records = await activityTracker.allRecords
        let productive: Set<ActivityType> = [.coding, .writing, .design]
        let deepWorkRecords = records.filter { productive.contains($0.activityType) }
        let total = deepWorkRecords.reduce(0) { $0 + $1.duration }
        let score = min(total / 3600 * 25, 100)
        return (total, deepWorkRecords.count, score)
    }

    private func detectBurnoutSignals() async -> BurnoutSignals {
        let dayRecords = await activityTracker.allRecords

        let totalActive = dayRecords.reduce(0) { $0 + $1.duration }
        let overtime = max(totalActive - 28800, 0)

        let risk: BurnoutRiskLevel = overtime > 14400 ? .high : (overtime > 7200 ? .moderate : .low)
        let wellbeing = max(0, min(100, 100 - (overtime / 14400) * 50))

        return BurnoutSignals(
            overtimeHoursToday: overtime,
            nightWorkHoursThisWeek: 0,
            weekendWorkHoursThisWeek: 0,
            meetingOverloadRatio: 0,
            contextSwitchesPerHour: 0,
            averageWorkdayDuration: totalActive,
            daysWorkedThisWeek: 1,
            riskLevel: risk,
            wellbeingScore: wellbeing,
            wellbeingTrend: .stable
        )
    }

    private func generateAdvice() async -> [CoachingAdvice] {
        let (deepWork, _, score) = await analyzeDeepWork()
        let burnout = await detectBurnoutSignals()
        var advice: [CoachingAdvice] = []

        if score < 30 {
            advice.append(CoachingAdvice(
                type: .focus,
                title: "Deep Work Deficit",
                description: "Deep work score is \(Int(score))/100. Try a 25-minute focus session.",
                priority: .medium,
                actionItem: "Start a focus session now"
            ))
        }

        if burnout.riskLevel == .high || burnout.riskLevel == .critical {
            advice.append(CoachingAdvice(
                type: .wellbeing,
                title: "Burnout Risk: \(burnout.riskLevel.rawValue)",
                description: "Your work patterns suggest overextension.",
                priority: .high,
                actionItem: "Take a 5-minute breathing break"
            ))
        }

        if deepWork < 3600 {
            advice.append(CoachingAdvice(
                type: .productivity,
                title: "Less than 1 hour of deep work",
                description: "Deep work today: \(Int(deepWork / 60)) min. Aim for 2+ hours.",
                priority: .medium,
                actionItem: "Block 2 hours for focused work"
            ))
        }

        let sorted = advice.sorted { $0.priority.score > $1.priority.score }
        for a in sorted {
            do {
                try database.saveCoachingAdvice(a)
            } catch {
                Log.error("Failed to save coaching advice: \(error.localizedDescription)")
            }
        }
        return sorted
    }

    // MARK: - Contextual Suggestions

    func getContextualSuggestion() async -> String {
        let app = await windowMonitor.currentApp
        let total = await activityTracker.allRecords.reduce(0) { $0 + $1.duration }
        return await wellness.getContextualSuggestion(currentApp: app.name, activeMinutes: total / 60)
    }

    // MARK: - State

    func dismissAdvice(_ id: String) async {
        if let index = recentAdvice.firstIndex(where: { $0.id == id }) {
            recentAdvice[index].isDismissed = true
        }
        do {
            try database.dismissAdvice(id: id)
        } catch {
            Log.error("Failed to dismiss advice: \(error.localizedDescription)")
        }
    }

    var currentAdvice: [CoachingAdvice] {
        recentAdvice.filter { !$0.isDismissed }
    }

    // MARK: - Background Monitoring

    private func checkForRealtimeAdvice() async {
        let advice = await generateAdvice()
        let critical = advice.filter { $0.priority == .critical || $0.priority == .high }
        if !critical.isEmpty {
            recentAdvice = advice
        }
    }
}
