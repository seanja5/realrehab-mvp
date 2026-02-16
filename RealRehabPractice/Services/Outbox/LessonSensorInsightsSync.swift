//
//  LessonSensorInsightsSync.swift
//  RealRehabPractice
//
//  Upserts lesson_sensor_insights to Supabase (rehab schema).
//

import Foundation
import Supabase

enum LessonSensorInsightsSync {
    /// Upsert lesson_sensor_insights row. Must be called from nonisolated context.
    static func upsert(draft: LessonSensorInsightsDraft) async throws {
        let row = LessonSensorInsightsUpsertRow(
            lesson_id: draft.lessonId,
            patient_profile_id: draft.patientProfileId,
            pt_profile_id: draft.ptProfileId,
            started_at: draft.startedAt,
            completed_at: draft.completedAt,
            total_duration_sec: draft.totalDurationSec,
            reps_target: draft.repsTarget,
            reps_completed: draft.repsCompleted,
            reps_attempted: draft.repsAttempted,
            events: draft.events,
            imu_samples: draft.imuSamples,
            shake_frequency_samples: draft.shakeFrequencySamples
        )
        let client = SupabaseService.shared.client
        try await client
            .schema("rehab")
            .from("lesson_sensor_insights")
            .upsert(row, onConflict: "lesson_id,patient_profile_id")
            .execute()
    }
}

private struct LessonSensorInsightsUpsertRow: Encodable {
    let lesson_id: UUID
    let patient_profile_id: UUID
    let pt_profile_id: UUID
    let started_at: Date
    let completed_at: Date?
    let total_duration_sec: Int
    let reps_target: Int
    let reps_completed: Int
    let reps_attempted: Int
    let events: [LessonSensorEventRecord]
    let imu_samples: [IMUSample]
    let shake_frequency_samples: [ShakeSample]
}
