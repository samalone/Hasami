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

    // MARK: - Priority Key Tests

    @Test func testPriorityKeyAge0() {
        let key = BackupTree.priorityKey(age: 0, radix: 2)
        #expect(key.reversedValue == 0)
        #expect(key.tier == 0)
    }

    @Test func testPriorityKeyBase2() {
        let k1 = BackupTree.priorityKey(age: 1, radix: 2)
        #expect(k1 == (1, 1))

        let k2 = BackupTree.priorityKey(age: 2, radix: 2)
        #expect(k2 == (1, 2))

        let k3 = BackupTree.priorityKey(age: 3, radix: 2)
        #expect(k3 == (3, 2))

        let k4 = BackupTree.priorityKey(age: 4, radix: 2)
        #expect(k4 == (1, 3))

        let k8 = BackupTree.priorityKey(age: 8, radix: 2)
        #expect(k8 == (1, 4))
    }

    @Test func testPriorityKeyTier4Ordering() {
        // From the spec: tier 4 (ages 8–15), priority order is 8, 12, 10, 14, 9, 13, 11, 15
        let ages = Array(8...15)
        let sorted = ages.sorted { a, b in
            let ka = BackupTree.priorityKey(age: a, radix: 2)
            let kb = BackupTree.priorityKey(age: b, radix: 2)
            if ka.reversedValue != kb.reversedValue { return ka.reversedValue < kb.reversedValue }
            return ka.tier < kb.tier
        }
        #expect(sorted == [8, 12, 10, 14, 9, 13, 11, 15])
    }

    // MARK: - Pruning Algorithm Tests

    @Test func testEmptyTree() {
        let tree = BackupTree()
        let result = tree.retainedBackups(radix: 2, keepCount: 10)
        #expect(result.isEmpty)
    }

    @Test func testKeepCountZero() {
        let tree = BackupTree(1, 2, 3)
        let result = tree.retainedBackups(radix: 2, keepCount: 0)
        #expect(result.isEmpty)
    }

    @Test func testFewerBackupsThanKeepCount() {
        let tree = BackupTree(90, 95, 100)
        let result = tree.retainedBackups(radix: 2, keepCount: 10)
        #expect(result.count == 3)
        #expect(Set(result) == Set([TimeCode(value: 90), TimeCode(value: 95), TimeCode(value: 100)]))
    }

    @Test func testMostRecentAlwaysRetained() {
        // Ages are measured from the newest timestamp, so the newest always has
        // priority key (0, 0) and is always picked first.
        let tree = BackupTree(timeCodes: (900...1000).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(radix: 2, keepCount: 1)
        #expect(result == [TimeCode(value: 1000)])
    }

    @Test func testDeterminism() {
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let r1 = tree.retainedBackups(radix: 2, keepCount: 20)
        let r2 = tree.retainedBackups(radix: 2, keepCount: 20)
        #expect(r1 == r2)
    }

    @Test func testRetainedCountMatchesKeepCount() {
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(radix: 2, keepCount: 20)
        #expect(result.count == 20)
    }

    @Test func testResultSortedNewestFirst() {
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(radix: 2, keepCount: 20)
        for i in 0..<(result.count - 1) {
            #expect(result[i].value >= result[i + 1].value)
        }
    }

    @Test func testSpecExample() {
        // 180 daily backups (ts=1..180), radix 2, keep 20. Ages are computed
        // relative to the newest timestamp (180), so expected ages start at 0.
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(radix: 2, keepCount: 20)

        let expectedAges = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128]
        let maxTs = 180
        let expectedTimeCodes = expectedAges.map { TimeCode(value: maxTs - $0) }
        #expect(result == expectedTimeCodes)
    }

    @Test func testGapsGrowGeometrically() {
        let tree = BackupTree(timeCodes: (1...400).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(radix: 2, keepCount: 20)

        // Compute ages (relative to newest) and gaps
        let maxTs = result.first!.value
        let ages = result.map { maxTs - $0.value }
        var gaps: [Int] = []
        for i in 0..<(ages.count - 1) {
            gaps.append(ages[i + 1] - ages[i])
        }

        // Gaps should be non-decreasing
        for i in 0..<(gaps.count - 1) {
            #expect(gaps[i] <= gaps[i + 1], "Gap at index \(i) (\(gaps[i])) should be <= gap at index \(i + 1) (\(gaps[i + 1]))")
        }
    }

    @Test func testRadix3() {
        let tree = BackupTree(timeCodes: (1...400).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(radix: 3, keepCount: 15)

        #expect(result.count == 15)
        for i in 0..<(result.count - 1) {
            #expect(result[i].value >= result[i + 1].value)
        }
    }

    @Test func testRetentionInvariantToInputOrder() {
        // Regression for issue #5: the retention set depends only on the input
        // set, never on wall-clock time or anything else external.
        let timestamps = [1000, 1001, 1002, 2000, 3500, 7000]
        let ascending = BackupTree(timeCodes: timestamps.sorted().map { TimeCode(value: $0) })
        let descending = BackupTree(timeCodes: timestamps.sorted(by: >).map { TimeCode(value: $0) })
        let r1 = ascending.retainedBackups(radix: 2, keepCount: 3)
        let r2 = descending.retainedBackups(radix: 2, keepCount: 3)
        #expect(r1 == r2)
        // The newest timestamp must always be retained.
        #expect(r1.contains(TimeCode(value: 7000)))
    }
}
