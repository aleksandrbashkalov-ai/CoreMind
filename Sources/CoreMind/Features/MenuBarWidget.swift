import SwiftUI
import EventKit

enum CoreMindView: String, CaseIterable {
    case home = "Home"
    case checkIn = "Check In"
    case breathe = "Breathe"
    case focus = "Focus"
    case wisdom = "Wisdom"
    case insights = "Insights"
    case journal = "Journal"
    case creativeBreak = "Creative Break"
    case paywall = "Pro"

    var icon: String {
        switch self {
        case .home: return "house"
        case .checkIn: return "face.smiling"
        case .breathe: return "wind"
        case .focus: return "target"
        case .wisdom: return "quote.opening"
        case .insights: return "chart.pie"
        case .journal: return "book.closed"
        case .creativeBreak: return "paintpalette"
        case .paywall: return "crown"
        }
    }
}

@MainActor
struct MenuBarView: View {
    @Environment(\.settings) var settings
    @Environment(\.deps) var deps
    @State private var currentView: CoreMindView = .home
    @State private var suggestion: String = ""
    @State private var activeApp: String = ""
    @State private var nudges: [ProactiveNudge] = []
    @State private var nextEvent: EKEvent?
    @State private var isInMeeting = false

    var body: some View {
        VStack(spacing: 0) {
            switch currentView {
            case .home:
                homeView
            case .checkIn:
                CheckInView()
            case .breathe:
                BreathingView()
            case .focus:
                FocusView()
            case .wisdom:
                CoachingView()
            case .insights:
                InsightsView()
            case .journal:
                JournalView()
            case .creativeBreak:
                CreativeBreakView()
            case .paywall:
                PaywallView()
            }
        }
        .frame(width: currentView == .home ? 300 : 360)
        .background(Color.surfacePrimary)
        .navigationShortcuts(currentView: $currentView)
        .task {
            await refresh()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task { await refresh() }
        }
    }

    // MARK: - Home

    private var homeView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection
                BrandDivider()
                oneThingSection
                BrandDivider()
                nudgeSection
                calendarSection
                quickActionsSection
                BrandDivider()
                statusSection
                Spacer().frame(height: Spacing.xs)
                appSection
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16))
                .foregroundColor(.brandPurple)

            Text("CoreMind")
                .headlineFont()

            Spacer()

            HStack(spacing: Spacing.xxs) {
                Circle()
                    .fill(settings.trackActivity ? Color.statusGreen : Color.statusRed)
                    .frame(width: 5, height: 5)
                    .accessibilityLabel(settings.trackActivity ? "Tracking active" : "Tracking paused")
                Text(Date(), style: .time)
                    .captionFont()
                    .foregroundColor(.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CoreMind header")
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - One Thing

    private var oneThingSection: some View {
        VStack(spacing: Spacing.xxs) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.brandPurple)
                Text("ONE THING")
                    .smallFont()
                    .fontWeight(.semibold)
                    .foregroundColor(.textTertiary)
                Spacer()
            }
            .accessibilityLabel("One thing section")
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            HStack {
                Image(systemName: "pencil.line")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                TextField("What matters most today?", text: Bindable(settings).oneThing)
                    .textFieldStyle(.plain)
                    .bodyFont()
                    .accessibilityLabel("What matters most today?")
                    .accessibilityValue(settings.oneThing.isEmpty ? "Empty" : settings.oneThing)
                if !settings.oneThing.isEmpty {
                    Button { settings.oneThing = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear one thing")
                    .accessibilityHint("Removes your current focus goal")
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
    }

    // MARK: - Proactive Nudges

    @ViewBuilder
    private var nudgeSection: some View {
        if !nudges.isEmpty {
            VStack(spacing: Spacing.xs) {
                HStack {
                    Image(systemName: "bell.badge")
                        .smallFont()
                        .foregroundColor(.statusOrange)
                    Text("SUGGESTIONS")
                        .smallFont()
                        .fontWeight(.semibold)
                        .foregroundColor(.statusOrange)
                    Spacer()
                }
                .accessibilityLabel("Suggestions section")
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)

                ForEach(Array(nudges.prefix(2))) { nudge in
                    nudgeCard(nudge)
                        .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.bottom, Spacing.xxs)

            if nudges.count > 2 {
                BrandDivider()
            }
        }
    }

    private func nudgeCard(_ nudge: ProactiveNudge) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: nudge.type.icon)
                .foregroundColor(nudgeColor(nudge.type))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(nudge.title)
                    .titleFont()
                    .fontWeight(.medium)
                Text(nudge.message)
                    .captionFont()
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(nudge.title): \(nudge.message)")

            Spacer(minLength: Spacing.sm)

            if let action = nudge.actionTitle {
                GradientButton(title: action, icon: nil) {
                    handleNudgeAction(nudge)
                }
                .accessibilityLabel(action)
                .accessibilityHint("Opens the relevant feature for this suggestion")
            }

            Button {
                Task { await deps.proactiveNudgeService.dismissNudge(nudge.id) }
            } label: {
                Image(systemName: "xmark")
                    .smallFont()
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .accessibilityLabel("Dismiss suggestion")
            .accessibilityHint("Removes this suggestion from the list")
        }
        .padding(Spacing.sm)
        .background(Color.surfaceSecondary)
        .cornerRadius(Radius.md)
        .cardShadow()
        .accessibilityElement(children: .contain)
    }

    private func nudgeColor(_ type: NudgeType) -> Color {
        switch type {
        case .burnout: return .statusRed
        case .distraction: return .statusOrange
        case .breakReminder: return .brandBlue
        case .movement: return .statusGreen
        case .creativeBreak: return .brandPurple
        case .focusSession: return .brandPurple
        case .breathing: return .statusTeal
        case .deepWork: return .brandBlue
        case .streak: return .statusOrange
        }
    }

    private func handleNudgeAction(_ nudge: ProactiveNudge) {
        switch nudge.type {
        case .breathing, .breakReminder:
            currentView = .breathe
        case .focusSession, .distraction:
            currentView = .focus
        case .creativeBreak:
            currentView = .breathe
        case .movement:
            break
        case .burnout:
            currentView = .wisdom
        case .deepWork, .streak:
            currentView = .focus
        }
        Task { await deps.proactiveNudgeService.dismissNudge(nudge.id) }
    }

    // MARK: - Calendar

    @ViewBuilder
    private var calendarSection: some View {
        if nextEvent != nil || isInMeeting {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isInMeeting ? "calendar.badge.exclamationmark" : "calendar")
                    .captionFont()
                    .foregroundColor(isInMeeting ? .statusRed : .brandPurple)

                if isInMeeting {
                    Text("In a meeting")
                        .captionFont()
                        .fontWeight(.medium)
                        .foregroundColor(.statusRed)
                } else if let event = nextEvent {
                    Text("Next: \(event.title ?? "Event")")
                        .captionFont()
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                    Text(event.startDate, style: .time)
                        .captionFont()
                        .foregroundColor(.textTertiary)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(calendarAccessibilityLabel)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xxs)
        }
    }

    private var calendarAccessibilityLabel: String {
        if isInMeeting {
            return "Currently in a meeting"
        } else if let event = nextEvent, let title = event.title {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Next event: \(title) at \(formatter.string(from: event.startDate))"
        }
        return "Calendar information"
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: Spacing.xxs) {
            HStack {
                Text("Quick Actions")
                    .smallFont()
                    .fontWeight(.semibold)
                    .foregroundColor(.textTertiary)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            ForEach([CoreMindView.checkIn, .breathe, .focus, .wisdom, .journal, .creativeBreak, .insights, .paywall], id: \.rawValue) { view in
                Button(action: { currentView = view }) {
                    FeatureRow(icon: view.icon, iconColor: .brandPurple) {
                        Text(view.rawValue)
                            .bodyFont()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xxs)
                .accessibilityLabel("Open \(view.rawValue)")
            }
        }
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(settings.trackActivity ? Color.statusGreen : Color.statusRed)
                .frame(width: 5, height: 5)
            Text(settings.trackActivity ? "Tracking" : "Paused")
                .smallFont()
                .foregroundColor(.textTertiary)
            Spacer()
            if !suggestion.isEmpty {
                Text(suggestion)
                    .captionFont()
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusAccessibilityLabel)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var statusAccessibilityLabel: String {
        let tracking = settings.trackActivity ? "Tracking active" : "Tracking paused"
        if suggestion.isEmpty {
            return tracking
        }
        return "\(tracking). Suggestion: \(suggestion)"
    }

    private var appSection: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "app.dashed")
                .smallFont()
                .foregroundColor(.textTertiary)
            Text(activeApp.isEmpty ? "No active app" : activeApp)
                .captionFont()
                .foregroundColor(.textTertiary)
            Spacer()
            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .captionFont()
            .foregroundColor(.brandPurple)
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens CoreMind settings window")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(activeApp.isEmpty ? "No active application" : "Active application: \(activeApp)")
    }

    // MARK: - Refresh

    private func refresh() async {
        async let appTask = deps.windowMonitor.currentApp
        async let textTask = deps.coachingService.getContextualSuggestion()
        async let eventTask = deps.calendarService.upcomingEvent()
        async let meetingTask = deps.calendarService.isInMeeting()

        let (app, text, event, inMeeting) = await (appTask, textTask, eventTask, meetingTask)
        let currentNudges = await deps.proactiveNudgeService.currentNudges

        await MainActor.run {
            activeApp = app.name
            suggestion = text
            nextEvent = event
            isInMeeting = inMeeting
            nudges = currentNudges
        }
    }
}
