import Foundation

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }

    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    var timeIntervalSinceMidnight: TimeInterval {
        timeIntervalSince(startOfDay)
    }

    var sleepTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }

    static func weekRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? date
        return (start, end)
    }

    static func monthRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: date)
        return (interval?.start ?? date, interval?.end ?? date)
    }
}
