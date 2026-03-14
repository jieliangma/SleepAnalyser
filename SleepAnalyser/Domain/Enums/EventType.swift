import Foundation

/// Types of audio events detected during sleep sessions
enum EventType: String, Codable, CaseIterable, Sendable {
    case snore
    case disturbance
    case speech
    case outOfBed
    case returnedToBed
    case apneaSuspected

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .snore:           return "Snoring"
        case .disturbance:     return "Disturbance"
        case .speech:          return "Speech/TV"
        case .outOfBed:        return "Got Out of Bed"
        case .returnedToBed:   return "Returned to Bed"
        case .apneaSuspected:  return "Possible Apnea"
        }
    }

    /// SF Symbol icon name
    var sfSymbolName: String {
        switch self {
        case .snore:           return "zzz"
        case .disturbance:     return "waveform.path.ecg"
        case .speech:          return "mouth.fill"
        case .outOfBed:        return "figure.walk"
        case .returnedToBed:   return "bed.double.fill"
        case .apneaSuspected:  return "exclamationmark.triangle.fill"
        }
    }

    /// Default severity level (0-1) for this event type
    var defaultSeverity: Double {
        switch self {
        case .snore:           return 0.3
        case .disturbance:     return 0.5
        case .speech:          return 0.4
        case .outOfBed:        return 0.6
        case .returnedToBed:   return 0.1
        case .apneaSuspected:  return 0.9
        }
    }

    /// Whether this event interrupts sleep quality scoring
    var affectsSleepQuality: Bool {
        switch self {
        case .snore, .disturbance, .outOfBed, .apneaSuspected: return true
        case .speech, .returnedToBed: return false
        }
    }
}
