import Foundation
import Supabase
import PostgREST

struct SessionRow: Decodable {
  let id: UUID
  let patient_id: UUID
  let program_id: UUID?
  let exercise_id: UUID?
  let started_at: Date?
  let ended_at: Date?
  let notes: String?
}

enum TelemetryService {
  private static let supabase = SupabaseService.shared.client
  private static let iso = ISO8601DateFormatter()

  // Start an exercise session for current user
  static func startSession(programId: UUID?, exerciseId: UUID?, notes: String? = nil) async throws -> UUID {
    let uid = try AuthService.currentUserId()

    let payload: [String: AnyEncodable] = [
      "patient_id": AnyEncodable(uid.uuidString),
      "program_id": AnyEncodable(programId?.uuidString),
      "exercise_id": AnyEncodable(exerciseId?.uuidString),
      "notes": AnyEncodable(notes)
    ]

    let row: SessionRow = try await supabase
      .from("telemetry.sessions")
      .insert(payload)
      .select("*")
      .single()
      .decoded(as: SessionRow.self)

    return row.id
  }

  // Record a single sensor sample
  static func recordSample(
    sessionId: UUID,
    angle: Double? = nil,
    flexRaw: Int? = nil,
    rateHz: Double? = nil,
    imuQuat: [String: Any]? = nil,
    timestamp: Date = Date()
  ) async throws {
    var payload: [String: AnyEncodable] = [
      "session_id": AnyEncodable(sessionId.uuidString),
      "t": AnyEncodable(iso.string(from: timestamp)),
      "angle": AnyEncodable(angle),
      "flex_raw": AnyEncodable(flexRaw),
      "rate_hz": AnyEncodable(rateHz)
    ]

    if let imuQuat {
      payload["imu_quat"] = AnyEncodable(imuQuat)
    }

    _ = try await supabase
      .from("telemetry.sensor_samples")
      .insert(payload)
      .execute()
  }

  // End the session (set ended_at)
  static func endSession(sessionId: UUID) async throws {
    let payload: [String: AnyEncodable] = [
      "ended_at": AnyEncodable(iso.string(from: Date()))
    ]

    _ = try await supabase
      .from("telemetry.sessions")
      .update(payload)
      .eq("id", value: sessionId.uuidString)
      .execute()
  }

  // Optional: fetch recent sessions for current user
  static func recentSessions(limit: Int = 10) async throws -> [SessionRow] {
    let uid = try AuthService.currentUserId()
    return try await supabase
      .from("telemetry.sessions")
      .select()
      .eq("patient_id", value: uid.uuidString)
      .order("started_at", ascending: false)
      .limit(limit)
      .decoded(as: [SessionRow].self)
  }

}

