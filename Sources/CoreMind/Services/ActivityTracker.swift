import Foundation
import AppKit

actor ActivityTracker: ActivityTrackerProtocol {
    static let shared = ActivityTracker()

    private let database: DatabaseServiceProtocol
    private var isRunning = false
    private var currentSessionStart: Date?
    private var currentAppID: String?
    private var trackingTask: Task<Void, Never>?
    private var records: [ActivityRecord] = []
    private var pendingRecords: [ActivityRecord] = []
    private let saveInterval: TimeInterval = 30
    private var saveTask: Task<Void, Never>?
    private let maxInMemoryRecords = 1000

    init(database: DatabaseServiceProtocol = DatabaseService.shared) {
        self.database = database
    }

    var allRecords: [ActivityRecord] { records }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentSessionStart = Date()
        records = (try? database.fetchActivityRecords(since: nil, limit: maxInMemoryRecords)) ?? []
        enforceRetention()
        Log.info("ActivityTracker started with \(records.count) loaded records")
        
        trackingTask = Task { [weak self] in
            while !Task.isCancelled, let self = self {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await self.recordSnapshot()
            }
        }
        
        saveTask = Task { [weak self] in
            while !Task.isCancelled, let self = self {
                try? await Task.sleep(nanoseconds: UInt64(self.saveInterval * 1_000_000_000))
                await self.flushPendingRecords()
            }
        }
    }

    func stop() async {
        trackingTask?.cancel()
        trackingTask = nil
        saveTask?.cancel()
        saveTask = nil
        isRunning = false
        if let start = currentSessionStart {
            recordSession(from: start, to: Date())
        }
        flushPendingRecords()
        Log.info("ActivityTracker stopped")
    }

    func records(in dateRange: ClosedRange<Date>) -> [ActivityRecord] {
        records.filter { dateRange.contains($0.timestamp) }
    }

    private func enforceRetention() {
        let cutoff = Date().addingTimeInterval(-TimeInterval(Constants.Defaults.dataRetentionDays * 86400))
        records.removeAll { $0.timestamp < cutoff }
        do {
            try database.deleteActivityRecords(before: cutoff)
        } catch {
            Log.error("Failed to enforce retention: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func recordSnapshot() {
        let now = Date()
        guard let start = currentSessionStart else {
            currentSessionStart = now
            return
        }

        let duration = now.timeIntervalSince(start)
        if duration >= 60 {
            let app = NSWorkspace.shared.frontmostApplication
            let type = classifyActivity(appID: app?.bundleIdentifier ?? "", appName: app?.localizedName ?? "")
            let record = ActivityRecord(
                id: UUID().uuidString,
                timestamp: start,
                activityType: type,
                appBundleID: app?.bundleIdentifier ?? "",
                appName: app?.localizedName ?? "Unknown",
                windowTitle: nil,
                duration: duration,
                confidence: 0.8,
                metadataJSON: nil
            )
            appendRecord(record)
        }

        if let newApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, newApp != currentAppID {
            if let start = currentSessionStart {
                recordSession(from: start, to: now)
            }
            currentSessionStart = now
            currentAppID = newApp
        } else {
            currentSessionStart = start
        }
    }

    private func recordSession(from start: Date, to end: Date) {
        let duration = end.timeIntervalSince(start)
        guard duration >= 60 else { return }

        let app = NSWorkspace.shared.frontmostApplication
        let type = classifyActivity(appID: app?.bundleIdentifier ?? "", appName: app?.localizedName ?? "")
        let record = ActivityRecord(
            id: UUID().uuidString,
            timestamp: start,
            activityType: type,
            appBundleID: app?.bundleIdentifier ?? "",
            appName: app?.localizedName ?? "Unknown",
            windowTitle: nil,
            duration: duration,
            confidence: 0.8,
            metadataJSON: nil
        )
        appendRecord(record)
    }

    private func appendRecord(_ record: ActivityRecord) {
        records.append(record)
        pendingRecords.append(record)
        if records.count > maxInMemoryRecords {
            records.removeFirst(records.count - maxInMemoryRecords)
        }
    }

    private func flushPendingRecords() {
        guard !pendingRecords.isEmpty else { return }
        let toSave = pendingRecords
        pendingRecords.removeAll()
        do {
            try database.saveActivityRecords(toSave)
        } catch {
            Log.error("Failed to flush pending records: \(error.localizedDescription)")
        }
    }

    // Internal for testability via @testable import
    func classifyActivity(appID: String, appName: String) -> ActivityType {
        let name = appName.lowercased()
        let id = appID.lowercased()

        if id.contains("xcode") || id.contains("vscode") || id.contains("code") || name.contains("terminal") {
            return .coding
        }
        if id.contains("safari") || id.contains("chrome") || id.contains("firefox") || id.contains("arc") || id.contains("edge") {
            return .browsing
        }
        if name.contains("figma") || name.contains("photoshop") || name.contains("sketch") || name.contains("illustrator") || name.contains("affinity") {
            return .design
        }
        if id.contains("mail") || id.contains("outlook") || name.contains("mail") || name.contains("spark") || name.contains("superhuman") {
            return .email
        }
        if id.contains("zoom") || id.contains("teams") || id.contains("meet") || id.contains("webex") || id.contains("slack") || name.contains("facetime") {
            return .meeting
        }
        if name.contains("spotify") || name.contains("music") || id.contains("apple.music") {
            return .media
        }
        if name.contains("notes") || name.contains("pages") || name.contains("word") || name.contains("obsidian") || name.contains("notion") || name.contains("bear") {
            return .writing
        }
        return .other
    }
}

enum ActivityError: Error {
    case noRecords
}
