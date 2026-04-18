import Foundation
import Testing
import Hasami
@testable import SukashiPlan

struct PlannerParseTests {
    @Test func parsesSimpleLine() throws {
        let items = try Planner.parse(lines: ["1713225600\tsnapshots/2026-04-15/"])
        #expect(items == [PlanItem(timeCode: TimeCode(value: 1713225600), key: "snapshots/2026-04-15/")])
    }

    @Test func parsesMultipleLines() throws {
        let input = [
            "1713225600\ta",
            "1713312000\tb",
            "1713398400\tc",
        ]
        let items = try Planner.parse(lines: input)
        #expect(items.map(\.key) == ["a", "b", "c"])
        #expect(items.map(\.timeCode.value) == [1713225600, 1713312000, 1713398400])
    }

    @Test func skipsEmptyLines() throws {
        let input = ["", "100\ta", "", "200\tb", ""]
        let items = try Planner.parse(lines: input)
        #expect(items.map(\.key) == ["a", "b"])
    }

    @Test func preservesTabsInsideKey() throws {
        // Only the first tab separates timestamp from key; any further tabs are
        // part of the opaque key payload.
        let items = try Planner.parse(lines: ["100\tpath/with\ttab"])
        #expect(items == [PlanItem(timeCode: TimeCode(value: 100), key: "path/with\ttab")])
    }

    @Test func stripsTrailingNewline() throws {
        let items = try Planner.parse(lines: ["100\ta\n"])
        #expect(items == [PlanItem(timeCode: TimeCode(value: 100), key: "a")])
    }

    @Test func rejectsMissingTab() {
        #expect(throws: PlanParseError.self) {
            try Planner.parse(lines: ["not-a-valid-line"])
        }
    }

    @Test func reportsLineNumberForMalformedInput() {
        do {
            _ = try Planner.parse(lines: ["100\ta", "200\tb", "garbage"])
            Issue.record("expected parse error")
        } catch let error as PlanParseError {
            #expect(error.lineNumber == 3)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func rejectsNonIntegerTimestamp() {
        do {
            _ = try Planner.parse(lines: ["notanumber\tkey"])
            Issue.record("expected parse error")
        } catch let error as PlanParseError {
            #expect(error.reason.contains("invalid timestamp"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func rejectsEmptyKey() {
        #expect(throws: PlanParseError.self) {
            try Planner.parse(lines: ["100\t"])
        }
    }
}

struct PlannerPlanTests {
    @Test func emptyInputProducesEmptyResult() {
        let result = Planner.plan(items: [], now: TimeCode(value: 1000), radix: 2, slotDuration: 1, retain: 10)
        #expect(result == PlanResult(keep: [], prune: []))
    }

    @Test func everyInputKeyAppearsInExactlyOneList() {
        let items: [PlanItem] = (1...50).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "key-\($0)")
        }
        let result = Planner.plan(items: items, now: TimeCode(value: 100), radix: 2, slotDuration: 1, retain: 10)
        let keepSet = Set(result.keep)
        let pruneSet = Set(result.prune)
        #expect(keepSet.isDisjoint(with: pruneSet))
        #expect(keepSet.union(pruneSet).count == items.count)
    }

    @Test func keepCountMatchesRetain() {
        // 180 daily samples, retain 20 — same shape as the documented spec example.
        let items: [PlanItem] = (1...180).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "key-\($0)")
        }
        let result = Planner.plan(
            items: items,
            now: TimeCode(value: 181),
            radix: 2,
            slotDuration: 1,
            retain: 20
        )
        #expect(result.keep.count == 20)
        #expect(result.prune.count == 160)
    }

    @Test func outputRespectsMode() {
        let items: [PlanItem] = [
            PlanItem(timeCode: TimeCode(value: 10), key: "a"),
            PlanItem(timeCode: TimeCode(value: 20), key: "b"),
            PlanItem(timeCode: TimeCode(value: 30), key: "c"),
        ]
        let result = Planner.plan(items: items, now: TimeCode(value: 30), radix: 2, slotDuration: 1, retain: 10)
        #expect(result.output(mode: .keep) == result.keep)
        #expect(result.output(mode: .prune) == result.prune)
    }

    @Test func outputPreservesInputOrder() {
        // Feed items in a non-chronological order and verify keep/prune preserve it.
        let items: [PlanItem] = [
            PlanItem(timeCode: TimeCode(value: 50), key: "mid"),
            PlanItem(timeCode: TimeCode(value: 10), key: "old"),
            PlanItem(timeCode: TimeCode(value: 90), key: "new"),
        ]
        let result = Planner.plan(items: items, now: TimeCode(value: 100), radix: 2, slotDuration: 1, retain: 3)
        #expect(result.keep == ["mid", "old", "new"])
        #expect(result.prune.isEmpty)
    }

    @Test func mostRecentKeyWinsWhenItOccupiesTheZeroSlot() {
        // When the most recent item lives in age slot 0, its priority key (0, 0)
        // beats everything else, so retain=1 always picks it.
        let items: [PlanItem] = (1...100).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "key-\($0)")
        }
        let result = Planner.plan(items: items, now: TimeCode(value: 100), radix: 2, slotDuration: 1, retain: 1)
        #expect(result.keep == ["key-100"])
    }

    @Test func slotDurationDeduplicatesWithinWindow() {
        // Two items 4 seconds apart with slot-duration 10 fall in the same age slot.
        // The more recent one (timestamp 95) wins the slot; the other is pruned
        // even though retain is larger than the input size.
        let items: [PlanItem] = [
            PlanItem(timeCode: TimeCode(value: 91), key: "old"),
            PlanItem(timeCode: TimeCode(value: 95), key: "new"),
        ]
        let result = Planner.plan(items: items, now: TimeCode(value: 100), radix: 2, slotDuration: 10, retain: 10)
        #expect(result.keep == ["new"])
        #expect(result.prune == ["old"])
    }

    @Test func ExactTimestampTieResolvesByInputOrder() {
        // Two items with identical timestamps: the first-seen wins the slot;
        // the second-seen is pruned.
        let items: [PlanItem] = [
            PlanItem(timeCode: TimeCode(value: 100), key: "first"),
            PlanItem(timeCode: TimeCode(value: 100), key: "second"),
        ]
        let result = Planner.plan(items: items, now: TimeCode(value: 100), radix: 2, slotDuration: 1, retain: 10)
        #expect(result.keep == ["first"])
        #expect(result.prune == ["second"])
    }

    @Test func keepListMatchesCoreAlgorithm() {
        // The spec example from BackupTreeTests: 180 daily samples, retain 20, radix 2.
        // keep-mode output should correspond to the exact same ages the core returns.
        let items: [PlanItem] = (1...180).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "key-\($0)")
        }
        let now = TimeCode(value: 181)
        let result = Planner.plan(items: items, now: now, radix: 2, slotDuration: 1, retain: 20)

        let expectedAges = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128, 160]
        let expectedKeys = expectedAges.map { "key-\(now.value - $0)" }
        // Input is in ascending timestamp order; keep is filtered in that order,
        // so sort the expectation by timestamp too.
        #expect(Set(result.keep) == Set(expectedKeys))
        #expect(result.keep.count == 20)
    }
}
