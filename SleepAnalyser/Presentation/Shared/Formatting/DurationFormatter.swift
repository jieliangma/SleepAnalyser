import Foundation

enum DurationFormatter {
    static func format(_ interval: TimeInterval, style: Style = .short) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60

        switch style {
        case .short:
            if hours > 0 { return "\(hours)h \(minutes)m" }
            return "\(minutes)m"
        case .long:
            if hours > 0 { return "\(hours) hours \(minutes) minutes" }
            return "\(minutes) minutes"
        case .compact:
            return String(format: "%d:%02d", hours, minutes)
        }
    }

    enum Style { case short, long, compact }
}
