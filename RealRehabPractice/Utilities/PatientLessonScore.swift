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
        // Match PT LessonAnalyticsView: accuracy = completed/attempted
        let repAccuracy: Double = {
            guard insights.reps_attempted > 0 else { return 100 }
            return min(100, (Double(insights.reps_completed) / Double(insights.reps_attempted)) * 100)
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

    /// What the score means (segment-based, plain language).
    static func whatItMeans(for score: Int) -> String {
        switch score {
        case 90...100:
            return "Excellent! Your movement quality was very strong throughout the session. You completed most reps with proper form, stayed steady during the motion, and kept a consistent pace. This is exactly the kind of performance your physical therapist is looking for—it shows you’ve built good control and are ready to maintain or increase the challenge."
        case 80..<90:
            return "Great job! You’re performing well and most of your reps showed strong form and control. A few reps may have had minor issues—for example, a slight drift to one side, a bit of extra wobble, or a pace that was slightly off. These are small fixes. Your PT can help you fine-tune those last few percentage points if you’d like to push higher."
        case 70..<80:
            return "Good effort—you’re on the right track. You completed a solid portion of your reps with acceptable form, but some reps were affected by steadiness, range of motion, or pacing. Focus on moving more smoothly through the full range, avoiding sudden shifts, and keeping a steady tempo. Small improvements in these areas will raise your score."
        case 50..<70:
            return "Solid attempt. You got through the session and completed many of your reps, but several were marked for form, steadiness, or pacing issues. The sensor picked up drift (leaning to one side), extra movement or shake, or reps that were too fast, too slow, or didn’t reach full range. Your PT can help identify which area to work on first—often one or two adjustments make a big difference."
        case 30..<50:
            return "You showed up and moved—that counts. The score indicates that form, steadiness, or pace need more attention. The sensor detected frequent drift, shake, or timing issues that affected many reps. This is common early in a program. Focus on slowing down, moving through the full range, and staying steady. Your PT can guide you on cues that help, and scores typically improve as you practice."
        default:
            return "Early days. This score helps your PT see what to focus on. The sensor recorded many reps with form, steadiness, or pacing issues—for example, drifting, extra movement, or timing that didn’t match the exercise. That’s normal when you’re new to the movement. Stick with it: scores improve as you learn the motion and get more comfortable. Your PT will use this feedback to tailor your plan."
        }
    }

    /// How the score was calculated (plain language, non-technical).
    static func howCalculated(insights: LessonSensorInsightsRow) -> String {
        let repPct = insights.reps_attempted > 0
            ? Int((Double(insights.reps_completed) / Double(insights.reps_attempted)) * 100)
            : 0
        return """
        Your score is a weighted combination of four factors:

        Rep completion (40%): Of the reps you attempted, \(repPct)% were counted as completed with acceptable form. This has the biggest impact on your score.

        Drift (25%): How often your movement leaned or drifted to one side during reps. Less drift means a higher score.

        Steadiness (20%): How much extra shake or wobble the sensor detected. Smoother movement scores higher.

        Pace (15%): Whether reps were done at the right speed—not too fast, not too slow—and whether you reached full range. Reps that were rushed, delayed, or didn’t reach the full motion lower this part.

        These percentages are combined to produce your final score. Improving any of these areas will raise your overall score.
        """
    }

    /// Legacy: single-string explanation (kept for backward compatibility).
    static func scoreExplanation(for score: Int) -> String {
        whatItMeans(for: score)
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
