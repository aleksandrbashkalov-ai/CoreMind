import SwiftUI

struct FocusView: View {
    @Environment(\.deps) var deps
    @State private var state: FocusState = .idle
    @State private var focusElapsed: TimeInterval = 0
    @State private var breakElapsed: TimeInterval = 0
    @State private var sessionType: FocusSessionType = .pomodoro
    @State private var currentSession: FocusSession?
    @State private var interruptions = 0
    @State private var saveError: String?

    private let timer = TimerManager(interval: 1.0)

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            if state == .idle || state == .completed || state == .interrupted {
                setupView
            } else {
                activeView
            }
        }
        .frame(width: 320)
        .padding()
        .background(Color.surfacePrimary)
        .onDisappear {
            timer.cancel()
        }
        .alert("Save Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Focus Session")
                    .headlineFont()
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Image(systemName: "target")
                    .foregroundColor(.cmPrimary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: Spacing.sm) {
                ForEach(FocusSessionType.allCases.filter { $0 != .custom }, id: \.self) { type in
                    Button(action: { sessionType = type }) {
                        Text(type.rawValue)
                            .smallFont()
                            .fontWeight(sessionType == type ? .semibold : .regular)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Group {
                                    if sessionType == type {
                                        Color.selectedBg
                                    } else {
                                        Color.surfaceSecondary
                                    }
                                }
                            )
                            .cornerRadius(Radius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .stroke(sessionType == type ? Color.cmPrimary : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                    .accessibilityLabel("\(type.rawValue) session type")
                    .accessibilityAddTraits(sessionType == type ? .isSelected : [])
                }
            }

            if state == .completed || state == .interrupted, let session = currentSession {
                sessionSummary(session)
            }

            Button(action: startSession) {
                Label("Start \(sessionType.rawValue)", systemImage: "play.fill")
                    .captionFont()
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cmPrimary)
            .controlSize(.large)
            .accessibilityHint("Begins a new focus session")
        }
    }

    // MARK: - Active

    private var activeView: some View {
        VStack(spacing: Spacing.xxxl) {
            HStack {
                Text(sessionType.rawValue)
                    .headlineFont()
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }

            TimerRingView(
                progress: progress,
                phaseColor: state == .break_ ? .statusTeal : .cmPrimary,
                lineWidth: 6,
                size: 200
            ) {
                VStack(spacing: Spacing.xxs) {
                    Text(state == .break_ ? "Break" : "Focus")
                        .captionFont()
                        .foregroundColor(.textSecondary)
                    Text(timeString(from: remainingTime))
                        .timerFont()
                }
            }
            .accessibilityLabel("\(state == .break_ ? "Break" : "Focus") phase, \(timeString(from: remainingTime)) remaining")

            HStack(spacing: Spacing.lg) {
                Button("Interrupt") {
                    interruptSession()
                }
                .buttonStyle(.plain)
                .bodyFont()
                .foregroundColor(.statusOrange)
                .accessibilityHint("Pause the current session without completing it")

                Button(state == .break_ ? "Skip Break" : "Complete") {
                    if state == .break_ {
                        finishSession(completed: true)
                    } else {
                        timer.cancel()
                        completeFocusPhase()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(state == .break_ ? .statusTeal : .cmPrimary)
                .accessibilityHint(state == .break_ ? "End the break early and finish the session" : "Complete the current focus session")
            }
        }
    }

    private func sessionSummary(_ session: FocusSession) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text("Session Complete")
                .titleFont()
                .fontWeight(.semibold)
            Text("Duration: \(timeString(from: session.duration))")
                .captionFont()
                .foregroundColor(.textSecondary)
            Text("Interruptions: \(session.interruptions)")
                .captionFont()
                .foregroundColor(.textSecondary)
            if let summary = session.activitySummary {
                Text(summary)
                    .captionFont()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSecondary)
        .cornerRadius(Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sessionSummaryAccessibilityLabel(session))
    }

    private func sessionSummaryAccessibilityLabel(_ session: FocusSession) -> String {
        var label = "Session complete. Duration: \(timeString(from: session.duration)). Interruptions: \(session.interruptions)."
        if let summary = session.activitySummary {
            label += " Summary: \(summary)"
        }
        return label
    }

    // MARK: - Helpers

    private var currentDuration: TimeInterval {
        sessionType.defaultDuration
    }

    private var currentBreakDuration: TimeInterval {
        sessionType.breakDuration
    }

    private var remainingTime: TimeInterval {
        if state == .break_ {
            return max(0, currentBreakDuration - breakElapsed)
        }
        return max(0, currentDuration - focusElapsed)
    }

    private var progress: Double {
        if state == .break_ {
            return min(1, breakElapsed / currentBreakDuration)
        }
        return min(1, focusElapsed / currentDuration)
    }

    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Session Control

    private func startSession() {
        state = .focusing
        focusElapsed = 0
        breakElapsed = 0
        interruptions = 0

        let session = FocusSession(
            startTime: Date(),
            duration: currentDuration,
            type: sessionType,
            state: .focusing,
            interruptions: 0,
            focusScore: 0
        )
        currentSession = session

        // Persist immediately for crash resilience
        do {
            try deps.database.saveFocusSession(session)
        } catch {
            saveError = "Failed to save session: \(error.localizedDescription)"
        }

        startFocusTimer()
    }

    private func startFocusTimer() {
        timer.start { [self] elapsed in
            focusElapsed = elapsed
            return elapsed >= currentDuration ? .stop : .continue
        } onComplete: { [self] in
            completeFocusPhase()
        }
    }

    private func completeFocusPhase() {
        // Save focus phase completion before starting break
        if var session = currentSession {
            session.endTime = Date()
            session.state = .completed
            session.focusScore = 1.0
            do {
                try deps.database.saveFocusSession(session)
            } catch {
                saveError = "Failed to save focus phase: \(error.localizedDescription)"
            }
            currentSession = session
        }

        state = .break_
        breakElapsed = 0
        startBreakTimer()
    }

    private func startBreakTimer() {
        timer.start { [self] elapsed in
            breakElapsed = elapsed
            return elapsed >= currentBreakDuration ? .stop : .continue
        } onComplete: { [self] in
            finishSession(completed: true)
        }
    }

    private func interruptSession() {
        timer.cancel()
        interruptions += 1
        finishSession(completed: false)
    }

    private func finishSession(completed: Bool) {
        state = completed ? .completed : .interrupted

        Task { [weak deps, session = currentSession] in
            guard let deps else { return }
            let suggestion = await deps.coachingService.getContextualSuggestion()
            let finalSession = FocusSession(
                id: session?.id ?? UUID(),
                startTime: session?.startTime ?? Date(),
                endTime: Date(),
                duration: session?.duration ?? focusElapsed,
                type: sessionType,
                state: completed ? .completed : .interrupted,
                interruptions: interruptions,
                focusScore: completed ? 1.0 : 0.5,
                activitySummary: suggestion
            )
            await MainActor.run {
                currentSession = finalSession
            }
            do {
                try deps.database.saveFocusSession(finalSession)
            } catch {
                await MainActor.run {
                    saveError = "Failed to finalize session: \(error.localizedDescription)"
                }
            }
        }
    }
}
