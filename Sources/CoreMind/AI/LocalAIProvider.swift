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
        let text = try await generateResponse(systemPrompt: systemPrompt + "\nRespond with valid JSON.", userMessage: userMessage)

        if let data = text.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }

        if let jsonStart = text.range(of: "```json"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            let jsonChunk = text[jsonStart.upperBound..<jsonEnd.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = jsonChunk.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }

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
            "\"Waste no more time arguing about what a good man should be. Be one.\" — Marcus Aurelius\n\nWhat kind of person do you want to be today?",
            "\"If you want to improve, be content to be thought foolish and stupid.\" — Epictetus\n\nWhat would you attempt if you weren't afraid of looking foolish?",
            "\"The sun has not caught me in bed.\" — Marcus Aurelius\n\nWhat will you win before the day wins you?"
        ]

        let eveningPrompts = [
            "\"I will keep constant watch over my thoughts.\" — Epictetus\n\nHow did you do today? What would you do differently?",
            "\"The wise man sees in the misfortune of others what he should avoid.\" — Seneca\n\nWhat did you learn today?",
            "Review your day with Stoic clarity: What did you do well? What could you improve? What did you endure?",
            "\"What progress have I made? I am beginning to be my own friend.\" — Seneca\n\nDid you act like your own friend today?",
            "\"We suffer more in imagination than in reality.\" — Seneca\n\nWhat worry turned out to be smaller than you thought?"
        ]

        let afternoonPrompts = [
            "\"It's not that we have little time, but rather that we waste much of it.\" — Seneca\n\nIs your current focus aligned with your values?",
            "\"The impediment to action advances action. What stands in the way becomes the way.\" — Marcus Aurelius\n\nWhat obstacle are you facing, and how can it become your path?",
            "\"He who is everywhere is nowhere.\" — Seneca\n\nAre you scattered? Bring your attention back to one thing.",
            "\"The whole future lies in uncertainty: live immediately.\" — Seneca\n\nWhat could you do right now that tomorrow you'd wish you had done?",
            "\"If it is not right, do not do it; if it is not true, do not say it.\" — Marcus Aurelius\n\nIs there something you need to correct?"
        ]

        let pool = isMorning ? morningPrompts : (isEvening ? eveningPrompts : afternoonPrompts)
        return pool.randomElement() ?? morningPrompts[0]
    }

    // MARK: - Mood Analysis

    private func analyzeMood(userMessage: String) -> String {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = userMessage

        var sentiment = "neutral"
        tagger.enumerateTags(in: userMessage.startIndex..<userMessage.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                if score < -0.3 { sentiment = "negative" }
                else if score > 0.3 { sentiment = "positive" }
                else { sentiment = "neutral" }
            }
            return true
        }

        let responses: [String: [String]] = [
            "positive": [
                "Your energy is bright today. Channel it into something meaningful.",
                "That spark you're feeling? It's real. Name it, then use it.",
                "A good day isn't just luck — it's momentum. What's one thing you can build on?",
                "This is the feeling that makes everything easier. Protect it fiercely.",
                "You're in flow. Don't question it — just ride it."
            ],
            "negative": [
                "This feeling is temporary. You have weathered every storm before.",
                "Hard days have a way of carving the most important lessons. What is this one teaching you?",
                "Rest isn't weakness. It's how you make sure you're still standing tomorrow.",
                "Some days are just heavy. You don't have to fix everything right now.",
                "Your feelings are valid. But they are not facts. Sit with them, then let them pass."
            ],
            "neutral": [
                "Stillness is not empty. It's potential waiting to take shape.",
                "Not every moment needs a label. Sometimes just being here is enough.",
                "A calm mind is a clear mind. What's one small thing you actually need right now?",
                "The middle ground isn't boring — it's balanced. Take a breath and look around.",
                "Neutral is not nothing. It's the space between waves. Rest here."
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
            "Rest is not the opposite of focus. It's the fuel for it.",
            "Deep work is rare not because it's hard, but because we avoid the discomfort of concentration. Lean into it.",
            "The most productive people don't work more — they protect their attention better.",
            "A single hour of focused work is worth three hours of distracted busyness."
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
