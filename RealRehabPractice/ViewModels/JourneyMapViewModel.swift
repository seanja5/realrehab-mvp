import Foundation
import Combine
import Supabase
import PostgREST

public struct JourneyNode: Identifiable {
    public let id: UUID
    public let isLocked: Bool
    public let title: String
    public let yOffset: CGFloat
    public let reps: Int
    public let restSec: Int
    public let nodeType: JourneyNodeType
    public let phase: Int
    public let timeHoldingPosition: Int?

    /// Display icons come from lessonIconSystemName(for: title), not from a stored icon.
    public init(id: UUID, isLocked: Bool, title: String, yOffset: CGFloat, reps: Int = 20, restSec: Int = 3, nodeType: JourneyNodeType = .lesson, phase: Int = 1, timeHoldingPosition: Int? = nil) {
        self.id = id
        self.isLocked = isLocked
        self.title = title
        self.yOffset = yOffset
        self.reps = reps
        self.restSec = restSec
        self.nodeType = nodeType
        self.phase = phase
        self.timeHoldingPosition = timeHoldingPosition
    }
}

/// Progress info for a lesson (from local draft or Supabase)
public struct LessonProgressInfo {
    public let repsCompleted: Int
    public let repsTarget: Int
    public let isCompleted: Bool
    public let isInProgress: Bool  // started but not completed (paused)
}

public final class JourneyMapViewModel: ObservableObject {
    @Published public var nodes: [JourneyNode] = []
    @Published public var lessonProgress: [UUID: LessonProgressInfo] = [:]
    @Published public var isLoading: Bool = true  // Start true so patient sees spinner + skeleton until load completes
    @Published public var errorMessage: String?
    /// nil = loading/unknown, true = linked to PT, false = not linked (show skeleton title + center message)
    @Published public var isLinkedToPT: Bool? = nil
    /// Plan title when loaded (e.g. "ACL Rehab"); nil until plan is loaded.
    @Published public var planTitle: String? = nil
    /// True when we should show the offline/stale banner (offline and either data is stale or user tried to refresh).
    @Published public var showOfflineBanner: Bool = false
    /// Streak state for fire icon on header (patient side only).
    @Published public var streakState: StreakState = .hidden

    public init() {}
    
    @MainActor
    public func load(forceRefresh: Bool = false) async {
        if nodes.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        showOfflineBanner = false
        
        do {
            let (profileOpt, profileStale) = try await AuthService.myProfileForDisplay()
            guard let profile = profileOpt else {
                throw NSError(domain: "JourneyMapViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
            }
            
            let patientProfileId: UUID
            var idsStale = profileStale
            if let cached = await PatientService.myPatientProfileIdForDisplay(profileId: profile.id) {
                patientProfileId = cached.0
                if NetworkMonitor.shared.isOnline { idsStale = false }
                else { idsStale = idsStale || cached.1 }
            } else {
                patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
            }
            debugLog("🔍 JourneyMapViewModel: patient_profile_id=\(patientProfileId.uuidString)")
            
            if forceRefresh {
                await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
                await CacheService.shared.invalidate(CacheKey.completionDates(patientProfileId: patientProfileId))
            }
            
            let ptProfileId: UUID?
            if let cached = await PatientService.getPTProfileIdForDisplay(patientProfileId: patientProfileId) {
                ptProfileId = cached.0
                if !NetworkMonitor.shared.isOnline { idsStale = idsStale || cached.1 }
            } else {
                ptProfileId = try await PatientService.getPTProfileId(patientProfileId: patientProfileId)
            }
            guard let ptProfileId = ptProfileId else {
                debugLog("⚠️ JourneyMapViewModel: no pt_patient_map found for patient")
                isLinkedToPT = false
                isLoading = false
                return
            }
            isLinkedToPT = true
            debugLog("🔍 JourneyMapViewModel: pt_profile_id=\(ptProfileId.uuidString)")
            
            let (plan, planStale) = try await RehabService.currentPlanForDisplay(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
            guard let plan = plan else {
                debugLog("ℹ️ JourneyMapViewModel: no active plan found")
                planTitle = nil
                isLoading = false
                return
            }
            planTitle = "\(plan.injury) Rehab"

            // New active plan row → PT replaced the plan; drop stale disk cache + local drafts + queued upserts
            // so the patient does not see old completions (lesson IDs often repeat across templates).
            let planKey = Self.lastRehabPlanUserDefaultsKey(patientProfileId: patientProfileId)
            let previousPlanId = UserDefaults.standard.string(forKey: planKey)
            if let previousPlanId, previousPlanId != plan.id.uuidString {
                await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
                await CacheService.shared.invalidate(CacheKey.completionDates(patientProfileId: patientProfileId))
                LocalLessonProgressStore.shared.clearAllDrafts()
                OutboxSyncManager.shared.removeAllLessonProgressItems(patientProfileId: patientProfileId)
                debugLog("🔄 JourneyMapViewModel: rehab plan id changed (\(previousPlanId) → \(plan.id)); cleared local progress + outbox")
            }
            UserDefaults.standard.set(plan.id.uuidString, forKey: planKey)
            
            var anyStale = idsStale || planStale
            
            if let planNodes = plan.nodes, !planNodes.isEmpty {
                let phases = planNodes.map { max(1, min(4, $0.phase ?? 1)) }
                let yOffsets = ACLJourneyModels.layoutYOffsets(phases: phases, width: 390)
                nodes = planNodes.enumerated().map { index, dto in
                    let lessonId = UUID(uuidString: dto.id) ?? UUID()
                    let yOffset = index < yOffsets.count ? yOffsets[index] : CGFloat(index) * ACLJourneyModels.baseStep
                    let nodeType: JourneyNodeType = (dto.nodeType == "benchmark") ? .benchmark : .lesson
                    let phase = phases[index]
                    return JourneyNode(id: lessonId, isLocked: dto.isLocked, title: dto.title, yOffset: yOffset, reps: dto.reps, restSec: dto.restSec, nodeType: nodeType, phase: phase, timeHoldingPosition: dto.timeHoldingPosition)
                }
                debugLog("✅ JourneyMapViewModel: loaded \(nodes.count) nodes from plan")
                
                var progress: [UUID: LessonProgressInfo] = [:]

                // Fetch lesson progress and completion dates concurrently (independent calls)
                async let progressFetch = RehabService.getLessonProgressForDisplay(patientProfileId: patientProfileId)
                async let datesFetch = RehabService.getCompletionDates(patientProfileId: patientProfileId)
                let (remoteProgress, progressStale) = (try? await progressFetch) ?? ([:], false)
                let completionDates = (try? await datesFetch) ?? []

                anyStale = anyStale || (NetworkMonitor.shared.isOnline ? false : progressStale)
                for node in nodes {
                    let lessonId = node.id
                    if let info = mergedLessonProgress(
                        lessonId: lessonId,
                        remoteProgress: remoteProgress,
                        patientProfileId: patientProfileId
                    ) {
                        progress[lessonId] = info
                    }
                }
                lessonProgress = progress

                // Compute streak from completion dates (fetched concurrently above)
                streakState = StreakService.computeStreakState(completionDates: completionDates, patientProfileId: patientProfileId)
            } else {
                debugLog("ℹ️ JourneyMapViewModel: plan has no nodes")
                streakState = .hidden
            }
            showOfflineBanner = !NetworkMonitor.shared.isOnline && (anyStale || forceRefresh)
        } catch {
            if error is CancellationError || Task.isCancelled {
                isLoading = false
                return
            }
            if nodes.isEmpty {
                errorMessage = error.localizedDescription
                debugLog("❌ JourneyMapViewModel.load error: \(error)")
            }
        }
        isLoading = false
    }

    private static func lastRehabPlanUserDefaultsKey(patientProfileId: UUID) -> String {
        "journey_last_rehab_plan_id_\(patientProfileId.uuidString)"
    }

    /// Remote progress is source of truth for completed; local drafts only for in-progress resume or offline completion still queued.
    private func mergedLessonProgress(
        lessonId: UUID,
        remoteProgress: [UUID: RehabService.PatientLessonProgressRow],
        patientProfileId: UUID
    ) -> LessonProgressInfo? {
        let remote = remoteProgress[lessonId]
        let local = LocalLessonProgressStore.shared.loadDraft(lessonId: lessonId)

        if let remote {
            if remote.status == "completed" {
                if local != nil {
                    LocalLessonProgressStore.shared.clearDraft(lessonId: lessonId)
                }
                return LessonProgressInfo(
                    repsCompleted: remote.reps_completed,
                    repsTarget: remote.reps_target,
                    isCompleted: true,
                    isInProgress: false
                )
            }
            if remote.status == "inProgress" {
                if let local, local.status == "inProgress" {
                    return LessonProgressInfo(
                        repsCompleted: max(local.repsCompleted, remote.reps_completed),
                        repsTarget: max(local.repsTarget, remote.reps_target),
                        isCompleted: false,
                        isInProgress: true
                    )
                }
                return LessonProgressInfo(
                    repsCompleted: remote.reps_completed,
                    repsTarget: remote.reps_target,
                    isCompleted: false,
                    isInProgress: true
                )
            }
        }

        guard let local else { return nil }

        if local.status == "inProgress" {
            return LessonProgressInfo(
                repsCompleted: local.repsCompleted,
                repsTarget: local.repsTarget,
                isCompleted: false,
                isInProgress: true
            )
        }

        if local.status == "completed" {
            if OutboxSyncManager.shared.hasPendingLessonProgressUpsert(patientProfileId: patientProfileId, lessonId: lessonId) {
                return LessonProgressInfo(
                    repsCompleted: local.repsCompleted,
                    repsTarget: local.repsTarget,
                    isCompleted: true,
                    isInProgress: false
                )
            }
            if NetworkMonitor.shared.isOnline {
                LocalLessonProgressStore.shared.clearDraft(lessonId: lessonId)
                return nil
            }
            return LessonProgressInfo(
                repsCompleted: local.repsCompleted,
                repsTarget: local.repsTarget,
                isCompleted: true,
                isInProgress: false
            )
        }

        return nil
    }
}

