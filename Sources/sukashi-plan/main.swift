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

        Use --half-life for an absolute half-life (e.g. 30d; retention density halves
        every <duration> of age) or --half-lives for a half-life relative to the
        history span (e.g. 4 means span/4, which is scale-free). The two are mutually
        exclusive; the default is --half-lives 4.

        Keys are treated as opaque strings and emitted in the order they appeared
        on stdin. Items that share a timestamp collapse to a single representative
        (first-in-input wins); the non-representative duplicates always land in
        the prune list. The planner consults no wall-clock time, so the output is
        a pure function of the input set.
        """
    )

    @Option(name: .long, help: "Which keys to emit: 'keep' or 'prune'. Required.")
    var mode: PlanMode

    @Option(name: .shortAndLong, help: "Number of items to retain.")
    var retain: Int = 10

    @Option(name: .long, help: "Absolute half-life: retention density halves every <duration> of age. Accepts s/m/h/d/w suffixes (e.g. 30d); a bare number is seconds. Mutually exclusive with --half-lives.")
    var halfLife: String?

    @Option(name: .long, help: "Relative half-life: how many half-lives span the full history (e.g. 4 means span/4). Scale-free. Mutually exclusive with --half-life. Default: 4.")
    var halfLives: Double?

    func validate() throws {
        if retain < 0 {
            throw ValidationError("--retain must be non-negative")
        }
        if halfLife != nil && halfLives != nil {
            throw ValidationError("Cannot specify both --half-life and --half-lives")
        }
        if let halfLives, halfLives <= 0 {
            throw ValidationError("--half-lives must be positive")
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

        let policy: RetentionPolicy
        if let halfLife {
            guard let seconds = DurationParser.seconds(from: halfLife) else {
                throw ValidationError("Invalid --half-life value '\(halfLife)'. Use e.g. 30d, 12h, 90m, 2w, or a number of seconds.")
            }
            policy = .absoluteHalfLife(seconds: seconds)
        } else {
            policy = .halfLivesAcrossSpan(halfLives ?? 4.0)
        }

        let result = Planner.plan(
            items: items,
            policy: policy,
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
