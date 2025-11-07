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

