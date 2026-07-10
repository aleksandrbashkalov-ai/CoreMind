import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(\.settings) var settings
    @Environment(\.deps) var deps
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            privacyTab
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 400)
        .background(Color.surfacePrimary)
    }

    // MARK: - General

    @MainActor private var generalTab: some View {
        Form {
            Section("Tracking") {
                Toggle(isOn: Bindable(settings).trackActivity) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Track Activity")
                            .titleFont()
                        Text("Monitor active app usage for insights")
                            .smallFont()
                            .foregroundColor(.textSecondary)
                    }
                }
                .tint(.cmPrimary)
                .accessibilityLabel("Track Activity")
                .accessibilityHint("Monitors active app usage for insights")
            }

            Section("Goals") {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Daily Focus Goal")
                        .titleFont()
                    Slider(
                        value: Bindable(settings).dailyGoalMinutes,
                        in: 30...480,
                        step: 15
                    )
                    .tint(.cmPrimary)
                    .accessibilityLabel("Daily Focus Goal")
                    .accessibilityValue("\(Int(settings.dailyGoalMinutes)) minutes")
                    Text("\(Int(settings.dailyGoalMinutes)) minutes")
                        .smallFont()
                        .foregroundColor(.textTertiary)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Break Interval")
                        .titleFont()
                    Slider(
                        value: Bindable(settings).breakInterval,
                        in: 1800...14400,
                        step: 600
                    )
                    .tint(.cmPrimary)
                    .accessibilityLabel("Break Interval")
                    .accessibilityValue("Every \(Int(settings.breakInterval / 60)) minutes")
                    Text("Every \(Int(settings.breakInterval / 60)) minutes")
                        .smallFont()
                        .foregroundColor(.textTertiary)
                }
            }

            Section("Mindfulness") {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Mood Reminder Interval")
                        .titleFont()
                    Slider(
                        value: Bindable(settings).moodReminderInterval,
                        in: 1800...14400,
                        step: 600
                    )
                    .tint(.cmPrimary)
                    .accessibilityLabel("Mood Reminder Interval")
                    .accessibilityValue("Every \(Int(settings.moodReminderInterval / 60)) minutes")
                    Text("Every \(Int(settings.moodReminderInterval / 60)) minutes")
                        .smallFont()
                        .foregroundColor(.textTertiary)
                }

                Toggle(isOn: Bindable(settings).useAI) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Coaching")
                            .titleFont()
                        Text("On-device mood analysis and personalized tips")
                            .smallFont()
                            .foregroundColor(.textSecondary)
                    }
                }
                .tint(.cmPrimary)
                .accessibilityLabel("Smart Coaching")
                .accessibilityHint("On-device mood analysis and personalized tips")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Privacy

    private var privacyTab: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.cmPrimary)
                        .accessibilityHidden(true)

                    Text("Privacy First")
                        .headlineFont()
                        .accessibilityAddTraits(.isHeader)

                    Text("Everything stays on your device.\nOptional cloud AI only with your consent.")
                        .bodyFont()
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                BrandDivider()

                VStack(alignment: .leading, spacing: Spacing.md) {
                    FeatureRow(icon: "lock.shield", iconColor: .statusGreen) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("On-Device Processing")
                                .titleFont()
                                .fontWeight(.medium)
                            Text("All mood analysis and coaching runs locally")
                                .smallFont()
                                .foregroundColor(.textSecondary)
                        }
                    }

                    FeatureRow(icon: "antenna.radiowaves.left.and.right.slash", iconColor: .cmPrimary) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("No Cloud by Default")
                                .titleFont()
                                .fontWeight(.medium)
                            Text("No data is sent to servers unless enabled")
                                .smallFont()
                                .foregroundColor(.textSecondary)
                        }
                    }

                    FeatureRow(icon: "calendar.badge.clock", iconColor: .cmTeal) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("30-Day Retention")
                                .titleFont()
                                .fontWeight(.medium)
                            Text("Activity data auto-cleans after 30 days")
                                .smallFont()
                                .foregroundColor(.textSecondary)
                        }
                    }
                }

                Button(action: {
                    Task { await deps.permissionsManager.requestAccessibility() }
                }) {
                    Text("Manage Permissions")
                        .bodyFont()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.cmPrimary)
                .accessibilityHint("Opens system accessibility permissions")

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete All Data")
                        .captionFont()
                        .fontWeight(.medium)
                        .foregroundColor(.statusRed)
                }
                .buttonStyle(.plain)
                .hoverEffect()
                .accessibilityHint("Permanently deletes all stored data")
                .confirmationDialog(
                    "Delete All Data",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        deleteAllData()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all mood check-ins, focus sessions, activity records, coaching advice, and journal entries. This action cannot be undone.")
                }
            }
            .padding()
            .alert("Error", isPresented: .init(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            ), presenting: deleteError) { error in
                Text(error)
            }
        }
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.cmPrimary)
                .accessibilityHidden(true)

            Text("CoreMind")
                .font(.system(size: 20, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            Text("v\(Constants.appVersion)")
                .captionFont()
                .foregroundColor(.textTertiary)

            Text("Your mindful productivity companion.\nTrack focus, build habits, stay balanced.")
                .bodyFont()
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()

            Text(Constants.appBundleID)
                .smallFont()
                .foregroundColor(.textTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.surfacePrimary)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Actions

    private func deleteAllData() {
        Task {
            do {
                try deps.database.deleteAllData()
                await MainActor.run { deleteError = nil }
            } catch {
                await MainActor.run { deleteError = error.localizedDescription }
            }
        }
    }
}
