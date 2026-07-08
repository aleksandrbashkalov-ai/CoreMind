import Foundation

enum AIModelTier: Sendable {
    case onDevice
    case cloud
}

protocol AIProvider: Sendable {
    var tier: AIModelTier { get }
    var isAvailable: Bool { get }
    func generateResponse(systemPrompt: String, userMessage: String) async throws -> String
    func generateStructured<T: Decodable & Sendable>(systemPrompt: String, userMessage: String, type: T.Type) async throws -> T
}

enum AIError: Error {
    case modelUnavailable
    case generationFailed(String)
    case timeout
    case notSupported
}
