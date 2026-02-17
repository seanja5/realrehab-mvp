//
//  StreakService.swift
//  RealRehabPractice
//
//  Computes streak state from completion dates. Fire icon: red + number when streak 2+,
//  gray (no number) for 24h after missing a day, then disappears.
//

import Foundation

/// Streak display state for the fire icon on the patient journey header
public enum StreakState: Equatable {
    /// No streak, or streak < 2, or fire has disappeared after 24h gray
    case hidden
    /// Active streak 2+; show red fire + number
    case active(count: Int)
    /// Lost streak within 24h; show gray fire, no number (recoverable if user does a lesson)
    case gray(recoverableCount: Int)
}

/// Persists gray state so we know when 24h expires. Keyed by patient_profile_id.
enum StreakStore {
    private static let defaults = UserDefaults.standard
    private static func key(_ patientProfileId: UUID) -> String {
        "streak_gray:\(patientProfileId.uuidString)"
    }

    struct GrayState: Codable {
        let startedAt: Date
        let lastCountBeforeGray: Int
    }

    static func loadGrayState(patientProfileId: UUID) -> GrayState? {
        guard let data = defaults.data(forKey: key(patientProfileId)),
              let state = try? JSONDecoder().decode(GrayState.self, from: data) else {
            return nil
        }
        return state
    }

    static func saveGrayState(patientProfileId: UUID, startedAt: Date, lastCountBeforeGray: Int) {
        let state = GrayState(startedAt: startedAt, lastCountBeforeGray: lastCountBeforeGray)
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key(patientProfileId))
        }
    }

    static func clearGrayState(patientProfileId: UUID) {
        defaults.removeObject(forKey: key(patientProfileId))
    }
}

enum StreakService {
    private static let grayDurationSeconds: TimeInterval = 24 * 60 * 60 // 24 hours

    /// Compute streak state from completion dates and persisted gray state.
    /// - Parameter completionDates: Sorted descending (most recent first). Calendar days when patient completed at least 1 lesson.
    /// - Parameter patientProfileId: For loading/saving gray state.
    static func computeStreakState(
        completionDates: [Date],
        patientProfileId: UUID,
        now: Date = Date()
    ) -> StreakState {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        guard !completionDates.isEmpty else { return .hidden }

        let sorted = completionDates.sorted(by: >)
        let mostRecent = sorted[0]

        // Count consecutive days ending with mostRecent
        func streakEnding(on endDate: Date) -> Int {
            var count = 0
            var current = endDate
            for d in sorted {
                let day = cal.startOfDay(for: d)
                if day == current {
                    count += 1
                    guard let prev = cal.date(byAdding: .day, value: -1, to: current) else { break }
                    current = prev
                } else if day < current {
                    break
                }
            }
            return count
        }

        // Active streak: most recent completion is today or yesterday
        if mostRecent == today || mostRecent == yesterday {
            // Recovery: user had gray fire and just did a lesson today
            if mostRecent == today, let gray = StreakStore.loadGrayState(patientProfileId: patientProfileId) {
                StreakStore.clearGrayState(patientProfileId: patientProfileId)
                return .active(count: gray.lastCountBeforeGray + 1)
            }
            let count = streakEnding(on: mostRecent)
            if count >= 2 {
                StreakStore.clearGrayState(patientProfileId: patientProfileId)
                return .active(count: count)
            }
            return .hidden
        }

        // Streak broken: most recent completion is before yesterday
        let countAtBreak = streakEnding(on: mostRecent)
        if countAtBreak < 2 {
            return .hidden
        }

        // Enter or continue gray state
        if let gray = StreakStore.loadGrayState(patientProfileId: patientProfileId) {
            let elapsed = now.timeIntervalSince(gray.startedAt)
            if elapsed >= grayDurationSeconds {
                StreakStore.clearGrayState(patientProfileId: patientProfileId)
                return .hidden
            }
            return .gray(recoverableCount: gray.lastCountBeforeGray)
        }

        // First time detecting break; persist gray state
        StreakStore.saveGrayState(
            patientProfileId: patientProfileId,
            startedAt: now,
            lastCountBeforeGray: countAtBreak
        )
        return .gray(recoverableCount: countAtBreak)
    }

}
