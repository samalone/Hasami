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
    
    /// Returns the digit at the given position in the base-N representation of this TimeCode.
    /// - Parameters:
    ///   - position: The position of the digit to retrieve (0-based, starting from the least significant digit)
    ///   - base: The base of the number system to use
    /// - Returns: The digit at the given position
    /// - Precondition: base > 1 && position >= 0
    public func digit(at position: Int, base: Int) -> Int {
        precondition(base > 1, "Base must be greater than 1")
        precondition(position >= 0, "Position must be non-negative")
        
        var remaining = value
        for _ in 0..<position {
            remaining /= base
        }
        return remaining % base
    }
    
    /// Returns the number of digits in the base-N representation of this TimeCode.
    /// - Parameter base: The base of the number system to use
    /// - Returns: The number of digits
    /// - Precondition: base > 1
    public func digitCount(base: Int) -> Int {
        precondition(base > 1, "Base must be greater than 1")
        
        if value == 0 {
            return 1
        }
        
        var count = 0
        var remaining = value
        while remaining > 0 {
            remaining /= base
            count += 1
        }
        return count
    }
    
    /// Returns the position of the most significant digit that differs between this TimeCode and another.
    /// - Parameters:
    ///   - other: The other TimeCode to compare with
    ///   - base: The base of the number system to use
    /// - Returns: The position of the most significant differing digit, or nil if the TimeCodes are equal
    /// - Precondition: base > 1
    public func mostSignificantDifferingDigitPosition(from other: TimeCode, base: Int) -> Int? {
        precondition(base > 1, "Base must be greater than 1")
        
        if value == other.value {
            return nil
        }
        
        let maxDigits = max(digitCount(base: base), other.digitCount(base: base))
        for position in (0..<maxDigits).reversed() {
            if digit(at: position, base: base) != other.digit(at: position, base: base) {
                return position
            }
        }
        return nil
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
