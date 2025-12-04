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

  // MARK: - Calibration Functions
  
  struct DeviceRow: Decodable {
    let id: UUID
  }
  
  struct DeviceAssignmentRow: Decodable {
    let id: UUID
    let device_id: UUID
    let patient_profile_id: UUID
    let pt_profile_id: UUID?
  }
  
  // Get or create device assignment
  // Uses RPC for device creation (devices table blocks patients), but direct insert for device_assignments
  private static func getOrCreateDeviceAssignment(bluetoothIdentifier: String) async throws -> UUID {
    // Get current user's profile and patient profile ID
    guard let profile = try await AuthService.myProfile() else {
      throw NSError(domain: "TelemetryService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
    }
    
    let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
    
    // Step 1: Get or create device using RPC (devices table RLS only allows admin)
    // The RPC function handles device creation, but we need to extract device_id from the assignment
    let assignmentIdString: String = try await Task { @Sendable in
      struct RPCParams: Encodable {
        let p_bluetooth_identifier: String
      }
      
      let params = RPCParams(p_bluetooth_identifier: bluetoothIdentifier)
      
      return try await supabase
        .database
        .rpc("get_or_create_device_assignment", params: params)
        .single()
        .execute()
        .value
    }.value
    
    guard let assignmentId = UUID(uuidString: assignmentIdString) else {
      throw NSError(domain: "TelemetryService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid device assignment ID returned from RPC"])
    }
    
    return assignmentId
  }
  
  // Save a calibration record
  static func saveCalibration(
    bluetoothIdentifier: String,
    stage: String, // "starting_position" or "maximum_position"
    flexValue: Int,
    kneeAngleDeg: Double? = nil,
    notes: String? = nil
  ) async throws {
    // Get or create device assignment using RPC (handles device creation too)
    let assignmentId = try await getOrCreateDeviceAssignment(bluetoothIdentifier: bluetoothIdentifier)
    
    // Save calibration record
    var payload: [String: AnyEncodable] = [
      "device_assignment_id": AnyEncodable(assignmentId.uuidString),
      "stage": AnyEncodable(stage),
      "flex_value": AnyEncodable(Double(flexValue)),
      "recorded_at": AnyEncodable(iso.string(from: Date()))
    ]
    
    if let angle = kneeAngleDeg {
      payload["knee_angle_deg"] = AnyEncodable(angle)
    }
    
    if let notesValue = notes {
      payload["notes"] = AnyEncodable(notesValue)
    }
    
    _ = try await supabase
      .schema("telemetry")
      .from("calibrations")
      .insert(payload)
      .execute()
    
    print("✅ TelemetryService: Saved calibration - stage: \(stage), flex_value: \(flexValue)")
  }
  
  // MARK: - Calibration Retrieval
  
  struct CalibrationRow: Decodable {
    let id: UUID
    let device_assignment_id: UUID
    let stage: String
    let flex_value: Double
    let knee_angle_deg: Double?
    let recorded_at: String
  }
  
  struct MostRecentCalibration {
    let restDegrees: Int?  // starting_position value
    let maxDegrees: Int?   // maximum_position value
  }
  
  // Get most recent calibration values for current user
  static func getMostRecentCalibration(bluetoothIdentifier: String) async throws -> MostRecentCalibration {
    // Get or create device assignment to ensure we have the assignment ID
    let assignmentId = try await getOrCreateDeviceAssignment(bluetoothIdentifier: bluetoothIdentifier)
    
    // Fetch all calibrations for this device assignment, ordered by most recent
    let calibrations: [CalibrationRow] = try await supabase
      .schema("telemetry")
      .from("calibrations")
      .select("*")
      .eq("device_assignment_id", value: assignmentId.uuidString)
      .order("recorded_at", ascending: false)
      .limit(100) // Get enough to find both stages
      .decoded(as: [CalibrationRow].self)
    
    // Find most recent starting_position and maximum_position
    var restDegrees: Int? = nil
    var maxDegrees: Int? = nil
    
    for calibration in calibrations {
      // flex_value is stored as degrees (as saved by CalibrateDeviceView)
      let flexValue = Int(calibration.flex_value)
      
      if calibration.stage == "starting_position" && restDegrees == nil {
        restDegrees = flexValue
      } else if calibration.stage == "maximum_position" && maxDegrees == nil {
        maxDegrees = flexValue
      }
      
      // Once we have both, we can stop
      if restDegrees != nil && maxDegrees != nil {
        break
      }
    }
    
    return MostRecentCalibration(restDegrees: restDegrees, maxDegrees: maxDegrees)
  }

}

