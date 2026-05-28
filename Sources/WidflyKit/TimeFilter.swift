import Foundation

public enum TimeFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning = "Morning (06:00 - 12:00)"
    case afternoon = "Afternoon (12:00 - 18:00)"
    case evening = "Evening (18:00 - 06:00)"

    public var id: String { rawValue }

    /// Stable token passed to in-page JavaScript filtering (independent of display labels).
    public var jsToken: String {
        switch self {
        case .morning: return "morning"
        case .afternoon: return "afternoon"
        case .evening: return "evening"
        }
    }
}
