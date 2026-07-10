import Foundation
import SwiftUI

@MainActor
final class AppDependencies {
    let database: DatabaseServiceProtocol
    let settings: SettingsStore
    let aiOrchestrator: AIProviderProtocol
    let windowMonitor: WindowMonitorProtocol
    let activityTracker: ActivityTrackerProtocol
    let coachingService: CoachingServiceProtocol
    let proactiveNudgeService: ProactiveNudgeServiceProtocol
    let wellnessEngine: WellnessEngineProtocol
    let calendarService: CalendarServiceProtocol
    let permissionsManager: PermissionsManagerProtocol
    let storeManager: StoreManagerProtocol
    let creativeBreakService: CreativeBreakServiceProtocol

    convenience init() {
        let database: DatabaseServiceProtocol = DatabaseService.shared
        let windowMonitor: WindowMonitorProtocol = WindowMonitor.shared
        let activityTracker: ActivityTrackerProtocol = ActivityTracker(database: database)
        let aiOrchestrator: AIProviderProtocol = AIOrchestrator.shared
        let wellnessEngine: WellnessEngineProtocol = WellnessEngine(
            ai: aiOrchestrator,
            database: database
        )
        let coachingService: CoachingServiceProtocol = CoachingService(
            wellness: wellnessEngine,
            database: database,
            activityTracker: activityTracker,
            windowMonitor: windowMonitor
        )
        let proactiveNudgeService: ProactiveNudgeServiceProtocol = ProactiveNudgeService(
            activityTracker: activityTracker,
            windowMonitor: windowMonitor
        )
        let calendarService: CalendarServiceProtocol = CalendarService.shared
        let permissionsManager: PermissionsManagerProtocol = PermissionsManager.shared
        let storeManager: StoreManagerProtocol = StoreManager.shared
        let creativeBreakService: CreativeBreakServiceProtocol = CreativeBreakService.shared
        self.init(
            database: database,
            windowMonitor: windowMonitor,
            activityTracker: activityTracker,
            coachingService: coachingService,
            proactiveNudgeService: proactiveNudgeService,
            wellnessEngine: wellnessEngine,
            calendarService: calendarService,
            permissionsManager: permissionsManager,
            storeManager: storeManager,
            creativeBreakService: creativeBreakService,
            aiOrchestrator: aiOrchestrator
        )
    }

    init(
        database: DatabaseServiceProtocol,
        windowMonitor: WindowMonitorProtocol,
        activityTracker: ActivityTrackerProtocol,
        coachingService: CoachingServiceProtocol,
        proactiveNudgeService: ProactiveNudgeServiceProtocol,
        wellnessEngine: WellnessEngineProtocol,
        calendarService: CalendarServiceProtocol,
        permissionsManager: PermissionsManagerProtocol,
        storeManager: StoreManagerProtocol,
        creativeBreakService: CreativeBreakServiceProtocol,
        aiOrchestrator: AIProviderProtocol
    ) {
        self.database = database
        self.settings = SettingsStore.shared
        self.creativeBreakService = creativeBreakService
        self.aiOrchestrator = aiOrchestrator
        self.windowMonitor = windowMonitor
        self.activityTracker = activityTracker
        self.calendarService = calendarService
        self.permissionsManager = permissionsManager
        self.storeManager = storeManager
        self.wellnessEngine = wellnessEngine
        self.coachingService = coachingService
        self.proactiveNudgeService = proactiveNudgeService
    }

    func initialize() async {
        do {
            try database.initialize()
            Log.info("Database initialized")
        } catch {
            Log.warning("Database init failed: \(error.localizedDescription)")
        }
        await aiOrchestrator.initialize()
        await storeManager.initialize()
        await windowMonitor.startMonitoring()
        let trackActivity = await MainActor.run { settings.trackActivity }
        if trackActivity {
            await activityTracker.start()
        }
        await coachingService.start()
        await proactiveNudgeService.start()
        Log.info("CoreMind services initialized")
    }
}

struct AppDependenciesKey: EnvironmentKey {
    @MainActor static let defaultValue = AppDependencies()
}

extension EnvironmentValues {
    var deps: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
