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

    private init(sortedSet: SortedSet<TimeCode>) {
        self.timeCodes = sortedSet
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

    private func applying(_ mutation: (inout SortedSet<TimeCode>) -> Void) -> BackupTree {
        var copy = timeCodes
        mutation(&copy)
        return BackupTree(sortedSet: copy)
    }

    /// Adds a new backup to the tree, maintaining the sorted order.
    public func adding(_ backup: TimeCode) -> BackupTree {
        applying { $0.insert(backup) }
    }

    /// Returns a new BackupTree containing the union of this tree and another.
    public func union(_ other: BackupTree) -> BackupTree {
        applying { $0.formUnion(other.timeCodes) }
    }

    /// Returns a new BackupTree containing the intersection of this tree and another.
    public func intersection(_ other: BackupTree) -> BackupTree {
        applying { $0.formIntersection(other.timeCodes) }
    }

    /// Returns a new BackupTree containing the difference between this tree and another.
    public func subtracting(_ other: BackupTree) -> BackupTree {
        applying { $0.subtract(other.timeCodes) }
    }

    /// Returns a new BackupTree containing the symmetric difference between this tree and another.
    public func symmetricDifference(_ other: BackupTree) -> BackupTree {
        applying { $0.formSymmetricDifference(other.timeCodes) }
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
}

// MARK: - Pruning

extension BackupTree {
    /// Computes the priority key for a backup age, used to rank backups for retention.
    ///
    /// The key is a tuple `(reversedValue, tier)` where:
    /// - `tier` is the number of digits in the radix representation of the age
    /// - `reversedValue` is the age's digits reversed and reinterpreted as a number
    ///
    /// Sorting by `(reversedValue, tier)` ascending interleaves across tiers,
    /// ensuring every time scale gets representation before any single tier
    /// consumes the budget.
    ///
    /// - Parameters:
    ///   - age: The age of the backup, in the same units as the timestamps (must be >= 0)
    ///   - radix: The radix for digit extraction (must be >= 2)
    /// - Returns: A tuple `(reversedValue, tier)` for sorting
    public static func priorityKey(age: Int, radix: Int) -> (reversedValue: Int, tier: Int) {
        precondition(radix >= 2, "Radix must be at least 2")

        if age <= 0 {
            return (0, 0)
        }

        var tier = 0
        var reversedValue = 0
        var remaining = age
        while remaining > 0 {
            reversedValue = reversedValue * radix + (remaining % radix)
            remaining /= radix
            tier += 1
        }

        return (reversedValue, tier)
    }

    /// Selects which backups to retain using the radix-based priority selection algorithm.
    ///
    /// Ages are computed relative to the most recent backup in the tree, so the
    /// newest item is always at age 0 and always retained (given `keepCount >= 1`).
    /// The result is a pure function of the stored timestamps — no wall-clock time
    /// is consulted.
    ///
    /// - Parameters:
    ///   - radix: Controls how aggressively older backups thin out (>= 2, default 2)
    ///   - keepCount: Maximum number of backups to retain
    /// - Returns: The backups to retain, sorted newest-first
    /// - Precondition: radix >= 2 && keepCount >= 0
    public func retainedBackups(radix: Int, keepCount: Int) -> [TimeCode] {
        precondition(radix >= 2, "Radix must be at least 2")
        precondition(keepCount >= 0, "Keep count must be non-negative")

        guard let maxTs = timeCodes.last, keepCount > 0 else {
            return []
        }

        let keyed = timeCodes.map { ts -> (key: (reversedValue: Int, tier: Int), timeCode: TimeCode) in
            let age = maxTs.value - ts.value
            return (key: Self.priorityKey(age: age, radix: radix), timeCode: ts)
        }
        let ranked = keyed.sorted { a, b in
            if a.key.reversedValue != b.key.reversedValue {
                return a.key.reversedValue < b.key.reversedValue
            }
            return a.key.tier < b.key.tier
        }

        let kept = ranked.prefix(keepCount).map { $0.timeCode }

        return kept.sorted { $0.value > $1.value }
    }
}
