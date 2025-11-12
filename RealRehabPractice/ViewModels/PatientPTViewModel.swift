import Foundation
import Combine
import Supabase
import PostgREST

public final class PatientPTViewModel: ObservableObject {
  @Published public var name: String = ""
  @Published public var email: String = ""
  @Published public var phone: String = ""
  @Published public var isLoading: Bool = false
  @Published public var errorMessage: String?
  @Published public var hasRehabPlan: Bool = false

  private var injectedPatientProfileId: UUID?

  public init(patientProfileId: UUID? = nil) {
    self.injectedPatientProfileId = patientProfileId
  }

  @MainActor
  public func load() async {
    isLoading = true
    errorMessage = nil
    do {
      guard let profile = try await AuthService.myProfile() else {
        throw NSError(domain: "PatientPTViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
      }

      var patientProfileId: UUID? = injectedPatientProfileId
      if patientProfileId == nil {
        if let id = try? await PatientService.myPatientProfileId(profileId: profile.id) {
          patientProfileId = id
        } else {
          struct Row: Decodable { let id: UUID }
          let rows: [Row] = try await SupabaseService.shared.client
            .schema("accounts")
            .from("patient_profiles")
            .select("id")
            .eq("profile_id", value: profile.id.uuidString)
            .limit(1)
            .decoded()
          patientProfileId = rows.first?.id
        }
      }

      guard let pid = patientProfileId else {
        throw NSError(domain: "PatientPTViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "No patient profile found"])
      }

      struct PTRow: Decodable {
        let id: UUID
        let email: String?
        let first_name: String?
        let last_name: String?
        let phone: String?
      }
      
      print("🔍 PatientPTViewModel: querying PT for patient_profile_id \(pid)")
      
      let rows: [PTRow] = try await SupabaseService.shared.client
        .schema("accounts")
        .from("pt_profiles")
        .select("id,email,first_name,last_name,phone,pt_patient_map!inner(patient_profile_id)")
        .eq("pt_patient_map.patient_profile_id", value: pid.uuidString)
        .limit(1)
        .decoded()
      
      let pt = rows.first
      
      if let pt = pt {
        print("✅ PatientPTViewModel: found PT \(pt.id) for patient \(pid)")
        self.apply(ptEmail: pt.email, first: pt.first_name, last: pt.last_name, phone: pt.phone)
      } else {
        print("⚠️ PatientPTViewModel: no PT found for patient \(pid) - patient may not be mapped to a PT")
        self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
      }
      
      // Check for active rehab plan
      if let ptId = pt?.id {
        struct PlanRow: Decodable {
          let id: UUID
        }
        let planRows: [PlanRow] = try await SupabaseService.shared.client
          .schema("accounts")
          .from("rehab_plans")
          .select("id")
          .eq("pt_profile_id", value: ptId.uuidString)
          .eq("patient_profile_id", value: pid.uuidString)
          .eq("status", value: "active")
          .limit(1)
          .decoded()
        self.hasRehabPlan = planRows.first != nil
        print("✅ PatientPTViewModel: hasRehabPlan = \(self.hasRehabPlan)")
      } else {
        self.hasRehabPlan = false
      }

      isLoading = false
    } catch {
      isLoading = false
      errorMessage = (error as NSError).localizedDescription
      print("❌ PatientPTViewModel load error: \(error)")
      if let postgrestError = error as? PostgrestError {
        print("❌ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
      }
      // Set empty values on error so UI shows "Your Physical Therapist" with no info
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

