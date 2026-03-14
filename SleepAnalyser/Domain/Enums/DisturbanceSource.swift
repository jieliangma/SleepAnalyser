import Foundation

/// Sources of environmental disturbance detected during sleep
enum DisturbanceSource: String, Codable, CaseIterable, Sendable {
    case traffic
    case hvac
    case rain
    case thunder
    case partner
    case pet
    case tv
    case alarm
    case unknown

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .traffic:  return "Traffic"
        case .hvac:     return "HVAC/Air Conditioning"
        case .rain:     return "Rain"
        case .thunder:  return "Thunder"
        case .partner:  return "Partner"
        case .pet:      return "Pet"
        case .tv:       return "TV/Media"
        case .alarm:    return "Alarm/Notification"
        case .unknown:  return "Unknown"
        }
    }

    /// SF Symbol icon name
    var sfSymbolName: String {
        switch self {
        case .traffic:  return "car.fill"
        case .hvac:     return "fan.fill"
        case .rain:     return "cloud.rain.fill"
        case .thunder:  return "cloud.bolt.fill"
        case .partner:  return "person.fill"
        case .pet:      return "pawprint.fill"
        case .tv:       return "tv.fill"
        case .alarm:    return "bell.fill"
        case .unknown:  return "questionmark.circle.fill"
        }
    }

    /// Brief description of the disturbance source
    var description: String {
        switch self {
        case .traffic:  return "Vehicle noise from outside (cars, motorcycles, trucks)"
        case .hvac:     return "Heating, ventilation, or air conditioning sounds"
        case .rain:     return "Rain or precipitation sounds"
        case .thunder:  return "Thunder or storm sounds"
        case .partner:  return "Sounds from a bed partner"
        case .pet:      return "Pet movement or vocalizations"
        case .tv:       return "Television, music, or media playback"
        case .alarm:    return "Alarm clock or device notifications"
        case .unknown:  return "Unidentified environmental sound"
        }
    }

    /// Whether this source is typically continuous (vs transient)
    var isContinuous: Bool {
        switch self {
        case .hvac, .rain, .tv: return true
        case .traffic, .thunder, .partner, .pet, .alarm, .unknown: return false
        }
    }
}
