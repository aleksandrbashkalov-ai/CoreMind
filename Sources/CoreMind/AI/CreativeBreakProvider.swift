import Foundation

struct CreativePrompt: Sendable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let suggestion: String
    let category: CreativeCategory
}

enum CreativeCategory: String, Sendable, CaseIterable {
    case visual = "Visual"
    case writing = "Writing"
    case mindfulness = "Mindfulness"
    case music = "Music"
    case nature = "Nature"

    var icon: String {
        switch self {
        case .visual: return "🎨"
        case .writing: return "✍️"
        case .mindfulness: return "🧘"
        case .music: return "🎵"
        case .nature: return "🌿"
        }
    }
}

actor CreativeBreakService: CreativeBreakServiceProtocol {
    static let shared = CreativeBreakService()

    private init() {}

    func randomPrompt() async -> CreativePrompt {
        Self.prompts.randomElement() ?? Self.prompts[0]
    }

    func prompts(for category: CreativeCategory) async -> [CreativePrompt] {
        Self.prompts.filter { $0.category == category }
    }

    static let prompts: [CreativePrompt] = [
        CreativePrompt(title: "Describe a peaceful place",
            description: "Close your eyes and imagine a place where you feel completely at ease.",
            suggestion: "A quiet beach at sunset with gentle waves",
            category: .visual),
        CreativePrompt(title: "Abstract shapes",
            description: "Let your mind wander through colors and forms.",
            suggestion: "Floating geometric shapes in warm colors",
            category: .visual),
        CreativePrompt(title: "Future self",
            description: "Picture yourself one year from now, having grown and learned.",
            suggestion: "A person standing on a mountain peak at sunrise",
            category: .visual),
        CreativePrompt(title: "Gratitude scene",
            description: "Think of something you're grateful for and visualize it.",
            suggestion: "A warm kitchen filled with the smell of fresh bread",
            category: .visual)
    ]
}

// MARK: - Image Playground (macOS 27+)

#if canImport(ImagePlayground)
import ImagePlayground

@available(macOS 27, *)
actor ImagePlaygroundProvider: CreativeBreakImageProviding {
    static let shared = ImagePlaygroundProvider()

    private init() {}

    nonisolated var isAvailable: Bool {
        true
    }

    func generateImage(description: String) async throws -> Data? {
        guard #available(macOS 27, *) else { return nil }
        let concept = await ImagePlaygroundConcept(description: description)
        let result = try await ImagePlayground.session.generateImage(from: concept)
        return try await result.dataRepresentation
    }
}

@available(macOS 27, *)
extension ImagePlaygroundConcept {
    convenience init(description: String) async {
        self.init(description: description, style: .illustration)
    }
}

#else

actor ImagePlaygroundProvider: CreativeBreakImageProviding {
    static let shared = ImagePlaygroundProvider()
    nonisolated var isAvailable: Bool { false }
    func generateImage(description: String) async throws -> Data? { nil }
}

#endif

protocol CreativeBreakImageProviding: Actor {
    static var shared: Self { get }
    nonisolated var isAvailable: Bool { get }
    func generateImage(description: String) async throws -> Data?
}
