import AppKit
import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let notificationIdentifier = "com.user.dailylogger.prompt"
    weak var window: NSWindow?

    private var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private lazy var center: UNUserNotificationCenter? = {
        guard isSupported else { return nil }
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        return c
    }()

    override init() {
        super.init()
    }

    func requestAuthorization() {
        guard let center = center else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func postPromptNotification() {
        guard let center = center else {
            // Standalone binary fallback: send native macOS notification via osascript
            let script = "display notification \"Time to log what you did today\" with title \"Daily Reflection\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Daily Reflection"
        content.body = "Time to log what you did today"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                print("Error posting notification: \(error)")
            }
        }
    }

    func removeDeliveredNotifications() {
        guard let center = center else { return }
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.orderFrontRegardless()
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
