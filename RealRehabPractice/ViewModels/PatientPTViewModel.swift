import Foundation
import Combine
import Supabase
import PostgREST

public final class PatientPTViewModel: ObservableObject {
  @Published public var name: String = ""
  @Published public var email: String = ""
  @Published public var phone: String = ""
  @Published public var isLoading: Bool = true  // Start true so PTDetailView shows skeleton until load completes
  @Published public var errorMessage: String?
  @Published public var hasRehabPlan: Bool = false

  private var injectedPatientProfileId: UUID?

  public init(patientProfileId: UUID? = nil) {
    self.injectedPatientProfileId = patientProfileId
  }

  @MainActor
  public func load() async {
    // Only show loading if we don't have data yet
    if name.isEmpty && email.isEmpty && phone.isEmpty {
      isLoading = true
    }
    errorMessage = nil
    do {
      guard let profile = try await AuthService.myProfile() else {
        throw NSError(domain: "PatientPTViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
      }

      var patientProfileId: UUID? = injectedPatientProfileId
      if patientProfileId == nil {
        patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
      }

      guard let pid = patientProfileId else {
        throw NSError(domain: "PatientPTViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "No patient profile found"])
      }

      print("🔍 PatientPTViewModel: querying PT for patient_profile_id \(pid)")
      
      // STEP 1: Get PT profile ID from patient profile ID (using cached service)
      print("📝 PatientPTViewModel: Step 1 - getting PT profile ID for patient_profile_id=\(pid)")
      guard let ptProfileId = try await PatientService.getPTProfileId(patientProfileId: pid) else {
        print("⚠️ PatientPTViewModel: no pt_patient_map row found for patient_profile_id=\(pid)")
        print("⚠️ This means the patient is not linked to a PT")
        self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
        self.hasRehabPlan = false
        isLoading = false
        return
      }
      
      print("✅ PatientPTViewModel: Step 1 - found pt_profile_id=\(ptProfileId)")
      
      // STEP 2: Get PT info using cached service
      print("📝 PatientPTViewModel: Step 2 - getting PT info for pt_profile_id=\(ptProfileId)")
      guard let ptInfo = try await PatientService.getPTInfo(ptProfileId: ptProfileId) else {
        print("⚠️ PatientPTViewModel: PT info not found for pt_profile_id=\(ptProfileId)")
        self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
        self.hasRehabPlan = false
        isLoading = false
        return
      }
      
      print("✅ PatientPTViewModel: Step 2 - found PT \(ptInfo.id) for patient \(pid)")
      self.apply(ptEmail: ptInfo.email, first: ptInfo.first_name, last: ptInfo.last_name, phone: ptInfo.phone)
      
      // STEP 3: Check for active rehab plan using cached service
      print("📝 PatientPTViewModel: Step 3 - checking for active rehab plan")
      let plan = try await RehabService.currentPlan(ptProfileId: ptProfileId, patientProfileId: pid)
      self.hasRehabPlan = plan != nil
      print("✅ PatientPTViewModel: hasRehabPlan = \(self.hasRehabPlan)")

      isLoading = false
    } catch {
      // Ignore cancellation errors when navigating quickly
      if error is CancellationError || Task.isCancelled {
        isLoading = false
        return
      }
      isLoading = false
      errorMessage = (error as NSError).localizedDescription
      print("❌ PatientPTViewModel load error: \(error)")
      if let postgrestError = error as? PostgrestError {
        print("❌ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
      }
      // Set empty values on error so UI shows "My Physical Therapist" with no info
      self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
      self.hasRehabPlan = false
    }
  }

  @MainActor
  private func apply(ptEmail: String?, first: String?, last: String?, phone: String?) {
    self.email = ptEmail ?? ""
    self.phone = phone ?? ""
    let parts = [first, last].compactMap { $0 }.filter { !$0.isEmpty }
    self.name = parts.isEmpty ? "" : parts.joined(separator: " ")
  }
}

