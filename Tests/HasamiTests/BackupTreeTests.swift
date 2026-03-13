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
        // Age 1: digits [1], tier 1, reversed = 1
        let k1 = BackupTree.priorityKey(age: 1, radix: 2)
        #expect(k1 == (1, 1))

        // Age 2: binary "10" → digits [0, 1], tier 2
        // reversed: rv=0, rv=0*2+0=0, rv=0*2+1=1
        let k2 = BackupTree.priorityKey(age: 2, radix: 2)
        #expect(k2 == (1, 2))

        // Age 3: binary "11" → digits [1, 1], tier 2, reversed = 1*2+1 = 3
        let k3 = BackupTree.priorityKey(age: 3, radix: 2)
        #expect(k3 == (3, 2))

        // Age 4: binary "100" → digits [0, 0, 1], tier 3, reversed = 1
        let k4 = BackupTree.priorityKey(age: 4, radix: 2)
        #expect(k4 == (1, 3))

        // Age 8: binary "1000" → digits [0, 0, 0, 1], tier 4, reversed = 1
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
        let result = tree.retainedBackups(now: TimeCode(value: 100), radix: 2, slotDuration: 1, keepCount: 10)
        #expect(result.isEmpty)
    }

    @Test func testKeepCountZero() {
        let tree = BackupTree(1, 2, 3)
        let result = tree.retainedBackups(now: TimeCode(value: 100), radix: 2, slotDuration: 1, keepCount: 0)
        #expect(result.isEmpty)
    }

    @Test func testFewerBackupsThanKeepCount() {
        let tree = BackupTree(90, 95, 100)
        let result = tree.retainedBackups(now: TimeCode(value: 100), radix: 2, slotDuration: 1, keepCount: 10)
        #expect(result.count == 3)
        #expect(Set(result) == Set([TimeCode(value: 90), TimeCode(value: 95), TimeCode(value: 100)]))
    }

    @Test func testMostRecentAlwaysRetained() {
        let now = TimeCode(value: 1000)
        let tree = BackupTree(timeCodes: (900...1000).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 1)
        #expect(result == [TimeCode(value: 1000)])
    }

    @Test func testDeduplication() {
        // With slot_duration=10, backups at 91 and 95 both map to age slot 0
        // (ages 5 and 9, both / 10 = 0). Only the more recent (95) should survive.
        let now = TimeCode(value: 100)
        let tree = BackupTree(91, 95)
        let result = tree.retainedBackups(now: now, radix: 2, slotDuration: 10, keepCount: 10)
        #expect(result == [TimeCode(value: 95)])
    }

    @Test func testDeterminism() {
        let now = TimeCode(value: 1000)
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let r1 = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 20)
        let r2 = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 20)
        #expect(r1 == r2)
    }

    @Test func testRetainedCountMatchesKeepCount() {
        let now = TimeCode(value: 200)
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 20)
        #expect(result.count == 20)
    }

    @Test func testResultSortedNewestFirst() {
        let now = TimeCode(value: 200)
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 20)
        for i in 0..<(result.count - 1) {
            #expect(result[i].value >= result[i + 1].value)
        }
    }

    @Test func testSpecExample() {
        // From the spec: 180 daily backups, radix 2, keep 20
        // Expected ages: 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128, 160
        let now = TimeCode(value: 181)
        let tree = BackupTree(timeCodes: (1...180).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 20)

        let expectedAges = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128, 160]
        let expectedTimeCodes = expectedAges.map { TimeCode(value: now.value - $0) }
        #expect(result == expectedTimeCodes)
    }

    @Test func testGapsGrowGeometrically() {
        let now = TimeCode(value: 500)
        let tree = BackupTree(timeCodes: (1...400).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 20)

        // Compute ages and gaps
        let ages = result.map { now.value - $0.value }
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
        let now = TimeCode(value: 500)
        let tree = BackupTree(timeCodes: (1...400).map { TimeCode(value: $0) })
        let result = tree.retainedBackups(now: now, radix: 3, slotDuration: 1, keepCount: 15)

        #expect(result.count == 15)
        for i in 0..<(result.count - 1) {
            #expect(result[i].value >= result[i + 1].value)
        }
    }

    @Test func testSlotDurationAffectsDeduplication() {
        let now = TimeCode(value: 100)
        let tree = BackupTree(timeCodes: (90...99).map { TimeCode(value: $0) })

        // With slot_duration=1, all 10 are distinct
        let r1 = tree.retainedBackups(now: now, radix: 2, slotDuration: 1, keepCount: 100)
        #expect(r1.count == 10)

        // With slot_duration=5, they collapse into fewer slots
        let r2 = tree.retainedBackups(now: now, radix: 2, slotDuration: 5, keepCount: 100)
        #expect(r2.count < 10)
    }
}
