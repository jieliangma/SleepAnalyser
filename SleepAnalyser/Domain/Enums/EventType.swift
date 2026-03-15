import Foundation

enum EventType: String, Codable, CaseIterable, Sendable {
    case snore
    case bruxism
    case sleepTalking
    case disturbance
    case speech
    case outOfBed
    case returnedToBed
    case apneaSuspected

    var displayName: String {
        switch self {
        case .snore:           return L10n.eventSnore
        case .bruxism:         return L10n.eventBruxism
        case .sleepTalking:    return L10n.eventSleepTalking
        case .disturbance:     return L10n.eventDisturbance
        case .speech:          return L10n.eventSpeech
        case .outOfBed:        return L10n.eventOutOfBed
        case .returnedToBed:   return L10n.eventReturnedToBed
        case .apneaSuspected:  return L10n.eventApnea
        }
    }

    var sfSymbolName: String {
        switch self {
        case .snore:           return "zzz"
        case .bruxism:         return "mouth.fill"
        case .sleepTalking:    return "text.bubble.fill"
        case .disturbance:     return "waveform.path.ecg"
        case .speech:          return "tv.fill"
        case .outOfBed:        return "figure.walk"
        case .returnedToBed:   return "bed.double.fill"
        case .apneaSuspected:  return "exclamationmark.triangle.fill"
        }
    }

    var defaultSeverity: Double {
        switch self {
        case .snore:           return 0.3
        case .bruxism:         return 0.5
        case .sleepTalking:    return 0.2
        case .disturbance:     return 0.5
        case .speech:          return 0.4
        case .outOfBed:        return 0.6
        case .returnedToBed:   return 0.1
        case .apneaSuspected:  return 0.9
        }
    }

    var affectsSleepQuality: Bool {
        switch self {
        case .snore, .bruxism, .disturbance, .outOfBed, .apneaSuspected: return true
        case .sleepTalking, .speech, .returnedToBed: return false
        }
    }
}
