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
    // Clear all caches on logout
    Task { @MainActor in
      CacheService.shared.clearAll()
      print("✅ AuthService.signOut: cleared all caches")
    }
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
    let cacheKey = CacheKey.authProfile(userId: uid)
    
    // Check cache first (disk persistence enabled, 24h TTL)
    if let cached = await CacheService.shared.getCached(cacheKey, as: Profile?.self, useDisk: true) {
      print("✅ AuthService.myProfile: cache hit")
      return cached
    }
    
    // Fetch from Supabase
    let rows: [Profile] = try await supabase
      .schema("accounts")
      .from("profiles")
      .select("id,user_id,email,role,first_name,last_name,phone,created_at,updated_at")
      .eq("user_id", value: uid.uuidString)
      .limit(1)
      .decoded(as: [Profile].self)

    let result = rows.first
    
    // Cache the result (disk persistence enabled, 24h TTL)
    await CacheService.shared.setCached(result, forKey: cacheKey, ttl: CacheService.TTL.profile, useDisk: true)
    print("✅ AuthService.myProfile: cached result")
    
    return result
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
  
  /// Cached session data for offline app launch. Stored when user successfully loads while online.
  struct ResolvedSessionBootstrap: Codable {
    let profileId: UUID
    let ptProfileId: UUID?
    let role: String
  }
  
  struct RRProfileRow: Decodable { let id: UUID }
  struct RRPTProfileRow: Decodable { let id: UUID }
  
  /// Cache the resolved session for offline app launch. Call after successful login.
  static func cacheResolvedSession(profileId: UUID, ptProfileId: UUID?, role: String) async {
    do {
      let uid = try currentUserId()
      let bootstrap = ResolvedSessionBootstrap(profileId: profileId, ptProfileId: ptProfileId, role: role)
      await CacheService.shared.setCached(bootstrap, forKey: CacheKey.resolvedSession(userId: uid), ttl: CacheService.TTL.resolvedSession, useDisk: true)
      print("✅ AuthService.cacheResolvedSession: cached for offline")
    } catch {
      print("❌ AuthService.cacheResolvedSession: \(error)")
    }
  }
  
  /// Resolve session for app launch. Uses cache when offline so user can access app without network.
  /// Returns (profileId, ptProfileId, role) or nil if no valid session.
  static func resolveSessionForLaunch() async -> ResolvedSessionBootstrap? {
    // Use currentUser only (sync, from local storage - works offline). Avoid session which is async.
    guard let user = supabase.auth.currentUser else { return nil }
    
    let cacheKey = CacheKey.resolvedSession(userId: user.id)
    
    // Check cache first (disk - survives app restart, works offline)
    if let cached = await CacheService.shared.getCached(cacheKey, as: ResolvedSessionBootstrap.self, useDisk: true) {
      print("✅ AuthService.resolveSessionForLaunch: cache hit (offline/restart)")
      return cached
    }
    
    // Fetch from network
    do {
      let ids = try await resolveIdsForCurrentUser()
      guard let profileId = ids.profileId else { return nil }
      let (_, role) = try await myProfileIdAndRole()
      
      let bootstrap = ResolvedSessionBootstrap(
        profileId: profileId,
        ptProfileId: ids.ptProfileId,
        role: role
      )
      await CacheService.shared.setCached(bootstrap, forKey: cacheKey, ttl: CacheService.TTL.resolvedSession, useDisk: true)
      print("✅ AuthService.resolveSessionForLaunch: cached for offline")
      return bootstrap
    } catch {
      print("❌ AuthService.resolveSessionForLaunch: \(error)")
      return nil
    }
  }
  
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
    // Note: JSONValue from RehabService.swift is accessible at module level
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

extension Date {
  func iso8601String() -> String {
    ISO8601DateFormatter().string(from: self)
  }
  
  /// Formats a date as "YYYY-MM-DD" using local calendar components
  /// This prevents timezone shifts that can cause dates to appear one day earlier
  func dateOnlyString() -> String {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: self)
    guard let year = components.year, let month = components.month, let day = components.day else {
      // Fallback to ISO8601 if components can't be extracted
      let df = ISO8601DateFormatter()
      df.formatOptions = [.withFullDate]
      return df.string(from: self)
    }
    return String(format: "%04d-%02d-%02d", year, month, day)
  }
  
  /// Parses a "YYYY-MM-DD" date string as a local date (no timezone conversion)
  /// This prevents dates from appearing one day earlier when displayed
  static func fromDateOnlyString(_ dateString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale.current
    return formatter.date(from: dateString)
  }
}

extension PostgrestBuilder {
  /// Async wrapper so `await` has a real suspension (avoids "no async operations" warning).
  func executeAsync(options: FetchOptions = FetchOptions()) async throws {
    await Task.yield()
    _ = try await execute(options: options)
  }

  func decoded<T: Decodable>(
    as type: T.Type = T.self,
    options: FetchOptions = FetchOptions()
  ) async throws -> T {
    await Task.yield()
    return try await execute(options: options).value
  }
}

