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
        #expect(tree1.wouldRetain(0b100, base: 2, retain: 2))
        
        // Test case 2: If a backup is retained, all backups with the same prefix up to the window level are retained
        let tree2 = BackupTree(0b100, 0b011, 0b010, 0b001)
        #expect(tree2.wouldRetain(0b100, base: 2, retain: 2))
        #expect(tree2.wouldRetain(0b101, base: 2, retain: 2))
        
        // Test case 3: The retention decision for a backup is independent of other backups
        let tree3 = BackupTree(0b100, 0b011, 0b010, 0b001)
        #expect(tree3.wouldRetain(0b100, base: 2, retain: 2))
        #expect(tree3.wouldRetain(0b101, base: 2, retain: 2))
        
        // Test case 4: The retention decision is deterministic based on the backup's TimeCode
        let tree4 = BackupTree(0b100, 0b011, 0b010, 0b001)
        #expect(tree4.wouldRetain(0b100, base: 2, retain: 2))
        #expect(tree4.wouldRetain(0b100, base: 2, retain: 2))
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
} 