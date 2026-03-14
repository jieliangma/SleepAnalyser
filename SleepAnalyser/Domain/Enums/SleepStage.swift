import Foundation

/// Represents the five clinically recognized sleep stages plus unknown.
/// Based on the AASM (American Academy of Sleep Medicine) scoring standard.
enum SleepStage: String, Codable, CaseIterable, Sendable, Comparable {
    case awake
    case n1
    case n2
    case n3
    case rem
    case unknown

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .awake:   return "Awake"
        case .n1:      return "Light Sleep (N1)"
        case .n2:      return "Light Sleep (N2)"
        case .n3:      return "Deep Sleep (N3)"
        case .rem:     return "REM Sleep"
        case .unknown: return "Unknown"
        }
    }

    /// Short display name for compact UI
    var shortName: String {
        switch self {
        case .awake:   return "Awake"
        case .n1:      return "N1"
        case .n2:      return "N2"
        case .n3:      return "Deep"
        case .rem:     return "REM"
        case .unknown: return "—"
        }
    }

    /// Hex color string for chart visualization
    var colorHex: String {
        switch self {
        case .awake:   return "94A3B8" // Slate gray
        case .n1:      return "38BDF8" // Sky blue
        case .n2:      return "3B82F6" // Blue
        case .n3:      return "6366F1" // Indigo
        case .rem:     return "A855F7" // Purple
        case .unknown: return "64748B" // Dark slate
        }
    }

    /// Order for Y-axis positioning in hypnogram (higher = top of chart)
    var order: Int {
        switch self {
        case .awake:   return 5
        case .rem:     return 4
        case .n1:      return 3
        case .n2:      return 2
        case .n3:      return 1
        case .unknown: return 0
        }
    }

    /// Whether the subject is actually asleep in this stage
    var isAsleep: Bool {
        switch self {
        case .n1, .n2, .n3, .rem: return true
        case .awake, .unknown:    return false
        }
    }

    /// Whether this is a light sleep stage (N1 or N2)
    var isLightSleep: Bool {
        self == .n1 || self == .n2
    }

    /// SF Symbol name for this stage
    var sfSymbolName: String {
        switch self {
        case .awake:   return "eye.fill"
        case .n1:      return "moon.fill"
        case .n2:      return "moon.stars.fill"
        case .n3:      return "moon.zzz.fill"
        case .rem:     return "brain.head.profile"
        case .unknown: return "questionmark.circle"
        }
    }

    // MARK: - Comparable

    static func < (lhs: SleepStage, rhs: SleepStage) -> Bool {
        lhs.order < rhs.order
    }
}
