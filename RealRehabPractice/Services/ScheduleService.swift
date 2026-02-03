import Foundation
import Supabase

/// Service for patient schedule slots (personalized weekly schedule).
/// Stores 30-minute blocks per day for "My Schedule" visualizer and future reminders.
enum ScheduleService {
    private static var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Models

    /// A single 30-minute schedule slot (day + start time)
    struct ScheduleSlot: Codable, Hashable, Sendable {
        let day_of_week: Int  // 0=Sun .. 6=Sat
        let slot_time: String // "HH:mm:ss" e.g. "12:00:00"
    }

    /// Row returned from Supabase
    struct ScheduleSlotRow: Decodable {
        let id: UUID
        let patient_profile_id: UUID
        let day_of_week: Int
        let slot_time: String
    }

    /// Insert payload
    private struct ScheduleSlotInsert: Encodable {
        let patient_profile_id: UUID
        let day_of_week: Int
        let slot_time: String
    }

    // MARK: - Fetch

    /// Fetch schedule slots for a patient (cache-first, disk persistence)
    static func getSchedule(patientProfileId: UUID) async throws -> [ScheduleSlot] {
        let cacheKey = CacheKey.patientSchedule(patientProfileId: patientProfileId)

        // Check cache first
        if let cached = await CacheService.shared.getCached(cacheKey, as: [ScheduleSlot].self, useDisk: true) {
            return cached
        }

        // Fetch from Supabase
        let rows: [ScheduleSlotRow] = try await client
            .schema("accounts")
            .from("patient_schedule_slots")
            .select("id,patient_profile_id,day_of_week,slot_time")
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .order("day_of_week")
            .order("slot_time")
            .decoded()

        let slots = rows.map { ScheduleSlot(day_of_week: $0.day_of_week, slot_time: $0.slot_time) }

        // Cache result
        await CacheService.shared.setCached(slots, forKey: cacheKey, ttl: CacheService.TTL.patientSchedule, useDisk: true)

        return slots
    }

    // MARK: - Save

    /// Save schedule slots for a patient. Replaces all existing slots.
    /// - Parameters:
    ///   - patientProfileId: The patient's profile ID
    ///   - slots: Array of (day_of_week, slot_time) - each represents a 30-min block
    static func saveSchedule(patientProfileId: UUID, slots: [ScheduleSlot]) async throws {
        let cacheKey = CacheKey.patientSchedule(patientProfileId: patientProfileId)

        // Delete existing slots
        try await client
            .schema("accounts")
            .from("patient_schedule_slots")
            .delete()
            .eq("patient_profile_id", value: patientProfileId.uuidString)
            .execute()

        // Insert new slots
        if !slots.isEmpty {
            let payloads = slots.map { slot in
                ScheduleSlotInsert(
                    patient_profile_id: patientProfileId,
                    day_of_week: slot.day_of_week,
                    slot_time: slot.slot_time
                )
            }
            _ = try await client
                .schema("accounts")
                .from("patient_schedule_slots")
                .insert(payloads)
                .execute()
        }

        // Update cache
        await CacheService.shared.setCached(slots, forKey: cacheKey, ttl: CacheService.TTL.patientSchedule, useDisk: true)
    }

    // MARK: - Helpers

    /// Convert Date (time-of-day) to PostgreSQL time string "HH:mm:ss"
    /// Rounds to nearest 15-minute block (0, 15, 30, 45)
    static func timeString(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        var m = comps.minute ?? 0
        m = (m / 15) * 15
        if m >= 60 { return String(format: "%02d:00:00", h + 1) }
        return String(format: "%02d:%02d:00", h, m)
    }

    /// Convert (Weekday, Date) pairs to ScheduleSlot array
    static func slotsFrom(selectedDays: Set<Weekday>, times: [Weekday: Date]) -> [ScheduleSlot] {
        selectedDays.compactMap { day in
            guard let time = times[day] else { return nil }
            return ScheduleSlot(
                day_of_week: day.rawValue,
                slot_time: timeString(from: time)
            )
        }
    }
}
