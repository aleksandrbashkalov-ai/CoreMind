import Foundation

struct JournalEntry: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var prompt: String
    var content: String
    var title: String
    var aiSummary: String?
    var tags: [String]
    var isFavorite: Bool

    init(prompt: String = "", content: String = "", title: String = "", tags: [String] = []) {
        self.date = Date()
        self.prompt = prompt
        self.content = content
        self.title = title
        self.tags = tags
        self.isFavorite = false
    }
}

struct StoicPrompt: Codable, Sendable, Identifiable {
    var id = UUID()
    var date: Date
    var text: String
    var author: String
    var reflection: String?
    var followUp: String?
}

enum PromptType: String, Codable, Sendable, CaseIterable {
    case morning = "Morning Reflection"
    case evening = "Evening Review"
    case stoic = "Stoic Wisdom"
    case gratitude = "Gratitude"
    case focus = "Focus Check"
    case creative = "Creative Block"
}
