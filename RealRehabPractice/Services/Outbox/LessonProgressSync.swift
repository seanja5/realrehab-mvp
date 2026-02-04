//
//  LessonProgressSync.swift
//  RealRehabPractice
//
//  Performs RPC call off MainActor to avoid Sendable/Encodable isolation issues.
//

import Foundation
import Supabase

enum LessonProgressSync {
    /// Call accounts.upsert_patient_lesson_progress RPC. Must be called from nonisolated context.
    static func upsert(lessonId: String, repsCompleted: Int, repsTarget: Int, elapsedSeconds: Int, status: String) async throws {
        let params = UpsertLessonProgressParams(
            p_lesson_id: lessonId,
            p_reps_completed: repsCompleted,
            p_reps_target: repsTarget,
            p_elapsed_seconds: elapsedSeconds,
            p_status: status
        )
        let client = SupabaseService.shared.client
        _ = try await client
            .schema("accounts")
            .rpc("upsert_patient_lesson_progress", params: params)
            .executeAsync()
    }
}
