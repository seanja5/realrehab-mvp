//
//  LessonSummaryService.swift
//  RealRehabPractice
//
//  Fetches AI lesson summary from Edge Function (cache-first). Falls back to nil so UI can use Swift text.
//

import Foundation
import Supabase

// MARK: - Payload

struct LessonSummaryPayload: Encodable {
    let audience: String
    let lesson_id: String
    let patient_profile_id: String
    let score: Int
    let reps_target: Int
    let reps_completed: Int
    let reps_attempted: Int
    let total_duration_sec: Int
    let event_counts: EventCounts

    struct EventCounts: Encodable {
        let drift_left: Int
        let drift_right: Int
        let too_fast: Int
        let too_slow: Int
        let max_not_reached: Int
        let shake: Int
    }
}

// MARK: - Response

private struct PatientSummaryResponse: Decodable {
    let patientSummary: String?
    let nextTimeCue: String?
}

private struct PTSummaryResponse: Decodable {
    let ptSummary: String?
}

// MARK: - Service

enum LessonSummaryService {
    private static let timeout: TimeInterval = 15

    /// Fetches AI summary for the patient (completion screen). Returns nil on any failure so UI can use PatientLessonScore fallback.
    static func fetchPatientSummary(
        lessonId: UUID,
        patientProfileId: UUID,
        insights: LessonSensorInsightsRow
    ) async -> (patientSummary: String, nextTimeCue: String)? {
        let payload = makePayload(audience: "patient", lessonId: lessonId, patientProfileId: patientProfileId, insights: insights)
        guard let (data, _) = await callEdgeFunction(payload: payload) else { return nil }
        guard let decoded = try? JSONDecoder().decode(PatientSummaryResponse.self, from: data),
              let summary = decoded.patientSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              let cue = decoded.nextTimeCue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty, !cue.isEmpty else {
            return nil
        }
        return (summary, cue)
    }

    /// Fetches AI summary for the PT (analytics view). Returns nil on any failure so UI can hide card or show fallback.
    static func fetchPTSummary(
        lessonId: UUID,
        patientProfileId: UUID,
        insights: LessonSensorInsightsRow
    ) async -> String? {
        let payload = makePayload(audience: "pt", lessonId: lessonId, patientProfileId: patientProfileId, insights: insights)
        guard let (data, _) = await callEdgeFunction(payload: payload) else { return nil }
        guard let decoded = try? JSONDecoder().decode(PTSummaryResponse.self, from: data),
              let summary = decoded.ptSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return nil
        }
        return summary
    }

    private static func makePayload(
        audience: String,
        lessonId: UUID,
        patientProfileId: UUID,
        insights: LessonSensorInsightsRow
    ) -> LessonSummaryPayload {
        let score = PatientLessonScore.compute(insights: insights).score
        let eventCounts = eventCountsFromInsights(insights)
        return LessonSummaryPayload(
            audience: audience,
            lesson_id: lessonId.uuidString,
            patient_profile_id: patientProfileId.uuidString,
            score: score,
            reps_target: insights.reps_target,
            reps_completed: insights.reps_completed,
            reps_attempted: insights.reps_attempted,
            total_duration_sec: insights.total_duration_sec,
            event_counts: eventCounts
        )
    }

    private static func eventCountsFromInsights(_ insights: LessonSensorInsightsRow) -> LessonSummaryPayload.EventCounts {
        let driftLeft = insights.events.filter { $0.eventType == "drift_left" }.count
        let driftRight = insights.events.filter { $0.eventType == "drift_right" }.count
        let tooFast = insights.events.filter { $0.eventType == "too_fast" }.count
        let tooSlow = insights.events.filter { $0.eventType == "too_slow" }.count
        let maxNotReached = insights.events.filter { $0.eventType == "max_not_reached" }.count
        let shake = countShakeViolations(insights.shake_frequency_samples)
        return LessonSummaryPayload.EventCounts(
            drift_left: driftLeft,
            drift_right: driftRight,
            too_fast: tooFast,
            too_slow: tooSlow,
            max_not_reached: maxNotReached,
            shake: shake
        )
    }

    private static func countShakeViolations(_ samples: [ShakeSample]) -> Int {
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

    private static func callEdgeFunction(payload: LessonSummaryPayload) async -> (Data, HTTPURLResponse)? {
        guard let session = try? await SupabaseService.shared.client.auth.session else { return nil }
        let url = SupabaseService.shared.baseURL.appendingPathComponent("functions/v1/get-lesson-summary")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            return nil
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return (data, http)
        } catch {
            return nil
        }
    }
}
