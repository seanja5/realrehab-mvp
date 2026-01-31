import Foundation
import Combine
import Supabase
import PostgREST

public struct JourneyNode: Identifiable {
    public let id = UUID()
    public let icon: String
    public let isLocked: Bool
    public let title: String
    public let yOffset: CGFloat
    public let reps: Int
    public let restSec: Int
    public let nodeType: JourneyNodeType
    public let phase: Int
    
    public init(icon: String, isLocked: Bool, title: String, yOffset: CGFloat, reps: Int = 20, restSec: Int = 3, nodeType: JourneyNodeType = .lesson, phase: Int = 1) {
        self.icon = icon
        self.isLocked = isLocked
        self.title = title
        self.yOffset = yOffset
        self.reps = reps
        self.restSec = restSec
        self.nodeType = nodeType
        self.phase = phase
    }
}

public final class JourneyMapViewModel: ObservableObject {
    @Published public var nodes: [JourneyNode] = []
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
            
            // Convert PlanNodeDTO to JourneyNode
            if let planNodes = plan.nodes, !planNodes.isEmpty {
                nodes = planNodes.enumerated().map { index, dto in
                    let iconName = dto.icon == "person" ? "figure.stand" : "video.fill"
                    let yOffset = CGFloat(index) * 120
                    let nodeType: JourneyNodeType = (dto.nodeType == "benchmark") ? .benchmark : .lesson
                    let phase = max(1, min(4, dto.phase ?? 1))
                    return JourneyNode(icon: iconName, isLocked: dto.isLocked, title: dto.title, yOffset: yOffset, reps: dto.reps, restSec: dto.restSec, nodeType: nodeType, phase: phase)
                }
                print("✅ JourneyMapViewModel: loaded \(nodes.count) nodes from plan")
            } else {
                print("ℹ️ JourneyMapViewModel: plan has no nodes")
            }
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                isLoading = false
                return
            }
            errorMessage = error.localizedDescription
            print("❌ JourneyMapViewModel.load error: \(error)")
        }
        
        isLoading = false
    }
}

