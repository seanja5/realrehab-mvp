import Foundation

// Canonical Weekday type used app-wide
public enum Weekday: Int, CaseIterable, Codable, Identifiable, Sendable {
    case sun = 0, mon, tue, wed, thu, fri, sat
    
    public var id: Int { rawValue }
    
    // Stable order for sorting / display (0-based to match existing stored data)
    public var order: Int { rawValue }
    
    // Short label used in UI chips
    public var shortLabel: String {
        switch self {
        case .sun: return "S"
        case .mon: return "M"
        case .tue: return "T"
        case .wed: return "W"
        case .thu: return "T"
        case .fri: return "F"
        case .sat: return "S"
        }
    }
    
    // Full name if needed
    public var name: String {
        switch self {
        case .sun: return "Sunday"
        case .mon: return "Monday"
        case .tue: return "Tuesday"
        case .wed: return "Wednesday"
        case .thu: return "Thursday"
        case .fri: return "Friday"
        case .sat: return "Saturday"
        }
    }
}

// Helpers commonly needed by both RehabOverviewView and JourneyMapView
public extension Array where Element == Weekday {
    func sortedByWeekOrder() -> [Weekday] {
        self.sorted { $0.order < $1.order }
    }
}

// Lightweight time-of-day model (24h minutes)
public struct DayTime: Codable, Hashable, Sendable {
    public var minutes: Int  // 0..1439
    public init(hours: Int, minutes: Int) { self.minutes = hours * 60 + minutes }
    public init(totalMinutes: Int) { self.minutes = totalMinutes }
    public var hours: Int { minutes / 60 }
    public var mins: Int { minutes % 60 }
    public var display: String {
        let h = hours, m = mins
        let ampm = h >= 12 ? "PM" : "AM"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", h12, m, ampm)
    }
}

// Mapping convenience if we ever need from DateComponents
// Note: Calendar uses 1=Sun, 2=Mon, ..., 7=Sat, but our enum is 0-based
public extension Weekday {
    init?(calendarWeekday: Int) {
        // Convert Calendar weekday (1-7) to our 0-based system (0-6)
        let adjusted = calendarWeekday - 1
        self.init(rawValue: adjusted)
    }
}

