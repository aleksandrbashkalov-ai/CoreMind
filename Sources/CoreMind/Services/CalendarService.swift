@preconcurrency import EventKit
import AppKit
import Foundation

actor CalendarService: CalendarServiceProtocol {
    static let shared = CalendarService()

    private let store = EKEventStore()
    private var isAuthorized = false

    private init() {}

    var hasAccess: Bool { isAuthorized }

    func requestAccess() async -> Bool {
        if #available(macOS 14, *) {
            let granted = try? await store.requestFullAccessToEvents()
            isAuthorized = granted ?? false
        } else {
            let granted = try? await store.requestAccess(to: .event)
            isAuthorized = granted ?? false
        }
        return isAuthorized
    }

    // MARK: - Read Calendar

    func currentEvents() async -> [EKEvent] {
        guard isAuthorized else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }

    func upcomingEvent() async -> EKEvent? {
        let events = await currentEvents()
        return events
            .filter { $0.startDate > Date() }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    func currentMeeting() async -> EKEvent? {
        let events = await currentEvents()
        let now = Date()
        return events.first {
            $0.startDate <= now && $0.endDate >= now
        }
    }

    func meetingsToday() async -> [EKEvent] {
        let events = await currentEvents()
        return events.filter { $0.startDate > Date().addingTimeInterval(-86400) }
    }

    func meetingHoursToday() async -> TimeInterval {
        let meetings = await meetingsToday()
        return meetings.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }

    // MARK: - Write Calendar

    func scheduleFocusBlock(duration: TimeInterval = 3600, title: String? = nil) async -> Bool {
        guard isAuthorized else { return false }

        let block = EKEvent(eventStore: store)
        block.title = title ?? "🧘 CoreMind Focus Block"
        block.notes = "Protected focus time — scheduled by CoreMind"
        block.calendar = store.defaultCalendarForNewEvents

        let now = Date()
        let rounded = roundToNextHour(now)
        block.startDate = rounded
        block.endDate = rounded.addingTimeInterval(duration)
        block.addAlarm(EKAlarm(relativeOffset: -300))

        do {
            try store.save(block, span: .thisEvent)
            return true
        } catch {
            Log.error("Failed to schedule focus block: \(error.localizedDescription)")
            return false
        }
    }

    func scheduleBreak(length: TimeInterval = 600) async -> Bool {
        guard isAuthorized else { return false }

        let block = EKEvent(eventStore: store)
        block.title = "☕ CoreMind Break"
        block.notes = "Wellness break — scheduled by CoreMind"
        block.calendar = store.defaultCalendarForNewEvents

        let now = Date()
        block.startDate = now
        block.endDate = now.addingTimeInterval(length)

        do {
            try store.save(block, span: .thisEvent)
            return true
        } catch {
            Log.error("Failed to schedule break: \(error.localizedDescription)")
            return false
        }
    }

    func isInMeeting() async -> Bool {
        await currentMeeting() != nil
    }

    // MARK: - Helpers

    func roundToNextHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: calendar.date(from: components) ?? date) else {
            return date.addingTimeInterval(3600)
        }
        return nextHour
    }
}
