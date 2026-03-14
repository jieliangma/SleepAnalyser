import Foundation

/// Represents confidence level of a prediction or detection
enum ConfidenceLevel: Sendable, Codable, Comparable {
    case veryLow
    case low
    case medium
    case high
    case veryHigh

    /// The threshold value for this confidence level
    var threshold: Double {
        switch self {
        case .veryLow:  return 0.2
        case .low:      return 0.4
        case .medium:   return 0.6
        case .high:     return 0.8
        case .veryHigh: return 0.95
        }
    }

    /// Initialize from a raw confidence value (0.0 - 1.0)
    init(rawConfidence: Double) {
        switch rawConfidence {
        case 0.95...: self = .veryHigh
        case 0.8..<0.95: self = .high
        case 0.6..<0.8: self = .medium
        case 0.4..<0.6: self = .low
        default: self = .veryLow
        }
    }

    /// Display name
    var displayName: String {
        switch self {
        case .veryLow:  return "Very Low"
        case .low:      return "Low"
        case .medium:   return "Medium"
        case .high:     return "High"
        case .veryHigh: return "Very High"
        }
    }

    /// Hex color for confidence badge
    var colorHex: String {
        switch self {
        case .veryLow:  return "EF4444" // Red
        case .low:      return "F59E0B" // Amber
        case .medium:   return "EAB308" // Yellow
        case .high:     return "22C55E" // Green
        case .veryHigh: return "10B981" // Emerald
        }
    }

    /// Whether this confidence level is trustworthy enough to display
    var isTrustworthy: Bool {
        switch self {
        case .high, .veryHigh: return true
        default: return false
        }
    }
}
