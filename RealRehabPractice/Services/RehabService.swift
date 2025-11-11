import Foundation
import Supabase
import PostgREST

// Supabase includes CodableValue to decode JSONB flexibly
struct Lesson: Decodable, Equatable {
  let id: UUID
  let program_id: UUID
  let exercise_id: UUID
  let order_index: Int
  let params: [String: JSONValue]?
  let created_at: Date?
}

struct AssignmentRow: Decodable {
  let id: UUID
  let patient_id: UUID
  let program_id: UUID
  let active: Bool
}

struct ProgramRow: Decodable {
  let id: UUID
  let title: String
  let description: String?
  let created_by: UUID
}

enum RehabService {
  private static let supabase = SupabaseService.shared.client
  
  // MARK: - Plan Node DTO for JSONB storage
  struct PlanNodeDTO: Codable {
    let id: String  // UUID as string
    let title: String
    let icon: String  // "person" or "video"
    let isLocked: Bool
    let reps: Int
    let restSec: Int
  }
  
  struct PlanRow: Decodable {
    let id: UUID
    let pt_profile_id: UUID
    let patient_profile_id: UUID
    let category: String
    let injury: String
    let status: String
    let created_at: Date?
    let nodes: [PlanNodeDTO]?  // Optional for backward compatibility
    let notes: String?  // Optional notes for the patient
  }

  // Active assignment for current (patient) user
  static func myActiveAssignment() async throws -> AssignmentRow {
    let uid = try AuthService.currentUserId()
    let rows: [AssignmentRow] = try await supabase
      .from("rehab.assignments")
      .select()
      .eq("patient_id", value: uid.uuidString)
      .eq("active", value: true)
      .limit(1)
      .decoded(as: [AssignmentRow].self)

    guard let first = rows.first else {
      throw NSError(
        domain: "RehabService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "No active assignment"]
      )
    }

    return first
  }

  // Ordered lessons for a program
  static func lessons(for programId: UUID) async throws -> [Lesson] {
    try await supabase
      .from("rehab.lessons")
      .select()
      .eq("program_id", value: programId.uuidString)
      .order("order_index", ascending: true)
      .decoded(as: [Lesson].self)
  }

  // Fetch program metadata (useful for UI headers)
  static func program(id: UUID) async throws -> ProgramRow? {
    let rows: [ProgramRow] = try await supabase
      .from("rehab.programs")
      .select()
      .eq("id", value: id.uuidString)
      .limit(1)
      .decoded(as: [ProgramRow].self)

    return rows.first
  }

  // PT-only: update lesson params (JSON) e.g. ["reps": 12, "rest_seconds": 20]
  static func updateLessonParams(lessonId: UUID, params: [String: Any]) async throws {
    let payload: [String: AnyEncodable] = [
      "params": AnyEncodable(params)
    ]

    _ = try await supabase
      .from("rehab.lessons")
      .update(payload)
      .eq("id", value: lessonId.uuidString)
      .execute()
  }

  // PT-only: reorder lessons by updating order_index
  static func updateLessonOrder(lessonId: UUID, newOrderIndex: Int) async throws {
    let payload: [String: AnyEncodable] = [
      "order_index": AnyEncodable(newOrderIndex)
    ]

    _ = try await supabase
      .from("rehab.lessons")
      .update(payload)
      .eq("id", value: lessonId.uuidString)
      .execute()
  }
  
  // MARK: - Rehab Plans (MVP)
  
  static func currentPlan(ptProfileId: UUID, patientProfileId: UUID) async throws -> PlanRow? {
    print("🔍 RehabService.currentPlan: pt_profile_id=\(ptProfileId.uuidString), patient_profile_id=\(patientProfileId.uuidString)")
    
    do {
      let rows: [PlanRow] = try await supabase
        .schema("accounts")
        .from("rehab_plans")
        .select("id,pt_profile_id,patient_profile_id,category,injury,status,created_at,nodes,notes")
        .eq("pt_profile_id", value: ptProfileId.uuidString)
        .eq("patient_profile_id", value: patientProfileId.uuidString)
        .eq("status", value: "active")
        .limit(1)
        .decoded(as: [PlanRow].self)
      
      if let plan = rows.first {
        print("✅ RehabService.currentPlan: found plan id=\(plan.id.uuidString), category=\(plan.category), injury=\(plan.injury)")
      } else {
        print("ℹ️ RehabService.currentPlan: no active plan found for pt_profile_id=\(ptProfileId.uuidString), patient_profile_id=\(patientProfileId.uuidString)")
      }
      
      return rows.first
    } catch {
      // Handle permission errors with user-friendly message
      if let postgrestError = error as? PostgrestError {
        if postgrestError.code == "42501" || postgrestError.code == "PGRST301" {
          print("❌ RehabService.currentPlan: permission denied (403/42501) for pt_profile_id=\(ptProfileId.uuidString), patient_profile_id=\(patientProfileId.uuidString)")
          throw NSError(
            domain: "RehabService",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Your account doesn't have permission to view this rehab plan."]
          )
        }
      }
      print("❌ RehabService.currentPlan error: \(error)")
      throw error
    }
  }
  
  static func saveACLPlan(ptProfileId: UUID, patientProfileId: UUID, nodes: [LessonNode], notes: String? = nil) async throws {
    print("💾 RehabService.saveACLPlan: pt_profile_id=\(ptProfileId.uuidString), patient_profile_id=\(patientProfileId.uuidString), nodes=\(nodes.count)")
    
    do {
      // Set any existing active plans for this patient to archived
      print("📝 RehabService.saveACLPlan: archiving existing active plans...")
      _ = try await supabase
        .schema("accounts")
        .from("rehab_plans")
        .update(AnyEncodable(["status": "archived"]))
        .eq("patient_profile_id", value: patientProfileId.uuidString)
        .eq("status", value: "active")
        .execute()
      
      // Convert LessonNode array to PlanNodeDTO array
      let nodeDTOs = nodes.map { node in
        PlanNodeDTO(
          id: node.id.uuidString,
          title: node.title,
          icon: node.icon.systemName == "figure.stand" ? "person" : "video",
          isLocked: node.isLocked,
          reps: node.reps,
          restSec: node.restSec
        )
      }
      
      // Encode nodes to JSONValue for JSONB storage
      let encoder = JSONEncoder()
      let nodesJSONData = try encoder.encode(nodeDTOs)
      let nodesJSONValue = try JSONDecoder().decode(JSONValue.self, from: nodesJSONData)
      
      // Insert new active plan
      print("➕ RehabService.saveACLPlan: inserting new active plan...")
      var payload: [String: Any] = [
        "pt_profile_id": ptProfileId.uuidString,
        "patient_profile_id": patientProfileId.uuidString,
        "category": "Knee",
        "injury": "ACL",
        "status": "active",
        "nodes": nodesJSONValue
      ]
      
      // Add notes if provided
      if let notes = notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        payload["notes"] = notes
      }
      
      _ = try await supabase
        .schema("accounts")
        .from("rehab_plans")
        .insert(AnyEncodable(payload))
        .execute()
      
      print("✅ RehabService.saveACLPlan: successfully saved plan with \(nodes.count) nodes")
    } catch {
      // Handle permission errors with user-friendly message
      if let postgrestError = error as? PostgrestError {
        if postgrestError.code == "42501" || postgrestError.code == "PGRST301" {
          print("❌ RehabService.saveACLPlan: permission denied (403/42501) for pt_profile_id=\(ptProfileId.uuidString), patient_profile_id=\(patientProfileId.uuidString)")
          throw NSError(
            domain: "RehabService",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Your account doesn't have permission to create this rehab plan."]
          )
        }
      }
      print("❌ RehabService.saveACLPlan error: \(error)")
      throw error
    }
  }
  
  // MARK: - Fetch plan by ID (for loading saved plans)
  static func fetchPlan(planId: UUID) async throws -> PlanRow? {
    print("🔍 RehabService.fetchPlan: planId=\(planId.uuidString)")
    
    do {
      let rows: [PlanRow] = try await supabase
        .schema("accounts")
        .from("rehab_plans")
        .select("id,pt_profile_id,patient_profile_id,category,injury,status,created_at,nodes,notes")
        .eq("id", value: planId.uuidString)
        .limit(1)
        .decoded(as: [PlanRow].self)
      
      if let plan = rows.first {
        print("✅ RehabService.fetchPlan: found plan id=\(plan.id.uuidString), nodes=\(plan.nodes?.count ?? 0)")
      } else {
        print("ℹ️ RehabService.fetchPlan: no plan found for planId=\(planId.uuidString)")
      }
      
      return rows.first
    } catch {
      if let postgrestError = error as? PostgrestError {
        if postgrestError.code == "42501" || postgrestError.code == "PGRST301" {
          print("❌ RehabService.fetchPlan: permission denied (403/42501) for planId=\(planId.uuidString)")
          throw NSError(
            domain: "RehabService",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Your account doesn't have permission to view this rehab plan."]
          )
        }
      }
      print("❌ RehabService.fetchPlan error: \(error)")
      throw error
    }
  }
  
  // MARK: - Update notes for a plan
  static func updatePlanNotes(ptProfileId: UUID, patientProfileId: UUID, notes: String?) async throws {
    print("📝 RehabService.updatePlanNotes: pt_profile_id=\(ptProfileId.uuidString), patient_profile_id=\(patientProfileId.uuidString)")
    
    do {
      // Find the active plan for this patient
      struct PlanIdRow: Decodable {
        let id: UUID
      }
      let rows: [PlanIdRow] = try await supabase
        .schema("accounts")
        .from("rehab_plans")
        .select("id")
        .eq("pt_profile_id", value: ptProfileId.uuidString)
        .eq("patient_profile_id", value: patientProfileId.uuidString)
        .eq("status", value: "active")
        .limit(1)
        .decoded(as: [PlanIdRow].self)
      
      guard let plan = rows.first else {
        // If no plan exists, create one with just notes
        print("ℹ️ RehabService.updatePlanNotes: no active plan found, creating one with notes")
        try await saveACLPlan(
          ptProfileId: ptProfileId,
          patientProfileId: patientProfileId,
          nodes: [],  // Empty nodes for notes-only plan
          notes: notes
        )
        return
      }
      
      // Update the existing plan's notes
      var updatePayload: [String: Any] = [:]
      if let notes = notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        updatePayload["notes"] = notes
      } else {
        updatePayload["notes"] = NSNull()  // Set to NULL if empty
      }
      
      _ = try await supabase
        .schema("accounts")
        .from("rehab_plans")
        .update(AnyEncodable(updatePayload))
        .eq("id", value: plan.id.uuidString)
        .execute()
      
      print("✅ RehabService.updatePlanNotes: successfully updated notes")
    } catch {
      print("❌ RehabService.updatePlanNotes error: \(error)")
      throw error
    }
  }
}

// MARK: - JSON value helpers

enum JSONValue: Codable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(from decoder: Decoder) throws {
    if let keyed = try? decoder.container(keyedBy: JSONCodingKey.self) {
      var dictionary: [String: JSONValue] = [:]
      for key in keyed.allKeys {
        dictionary[key.stringValue] = try keyed.decode(JSONValue.self, forKey: key)
      }
      self = .object(dictionary)
      return
    }

    if var unkeyed = try? decoder.unkeyedContainer() {
      var values: [JSONValue] = []
      while !unkeyed.isAtEnd {
        values.append(try unkeyed.decode(JSONValue.self))
      }
      self = .array(values)
      return
    }

    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
      return
    }
    if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
      return
    }
    if let double = try? container.decode(Double.self) {
      self = .number(double)
      return
    }
    self = .string(try container.decode(String.self))
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .string(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .number(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .bool(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .object(let dictionary):
      var container = encoder.container(keyedBy: JSONCodingKey.self)
      for (key, value) in dictionary {
        try container.encode(value, forKey: JSONCodingKey(stringValue: key)!)
      }
    case .array(let array):
      var container = encoder.unkeyedContainer()
      for value in array {
        try container.encode(value)
      }
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }
}

private struct JSONCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int? = nil

  init?(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue: Int) {
    self.stringValue = "\(intValue)"
  }
}

