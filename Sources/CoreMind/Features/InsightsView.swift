import SwiftUI
import Charts

// MARK: - Chart Data Models

private struct MoodChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let series: String
}

private struct FocusChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let duration: TimeInterval
    let type: String
}

private struct ActivityChartPoint: Identifiable, Equatable {
    let id = UUID()
    let type: String
    let duration: TimeInterval
}

// MARK: - Insights View

struct InsightsView: View {
    @Environment(\.deps) var deps
    @State private var checkIns: [MoodCheckIn] = []
    @State private var focusSessions: [FocusSession] = []
    @State private var weeklyPattern: String?
    @State private var isLoading = true
    @State private var totalTime: TimeInterval = 0
    @State private var productiveTime: TimeInterval = 0
    @State private var activityBreakdown: [ActivityChartPoint] = []

    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Text("Your Patterns")
                    .headlineFont()
                Spacer()
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.brandPurple)
            }
            .accessibilityAddTraits(.isHeader)

            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else {
                moodChartCard
                focusChartCard
                activityChartCard
                if let pattern = weeklyPattern {
                    patternCard(pattern)
                }
                focusSummaryCard
                streakCard
            }
        }
        .frame(width: 320)
        .padding()
        .background(Color.surfacePrimary)
        .task { await loadInsights() }
    }

    // MARK: - Data Loading

    private func loadInsights() async {
        isLoading = true
        let loaded = await deps.wellnessEngine.loadCheckIns()
        checkIns = loaded

        async let patternTask = deps.wellnessEngine.analyzeWeeklyPattern(checkIns: loaded)

        let records = await deps.activityTracker.allRecords
        let t = records.reduce(0) { $0 + $1.duration }
        let p = records.filter {
            [ActivityType.coding, .writing, .design].contains($0.activityType)
        }.reduce(0) { $0 + $1.duration }

        let breakdown = buildActivityBreakdown(from: records)
        let sessions = (try? deps.database.fetchFocusSessions(limit: 30)) ?? []

        let pattern = await patternTask

        await MainActor.run {
            weeklyPattern = pattern
            totalTime = t
            productiveTime = p
            activityBreakdown = breakdown
            focusSessions = sessions
            isLoading = false
        }
    }

    private func buildActivityBreakdown(from records: [ActivityRecord]) -> [ActivityChartPoint] {
        let grouped = Dictionary(grouping: records) { $0.activityType.rawValue }
        return grouped.map { type, recs in
            ActivityChartPoint(type: type, duration: recs.reduce(0) { $0 + $1.duration })
        }
        .filter { $0.duration > 0 }
        .sorted { $0.duration > $1.duration }
    }

    // MARK: - Mood Trend Chart

    private var moodChartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Mood & Energy Trend")
                    .titleFont()
                    .fontWeight(.medium)
                    .accessibilityAddTraits(.isHeader)

                if checkIns.isEmpty {
                    Text("No check-ins yet. Start with a mood check.")
                        .captionFont()
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.md)
                } else {
                    let points = buildMoodChartPoints()
                    let styleScale: KeyValuePairs<String, Color> = ["Mood": .brandPurple, "Energy": .brandBlue]
                    Chart(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(by: .value("Series", point.series))

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(
                            by: .value("Series", point.series)
                        )
                        .opacity(0.12)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                                .font(.system(size: 10))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.textTertiary)
                                }
                            }
                        }
                    }
                    .chartForegroundStyleScale(styleScale)
                    .chartLegend(position: .bottom, spacing: 4) {
                        HStack(spacing: Spacing.lg) {
                            legendDot(color: .brandPurple, label: "Mood")
                            legendDot(color: .brandBlue, label: "Energy")
                        }
                        .smallFont()
                    }
                    .frame(height: 140)
                    .accessibilityLabel("Mood and energy trend chart")
                }
            }
        }
    }

    private func buildMoodChartPoints() -> [MoodChartPoint] {
        let recent = checkIns.suffix(14)
        var points: [MoodChartPoint] = []
        for check in recent {
            points.append(MoodChartPoint(date: check.timestamp, value: check.mood.score, series: "Mood"))
            points.append(MoodChartPoint(date: check.timestamp, value: check.energy.score, series: "Energy"))
        }
        return points
    }

    // MARK: - Focus Session Chart

    private var focusChartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Focus Sessions")
                    .titleFont()
                    .fontWeight(.medium)
                    .accessibilityAddTraits(.isHeader)

                if focusSessions.isEmpty {
                    Text("No sessions yet. Start a focus timer to see data.")
                        .captionFont()
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.md)
                } else {
                    let points = buildFocusChartPoints()
                    Chart(points) { point in
                        BarMark(
                            x: .value("Date", point.label),
                            y: .value("Minutes", point.duration / 60)
                        )
                        .foregroundStyle(by: .value("Type", point.type))
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 10))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.textTertiary)
                                }
                            }
                        }
                    }
                    .chartLegend(position: .bottom, spacing: 4)
                    .frame(height: 120)
                    .accessibilityLabel("Focus sessions chart")
                }
            }
        }
    }

    private func buildFocusChartPoints() -> [FocusChartPoint] {
        let recent = focusSessions.filter { $0.state == .completed || $0.state == .interrupted }.suffix(10)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return recent.map { session in
            FocusChartPoint(
                label: formatter.string(from: session.startTime),
                duration: session.duration,
                type: session.type.rawValue
            )
        }
    }

    // MARK: - Activity Breakdown Chart

    private var activityChartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Time by Activity")
                    .titleFont()
                    .fontWeight(.medium)
                    .accessibilityAddTraits(.isHeader)

                if activityBreakdown.isEmpty {
                    Text("No activity data yet.")
                        .captionFont()
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.md)
                } else {
                    let top = Array(activityBreakdown.prefix(6))
                    Chart(top) { point in
                        BarMark(
                            x: .value("Minutes", point.duration / 60),
                            y: .value("Activity", point.type)
                        )
                        .foregroundStyle(by: .value("Type", point.type))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("\(Int(point.duration / 60))m")
                                .smallFont()
                                .foregroundColor(.textTertiary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.textTertiary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 10))
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: CGFloat(top.count * 30 + 20))
                    .accessibilityLabel("Activity breakdown chart")
                }
            }
        }
    }

    // MARK: - Pattern Card

    private func patternCard(_ pattern: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles.rectangle.stack")
                .foregroundColor(.brandPurple)
            Text(pattern)
                .bodyFont()
            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            LinearGradient.brandSubtle
                .overlay(Color.surfaceSecondary.opacity(0.7))
        )
        .cornerRadius(Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(LinearGradient.brand, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pattern insight: \(pattern)")
    }

    // MARK: - Focus Summary

    private var focusSummaryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Today's Focus")
                    .titleFont()
                    .fontWeight(.medium)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: Spacing.lg) {
                    statBlock("Total", timeString(from: totalTime))
                    statBlock("Focused", timeString(from: productiveTime))
                    statBlock("Score", totalTime > 0 ? "\(Int(productiveTime / totalTime * 100))%" : "—")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's focus: total \(timeString(from: totalTime)), focused \(timeString(from: productiveTime)), score \(totalTime > 0 ? "\(Int(productiveTime / totalTime * 100)) percent" : "no data")")
    }

    // MARK: - Streak

    private var streakCard: some View {
        CardView {
            HStack(spacing: Spacing.md) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.statusOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check-ins")
                        .captionFont()
                        .foregroundColor(.textSecondary)
                    Text("\(checkIns.count) total")
                        .titleFont()
                        .fontWeight(.medium)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total check-ins: \(checkIns.count)")
    }

    // MARK: - Helpers

    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            Text(label)
                .smallFont()
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(label): \(value)")
    }

    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .smallFont()
                .foregroundColor(.textSecondary)
        }
    }
}
