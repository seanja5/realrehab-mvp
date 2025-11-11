import Foundation

enum GenderMapper {
    static func apiValue(from display: String) -> String {
        switch display.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "male":
            return "male"
        case "female":
            return "female"
        case "non-binary", "nonbinary", "non binary":
            return "non_binary"
        case "prefer not to say", "prefer_not_to_say", "prefer-not-to-say":
            return "prefer_not_to_say"
        default:
            return "other"
        }
    }
}

