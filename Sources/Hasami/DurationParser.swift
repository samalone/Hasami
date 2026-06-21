import Foundation

/// Parses human-friendly duration strings into a number of seconds, for use as
/// an absolute half-life on the command line.
public enum DurationParser {
    private static let multipliers: [Character: Double] = [
        "s": 1,        // seconds
        "m": 60,       // minutes
        "h": 3600,     // hours
        "d": 86400,    // days
        "w": 604800,   // weeks
    ]

    /// Parses a duration string such as `30d`, `12h`, `90m`, `2w`, or `45s` into a
    /// number of seconds. A bare number (no suffix) is interpreted as seconds.
    /// Fractional values are allowed (e.g. `1.5d`).
    ///
    /// - Parameter string: The duration string to parse.
    /// - Returns: The duration in seconds, or `nil` if the string is not a valid,
    ///   positive duration.
    public static func seconds(from string: String) -> Double? {
        let s = string.trimmingCharacters(in: .whitespaces).lowercased()
        guard let last = s.last else { return nil }

        if let multiplier = multipliers[last] {
            guard let value = Double(s.dropLast()), value > 0 else { return nil }
            return value * multiplier
        }

        // No recognized suffix: treat the whole string as a number of seconds.
        guard let value = Double(s), value > 0 else { return nil }
        return value
    }
}
