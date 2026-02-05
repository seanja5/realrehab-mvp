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
    
    public init() {}
    
    @MainActor
    public func load() async {
        // Only show loading if we don't have data yet
        if nodes.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            // Get current user's profile
            guard let profile = try await AuthService.myProfile() else {
                throw NSError(domain: "JourneyMapViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
            }
            
            // Get patient profile ID
            let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
            print("🔍 JourneyMapViewModel: patient_profile_id=\(patientProfileId.uuidString)")
            
            // Get PT profile ID from patient profile ID (using cached service)
            guard let ptProfileId = try await PatientService.getPTProfileId(patientProfileId: patientProfileId) else {
                print("⚠️ JourneyMapViewModel: no pt_patient_map found for patient")
                isLoading = false
                return
            }
            print("🔍 JourneyMapViewModel: pt_profile_id=\(ptProfileId.uuidString)")
            
            // Fetch the active rehab plan
            guard let plan = try await RehabService.currentPlan(ptProfileId: ptProfileId, patientProfileId: patientProfileId) else {
                print("ℹ️ JourneyMapViewModel: no active plan found")
                isLoading = false
                return
            }
            
            // Convert PlanNodeDTO to JourneyNode (constant-segment layout; nominal width 390)
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
                
                // Load lesson progress (merge local drafts + Supabase)
                var progress: [UUID: LessonProgressInfo] = [:]
                let remoteProgress = (try? await RehabService.getLessonProgress(patientProfileId: patientProfileId)) ?? [:]
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
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                isLoading = false
                return
            }
            // Don't show error when we have cached data to display (e.g. offline after tab switch)
            if nodes.isEmpty {
                errorMessage = error.localizedDescription
                print("❌ JourneyMapViewModel.load error: \(error)")
            }
        }
        
        isLoading = false
    }
}

