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

    enum CodingKeys: String, CodingKey {
      case profile_id
      case dateOfBirth = "date_of_birth"
      case surgeryDate = "surgery_date"
      case lastPtVisit = "last_pt_visit"
      case gender
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

  static func ensurePatientProfile(
    profileId: UUID,
    firstName: String,
    lastName: String,
    dob: Date?,
    surgeryDate: Date?,
    lastPtVisit: Date?,
    gender: String?
  ) async throws -> UUID {
    let df = ISO8601DateFormatter()
    df.formatOptions = [.withFullDate]

    func iso(_ date: Date?) -> String? {
      date.map { df.string(from: $0) }
    }
    
    let dobString = iso(dob)
    let apiGender = gender
    
    // Normalize name inputs for matching (trim whitespace, lowercase)
    let normalizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let normalizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    // STEP 1: Check for matching placeholder (profile_id IS NULL) with matching name, DOB, gender
    struct PlaceholderRow: Decodable {
      let id: UUID
      let first_name: String?
      let last_name: String?
      let date_of_birth: String?
      let gender: String?
    }
    
    // Query for placeholders with NULL profile_id
    var placeholderQuery = client
      .schema("accounts")
      .from("patient_profiles")
      .select("id,first_name,last_name,date_of_birth,gender")
      .is("profile_id", value: nil)
    
    // Match on normalized names (case-insensitive comparison via Postgres)
    // Note: We'll filter in Swift for exact matching after fetching
    let allPlaceholders: [PlaceholderRow] = try await placeholderQuery
      .decoded()
    
    // Find matching placeholder by comparing normalized values
    let matchingPlaceholder = allPlaceholders.first { placeholder in
      let placeholderFirstName = (placeholder.first_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      let placeholderLastName = (placeholder.last_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      
      guard placeholderFirstName == normalizedFirstName && placeholderLastName == normalizedLastName else {
        return false
      }
      
      // Match DOB if provided
      if let dobString = dobString {
        guard placeholder.date_of_birth == dobString else { return false }
      } else {
        guard placeholder.date_of_birth == nil else { return false }
      }
      
      // Match gender if provided
      if let apiGender = apiGender {
        guard placeholder.gender == apiGender else { return false }
      } else {
        guard placeholder.gender == nil else { return false }
      }
      
      return true
    }
    
    // STEP 2: If matching placeholder found, UPDATE it to link to this profile
    if let placeholder = matchingPlaceholder {
      print("🔗 PatientService.ensurePatientProfile: found matching placeholder \(placeholder.id), linking to profile \(profileId)")
      
      // Update the placeholder to set profile_id and other fields
      let updatePayload = PatientProfileUpsert(
        profile_id: profileId,
        dateOfBirth: dobString,
        surgeryDate: iso(surgeryDate),
        lastPtVisit: iso(lastPtVisit),
        gender: apiGender
      )
      
      do {
        _ = try await client
          .schema("accounts")
          .from("patient_profiles")
          .update(updatePayload)
          .eq("id", value: placeholder.id.uuidString)
          .execute()
        
        print("✅ PatientService.ensurePatientProfile: linked placeholder \(placeholder.id) to profile \(profileId)")
        
        // Note: pt_patient_map link should already exist from when PT created the placeholder
        // The link is preserved because we're only updating the patient_profiles row, not deleting it
        
        return placeholder.id
      } catch {
        print("❌ PatientService.ensurePatientProfile: failed to update placeholder \(placeholder.id): \(error)")
        throw error
      }
    }

    // STEP 3: No matching placeholder found, proceed with normal upsert/insert
    print("ℹ️ PatientService.ensurePatientProfile: no matching placeholder found, creating new profile")
    
    let payload = PatientProfileUpsert(
      profile_id: profileId,
      dateOfBirth: dobString,
      surgeryDate: iso(surgeryDate),
      lastPtVisit: iso(lastPtVisit),
      gender: apiGender
    )

    struct Row: Decodable { let id: UUID }
    
    // Try upsert first
    do {
      let rows: [Row] = try await client
        .schema("accounts").from("patient_profiles")
        .upsert(payload, onConflict: "profile_id")
        .select("id")
        .limit(1)
        .decoded()

      if let row = rows.first {
        print("✅ PatientService.ensurePatientProfile: upserted \(row.id) for profile \(profileId)")
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
        .select("id")
        .limit(1)
        .decoded()
      
      if let row = inserted.first {
        print("✅ PatientService.ensurePatientProfile: inserted new row \(row.id) for profile \(profileId)")
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

