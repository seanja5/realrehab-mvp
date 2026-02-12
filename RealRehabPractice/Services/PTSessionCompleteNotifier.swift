//
//  PTSessionCompleteNotifier.swift
//  RealRehabPractice
//
//  When the PT has "Patient session completed" enabled, fetches recent session-complete events
//  and shows a local notification for each new one. Run when PT app becomes active.
//

import Foundation
import UserNotifications

enum PTSessionCompleteNotifier {
    private static let notifiedIdsKey = "pt_session_complete_notified_ids"
    private static let maxNotifiedIds = 100
    
    /// Fetch recent events and show a local notification for any we haven't notified yet. Call when PT app becomes active.
    @MainActor
    static func checkAndNotify() async {
        guard await NotificationManager.authorizationStatus() == .authorized else { return }
        do {
            let events = try await PTService.fetchRecentSessionCompleteEvents(limit: 20)
            var notified = Self.loadNotifiedIds()
            for event in events {
                guard !notified.contains(event.id) else { continue }
                let name = [event.patient_first_name, event.patient_last_name]
                    .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let patientName = name.isEmpty ? "A patient" : name
                let lessonName = (event.lesson_title?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? "a lesson"
                await NotificationManager.showSessionCompleteNotification(
                    patientName: patientName,
                    lessonName: lessonName,
                    patientProfileId: event.patient_profile_id
                )
                notified.insert(event.id)
            }
            Self.saveNotifiedIds(notified)
        } catch {
            print("⚠️ PTSessionCompleteNotifier: \(error)")
        }
    }
    
    private static func loadNotifiedIds() -> Set<UUID> {
        guard let list = UserDefaults.standard.stringArray(forKey: notifiedIdsKey) else { return [] }
        return Set(list.compactMap { UUID(uuidString: $0) })
    }
    
    private static func saveNotifiedIds(_ ids: Set<UUID>) {
        let list = Array(ids.prefix(maxNotifiedIds)).map(\.uuidString)
        UserDefaults.standard.set(list, forKey: notifiedIdsKey)
    }
}
