import SwiftUI

struct CoachingView: View {
    @Environment(\.deps) var deps
    @State private var prompt: StoicPrompt?
    @State private var isLoading = true
    @State private var reflection: String = ""
    @State private var hasReflected = false
    @State private var report: CoachingReport?
    @State private var advice: [CoachingAdvice] = []
    @State private var saveError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                HStack {
                    Text("Wisdom")
                        .headlineFont()
                    Spacer()
                    Image(systemName: "quote.opening")
                        .foregroundColor(.cmPrimary)
                }
                .accessibilityAddTraits(.isHeader)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                } else {
                    stoicPromptCard
                    if !reflection.isEmpty || hasReflected {
                        reflectionCard
                    }
                    BrandDivider()
                    dailyInsightCard
                    adviceSection
                }
            }
            .padding()
        }
        .frame(width: 360)
        .background(Color.surfacePrimary)
        .task { await load() }
        .alert("Save Error", isPresented: .init(get: { saveError != nil }, set: { _ in saveError = nil }), presenting: saveError) { _ in
            Button("OK") { saveError = nil }
        } message: { error in
            Text(error)
        }
    }

    private func load() async {
        isLoading = true
        prompt = await deps.wellnessEngine.generateDailyPrompt()
        report = await deps.coachingService.generateDailyReport()
        advice = await deps.coachingService.generateRealtimeAdvice()
        isLoading = false
    }

    // MARK: - Stoic Prompt

    private var stoicPromptCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Today's Wisdom")
                    .titleFont()
                    .fontWeight(.semibold)
                Spacer()
                Text(prompt?.date ?? Date(), style: .date)
                    .smallFont()
                    .foregroundColor(.textTertiary)
            }
            .accessibilityElement(children: .combine)

            if let prompt = prompt {
                VStack(spacing: Spacing.sm) {
                    Text(prompt.text)
                        .bodyFont()
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("— \(prompt.author)")
                        .captionFont()
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Quote: \(prompt.text) — \(prompt.author)")

                BrandDivider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    TextField("Your reflection...", text: $reflection, axis: .vertical)
                        .textFieldStyle(.plain)
                        .bodyFont()
                        .lineLimit(3...6)
                        .padding(Spacing.sm)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(Radius.sm)
                        .accessibilityLabel("Your reflection")
                        .accessibilityHint("Write your thoughts on today's wisdom")

                    HStack {
                        Spacer()
                        if hasReflected {
                            Text("Saved")
                                .smallFont()
                                .foregroundColor(.statusGreen)
                                .accessibilityLabel("Reflection saved")
                        }
                        Button(action: submitReflection) {
                            Text(hasReflected ? "Update" : "Reflect")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.cmPrimary)
                        .disabled(reflection.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityHint("Submits your reflection on this wisdom")
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.surfaceSecondary)
        .cornerRadius(Radius.lg)
        .cardShadow()
    }

    // MARK: - Reflection

    private var reflectionCard: some View {
        CardView {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "pencil.line")
                    .foregroundColor(.cmPrimary)
                Text("Reflection recorded")
                    .bodyFont()
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reflection recorded")
        }
    }

    // MARK: - Daily Insight

    private var dailyInsightCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.cmPrimary)
                    Text("Daily Insight")
                        .titleFont()
                        .fontWeight(.semibold)
                    Spacer()
                }

                if let report = report {
                    Text(report.summary)
                        .bodyFont()
                        .foregroundColor(.textSecondary)
                }

                if let trend = report?.moodTrend {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "waveform.path.ecg")
                            .smallFont()
                            .foregroundColor(.statusGreen)
                        Text(trend)
                            .captionFont()
                            .foregroundColor(.textTertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Mood trend: \(trend)")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily insight: \(report?.summary ?? "No data yet")")
    }

    // MARK: - Advice

    @ViewBuilder
    private var adviceSection: some View {
        if !advice.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Suggestions")
                    .titleFont()
                    .fontWeight(.semibold)

                ForEach(advice.filter { !$0.isDismissed }) { item in
                    adviceCard(item)
                }
            }
        }
    }

    private func adviceCard(_ item: CoachingAdvice) -> some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(priorityColor(item.priority))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .titleFont()
                    .fontWeight(.medium)
                Text(item.description)
                    .captionFont()
                    .foregroundColor(.textSecondary)
            }

            Spacer(minLength: Spacing.sm)

            Button {
                Task { await deps.coachingService.dismissAdvice(item.id) }
            } label: {
                Image(systemName: "xmark")
                    .smallFont()
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss suggestion")
            .accessibilityHint("Removes this suggestion from the list")
        }
        .padding(Spacing.sm)
        .background(Color.surfaceSecondary)
        .cornerRadius(Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggestion: \(item.title). \(item.description). Priority: \(item.priority).")
    }

    private func priorityColor(_ priority: AdvicePriority) -> Color {
        switch priority {
        case .critical: return .statusRed
        case .high: return .statusOrange
        case .medium: return .cmTeal
        case .low: return .statusGreen
        }
    }

    // MARK: - Actions

    private func submitReflection() {
        guard let prompt = prompt else { return }
        hasReflected = true
        let entry = JournalEntry(
            prompt: "Stoic Reflection",
            content: reflection,
            title: "Reflection on \"\(prompt.text.prefix(40))...\"",
            tags: ["stoic", "reflection"]
        )
        do {
            try deps.database.saveJournalEntry(entry)
        } catch {
            saveError = "Failed to save reflection: \(error.localizedDescription)"
        }
    }
}
