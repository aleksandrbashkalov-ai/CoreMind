import SwiftUI

/// Provides keyboard navigation shortcuts for the menu bar app.
/// Renders zero-size hidden buttons so SwiftUI captures key equivalents.
struct NavigationShortcuts: View {
    @Binding var currentView: CoreMindView
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            // Navigation: Cmd+1…9
            Button("Home") { currentView = .home }
                .keyboardShortcut("1", modifiers: .command)
            Button("Check In") { currentView = .checkIn }
                .keyboardShortcut("2", modifiers: .command)
            Button("Breathe") { currentView = .breathe }
                .keyboardShortcut("3", modifiers: .command)
            Button("Focus") { currentView = .focus }
                .keyboardShortcut("4", modifiers: .command)
            Button("Wisdom") { currentView = .wisdom }
                .keyboardShortcut("5", modifiers: .command)
            Button("Insights") { currentView = .insights }
                .keyboardShortcut("6", modifiers: .command)
            Button("Journal") { currentView = .journal }
                .keyboardShortcut("7", modifiers: .command)
            Button("Creative Break") { currentView = .creativeBreak }
                .keyboardShortcut("8", modifiers: .command)
            Button("Pro") { currentView = .paywall }
                .keyboardShortcut("9", modifiers: .command)

            // Settings: Cmd+,
            Button("Settings") { onSettings() }
                .keyboardShortcut(",", modifiers: .command)

            // Escape → Home
            Button("Go Home") { currentView = .home }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// ViewModifier that attaches keyboard navigation shortcuts to any view.
extension View {
    func navigationShortcuts(
        currentView: Binding<CoreMindView>,
        onSettings: @escaping () -> Void = {
            openSettingsWindow()
        }
    ) -> some View {
        self.background {
            NavigationShortcuts(
                currentView: currentView,
                onSettings: onSettings
            )
        }
    }
}

/// Opens the CoreMind settings window via the standard AppKit responder chain.
/// SwiftUI's `Settings { ... }` scene registers this selector automatically.
/// Using the standard AppKit selector name (not a custom one) makes this safe.
func openSettingsWindow() {
    // showSettingsWindow: is a standard AppKit/SwiftUI action for Settings scenes.
    // It's registered by SwiftUI's Settings scene — not a custom selector.
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}
