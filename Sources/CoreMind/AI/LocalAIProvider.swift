import Foundation
import NaturalLanguage

// Thread safety: all methods are called exclusively through the AIOrchestrator actor.
// The class is @unchecked Sendable only because NLTagger is non-Sendable — in practice
// every method is synchronous (no suspension points), so actor re-entrancy is not a concern,
// and NLTagger instances are created locally within each method to avoid shared mutable state.
final class LocalAIProvider: AIProvider, @unchecked Sendable {
    let tier: AIModelTier = .onDevice
    var isAvailable: Bool { true }

    func generateResponse(systemPrompt: String, userMessage: String) async throws -> String {
        let combined = "\(systemPrompt)\n\(userMessage)".lowercased()

        if systemPrompt.contains("stoic") || systemPrompt.contains("prompt") {
            return generateStoicPrompt(userMessage: userMessage)
        }
        if systemPrompt.contains("mood") || systemPrompt.contains("reflection") {
            return analyzeMood(userMessage: userMessage)
        }
        if systemPrompt.contains("focus") || systemPrompt.contains("pattern") {
            return generateFocusInsight(userMessage: userMessage)
        }

        return generateGenericResponse(combined: combined, userMessage: userMessage)
    }

    func generateStructured<T: Decodable & Sendable>(systemPrompt: String, userMessage: String, type: T.Type) async throws -> T {
        // Strategy: generate text first, then try to parse as JSON for the requested type.
        // This provides graceful fallback when FM is unavailable (macOS < 26).
        let text = try await generateResponse(systemPrompt: systemPrompt + "\nRespond with valid JSON.", userMessage: userMessage)

        // Try 1: direct JSON parse from response
        if let data = text.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }

        // Try 2: extract JSON block from markdown (```json ... ```)
        if let jsonStart = text.range(of: "```json"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            let jsonChunk = text[jsonStart.upperBound..<jsonEnd.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = jsonChunk.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }

        // Try 3: wrap text in common JSON structures for simple Decodable types
        let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "'")
        let wrappers: [String] = [
            "{\"value\": \"\(sanitized)\"}",
            "{\"text\": \"\(sanitized)\"}",
            "{\"message\": \"\(sanitized)\"}",
            "{\"content\": \"\(sanitized)\"}"
        ]
        for wrapped in wrappers {
            if let data = wrapped.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }

        // Try 4: empty object — works for types with all-optional/default properties
        if let decoded = try? JSONDecoder().decode(T.self, from: Data("{}".utf8)) {
            return decoded
        }

        throw AIError.generationFailed("LocalAIProvider cannot generate structured output for \(T.self). Use FMProvider (macOS 26+) for structured decoding.")
    }

    // MARK: - Stoic Prompts

    private func generateStoicPrompt(userMessage: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let isMorning = hour < 12
        let isEvening = hour > 17

        let morningPrompts = [
            "\"The happiness of your life depends upon the quality of your thoughts.\" — Marcus Aurelius\n\nWhat thoughts will you cultivate today?",
            "\"The first hour of the morning is the rudder of the day.\" — Henry Ward Beecher\n\nWhat is your intention for today?",
            "\"Waste no more time arguing about what a good man should be. Be one.\" — Marcus Aurelius\n\nWhat kind of person do you want to be today?"
        ]

        let eveningPrompts = [
            "\"I will keep constant watch over my thoughts.\" — Epictetus\n\nHow did you do today? What would you do differently?",
            "\"The wise man sees in the misfortune of others what he should avoid.\" — Seneca\n\nWhat did you learn today?",
            "Review your day with Stoic clarity: What did you do well? What could you improve? What did you endure?"
        ]

        let afternoonPrompts = [
            "\"It's not that we have little time, but rather that we waste much of it.\" — Seneca\n\nIs your current focus aligned with your values?",
            "\"The impediment to action advances action. What stands in the way becomes the way.\" — Marcus Aurelius\n\nWhat obstacle are you facing, and how can it become your path?",
            "\"He who is everywhere is nowhere.\" — Seneca\n\nAre you scattered? Bring your attention back to one thing."
        ]

        let pool = isMorning ? morningPrompts : (isEvening ? eveningPrompts : afternoonPrompts)
        return pool.randomElement() ?? morningPrompts[0]
    }

    // MARK: - Mood Analysis

    private func analyzeMood(userMessage: String) -> String {
        // Create a local NLTagger per invocation to avoid shared mutable state.
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = userMessage

        var sentiment = "neutral"
        tagger.enumerateTags(in: userMessage.startIndex..<userMessage.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                if score < -0.3 { sentiment = "negative" } else if score > 0.3 { sentiment = "positive" } else { sentiment = "neutral" }
            }
            return true
        }

        let responses: [String: [String]] = [
            "positive": [
                "Your energy is bright today. Channel it into something meaningful.",
                "Joy is a sign of alignment. What's working well?",
                "This positive state is your creative fuel. Protect it."
            ],
            "negative": [
                "This feeling is temporary. You have weathered every storm before.",
                "Even the strongest trees bend in the wind. Allow yourself grace.",
                "Difficult days are the soil in which resilience grows."
            ],
            "neutral": [
                "Stillness is not empty. It's potential waiting to take shape.",
                "A calm mind is a clear mind. What do you truly need right now?",
                "Balance is not the absence of feeling, but the wisdom to observe it."
            ]
        ]

        let pool = responses[sentiment] ?? responses["neutral"] ?? []
        guard let pick = pool.randomElement() else { return "Take a moment to breathe." }
        return pick
    }

    // MARK: - Focus Insights

    private func generateFocusInsight(userMessage: String) -> String {
        let insights = [
            "Focus is like a muscle — it grows stronger with consistent training.",
            "Your mind wanders not because you're weak, but because it's trying to protect you. Bring it back gently.",
            "The depth of your focus determines the quality of your output.",
            "Rest is not the opposite of focus. It's the fuel for it."
        ]
        return insights.randomElement() ?? "Focus is like a muscle — it grows stronger with consistent training."
    }

    // MARK: - Generic

    private func generateGenericResponse(combined: String, userMessage: String) -> String {
        if combined.contains("grateful") || combined.contains("gratitude") {
            return "Gratitude is the foundation of resilience. What small thing brought you joy today?"
        }
        if combined.contains("stress") || combined.contains("anxious") || combined.contains("overwhelm") {
            return "Take a breath. You don't need to do everything at once. What's the one thing that matters most right now?"
        }
        if combined.contains("focus") || combined.contains("distract") {
            return "Bring your attention back to the present task. The future will wait five minutes."
        }
        return "Thank you for sharing. Reflect on this moment — what do you need right now?"
    }
}
