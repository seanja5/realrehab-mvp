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
    
    _ = try await PatientService.myPatientProfileId(profileId: profile.id)
    
    // Step 1: Get or create device using RPC (devices table RLS only allows admin)
    // The RPC function handles device creation, but we need to extract device_id from the assignment
    let assignmentIdString: String = try await Task { @Sendable in
      struct RPCParams: Encodable {
        let p_bluetooth_identifier: String
      }
      
      let params = RPCParams(p_bluetooth_identifier: bluetoothIdentifier)
      
      return try await supabase
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

    // Invalidate calibration cache so chart shows new data
    if let profile = try? await AuthService.myProfile(),
       let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) {
      await CacheService.shared.invalidate(CacheKey.calibrationPoints(patientProfileId: patientProfileId))
    }
    
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
  
  // MARK: - Fetch All Maximum Calibrations for Patient
  
  struct MaximumCalibrationPoint: Identifiable, Codable {
    let id: UUID
    let degrees: Int
    let recordedAt: Date
  }
  
  // Fetch all maximum calibration values for the current patient
  static func getAllMaximumCalibrationsForPatient() async throws -> [MaximumCalibrationPoint] {
    // Get current user's profile and patient profile ID
    guard let profile = try await AuthService.myProfile() else {
      throw NSError(domain: "TelemetryService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
    }
    
    let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
    return try await getAllMaximumCalibrationsForPatient(patientProfileId: patientProfileId)
  }
  
    // Fetch all maximum calibration values for a specific patient by patientProfileId
    // Uses disk cache so data persists when switching tabs or offline
    static func getAllMaximumCalibrationsForPatient(patientProfileId: UUID) async throws -> [MaximumCalibrationPoint] {
      let cacheKey = CacheKey.calibrationPoints(patientProfileId: patientProfileId)

      // Check cache first (disk persistence for tab switching/offline)
      if let cached = await CacheService.shared.getCached(cacheKey, as: [MaximumCalibrationPoint].self, useDisk: true) {
        return cached
      }

      // Fetch all device assignments for this patient
      let assignments: [DeviceAssignmentRow] = try await supabase
        .schema("telemetry")
        .from("device_assignments")
        .select("*")
        .eq("patient_profile_id", value: patientProfileId.uuidString)
        .decoded(as: [DeviceAssignmentRow].self)
      
      guard !assignments.isEmpty else {
        // Cache empty result so we don't refetch when offline
        let empty: [MaximumCalibrationPoint] = []
        await CacheService.shared.setCached(empty, forKey: cacheKey, ttl: CacheService.TTL.calibrationPoints, useDisk: true)
        return empty
      }
      
      // Get all assignment IDs
      let assignmentIds = assignments.map { $0.id }
      
      // Fetch all maximum_position calibrations for these device assignments
      // We need to query each assignment separately and combine results
      // IMPORTANT: Only fetch "maximum_position" stage, explicitly exclude "starting_position"
      var allCalibrations: [CalibrationRow] = []
      
      for assignmentId in assignmentIds {
        let calibrations: [CalibrationRow] = try await supabase
          .schema("telemetry")
          .from("calibrations")
          .select("*")
          .eq("device_assignment_id", value: assignmentId.uuidString)
          .eq("stage", value: "maximum_position")  // Only filter by stage column - rely on database
          .order("recorded_at", ascending: true)
          .decoded(as: [CalibrationRow].self)
        
        allCalibrations.append(contentsOf: calibrations)
      }
      
      // Convert to MaximumCalibrationPoint array with degrees conversion
      // Note: flex_value in DB might be stored as raw sensor value or already converted to degrees
      // We'll check and convert if needed (if value is in raw sensor range 200-400, convert it)
      let calibrationPoints = allCalibrations.compactMap { calibration -> MaximumCalibrationPoint? in
        // SAFETY CHECK: Only process maximum_position calibrations
        // Double-check stage field to ensure we don't accidentally include rest values
        guard calibration.stage == "maximum_position" else {
          print("⚠️ TelemetryService: Skipping calibration with stage '\(calibration.stage)' - expected 'maximum_position'")
          return nil
        }
        
        // Parse the recorded_at timestamp
        guard let recordedDate = iso.date(from: calibration.recorded_at) else {
          return nil
        }
        
        // Get the stored value
        let storedValue = Int(calibration.flex_value)
        
        // Check if value looks like a raw sensor value (200-400 range) or already in degrees (0-200 range)
        // If it's in the raw sensor range, convert it. Otherwise, use it as-is (already in degrees)
        let degrees: Int
        if storedValue >= 180 && storedValue <= 400 {
          // Looks like raw sensor value, convert it (new range: 180-305 typical, allow up to 400 for safety)
          degrees = convertRawSensorToDegrees(storedValue)
        } else {
          // Already in degrees, use directly
          degrees = storedValue
        }
        
        // Rely only on stage column from database - no degree-based filtering
        // The database stage column is the source of truth
        
        return MaximumCalibrationPoint(
          id: calibration.id,
          degrees: degrees,
          recordedAt: recordedDate
        )
      }
      
      // Sort by recorded_at to ensure chronological order
      let result = calibrationPoints.sorted { $0.recordedAt < $1.recordedAt }

      // Cache the result (disk persistence for tab switching/offline)
      await CacheService.shared.setCached(result, forKey: cacheKey, ttl: CacheService.TTL.calibrationPoints, useDisk: true)

      return result
    }
  
  // Convert raw flex sensor value to degrees (same formula as CalibrateDeviceView)
  private static func convertRawSensorToDegrees(_ sensorValue: Int) -> Int {
    let minSensorValue = 185  // 90 degrees (midpoint of 180-190 range)
    let minDegrees = 90.0
    let sensorRange = 115  // 300 - 185 = 115
    let degreeRange = 90.0  // 180 - 90 = 90
    
    // Convert: degrees = 90 + ((value - 185) / 115) * 90
    // This formula works for any input value, allowing values below 90° and above 180°
    let degrees = minDegrees + (Double(sensorValue - minSensorValue) / Double(sensorRange)) * degreeRange
    
    // Round to nearest integer degree
    return Int(degrees.rounded())
  }

}

