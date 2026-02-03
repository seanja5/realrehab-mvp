import Foundation
import UserNotifications

/// Handles notification tap to deep link to Journey Map.
extension Notification.Name {
    static let scheduleReminderTapped = Notification.Name("scheduleReminderTapped")
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == NotificationManager.scheduleReminderCategory {
            NotificationCenter.default.post(name: .scheduleReminderTapped, object: nil)
        }
        completionHandler()
    }
}
