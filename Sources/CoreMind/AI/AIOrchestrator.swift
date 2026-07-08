import Foundation

actor AIOrchestrator: AIProviderProtocol {
    static let shared = AIOrchestrator()

    private var localProvider: (any AIProvider)?

    private init() {}

    /// Test-only initializer for dependency injection.
    /// When `localProvider` is provided, `initialize()` is a no-op
    /// and the provider is used as-is.
    internal init(localProvider: AIProvider?) {
        self.localProvider = localProvider
    }

    func initialize() {
        guard localProvider == nil else { return }
        localProvider = LocalAIProvider()
        Log.info("AIOrchestrator initialized")
    }

    var isAvailable: Bool {
        localProvider?.isAvailable ?? false
    }

    func smartPrompt(system: String, user: String, preferCloud: Bool = false) async throws -> String {
#if canImport(FoundationModels)
        if #available(macOS 26, *), let fm = try? createFMProvider(tier: preferCloud ? .cloud : .onDevice) {
            do {
                return try await fm.generateResponse(systemPrompt: system, userMessage: user)
            } catch {
                Log.warning("FM provider failed: \(error.localizedDescription), falling back to local")
            }
        }
#endif
        guard let local = localProvider else { throw AIError.modelUnavailable }
        return try await local.generateResponse(systemPrompt: system, userMessage: user)
    }

    func smartStructured<T: Decodable & Sendable>(system: String, user: String, type: T.Type) async throws -> T {
#if canImport(FoundationModels)
        if #available(macOS 26, *), let fm = try? createFMProvider(tier: .onDevice) {
            do {
                return try await fm.generateStructured(systemPrompt: system, userMessage: user, type: type)
            } catch {
                Log.warning("FM structured failed, falling back")
            }
        }
#endif
        guard let local = localProvider else { throw AIError.modelUnavailable }
        return try await local.generateStructured(systemPrompt: system, userMessage: user, type: type)
    }

#if canImport(FoundationModels)
    @available(macOS 26, *)
    private func createFMProvider(tier: AIModelTier) -> FMProvider? {
        FMProvider()
    }
#endif
}
