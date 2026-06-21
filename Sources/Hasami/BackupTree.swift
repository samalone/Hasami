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
    /// Selects which backups to retain so the retained set follows an
    /// exponential-decay retention curve: the density of retained backups halves
    /// for every `halfLife` of additional age.
    ///
    /// The algorithm warps each backup's age (measured from the newest backup in
    /// the tree) into a CDF coordinate `u(age) = 1 - 2^(-age / halfLife)`, in which
    /// the target retention density is uniform. It then greedily removes the most
    /// redundant backup — the one whose removal merges the smallest `u`-gap —
    /// until only `keepCount` remain. The newest and oldest backups are always
    /// retained (when `keepCount >= 2`), so the retained set always spans the full
    /// history.
    ///
    /// Ages are measured relative to the most recent backup in the tree, so the
    /// result is a pure function of the stored timestamps: no wall-clock time is
    /// consulted, and re-running on an unchanged set is a no-op.
    ///
    /// - Parameters:
    ///   - halfLife: The age over which retention density halves, in the same
    ///     units as the timestamps (seconds). Must be > 0.
    ///   - keepCount: Maximum number of backups to retain (>= 0).
    /// - Returns: The backups to retain, sorted newest-first.
    public func retainedBackups(halfLife: Double, keepCount: Int) -> [TimeCode] {
        precondition(halfLife > 0, "Half-life must be positive")
        precondition(keepCount >= 0, "Keep count must be non-negative")
        return thinned(halfLife: halfLife, keepCount: keepCount)
    }

    /// Selects which backups to retain using a half-life expressed as a fraction
    /// of the tree's total history span.
    ///
    /// The absolute half-life is computed as `span / halfLivesAcrossSpan`, where
    /// `span` is the difference between the newest and oldest timestamps. This
    /// makes the retained shape scale-free: it is identical whether the history
    /// covers a week or a decade. Delegates to ``retainedBackups(halfLife:keepCount:)``.
    ///
    /// - Parameters:
    ///   - halfLivesAcrossSpan: How many half-lives fit across the full history
    ///     span. Must be > 0.
    ///   - keepCount: Maximum number of backups to retain (>= 0).
    /// - Returns: The backups to retain, sorted newest-first.
    public func retainedBackups(halfLivesAcrossSpan: Double, keepCount: Int) -> [TimeCode] {
        precondition(halfLivesAcrossSpan > 0, "Half-lives across span must be positive")
        precondition(keepCount >= 0, "Keep count must be non-negative")

        guard let newest = timeCodes.last, let oldest = timeCodes.first else {
            return []
        }
        let span = newest.value - oldest.value
        guard span > 0 else {
            // All timestamps identical (degenerate); the count guard in `thinned`
            // returns everything, so the half-life value is irrelevant.
            return thinned(halfLife: 1, keepCount: keepCount)
        }
        return thinned(halfLife: Double(span) / halfLivesAcrossSpan, keepCount: keepCount)
    }

    /// Core CDF-warp greedy thinner. Assumes `halfLife > 0` and `keepCount >= 0`.
    private func thinned(halfLife: Double, keepCount: Int) -> [TimeCode] {
        let points = Array(timeCodes)            // ascending: oldest -> newest
        let n = points.count

        guard keepCount > 0, n > 0 else { return [] }
        if n <= keepCount { return Array(points.reversed()) }   // keep all, newest-first
        if keepCount == 1 { return [points[n - 1]] }            // newest only

        // Warp each age (relative to the newest) into u = 1 - 2^(-age / H).
        // u is non-decreasing along `points`; the newest has u = 0.
        let newest = points[n - 1].value
        let u = points.map { 1.0 - pow(2.0, -Double(newest - $0.value) / halfLife) }

        // Survivors form a doubly-linked sequence over indices 0..<n. The
        // endpoints (0 = oldest, n-1 = newest) are pinned; only interior points
        // are removal candidates. Removing interior point i merges the gap left by
        // its neighbors, costing u[next] - u[prev].
        var prev = (0..<n).map { $0 - 1 }
        var next = (0..<n).map { $0 + 1 }
        var alive = Array(repeating: true, count: n)
        var version = Array(repeating: 0, count: n)  // for lazy heap invalidation
        var survivors = n

        // The merge cost is the u-distance between i's neighbors. `u` is monotonic
        // along the array, so `abs` makes this independent of array orientation.
        func cost(_ i: Int) -> Double { abs(u[next[i]] - u[prev[i]]) }

        // Min-heap of (cost, index, version), smallest cost first; ties broken by
        // index so the result is deterministic and invariant to input order.
        var heap: [(cost: Double, index: Int, version: Int)] = []
        heap.reserveCapacity(n)
        func ordered(_ a: (cost: Double, index: Int, version: Int),
                     _ b: (cost: Double, index: Int, version: Int)) -> Bool {
            a.cost != b.cost ? a.cost < b.cost : a.index < b.index
        }
        func push(_ i: Int) {
            heap.append((cost: cost(i), index: i, version: version[i]))
            var c = heap.count - 1
            while c > 0 {
                let p = (c - 1) / 2
                if ordered(heap[c], heap[p]) { heap.swapAt(c, p); c = p } else { break }
            }
        }
        func pop() -> (cost: Double, index: Int, version: Int)? {
            guard let top = heap.first else { return nil }
            let last = heap.removeLast()
            if !heap.isEmpty {
                heap[0] = last
                var c = 0
                while true {
                    let l = 2 * c + 1, r = 2 * c + 2
                    var m = c
                    if l < heap.count, ordered(heap[l], heap[m]) { m = l }
                    if r < heap.count, ordered(heap[r], heap[m]) { m = r }
                    if m == c { break }
                    heap.swapAt(c, m); c = m
                }
            }
            return top
        }

        for i in 1..<(n - 1) { push(i) }

        while survivors > keepCount, let top = pop() {
            let i = top.index
            // Skip superseded (stale) heap entries.
            guard alive[i], top.version == version[i] else { continue }

            alive[i] = false
            survivors -= 1
            let p = prev[i], q = next[i]
            next[p] = q
            prev[q] = p
            // Re-cost the interior neighbors; endpoints are pinned and never pushed.
            if p > 0, p < n - 1 { version[p] += 1; push(p) }
            if q > 0, q < n - 1 { version[q] += 1; push(q) }
        }

        var kept: [TimeCode] = []
        kept.reserveCapacity(survivors)
        for i in (0..<n).reversed() where alive[i] { kept.append(points[i]) }  // newest-first
        return kept
    }
}
