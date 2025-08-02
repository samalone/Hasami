# Sukashi Algorithm Technical Documentation

## Overview

The sukashi algorithm is a deterministic pruning algorithm that treats filesystem items as base-N numbers based on their creation timestamps. It uses a recursive tree approach to intelligently allocate retention slots while favoring more recent items.

## Core Concepts

### TimeCode

A `TimeCode` represents a Unix timestamp (seconds since epoch) as an integer value:

```swift
struct TimeCode {
    let value: Int
    
    init(date: Date) {
        self.value = Int(date.timeIntervalSince1970)
    }
}
```

### Base-N Representation

TimeCodes are treated as base-N numbers where N is the specified base (default: 2). Each digit position represents a different time scale:

- **Base 2**: Binary representation, most aggressive pruning
- **Base 10**: Decimal representation, balanced approach  
- **Base 16**: Hexadecimal representation, more conservative

### Digit Operations

The algorithm relies on digit-level operations:

```swift
extension TimeCode {
    func digitCount(base: Int) -> Int {
        // Number of digits in base-N representation
    }
    
    func digit(at position: Int, base: Int) -> Int {
        // Get digit at specific position
    }
}
```

## Algorithm Steps

### 1. TimeCode Conversion

Each filesystem item's creation timestamp is converted to a TimeCode:

```swift
let timeCodes = items.map { (name, date) in
    (name: name, timeCode: TimeCode(date: date))
}
```

### 2. Most Significant Digit Analysis

The algorithm finds the most significant digit position that varies among TimeCodes:

```swift
func mostSignificantDifferingDigitPosition(from other: TimeCode, base: Int) -> Int? {
    // Find first digit position where values differ
}
```

This determines the starting level for the recursive algorithm.

### 3. Recursive Tree Processing

The core algorithm processes TimeCodes recursively by digit level:

```swift
func retainedBackups(base: Int, retain: Int) -> [TimeCode] {
    guard let mostRecent = mostRecent else { return [] }
    
    let msdPosition = mostSignificantDifferingDigitPosition(from: oldest, base: base)
    
    // Group by digit at current position
    let groups = groupByDigit(at: msdPosition, base: base)
    
    // Allocate retention slots among groups
    let allocations = allocateBackupsExactly(available: retain, base: base, digits: groups.keys)
    
    // Recursively process each group
    var result: [TimeCode] = []
    for (digit, count) in allocations {
        let groupTimeCodes = groups[digit] ?? []
        let subtree = BackupTree(timeCodes: groupTimeCodes)
        result.append(contentsOf: subtree.retainedBackups(base: base, retain: count))
    }
    
    return result
}
```

### 4. Geometric Distribution

Retention slots are allocated using a geometric distribution that favors larger digits (more recent items):

```swift
private func allocateBackupsExactly(available: Int, base: Int, digits: [Int]) -> [Int: Int] {
    let totalWeight = base * (base + 1) / 2
    
    // Pass 1: Calculate geometric distribution with rounding
    for digit in digits {
        let weight = base - digit  // Larger digits get more weight
        let exactAllocation = (Double(available) * Double(weight)) / Double(totalWeight)
        let allocation = Int(exactAllocation.rounded())
        allocations[digit] = allocation
    }
    
    // Pass 2: Distribute remaining/excess slots
    // Ensures total allocation exactly matches requested count
}
```

### 5. Deterministic Results

The algorithm guarantees:
- Same input always produces same output
- Independent of filesystem order
- Predictable retention patterns

## Example Walkthrough

### Input
```
Items with timestamps:
- item1: 1704067200 (2024-01-01)
- item2: 1717200000 (2024-06-01)
- item3: 1735689600 (2024-12-01)
```

### Base 2 Processing

1. **Binary Conversion**:
   ```
   item1: 1100111010011001001011000010000
   item2: 1100110010110110100010110000000  
   item3: 1100101100100101110111110010000
   ```

2. **Most Significant Digit**: Position 0 (leftmost)

3. **Grouping by Digit**:
   ```
   Digit 1: [item1, item2, item3]  // All start with 1
   ```

4. **Allocation** (retain 2):
   ```
   Weight calculation: base - digit = 2 - 1 = 1
   Total weight: 1
   Allocation: 2 slots to digit 1
   ```

5. **Recursive Processing**:
   - Process subtree with items [item1, item2, item3]
   - Find next differing digit position
   - Continue until retention slots are exhausted

### Result
```
Retained: item1, item3
Deleted: item2
```

## Implementation Details

### Data Structures

- **BackupTree**: Sorted collection of TimeCodes using `SortedSet`
- **TimeCode**: Immutable struct with value-based equality
- **Allocation Map**: `[Int: Int]` mapping digits to retention counts

### Performance Characteristics

- **Time Complexity**: O(n log n) for sorting, O(n) for processing
- **Space Complexity**: O(n) for storing TimeCodes and allocations
- **Deterministic**: No randomization, same input = same output

### Edge Cases

- **Empty Directory**: Returns empty result
- **Single Item**: Always retained
- **Identical Timestamps**: All items with same timestamp are treated equally
- **Invalid Base**: Precondition failure for base ≤ 1

## Mathematical Foundation

### Geometric Distribution

The allocation uses a geometric distribution where:
- Weight for digit d = base - d
- Larger digits (more recent) get higher weights
- Total weight = base * (base + 1) / 2

### Two-Pass Allocation

1. **Pass 1**: Calculate initial allocation using geometric distribution
2. **Pass 2**: Distribute remaining/excess slots to ensure exact count

This ensures the total allocated slots exactly matches the requested retention count.

## Chronological Consistency Property

### Definition

The sukashi algorithm maintains **chronological consistency**, which means that when backups are created in chronological order, no older pruning operation removes files that would be retained by a newer pruning operation.

### Mathematical Guarantee

For any sequence of backups created in chronological order:
1. Let `A` be the initial set of backups
2. Let `P_A` be the result of pruning `A` with parameters `(base, retain)`
3. Let `B` be a set of subsequent backups (all occurring after backups in `A`)
4. Let `P_full` be the result of pruning `A ∪ B` with parameters `(base, retain)`
5. Let `P_combined` be the result of pruning `P_A ∪ B` with parameters `(base, retain)`

Then: `P_full = P_combined`

### Practical Implications

This property ensures:
- **Predictable Behavior**: Pruning decisions are consistent over time
- **No Regret**: Files retained by earlier pruning won't be deleted by later pruning
- **Incremental Processing**: Can process backups in batches without losing consistency
- **Safe Automation**: Automated pruning systems can operate without unexpected file deletions

### Verification

The property is verified through comprehensive fuzzy testing:
- Random generation of backup sequences
- Multiple test configurations with different bases and retention counts
- Edge cases and stress tests
- Statistical validation across thousands of test cases

## Base Parameter Effects

### Distribution Characteristics

The `base` parameter fundamentally affects how retention slots are distributed across time periods:

#### Base 2 (Binary)
- **Most Aggressive**: Favoring very recent backups
- **Distribution**: Heavy concentration on most recent items
- **Use Case**: When storage is extremely limited and recent backups are most valuable
- **Example**: With retain=3, might keep 1 very recent, 1 moderately recent, 1 older backup

#### Base 10 (Decimal)
- **Balanced Approach**: Moderate distribution across time periods
- **Distribution**: More even spread across different time scales
- **Use Case**: General-purpose backup retention with good coverage
- **Example**: With retain=5, might keep 2 recent, 2 moderately recent, 1 older backup

#### Base 16 (Hexadecimal)
- **Conservative**: More even distribution across time periods
- **Distribution**: Broader spread, less concentration on recent items
- **Use Case**: When historical backups are equally valuable
- **Example**: With retain=7, might keep 2 recent, 2 moderately recent, 2 older, 1 very old backup

### Mathematical Relationship

The base parameter affects the geometric distribution weights:

```
Weight for digit d = base - d
```

For base 2: weights are [1, 0] (very aggressive)
For base 10: weights are [9, 8, 7, ..., 1, 0] (moderate)
For base 16: weights are [15, 14, 13, ..., 1, 0] (conservative)

### Selection Guidelines

#### Choose Base 2 When:
- Storage space is extremely limited
- Recent backups are significantly more valuable
- You need maximum retention of recent items
- Acceptable to lose older backups quickly

#### Choose Base 10 When:
- Storage space is moderately limited
- You want balanced coverage across time periods
- Recent and historical backups have similar value
- General-purpose backup retention

#### Choose Base 16 When:
- Storage space is plentiful
- Historical backups are valuable
- You want maximum coverage across time periods
- Long-term retention is important

### Time Scale Effects

The base parameter also affects which time scales are prioritized:

- **Base 2**: Prioritizes the most recent time periods (hours/days)
- **Base 10**: Balances recent (days/weeks) and historical (months) periods
- **Base 16**: Provides better coverage of historical periods (months/years)

### Retention Pattern Examples

#### Base 2 with retain=4:
```
Recent (last 24h): 2 backups
Recent (last week): 1 backup  
Historical (older): 1 backup
```

#### Base 10 with retain=4:
```
Recent (last 24h): 1 backup
Recent (last week): 1 backup
Recent (last month): 1 backup
Historical (older): 1 backup
```

#### Base 16 with retain=4:
```
Recent (last 24h): 1 backup
Recent (last week): 1 backup
Recent (last month): 1 backup
Historical (older): 1 backup
```

Note: The actual distribution depends on the specific timestamps and the recursive nature of the algorithm.

## Testing Strategy

### Unit Tests

- **TimeCode Tests**: Digit operations, comparisons, conversions
- **BackupTree Tests**: Tree operations, pruning algorithm
- **Integration Tests**: End-to-end scenarios

### Property-Based Tests

- **Determinism**: Same input always produces same output
- **Retention Count**: Always returns exactly requested number of items
- **Most Recent Retention**: Most recent item is always retained
- **Base Independence**: Algorithm works with different bases

### Edge Case Tests

- Empty trees, single items, identical timestamps
- Invalid inputs, boundary conditions
- Different bases and retention counts

## Future Enhancements

### Potential Improvements

- **Custom Weight Functions**: Allow user-defined allocation strategies
- **Time-Based Filtering**: Filter by date ranges before processing
- **Size-Aware Pruning**: Consider file sizes in allocation
- **Parallel Processing**: Process large directories more efficiently

### Algorithm Variants

- **Exponential Decay**: Different weight distribution functions
- **Adaptive Bases**: Automatically select optimal base
- **Hierarchical Pruning**: Multi-level retention strategies 