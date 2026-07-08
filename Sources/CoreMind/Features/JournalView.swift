import SwiftUI

struct JournalView: View {
    @Environment(\.deps) var deps
    @State private var entries: [JournalEntry] = []
    @State private var selectedEntry: JournalEntry?
    @State private var isNewEntry = false
    @State private var isLoading = true
    @State private var saveError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            BrandDivider()

            if isLoading {
                Spacer()
                ProgressView().scaleEffect(0.8)
                Spacer()
            } else if isNewEntry {
                JournalEntryEditor(
                    onSave: { entry in
                        do {
                            try deps.database.saveJournalEntry(entry)
                            entries.insert(entry, at: 0)
                            isNewEntry = false
                            selectedEntry = entry
                            loadEntries()
                        } catch {
                            saveError = "Failed to save journal entry: \(error.localizedDescription)"
                        }
                    },
                    onCancel: { isNewEntry = false }
                )
                .transition(reduceMotion ? .identity : .move(edge: .trailing))
            } else if let entry = selectedEntry {
                JournalEntryDetail(
                    entry: entry,
                    onDelete: { deleteEntry(entry) },
                    onBack: { selectedEntry = nil },
                    onToggleFavorite: { toggleFavorite(entry) },
                    onGenerateAI: { await generateAISummary(for: entry) }
                )
                    .transition(reduceMotion ? .identity : .move(edge: .trailing))
            } else if entries.isEmpty {
                emptyView
            } else {
                entriesList
            }
        }
        .frame(width: 360, height: 480)
        .background(Color.surfacePrimary)
        .task { loadEntries() }
        .conditionalAnimation(.easeInOut(duration: 0.2), value: isNewEntry)
        .conditionalAnimation(.easeInOut(duration: 0.2), value: selectedEntry?.id)
        .alert("Save Error", isPresented: .init(get: { saveError != nil }, set: { _ in saveError = nil }), presenting: saveError) { _ in
            Button("OK") { saveError = nil }
        } message: { error in
            Text(error)
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Journal")
                .headlineFont()
            Spacer()
            if selectedEntry != nil {
                Button { selectedEntry = nil } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundColor(.brandPurple)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to entries list")
                .accessibilityHint("Returns to the journal entries overview")
            } else if !isNewEntry {
                Button { isNewEntry = true } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.brandPurple)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New journal entry")
                .accessibilityHint("Opens the editor to create a new entry")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(.brandPurple.opacity(0.5))
            Text("No journal entries yet")
                .headlineFont()
                .foregroundColor(.textSecondary)
            Text("Tap + to write your first entry")
                .captionFont()
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No journal entries yet. Tap plus to write your first entry.")
    }

    private var entriesList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xxs) {
                ForEach(entries) { entry in
                    entryRow(entry)
                        .padding(.horizontal, Spacing.md)
                }
                .padding(.vertical, Spacing.xxs)
            }
        }
    }

    private func entryRow(_ entry: JournalEntry) -> some View {
        Button(action: { selectedEntry = entry }) {
            HStack(spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(LinearGradient.brandVertical)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                        .titleFont()
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: Spacing.xs) {
                        Text(entry.date, style: .date)
                            .smallFont()
                            .foregroundColor(.textTertiary)
                        if !entry.tags.isEmpty {
                            Text(entry.tags.prefix(2).joined(separator: ", "))
                                .smallFont()
                                .foregroundColor(.brandPurple.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.statusOrange)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.sm)
            .background(Color.surfaceSecondary)
            .cornerRadius(Radius.md)
            .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Journal entry: \(entry.title.isEmpty ? "Untitled" : entry.title), \(formattedDate(entry.date))")
        .accessibilityHint("Opens this journal entry for viewing")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        selectedEntry = nil
    }

    private func toggleFavorite(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].isFavorite.toggle()
        selectedEntry = entries[index]
        do {
            try deps.database.saveJournalEntry(entries[index])
        } catch {
            // Revert on failure
            entries[index].isFavorite.toggle()
            selectedEntry = entries[index]
            saveError = "Failed to update entry: \(error.localizedDescription)"
        }
    }

    private func generateAISummary(for entry: JournalEntry) async {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let summary = await deps.wellnessEngine.analyzeCheckIn(
            MoodCheckIn(mood: .okay, energy: .moderate, focus: 5, notes: entry.content)
        )
        await MainActor.run {
            entries[index].aiSummary = summary
            selectedEntry = entries[index]
            do {
                try deps.database.saveJournalEntry(entries[index])
            } catch {
                entries[index].aiSummary = nil
                selectedEntry = entries[index]
                saveError = "Failed to save AI reflection: \(error.localizedDescription)"
            }
        }
    }

    private func loadEntries() {
        isLoading = true
        entries = (try? deps.database.fetchJournalEntries(limit: 100)) ?? []
        isLoading = false
    }
}

// MARK: - Journal Entry Editor

struct JournalEntryEditor: View {
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedPrompt: PromptType = .morning
    @State private var tagInput: String = ""
    @State private var tags: [String] = []

    let onSave: (JournalEntry) -> Void
    let onCancel: () -> Void

    private let prompts: [PromptType: String] = [
        .morning: "What's your intention for today?",
        .evening: "How was your day? What stood out?",
        .stoic: "What Stoic principle resonated with you today?",
        .gratitude: "What are you grateful for right now?",
        .focus: "How focused were you today? What helped or hindered?",
        .creative: "What creative idea or block are you experiencing?"
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                TextField("Entry title...", text: $title)
                    .textFieldStyle(.plain)
                    .headlineFont()
                    .accessibilityLabel("Entry title")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xxs) {
                        ForEach(PromptType.allCases, id: \.rawValue) { prompt in
                            Button(action: { selectedPrompt = prompt }) {
                                Text(prompt.rawValue)
                                    .smallFont()
                                    .fontWeight(selectedPrompt == prompt ? .semibold : .regular)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xxs)
                                    .background(selectedPrompt == prompt ? AnyShapeStyle(LinearGradient.brandSubtle) : AnyShapeStyle(Color.surfaceSecondary))
                                    .cornerRadius(Radius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.sm)
                                            .stroke(selectedPrompt == prompt ? Color.brandPurple : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Prompt: \(prompt.rawValue)")
                            .accessibilityAddTraits(selectedPrompt == prompt ? .isSelected : [])
                        }
                    }
                }
                .accessibilityLabel("Prompt type selector")

                if let promptText = prompts[selectedPrompt] {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "quote.opening")
                            .smallFont()
                            .foregroundColor(.brandPurple)
                        Text(promptText)
                            .captionFont()
                            .italic()
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Writing prompt: \(promptText)")
                }

                TextEditor(text: $content)
                    .bodyFont()
                    .frame(height: 200)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(Radius.sm)
                    .accessibilityLabel("Entry content")
                    .accessibilityHint("Write your journal entry here")

                HStack {
                    TextField("Add tag...", text: $tagInput)
                        .textFieldStyle(.plain)
                        .captionFont()
                        .onSubmit { addTag() }
                        .accessibilityLabel("Add tag")

                    if !tagInput.isEmpty {
                        Button("Add") { addTag() }
                            .buttonStyle(.plain)
                            .captionFont()
                            .foregroundColor(.brandPurple)
                            .accessibilityLabel("Add tag button")
                    }
                }
                .padding(Spacing.sm)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(Radius.sm)

                if !tags.isEmpty {
                    FlowLayout(spacing: Spacing.xxs) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 2) {
                                Text("#\(tag)")
                                    .smallFont()
                                    .foregroundColor(.brandPurple)
                                Button { tags.removeAll { $0 == tag } } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 6))
                                        .foregroundColor(.textTertiary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove tag \(tag)")
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Tag: \(tag)")
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(LinearGradient.brandSubtle)
                            .cornerRadius(Radius.sm)
                        }
                    }
                }

                BrandDivider()

                HStack {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.plain)
                        .captionFont()
                        .foregroundColor(.textSecondary)
                        .accessibilityHint("Discards the current entry and goes back")
                    Spacer()
                    GradientButton(title: "Save Entry", icon: "bookmark.fill") {
                        let entry = JournalEntry(
                            prompt: selectedPrompt.rawValue,
                            content: content,
                            title: title,
                            tags: tags
                        )
                        onSave(entry)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && content.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityHint("Saves this journal entry")
                }
            }
            .padding()
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }
}

// MARK: - Journal Entry Detail

struct JournalEntryDetail: View {
    let entry: JournalEntry
    let onDelete: () -> Void
    let onBack: () -> Void
    let onToggleFavorite: () -> Void
    let onGenerateAI: () async -> Void

    @State private var isGeneratingAI = false

    private static var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .headlineFont()
                        Text(entry.date, style: .date)
                            .captionFont()
                            .foregroundColor(.textTertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.title.isEmpty ? "Untitled" : entry.title), \(Self.dateFormatter.string(from: entry.date))")

                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                            .foregroundColor(.statusOrange)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entry.isFavorite ? "Remove from favorites" : "Mark as favorite")
                    .accessibilityValue(entry.isFavorite ? "Favorited" : "Not favorited")
                }

                BrandDivider()

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Prompt")
                        .smallFont()
                        .foregroundColor(.textTertiary)
                    Text(entry.prompt.isEmpty ? "Free write" : entry.prompt)
                        .captionFont()
                        .italic()
                        .foregroundColor(.brandPurple)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Writing prompt: \(entry.prompt.isEmpty ? "Free write" : entry.prompt)")

                Text(entry.content)
                    .bodyFont()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Entry content")
                    .accessibilityHint(entry.content.prefix(200).trimmingCharacters(in: .whitespacesAndNewlines))

                if !entry.tags.isEmpty {
                    FlowLayout(spacing: Spacing.xxs) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .smallFont()
                                .foregroundColor(.brandPurple)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(LinearGradient.brandSubtle)
                                .cornerRadius(Radius.sm)
                                .accessibilityLabel("Tag: \(tag)")
                        }
                    }
                    .accessibilityLabel("Tags: \(entry.tags.joined(separator: ", "))")
                }

                if let summary = entry.aiSummary {
                    BrandDivider()
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Image(systemName: "sparkles")
                                .smallFont()
                                .foregroundColor(.brandPurple)
                            Text("AI Reflection")
                                .smallFont()
                                .foregroundColor(.textSecondary)
                        }
                        Text(summary)
                            .captionFont()
                            .foregroundColor(.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.sm)
                            .background(LinearGradient.brandSubtle)
                            .cornerRadius(Radius.sm)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("AI reflection: \(summary)")
                }

                BrandDivider()

                HStack {
                    Button(action: onBack) {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "chevron.left")
                                .captionFont()
                            Text("Back")
                                .captionFont()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.brandPurple)
                    .accessibilityLabel("Back to entries list")
                    .accessibilityHint("Returns to the journal overview")

                    Spacer()

                    Button(action: { Task { isGeneratingAI = true; await onGenerateAI(); isGeneratingAI = false } }) {
                        if isGeneratingAI {
                            ProgressView().scaleEffect(0.6)
                        } else {
                    Label("AI Reflect", systemImage: "sparkles")
                        .captionFont()
                        .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.brandPurple)
                    .disabled(isGeneratingAI || entry.aiSummary != nil)
                    .accessibilityLabel("Generate AI reflection")
                    .accessibilityHint("Creates an AI-powered analysis of this journal entry")
                    .accessibilityValue(entry.aiSummary != nil ? "Already generated" : (isGeneratingAI ? "Generating" : "Available"))

                    Button("Delete", action: onDelete)
                        .buttonStyle(.plain)
                        .captionFont()
                        .foregroundColor(.statusRed)
                        .accessibilityHint("Permanently deletes this journal entry. This action cannot be undone.")
                }
            }
            .padding()
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                y += size.height + spacing
                x = 0
            }
            x += size.width + spacing
            height = max(height, y + size.height)
        }

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                y += size.height + spacing
                x = bounds.minX
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
        }
    }
}
