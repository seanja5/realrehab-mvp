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
    let flex_angle_samples: [FlexAngleSample]
    let calibration_min_deg: Double?
    let calibration_max_deg: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                      = try c.decode(UUID.self,                      forKey: .id)
        lesson_id               = try c.decode(UUID.self,                      forKey: .lesson_id)
        patient_profile_id      = try c.decode(UUID.self,                      forKey: .patient_profile_id)
        pt_profile_id           = try c.decode(UUID.self,                      forKey: .pt_profile_id)
        started_at              = try c.decode(Date.self,                      forKey: .started_at)
        completed_at            = try c.decodeIfPresent(Date.self,             forKey: .completed_at)
        total_duration_sec      = try c.decode(Int.self,                       forKey: .total_duration_sec)
        reps_target             = try c.decode(Int.self,                       forKey: .reps_target)
        reps_completed          = try c.decode(Int.self,                       forKey: .reps_completed)
        reps_attempted          = try c.decode(Int.self,                       forKey: .reps_attempted)
        events                  = try c.decode([LessonSensorEventRecord].self, forKey: .events)
        imu_samples             = try c.decode([IMUSample].self,               forKey: .imu_samples)
        shake_frequency_samples = try c.decode([ShakeSample].self,             forKey: .shake_frequency_samples)
        // Backward compat: rows written before flex_angle_samples column decode as empty
        flex_angle_samples      = (try? c.decode([FlexAngleSample].self,       forKey: .flex_angle_samples)) ?? []
        calibration_min_deg     = try? c.decodeIfPresent(Double.self,          forKey: .calibration_min_deg) ?? nil
        calibration_max_deg     = try? c.decodeIfPresent(Double.self,          forKey: .calibration_max_deg) ?? nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, lesson_id, patient_profile_id, pt_profile_id
        case started_at, completed_at, total_duration_sec
        case reps_target, reps_completed, reps_attempted
        case events, imu_samples, shake_frequency_samples
        case flex_angle_samples, calibration_min_deg, calibration_max_deg
    }
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

    /// Fetch all completed lesson sensor insights for a patient (for PT performance overview).
    static func fetchAll(patientProfileId: UUID) async throws -> [LessonSensorInsightsRow] {
        let client = SupabaseService.shared.client
        let rows: [LessonSensorInsightsRow] = try await client
            .schema("rehab")
            .from("lesson_sensor_insights")
            .select()
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .execute()
            .value
        return rows.filter { $0.completed_at != nil }
    }
}
