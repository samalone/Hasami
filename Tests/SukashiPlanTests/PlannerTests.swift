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

    @Test func stripsTrailingCRLF() throws {
        // CRLF-terminated lines should parse identically to LF-terminated ones,
        // so callers on Windows or piping through tools that emit CRLF don't
        // leave a stray \r at the end of the key.
        let items = try Planner.parse(lines: ["100\ta\r\n"])
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
        let result = Planner.plan(items: [], radix: 2, retain: 10)
        #expect(result == PlanResult(keep: [], prune: []))
    }

    @Test func everyInputKeyAppearsInExactlyOneList() {
        let items: [PlanItem] = (1...50).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "key-\($0)")
        }
        let result = Planner.plan(items: items, radix: 2, retain: 10)
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
        let result = Planner.plan(items: items, radix: 2, retain: 20)
        #expect(result.keep.count == 20)
        #expect(result.prune.count == 160)
    }

    @Test func outputRespectsMode() {
        let items: [PlanItem] = [
            PlanItem(timeCode: TimeCode(value: 10), key: "a"),
            PlanItem(timeCode: TimeCode(value: 20), key: "b"),
            PlanItem(timeCode: TimeCode(value: 30), key: "c"),
        ]
        let result = Planner.plan(items: items, radix: 2, retain: 10)
        #expect(result.output(mode: .keep) == result.keep)
        #expect(result.output(mode: .prune) == result.prune)
    }

    @Test func outputPreservesInputOrder() {
        let items: [PlanItem] = [
            PlanItem(timeCode: TimeCode(value: 50), key: "mid"),
            PlanItem(timeCode: TimeCode(value: 10), key: "old"),
            PlanItem(timeCode: TimeCode(value: 90), key: "new"),
        ]
        let result = Planner.plan(items: items, radix: 2, retain: 3)
        #expect(result.keep == ["mid", "old", "new"])
        #expect(result.prune.isEmpty)
    }

    @Test func newestItemAlwaysRetained() {
        // With ages measured from the max timestamp, the newest item sits at age
        // 0 and always has the top priority key. retain=1 must pick it.
        let items: [PlanItem] = (1...100).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "key-\($0)")
        }
        let result = Planner.plan(items: items, radix: 2, retain: 1)
        #expect(result.keep == ["key-100"])
    }

    @Test func exactTimestampTieResolvesByInputOrder() {
        // Two items with identical timestamps collapse: first-seen is kept,
        // second-seen is pruned.
        let items: [PlanItem] = [
            PlanItem(timeCode: TimeCode(value: 100), key: "first"),
            PlanItem(timeCode: TimeCode(value: 100), key: "second"),
        ]
        let result = Planner.plan(items: items, radix: 2, retain: 10)
        #expect(result.keep == ["first"])
        #expect(result.prune == ["second"])
    }

    @Test func retentionSetIsInvariantToInputOrder() {
        // Regression for issue #5: shuffling the input must not change the
        // retention set.
        let timestamps = [1000, 1001, 1002, 2000, 3500, 7000]
        let ascending: [PlanItem] = timestamps.sorted().map {
            PlanItem(timeCode: TimeCode(value: $0), key: "k-\($0)")
        }
        let descending: [PlanItem] = timestamps.sorted(by: >).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "k-\($0)")
        }
        let r1 = Planner.plan(items: ascending, radix: 2, retain: 3)
        let r2 = Planner.plan(items: descending, radix: 2, retain: 3)
        #expect(Set(r1.keep) == Set(r2.keep))
        // Newest is never dropped.
        #expect(r1.keep.contains("k-7000"))
        #expect(r2.keep.contains("k-7000"))
    }

    @Test func keepListMatchesCoreAlgorithm() {
        // Spec example: 180 daily samples, retain 20, radix 2. Ages are
        // measured from max_ts = 180, so expected ages are offsets 0..128.
        let items: [PlanItem] = (1...180).map {
            PlanItem(timeCode: TimeCode(value: $0), key: "key-\($0)")
        }
        let result = Planner.plan(items: items, radix: 2, retain: 20)

        let expectedAges = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128]
        let maxTs = 180
        let expectedKeys = expectedAges.map { "key-\(maxTs - $0)" }
        #expect(Set(result.keep) == Set(expectedKeys))
        #expect(result.keep.count == 20)
    }
}
