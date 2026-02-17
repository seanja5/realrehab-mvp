//
//  MessagingService.swift
//  RealRehabPractice
//
//  Fetches and sends messages between PT and patient.
//

import Foundation
import Supabase

enum MessagingService {
    private static var client: SupabaseClient { SupabaseService.shared.client }

    struct MessageRow: Codable, Identifiable {
        let id: UUID
        let pt_profile_id: UUID
        let patient_profile_id: UUID
        let sender_role: String
        let sender_display_name: String?
        let body: String
        let created_at: Date
    }

    /// Fetch messages for a thread, ordered by created_at ascending (oldest first).
    @MainActor
    static func fetchMessages(ptProfileId: UUID, patientProfileId: UUID) async throws -> [MessageRow] {
        let rows: [MessageRow] = try await client
            .schema("accounts")
            .from("messages")
            .select("id,pt_profile_id,patient_profile_id,sender_role,sender_display_name,body,created_at")
            .eq("pt_profile_id", value: ptProfileId.uuidString)
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .order("created_at", ascending: true)
            .decoded()
        return rows
    }

    /// Send a message. Returns the inserted row.
    @MainActor
    static func sendMessage(
        ptProfileId: UUID,
        patientProfileId: UUID,
        senderRole: String,
        senderDisplayName: String?,
        body: String
    ) async throws -> MessageRow {
        struct InsertPayload: Encodable {
            let pt_profile_id: UUID
            let patient_profile_id: UUID
            let sender_role: String
            let sender_display_name: String?
            let body: String
        }
        let payload = InsertPayload(
            pt_profile_id: ptProfileId,
            patient_profile_id: patientProfileId,
            sender_role: senderRole,
            sender_display_name: senderDisplayName,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let rows: [MessageRow] = try await client
            .schema("accounts")
            .from("messages")
            .insert(payload)
            .select("id,pt_profile_id,patient_profile_id,sender_role,sender_display_name,body,created_at")
            .limit(1)
            .decoded()
        guard let row = rows.first else {
            throw NSError(domain: "MessagingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert message"])
        }
        return row
    }

    // MARK: - Unread count (stored locally: last time user opened this thread)

    private static func lastReadKey(ptProfileId: UUID, patientProfileId: UUID, isPT: Bool) -> String {
        let role = isPT ? "pt" : "patient"
        return "messaging_last_read_\(ptProfileId.uuidString)_\(patientProfileId.uuidString)_\(role)"
    }

    static func markThreadAsRead(ptProfileId: UUID, patientProfileId: UUID, isPT: Bool) {
        UserDefaults.standard.set(Date(), forKey: lastReadKey(ptProfileId: ptProfileId, patientProfileId: patientProfileId, isPT: isPT))
    }

    /// Unread = messages from the other party received since user last opened this thread.
    @MainActor
    static func getUnreadCount(ptProfileId: UUID, patientProfileId: UUID, isPT: Bool) async throws -> Int {
        let messages = try await fetchMessages(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
        let myRole = isPT ? "pt" : "patient"
        let lastRead = UserDefaults.standard.object(forKey: lastReadKey(ptProfileId: ptProfileId, patientProfileId: patientProfileId, isPT: isPT)) as? Date ?? .distantPast
        return messages.filter { $0.sender_role != myRole && $0.created_at > lastRead }.count
    }
}
