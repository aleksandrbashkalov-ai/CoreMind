import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Environment(\.settings) var settings
    @Environment(\.deps) var deps
    @State private var step = 0
    @State private var selectedGoals: Set<String> = []
    @State private var oneThing = ""
    @State private var permAccessibility = false
    @State private var permNotifications = false
    @State private var permCalendar = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            switch step {
            case 0: welcomeView
            case 1: permissionsView
            case 2: goalsView
            case 3: oneThingView
            default: EmptyView()
            }

            Spacer()

            if step < totalSteps - 1 {
                HStack {
                    if step > 0 {
                        Button("Back") {
                            if !reduceMotion { withAnimation { step -= 1 } } else { step -= 1 }
                        }
                        .buttonStyle(.plain)
                        .hoverEffect()
                        .captionFont()
                        .foregroundColor(.textSecondary)
                        .accessibilityHint("Go to the previous step")
                    }
                    Spacer()
                    GradientButton(
                        title: step == 0 ? "Get Started" : "Continue",
                        icon: step == 0 ? nil : "arrow.right"
                    ) {
                        if !reduceMotion { withAnimation { step += 1 } } else { step += 1 }
                    }
                    .accessibilityHint(step == 0 ? "Begin onboarding" : "Proceed to the next step")
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxl)
            } else {
                GradientButton(title: "Start Using CoreMind", icon: "sparkles") {
                    completeOnboarding()
                }
                .controlSize(.large)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxl)
                .accessibilityHint("Complete onboarding and open CoreMind")
            }

            if step > 0 && step < totalSteps - 1 {
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i <= step ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(Color.gray.opacity(0.25)))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, Spacing.md)
                .accessibilityLabel("Step \(step + 1) of \(totalSteps)")
            }
        }
        .frame(width: 400, height: 500)
        .background(Color.surfacePrimary)
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient.brandVertical)
                .accessibilityHidden(true)

            Text("Welcome to CoreMind")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(LinearGradient.brandVertical)
                .accessibilityAddTraits(.isHeader)

            Text("Your mindful productivity companion.\nTrack focus, build habits, and stay balanced — right from your menu bar.")
                .bodyFont()
                .multilineTextAlignment(.center)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Permissions

    private var permissionsView: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.brandPurple)
                    .accessibilityHidden(true)
                Text("Permissions")
                    .headlineFont()
                    .accessibilityAddTraits(.isHeader)
            }

            Text("CoreMind needs a few permissions to help you. You can change these later in System Settings.")
                .captionFont()
                .foregroundColor(.textSecondary)

            permissionCard(
                icon: "keyboard",
                title: "Accessibility",
                description: "Detect your active app for automatic time tracking.",
                granted: permAccessibility,
                action: requestAccessibility
            )

            permissionCard(
                icon: "bell.badge",
                title: "Notifications",
                description: "Send break reminders and wellness nudges.",
                granted: permNotifications,
                action: requestNotifications
            )

            permissionCard(
                icon: "calendar",
                title: "Calendar",
                description: "Check meeting status and suggest focus blocks.",
                granted: permCalendar,
                action: requestCalendar
            )
        }
        .padding(.horizontal, Spacing.xxl)
    }

    private func permissionCard(icon: String, title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .foregroundColor(granted ? .statusGreen : .textSecondary)
                .font(.title3)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .titleFont()
                    .fontWeight(.medium)
                Text(description)
                    .smallFont()
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if !granted {
                GradientButton(title: "Allow", icon: nil, action: action)
                    .accessibilityLabel("Allow \(title)")
                    .accessibilityHint(description)
            }
        }
        .padding(Spacing.md)
        .background(Color.surfaceSecondary)
        .cornerRadius(Radius.md)
        .cardShadow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title): \(granted ? "Granted" : "Not granted")")
    }

    // MARK: - Goals

    private var goalsView: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.brandPurple)
                    .accessibilityHidden(true)
                Text("Your Goals")
                    .headlineFont()
                    .accessibilityAddTraits(.isHeader)
            }

            Text("What do you want to improve?")
                .captionFont()
                .foregroundColor(.textSecondary)

            ForEach(Goal.allCases, id: \.self) { goal in
                Button(action: { toggleGoal(goal.rawValue) }) {
                    HStack(spacing: Spacing.md) {
                        Text(goal.icon)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.rawValue)
                                .titleFont()
                                .fontWeight(.medium)
                            Text(goal.description)
                                .smallFont()
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                        if selectedGoals.contains(goal.rawValue) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.brandPurple)
                        }
                    }
                    .padding(Spacing.md)
                    .background(
                        Group {
                            if selectedGoals.contains(goal.rawValue) {
                                LinearGradient.brandSubtle
                            } else {
                                Color.surfaceSecondary
                            }
                        }
                    )
                    .cornerRadius(Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(selectedGoals.contains(goal.rawValue) ? Color.brandPurple : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(goal.rawValue) goal: \(goal.description)")
                .accessibilityAddTraits(selectedGoals.contains(goal.rawValue) ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: - One Thing

    private var oneThingView: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "quote.opening")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient.brandVertical)
                .accessibilityHidden(true)

            Text("Your North Star")
                .headlineFont()
                .accessibilityAddTraits(.isHeader)

            Text("What's the one thing that matters most to you right now?")
                .captionFont()
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            TextField("e.g. Finish the project proposal", text: $oneThing)
                .textFieldStyle(.roundedBorder)
                .bodyFont()
                .frame(maxWidth: 280)
                .accessibilityLabel("Your one thing")
                .accessibilityHint("What matters most to you right now")

            Text("You can change this anytime from the menu bar.")
                .smallFont()
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: - Actions

    private func toggleGoal(_ goal: String) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }

    private func requestAccessibility() {
        Task {
            await deps.permissionsManager.requestAccessibility()
            await MainActor.run { permAccessibility = true }
        }
    }

    private func requestNotifications() {
        Task {
            let granted = await deps.permissionsManager.requestNotifications()
            await MainActor.run { permNotifications = granted }
        }
    }

    private func requestCalendar() {
        Task {
            let granted = await deps.calendarService.requestAccess()
            await MainActor.run { permCalendar = granted }
        }
    }

    @MainActor private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        if !oneThing.isEmpty {
            settings.oneThing = oneThing
        }
        if let window = NSApp.windows.first(where: { $0.title == "Welcome to CoreMind" }) {
            window.close()
        }
    }
}

enum Goal: String, CaseIterable {
    case focus = "Deep Focus"
    case wellbeing = "Wellbeing & Balance"
    case productivity = "Productivity"
    case mindfulness = "Mindfulness & Calm"
    case creative = "Creative Flow"

    var icon: String {
        switch self {
        case .focus: return "🎯"
        case .wellbeing: return "💚"
        case .productivity: return "⚡"
        case .mindfulness: return "🧘"
        case .creative: return "🎨"
        }
    }

    var description: String {
        switch self {
        case .focus: return "Build deep work habits and minimize distractions"
        case .wellbeing: return "Prevent burnout with breaks and wellness nudges"
        case .productivity: return "Optimize your time and energy throughout the day"
        case .mindfulness: return "Daily check-ins, breathing, and Stoic prompts"
        case .creative: return "Protect creative time and manage context switching"
        }
    }
}
