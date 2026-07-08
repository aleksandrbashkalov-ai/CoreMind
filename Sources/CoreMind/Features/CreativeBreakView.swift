import SwiftUI

struct CreativeBreakView: View {
    @Environment(\.deps) var deps
    @State private var prompt: CreativePrompt
    @State private var selectedCategory: CreativeCategory?
    @State private var isTimerRunning = false
    @State private var timerMinutes: Double = 5
    @State private var elapsed: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        _prompt = State(initialValue: CreativeBreakService.prompts.randomElement() ?? CreativeBreakService.prompts[0])
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            headerSection
            BrandDivider()
            categorySection
            promptCard
            timerSection
            Spacer()
        }
        .frame(width: 320)
        .padding()
        .background(Color.surfacePrimary)
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Creative Break")
                .headlineFont()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Image(systemName: "paintpalette")
                .foregroundColor(.brandPurple)
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xxs) {
                Button(action: { selectedCategory = nil }) {
                    Text("All")
                        .smallFont()
                        .fontWeight(selectedCategory == nil ? .semibold : .regular)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(selectedCategory == nil ? AnyShapeStyle(LinearGradient.brandSubtle) : AnyShapeStyle(Color.surfaceSecondary))
                        .cornerRadius(Radius.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All categories")
                .accessibilityAddTraits(selectedCategory == nil ? [.isSelected] : [])

                ForEach(CreativeCategory.allCases, id: \.rawValue) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack(spacing: 2) {
                            Text(category.icon)
                                .font(.system(size: 10))
                            Text(category.rawValue)
                                .smallFont()
                        }
                        .fontWeight(selectedCategory == category ? .semibold : .regular)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(selectedCategory == category ? AnyShapeStyle(LinearGradient.brandSubtle) : AnyShapeStyle(Color.surfaceSecondary))
                        .cornerRadius(Radius.sm)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(category.rawValue) category")
                    .accessibilityAddTraits(selectedCategory == category ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - Prompt

    private var promptCard: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text(prompt.category.icon)
                    .font(.title2)
                Text(prompt.category.rawValue)
                    .captionFont()
                    .foregroundColor(.brandPurple)
            }

            Text(prompt.title)
                .font(.system(size: 18, weight: .semibold))
                .multilineTextAlignment(.center)

            Text(prompt.description)
                .bodyFont()
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Text("\"\(prompt.suggestion)\"")
                .captionFont()
                .italic()
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(Spacing.sm)
                .background(LinearGradient.brandSubtle)
                .cornerRadius(Radius.sm)

            GradientButton(title: "New Prompt", icon: "shuffle") {
                newPrompt()
            }
            .transaction { t in
                if reduceMotion { t.disablesAnimations = true }
            }
            .accessibilityHint("Shuffles to a new creative prompt")
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSecondary)
        .cornerRadius(Radius.lg)
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prompt: \(prompt.title). \(prompt.description)")
    }

    // MARK: - Timer

    private var timerSection: some View {
        VStack(spacing: Spacing.md) {
            BrandDivider()

            Text("Take a Break")
                .titleFont()
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            if isTimerRunning {
                VStack(spacing: Spacing.sm) {
                    Text(formattedTime(from: timerMinutes * 60 - elapsed))
                        .timerFont()
                        .foregroundColor(.brandPurple)
                        .accessibilityLabel("Break time remaining: \(formattedTime(from: timerMinutes * 60 - elapsed))")

                    Button("End Break") {
                        endTimer()
                    }
                    .buttonStyle(.plain)
                    .captionFont()
                    .foregroundColor(.textSecondary)
                    .accessibilityHint("Stops the break timer early")
                }
            } else {
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.lg) {
                        breakOption(minutes: 3, icon: "☕️")
                        breakOption(minutes: 5, icon: "🧘")
                        breakOption(minutes: 10, icon: "🌿")
                        breakOption(minutes: 15, icon: "🌊")
                    }

                    Slider(value: $timerMinutes, in: 1...30, step: 1)
                        .tint(.brandPurple)
                        .accessibilityLabel("Break duration")
                        .accessibilityValue("\(Int(timerMinutes)) minutes")

                    Text("\(Int(timerMinutes)) min break")
                        .captionFont()
                        .foregroundColor(.textTertiary)
                        .accessibilityLabel("\(Int(timerMinutes)) minute break selected")

                    GradientButton(title: "Start Break", icon: "play.fill") {
                        startTimer()
                    }
                    .accessibilityHint("Starts a \(Int(timerMinutes)) minute creative break timer")
                }
            }
        }
    }

    private func breakOption(minutes: Int, icon: String) -> some View {
        Button(action: { timerMinutes = Double(minutes); startTimer() }) {
            VStack(spacing: 2) {
                Text(icon).font(.title3)
                Text("\(minutes)m")
                    .smallFont()
                    .foregroundColor(.brandPurple)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes) minute break")
        .accessibilityHint("Starts a \(minutes) minute break timer")
    }

    // MARK: - Actions

    private func newPrompt() {
        Task {
            if let category = selectedCategory {
                let filtered = await deps.creativeBreakService.prompts(for: category)
                await MainActor.run {
                    prompt = filtered.randomElement() ?? CreativeBreakService.prompts.randomElement() ?? CreativeBreakService.prompts[0]
                }
            } else {
                await MainActor.run {
                    prompt = CreativeBreakService.prompts.randomElement() ?? CreativeBreakService.prompts[0]
                }
            }
        }
    }

    private func startTimer() {
        isTimerRunning = true
        elapsed = 0
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let done = await MainActor.run {
                    elapsed += 1
                    if elapsed >= timerMinutes * 60 {
                        endTimer()
                        return true
                    }
                    return false
                }
                if done { break }
            }
        }
    }

    private func endTimer() {
        timerTask?.cancel()
        timerTask = nil
        isTimerRunning = false
        elapsed = 0
    }

    private func formattedTime(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
