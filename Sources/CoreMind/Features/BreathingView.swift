import SwiftUI

struct BreathingView: View {
    @State private var selectedExercise: BreathingExercise = .boxBreathing
    @State private var isActive = false
    @State private var phase: BreathingPhase = .idle
    @State private var cycleCount = 0
    @State private var phaseTime: TimeInterval = 0
    @State private var timer: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum BreathingPhase {
        case idle, inhale, hold, exhale, holdAfterExhale

        var label: String {
            switch self {
            case .idle: return "Ready"
            case .inhale: return "Inhale"
            case .hold: return "Hold"
            case .exhale: return "Exhale"
            case .holdAfterExhale: return "Hold"
            }
        }

        var color: Color {
            switch self {
            case .idle: return .gray
            case .inhale: return Color.brandBlue
            case .hold: return .brandPurple
            case .exhale: return .statusGreen
            case .holdAfterExhale: return .statusTeal
            }
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            if isActive {
                activeView
            } else {
                setupView
            }
        }
        .frame(width: 320)
        .padding()
        .background(Color.surfacePrimary)
        .onDisappear {
            timer?.cancel()
            isActive = false
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Text("Breathe")
                    .headlineFont()
                Spacer()
                Image(systemName: "wind")
                    .foregroundColor(.brandPurple)
            }
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: Spacing.sm) {
                ForEach(BreathingExercise.all) { exercise in
                    Button(action: { selectedExercise = exercise }) {
                        HStack(spacing: Spacing.md) {
                            Text(exercise.emoji)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .titleFont()
                                    .fontWeight(.medium)
                                Text(exercise.description)
                                    .smallFont()
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if selectedExercise.id == exercise.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandPurple)
                            }
                        }
                        .padding(Spacing.md)
                        .background(
                            Group {
                                if selectedExercise.id == exercise.id {
                                    LinearGradient.brandSubtle
                                } else {
                                    Color.surfaceSecondary
                                }
                            }
                        )
                        .cornerRadius(Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(selectedExercise.id == exercise.id ? Color.brandPurple : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(exercise.name) breathing")
                    .accessibilityHint(exercise.description)
                    .accessibilityAddTraits(selectedExercise.id == exercise.id ? .isSelected : [])
                }
            }

            GradientButton(title: "Begin \(selectedExercise.name)", icon: "play.fill") {
                startSession()
            }
            .accessibilityHint("Starts the breathing exercise")
        }
    }

    // MARK: - Active

    private var activeView: some View {
        VStack(spacing: Spacing.xxxl) {
            HStack {
                Text(selectedExercise.name)
                    .headlineFont()
                Spacer()
                Text("\(cycleCount)/\(selectedExercise.cycles)")
                    .captionFont()
                    .foregroundColor(.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(selectedExercise.name), cycle \(cycleCount) of \(selectedExercise.cycles)")

            TimerRingView(
                progress: phaseProgress,
                phaseColor: phase.color,
                lineWidth: 5,
                size: 200
            ) {
                VStack(spacing: Spacing.xs) {
                    Text(phase.label)
                        .titleFont()
                        .foregroundColor(phase.color)
                    Text("\(Int(phaseTime))")
                        .timerFont()
                        .foregroundColor(phase.color)
                }
                .transition(reduceMotion ? .identity : .opacity)
            }

            VStack(spacing: Spacing.xxs) {
                Text(phaseInstruction)
                    .captionFont()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 36)

            Button("End Session") {
                endSession()
            }
            .buttonStyle(.plain)
            .captionFont()
            .foregroundColor(.textTertiary)
            .accessibilityHint("Stops the breathing exercise early")
        }
    }

    private var phaseInstruction: String {
        switch phase {
        case .idle: return "Get ready..."
        case .inhale: return "Breathe in slowly"
        case .hold: return "Hold your breath"
        case .exhale: return "Breathe out gently"
        case .holdAfterExhale: return "Pause before next breath"
        }
    }

    private var phaseProgress: Double {
        let total: TimeInterval
        switch phase {
        case .idle: return 0
        case .inhale:
            total = selectedExercise.inhale
        case .hold:
            total = selectedExercise.hold
        case .exhale:
            total = selectedExercise.exhale
        case .holdAfterExhale:
            total = selectedExercise.holdAfterExhale
        }
        guard total > 0 else { return 0 }
        return min(phaseTime / total, 1)
    }

    // MARK: - Session Control

    private func startSession() {
        isActive = true
        cycleCount = 1
        phase = .inhale
        phaseTime = 0

        timer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    phaseTime += 0.1
                    checkPhaseTransition()
                }
            }
        }
    }

    private func checkPhaseTransition() {
        let exercise = selectedExercise
        switch phase {
        case .inhale:
            if phaseTime >= exercise.inhale {
                if exercise.hold > 0 {
                    phase = .hold
                    phaseTime = 0
                } else if exercise.holdAfterExhale > 0 {
                    phase = .exhale
                    phaseTime = 0
                } else {
                    phase = .exhale
                    phaseTime = 0
                }
            }
        case .hold:
            if phaseTime >= exercise.hold {
                phase = .exhale
                phaseTime = 0
            }
        case .exhale:
            if phaseTime >= exercise.exhale {
                if exercise.holdAfterExhale > 0 {
                    phase = .holdAfterExhale
                    phaseTime = 0
                } else {
                    cycleCount += 1
                    if cycleCount > exercise.cycles {
                        phase = .idle
                    } else {
                        phase = .inhale
                        phaseTime = 0
                    }
                }
            }
        case .holdAfterExhale:
            if phaseTime >= exercise.holdAfterExhale {
                cycleCount += 1
                if cycleCount > exercise.cycles {
                    phase = .idle
                } else {
                    phase = .inhale
                    phaseTime = 0
                }
            }
        case .idle:
            break
        }
    }

    private func endSession() {
        timer?.cancel()
        timer = nil
        isActive = false
        phase = .idle
        cycleCount = 0
        phaseTime = 0
    }
}
