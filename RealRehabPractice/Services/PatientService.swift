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
  
  struct PatientProfileRow: Decodable {
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

  // Resolve the current user's patient_profiles.id from profiles.id
  static func myPatientProfileId(profileId: UUID) async throws -> UUID {
    let rows: [IdRow] = try await client
      .schema("accounts").from("patient_profiles")
      .select("id")
      .eq("profile_id", value: profileId.uuidString)
      .limit(1)
      .decoded()
    guard let r = rows.first else {
      throw NSError(domain: "PatientService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No patient_profile row for current user"])
    }
    return r.id
  }
  
  // Fetch the current user's patient profile
  static func myPatientProfile() async throws -> PatientProfileRow {
    guard let profile = try await AuthService.myProfile() else {
      throw NSError(domain: "PatientService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
    }
    
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
    
    return row
  }
  
  // Get email from profiles table
  static func getEmail(profileId: UUID) async throws -> String? {
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
    
    return rows.first?.email
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
  static func upsertPTMapping(patientProfileId: UUID, ptProfileId: UUID) async throws {
    let payload = PTMapUpsert(patient_profile_id: patientProfileId, pt_profile_id: ptProfileId)
    _ = try await client
      .schema("accounts").from("pt_patient_map")
      .upsert(payload, onConflict: "patient_profile_id")
      .execute()
    print("PatientService.upsertPTMapping: linked patient_profile \(patientProfileId) to pt_profile \(ptProfileId)")
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
    let df = ISO8601DateFormatter()
    df.formatOptions = [.withFullDate]

    func iso(_ date: Date?) -> String? {
      date.map { df.string(from: $0) }
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

