import Foundation

/// Cache service providing memory-first caching with optional disk persistence
@MainActor
final class CacheService {
    static let shared = CacheService()
    
    // In-memory cache
    private var memoryCache: [String: Any] = [:]
    
    // Disk cache directory
    private let cacheDirectory: URL
    
    // TTL defaults (in seconds)
    enum TTL {
        static let profile: TimeInterval = 24 * 60 * 60 // 24 hours
        static let ptInfo: TimeInterval = 60 * 60 // 1 hour
        static let rehabPlan: TimeInterval = 5 * 60 // 5 minutes
        static let patientList: TimeInterval = 5 * 60 // 5 minutes
        static let patientDetail: TimeInterval = 10 * 60 // 10 minutes
        static let assignment: TimeInterval = 10 * 60 // 10 minutes
        static let program: TimeInterval = 10 * 60 // 10 minutes
        static let lessons: TimeInterval = 10 * 60 // 10 minutes
        static let hasPT: TimeInterval = 60 * 60 // 1 hour
    }
    
    private init() {
        // Create cache directory in app's caches directory
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesURL.appendingPathComponent("RealRehabCache", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Memory Cache Operations
    
    /// Get value from memory cache
    func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        guard let entry = memoryCache[key] as? CacheEntry<T> else {
            return nil
        }
        
        if entry.isExpired {
            memoryCache.removeValue(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    /// Set value in memory cache
    func set<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval) {
        let entry = CacheEntry(value: value, ttl: ttl)
        memoryCache[key] = entry
    }
    
    /// Remove value from memory cache
    func remove(_ key: String) {
        memoryCache.removeValue(forKey: key)
    }
    
    // MARK: - Disk Cache Operations
    
    /// Get value from disk cache (also loads into memory)
    func getFromDisk<T: Codable>(_ key: String, as type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) else {
            return nil
        }
        
        if entry.isExpired {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        
        // Load into memory cache for faster access
        memoryCache[key] = entry
        
        return entry.value
    }
    
    /// Set value in disk cache (also updates memory)
    func setToDisk<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval) {
        let entry = CacheEntry(value: value, ttl: ttl)
        
        // Update memory cache
        memoryCache[key] = entry
        
        // Write to disk
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
    
    /// Remove value from disk cache
    func removeFromDisk(_ key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        try? FileManager.default.removeItem(at: fileURL)
        memoryCache.removeValue(forKey: key)
    }
    
    // MARK: - Combined Operations
    
    /// Get value from cache (memory first, then disk)
    func getCached<T: Codable>(_ key: String, as type: T.Type, useDisk: Bool = false) async -> T? {
        await Task.yield()
        // Try memory first
        if let value = get(key, as: type) {
            return value
        }
        
        // Try disk if enabled
        if useDisk {
            return getFromDisk(key, as: type)
        }
        
        return nil
    }
    
    /// Set value in cache (memory, optionally disk)
    func setCached<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval, useDisk: Bool = false) async {
        await Task.yield()
        if useDisk {
            setToDisk(value, forKey: key, ttl: ttl)
        } else {
            set(value, forKey: key, ttl: ttl)
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all caches (memory + disk)
    func clearAll() {
        memoryCache.removeAll()
        
        // Remove all cache files
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    /// Clear expired entries from memory
    func clearExpired() {
        let keysToRemove = memoryCache.keys.filter { key in
            // Try to check if entry is expired (type-erased check)
            if let entry = memoryCache[key] as? (any CacheEntryProtocol) {
                return entry.isExpired
            }
            return false
        }
        
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
        }
    }
    
    /// Invalidate specific key (remove from both memory and disk)
    func invalidate(_ key: String) async {
        await Task.yield()
        remove(key)
        removeFromDisk(key)
    }
    
    /// Invalidate keys matching pattern (e.g., all patient_profile:*)
    func invalidateMatching(_ pattern: String) async {
        let keysToRemove = memoryCache.keys.filter { $0.hasPrefix(pattern) }
        for key in keysToRemove {
            await invalidate(key)
        }
    }
}

// MARK: - Type-erased protocol for expired check
private protocol CacheEntryProtocol {
    var isExpired: Bool { get }
}

extension CacheEntry: CacheEntryProtocol {}

