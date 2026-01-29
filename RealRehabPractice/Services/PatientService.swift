import Foundation
import Supabase
import PostgREST

enum PatientService {
  private static var client: SupabaseClient { SupabaseService.shared.client }

  // MARK: - DTOs
  struct PTProfileRow: Decodable {
    let id: UUID
    let email: String?
    let first_name: String?
    let last_name: String?
    let phone: String?
  }
  
  struct PatientProfileRow: Codable {
    let id: UUID
    let profile_id: UUID?
    let first_name: String?
    let last_name: String?
    let date_of_birth: String?
    let gender: String?
    let phone: String?
    let surgery_date: String?
    let last_pt_visit: String?
  }

  struct PTProfileUpsert: Encodable {
    let email: String
    let first_name: String?
    let last_name: String?
    let phone: String?
  }

  private struct PTMapUpsert: Encodable {
    let patient_profile_id: UUID
    let pt_profile_id: UUID
  }

  private struct IdRow: Decodable { let id: UUID }

  private struct PatientProfileUpsert: Encodable {
    let profile_id: UUID
    let dateOfBirth: String?
    let surgeryDate: String?
    let lastPtVisit: String?
    let gender: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
      case profile_id
      case dateOfBirth = "date_of_birth"
      case surgeryDate = "surgery_date"
      case lastPtVisit = "last_pt_visit"
      case gender
      case phone
    }
  }

  // Resolve the current user's patient_profiles.id from profiles.id (with caching)
  static func myPatientProfileId(profileId: UUID) async throws -> UUID {
    let cacheKey = CacheKey.patientProfileId(profileId: profileId)
    
    // Check cache first (disk persistence enabled, 24h TTL)
    if let cached = await CacheService.shared.getCached(cacheKey, as: UUID.self, useDisk: true) {
      print("✅ PatientService.myPatientProfileId: cache hit")
      return cached
    }
    
    // Fetch from Supabase
    let rows: [IdRow] = try await client
      .schema("accounts").from("patient_profiles")
      .select("id")
      .eq("profile_id", value: profileId.uuidString)
      .limit(1)
      .decoded()
    guard let r = rows.first else {
      throw NSError(domain: "PatientService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No patient_profile row for current user"])
    }
    
    // Cache the result (disk persistence enabled, 24h TTL)
    await CacheService.shared.setCached(r.id, forKey: cacheKey, ttl: CacheService.TTL.profile, useDisk: true)
    print("✅ PatientService.myPatientProfileId: cached result")
    
    return r.id
  }
  
  // Check if patient has a PT (with caching)
  static func hasPT(patientProfileId: UUID) async throws -> Bool {
    let cacheKey = CacheKey.hasPT(patientProfileId: patientProfileId)
    
    // Check cache first (memory only)
    if let cached = await CacheService.shared.getCached(cacheKey, as: Bool.self, useDisk: false) {
      print("✅ PatientService.hasPT: cache hit")
      return cached
    }
    
    // Fetch from Supabase
    struct MapRow: Decodable {
      let pt_profile_id: UUID
    }
    
    let mapRows: [MapRow] = try await client
      .schema("accounts")
      .from("pt_patient_map")
      .select("pt_profile_id")
      .eq("patient_profile_id", value: patientProfileId.uuidString)
      .limit(1)
      .decoded()
    
    let hasPT = mapRows.first != nil
    
    // Cache the result (memory only)
    await CacheService.shared.setCached(hasPT, forKey: cacheKey, ttl: CacheService.TTL.hasPT, useDisk: false)
    print("✅ PatientService.hasPT: cached result = \(hasPT)")
    
    return hasPT
  }
  
  // Fetch the current user's patient profile (with caching)
  static func myPatientProfile() async throws -> PatientProfileRow {
    guard let profile = try await AuthService.myProfile() else {
      throw NSError(domain: "PatientService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
    }
    
    let cacheKey = CacheKey.patientProfile(userId: profile.id)
    
    // Check cache first (disk persistence enabled)
    if let cached = await CacheService.shared.getCached(cacheKey, as: PatientProfileRow.self, useDisk: true) {
      print("✅ PatientService.myPatientProfile: cache hit")
      return cached
    }
    
    // Fetch from Supabase
    let rows: [PatientProfileRow] = try await client
      .schema("accounts")
      .from("patient_profiles")
      .select("id,profile_id,first_name,last_name,date_of_birth,gender,phone,surgery_date,last_pt_visit")
      .eq("profile_id", value: profile.id.uuidString)
      .limit(1)
      .decoded()
    
    guard let row = rows.first else {
      throw NSError(domain: "PatientService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Patient profile not found"])
    }
    
    // Cache the result (disk persistence enabled)
    await CacheService.shared.setCached(row, forKey: cacheKey, ttl: CacheService.TTL.profile, useDisk: true)
    print("✅ PatientService.myPatientProfile: cached result")
    
    return row
  }
  
  // Get email from profiles table (with caching)
  static func getEmail(profileId: UUID) async throws -> String? {
    let cacheKey = CacheKey.patientEmail(profileId: profileId)
    
    // Check cache first (disk persistence enabled)
    if let cached = await CacheService.shared.getCached(cacheKey, as: String?.self, useDisk: true) {
      print("✅ PatientService.getEmail: cache hit")
      return cached
    }
    
    // Fetch from Supabase
    struct EmailRow: Decodable {
      let email: String?
    }
    
    let rows: [EmailRow] = try await client
      .schema("accounts")
      .from("profiles")
      .select("email")
      .eq("id", value: profileId.uuidString)
      .limit(1)
      .decoded()
    
    let email = rows.first?.email
    
    // Cache the result (disk persistence enabled)
    await CacheService.shared.setCached(email, forKey: cacheKey, ttl: CacheService.TTL.profile, useDisk: true)
    print("✅ PatientService.getEmail: cached result")
    
    return email
  }
  
  // Get PT profile ID from patient profile ID (with caching)
  static func getPTProfileId(patientProfileId: UUID) async throws -> UUID? {
    let cacheKey = CacheKey.ptProfileIdFromPatient(patientProfileId: patientProfileId)
    
    // Check cache first (memory only, 1h TTL)
    if let cached = await CacheService.shared.getCached(cacheKey, as: UUID?.self, useDisk: false) {
      print("✅ PatientService.getPTProfileId: cache hit")
      return cached
    }
    
    // Fetch from Supabase
    struct MapRow: Decodable {
      let pt_profile_id: UUID
    }
    
    let mapRows: [MapRow] = try await client
      .schema("accounts")
      .from("pt_patient_map")
      .select("pt_profile_id")
      .eq("patient_profile_id", value: patientProfileId.uuidString)
      .limit(1)
      .decoded()
    
    let result = mapRows.first?.pt_profile_id
    
    // Cache the result (memory only, 1h TTL)
    await CacheService.shared.setCached(result, forKey: cacheKey, ttl: CacheService.TTL.hasPT, useDisk: false)
    print("✅ PatientService.getPTProfileId: cached result")
    
    return result
  }
  
  // Get PT info (name, email, phone) by PT profile ID (with caching)
  struct PTInfo: Codable {
    let id: UUID
    let email: String?
    let first_name: String?
    let last_name: String?
    let phone: String?
  }
  
  static func getPTInfo(ptProfileId: UUID) async throws -> PTInfo? {
    let actualKey = "pt_info_by_id:\(ptProfileId.uuidString)"
    
    // Check cache first (memory only, 1h TTL)
    if let cached = await CacheService.shared.getCached(actualKey, as: PTInfo?.self, useDisk: false) {
      print("✅ PatientService.getPTInfo: cache hit")
      return cached
    }
    
    // Fetch from Supabase
    struct PTRow: Decodable {
      let id: UUID
      let email: String?
      let first_name: String?
      let last_name: String?
      let phone: String?
    }
    
    let ptRows: [PTRow] = try await client
      .schema("accounts")
      .from("pt_profiles")
      .select("id,email,first_name,last_name,phone")
      .eq("id", value: ptProfileId.uuidString)
      .limit(1)
      .decoded()
    
    let result = ptRows.first.map { pt in
      PTInfo(id: pt.id, email: pt.email, first_name: pt.first_name, last_name: pt.last_name, phone: pt.phone)
    }
    
    // Cache the result (memory only, 1h TTL)
    await CacheService.shared.setCached(result, forKey: actualKey, ttl: CacheService.TTL.ptInfo, useDisk: false)
    print("✅ PatientService.getPTInfo: cached result")
    
    return result
  }

  // Upsert/find a PT profile by email and return the row
  static func upsertPTProfile(
    email: String,
    first: String?,
    last: String?,
    phone: String?
  ) async throws -> PTProfileRow {
    let payload = PTProfileUpsert(email: email, first_name: first, last_name: last, phone: phone)

    let rows: [PTProfileRow] = try await client
      .schema("accounts").from("pt_profiles")
      .upsert(payload, onConflict: "email")
      .select()
      .limit(1)
      .decoded()

    if let r = rows.first {
      print("PatientService.upsertPTProfile: upsert returned \(r.id) (\(r.email ?? "<no email>"))")
      return r
    }

    let sel: [PTProfileRow] = try await client
      .schema("accounts").from("pt_profiles")
      .select()
      .eq("email", value: email)
      .limit(1)
      .decoded()

    guard let found = sel.first else {
      throw NSError(domain: "PatientService", code: 404, userInfo: [NSLocalizedDescriptionKey: "PT not found after upsert"])
    }
    print("PatientService.upsertPTProfile: selected existing \(found.id) (\(found.email ?? "<no email>"))")
    return found
  }

  // Upsert the patient -> PT mapping (one PT per patient)
  // Uses direct upsert for PT-initiated mappings, RPC for patient-initiated mappings
  static func upsertPTMapping(patientProfileId: UUID, ptProfileId: UUID) async throws {
    let payload = PTMapUpsert(patient_profile_id: patientProfileId, pt_profile_id: ptProfileId)
    _ = try await client
      .schema("accounts").from("pt_patient_map")
      .upsert(payload, onConflict: "patient_profile_id")
      .execute()
    print("PatientService.upsertPTMapping: linked patient_profile \(patientProfileId) to pt_profile \(ptProfileId)")
  }
  
  // Link patient to PT using RPC function (bypasses RLS for patient-initiated linking)
  // Use this when a patient is linking themselves to a PT (e.g., via access code)
  static func linkPatientToPT(patientProfileId: UUID, ptProfileId: UUID) async throws {
    print("🔗 PatientService.linkPatientToPT: linking patient_profile \(patientProfileId) to pt_profile \(ptProfileId)")
    
    // Create params in a nonisolated context to avoid Sendable issues
    try await Task { @Sendable in
      struct RPCParams: Encodable {
        let patient_profile_id_param: String
        let pt_profile_id_param: String
      }
      
      let params = RPCParams(
        patient_profile_id_param: patientProfileId.uuidString,
        pt_profile_id_param: ptProfileId.uuidString
      )
      
      // Call RPC function that bypasses RLS
      try await client
        .database
        .rpc("link_patient_to_pt", params: params)
        .execute()
    }.value
    
    print("✅ PatientService.linkPatientToPT: successfully linked patient_profile \(patientProfileId) to pt_profile \(ptProfileId)")
  }
  
  // Link patient to PT via access code - updates placeholder instead of creating duplicate
  // This is the preferred method when linking via access code
  static func linkPatientViaAccessCode(accessCode: String, patientProfileId: UUID) async throws {
    print("🔗 PatientService.linkPatientViaAccessCode: linking patient_profile \(patientProfileId) via access code")
    
    let normalizedCode = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Create params in a nonisolated context to avoid Sendable issues
    try await Task { @Sendable in
      struct RPCParams: Encodable {
        let access_code_param: String
        let patient_profile_id_param: String
      }
      
      let params = RPCParams(
        access_code_param: normalizedCode,
        patient_profile_id_param: patientProfileId.uuidString
      )
      
      // Call RPC function that updates placeholder and handles duplicates
      try await client
        .database
        .rpc("link_patient_via_access_code", params: params)
        .execute()
    }.value
    
    print("✅ PatientService.linkPatientViaAccessCode: successfully linked patient_profile \(patientProfileId) via access code")
  }

  // Get PT profile ID by access code (for linking existing accounts)
  // Uses RPC function to bypass RLS and get PT ID from placeholder mapping
  static func getPTProfileIdByAccessCode(_ code: String) async throws -> UUID? {
    let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !normalizedCode.isEmpty else {
      return nil
    }
    
    print("🔍 PatientService.getPTProfileIdByAccessCode: searching for code '\(normalizedCode)'")
    
    // Create params in a nonisolated context to avoid Sendable issues
    let uuidString: String? = try await Task { @Sendable in
      struct RPCParams: Encodable {
        let access_code_param: String
      }
      
      let params = RPCParams(access_code_param: normalizedCode)
      
      // RPC returns UUID as string, or null if not found
      return try await client
        .database
        .rpc("get_pt_profile_id_by_access_code", params: params)
        .single()
        .execute()
        .value
    }.value
    
    if let uuidString = uuidString, let ptProfileId = UUID(uuidString: uuidString) {
      print("✅ PatientService.getPTProfileIdByAccessCode: found PT \(ptProfileId) for code '\(normalizedCode)'")
      return ptProfileId
    } else {
      print("ℹ️ PatientService.getPTProfileIdByAccessCode: no PT found for code '\(normalizedCode)'")
      return nil
    }
  }

  // Find patient profile by access code
  // Returns patient_profile_id if found, nil otherwise
  static func findPatientByAccessCode(_ code: String) async throws -> UUID? {
    struct AccessCodeRow: Decodable {
      let id: UUID
    }
    
    // Normalize the code (trim whitespace)
    let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !normalizedCode.isEmpty else {
      return nil
    }
    
    print("🔍 PatientService.findPatientByAccessCode: searching for code '\(normalizedCode)'")
    
    let rows: [AccessCodeRow] = try await client
      .schema("accounts")
      .from("patient_profiles")
      .select("id")
      .eq("access_code", value: normalizedCode)
      .is("profile_id", value: nil)  // Only find placeholders (not yet linked)
      .limit(1)
      .decoded()
    
    if let row = rows.first {
      print("✅ PatientService.findPatientByAccessCode: found placeholder \(row.id) for code '\(normalizedCode)'")
      return row.id
    } else {
      print("ℹ️ PatientService.findPatientByAccessCode: no placeholder found for code '\(normalizedCode)'")
      return nil
    }
  }

  static func ensurePatientProfile(
    profileId: UUID,
    firstName: String,
    lastName: String,
    dob: Date?,
    surgeryDate: Date?,
    lastPtVisit: Date?,
    gender: String?,
    accessCode: String?,
    phone: String?
  ) async throws -> UUID {
    func iso(_ date: Date?) -> String? {
      date.map { $0.dateOnlyString() }
    }
    
    let dobString = iso(dob)
    let apiGender = gender
    
    // STEP 1: If access code provided, look up placeholder by access code
    var matchingPlaceholderId: UUID? = nil
    
    if let accessCode = accessCode, !accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      print("🔍 PatientService.ensurePatientProfile: looking up placeholder by access code")
      matchingPlaceholderId = try await findPatientByAccessCode(accessCode)
      
      if matchingPlaceholderId != nil {
        print("✅ PatientService.ensurePatientProfile: found placeholder by access code!")
      } else {
        print("ℹ️ PatientService.ensurePatientProfile: no placeholder found for access code '\(accessCode)'")
      }
    } else {
      print("ℹ️ PatientService.ensurePatientProfile: no access code provided, will create new profile")
    }
    
    // STEP 2: If matching placeholder found, UPDATE it to link to this profile
    if let placeholderId = matchingPlaceholderId {
      print("🔗 PatientService.ensurePatientProfile: found placeholder \(placeholderId), linking to profile \(profileId)")
      print("🔍 PatientService.ensurePatientProfile: attempting to update patient_profiles.id=\(placeholderId) to set profile_id=\(profileId)")
      
      // Update the placeholder to set profile_id and other fields
      let trimmedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
      let phoneToSave = trimmedPhone?.isEmpty == false ? trimmedPhone : nil
      print("📱 PatientService.ensurePatientProfile: updating placeholder with phone='\(phoneToSave ?? "nil")'")
      
      let updatePayload = PatientProfileUpsert(
        profile_id: profileId,
        dateOfBirth: dobString,
        surgeryDate: iso(surgeryDate),
        lastPtVisit: iso(lastPtVisit),
        gender: apiGender,
        phone: phoneToSave
      )
      
      do {
        print("📝 PatientService.ensurePatientProfile: executing UPDATE on patient_profiles...")
        _ = try await client
          .schema("accounts")
          .from("patient_profiles")
          .update(updatePayload)
          .eq("id", value: placeholderId.uuidString)
          .execute()
        
        print("✅ PatientService.ensurePatientProfile: UPDATE executed successfully")
        
        // Verify the update actually worked by querying the row
        struct VerifyRow: Decodable {
          let id: UUID
          let profile_id: UUID?
          let phone: String?
        }
        
        do {
          let verifyRows: [VerifyRow] = try await client
            .schema("accounts")
            .from("patient_profiles")
            .select("id,profile_id,phone")
            .eq("id", value: placeholderId.uuidString)
            .limit(1)
            .decoded()
          
          if let row = verifyRows.first {
            if row.profile_id == profileId {
              print("✅ PatientService.ensurePatientProfile: verified profile_id was updated correctly to \(profileId)")
            } else {
              print("⚠️ PatientService.ensurePatientProfile: WARNING - profile_id is \(row.profile_id?.uuidString ?? "NULL"), expected \(profileId)")
            }
            // Verify phone was saved
            if let savedPhone = row.phone, !savedPhone.isEmpty {
              print("✅ PatientService.ensurePatientProfile: verified phone was saved: '\(savedPhone)'")
            } else if phoneToSave != nil {
              print("⚠️ PatientService.ensurePatientProfile: WARNING - phone was NOT saved! Expected '\(phoneToSave!)', but got NULL")
            } else {
              print("ℹ️ PatientService.ensurePatientProfile: phone is NULL (no phone provided)")
            }
          } else {
            print("⚠️ PatientService.ensurePatientProfile: WARNING - could not find row after update")
          }
        } catch {
          print("⚠️ PatientService.ensurePatientProfile: could not verify update: \(error)")
        }
        
        // Verify pt_patient_map link exists after update
        // The link should already exist from when PT created the placeholder
        struct MapRow: Decodable {
          let pt_profile_id: UUID
        }
        
        do {
          print("🔍 PatientService.ensurePatientProfile: verifying pt_patient_map link for patient_profile_id=\(placeholderId)")
          let mapRows: [MapRow] = try await client
            .schema("accounts")
            .from("pt_patient_map")
            .select("pt_profile_id")
            .eq("patient_profile_id", value: placeholderId.uuidString)
            .limit(1)
            .decoded()
          
          if let map = mapRows.first {
            print("✅ PatientService.ensurePatientProfile: verified pt_patient_map link exists to PT \(map.pt_profile_id)")
          } else {
            print("⚠️ PatientService.ensurePatientProfile: WARNING - no pt_patient_map link found for placeholder \(placeholderId)")
            print("⚠️ This means the patient will not be able to see their PT in PTDetailView")
          }
        } catch {
          print("⚠️ PatientService.ensurePatientProfile: could not verify pt_patient_map link: \(error)")
          if let postgrestError = error as? PostgrestError {
            print("⚠️ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
          }
          // Don't throw - the link might still exist, we just can't verify it due to RLS
        }
        
        return placeholderId
      } catch {
        print("❌ PatientService.ensurePatientProfile: failed to update placeholder \(placeholderId): \(error)")
        if let postgrestError = error as? PostgrestError {
          print("❌ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
          print("❌ This is likely an RLS policy issue preventing the UPDATE")
        }
        throw error
      }
    }

    // STEP 3: No matching placeholder found, proceed with normal upsert/insert
    print("ℹ️ PatientService.ensurePatientProfile: no matching placeholder found, creating new profile")
    
    let trimmedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
    let phoneToSave = trimmedPhone?.isEmpty == false ? trimmedPhone : nil
    print("📱 PatientService.ensurePatientProfile: creating new profile with phone='\(phoneToSave ?? "nil")'")
    
    let payload = PatientProfileUpsert(
      profile_id: profileId,
      dateOfBirth: dobString,
      surgeryDate: iso(surgeryDate),
      lastPtVisit: iso(lastPtVisit),
      gender: apiGender,
      phone: phoneToSave
    )

    struct Row: Decodable { 
      let id: UUID
      let phone: String?
    }
    
    // Try upsert first
    do {
      let rows: [Row] = try await client
        .schema("accounts").from("patient_profiles")
        .upsert(payload, onConflict: "profile_id")
        .select("id,phone")
        .limit(1)
        .decoded()

      if let row = rows.first {
        print("✅ PatientService.ensurePatientProfile: upserted \(row.id) for profile \(profileId)")
        if let savedPhone = row.phone, !savedPhone.isEmpty {
          print("✅ PatientService.ensurePatientProfile: verified phone was saved via upsert: '\(savedPhone)'")
        } else if phoneToSave != nil {
          print("⚠️ PatientService.ensurePatientProfile: WARNING - phone was NOT saved via upsert! Expected '\(phoneToSave!)', but got NULL")
        } else {
          print("ℹ️ PatientService.ensurePatientProfile: phone is NULL (no phone provided)")
        }
        return row.id
      }
    } catch {
      print("⚠️ PatientService.ensurePatientProfile: upsert failed, trying direct insert: \(error)")
      // Fall through to direct insert
    }
    
    // If upsert failed or returned no rows, try direct insert
    do {
      let inserted: [Row] = try await client
        .schema("accounts").from("patient_profiles")
        .insert(payload, returning: .representation)
        .select("id,phone")
        .limit(1)
        .decoded()
      
      if let row = inserted.first {
        print("✅ PatientService.ensurePatientProfile: inserted new row \(row.id) for profile \(profileId)")
        if let savedPhone = row.phone, !savedPhone.isEmpty {
          print("✅ PatientService.ensurePatientProfile: verified phone was saved via insert: '\(savedPhone)'")
        } else if phoneToSave != nil {
          print("⚠️ PatientService.ensurePatientProfile: WARNING - phone was NOT saved via insert! Expected '\(phoneToSave!)', but got NULL")
        } else {
          print("ℹ️ PatientService.ensurePatientProfile: phone is NULL (no phone provided)")
        }
        return row.id
      }
    } catch {
      print("❌ PatientService.ensurePatientProfile: insert also failed: \(error)")
      // Fall through to select as last resort
    }

    // Last resort: try to find existing row
    let sel: [Row] = try await client
      .schema("accounts").from("patient_profiles")
      .select("id")
      .eq("profile_id", value: profileId.uuidString)
      .limit(1)
      .decoded()

    if let found = sel.first {
      print("✅ PatientService.ensurePatientProfile: found existing \(found.id) for profile \(profileId)")
      return found.id
    }
    
    // If we get here, everything failed
    throw NSError(
      domain: "PatientService",
      code: 500,
      userInfo: [NSLocalizedDescriptionKey: "Failed to create or find patient_profile after all attempts"]
    )
  }
}

