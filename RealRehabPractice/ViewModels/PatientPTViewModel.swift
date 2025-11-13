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

      print("🔍 PatientPTViewModel: querying PT for patient_profile_id \(pid)")
      print("🔍 PatientPTViewModel: current user profile_id=\(profile.id)")
      
      // Diagnostic: Check patient_profiles row to see if profile_id is set
      struct PatientProfileCheck: Decodable {
        let id: UUID
        let profile_id: UUID?
        let access_code: String?
      }
      
      do {
        let checkRows: [PatientProfileCheck] = try await SupabaseService.shared.client
          .schema("accounts")
          .from("patient_profiles")
          .select("id,profile_id,access_code")
          .eq("id", value: pid.uuidString)
          .limit(1)
          .decoded()
        
        if let check = checkRows.first {
          print("📊 PatientPTViewModel: patient_profiles row check:")
          print("   - id: \(check.id)")
          print("   - profile_id: \(check.profile_id?.uuidString ?? "NULL")")
          print("   - access_code: \(check.access_code ?? "NULL")")
          print("   - Expected profile_id: \(profile.id)")
          
          if check.profile_id == nil {
            print("⚠️ PatientPTViewModel: CRITICAL - profile_id is NULL! The UPDATE during signup may have failed.")
          } else if check.profile_id != profile.id {
            print("⚠️ PatientPTViewModel: WARNING - profile_id mismatch! Row has \(check.profile_id?.uuidString ?? "NULL"), expected \(profile.id)")
          } else {
            print("✅ PatientPTViewModel: profile_id matches correctly")
          }
        } else {
          print("⚠️ PatientPTViewModel: Could not find patient_profiles row with id=\(pid)")
        }
      } catch {
        print("⚠️ PatientPTViewModel: Could not check patient_profiles row: \(error)")
      }
      
      // STEP 1: Query pt_patient_map directly to get pt_profile_id
      struct MapRow: Decodable {
        let pt_profile_id: UUID
      }
      
      print("📝 PatientPTViewModel: Step 1 - querying pt_patient_map for patient_profile_id=\(pid)")
      let mapRows: [MapRow] = try await SupabaseService.shared.client
        .schema("accounts")
        .from("pt_patient_map")
        .select("pt_profile_id")
        .eq("patient_profile_id", value: pid.uuidString)
        .limit(1)
        .decoded()
      
      guard let mapRow = mapRows.first else {
        print("⚠️ PatientPTViewModel: no pt_patient_map row found for patient_profile_id=\(pid)")
        print("⚠️ This means the patient is not linked to a PT")
        
        // Diagnostic: Check if ANY pt_patient_map rows exist for this patient
        struct AllMapRows: Decodable {
          let id: UUID
          let patient_profile_id: UUID
          let pt_profile_id: UUID
        }
        
        do {
          let allMaps: [AllMapRows] = try await SupabaseService.shared.client
            .schema("accounts")
            .from("pt_patient_map")
            .select("id,patient_profile_id,pt_profile_id")
            .eq("patient_profile_id", value: pid.uuidString)
            .decoded()
          
          if allMaps.isEmpty {
            print("⚠️ PatientPTViewModel: No pt_patient_map rows exist for patient_profile_id=\(pid)")
            print("⚠️ This suggests the mapping was never created when PT added the patient, OR RLS is blocking the query")
          } else {
            print("⚠️ PatientPTViewModel: Found \(allMaps.count) pt_patient_map row(s), but RLS may be blocking access:")
            for map in allMaps {
              print("   - id: \(map.id), patient_profile_id: \(map.patient_profile_id), pt_profile_id: \(map.pt_profile_id)")
            }
          }
        } catch {
          print("⚠️ PatientPTViewModel: Could not check pt_patient_map rows: \(error)")
          if let postgrestError = error as? PostgrestError {
            print("⚠️ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
          }
        }
        
        self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
        self.hasRehabPlan = false
        isLoading = false
        return
      }
      
      let ptProfileId = mapRow.pt_profile_id
      print("✅ PatientPTViewModel: Step 1 - found pt_profile_id=\(ptProfileId)")
      
      // STEP 2: Query pt_profiles to get PT details
      struct PTRow: Decodable {
        let id: UUID
        let email: String?
        let first_name: String?
        let last_name: String?
        let phone: String?
      }
      
      print("📝 PatientPTViewModel: Step 2 - querying pt_profiles for pt_profile_id=\(ptProfileId)")
      let ptRows: [PTRow] = try await SupabaseService.shared.client
        .schema("accounts")
        .from("pt_profiles")
        .select("id,email,first_name,last_name,phone")
        .eq("id", value: ptProfileId.uuidString)
        .limit(1)
        .decoded()
      
      guard let pt = ptRows.first else {
        print("⚠️ PatientPTViewModel: pt_profiles row not found for pt_profile_id=\(ptProfileId)")
        self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
        self.hasRehabPlan = false
        isLoading = false
        return
      }
      
      print("✅ PatientPTViewModel: Step 2 - found PT \(pt.id) for patient \(pid)")
      self.apply(ptEmail: pt.email, first: pt.first_name, last: pt.last_name, phone: pt.phone)
      
      // Check for active rehab plan
      struct PlanRow: Decodable {
        let id: UUID
      }
      print("📝 PatientPTViewModel: checking for active rehab plan (pt_profile_id=\(ptProfileId), patient_profile_id=\(pid))")
      let planRows: [PlanRow] = try await SupabaseService.shared.client
        .schema("accounts")
        .from("rehab_plans")
        .select("id")
        .eq("pt_profile_id", value: ptProfileId.uuidString)
        .eq("patient_profile_id", value: pid.uuidString)
        .eq("status", value: "active")
        .limit(1)
        .decoded()
      self.hasRehabPlan = planRows.first != nil
      print("✅ PatientPTViewModel: hasRehabPlan = \(self.hasRehabPlan)")

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

