import Foundation
import Supabase
import PostgREST

enum PTService {
    private static var client: SupabaseClient { SupabaseService.shared.client }

    private struct PTProfileRow: Decodable {
        let id: UUID
        let profile_id: UUID
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
}

