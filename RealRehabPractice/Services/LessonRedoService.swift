//
//  LessonRedoService.swift
//  RealRehabPractice
//
//  Clears local + remote lesson completion data so the patient can run the lesson again.
//

import Foundation
import Supabase

enum LessonRedoRemoteSync {
    static func performDeletes(patientProfileId: UUID, lessonId: UUID) async throws {
        let lid = lessonId.uuidString
        try await LessonProgressSync.delete(lessonId: lid)
        try await LessonSensorInsightsSync.delete(lessonId: lessonId, patientProfileId: patientProfileId)
        try await LessonAISummariesDelete.deleteForLesson(lessonId: lessonId, patientProfileId: patientProfileId)
    }
}

private enum LessonAISummariesDelete {
    static func deleteForLesson(lessonId: UUID, patientProfileId: UUID) async throws {
        let client = SupabaseService.shared.client
        try await client
            .schema("rehab")
            .from("lesson_ai_summaries")
            .delete()
            .eq("lesson_id", value: lessonId.uuidString)
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .executeAsync()
    }
}

@MainActor
enum LessonRedoService {
    static func clearLessonForRedo(lessonId: UUID) async throws {
        let profile = try await PatientService.myPatientProfile()
        let pid = profile.id
        LocalLessonProgressStore.shared.clearDraft(lessonId: lessonId)
        LessonSensorInsightsCollector.shared.removeDraftFile(lessonId: lessonId)
        OutboxSyncManager.shared.removeOutboxItemsForLessonRedo(patientProfileId: pid, lessonId: lessonId)
        await CompletionPageCache.shared.remove(lessonId)
        if NetworkMonitor.shared.isOnline {
            try await Task.detached {
                try await LessonRedoRemoteSync.performDeletes(patientProfileId: pid, lessonId: lessonId)
            }.value
            await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: pid))
            await CacheService.shared.invalidate(CacheKey.completionDates(patientProfileId: pid))
        } else {
            OutboxSyncManager.shared.enqueueLessonRedoRemoteDelete(patientProfileId: pid, lessonId: lessonId)
        }
    }
}
