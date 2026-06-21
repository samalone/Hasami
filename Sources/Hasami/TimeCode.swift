import Foundation

/// A TimeCode represents a point in time as an integer value.
/// The value is typically the number of seconds since the Unix epoch.
public struct TimeCode: Equatable, Comparable, Hashable, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral {
    public let value: Int
    
    public init(value: Int) {
        self.value = value
    }
    
    public init(integerLiteral value: Int) {
        self.value = value
    }
    
    public init(stringLiteral value: String) {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else {
            fatalError("Invalid ISO 8601 date string: \(value)")
        }
        self.value = Int(date.timeIntervalSince1970)
    }
    
    public init(date: Date) {
        self.value = Int(date.timeIntervalSince1970)
    }

    public static func < (lhs: TimeCode, rhs: TimeCode) -> Bool {
        return lhs.value < rhs.value
    }
}

// MARK: - CustomStringConvertible
extension TimeCode: CustomStringConvertible {
    public var description: String {
        return "\(value)"
    }
}
