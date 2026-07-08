@preconcurrency import ApplicationServices
import AppKit
import Foundation

actor WindowMonitor: WindowMonitorProtocol {
    static let shared = WindowMonitor()

    private var isMonitoring = false
    private var activeAppID = ""
    private var activeAppName = ""
    private var observation: NSObjectProtocol?

    private let (focusStream, focusContinuation) = AsyncStream<(id: String, name: String)>.makeStream()

    nonisolated var focusChanges: AsyncStream<(id: String, name: String)> { focusStream }

    var currentApp: (id: String, name: String) {
        (activeAppID, activeAppName)
    }

    nonisolated var isAccessibilityAuthorized: Bool {
        AXIsProcessTrusted()
    }

    nonisolated func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func startMonitoring() async {
        guard !isMonitoring else { return }
        isMonitoring = true
        scanActiveApp()

        observation = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let id = app.bundleIdentifier ?? ""
                let name = app.localizedName ?? ""
                Task {
                    await self.handleAppActivation(id: id, name: name)
                }
            }
        }

        Log.info("WindowMonitor started with NSWorkspace notifications")
    }

    func stopMonitoring() async {
        if let observation = observation {
            NotificationCenter.default.removeObserver(observation)
            self.observation = nil
        }
        isMonitoring = false
        Log.info("WindowMonitor stopped")
    }

    private func handleAppActivation(id: String, name: String) {
        if id != activeAppID {
            activeAppID = id
            activeAppName = name
            focusContinuation.yield((id, name))
        }
    }

    private func scanActiveApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let id = frontApp.bundleIdentifier ?? ""
        let name = frontApp.localizedName ?? ""

        if id != activeAppID {
            activeAppID = id
            activeAppName = name
            focusContinuation.yield((id, name))
        }
    }
}
