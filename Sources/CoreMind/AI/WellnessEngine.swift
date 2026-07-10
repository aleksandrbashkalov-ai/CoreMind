import Foundation

actor WellnessEngine: WellnessEngineProtocol {
    static let shared = WellnessEngine()

    private let ai: AIProviderProtocol
    private let database: DatabaseServiceProtocol

    init(
        ai: AIProviderProtocol = AIOrchestrator.shared,
        database: DatabaseServiceProtocol = DatabaseService.shared
    ) {
        self.ai = ai
        self.database = database
    }

    // MARK: - Mood Analysis

    func analyzeCheckIn(_ checkIn: MoodCheckIn) async -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "morning" : (hour > 17 ? "evening" : "afternoon")
        let recentCheckIns: String = {
            let past = (try? database.fetchMoodCheckIns(limit: 5)) ?? []
            guard !past.isEmpty else { return "none yet" }
            let scores = past.map { "\($0.mood.rawValue) (focus \($0.focus)/10)" }.joined(separator: ", ")
            return scores
        }()

        let prompt = """
        Reflect on this check-in:
        - Time: \(timeOfDay)
        - Mood: \(checkIn.mood.rawValue) (\(checkIn.mood.emoji))
        - Energy: \(checkIn.energy.rawValue)
        - Focus level: \(checkIn.focus)/10
        - Notes: \(checkIn.notes.isEmpty ? "none" : checkIn.notes)
        - Recent trend: \(recentCheckIns)

        Write a brief, compassionate reflection (2-3 sentences). Connect the current state to the recent trend if available. End with a gentle, specific suggestion for right now.
        """

        let reflection: String
        do {
            reflection = try await ai.smartPrompt(system: "You are a calm, empathetic wellness coach who notices patterns and offers gentle guidance.", user: prompt, preferCloud: false)
        } catch {
            reflection = generateFallbackReflection(for: checkIn)
        }

        var saved = checkIn
        saved.aiReflection = reflection
        do {
            try database.saveMoodCheckIn(saved)
        } catch {
            Log.error("Failed to save check-in reflection: \(error.localizedDescription)")
        }
        return reflection
    }

    private func generateFallbackReflection(for checkIn: MoodCheckIn) -> String {
        if checkIn.mood == .terrible || checkIn.mood == .bad {
            return "Rough days are part of the terrain. You don't have to solve everything — just showing up counts."
        } else if checkIn.mood == .great || checkIn.mood == .good {
            return "This is a good moment. Don't rush past it. Notice what's working and let it sink in."
        } else {
            return "You're here. That's enough. Take a slow breath and see what the next moment brings."
        }
    }

    // MARK: - Action Suggestions

    nonisolated func suggestAction(for checkIn: MoodCheckIn) -> String {
        switch (checkIn.mood, checkIn.energy) {
        case (.terrible, _), (.bad, .exhausted), (.bad, .low):
            return "Try a 2-minute breathing exercise"
        case (.bad, _), (.okay, .exhausted):
            return "Journal about what's weighing on you"
        case (.okay, _):
            return "Take a short walk or stretch break"
        case (.good, .high), (.good, .full), (.great, _):
            return "Capture this energy — write down three things you're grateful for"
        default:
            return "Close your eyes and take three deep breaths"
        }
    }

    // MARK: - Stoic Prompt Generation

    func generateDailyPrompt() async -> StoicPrompt {
        let hour = Calendar.current.component(.hour, from: Date())
        let promptType = hour < 12 ? "morning" : (hour > 17 ? "evening" : "afternoon")

        let systemPrompt = """
        You are a Stoic philosopher. Generate a brief, original Stoic-style prompt for the \(promptType).
        Format: a short quote-like insight (1-2 sentences), followed by a reflective question.
        Author should be "CoreMind" or a classical Stoic figure.
        """

        do {
            let response = try await ai.smartPrompt(system: systemPrompt, user: "Give me a Stoic prompt for the \(promptType).", preferCloud: false)
            return parsePrompt(from: response)
        } catch {
            return generateFallbackPrompt(for: promptType)
        }
    }

    private func parsePrompt(from response: String) -> StoicPrompt {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }
        let text = lines.first ?? response
        let author = lines.dropFirst().first(where: { $0.contains("—") || $0.contains("~") }) ?? "— Marcus Aurelius"
        return StoicPrompt(
            date: Date(),
            text: text,
            author: author.replacingOccurrences(of: "^[—~]\\s*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces),
            reflection: nil
        )
    }

    private func generateFallbackPrompt(for type: String) -> StoicPrompt {
        let prompts: [(String, String)] = [
            ("The happiness of your life depends upon the quality of your thoughts.", "Marcus Aurelius"),
            ("Waste no more time arguing about what a good man should be. Be one.", "Marcus Aurelius"),
            ("We suffer more in imagination than in reality.", "Seneca"),
            ("The chief task in life is simply this: to identify and separate matters.", "Epictetus"),
            ("It's not what happens to you, but how you react that matters.", "Epictetus")
        ]
        let pick = prompts.randomElement() ?? ("The happiness of your life depends upon the quality of your thoughts.", "Marcus Aurelius")
        return StoicPrompt(
            date: Date(),
            text: pick.0,
            author: pick.1,
            reflection: nil
        )
    }

    // MARK: - Pattern Analysis

    func loadCheckIns() async -> [MoodCheckIn] {
        (try? database.fetchMoodCheckIns(limit: 100)) ?? []
    }

    func analyzeWeeklyPattern(checkIns: [MoodCheckIn]) async -> String {
        guard !checkIns.isEmpty else { return "Not enough data yet. Keep checking in daily." }

        let avgMood = checkIns.map { $0.mood.score }.reduce(0, +) / Double(checkIns.count)
        let avgEnergy = checkIns.map { $0.energy.score }.reduce(0, +) / Double(checkIns.count)
        let avgFocus = checkIns.map { $0.focus }.reduce(0, +) / checkIns.count

        let systemPrompt = "You are an insightful wellness coach. Analyze these weekly patterns briefly."
        let userPrompt = """
        This week: avg mood \(String(format: "%.1f", avgMood))/5, avg energy \(String(format: "%.1f", avgEnergy))/5, avg focus \(avgFocus)/10.
        Provide a 1-2 sentence pattern insight.
        """

        do {
            return try await ai.smartPrompt(system: systemPrompt, user: userPrompt, preferCloud: false)
        } catch {
            if avgMood < 3 { return "Your mood has been low this week. Consider prioritizing rest and self-compassion." }
            if avgMood > 4 { return "You're thriving! Notice what's working and protect it." }
            return "Steady and consistent. You're building resilience."
        }
    }

    // MARK: - Context-Based Suggestions

    func getContextualSuggestion(currentApp: String, activeMinutes: TimeInterval) async -> String {
        if activeMinutes > 7200 {
            return "You've been at it for \(Int(activeMinutes / 60)) minutes. Your brain needs a reset — try 2 minutes of box breathing."
        }
        if currentApp.lowercased().contains("figma") || currentApp.lowercased().contains("design") {
            return "Creative work stretches the mind. A short step back can help you see the bigger picture."
        }
        if currentApp.lowercased().contains("xcode") || currentApp.lowercased().contains("code") || currentApp.lowercased().contains("terminal") {
            return "Deep in the flow. Don't forget: your body needs a stretch more than your code does."
        }
        return "Wherever you are, be all there."
    }
}
