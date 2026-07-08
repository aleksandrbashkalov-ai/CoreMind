@preconcurrency import ApplicationServices
import AppKit
import Foundation
import UserNotifications

struct PermissionState: Codable, Sendable {
    var accessibility: Bool
    var notifications: Bool

    static let initial = PermissionState(accessibility: false, notifications: false)
}

actor PermissionsManager: PermissionsManagerProtocol {
    static let shared = PermissionsManager()

    private init() {}

    func currentState() async -> PermissionState {
        PermissionState(
            accessibility: AXIsProcessTrusted(),
            notifications: await checkNotificationPermission()
        )
    }

    func requestAccessibility() async {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
