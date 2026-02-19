//
//  PatientLessonScore.swift
//  RealRehabPractice
//
//  Composite score and Whoop-style explanation for patient lesson results.
//

import Foundation

enum PatientLessonScore {
    /// Compute 0–100 composite score from sensor insights (Whoop-inspired weights).
    /// Returns (score, explanation) where explanation is plain-language only.
    static func compute(insights: LessonSensorInsightsRow) -> (score: Int, explanation: String) {
        let repAccuracy: Double = {
            guard insights.reps_target > 0 else { return 100 }
            return min(100, (Double(insights.reps_completed) / Double(insights.reps_target)) * 100)
        }()

        let driftEvents = filterEvents(insights.events, type: "drift_left") + filterEvents(insights.events, type: "drift_right")
        let driftPercent = percentCorrect(total: insights.reps_attempted, errors: driftEvents.count)

        let shakeCount = countShakeViolations(insights.shake_frequency_samples)
        let shakePercent = percentCorrect(total: insights.reps_attempted, errors: shakeCount)

        let tooFast = filterEvents(insights.events, type: "too_fast")
        let tooSlow = filterEvents(insights.events, type: "too_slow")
        let maxNotReached = filterEvents(insights.events, type: "max_not_reached")
        let tooFastPercent = percentCorrect(total: insights.reps_attempted, errors: tooFast.count)
        let tooSlowPercent = percentCorrect(total: insights.reps_attempted, errors: tooSlow.count)
        let maxNotReachedPercent = percentCorrect(total: insights.reps_attempted, errors: maxNotReached.count)
        let pacePercent = (tooFastPercent + tooSlowPercent + maxNotReachedPercent) / 3

        // Weights: rep 40%, drift 25%, shake 20%, pace 15%
        let composite = (repAccuracy * 0.40) + (driftPercent * 0.25) + (shakePercent * 0.20) + (pacePercent * 0.15)
        let score = min(100, max(0, Int(composite.rounded())))

        let explanation = scoreExplanation(for: score)
        return (score, explanation)
    }

    /// Whoop-style plain-language explanation (no numbers).
    static func scoreExplanation(for score: Int) -> String {
        switch score {
        case 67...100:
            return "Your body responded well to this session. You're building strength and control."
        case 34...66:
            return "Solid effort. Small tweaks in form and pace will help next time."
        default:
            return "Room to grow. Focus on steady movement and full extension next session."
        }
    }
}

// MARK: - Helpers (mirror LessonAnalyticsView logic)

private func filterEvents(_ events: [LessonSensorEventRecord], type: String) -> [(rep: Int, timeSec: Double)] {
    events
        .filter { $0.eventType == type }
        .map { (rep: $0.repAttempt, timeSec: $0.timeSec) }
}

private func percentCorrect(total: Int, errors: Int) -> Double {
    guard total > 0 else { return 100 }
    let correct = max(0, total - errors)
    return (Double(correct) / Double(total)) * 100
}

private func countShakeViolations(_ samples: [ShakeSample]) -> Int {
    let threshold: Double = 0.85
    var violations = 0
    var inViolation = false
    for s in samples {
        if s.frequency > threshold {
            if !inViolation {
                violations += 1
                inViolation = true
            }
        } else {
            inViolation = false
        }
    }
    return violations
}
