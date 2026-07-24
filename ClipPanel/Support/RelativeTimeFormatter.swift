import Foundation

enum RelativeTimeFormatter {
    /// Deliberately coarse for the compact panel: no live second-by-second counter.
    static func string(since date: Date, now: Date = .now) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        let minutes = Int(elapsed / 60)
        guard minutes > 0 else { return "Now" }
        if minutes < 60 { return "\(minutes) min" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr" }

        let days = hours / 24
        if days < 7 { return "\(days) d" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
