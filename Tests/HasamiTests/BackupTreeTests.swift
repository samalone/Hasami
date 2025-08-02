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
        
        // Test union
        let union = tree1.union(tree2)
        #expect(union.backups == [1, 2, 3, 4])
        
        // Test intersection
        let intersection = tree1.intersection(tree2)
        #expect(intersection.backups == [2, 3])
        
        // Test subtraction
        let subtraction = tree1.subtracting(tree2)
        #expect(subtraction.backups == [1])
        
        // Test symmetric difference
        let symmetricDifference = tree1.symmetricDifference(tree2)
        #expect(symmetricDifference.backups == [1, 4])
    }
    
    @Test func testSetPredicates() {
        let tree1 = BackupTree(1, 2, 3)
        let tree2 = BackupTree(1, 2, 3)
        let tree3 = BackupTree(1, 2)
        let tree4 = BackupTree(1, 2, 3, 4)
        
        // Test equality
        #expect(tree1 == tree2)
        #expect(tree1 != tree3)
        #expect(tree1 != tree4)
        
        // Test subset
        #expect(tree1.isSubset(of: tree1))
        #expect(tree3.isSubset(of: tree1))
        #expect(tree1.isSubset(of: tree4))
        #expect(!tree1.isSubset(of: tree3))
        
        // Test strict subset
        #expect(!tree1.isStrictSubset(of: tree1))
        #expect(tree3.isStrictSubset(of: tree1))
        #expect(tree1.isStrictSubset(of: tree4))
        #expect(!tree1.isStrictSubset(of: tree3))
    }
    
    @Test func testAdding() {
        let tree = BackupTree(1, 2, 3)
        let newTree = tree.adding(4)
        
        #expect(newTree.backups == [1, 2, 3, 4])
        #expect(newTree.count == 4)
        #expect(newTree.mostRecent == 4)
        
        // Original tree should be unchanged
        #expect(tree.backups == [1, 2, 3])
        #expect(tree.count == 3)
    }
    
    @Test func testPruningProperties() {
        // Test case 1: Most recent backup is always retained
        let tree1 = BackupTree(0b100, 0b011, 0b010, 0b001)
        #expect(tree1.wouldRetain(0b100, base: 2, retain: 1))
        #expect(tree1.wouldRetain(0b100, base: 2, retain: 2))
        #expect(tree1.wouldRetain(0b100, base: 2, retain: 4))
        
        // Test case 2: More recent backups are preferred when retain count is limited
        let tree2 = BackupTree(0b100, 0b011, 0b010, 0b001)
        let retained2 = tree2.retainedBackups(base: 2, retain: 2)
        #expect(retained2.contains(TimeCode(value: 0b100))) // Most recent should be retained
        #expect(retained2.count == 2)
        
        // Test case 3: The retention decision is deterministic based on the backup's TimeCode
        let tree3 = BackupTree(0b100, 0b011, 0b010, 0b001)
        let retained3a = tree3.retainedBackups(base: 2, retain: 2)
        let retained3b = tree3.retainedBackups(base: 2, retain: 2)
        #expect(retained3a == retained3b)
        
        // Test case 4: Algorithm works with different bases
        let tree4 = BackupTree(9, 5, 3, 1)
        let retained4 = tree4.retainedBackups(base: 10, retain: 2)
        #expect(retained4.contains(TimeCode(value: 9))) // Most recent should be retained
        #expect(retained4.count == 2)
    }
    
    @Test func testWindowLevels() {
        // Test case 1: Retain 1 backup
        let tree1 = BackupTree(0b100, 0b011, 0b010, 0b001)
        #expect(tree1.retainedBackups(base: 2, retain: 1).count == 1)
        
        // Test case 2: Retain 2 backups
        let tree2 = BackupTree(0b100, 0b011, 0b010, 0b001)
        #expect(tree2.retainedBackups(base: 2, retain: 2).count == 2)
        
        // Test case 3: Retain all backups
        let tree3 = BackupTree(0b100, 0b011, 0b010, 0b001)
        #expect(tree3.retainedBackups(base: 2, retain: 4).count == 4)
    }
    
    @Test func testDescription() {
        // Test case 1: Empty tree
        let tree1 = BackupTree()
        #expect(tree1.description(base: 2) == "")
        
        // Test case 2: Single backup
        let tree2 = BackupTree(5)
        #expect(tree2.description(base: 2) == "101")
        
        // Test case 3: Multiple backups in base 2
        let tree3 = BackupTree(4, 2, 1)
        #expect(tree3.description(base: 2) == """
        100
        010
        001
        """)
        
        // Test case 4: Multiple backups in base 10
        let tree4 = BackupTree(100, 10, 1)
        #expect(tree4.description(base: 10) == """
        100
        010
        001
        """)
        
        // Test case 5: Multiple backups in base 16
        let tree5 = BackupTree(0xFF, 0x0F, 0x01)
        #expect(tree5.description(base: 16) == """
        ff
        0f
        01
        """)
        
        // Test case 6: Zero-padding
        let tree6 = BackupTree(0b1000, 0b0010, 0b0001)
        #expect(tree6.description(base: 2) == """
        1000
        0010
        0001
        """)
    }
    
    @Test func testDiff() {
        // Test case 1: Empty trees
        let tree1 = BackupTree()
        let tree2 = BackupTree()
        #expect(tree1.diff(tree2, base: 2) == "")
        
        // Test case 2: One tree empty
        let tree3 = BackupTree(1, 2, 3)
        let tree4 = BackupTree()
        #expect(tree3.diff(tree4, base: 2) == """
        - 11
        - 10
        - 01
        """)
        
        // Test case 3: Disjoint trees
        let tree5 = BackupTree(1, 2)
        let tree6 = BackupTree(3, 4)
        #expect(tree5.diff(tree6, base: 2) == """
        + 100
        + 011
        - 010
        - 001
        """)
        
        // Test case 4: Overlapping trees
        let tree7 = BackupTree(1, 2, 3)
        let tree8 = BackupTree(2, 3, 4)
        #expect(tree7.diff(tree8, base: 2) == """
        + 100
          011
          010
        - 001
        """)
        
        // Test case 5: Different bases
        let tree9 = BackupTree(1, 2, 3)
        let tree10 = BackupTree(2, 3, 4)
        #expect(tree9.diff(tree10, base: 10) == """
        + 4
          3
          2
        - 1
        """)
    }
    
    // MARK: - Fuzzy Tests for Chronological Consistency
    
    /// Tests that the pruning algorithm maintains chronological consistency.
    /// This ensures that no older pruning removes files that would be retained by a newer pruning
    /// when backups are created in chronological order.
    /// - Parameters:
    ///   - base: The base of the number system to use for pruning
    ///   - retain: The number of backups to retain
    ///   - initialBackups: The number of initial backups to generate
    ///   - subsequentBackups: The number of subsequent backups to generate
    private func testChronologicalConsistency(base: Int, retain: Int, initialBackups: Int, subsequentBackups: Int) {
        // Generate random initial backups in chronological order
        var initialTimeCodes: [TimeCode] = []
        var currentTime = 1000 // Start with a reasonable base time
        
        for _ in 0..<initialBackups {
            // Add some randomness to the time intervals
            let interval = Int.random(in: 1...100)
            currentTime += interval
            initialTimeCodes.append(TimeCode(value: currentTime))
        }
        
        // Create the initial backup tree
        let initialTree = BackupTree(timeCodes: initialTimeCodes)
        
        // Run the pruning algorithm on the initial backups
        let prunedInitial = initialTree.retainedBackups(base: base, retain: retain)
        let prunedTree = BackupTree(timeCodes: prunedInitial)
        
        // Generate subsequent backups that all occur after the initial backups
        var subsequentTimeCodes: [TimeCode] = []
        
        for _ in 0..<subsequentBackups {
            let interval = Int.random(in: 1...100)
            currentTime += interval
            subsequentTimeCodes.append(TimeCode(value: currentTime))
        }
        
        // Test 1: Run pruning on the full set (initial + subsequent)
        let fullTree = initialTree.union(BackupTree(timeCodes: subsequentTimeCodes))
        let fullPruned = fullTree.retainedBackups(base: base, retain: retain)
        
        // Test 2: Run pruning on the pruned initial set + subsequent
        let combinedTree = prunedTree.union(BackupTree(timeCodes: subsequentTimeCodes))
        let combinedPruned = combinedTree.retainedBackups(base: base, retain: retain)
        
        // The two results should be identical
        #expect(fullPruned == combinedPruned, 
                "Chronological consistency violated for base=\(base), retain=\(retain), initial=\(initialBackups), subsequent=\(subsequentBackups)")
    }
    
    @Test func testChronologicalConsistencyFuzzy() {
        // Test with various combinations of parameters
        let testCases = [
            (base: 2, retain: 1, initial: 5, subsequent: 3),
            (base: 2, retain: 2, initial: 8, subsequent: 4),
            (base: 2, retain: 3, initial: 10, subsequent: 5),
            (base: 10, retain: 1, initial: 6, subsequent: 3),
            (base: 10, retain: 2, initial: 9, subsequent: 4),
            (base: 10, retain: 3, initial: 12, subsequent: 6),
            (base: 16, retain: 1, initial: 7, subsequent: 3),
            (base: 16, retain: 2, initial: 10, subsequent: 5),
            (base: 16, retain: 3, initial: 15, subsequent: 7),
        ]
        
        for testCase in testCases {
            testChronologicalConsistency(
                base: testCase.base,
                retain: testCase.retain,
                initialBackups: testCase.initial,
                subsequentBackups: testCase.subsequent
            )
        }
    }
    
    @Test func testChronologicalConsistencyEdgeCases() {
        // Test edge cases that might reveal issues
        let edgeCases = [
            (base: 2, retain: 1, initial: 1, subsequent: 1),   // Minimal case
            (base: 2, retain: 1, initial: 2, subsequent: 1),   // Small initial set
            (base: 10, retain: 1, initial: 1, subsequent: 10), // Many subsequent
            (base: 16, retain: 5, initial: 20, subsequent: 10), // Large retain count
        ]
        
        for edgeCase in edgeCases {
            testChronologicalConsistency(
                base: edgeCase.base,
                retain: edgeCase.retain,
                initialBackups: edgeCase.initial,
                subsequentBackups: edgeCase.subsequent
            )
        }
    }
    
    @Test func testChronologicalConsistencyStress() {
        // Stress test with larger numbers
        let stressTests = [
            (base: 2, retain: 3, initial: 50, subsequent: 25),
            (base: 10, retain: 5, initial: 100, subsequent: 50),
            (base: 16, retain: 7, initial: 200, subsequent: 100),
        ]
        
        for stressTest in stressTests {
            testChronologicalConsistency(
                base: stressTest.base,
                retain: stressTest.retain,
                initialBackups: stressTest.initial,
                subsequentBackups: stressTest.subsequent
            )
        }
    }
    
    @Test func testChronologicalConsistencyComprehensive() {
        // Run multiple iterations with different random seeds to increase confidence
        let iterations = 10
        let testConfigs = [
            (base: 2, retain: 2, initial: 10, subsequent: 5),
            (base: 10, retain: 3, initial: 15, subsequent: 8),
            (base: 16, retain: 4, initial: 20, subsequent: 10),
        ]
        
        for config in testConfigs {
            for _ in 0..<iterations {
                testChronologicalConsistency(
                    base: config.base,
                    retain: config.retain,
                    initialBackups: config.initial,
                    subsequentBackups: config.subsequent
                )
            }
        }
    }
    
    @Test func testRetainLessThanBase() {
        // Test the algorithm's behavior when retain count is less than base
        let testCases = [
            (base: 10, retain: 3, description: "Base 10, retain 3"),
            (base: 16, retain: 5, description: "Base 16, retain 5"),
            (base: 2, retain: 1, description: "Base 2, retain 1"),
        ]
        
        for testCase in testCases {
            // Create a tree with backups that span different digit groups
            let tree = BackupTree(100, 90, 80, 70, 60, 50, 40, 30, 20, 10)
            
            let retained = tree.retainedBackups(base: testCase.base, retain: testCase.retain)
            
            // Verify we get exactly the requested number of backups
            #expect(retained.count == testCase.retain, 
                    "Expected \(testCase.retain) backups for \(testCase.description), got \(retained.count)")
            
            // Verify the most recent backup is always retained
            #expect(retained.contains(TimeCode(value: 100)), 
                    "Most recent backup should always be retained for \(testCase.description)")
            
            // Verify all retained backups are from the original set
            for backup in retained {
                #expect(tree.backups.contains(backup), 
                        "All retained backups should be from original set for \(testCase.description)")
            }
        }
    }
    
    @Test func testRetainLessThanBaseDetailed() {
        // Detailed test showing allocation behavior when retain < base
        let tree = BackupTree(100, 90, 80, 70, 60, 50, 40, 30, 20, 10)
        
        // Test with base 10, retain 3
        let retained = tree.retainedBackups(base: 10, retain: 3)
        
        #expect(retained.count == 3)
        #expect(retained.contains(TimeCode(value: 100))) // Most recent always retained
        
        // The remaining 2 slots should be allocated based on geometric distribution
        // With base 10, weights are [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
        // Total weight = 45
        // For 2 remaining slots:
        // - Highest digit gets: (2 * 9) / 45 = 0.4 → 0 slots
        // - Second highest gets: (2 * 8) / 45 = 0.36 → 0 slots
        // - Third highest gets: (2 * 7) / 45 = 0.31 → 0 slots
        // - Fourth highest gets: (2 * 6) / 45 = 0.27 → 0 slots
        // - Fifth highest gets: (2 * 5) / 45 = 0.22 → 0 slots
        // - Sixth highest gets: (2 * 4) / 45 = 0.18 → 0 slots
        // - Seventh highest gets: (2 * 3) / 45 = 0.13 → 0 slots
        // - Eighth highest gets: (2 * 2) / 45 = 0.09 → 0 slots
        // - Ninth highest gets: (2 * 1) / 45 = 0.04 → 0 slots
        // - Tenth highest gets: (2 * 0) / 45 = 0 → 0 slots
        // 
        // After rounding, all get 0, so the two-pass algorithm distributes the 2 slots
        // to the highest digits first: 1 to highest, 1 to second highest
        
        // Verify the algorithm still works correctly despite the small allocation
        #expect(retained.count == 3)
    }
    
    @Test func testRetainLessThanBaseBehavior() {
        // Test to demonstrate the actual behavior when retain < base
        let tree = BackupTree(100, 90, 80, 70, 60, 50, 40, 30, 20, 10)
        
        print("=== Testing retain < base behavior ===")
        
        // Test different combinations
        let testCases = [
            (base: 10, retain: 3, name: "Base 10, retain 3"),
            (base: 16, retain: 5, name: "Base 16, retain 5"),
            (base: 2, retain: 1, name: "Base 2, retain 1"),
        ]
        
        for testCase in testCases {
            let retained = tree.retainedBackups(base: testCase.base, retain: testCase.retain)
            
            print("\n\(testCase.name):")
            print("  Retained backups: \(retained.map { $0.value })")
            print("  Count: \(retained.count) (expected \(testCase.retain))")
            
            // Verify the behavior
            #expect(retained.count == testCase.retain)
            #expect(retained.contains(TimeCode(value: 100))) // Most recent always retained
        }
        
        print("\n=== Key observations ===")
        print("1. Most recent backup (100) is always retained")
        print("2. When retain < base, the geometric distribution rounds most allocations to 0")
        print("3. The two-pass algorithm distributes remaining slots to highest digits first")
        print("4. This results in very aggressive retention of recent backups")
        print("5. The algorithm still guarantees exactly 'retain' backups are kept")
    }
} 