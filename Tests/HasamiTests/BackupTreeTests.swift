import Foundation
import Testing
import Hasami

struct BackupTreeTests {
    @Test func testBackupTreeCreation() {
        let tree = BackupTree(3, 1, 2)

        #expect(tree.backups == [1, 2, 3])
        #expect(tree.count == 3)
        #expect(tree.oldest == 1)
        #expect(tree.mostRecent == 3)
    }

    @Test func testSetOperations() {
        let tree1 = BackupTree(1, 2, 3)
        let tree2 = BackupTree(2, 3, 4)

        #expect(tree1.union(tree2).backups == [1, 2, 3, 4])
        #expect(tree1.intersection(tree2).backups == [2, 3])
        #expect(tree1.subtracting(tree2).backups == [1])
        #expect(tree1.symmetricDifference(tree2).backups == [1, 4])
    }

    @Test func testSetPredicates() {
        let tree1 = BackupTree(1, 2, 3)
        let tree3 = BackupTree(1, 2)
        let tree4 = BackupTree(1, 2, 3, 4)

        #expect(tree1.isSubset(of: tree1))
        #expect(tree3.isSubset(of: tree1))
        #expect(tree1.isSubset(of: tree4))
        #expect(!tree1.isSubset(of: tree3))

        #expect(!tree1.isStrictSubset(of: tree1))
        #expect(tree3.isStrictSubset(of: tree1))
    }

    @Test func testAdding() {
        let tree = BackupTree(1, 2, 3)
        let newTree = tree.adding(4)

        #expect(newTree.backups == [1, 2, 3, 4])
        #expect(tree.backups == [1, 2, 3]) // original unchanged
    }

    // MARK: - Pruning Algorithm Tests

    @Test func testEmptyTree() {
        let tree = BackupTree()
        #expect(tree.retainedBackups(halfLife: 10, keepCount: 10).isEmpty)
        #expect(tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 10).isEmpty)
    }

    @Test func testKeepCountZero() {
        let tree = BackupTree(1, 2, 3)
        #expect(tree.retainedBackups(halfLife: 10, keepCount: 0).isEmpty)
        #expect(tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 0).isEmpty)
    }

    @Test func testFewerBackupsThanKeepCount() {
        // When there are no more backups than keepCount, everything is retained,
        // sorted newest-first.
        let tree = BackupTree(90, 95, 100)
        let result = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 10)
        #expect(result == [TimeCode(value: 100), TimeCode(value: 95), TimeCode(value: 90)])
    }

    @Test func testKeepCountEqualToCountReturnsAll() {
        let tree = BackupTree(timeCodes: (1...20).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20)
        #expect(result.count == 20)
        #expect(Set(result) == Set((1...20).map { TimeCode(value: $0) }))
    }

    @Test func testKeepCountOneReturnsNewest() {
        let tree = BackupTree(timeCodes: (900...1000).map { TimeCode(value: $0) })
        #expect(tree.retainedBackups(halfLife: 10, keepCount: 1) == [TimeCode(value: 1000)])
        #expect(tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 1) == [TimeCode(value: 1000)])
    }

    @Test func testNewestAndOldestPinned() {
        // With keepCount >= 2, the retained set always spans the full history.
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20)
        #expect(result.first == TimeCode(value: 180))  // newest, sorted first
        #expect(result.last == TimeCode(value: 1))     // oldest, sorted last
    }

    @Test func testDeterminism() {
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let r1 = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20)
        let r2 = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20)
        #expect(r1 == r2)
    }

    @Test func testRetainedCountMatchesKeepCount() {
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        #expect(tree.retainedBackups(halfLife: 30, keepCount: 20).count == 20)
        #expect(tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20).count == 20)
    }

    @Test func testResultSortedNewestFirst() {
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20)
        for i in 0..<(result.count - 1) {
            #expect(result[i].value > result[i + 1].value)
        }
    }

    @Test func testRecentBackupsAreDenserThanOld() {
        // Fitting an exponential-decay curve means retained backups cluster near
        // the newest end: the gap between the two newest retained backups must be
        // no larger than the gap between the two oldest.
        let tree = BackupTree(timeCodes: (1...400).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20)

        // result is newest-first; ages increase as we go toward the end.
        let ages = result.map { result[0].value - $0.value }
        let newestGap = ages[1] - ages[0]
        let oldestGap = ages[ages.count - 1] - ages[ages.count - 2]
        #expect(newestGap <= oldestGap)
    }

    @Test func testExtremeDivisorDoesNotCrash() {
        // A tiny --half-lives makes span/k overflow to infinity; the relative
        // method must clamp gracefully rather than trip the half-life precondition.
        let tree = BackupTree(timeCodes: (1...50).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(halfLivesAcrossSpan: 1e-310, keepCount: 20)
        #expect(result.count == 20)
        #expect(result.first == TimeCode(value: 50))  // newest still pinned
        #expect(result.last == TimeCode(value: 1))     // oldest still pinned
    }

    @Test func testAbsoluteEqualsRelativeWhenHalfLifeMatchesSpan() {
        // The relative entry point is just the absolute one with H = span / k.
        let tree = BackupTree(timeCodes: (1...400).map { TimeCode(value: $0) })
        let span = 400.0 - 1.0
        let k = 4.0
        let absolute = tree.retainedBackups(halfLife: span / k, keepCount: 15)
        let relative = tree.retainedBackups(halfLivesAcrossSpan: k, keepCount: 15)
        #expect(absolute == relative)
    }

    @Test func testRetentionInvariantToInputOrder() {
        // Regression for issue #5: the retention set depends only on the input
        // set, never on wall-clock time or insertion order.
        let timestamps = [1000, 1001, 1002, 2000, 3500, 7000]
        let ascending = BackupTree(timeCodes: timestamps.sorted().map { TimeCode(value: $0) })
        let descending = BackupTree(timeCodes: timestamps.sorted(by: >).map { TimeCode(value: $0) })
        let r1 = ascending.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 3)
        let r2 = descending.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 3)
        #expect(r1 == r2)
        // The newest timestamp must always be retained.
        #expect(r1.contains(TimeCode(value: 7000)))
    }

    @Test func testCharacterizationEvenlySpaced() {
        // Golden test: 180 evenly-spaced backups (ts 1...180), keep 20, half-life
        // = span/4. Locks in the exact retained set produced by the greedy thinner.
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(halfLivesAcrossSpan: 4, keepCount: 20)
        let expectedAges = CHARACTERIZATION_AGES_180_20
        let newest = 180
        #expect(result == expectedAges.map { TimeCode(value: newest - $0) })
    }
}

// Filled in from the algorithm's actual output; see testCharacterizationEvenlySpaced.
// Gaps grow with age (3, 4×8, 8×6, 16×2, 32×2 — 19 gaps), fitting the exponential-decay curve.
private let CHARACTERIZATION_AGES_180_20: [Int] = [
    0, 3, 7, 11, 15, 19, 23, 27, 31, 35, 43, 51, 59, 67, 75, 83, 99, 115, 147, 179,
]
