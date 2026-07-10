import SwiftUI
import AppKit
import UserNotifications

@main
struct CoreMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(\.settings, SettingsStore.shared)
                .environment(\.deps, appDelegate.deps)
        } label: {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(\.settings, SettingsStore.shared)
                .environment(\.deps, appDelegate.deps)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 500)
    }
}

extension Color {
    static let appAccent = Color.cmPrimary
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let deps = AppDependencies()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if !deps.settings.hasCompletedOnboarding {
            showOnboarding()
        }

        Task { await deps.initialize() }
        requestPermissions()
    }

    private var onboardingWindow: NSWindow?

    private func showOnboarding() {
        let hostingView = NSHostingView(
            rootView: OnboardingView()
                .environment(\.settings, SettingsStore.shared)
                .environment(\.deps, deps)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to CoreMind"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
        onboardingWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if !SettingsStore.shared.hasCompletedOnboarding {
                    SettingsStore.shared.hasCompletedOnboarding = true
                }
            }
        }
    }

    private var onboardingWindowObserver: NSObjectProtocol?

    private func requestPermissions() {
        Task {
            _ = await deps.permissionsManager.requestNotifications()
            let state = await deps.permissionsManager.currentState()
            if !state.accessibility {
                await deps.permissionsManager.requestAccessibility()
            }
            let calGranted = await deps.calendarService.requestAccess()
            Log.info("Calendar access: \(calGranted)")
        }
    }
}
