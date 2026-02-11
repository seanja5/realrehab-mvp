import Foundation
import Supabase
import PostgREST

enum PTService {
    private static var client: SupabaseClient { SupabaseService.shared.client }

    struct PTProfileRow: Codable {
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
    
    struct SimplePatient: Codable, Identifiable {
        let patient_profile_id: UUID
        let first_name: String
        let last_name: String
        let date_of_birth: String?  // Keep as String? for resilience
        let gender: String?          // Can be NULL
        let email: String?
        let phone: String?
        let profile_id: UUID?        // Can be NULL for placeholder patients
        let access_code: String?     // 8-digit access code for linking
        let surgery_date: String?    // From patient signup
        let last_pt_visit: String?   // From patient signup
        
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
        
        let cacheKey = CacheKey.ptProfile(profileId: profile.id)
        
        // Check cache first (disk persistence enabled)
        if let cached = await CacheService.shared.getCached(cacheKey, as: PTProfileRow.self, useDisk: true) {
            print("✅ PTService.myPTProfile: cache hit")
            return cached
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
        
        // Cache the result (disk persistence enabled)
        await CacheService.shared.setCached(pt, forKey: cacheKey, ttl: CacheService.TTL.profile, useDisk: true)
        print("✅ PTService.myPTProfile: cached result")
        
        return pt
    }
    
    /// Load PT profile for display; when offline returns stale cache if available and reports isStale for banner.
    @MainActor
    static func myPTProfileForDisplay() async throws -> (PTProfileRow, isStale: Bool) {
        let profileResult = try await AuthService.myProfileForDisplay()
        guard let profile = profileResult.value else {
            throw NSError(domain: "PTService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Unable to load profile"])
        }
        let cacheKey = CacheKey.ptProfile(profileId: profile.id)
        let allowStale = !NetworkMonitor.shared.isOnline
        if let result = await CacheService.shared.getCachedResult(cacheKey, as: PTProfileRow.self, useDisk: true, allowStaleWhenOffline: allowStale) {
            if !NetworkMonitor.shared.isOnline {
                return (result.value, result.isStale)
            }
            // Online: use fresh cache hit
            return (result.value, false)
        }
        if !NetworkMonitor.shared.isOnline {
            throw NSError(domain: "PTService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Offline and no cached profile"])
        }
        let pt = try await myPTProfile()
        return (pt, false)
    }
    
    // MARK: - Patient Management
    
    static func addPatient(
        ptProfileId: UUID,
        firstName: String,
        lastName: String,
        dob: Date,
        gender: String
    ) async throws {
        print("🔍 PTService.addPatient: calling RPC function with firstName=\(firstName), lastName=\(lastName), gender=\(gender), ptProfileId=\(ptProfileId)")
        
        do {
            // Call RPC function to create patient profile AND pt_patient_map entry
            // This bypasses RLS by using a SECURITY DEFINER function
            // Create params in a nonisolated context to avoid Sendable issues
            let uuidString: String = try await Task { @Sendable in
                struct RPCParams: Encodable {
                    let p_first_name: String
                    let p_last_name: String
                    let p_date_of_birth: String
                    let p_gender: String
                    let p_pt_profile_id: String
                }
                
                let params = RPCParams(
                    p_first_name: firstName,
                    p_last_name: lastName,
                    p_date_of_birth: dob.dateOnlyString(),
                    p_gender: gender,
                    p_pt_profile_id: ptProfileId.uuidString
                )
                
                // Call RPC function - PostgREST returns UUID as a string directly
                // The function returns uuid type, which PostgREST serializes as a string
                return try await client
                    .rpc("add_patient_with_mapping", params: params)
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
            
            print("✅ PTService.addPatient: successfully created patient_profile \(pid) and pt_patient_map entry via RPC")
            
            // Invalidate patient list cache
            let cacheKey = CacheKey.patientList(ptProfileId: ptProfileId)
            await CacheService.shared.invalidate(cacheKey)
            print("✅ PTService.addPatient: invalidated patient list cache")
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
        let cacheKey = CacheKey.patientList(ptProfileId: ptProfileId)
        
        // Check cache first (disk persistence for offline/tab switching)
        if let cached = await CacheService.shared.getCached(cacheKey, as: [SimplePatient].self, useDisk: true) {
            print("✅ PTService.listMyPatients: cache hit")
            return cached
        }
        
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
            let first_name: String?        // Can be NULL for placeholder patients
            let last_name: String?         // Can be NULL for placeholder patients
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
        
        // Log phone numbers from patient_profiles
        print("📱 PTService.listMyPatients: phone numbers from patient_profiles:")
        for patient in patients {
            print("   - Patient \(patient.id): phone=\(patient.phone ?? "NULL")")
        }
        
        // Fetch emails and phones for those with a profile_id
        var emailByProfile: [UUID: String] = [:]
        var phoneByProfile: [UUID: String] = [:]
        let profileIds = patients.compactMap { $0.profile_id?.uuidString }
        print("🔍 PTService.listMyPatients: fetching emails/phones for \(profileIds.count) profile IDs: \(profileIds)")
        
        if !profileIds.isEmpty {
            struct PRow: Decodable {
                let id: UUID
                let email: String?
                let phone: String?
            }
            let baseProfiles: [PRow] = try await client
                .schema("accounts")
                .from("profiles")
                .select("id,email,phone")
                .in("id", values: profileIds)
                .decoded()
            
            print("📧 PTService.listMyPatients: fetched \(baseProfiles.count) profiles from accounts.profiles")
            
            // Build email map - handle citext by converting to String explicitly
            emailByProfile = Dictionary(uniqueKeysWithValues: baseProfiles.compactMap { profile in
                guard let email = profile.email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                let emailString = String(describing: email).trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ PTService.listMyPatients: found email '\(emailString)' for profile \(profile.id)")
                return (profile.id, emailString)
            })
            
            // Build phone map
            phoneByProfile = Dictionary(uniqueKeysWithValues: baseProfiles.compactMap { profile in
                guard let phone = profile.phone, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                print("✅ PTService.listMyPatients: found phone '\(phone)' for profile \(profile.id)")
                return (profile.id, phone)
            })
            
            print("📊 PTService.listMyPatients: built email map with \(emailByProfile.count) entries, phone map with \(phoneByProfile.count) entries")
        }
        
        let result = patients.map { patient in
            // Use phone from profiles table as fallback if patient_profiles.phone is NULL
            let phoneFromPatientProfiles = patient.phone
            let phoneFromProfiles = patient.profile_id.flatMap { profileId in phoneByProfile[profileId] }
            let phoneValue = phoneFromPatientProfiles ?? phoneFromProfiles
            
            // Get email from profiles table using profile_id
            let emailValue = patient.profile_id.flatMap { profileId in emailByProfile[profileId] }
            
            if let profileId = patient.profile_id {
                print("🔍 PTService.listMyPatients: patient \(patient.id) has profile_id \(profileId)")
                print("   📧 Email: patient_profiles=\(emailValue ?? "nil"), profiles=\(emailValue ?? "nil")")
                print("   📱 Phone: patient_profiles=\(phoneFromPatientProfiles ?? "NULL"), profiles=\(phoneFromProfiles ?? "NULL"), final=\(phoneValue ?? "nil")")
            } else {
                print("⚠️ PTService.listMyPatients: patient \(patient.id) has no profile_id (unlinked)")
                print("   📱 Phone: patient_profiles=\(phoneFromPatientProfiles ?? "NULL"), final=\(phoneValue ?? "nil")")
            }
            
            return SimplePatient(
                patient_profile_id: patient.id,
                first_name: patient.first_name ?? "",  // Default to empty string if NULL
                last_name: patient.last_name ?? "",    // Default to empty string if NULL
                date_of_birth: patient.date_of_birth,  // Already string
                gender: patient.gender,                 // Can be nil
                email: emailValue,
                phone: phoneValue,
                profile_id: patient.profile_id,
                access_code: patient.access_code,
                surgery_date: nil,   // Only loaded in getPatient (detail)
                last_pt_visit: nil   // Only loaded in getPatient (detail)
            )
        }
        
        // Cache the result (disk persistence for offline/tab switching)
        await CacheService.shared.setCached(result, forKey: cacheKey, ttl: CacheService.TTL.patientList, useDisk: true)
        print("✅ PTService.listMyPatients: cached \(result.count) patients")
        
        return result
    }
    
    /// Load patient list for display; when offline returns stale cache if available and reports isStale for banner.
    @MainActor
    static func listMyPatientsForDisplay(ptProfileId: UUID) async throws -> ([SimplePatient], isStale: Bool) {
        let cacheKey = CacheKey.patientList(ptProfileId: ptProfileId)
        let allowStale = !NetworkMonitor.shared.isOnline
        if let result = await CacheService.shared.getCachedResult(cacheKey, as: [SimplePatient].self, useDisk: true, allowStaleWhenOffline: allowStale) {
            if !NetworkMonitor.shared.isOnline {
                return (result.value, result.isStale)
            }
            return (result.value, false)
        }
        if !NetworkMonitor.shared.isOnline {
            throw NSError(domain: "PTService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Offline and no cached patient list"])
        }
        let list = try await listMyPatients(ptProfileId: ptProfileId)
        return (list, false)
    }
    
    @MainActor
    static func getPatient(patientProfileId: UUID) async throws -> SimplePatient {
        let cacheKey = CacheKey.patientDetail(patientProfileId: patientProfileId)
        
        // Check cache first (disk persistence for offline/tab switching)
        if let cached = await CacheService.shared.getCached(cacheKey, as: SimplePatient.self, useDisk: true) {
            print("✅ PTService.getPatient: cache hit")
            return cached
        }
        
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
            let surgery_date: String?
            let last_pt_visit: String?
        }
        
        // Fetch the specific patient
        let patients: [PatientCardDTO] = try await client
            .schema("accounts")
            .from("patient_profiles")
            .select("id,first_name,last_name,date_of_birth,gender,phone,profile_id,access_code,surgery_date,last_pt_visit")
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
        
        // Fetch email and phone if profile_id exists
        var email: String? = nil
        var phone: String? = patient.phone  // Start with phone from patient_profiles
        if let profileId = patient.profile_id {
            struct PRow: Decodable {
                let id: UUID
                let email: String?
                let phone: String?
            }
            let profiles: [PRow] = try await client
                .schema("accounts")
                .from("profiles")
                .select("id,email,phone")
                .eq("id", value: profileId.uuidString)
                .limit(1)
                .decoded()
            
            if let profile = profiles.first {
                // Handle email (citext) - convert to String explicitly
                if let profileEmail = profile.email, !profileEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    email = String(describing: profileEmail).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Use phone from profiles as fallback if patient_profiles.phone is NULL
                if phone == nil || phone!.isEmpty {
                    if let profilePhone = profile.phone, !profilePhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        phone = profilePhone
                    }
                }
            }
        }
        
        let result = SimplePatient(
            patient_profile_id: patient.id,
            first_name: patient.first_name,
            last_name: patient.last_name,
            date_of_birth: patient.date_of_birth,
            gender: patient.gender,
            email: email,
            phone: phone,
            profile_id: patient.profile_id,
            access_code: patient.access_code,
            surgery_date: patient.surgery_date,
            last_pt_visit: patient.last_pt_visit
        )
        
        // Cache the result (disk persistence for offline/tab switching)
        await CacheService.shared.setCached(result, forKey: cacheKey, ttl: CacheService.TTL.patientDetail, useDisk: true)
        print("✅ PTService.getPatient: cached result")
        
        return result
    }
    
    /// Load patient detail for display; when offline returns stale cache if available and reports isStale for banner.
    @MainActor
    static func getPatientForDisplay(patientProfileId: UUID) async throws -> (SimplePatient, isStale: Bool) {
        let cacheKey = CacheKey.patientDetail(patientProfileId: patientProfileId)
        let allowStale = !NetworkMonitor.shared.isOnline
        if let result = await CacheService.shared.getCachedResult(cacheKey, as: SimplePatient.self, useDisk: true, allowStaleWhenOffline: allowStale) {
            if !NetworkMonitor.shared.isOnline {
                return (result.value, result.isStale)
            }
            return (result.value, false)
        }
        if !NetworkMonitor.shared.isOnline {
            throw NSError(domain: "PTService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Offline and no cached patient detail"])
        }
        let patient = try await getPatient(patientProfileId: patientProfileId)
        return (patient, false)
    }
    
    @MainActor
    static func deletePatientMapping(ptProfileId: UUID, patientProfileId: UUID) async throws {
        // Try RPC function first (bypasses RLS issues)
        do {
            let params: [String: String] = [
                "p_pt_profile_id": ptProfileId.uuidString,
                "p_patient_profile_id": patientProfileId.uuidString
            ]
            
            _ = try await client
                .schema("accounts")
                .rpc("delete_pt_patient_mapping", params: params)
                .execute()
            
            print("✅ PTService.deletePatientMapping: RPC function succeeded")
            return
        } catch {
            print("⚠️ PTService.deletePatientMapping: RPC failed, trying direct delete: \(error)")
            // Fall back to direct delete if RPC doesn't exist
        }
        
        // Fallback to direct delete (original method)
        _ = try await client
            .schema("accounts")
            .from("pt_patient_map")
            .delete()
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .eq("pt_profile_id", value: ptProfileId.uuidString)
            .execute()
        
        // Invalidate patient list cache and patient detail cache
        let listCacheKey = CacheKey.patientList(ptProfileId: ptProfileId)
        let detailCacheKey = CacheKey.patientDetail(patientProfileId: patientProfileId)
        await CacheService.shared.invalidate(listCacheKey)
        await CacheService.shared.invalidate(detailCacheKey)
        print("✅ PTService.deletePatientMapping: invalidated patient list and detail caches")
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
        
        // Invalidate PT profile cache (need profileId to get cache key)
        if let profile = try? await AuthService.myProfile() {
            let cacheKey = CacheKey.ptProfile(profileId: profile.id)
            await CacheService.shared.invalidate(cacheKey)
            print("✅ PTService.updatePTProfile: invalidated PT profile cache")
        }
        
        print("✅ PTService.updatePTProfile: successfully updated profile")
    }
}

