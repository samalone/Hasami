import Foundation

/// A representation of a number in a specific base, where each digit represents a time unit.
/// This is used as a fundamental building block for the backup pruning algorithm.
public struct TimeCode {
    /// The value represented by this TimeCode
    public let value: Int

    /// Creates a new TimeCode with the given value.
    /// - Parameter value: The integer value to represent
    public init(value: Int) {
        self.value = value
    }
    
    /// Creates a new TimeCode from a Date, representing the number of seconds since the Unix epoch.
    /// - Parameter date: The date to convert to a TimeCode
    public init(date: Date) {
        self.value = Int(date.timeIntervalSince1970)
    }

    /// Returns the digit at the specified position (0-based, from least significant to most significant).
    /// - Parameters:
    ///   - position: The position of the digit to retrieve
    ///   - base: The base of the number system (must be greater than 1)
    /// - Returns: The digit at the specified position
    /// - Precondition: base > 1
    public func digit(at position: Int, base: Int) -> Int {
        precondition(base > 1, "Base must be greater than 1")
        let absValue = abs(value)
        var divisor = 1
        for _ in 0..<position {
            divisor *= base
        }
        return (absValue / divisor) % base
    }

    /// Returns the number of digits in this TimeCode for the given base.
    /// - Parameter base: The base of the number system (must be greater than 1)
    /// - Returns: The number of digits
    /// - Precondition: base > 1
    public func digitCount(base: Int) -> Int {
        precondition(base > 1, "Base must be greater than 1")
        if value == 0 {
            return 1
        }
        var absValue = abs(value)
        var count = 0
        while absValue > 0 {
            absValue /= base
            count += 1
        }
        return count
    }
    
    /// Returns the position of the most significant digit where this TimeCode differs from another TimeCode.
    /// - Parameters:
    ///   - other: The TimeCode to compare against
    ///   - base: The base to use for digit comparison
    /// - Returns: The 0-based position of the most significant differing digit, or nil if the TimeCodes are identical
    /// - Precondition: base > 1
    public func mostSignificantDifferingDigitPosition(from other: TimeCode, base: Int) -> Int? {
        precondition(base > 1, "Base must be greater than 1")
        
        let maxLength = max(self.digitCount(base: base), other.digitCount(base: base))
        
        // Compare from most significant to least significant
        for i in (0..<maxLength).reversed() {
            if self.digit(at: i, base: base) != other.digit(at: i, base: base) {
                return i
            }
        }
        
        return nil // TimeCodes are identical
    }
}

// MARK: - Equatable
extension TimeCode: Equatable {
    public static func == (lhs: TimeCode, rhs: TimeCode) -> Bool {
        return lhs.value == rhs.value
    }
}

// MARK: - CustomStringConvertible
extension TimeCode: CustomStringConvertible {
    public var description: String {
        return "\(value)"
    }
}
