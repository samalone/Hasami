import Foundation
import SortedCollections

/// A sorted collection of TimeCodes representing backups.
/// The backups are sorted in ascending order (oldest to newest).
public struct BackupTree: Equatable {
    private var timeCodes: SortedSet<TimeCode>
    
    /// Creates a new BackupTree with the given TimeCodes.
    /// - Parameter timeCodes: The TimeCodes to include in the tree
    public init(timeCodes: [TimeCode]) {
        self.timeCodes = SortedSet(timeCodes)
    }

    /// Creates a new BackupTree with the given TimeCodes.
    /// - Parameter timeCodes: The TimeCodes to include in the tree
    public init(_ timeCodes: TimeCode...) {
        self.timeCodes = SortedSet(timeCodes)
    }
    
    /// Returns the TimeCodes in the tree.
    public var backups: [TimeCode] {
        return Array(timeCodes)
    }
    
    /// Returns the number of backups in the tree.
    public var count: Int {
        return timeCodes.count
    }
    
    /// Returns the most recent backup in the tree, or nil if the tree is empty.
    public var mostRecent: TimeCode? {
        return timeCodes.last
    }
    
    /// Returns the oldest backup in the tree, or nil if the tree is empty.
    public var oldest: TimeCode? {
        return timeCodes.first
    }
    
    /// Adds a new backup to the tree, maintaining the sorted order.
    /// - Parameter backup: The TimeCode to add
    /// - Returns: A new BackupTree with the added backup
    public func adding(_ backup: TimeCode) -> BackupTree {
        var newTimeCodes = timeCodes
        newTimeCodes.insert(backup)
        return BackupTree(timeCodes: Array(newTimeCodes))
    }
    
    /// Returns a new BackupTree containing the union of this tree and another.
    /// - Parameter other: The other BackupTree to union with
    /// - Returns: A new BackupTree containing all backups from both trees
    public func union(_ other: BackupTree) -> BackupTree {
        var newTimeCodes = timeCodes
        newTimeCodes.formUnion(other.timeCodes)
        return BackupTree(timeCodes: Array(newTimeCodes))
    }
    
    /// Returns a new BackupTree containing the intersection of this tree and another.
    /// - Parameter other: The other BackupTree to intersect with
    /// - Returns: A new BackupTree containing only backups present in both trees
    public func intersection(_ other: BackupTree) -> BackupTree {
        var newTimeCodes = timeCodes
        newTimeCodes.formIntersection(other.timeCodes)
        return BackupTree(timeCodes: Array(newTimeCodes))
    }
    
    /// Returns a new BackupTree containing the difference between this tree and another.
    /// - Parameter other: The other BackupTree to subtract
    /// - Returns: A new BackupTree containing only backups not present in the other tree
    public func subtracting(_ other: BackupTree) -> BackupTree {
        var newTimeCodes = timeCodes
        newTimeCodes.subtract(other.timeCodes)
        return BackupTree(timeCodes: Array(newTimeCodes))
    }
    
    /// Returns a new BackupTree containing the symmetric difference between this tree and another.
    /// - Parameter other: The other BackupTree to compare with
    /// - Returns: A new BackupTree containing only backups present in exactly one tree
    public func symmetricDifference(_ other: BackupTree) -> BackupTree {
        var newTimeCodes = timeCodes
        newTimeCodes.formSymmetricDifference(other.timeCodes)
        return BackupTree(timeCodes: Array(newTimeCodes))
    }
    
    /// Returns true if this tree is a subset of another tree.
    /// - Parameter other: The other BackupTree to compare with
    /// - Returns: True if all backups in this tree are also in the other tree
    public func isSubset(of other: BackupTree) -> Bool {
        return timeCodes.isSubset(of: other.timeCodes)
    }
    
    /// Returns true if this tree is a strict subset of another tree.
    /// - Parameter other: The other BackupTree to compare with
    /// - Returns: True if all backups in this tree are also in the other tree, and the other tree has at least one additional backup
    public func isStrictSubset(of other: BackupTree) -> Bool {
        return timeCodes.isStrictSubset(of: other.timeCodes)
    }
    
    /// Returns a string representation of this tree in the given base.
    /// The backups are displayed in reverse chronological order (most recent first),
    /// with each backup on its own line. All backups are displayed with the same
    /// number of digits, determined by the most recent backup.
    /// - Parameter base: The base to use for the string representation
    /// - Returns: A string representation of the tree
    /// - Precondition: base > 1
    public func description(base: Int) -> String {
        precondition(base > 1, "Base must be greater than 1")
        
        guard let mostRecent = mostRecent else {
            return ""
        }
        
        let digitCount = mostRecent.digitCount(base: base)
        let backups = Array(timeCodes.reversed())
        
        return backups.map { timeCode in
            let digits = String(timeCode.value, radix: base)
            return String(repeating: "0", count: digitCount - digits.count) + digits
        }.joined(separator: "\n")
    }
    
    /// Returns a string representation of the differences between this tree and another.
    /// The output shows the union of both trees in reverse chronological order,
    /// with each line prefixed by:
    /// - "+ " if the TimeCode is only in the other tree
    /// - "- " if the TimeCode is only in this tree
    /// - "  " if the TimeCode is in both trees
    /// - Parameter other: The other BackupTree to compare with
    /// - Parameter base: The base to use for the string representation
    /// - Returns: A string representation of the differences
    /// - Precondition: base > 1
    public func diff(_ other: BackupTree, base: Int) -> String {
        precondition(base > 1, "Base must be greater than 1")
        
        let union = self.union(other)
        guard let mostRecent = union.mostRecent else {
            return ""
        }
        
        let digitCount = mostRecent.digitCount(base: base)
        let backups = Array(union.timeCodes.reversed())
        
        return backups.map { timeCode in
            let digits = String(timeCode.value, radix: base)
            let paddedDigits = String(repeating: "0", count: digitCount - digits.count) + digits
            
            if self.timeCodes.contains(timeCode) {
                if other.timeCodes.contains(timeCode) {
                    return "  " + paddedDigits
                } else {
                    return "- " + paddedDigits
                }
            } else {
                return "+ " + paddedDigits
            }
        }.joined(separator: "\n")
    }
}

// MARK: - Pruning Properties
extension BackupTree {
    /// Determines how many backups to retain for a subtree based on its digit.
    /// - Parameters:
    ///   - available: The number of backups available to allocate
    ///   - base: The base of the number system
    ///   - digit: The digit of the subtree (0 ..< base)
    /// - Returns: The number of backups to allocate to this subtree
    private func allocateBackups(available: Int, base: Int, digit: Int) -> Int {
        precondition(available >= 0, "Available backups must be non-negative")
        precondition(base > 1, "Base must be greater than 1")
        precondition(digit >= 0 && digit < base, "Digit must be in range 0..<base")
        
        if available == 0 {
            return 0
        }
        
        // Use a geometric distribution where each digit gets a fraction of the remaining backups
        // Higher digits (more recent backups) get more allocations
        let weight = base - digit
        let totalWeight = base * (base + 1) / 2  // Sum of weights from 1 to base
        let allocation = Int((Double(available) * Double(weight)) / Double(totalWeight))
        
        // Ensure at least one backup is allocated if any are available
        return max(1, allocation)
    }
    
    /// Returns the backups that should be retained according to the pruning algorithm.
    /// - Parameters:
    ///   - base: The base of the number system to use for pruning
    ///   - retain: The number of backups to retain
    /// - Returns: An array of TimeCodes that should be retained
    /// - Precondition: base > 1 && retain > 0
    public func retainedBackups(base: Int, retain: Int) -> [TimeCode] {
        precondition(base > 1, "Base must be greater than 1")
        precondition(retain > 0, "Must retain at least one backup")
        
        guard let oldest = oldest, let mostRecent = mostRecent else {
            return []
        }
        
        // Find the most significant digit that varies between oldest and most recent
        guard let msdPosition = oldest.mostSignificantDifferingDigitPosition(from: mostRecent, base: base) else {
            // If there are no differing digits, return just the most recent backup
            return [mostRecent]
        }
        
        // Start with the most recent backup
        var retained: [TimeCode] = [mostRecent]
        var remainingToRetain = retain - 1
        
        // If we've already reached our retain count, return what we have
        if remainingToRetain == 0 {
            return retained
        }
        
        // Group backups by their digit at the current position
        var digitGroups: [Int: [TimeCode]] = [:]
        for timeCode in timeCodes {
            if timeCode != mostRecent {  // Skip the most recent backup as it's already included
                let digit = timeCode.digit(at: msdPosition, base: base)
                digitGroups[digit, default: []].append(timeCode)
            }
        }
        
        // Sort digits in descending order (most recent first)
        let sortedDigits = digitGroups.keys.sorted(by: >)
        
        // Allocate backups to each digit group
        for digit in sortedDigits {
            let allocation = allocateBackups(available: remainingToRetain, base: base, digit: digit)
            if allocation > 0 {
                let group = digitGroups[digit]!
                let subtree = BackupTree(timeCodes: group)
                let subtreeRetained = subtree.retainedBackups(base: base, retain: allocation)
                retained.append(contentsOf: subtreeRetained)
                remainingToRetain -= subtreeRetained.count
                
                if remainingToRetain == 0 {
                    break
                }
            }
        }
        
        return retained
    }
    
    /// Returns true if the given TimeCode would be retained by the pruning algorithm.
    /// - Parameters:
    ///   - timeCode: The TimeCode to check
    ///   - base: The base of the number system to use for pruning
    ///   - retain: The number of backups to retain
    /// - Returns: True if the TimeCode would be retained
    /// - Precondition: base > 1 && retain > 0
    public func wouldRetain(_ timeCode: TimeCode, base: Int, retain: Int) -> Bool {
        return retainedBackups(base: base, retain: retain).contains(timeCode)
    }
    
    /// Returns true if the given integer value would be retained by the pruning algorithm.
    /// - Parameters:
    ///   - value: The integer value to check
    ///   - base: The base of the number system to use for pruning
    ///   - retain: The number of backups to retain
    /// - Returns: True if the value would be retained
    /// - Precondition: base > 1 && retain > 0
    public func wouldRetain(_ value: Int, base: Int, retain: Int) -> Bool {
        return wouldRetain(TimeCode(value: value), base: base, retain: retain)
    }
}
