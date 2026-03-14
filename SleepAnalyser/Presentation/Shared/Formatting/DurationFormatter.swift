import Foundation

enum DurationFormatter {
    static func format(_ interval: TimeInterval, style: Style = .short) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        switch style {
        case .short:
            return hours > 0 ? L10n.hoursMinutes(hours, minutes) : L10n.minutesOnly(minutes)
        case .long:
            return hours > 0 ? L10n.hoursMinutesLong(hours, minutes) : L10n.minutesOnlyLong(minutes)
        case .compact:
            return String(format: "%d:%02d", hours, minutes)
        }
    }

    enum Style { case short, long, compact }
}
