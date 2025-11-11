import Foundation
import Supabase
import PostgREST

struct Profile: Codable, Equatable {
  let id: UUID
  let user_id: UUID
  var role: String
  var email: String?
  var first_name: String?
  var last_name: String?
  var phone: String?
  var created_at: Date?
  var updated_at: Date?
}

enum AuthService {
  private static let supabase = SupabaseService.shared.client

  // MARK: - Auth
  static func signUp(email: String, password: String) async throws {
    _ = try await supabase.auth.signUp(email: email, password: password)
  }

  static func signIn(email: String, password: String) async throws {
    _ = try await supabase.auth.signIn(email: email, password: password)
  }

  static func signOut() async throws {
    try await supabase.auth.signOut()
  }

  static func currentUserId() throws -> UUID {
    if let cached = supabase.auth.currentUser?.id {
      return cached
    }

    throw NSError(
      domain: "AuthService",
      code: 401,
      userInfo: [NSLocalizedDescriptionKey: "No authenticated user - please sign in."]
    )
  }

  // MARK: - Profile bootstrap (if DB trigger wasn’t added)
  static func ensureProfile(
    defaultRole: String = "patient",
    firstName: String,
    lastName: String
  ) async throws {
    let user = try await fetchCurrentUser()
    let uid = user.id

    let payload: [String: AnyEncodable] = [
      "user_id": AnyEncodable(uid.uuidString),
      "email": AnyEncodable(user.email ?? ""),
      "role": AnyEncodable(defaultRole),
      "first_name": AnyEncodable(firstName),
      "last_name": AnyEncodable(lastName)
    ]

    _ = try await supabase
      .schema("accounts")
      .from("profiles")
      .upsert(payload, onConflict: "user_id")
      .execute()
  }

  // MARK: - Fetch my profile
  static func myProfile() async throws -> Profile? {
    let uid = try currentUserId()
    let rows: [Profile] = try await supabase
      .schema("accounts")
      .from("profiles")
      .select("id,user_id,email,role,first_name,last_name,phone,created_at,updated_at")
      .eq("user_id", value: uid.uuidString)
      .limit(1)
      .decoded(as: [Profile].self)

    return rows.first
  }

  // MARK: - Fetch profile ID and role
  static func myProfileIdAndRole() async throws -> (UUID, String) {
    let uid = try currentUserId()
    struct ProfileRow: Decodable {
      let id: UUID
      let role: String
    }
    let rows: [ProfileRow] = try await supabase
      .schema("accounts")
      .from("profiles")
      .select("id,role")
      .eq("user_id", value: uid.uuidString)
      .limit(1)
      .decoded(as: [ProfileRow].self)

    guard let row = rows.first else {
      throw NSError(
        domain: "AuthService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Profile not found"]
      )
    }
    return (row.id, row.role)
  }

  // MARK: - Identity resolution
  struct RRProfileRow: Decodable { let id: UUID }
  struct RRPTProfileRow: Decodable { let id: UUID }
  
  /// Resolve the app's base profile id and PT profile id for the current session.
  static func resolveIdsForCurrentUser() async throws -> (profileId: UUID?, ptProfileId: UUID?) {
    let user: User?
    if let session = try? await supabase.auth.session {
      user = session.user
    } else {
      user = supabase.auth.currentUser
    }
    
    guard let user = user else {
      return (nil, nil)
    }
    
    // 1) accounts.profiles.id by auth user_id
    let profileRows: [RRProfileRow] = try await supabase
      .schema("accounts")
      .from("profiles")
      .select("id")
      .eq("user_id", value: user.id.uuidString)
      .limit(1)
      .decoded(as: [RRProfileRow].self)
    
    guard let profile = profileRows.first else {
      return (nil, nil)
    }
    
    // 2) accounts.pt_profiles.id by profile_id
    let ptRows: [RRPTProfileRow]? = try? await supabase
      .schema("accounts")
      .from("pt_profiles")
      .select("id")
      .eq("profile_id", value: profile.id.uuidString)
      .limit(1)
      .decoded(as: [RRPTProfileRow].self)
    
    return (profile.id, ptRows?.first?.id)
  }

  // MARK: - Helpers
  private static func fetchCurrentUser() async throws -> User {
    if let session = try? await supabase.auth.session {
      return session.user
    }

    if let cached = supabase.auth.currentUser {
      return cached
    }

    throw NSError(
      domain: "AuthService",
      code: 401,
      userInfo: [NSLocalizedDescriptionKey: "No authenticated user - please sign in."]
    )
  }
}

// MARK: - Dynamic Encoding Helper

struct AnyEncodable: Encodable {
  private let value: Any?

  init(_ value: Any?) {
    self.value = value
  }

  func encode(to encoder: Encoder) throws {
    guard let value else {
      var container = encoder.singleValueContainer()
      try container.encodeNil()
      return
    }

    if Mirror(reflecting: value).displayStyle == .optional {
      if let child = Mirror(reflecting: value).children.first {
        try AnyEncodable(child.value).encode(to: encoder)
      } else {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
      }
      return
    }

    switch value {
    case let encodableValue as JSONValue:
      try encodableValue.encode(to: encoder)
    case let string as String:
      var container = encoder.singleValueContainer()
      try container.encode(string)
    case let bool as Bool:
      var container = encoder.singleValueContainer()
      try container.encode(bool)
    case let int as Int:
      var container = encoder.singleValueContainer()
      try container.encode(int)
    case let int8 as Int8:
      var container = encoder.singleValueContainer()
      try container.encode(int8)
    case let int16 as Int16:
      var container = encoder.singleValueContainer()
      try container.encode(int16)
    case let int32 as Int32:
      var container = encoder.singleValueContainer()
      try container.encode(int32)
    case let int64 as Int64:
      var container = encoder.singleValueContainer()
      try container.encode(int64)
    case let uint as UInt:
      var container = encoder.singleValueContainer()
      try container.encode(uint)
    case let uint8 as UInt8:
      var container = encoder.singleValueContainer()
      try container.encode(uint8)
    case let uint16 as UInt16:
      var container = encoder.singleValueContainer()
      try container.encode(uint16)
    case let uint32 as UInt32:
      var container = encoder.singleValueContainer()
      try container.encode(uint32)
    case let uint64 as UInt64:
      var container = encoder.singleValueContainer()
      try container.encode(uint64)
    case let double as Double:
      var container = encoder.singleValueContainer()
      try container.encode(double)
    case let float as Float:
      var container = encoder.singleValueContainer()
      try container.encode(float)
    case let uuid as UUID:
      var container = encoder.singleValueContainer()
      try container.encode(uuid.uuidString)
    case let date as Date:
      var container = encoder.singleValueContainer()
      try container.encode(date.iso8601String())
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        var container = encoder.singleValueContainer()
        try container.encode(number.boolValue)
      } else {
        var container = encoder.singleValueContainer()
        try container.encode(number.doubleValue)
      }
    case let dict as [String: Any]:
      var container = encoder.container(keyedBy: AnyCodingKey.self)
      for (key, nestedValue) in dict {
        try container.encode(AnyEncodable(nestedValue), forKey: AnyCodingKey(key))
      }
    case let array as [Any]:
      var container = encoder.unkeyedContainer()
      for element in array {
        try container.encode(AnyEncodable(element))
      }
    case is NSNull:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    default:
      throw NSError(
        domain: "AnyEncodable",
        code: 422,
        userInfo: [NSLocalizedDescriptionKey: "Unsupported value: \(value)"]
      )
    }
  }
}

private struct AnyCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init(_ string: String) {
    self.stringValue = string
    self.intValue = nil
  }

  init?(stringValue: String) {
    self.init(stringValue)
  }

  init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
}

private extension Date {
  func iso8601String() -> String {
    ISO8601DateFormatter().string(from: self)
  }
}

extension PostgrestBuilder {
  func decoded<T: Decodable>(
    as type: T.Type = T.self,
    options: FetchOptions = FetchOptions()
  ) async throws -> T {
    try await execute(options: options).value
  }
}

