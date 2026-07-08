import Foundation

// Foundation Models framework is available on macOS 26+
// Conditional compilation allows building on older macOS while supporting FM on newer systems

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26, *)
// Thread safety: called exclusively through AIOrchestrator actor.
// LanguageModelSession is thread-safe per Apple's Foundation Models framework.
final class FMProvider: AIProvider, @unchecked Sendable {
    let tier: AIModelTier
    var isAvailable: Bool { isModelAvailable }

    private var model: (any LanguageModel)?
    private var session: LanguageModelSession?
    private var isModelAvailable = false

    init(tier: AIModelTier = .onDevice) {
        self.tier = tier
        setupModel()
    }

    private func setupModel() {
        switch tier {
        case .onDevice:
            model = SystemLanguageModel()
        case .cloud:
            if #available(macOS 27, *) {
                model = PrivateCloudComputeLanguageModel()
            } else {
                model = SystemLanguageModel()
            }
        }

        if let model = model {
            session = LanguageModelSession(model: model)
            isModelAvailable = true
        }
    }

    func generateResponse(systemPrompt: String, userMessage: String) async throws -> String {
        guard let session = session else { throw AIError.modelUnavailable }

        let prompt = """
        System: \(systemPrompt)

        User: \(userMessage)

        Response:
        """

        let response = try await session.respond(to: prompt)
        return response.content
    }

    func generateStructured<T: Decodable & Sendable>(systemPrompt: String, userMessage: String, type: T.Type) async throws -> T {
        guard let session = session else { throw AIError.modelUnavailable }

        let prompt = """
        System: \(systemPrompt)

        User: \(userMessage)

        Respond with valid JSON that matches the expected schema.
        """

        let response = try await session.respond(to: prompt)
        guard let data = response.content.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw AIError.generationFailed("Failed to decode structured output")
        }
        return decoded
    }
}

#else

@available(macOS 26, *)
// Thread safety: no mutable state, always returns modelUnavailable error.
// Conforms to AIProvider protocol through AIOrchestrator actor.
final class FMProvider: AIProvider, @unchecked Sendable {
    let tier: AIModelTier = .onDevice
    var isAvailable: Bool { false }

    func generateResponse(systemPrompt: String, userMessage: String) async throws -> String {
        throw AIError.modelUnavailable
    }

    func generateStructured<T: Decodable & Sendable>(systemPrompt: String, userMessage: String, type: T.Type) async throws -> T {
        throw AIError.modelUnavailable
    }
}
#endif
