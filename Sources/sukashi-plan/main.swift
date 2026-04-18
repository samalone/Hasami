import ArgumentParser
import Foundation
import Hasami
import SukashiPlan

extension PlanMode: ExpressibleByArgument {}

@main
struct SukashiPlanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sukashi-plan",
        abstract: "Emit a keep or prune plan for timestamped items read from stdin.",
        discussion: """
        Reads lines of <unix-timestamp><TAB><key> from stdin and writes a subset of
        keys to stdout, one per line. Composes in Unix pipelines to prune any
        collection keyed by timestamp — cloud object storage, database rows, or
        anything else — without touching the filesystem.

        --mode keep emits the keys the Hasami algorithm would retain; --mode prune
        emits the keys it would discard. There is no default; the caller must pick
        one, so a retain list cannot accidentally be piped into a delete command.

        Keys are treated as opaque strings and emitted in the order they appeared
        on stdin. Items whose timestamps fall within --slot-duration of each other
        are deduplicated (most recent wins, first-in-input breaks ties) and the
        non-representative duplicates always land in the prune list.
        """
    )

    @Option(name: .long, help: "Which keys to emit: 'keep' or 'prune'. Required.")
    var mode: PlanMode

    @Option(name: .shortAndLong, help: "Number of items to retain.")
    var retain: Int = 10

    @Option(name: [.long, .customShort("x")], help: "Radix for the pruning algorithm.")
    var radix: Int = 2

    @Option(name: .long, help: "Slot duration in seconds (deduplication window).")
    var slotDuration: Int = 1

    func validate() throws {
        if retain < 0 {
            throw ValidationError("--retain must be non-negative")
        }
        if radix < 2 {
            throw ValidationError("--radix must be at least 2")
        }
        if slotDuration < 1 {
            throw ValidationError("--slot-duration must be at least 1")
        }
    }

    func run() throws {
        let items: [PlanItem]
        do {
            items = try Planner.parse(lines: StdinLineSequence())
        } catch let error as PlanParseError {
            let message = "sukashi-plan: \(error.errorDescription ?? "parse error")\n"
            FileHandle.standardError.write(Data(message.utf8))
            throw ExitCode(65)
        }

        let now = TimeCode(date: Date())
        let result = Planner.plan(
            items: items,
            now: now,
            radix: radix,
            slotDuration: slotDuration,
            retain: retain
        )

        for key in result.output(mode: mode) {
            print(key)
        }
    }
}

private struct StdinLineSequence: Sequence, IteratorProtocol {
    mutating func next() -> String? {
        readLine(strippingNewline: true)
    }

    func makeIterator() -> StdinLineSequence { self }
}
