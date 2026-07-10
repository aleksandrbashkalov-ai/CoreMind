import SwiftUI

struct CheckInView: View {
    @Environment(\.deps) var deps
    @State private var selectedMood: Mood = .okay
    @State private var selectedEnergy: EnergyLevel = .moderate
    @State private var focusLevel: Double = 5
    @State private var notes: String = ""
    @State private var reflection: String?
    @State private var suggestedAction: String?
    @State private var isLoading = false
    @State private var isDone = false
    @State private var reflectionOpacity: Double = 0
    @State private var reflectionOffset: Double = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if isDone {
                doneView
            } else {
                checkInForm
            }
        }
        .frame(width: 320)
        .padding()
        .background(Color.surfacePrimary)
    }

    // MARK: - Form

    private var checkInForm: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("How are you?")
                    .headlineFont()
                Spacer()
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.cmPrimary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Mood").captionFont().foregroundColor(.textSecondary)
                HStack(spacing: Spacing.sm) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        Button(action: { selectedMood = mood }) {
                            VStack(spacing: 2) {
                                Text(mood.emoji).font(.title2)
                                Text(mood.rawValue).smallFont()
                                    .foregroundColor(selectedMood == mood ? .cmPrimary : .textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Group {
                                    if selectedMood == mood {
                                        Color.selectedBg
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .cornerRadius(Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(selectedMood == mood ? Color.cmPrimary : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect()
                        .accessibilityLabel("Mood: \(mood.rawValue)")
                        .accessibilityAddTraits(selectedMood == mood ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Energy").captionFont().foregroundColor(.textSecondary)
                HStack(spacing: Spacing.sm) {
                    ForEach(EnergyLevel.allCases, id: \.self) { energy in
                        Button(action: { selectedEnergy = energy }) {
                            VStack(spacing: 2) {
                                Text(energy.emoji).font(.title2)
                                Text(energy.rawValue).smallFont()
                                    .foregroundColor(selectedEnergy == energy ? .cmPrimary : .textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Group {
                                    if selectedEnergy == energy {
                                        Color.selectedBg
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .cornerRadius(Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(selectedEnergy == energy ? Color.cmPrimary : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect()
                        .accessibilityLabel("Energy: \(energy.rawValue)")
                        .accessibilityAddTraits(selectedEnergy == energy ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Focus: \(Int(focusLevel))/10")
                    .captionFont()
                    .foregroundColor(.textSecondary)
                Slider(value: $focusLevel, in: 1...10, step: 1)
                    .tint(.cmPrimary)
                    .accessibilityLabel("Focus level")
                    .accessibilityValue(Text("\(Int(focusLevel)) out of 10"))
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Notes (optional)")
                    .captionFont()
                    .foregroundColor(.textSecondary)
                TextEditor(text: $notes)
                    .bodyFont()
                    .frame(height: 60)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(Radius.sm)
            }

            HStack {
                Button("Skip") {
                    isDone = true
                }
                .buttonStyle(.plain)
                .captionFont()
                .foregroundColor(.textSecondary)

                Spacer()

                Button(action: submitCheckIn) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 80)
                    } else {
                        Text("Reflect")
                            .captionFont()
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cmPrimary)
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 32))
                    .foregroundColor(.cmAmber)

                Text("Reflection")
                    .headlineFont()
            }

            if let reflection = reflection {
                Text(reflection)
                    .bodyFont()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Color.surfaceSecondary)
                    .cornerRadius(Radius.lg)
                    .opacity(reflectionOpacity)
                    .offset(y: reflectionOffset)
                    .onAppear {
                        if reduceMotion {
                            reflectionOpacity = 1
                            reflectionOffset = 0
                        } else {
                            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                                reflectionOpacity = 1
                                reflectionOffset = 0
                            }
                        }
                    }
                    .accessibilityAddTraits(.isHeader)
            }

            if let action = suggestedAction {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "hand.point.up")
                        .foregroundColor(.cmTeal)
                    Text(action)
                        .smallFont()
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.surfaceSecondary)
                .cornerRadius(Radius.md)
                .opacity(reflectionOpacity)
            }

            Spacer()

            VStack(spacing: Spacing.sm) {
                Button("Check in again") {
                    resetForm()
                }
                .buttonStyle(.plain)
                .bodyFont()
                .foregroundColor(.cmPrimary)

                Button("Done") {
                    isDone = false
                    resetForm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.cmPrimary)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func submitCheckIn() {
        isLoading = true
        let checkIn = MoodCheckIn(
            mood: selectedMood,
            energy: selectedEnergy,
            focus: Int(focusLevel),
            notes: notes
        )

        Task {
            async let reflectionTask = deps.wellnessEngine.analyzeCheckIn(checkIn)
            let action = deps.wellnessEngine.suggestAction(for: checkIn)
            let reflection = await reflectionTask

            await MainActor.run {
                self.reflection = reflection
                self.suggestedAction = action
                self.isLoading = false
                self.isDone = true
            }
        }
    }

    private func resetForm() {
        selectedMood = .okay
        selectedEnergy = .moderate
        focusLevel = 5
        notes = ""
        reflection = nil
        suggestedAction = nil
        isDone = false
        reflectionOpacity = 0
        reflectionOffset = 20
    }
}
