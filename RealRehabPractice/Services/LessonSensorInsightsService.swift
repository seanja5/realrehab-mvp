//
//  LessonSensorInsightsService.swift
//  RealRehabPractice
//
//  Fetches lesson_sensor_insights from Supabase for PT analytics view.
//

import Foundation
import Supabase

struct LessonSensorInsightsRow: Decodable {
    let id: UUID
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

enum LessonSensorInsightsService {
    /// Fetch lesson sensor insights for a given lesson and patient. Returns nil if not found.
    static func fetch(lessonId: UUID, patientProfileId: UUID) async throws -> LessonSensorInsightsRow? {
        let client = SupabaseService.shared.client
        let rows: [LessonSensorInsightsRow] = try await client
            .schema("rehab")
            .from("lesson_sensor_insights")
            .select()
            .eq("lesson_id", value: lessonId.uuidString)
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
