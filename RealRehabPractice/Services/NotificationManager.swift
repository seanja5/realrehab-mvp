import Foundation
import UserNotifications

/// Manages schedule reminder notifications (T-15 and T) for patient rehab sessions.
/// Uses stable identifiers for easy cancel/reschedule. Rolling 14-day window.
enum NotificationManager {
    static let scheduleReminderCategory = "SCHEDULE_REMINDER"
    static let scheduleReminderIdentifierPrefix = "schedule_reminder_"

    /// Request notification permission. Call when user first enables reminders.
    /// - Returns: true if granted, false if denied
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return granted
        case .provisional, .ephemeral:
            return true
        @unknown default:
            return false
        }
    }

    /// Check current authorization status (for UI)
    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Schedule reminders for the next 14 days. Two notifications per session: T-15 and T.
    /// - Parameters:
    ///   - slots: Schedule slots (day_of_week 0-6, slot_time "HH:mm:ss")
    ///   - firstName: Patient first name for personalization; fallback "Hey there" if nil/empty
    static func scheduleScheduleReminders(slots: [ScheduleService.ScheduleSlot], firstName: String?) async {
        await cancelScheduleReminders()

        guard !slots.isEmpty else { return }

        let greeting = (firstName?.trimmingCharacters(in: .whitespaces).isEmpty == false)
            ? firstName!.trimmingCharacters(in: .whitespaces)
            : "Hey there"

        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)

        var requests: [UNNotificationRequest] = []

        for dayOffset in 0..<14 {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let weekday = (cal.component(.weekday, from: date) + 6) % 7 // 0=Sun .. 6=Sat

            for slot in slots where slot.day_of_week == weekday {
                guard let (hour, minute) = parseSlotTime(slot.slot_time) else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: date)
                comps.hour = hour
                comps.minute = minute
                comps.second = 0
                guard let sessionDate = cal.date(from: comps), sessionDate > now else { continue }

                // T-15 notification
                let t15Date = sessionDate.addingTimeInterval(-15 * 60)
                if t15Date > now {
                    let content = UNMutableNotificationContent()
                    content.title = "Rehab Reminder"
                    content.body = "Hey \(greeting), your rehab lesson starts in 15 minutes!"
                    content.sound = .default
                    content.categoryIdentifier = scheduleReminderCategory
                    content.userInfo = ["route": "journeyMap"]
                    let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: t15Date), repeats: false)
                    let id = "\(scheduleReminderIdentifierPrefix)t15_\(weekday)_\(hour)_\(minute)_\(dayOffset)"
                    requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }

                // T notification (at start time)
                let content = UNMutableNotificationContent()
                content.title = "Time to Heal!"
                content.body = "It's time to heal! Tap here to start now."
                content.sound = .default
                content.categoryIdentifier = scheduleReminderCategory
                content.userInfo = ["route": "journeyMap"]
                let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: sessionDate), repeats: false)
                let id = "\(scheduleReminderIdentifierPrefix)t0_\(weekday)_\(hour)_\(minute)_\(dayOffset)"
                requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }

        let center = UNUserNotificationCenter.current()
        for req in requests.prefix(64) {
            try? await center.add(req)
        }
    }

    /// Remove all pending schedule reminder notifications
    static func cancelScheduleReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(scheduleReminderIdentifierPrefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func parseSlotTime(_ s: String) -> (hour: Int, minute: Int)? {
        let parts = s.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              h >= 0, h <= 23, m >= 0, m < 60 else { return nil }
        return (h, m)
    }
}
