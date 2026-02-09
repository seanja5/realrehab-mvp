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
    
    /// Display icons come from lessonIconSystemName(for: title), not from a stored icon.
    public init(id: UUID, isLocked: Bool, title: String, yOffset: CGFloat, reps: Int = 20, restSec: Int = 3, nodeType: JourneyNodeType = .lesson, phase: Int = 1) {
        self.id = id
        self.isLocked = isLocked
        self.title = title
        self.yOffset = yOffset
        self.reps = reps
        self.restSec = restSec
        self.nodeType = nodeType
        self.phase = phase
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
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    /// True when we should show the offline/stale banner (offline and either data is stale or user tried to refresh).
    @Published public var showOfflineBanner: Bool = false
    
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
            print("🔍 JourneyMapViewModel: patient_profile_id=\(patientProfileId.uuidString)")
            
            if forceRefresh {
                await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
            }
            
            let ptProfileId: UUID?
            if let cached = await PatientService.getPTProfileIdForDisplay(patientProfileId: patientProfileId) {
                ptProfileId = cached.0
                if !NetworkMonitor.shared.isOnline { idsStale = idsStale || cached.1 }
            } else {
                ptProfileId = try await PatientService.getPTProfileId(patientProfileId: patientProfileId)
            }
            guard let ptProfileId = ptProfileId else {
                print("⚠️ JourneyMapViewModel: no pt_patient_map found for patient")
                isLoading = false
                return
            }
            print("🔍 JourneyMapViewModel: pt_profile_id=\(ptProfileId.uuidString)")
            
            let (plan, planStale) = try await RehabService.currentPlanForDisplay(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
            guard let plan = plan else {
                print("ℹ️ JourneyMapViewModel: no active plan found")
                isLoading = false
                return
            }
            
            var anyStale = idsStale || planStale
            
            if let planNodes = plan.nodes, !planNodes.isEmpty {
                let phases = planNodes.map { max(1, min(4, $0.phase ?? 1)) }
                let yOffsets = ACLJourneyModels.layoutYOffsets(phases: phases, width: 390)
                nodes = planNodes.enumerated().map { index, dto in
                    let lessonId = UUID(uuidString: dto.id) ?? UUID()
                    let yOffset = index < yOffsets.count ? yOffsets[index] : CGFloat(index) * ACLJourneyModels.baseStep
                    let nodeType: JourneyNodeType = (dto.nodeType == "benchmark") ? .benchmark : .lesson
                    let phase = phases[index]
                    return JourneyNode(id: lessonId, isLocked: dto.isLocked, title: dto.title, yOffset: yOffset, reps: dto.reps, restSec: dto.restSec, nodeType: nodeType, phase: phase)
                }
                print("✅ JourneyMapViewModel: loaded \(nodes.count) nodes from plan")
                
                var progress: [UUID: LessonProgressInfo] = [:]
                let (remoteProgress, progressStale) = (try? await RehabService.getLessonProgressForDisplay(patientProfileId: patientProfileId)) ?? ([:], false)
                anyStale = anyStale || (NetworkMonitor.shared.isOnline ? false : progressStale)
                for node in nodes where node.nodeType == .lesson {
                    let lessonId = node.id
                    if let local = LocalLessonProgressStore.shared.loadDraft(lessonId: lessonId) {
                        progress[lessonId] = LessonProgressInfo(
                            repsCompleted: local.repsCompleted,
                            repsTarget: local.repsTarget,
                            isCompleted: local.status == "completed",
                            isInProgress: local.status == "inProgress"
                        )
                    } else if let remote = remoteProgress[lessonId] {
                        progress[lessonId] = LessonProgressInfo(
                            repsCompleted: remote.reps_completed,
                            repsTarget: remote.reps_target,
                            isCompleted: remote.status == "completed",
                            isInProgress: remote.status == "inProgress"
                        )
                    }
                }
                lessonProgress = progress
            } else {
                print("ℹ️ JourneyMapViewModel: plan has no nodes")
            }
            showOfflineBanner = !NetworkMonitor.shared.isOnline && (anyStale || forceRefresh)
        } catch {
            if error is CancellationError || Task.isCancelled {
                isLoading = false
                return
            }
            if nodes.isEmpty {
                errorMessage = error.localizedDescription
                print("❌ JourneyMapViewModel.load error: \(error)")
            }
        }
        isLoading = false
    }
}

