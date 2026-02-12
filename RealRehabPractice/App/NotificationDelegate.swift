import Foundation
import UserNotifications

/// Handles notification tap to deep link to Journey Map or PT Patient Detail.
extension Notification.Name {
    static let scheduleReminderTapped = Notification.Name("scheduleReminderTapped")
    static let ptSessionCompleteTapped = Notification.Name("ptSessionCompleteTapped")
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        let userInfo = response.notification.request.content.userInfo
        if category == NotificationManager.scheduleReminderCategory {
            NotificationCenter.default.post(name: .scheduleReminderTapped, object: nil)
        } else if category == NotificationManager.ptSessionCompleteCategory,
                  let idString = userInfo["patientProfileId"] as? String,
                  let patientProfileId = UUID(uuidString: idString) {
            NotificationCenter.default.post(name: .ptSessionCompleteTapped, object: nil, userInfo: ["patientProfileId": patientProfileId])
        }
        completionHandler()
    }
}
