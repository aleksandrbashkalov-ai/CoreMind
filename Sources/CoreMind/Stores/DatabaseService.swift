import Foundation
import GRDB

enum DBError: Error {
    case notInitialized
    case decodingFailed(String)
    case initializationFailed(String)
    case migrationFailed(String)
    case storageUnavailable(String)
}

extension Row {
    func safeString(_ column: String) -> String {
        self[column] as String? ?? ""
    }

    func safeInt(_ column: String) -> Int {
        self[column] as Int? ?? 0
    }

    func safeDouble(_ column: String) -> Double {
        self[column] as Double? ?? 0
    }

    func safeDate(_ column: String) -> Date {
        self[column] as Date? ?? Date.distantPast
    }

    func safeBool(_ column: String) -> Bool {
        self[column] as Bool? ?? false
    }

    func safeUUID(_ column: String) -> UUID {
        self[column] as UUID? ?? UUID()
    }
}

// Thread safety: dbWriter (DatabaseQueue/DatabasePool) is internally synchronized by GRDB.
// Shared singleton accessed through Swift actors in services.
final class DatabaseService: DatabaseServiceProtocol, @unchecked Sendable {
    static let shared = DatabaseService()

    private var dbWriter: (any DatabaseWriter)?

    private init() {}

    init(dbWriter: (any DatabaseWriter)) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    func initialize() throws {
        let appSupport: URL
        do {
            appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw DBError.initializationFailed("Cannot access Application Support directory: \(error.localizedDescription)")
        }

        let dbURL = appSupport.appendingPathComponent("CoreMind.sqlite")
        let dbQueue: DatabaseQueue
        do {
            dbQueue = try DatabaseQueue(path: dbURL.path)
        } catch {
            throw DBError.initializationFailed("Cannot create database queue at \(dbURL.path): \(error.localizedDescription)")
        }

        dbWriter = dbQueue
        do {
            try migrator.migrate(dbQueue)
        } catch {
            dbWriter = nil
            throw DBError.migrationFailed("Database migration failed: \(error.localizedDescription)")
        }

        Log.info("DB ready at \(dbURL.path)")
    }

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.create(table: "mood_check_in") { t in
                t.column("id", .text).primaryKey()
                t.column("timestamp", .datetime).notNull()
                t.column("mood", .text).notNull()
                t.column("energy", .text).notNull()
                t.column("focus", .integer).notNull()
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("ai_reflection", .text)
            }
            try db.create(table: "focus_session") { t in
                t.column("id", .text).primaryKey()
                t.column("start_time", .datetime).notNull()
                t.column("end_time", .datetime)
                t.column("duration", .double).notNull()
                t.column("type", .text).notNull()
                t.column("state", .text).notNull()
                t.column("interruptions", .integer).notNull().defaults(to: 0)
                t.column("focus_score", .double).notNull().defaults(to: 0)
                t.column("activity_summary", .text)
                t.column("note", .text)
            }
            try db.create(table: "activity_record") { t in
                t.column("id", .text).primaryKey()
                t.column("timestamp", .datetime).notNull()
                t.column("activity_type", .text).notNull()
                t.column("app_bundle_id", .text).notNull()
                t.column("app_name", .text).notNull()
                t.column("window_title", .text)
                t.column("duration", .double).notNull()
                t.column("confidence", .double).notNull()
                t.column("metadata_json", .text)
            }
            try db.create(table: "coaching_advice") { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("title", .text).notNull()
                t.column("description", .text).notNull()
                t.column("priority", .text).notNull()
                t.column("action_item", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("is_read", .boolean).notNull().defaults(to: false)
                t.column("is_dismissed", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "journal_entry") { t in
                t.column("id", .text).primaryKey()
                t.column("date", .datetime).notNull()
                t.column("prompt", .text).notNull().defaults(to: "")
                t.column("content", .text).notNull().defaults(to: "")
                t.column("title", .text).notNull().defaults(to: "")
                t.column("ai_summary", .text)
                t.column("tags", .text).notNull().defaults(to: "[]")
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
            }
        }
        return m
    }

    // MARK: - Access

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        guard let w = dbWriter else { throw DBError.notInitialized }
        return try w.read(block)
    }

    func write<T>(_ block: (Database) throws -> T) throws -> T {
        guard let w = dbWriter else { throw DBError.notInitialized }
        return try w.write(block)
    }

    // MARK: - Mood Check-Ins

    func saveMoodCheckIn(_ checkIn: MoodCheckIn) throws {
        try write { db in
            let dict: [String: DatabaseValue] = [
                "id": checkIn.id.databaseValue,
                "timestamp": checkIn.timestamp.databaseValue,
                "mood": checkIn.mood.rawValue.databaseValue,
                "energy": checkIn.energy.rawValue.databaseValue,
                "focus": checkIn.focus.databaseValue,
                "notes": checkIn.notes.databaseValue,
                "ai_reflection": checkIn.aiReflection?.databaseValue ?? .null
            ]
            try db.execute(sql: """
                INSERT OR REPLACE INTO mood_check_in (id, timestamp, mood, energy, focus, notes, ai_reflection)
                VALUES (:id, :timestamp, :mood, :energy, :focus, :notes, :ai_reflection)
                """, arguments: StatementArguments(dict))
        }
    }

    func fetchMoodCheckIns(limit: Int = 50) throws -> [MoodCheckIn] {
        try read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM mood_check_in ORDER BY timestamp DESC LIMIT ?
                """, arguments: [limit])
            return rows.map { row in
                var checkIn = MoodCheckIn(
                    mood: Mood(rawValue: row.safeString("mood")) ?? .okay,
                    energy: EnergyLevel(rawValue: row.safeString("energy")) ?? .moderate,
                    focus: row.safeInt("focus"),
                    notes: row.safeString("notes")
                )
                checkIn.id = row.safeUUID("id")
                checkIn.timestamp = row.safeDate("timestamp")
                checkIn.aiReflection = row["ai_reflection"] as String?
                return checkIn
            }
        }
    }

    // MARK: - Focus Sessions

    func saveFocusSession(_ session: FocusSession) throws {
        try write { db in
            let dict: [String: DatabaseValue] = [
                "id": session.id.databaseValue,
                "start_time": session.startTime.databaseValue,
                "end_time": session.endTime?.databaseValue ?? .null,
                "duration": session.duration.databaseValue,
                "type": session.type.rawValue.databaseValue,
                "state": session.state.rawValue.databaseValue,
                "interruptions": session.interruptions.databaseValue,
                "focus_score": session.focusScore.databaseValue,
                "activity_summary": session.activitySummary?.databaseValue ?? .null,
                "note": session.note?.databaseValue ?? .null
            ]
            try db.execute(sql: """
                INSERT OR REPLACE INTO focus_session (id, start_time, end_time, duration, type, state, interruptions, focus_score, activity_summary, note)
                VALUES (:id, :start_time, :end_time, :duration, :type, :state, :interruptions, :focus_score, :activity_summary, :note)
                """, arguments: StatementArguments(dict))
        }
    }

    func fetchFocusSessions(limit: Int = 30) throws -> [FocusSession] {
        try read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM focus_session ORDER BY start_time DESC LIMIT ?
                """, arguments: [limit])
            return rows.map { row in
                FocusSession(
                    id: row.safeUUID("id"),
                    startTime: row.safeDate("start_time"),
                    endTime: row["end_time"] as Date?,
                    duration: row.safeDouble("duration"),
                    type: FocusSessionType(rawValue: row.safeString("type")) ?? .pomodoro,
                    state: FocusState(rawValue: row.safeString("state")) ?? .idle,
                    interruptions: row.safeInt("interruptions"),
                    focusScore: row.safeDouble("focus_score"),
                    activitySummary: row["activity_summary"] as String?,
                    note: row["note"] as String?
                )
            }
        }
    }

    // MARK: - Activity Records

    func saveActivityRecord(_ record: ActivityRecord) throws {
        try write { db in
            let dict: [String: DatabaseValue] = [
                "id": record.id.databaseValue,
                "timestamp": record.timestamp.databaseValue,
                "activity_type": record.activityType.rawValue.databaseValue,
                "app_bundle_id": record.appBundleID.databaseValue,
                "app_name": record.appName.databaseValue,
                "window_title": record.windowTitle?.databaseValue ?? .null,
                "duration": record.duration.databaseValue,
                "confidence": record.confidence.databaseValue,
                "metadata_json": record.metadataJSON?.databaseValue ?? .null
            ]
            try db.execute(sql: """
                INSERT OR REPLACE INTO activity_record (id, timestamp, activity_type, app_bundle_id, app_name, window_title, duration, confidence, metadata_json)
                VALUES (:id, :timestamp, :activity_type, :app_bundle_id, :app_name, :window_title, :duration, :confidence, :metadata_json)
                """, arguments: StatementArguments(dict))
        }
    }

    func saveActivityRecords(_ records: [ActivityRecord]) throws {
        try write { db in
            for record in records {
                let dict: [String: DatabaseValue] = [
                    "id": record.id.databaseValue,
                    "timestamp": record.timestamp.databaseValue,
                    "activity_type": record.activityType.rawValue.databaseValue,
                    "app_bundle_id": record.appBundleID.databaseValue,
                    "app_name": record.appName.databaseValue,
                    "window_title": record.windowTitle?.databaseValue ?? .null,
                    "duration": record.duration.databaseValue,
                    "confidence": record.confidence.databaseValue,
                    "metadata_json": record.metadataJSON?.databaseValue ?? .null
                ]
                try db.execute(sql: """
                    INSERT OR REPLACE INTO activity_record (id, timestamp, activity_type, app_bundle_id, app_name, window_title, duration, confidence, metadata_json)
                    VALUES (:id, :timestamp, :activity_type, :app_bundle_id, :app_name, :window_title, :duration, :confidence, :metadata_json)
                    """, arguments: StatementArguments(dict))
            }
        }
    }

    func fetchActivityRecords(since: Date? = nil, limit: Int = 200) throws -> [ActivityRecord] {
        try read { db in
            if let since = since {
                let rows = try Row.fetchAll(db, sql: """
                    SELECT * FROM activity_record WHERE timestamp >= ? ORDER BY timestamp DESC LIMIT ?
                    """, arguments: [since, limit])
                return rows.map { rowToRecord($0) }
            } else {
                let rows = try Row.fetchAll(db, sql: """
                    SELECT * FROM activity_record ORDER BY timestamp DESC LIMIT ?
                    """, arguments: [limit])
                return rows.map { rowToRecord($0) }
            }
        }
    }

    func deleteActivityRecords(before date: Date) throws {
        try write { db in
            try db.execute(sql: "DELETE FROM activity_record WHERE timestamp < ?", arguments: [date])
        }
    }

    private func rowToRecord(_ row: Row) -> ActivityRecord {
        ActivityRecord(
            id: row.safeString("id"),
            timestamp: row.safeDate("timestamp"),
            activityType: ActivityType(rawValue: row.safeString("activity_type")) ?? .other,
            appBundleID: row.safeString("app_bundle_id"),
            appName: row.safeString("app_name"),
            windowTitle: row["window_title"] as String?,
            duration: row.safeDouble("duration"),
            confidence: row.safeDouble("confidence"),
            metadataJSON: row["metadata_json"] as String?
        )
    }

    // MARK: - Coaching Advice

    func saveCoachingAdvice(_ advice: CoachingAdvice) throws {
        try write { db in
            let dict: [String: DatabaseValue] = [
                "id": advice.id.databaseValue,
                "type": advice.type.rawValue.databaseValue,
                "title": advice.title.databaseValue,
                "description": advice.description.databaseValue,
                "priority": advice.priority.rawValue.databaseValue,
                "action_item": advice.actionItem?.databaseValue ?? .null,
                "timestamp": advice.timestamp.databaseValue,
                "is_read": advice.isRead.databaseValue,
                "is_dismissed": advice.isDismissed.databaseValue
            ]
            try db.execute(sql: """
                INSERT OR REPLACE INTO coaching_advice (id, type, title, description, priority, action_item, timestamp, is_read, is_dismissed)
                VALUES (:id, :type, :title, :description, :priority, :action_item, :timestamp, :is_read, :is_dismissed)
                """, arguments: StatementArguments(dict))
        }
    }

    func fetchActiveAdvice() throws -> [CoachingAdvice] {
        try read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM coaching_advice WHERE is_dismissed = 0 ORDER BY timestamp DESC
                """)
            return rows.map { row in
                CoachingAdvice(
                    id: row.safeString("id"),
                    type: AdviceType(rawValue: row.safeString("type")) ?? .wellbeing,
                    title: row.safeString("title"),
                    description: row.safeString("description"),
                    priority: AdvicePriority(rawValue: row.safeString("priority")) ?? .medium,
                    actionItem: row["action_item"] as String?,
                    timestamp: row.safeDate("timestamp"),
                    isRead: row.safeBool("is_read"),
                    isDismissed: row.safeBool("is_dismissed")
                )
            }
        }
    }

    func dismissAdvice(id: String) throws {
        try write { db in
            try db.execute(sql: "UPDATE coaching_advice SET is_dismissed = 1 WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Journal Entries

    func saveJournalEntry(_ entry: JournalEntry) throws {
        try write { db in
            let tagsData = try JSONEncoder().encode(entry.tags)
            let tagsJSON = String(data: tagsData, encoding: .utf8) ?? "[]"
            let dict: [String: DatabaseValue] = [
                "id": entry.id.databaseValue,
                "date": entry.date.databaseValue,
                "prompt": entry.prompt.databaseValue,
                "content": entry.content.databaseValue,
                "title": entry.title.databaseValue,
                "ai_summary": entry.aiSummary?.databaseValue ?? .null,
                "tags": tagsJSON.databaseValue,
                "is_favorite": entry.isFavorite.databaseValue
            ]
            try db.execute(sql: """
                INSERT OR REPLACE INTO journal_entry (id, date, prompt, content, title, ai_summary, tags, is_favorite)
                VALUES (:id, :date, :prompt, :content, :title, :ai_summary, :tags, :is_favorite)
                """, arguments: StatementArguments(dict))
        }
    }

    func fetchJournalEntries(limit: Int = 50) throws -> [JournalEntry] {
        try read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM journal_entry ORDER BY date DESC LIMIT ?
                """, arguments: [limit])
            return rows.map { row in
                let tagsString = row.safeString("tags")
                let tags = (try? JSONDecoder().decode([String].self, from: Data(tagsString.utf8))) ?? []
                var entry = JournalEntry(
                    prompt: row.safeString("prompt"),
                    content: row.safeString("content"),
                    title: row.safeString("title"),
                    tags: tags
                )
                entry.id = row.safeUUID("id")
                entry.date = row.safeDate("date")
                entry.aiSummary = row["ai_summary"] as String?
                entry.isFavorite = row.safeBool("is_favorite")
                return entry
            }
        }
    }

    // MARK: - Maintenance

    func deleteAllData() throws {
        try write { db in
            try db.execute(sql: "DELETE FROM mood_check_in")
            try db.execute(sql: "DELETE FROM focus_session")
            try db.execute(sql: "DELETE FROM activity_record")
            try db.execute(sql: "DELETE FROM coaching_advice")
            try db.execute(sql: "DELETE FROM journal_entry")
        }
    }

    func vacuum() throws {
        guard let w = dbWriter else { throw DBError.notInitialized }
        try w.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM")
        }
    }
}
