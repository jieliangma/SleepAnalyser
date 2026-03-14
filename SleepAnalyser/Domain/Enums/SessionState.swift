import Foundation

/// State of a sleep tracking session
enum SessionState: String, Codable, Sendable {
    case idle
    case preparing
    case recording
    case paused
    case stopped
    case failed

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .idle:      return "Idle"
        case .preparing: return "Preparing"
        case .recording: return "Recording"
        case .paused:    return "Paused"
        case .stopped:   return "Stopped"
        case .failed:    return "Failed"
        }
    }

    /// Whether the session is actively tracking
    var isActive: Bool {
        self == .recording || self == .paused
    }

    /// Whether the session has ended (either normally or with error)
    var isFinished: Bool {
        self == .stopped || self == .failed
    }

    /// Check if transitioning to a target state is valid
    func canTransition(to target: SessionState) -> Bool {
        switch (self, target) {
        case (.idle, .preparing):       return true
        case (.preparing, .recording):  return true
        case (.preparing, .failed):     return true
        case (.recording, .paused):     return true
        case (.recording, .stopped):    return true
        case (.recording, .failed):     return true
        case (.paused, .recording):     return true
        case (.paused, .stopped):       return true
        default:                        return false
        }
    }

    /// SF Symbol for this state
    var sfSymbolName: String {
        switch self {
        case .idle:      return "moon.fill"
        case .preparing: return "gear"
        case .recording: return "waveform"
        case .paused:    return "pause.fill"
        case .stopped:   return "stop.fill"
        case .failed:    return "exclamationmark.triangle.fill"
        }
    }
}
