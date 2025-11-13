import Foundation
import Supabase
import PostgREST

enum PTService {
    private static var client: SupabaseClient { SupabaseService.shared.client }

    struct PTProfileRow: Decodable {
        let id: UUID
        let profile_id: UUID
        let email: String?
        let first_name: String?
        let last_name: String?
        let phone: String?
        let license_number: String?
        let npi_number: String?
        let practice_name: String?
        let practice_address: String?
        let specialization: String?
    }
    
    struct SimplePatient: Decodable, Identifiable {
        let patient_profile_id: UUID
        let first_name: String
        let last_name: String
        let date_of_birth: String?  // Keep as String? for resilience
        let gender: String?          // Can be NULL
        let email: String?
        let phone: String?
        let profile_id: UUID?        // Can be NULL for placeholder patients
        let access_code: String?     // 8-digit access code for linking
        
        // Identifiable conformance - use patient_profile_id as id
        var id: UUID { patient_profile_id }
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
            .select("id,profile_id,email,first_name,last_name,phone,license_number,npi_number,practice_name,practice_address,specialization")
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
    
    static func addPatient(
        ptProfileId: UUID,
        firstName: String,
        lastName: String,
        dob: Date,
        gender: String
    ) async throws {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        
        print("🔍 PTService.addPatient: calling RPC function with firstName=\(firstName), lastName=\(lastName), gender=\(gender)")
        
        do {
            // 1) Call RPC function to insert patient profile with NULL profile_id
            // This bypasses RLS by using a SECURITY DEFINER function
            // Create params in a nonisolated context to avoid Sendable issues
            let uuidString: String = try await Task { @Sendable in
                struct RPCParams: Encodable {
                    let p_first_name: String
                    let p_last_name: String
                    let p_date_of_birth: String
                    let p_gender: String
                }
                
                let params = RPCParams(
                    p_first_name: firstName,
                    p_last_name: lastName,
                    p_date_of_birth: df.string(from: dob),
                    p_gender: gender
                )
                
                // Call RPC function - PostgREST returns UUID as a string directly
                // The function returns uuid type, which PostgREST serializes as a string
                return try await client.database
                    .rpc("insert_patient_profile_placeholder", params: params)
                    .single()
                    .execute()
                    .value
            }.value
            
            guard let pid = UUID(uuidString: uuidString) else {
                throw NSError(
                    domain: "PTService",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse UUID from RPC response: \(uuidString)"]
                )
            }
            
            print("✅ PTService.addPatient: successfully created patient_profile \(pid) via RPC")
            
            // 2) Map to this PT
            print("📝 PTService.addPatient: attempting to create pt_patient_map row (patient_profile_id=\(pid), pt_profile_id=\(ptProfileId))")
            do {
                _ = try await client
                    .schema("accounts")
                    .from("pt_patient_map")
                    .upsert(AnyEncodable([
                        "patient_profile_id": pid.uuidString,
                        "pt_profile_id": ptProfileId.uuidString
                    ]), onConflict: "patient_profile_id")
                    .execute()
                
                print("✅ PTService.addPatient: upsert executed successfully")
                
                // Verify the mapping was actually created
                struct MapVerifyRow: Decodable {
                    let id: UUID
                    let patient_profile_id: UUID
                    let pt_profile_id: UUID
                }
                
                let verifyRows: [MapVerifyRow] = try await client
                    .schema("accounts")
                    .from("pt_patient_map")
                    .select("id,patient_profile_id,pt_profile_id")
                    .eq("patient_profile_id", value: pid.uuidString)
                    .eq("pt_profile_id", value: ptProfileId.uuidString)
                    .limit(1)
                    .decoded()
                
                if let verify = verifyRows.first {
                    print("✅ PTService.addPatient: verified pt_patient_map row exists:")
                    print("   - id: \(verify.id)")
                    print("   - patient_profile_id: \(verify.patient_profile_id)")
                    print("   - pt_profile_id: \(verify.pt_profile_id)")
                } else {
                    print("⚠️ PTService.addPatient: WARNING - upsert succeeded but verification query found no row!")
                    print("⚠️ This suggests RLS is blocking the verification query, or the row wasn't actually created")
                }
                
                print("✅ PTService.addPatient: successfully mapped patient \(pid) to PT \(ptProfileId)")
            } catch {
                print("❌ PTService.addPatient: failed to create pt_patient_map row: \(error)")
                if let postgrestError = error as? PostgrestError {
                    print("❌ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
                    print("❌ This is likely an RLS policy issue preventing the INSERT")
                }
                throw error
            }
        } catch {
            print("❌ PTService.addPatient: RLS error or other failure: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("❌ PostgrestError code: \(postgrestError.code ?? "unknown"), message: \(postgrestError.message)")
            }
            throw error
        }
    }
    
    @MainActor
    static func listMyPatients(ptProfileId: UUID) async throws -> [SimplePatient] {
        // Find all patient_profile_id for my map
        struct MapRow: Decodable {
            let patient_profile_id: UUID
        }
        let map: [MapRow] = try await client
            .schema("accounts")
            .from("pt_patient_map")
            .select("patient_profile_id")
            .eq("pt_profile_id", value: ptProfileId.uuidString)
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
            let access_code: String?       // 8-digit access code
        }
        
        // Select only the columns we need, explicitly
        let patients: [PatientCardDTO] = try await client
            .schema("accounts")
            .from("patient_profiles")
            .select("id,first_name,last_name,date_of_birth,gender,phone,profile_id,access_code")
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
                profile_id: $0.profile_id,
                access_code: $0.access_code
            )
        }
    }
    
    @MainActor
    static func getPatient(patientProfileId: UUID) async throws -> SimplePatient {
        // DTO that matches database exactly
        struct PatientCardDTO: Decodable {
            let id: UUID
            let first_name: String
            let last_name: String
            let date_of_birth: String?
            let gender: String?
            let phone: String?
            let profile_id: UUID?
            let access_code: String?
        }
        
        // Fetch the specific patient
        let patients: [PatientCardDTO] = try await client
            .schema("accounts")
            .from("patient_profiles")
            .select("id,first_name,last_name,date_of_birth,gender,phone,profile_id,access_code")
            .eq("id", value: patientProfileId.uuidString)
            .limit(1)
            .decoded()
        
        guard let patient = patients.first else {
            throw NSError(
                domain: "PTService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Patient not found"]
            )
        }
        
        // Fetch email if profile_id exists
        var email: String? = nil
        if let profileId = patient.profile_id {
            struct PRow: Decodable {
                let id: UUID
                let email: String?
            }
            let profiles: [PRow] = try await client
                .schema("accounts")
                .from("profiles")
                .select("id,email")
                .eq("id", value: profileId.uuidString)
                .limit(1)
                .decoded()
            
            if let profile = profiles.first, let profileEmail = profile.email, !profileEmail.isEmpty {
                email = profileEmail
            }
        }
        
        return SimplePatient(
            patient_profile_id: patient.id,
            first_name: patient.first_name,
            last_name: patient.last_name,
            date_of_birth: patient.date_of_birth,
            gender: patient.gender,
            email: email,
            phone: patient.phone,
            profile_id: patient.profile_id,
            access_code: patient.access_code
        )
    }
    
    @MainActor
    static func deletePatientMapping(ptProfileId: UUID, patientProfileId: UUID) async throws {
        _ = try await client
            .schema("accounts")
            .from("pt_patient_map")
            .delete()
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .eq("pt_profile_id", value: ptProfileId.uuidString)
            .execute()
    }
    
    // MARK: - Update PT Profile
    @MainActor
    static func updatePTProfile(
        ptProfileId: UUID,
        email: String?,
        firstName: String?,
        lastName: String?,
        phone: String?,
        licenseNumber: String?,
        npiNumber: String?,
        practiceName: String?,
        practiceAddress: String?,
        specialization: String?
    ) async throws {
        var payload: [String: AnyEncodable] = [:]
        
        if let email = email, !email.isEmpty {
            payload["email"] = AnyEncodable(email)
        }
        if let firstName = firstName, !firstName.isEmpty {
            payload["first_name"] = AnyEncodable(firstName)
        }
        if let lastName = lastName, !lastName.isEmpty {
            payload["last_name"] = AnyEncodable(lastName)
        }
        if let phone = phone, !phone.isEmpty {
            payload["phone"] = AnyEncodable(phone)
        }
        if let licenseNumber = licenseNumber, !licenseNumber.isEmpty {
            payload["license_number"] = AnyEncodable(licenseNumber)
        }
        if let npiNumber = npiNumber, !npiNumber.isEmpty {
            payload["npi_number"] = AnyEncodable(npiNumber)
        }
        if let practiceName = practiceName, !practiceName.isEmpty {
            payload["practice_name"] = AnyEncodable(practiceName)
        }
        if let practiceAddress = practiceAddress, !practiceAddress.isEmpty {
            payload["practice_address"] = AnyEncodable(practiceAddress)
        }
        if let specialization = specialization, !specialization.isEmpty {
            payload["specialization"] = AnyEncodable(specialization)
        }
        
        _ = try await client
            .schema("accounts")
            .from("pt_profiles")
            .update(AnyEncodable(payload))
            .eq("id", value: ptProfileId.uuidString)
            .execute()
        
        print("✅ PTService.updatePTProfile: successfully updated profile")
    }
}

