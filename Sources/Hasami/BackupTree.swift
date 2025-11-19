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
    /// Determines how many backups to retain for each digit group using geometric distribution.
    /// This ensures the total allocations exactly match the available count.
    /// - Parameters:
    ///   - available: The number of backups available to allocate
    ///   - base: The base of the number system
    ///   - digits: The digits that have backup groups
    /// - Returns: A dictionary mapping digits to their allocation counts
    private func allocateBackupsExactly(available: Int, base: Int, digits: [Int]) -> [Int: Int] {
        precondition(available >= 0, "Available backups must be non-negative")
        precondition(base > 1, "Base must be greater than 1")
        
        var allocations: [Int: Int] = [:]
        var remaining = available
        
        if available == 0 || digits.isEmpty {
            return allocations
        }
        
        let totalWeight = base * (base + 1) / 2  // Sum of weights from 1 to base
        
        // Pass 1: Calculate geometric distribution with rounding
        for digit in digits {
            let weight = base - digit
            let exactAllocation = (Double(available) * Double(weight)) / Double(totalWeight)
            let allocation = Int(exactAllocation.rounded())
            allocations[digit] = allocation
            remaining -= allocation
        }
        
        // Pass 2: Distribute any remaining backups to highest digits first
        // (or remove from lowest digits if we over-allocated)
        let sortedDigits = digits.sorted(by: >)  // Highest digits first
        
        while remaining != 0 {
            for digit in (remaining > 0 ? sortedDigits : sortedDigits.reversed()) {
                if remaining == 0 { break }
                
                if remaining > 0 {
                    // Add one more backup to this digit
                    allocations[digit] = (allocations[digit] ?? 0) + 1
                    remaining -= 1
                } else if (allocations[digit] ?? 0) > 0 {
                    // Remove one backup from this digit
                    allocations[digit] = (allocations[digit] ?? 0) - 1
                    remaining += 1
                }
            }
        }
        
        return allocations
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
        
        // Calculate exact allocations that sum to remainingToRetain
        let allocations = allocateBackupsExactly(available: remainingToRetain, base: base, digits: sortedDigits)
        
        // Apply the allocations by recursively retaining backups from each digit group
        for digit in sortedDigits {
            guard let allocation = allocations[digit], allocation > 0 else { continue }
            guard let group = digitGroups[digit] else { continue }
            
            let subtree = BackupTree(timeCodes: group)
            let subtreeRetained = subtree.retainedBackups(base: base, retain: min(allocation, group.count))
            retained.append(contentsOf: subtreeRetained)
            remainingToRetain -= subtreeRetained.count
            
            if remainingToRetain <= 0 {
                break
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

// MARK: - Visualization
extension BackupTree {
    /// Generates a recursive MermaidJS diagram showing the complete tree structure and retention decisions.
    /// - Parameters:
    ///   - base: The base of the number system to use for pruning
    ///   - retain: The number of backups to retain
    /// - Returns: A recursive MermaidJS diagram string
    /// - Precondition: base > 1 && retain > 0
    public func mermaidDiagram(base: Int, retain: Int) -> String {
        precondition(base > 1, "Base must be greater than 1")
        precondition(retain > 0, "Must retain at least one backup")
        
        var diagram = "graph LR\n"
        var nodeCounter = 0
        var nodeMap: [TimeCode: String] = [:]
        
        func addNode(_ timeCode: TimeCode, label: String, color: String) -> String {
            let nodeId = "N\(nodeCounter)"
            nodeCounter += 1
            nodeMap[timeCode] = nodeId
            diagram += "    \(nodeId)[\"\(label)\"]\n"
            diagram += "    style \(nodeId) fill:\(color)\n"
            return nodeId
        }
        
        func formatTimeCode(_ timeCode: TimeCode, startPosition: Int? = nil, endPosition: Int? = nil) -> String {
            let fullString = String(timeCode.value, radix: base)
            
            if let start = startPosition, let end = endPosition {
                // Ensure we have valid indices and start <= end
                let startIndex = fullString.index(fullString.startIndex, offsetBy: max(0, fullString.count - start - 1))
                let endIndex = fullString.index(fullString.startIndex, offsetBy: max(0, fullString.count - end - 1))
                
                // Ensure startIndex <= endIndex
                if startIndex <= endIndex {
                    return String(fullString[startIndex..<endIndex])
                } else {
                    // If the range is invalid, return the full string
                    return fullString
                }
            }
            
            return fullString
        }
        
        func formatTimeCodeRelevant(_ timeCode: TimeCode, msdPosition: Int) -> String {
            let fullString = String(timeCode.value, radix: base)
            
            // Show digits from the most significant differing position down to the end
            let startIndex = fullString.index(fullString.startIndex, offsetBy: max(0, fullString.count - msdPosition - 1))
            return String(fullString[startIndex...])
        }
        
        func addSubtree(_ tree: BackupTree, parentId: String?, level: Int, retain: Int) {
            guard let oldest = tree.oldest, let mostRecent = tree.mostRecent else { return }
            
            // Find the most significant digit that varies
            guard let msdPosition = oldest.mostSignificantDifferingDigitPosition(from: mostRecent, base: base) else {
                // Single value case - this is a leaf
                let nodeId = addNode(mostRecent, label: "\(formatTimeCode(mostRecent))\n[RETAINED]", color: "#90EE90")
                if let parentId = parentId {
                    diagram += "    \(parentId) --> \(nodeId)\n"
                }
                return
            }
            
            // Group backups by their digit at the current position
            var digitGroups: [Int: [TimeCode]] = [:]
            for timeCode in tree.timeCodes {
                if timeCode != mostRecent {
                    let digit = timeCode.digit(at: msdPosition, base: base)
                    digitGroups[digit, default: []].append(timeCode)
                }
            }
            
            // Sort digits in descending order
            let sortedDigits = digitGroups.keys.sorted(by: >)
            
            // Calculate allocations
            let remainingToRetain = retain - 1
            let allocations = allocateBackupsExactly(available: remainingToRetain, base: base, digits: sortedDigits)
            
            // Add most recent backup
            let mostRecentLabel = "\(formatTimeCodeRelevant(mostRecent, msdPosition: msdPosition))\n[RETAINED]"
            let mostRecentId = addNode(mostRecent, label: mostRecentLabel, color: "#90EE90")
            if let parentId = parentId {
                diagram += "    \(parentId) --> \(mostRecentId)\n"
            }
            
            // Process each digit group
            for digit in sortedDigits {
                guard let group = digitGroups[digit] else { continue }
                let allocation = allocations[digit] ?? 0
                
                // Create digit group node
                let groupId = addNode(TimeCode(value: -1), label: "Digit \(digit) Group\nCount: \(group.count)\nAllocated: \(allocation)", color: "#ffeb3b")
                if let parentId = parentId {
                    diagram += "    \(parentId) --> \(groupId)\n"
                }
                
                // Create subtree for this digit group
                let subtree = BackupTree(timeCodes: group)
                
                // Check if this subtree can be further subdivided
                let canSubdivide = subtree.count > 1 && allocation > 1
                
                if allocation == 0 {
                    // Zero allocation case - show all items as deleted at this level
                    for timeCode in group {
                        let timeCodeLabel = "\(formatTimeCodeRelevant(timeCode, msdPosition: msdPosition))\n[DELETED]"
                        let nodeId = addNode(timeCode, label: timeCodeLabel, color: "#ffcdd2")
                        diagram += "    \(groupId) --> \(nodeId)\n"
                    }
                } else if canSubdivide {
                    // Can be further subdivided - recurse without showing individual items
                    addSubtree(subtree, parentId: groupId, level: level + 1, retain: allocation)
                } else {
                    // Cannot be further subdivided - this is a leaf, show individual items
                    let subtreeRetained = subtree.retainedBackups(base: base, retain: min(allocation, group.count))
                    
                    for timeCode in group {
                        let isRetained = subtreeRetained.contains(timeCode)
                        let status = isRetained ? "[RETAINED]" : "[DELETED]"
                        let color = isRetained ? "#90EE90" : "#ffcdd2"
                        let timeCodeLabel = "\(formatTimeCodeRelevant(timeCode, msdPosition: msdPosition))\n\(status)"
                        let nodeId = addNode(timeCode, label: timeCodeLabel, color: color)
                        diagram += "    \(groupId) --> \(nodeId)\n"
                    }
                }
            }
        }
        
        // Add root node
        let rootId = addNode(TimeCode(value: -1), label: "BackupTree\nTotal: \(count)\nRetain: \(retain)\nBase: \(base)", color: "#e6f3ff")
        
        // Start the recursive process
        addSubtree(self, parentId: rootId, level: 0, retain: retain)
        
        return diagram
    }
}
