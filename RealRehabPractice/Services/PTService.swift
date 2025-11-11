import Foundation
import Supabase
import PostgREST

enum PTService {
    private static var client: SupabaseClient { SupabaseService.shared.client }

    struct PTProfileRow: Decodable {
        let id: UUID
        let profile_id: UUID
    }
    
    struct SimplePatient: Decodable {
        let patient_profile_id: UUID
        let first_name: String
        let last_name: String
        let date_of_birth: String?  // Keep as String? for resilience
        let gender: String?          // Can be NULL
        let email: String?
        let phone: String?
        let profile_id: UUID?        // Can be NULL for placeholder patients
    }
    
    struct UUIDWrapper: Decodable {
        let id: UUID
    }

    @MainActor
    static func ensurePTProfile(
        firstName: String,
        lastName: String,
        email: String,
        phone: String,
        licenseNumber: String,
        npiNumber: String,
        practiceName: String?,
        practiceAddress: String?,
        specialization: String?
    ) async throws -> UUID {
        guard let profile = try await AuthService.myProfile() else {
            throw NSError(
                domain: "PTService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load profile after sign-up."]
            )
        }

        let trimmedPracticeName = practiceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPracticeAddress = practiceAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSpecialization = specialization?.trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: [String: AnyEncodable] = [
            "profile_id": AnyEncodable(profile.id.uuidString),
            "first_name": AnyEncodable(firstName),
            "last_name": AnyEncodable(lastName),
            "email": AnyEncodable(email),
            "phone": AnyEncodable(phone),
            "license_number": AnyEncodable(licenseNumber),
            "npi_number": AnyEncodable(npiNumber)
        ]

        if let practiceName = trimmedPracticeName, !practiceName.isEmpty {
            payload["practice_name"] = AnyEncodable(practiceName)
        } else {
            payload["practice_name"] = AnyEncodable(Optional<String>.none)
        }

        if let practiceAddress = trimmedPracticeAddress, !practiceAddress.isEmpty {
            payload["practice_address"] = AnyEncodable(practiceAddress)
        } else {
            payload["practice_address"] = AnyEncodable(Optional<String>.none)
        }

        if let specialization = trimmedSpecialization, !specialization.isEmpty {
            payload["specialization"] = AnyEncodable(specialization)
        } else {
            payload["specialization"] = AnyEncodable(Optional<String>.none)
        }

        let rows: [PTProfileRow] = try await client
            .schema("accounts")
            .from("pt_profiles")
            .upsert(payload, onConflict: "profile_id")
            .select("id,profile_id")
            .limit(1)
            .decoded()

        if let row = rows.first {
            return row.id
        }

        let fetched: [PTProfileRow] = try await client
            .schema("accounts")
            .from("pt_profiles")
            .select("id,profile_id")
            .eq("profile_id", value: profile.id.uuidString)
            .limit(1)
            .decoded()

        guard let existing = fetched.first else {
            throw NSError(
                domain: "PTService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create PT profile."]
            )
        }

        return existing.id
    }
    
    // MARK: - PT Profile Management
    
    @MainActor
    static func myPTProfile() async throws -> PTProfileRow {
        guard let profile = try await AuthService.myProfile() else {
            throw NSError(
                domain: "PTService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load profile"]
            )
        }
        
        let rows: [PTProfileRow] = try await client
            .schema("accounts")
            .from("pt_profiles")
            .select("id,profile_id")
            .eq("profile_id", value: profile.id.uuidString)
            .limit(1)
            .decoded()
        
        guard let pt = rows.first else {
            throw NSError(
                domain: "PTService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "PT profile not found"]
            )
        }
        
        return pt
    }
    
    // MARK: - Patient Management
    
    @MainActor
    static func addPatient(
        firstName: String,
        lastName: String,
        dob: Date,
        gender: String
    ) async throws {
        let pt = try await myPTProfile()
        
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        
        // 1) Insert into accounts.patient_profiles (profile_id null, but include demographics)
        let inserted: [UUIDWrapper] = try await client
            .schema("accounts")
            .from("patient_profiles")
            .insert(AnyEncodable([
                "first_name": firstName,
                "last_name": lastName,
                "date_of_birth": df.string(from: dob),
                "gender": gender
            ]), returning: .representation)
            .select("id")
            .limit(1)
            .decoded()
        
        guard let pid = inserted.first?.id else {
            throw NSError(
                domain: "PTService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create patient profile"]
            )
        }
        
        // 2) Map to this PT
        _ = try await client
            .schema("accounts")
            .from("pt_patient_map")
            .upsert(AnyEncodable([
                "patient_profile_id": pid.uuidString,
                "pt_profile_id": pt.id.uuidString
            ]), onConflict: "patient_profile_id")
            .execute()
    }
    
    @MainActor
    static func listMyPatients() async throws -> [SimplePatient] {
        let pt = try await myPTProfile()
        
        // Find all patient_profile_id for my map
        struct MapRow: Decodable {
            let patient_profile_id: UUID
        }
        let map: [MapRow] = try await client
            .schema("accounts")
            .from("pt_patient_map")
            .select("patient_profile_id")
            .eq("pt_profile_id", value: pt.id.uuidString)
            .decoded()
        
        if map.isEmpty { return [] }
        
        let ids = map.map { $0.patient_profile_id.uuidString }
        
        // DTO that matches database exactly - all nullable fields are Optional
        struct PatientCardDTO: Decodable {
            let id: UUID
            let first_name: String
            let last_name: String
            let date_of_birth: String?     // Decode as string "YYYY-MM-DD" (can be NULL)
            let gender: String?            // Can be NULL
            let phone: String?
            let profile_id: UUID?          // Can be NULL for placeholder patients
        }
        
        // Select only the columns we need, explicitly
        let patients: [PatientCardDTO] = try await client
            .schema("accounts")
            .from("patient_profiles")
            .select("id,first_name,last_name,date_of_birth,gender,phone,profile_id")
            .in("id", values: ids)
            .decoded()
        
        // Fetch emails for those with a profile_id
        var emailByProfile: [UUID: String] = [:]
        let profileIds = patients.compactMap { $0.profile_id?.uuidString }
        if !profileIds.isEmpty {
            struct PRow: Decodable {
                let id: UUID
                let email: String?
            }
            let baseProfiles: [PRow] = try await client
                .schema("accounts")
                .from("profiles")
                .select("id,email")
                .in("id", values: profileIds)
                .decoded()
            emailByProfile = Dictionary(uniqueKeysWithValues: baseProfiles.compactMap { profile in
                guard let email = profile.email, !email.isEmpty else { return nil }
                return (profile.id, email)
            })
        }
        
        return patients.map {
            SimplePatient(
                patient_profile_id: $0.id,
                first_name: $0.first_name,
                last_name: $0.last_name,
                date_of_birth: $0.date_of_birth,  // Already string
                gender: $0.gender,                 // Can be nil
                email: $0.profile_id.flatMap { emailByProfile[$0] },
                phone: $0.phone,
                profile_id: $0.profile_id
            )
        }
    }
    
    @MainActor
    static func deletePatientMapping(patientProfileId: UUID) async throws {
        let pt = try await myPTProfile()
        _ = try await client
            .schema("accounts")
            .from("pt_patient_map")
            .delete()
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .eq("pt_profile_id", value: pt.id.uuidString)
            .execute()
    }
}

