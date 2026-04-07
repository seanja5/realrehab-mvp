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
  @Published public var ptProfileId: UUID?
  @Published public var patientProfileId: UUID?
  @Published public var practiceName: String = ""
  @Published public var practiceAddress: String = ""
  @Published public var specialization: String = ""
  @Published public var credentialType: String = ""
  @Published public var licenseNumber: String = ""
  @Published public var npiNumber: String = ""

  private var injectedPatientProfileId: UUID?

  // MARK: - Static in-memory store
  // Restored synchronously in init() so the loading skeleton never flashes on repeat tab visits.
  private static var sharedName: String = ""
  private static var sharedEmail: String = ""
  private static var sharedPhone: String = ""
  private static var sharedPracticeName: String = ""
  private static var sharedPracticeAddress: String = ""
  private static var sharedSpecialization: String = ""
  private static var sharedCredentialType: String = ""
  private static var sharedLicenseNumber: String = ""
  private static var sharedNpiNumber: String = ""
  private static var sharedHasRehabPlan: Bool = false
  private static var sharedPtProfileId: UUID? = nil
  private static var sharedPatientProfileId: UUID? = nil

  public init(patientProfileId: UUID? = nil) {
    self.injectedPatientProfileId = patientProfileId
    if !Self.sharedName.isEmpty || !Self.sharedEmail.isEmpty {
      self.name = Self.sharedName
      self.email = Self.sharedEmail
      self.phone = Self.sharedPhone
      self.practiceName = Self.sharedPracticeName
      self.practiceAddress = Self.sharedPracticeAddress
      self.specialization = Self.sharedSpecialization
      self.credentialType = Self.sharedCredentialType
      self.licenseNumber = Self.sharedLicenseNumber
      self.npiNumber = Self.sharedNpiNumber
      self.hasRehabPlan = Self.sharedHasRehabPlan
      self.ptProfileId = Self.sharedPtProfileId
      self.patientProfileId = Self.sharedPatientProfileId
      self.isLoading = false
    }
  }

  /// Call on sign-out so a subsequent login sees a clean state.
  public static func clearSharedCache() {
    sharedName = ""
    sharedEmail = ""
    sharedPhone = ""
    sharedPracticeName = ""
    sharedPracticeAddress = ""
    sharedSpecialization = ""
    sharedCredentialType = ""
    sharedLicenseNumber = ""
    sharedNpiNumber = ""
    sharedHasRehabPlan = false
    sharedPtProfileId = nil
    sharedPatientProfileId = nil
  }

  @MainActor
  public func load(forceRefresh: Bool = false) async {
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

      debugLog("🔍 PatientPTViewModel: querying PT for patient_profile_id \(pid)")
      
      // STEP 1: Get PT profile ID from patient profile ID (using cached service)
      debugLog("📝 PatientPTViewModel: Step 1 - getting PT profile ID for patient_profile_id=\(pid)")
      guard let ptProfileId = try await PatientService.getPTProfileId(patientProfileId: pid) else {
        debugLog("⚠️ PatientPTViewModel: no pt_patient_map row found for patient_profile_id=\(pid)")
        debugLog("⚠️ This means the patient is not linked to a PT")
        self.ptProfileId = nil
        self.patientProfileId = nil
        self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
        self.hasRehabPlan = false
        isLoading = false
        return
      }
      self.ptProfileId = ptProfileId
      self.patientProfileId = pid
      debugLog("✅ PatientPTViewModel: Step 1 - found pt_profile_id=\(ptProfileId)")

      if forceRefresh {
        await CacheService.shared.invalidate("pt_info_by_id_v3:\(ptProfileId.uuidString)")
      }
      
      // STEP 2: Get PT info using cached service
      debugLog("📝 PatientPTViewModel: Step 2 - getting PT info for pt_profile_id=\(ptProfileId)")
      guard let ptInfo = try await PatientService.getPTInfo(ptProfileId: ptProfileId) else {
        debugLog("⚠️ PatientPTViewModel: PT info not found for pt_profile_id=\(ptProfileId)")
        self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
        self.hasRehabPlan = false
        isLoading = false
        return
      }
      
      debugLog("✅ PatientPTViewModel: Step 2 - found PT \(ptInfo.id) for patient \(pid)")
      self.apply(ptEmail: ptInfo.email, first: ptInfo.first_name, last: ptInfo.last_name, phone: ptInfo.phone, practiceName: ptInfo.practice_name, practiceAddress: ptInfo.practice_address, specialization: ptInfo.specialization, credentialType: ptInfo.pt_credential_type, licenseNumber: ptInfo.license_number, npiNumber: ptInfo.npi_number)
      
      // STEP 3: Check for active rehab plan using cached service
      debugLog("📝 PatientPTViewModel: Step 3 - checking for active rehab plan")
      let plan = try await RehabService.currentPlan(ptProfileId: ptProfileId, patientProfileId: pid)
      self.hasRehabPlan = plan != nil
      debugLog("✅ PatientPTViewModel: hasRehabPlan = \(self.hasRehabPlan)")

      // Persist to static store so next ViewModel init restores instantly
      Self.sharedName = name
      Self.sharedEmail = email
      Self.sharedPhone = phone
      Self.sharedPracticeName = practiceName
      Self.sharedPracticeAddress = practiceAddress
      Self.sharedSpecialization = specialization
      Self.sharedCredentialType = credentialType
      Self.sharedLicenseNumber = licenseNumber
      Self.sharedNpiNumber = npiNumber
      Self.sharedHasRehabPlan = hasRehabPlan
      Self.sharedPtProfileId = ptProfileId
      Self.sharedPatientProfileId = patientProfileId

      isLoading = false
    } catch {
      // Ignore cancellation errors when navigating quickly
      if error is CancellationError || Task.isCancelled {
        isLoading = false
        return
      }
      isLoading = false
      errorMessage = (error as NSError).localizedDescription
      debugLog("❌ PatientPTViewModel load error: \(error)")
      if let postgrestError = error as? PostgrestError {
        debugLog("❌ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
      }
      self.ptProfileId = nil
      self.patientProfileId = nil
      self.apply(ptEmail: nil, first: nil, last: nil, phone: nil)
      self.hasRehabPlan = false
    }
  }

  @MainActor
  private func apply(ptEmail: String?, first: String?, last: String?, phone: String?, practiceName: String? = nil, practiceAddress: String? = nil, specialization: String? = nil, credentialType: String? = nil, licenseNumber: String? = nil, npiNumber: String? = nil) {
    self.email = ptEmail ?? ""
    self.phone = phone ?? ""
    let parts = [first, last].compactMap { $0 }.filter { !$0.isEmpty }
    self.name = parts.isEmpty ? "" : parts.joined(separator: " ")
    self.practiceName = practiceName ?? ""
    self.practiceAddress = practiceAddress ?? ""
    self.specialization = specialization ?? ""
    self.credentialType = credentialType ?? ""
    self.licenseNumber = licenseNumber ?? ""
    self.npiNumber = npiNumber ?? ""
  }
}

