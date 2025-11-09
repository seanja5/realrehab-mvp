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

    let payload = PatientProfileUpsert(
      profile_id: profileId,
      dateOfBirth: iso(dob),
      surgeryDate: iso(surgeryDate),
      lastPtVisit: iso(lastPtVisit),
      gender: gender
    )

    struct Row: Decodable { let id: UUID }
    let rows: [Row] = try await client
      .schema("accounts").from("patient_profiles")
      .upsert(payload, onConflict: "profile_id")
      .select("id")
      .limit(1)
      .decoded()

    if let row = rows.first {
      print("PatientService.ensurePatientProfile: upserted \(row.id) for profile \(profileId)")
      return row.id
    }

    let sel: [Row] = try await client
      .schema("accounts").from("patient_profiles")
      .select("id")
      .eq("profile_id", value: profileId.uuidString)
      .limit(1)
      .decoded()

    guard let found = sel.first else {
      throw NSError(
        domain: "PatientService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Failed to create/find patient_profile"]
      )
    }
    print("PatientService.ensurePatientProfile: found existing \(found.id) for profile \(profileId)")
    return found.id
  }
}

