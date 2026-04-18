import Foundation
import Hasami

/// Which keys `sukashi-plan` should emit: the retained set or its complement.
public enum PlanMode: String, CaseIterable {
    case keep
    case prune
}

/// A single `(timestamp, key)` pair parsed from stdin.
public struct PlanItem: Equatable {
    public let timeCode: TimeCode
    public let key: String

    public init(timeCode: TimeCode, key: String) {
        self.timeCode = timeCode
        self.key = key
    }
}

/// Error produced when a stdin line cannot be parsed as a plan item.
public struct PlanParseError: Error, LocalizedError, Equatable {
    public let lineNumber: Int
    public let line: String
    public let reason: String

    public init(lineNumber: Int, line: String, reason: String) {
        self.lineNumber = lineNumber
        self.line = line
        self.reason = reason
    }

    public var errorDescription: String? {
        "line \(lineNumber): \(reason)"
    }
}

/// The partitioned result of a plan: every input key ends up in exactly one list,
/// preserving the order the keys appeared in on stdin.
public struct PlanResult: Equatable {
    public let keep: [String]
    public let prune: [String]

    public init(keep: [String], prune: [String]) {
        self.keep = keep
        self.prune = prune
    }

    /// Returns the list of keys corresponding to the requested mode.
    public func output(mode: PlanMode) -> [String] {
        switch mode {
        case .keep: return keep
        case .prune: return prune
        }
    }
}

public enum Planner {
    /// Parses lines of `<unix-timestamp><TAB><key>` into `PlanItem`s.
    ///
    /// Empty lines are skipped. Any other malformed line raises `PlanParseError`
    /// identifying the 1-based line number.
    public static func parse<S: Sequence>(lines: S) throws -> [PlanItem] where S.Element == String {
        var items: [PlanItem] = []
        var lineNumber = 0
        for rawLine in lines {
            lineNumber += 1
            let line = rawLine.trimmingCharacters(in: .newlines)
            if line.isEmpty { continue }

            guard let tabIdx = line.firstIndex(of: "\t") else {
                throw PlanParseError(
                    lineNumber: lineNumber,
                    line: line,
                    reason: "missing tab separator between timestamp and key"
                )
            }
            let tsPart = line[line.startIndex..<tabIdx]
            let keyPart = line[line.index(after: tabIdx)...]

            guard let ts = Int(tsPart) else {
                throw PlanParseError(
                    lineNumber: lineNumber,
                    line: line,
                    reason: "invalid timestamp \"\(tsPart)\" (expected integer Unix seconds)"
                )
            }
            if keyPart.isEmpty {
                throw PlanParseError(
                    lineNumber: lineNumber,
                    line: line,
                    reason: "empty key after tab separator"
                )
            }
            items.append(PlanItem(timeCode: TimeCode(value: ts), key: String(keyPart)))
        }
        return items
    }

    /// Runs the Hasami retention algorithm against `items` and partitions the input
    /// into keep/prune lists.
    ///
    /// Items whose timestamps collide within `slotDuration` are deduplicated exactly
    /// the way `sukashi` does it — the most recent timestamp in a slot represents the
    /// slot. When two items tie on timestamp, the one that appeared *first* in the
    /// input wins, so the partition is deterministic for any given input ordering.
    /// Non-representative duplicates always land in the prune list.
    public static func plan(
        items: [PlanItem],
        now: TimeCode,
        radix: Int,
        slotDuration: Int,
        retain: Int
    ) -> PlanResult {
        precondition(radix >= 2, "Radix must be at least 2")
        precondition(slotDuration >= 1, "Slot duration must be at least 1")
        precondition(retain >= 0, "Retain count must be non-negative")

        if items.isEmpty {
            return PlanResult(keep: [], prune: [])
        }

        // For each age slot, pick a representative: highest timestamp wins;
        // ties resolved by first-in-input order.
        var repByAge: [Int: (index: Int, timeCode: TimeCode)] = [:]
        for (idx, item) in items.enumerated() {
            let age = max(0, (now.value - item.timeCode.value) / slotDuration)
            if let current = repByAge[age] {
                if item.timeCode.value > current.timeCode.value {
                    repByAge[age] = (idx, item.timeCode)
                }
            } else {
                repByAge[age] = (idx, item.timeCode)
            }
        }

        let representativeTimeCodes = repByAge.values.map { $0.timeCode }
        let tree = BackupTree(timeCodes: representativeTimeCodes)
        let retained = tree.retainedBackups(
            now: now,
            radix: radix,
            slotDuration: slotDuration,
            keepCount: retain
        )
        let retainedTimeCodes = Set(retained)

        var keptIndices: Set<Int> = []
        for (_, rep) in repByAge where retainedTimeCodes.contains(rep.timeCode) {
            keptIndices.insert(rep.index)
        }

        var keep: [String] = []
        var prune: [String] = []
        for (idx, item) in items.enumerated() {
            if keptIndices.contains(idx) {
                keep.append(item.key)
            } else {
                prune.append(item.key)
            }
        }
        return PlanResult(keep: keep, prune: prune)
    }
}
