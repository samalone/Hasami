import Foundation
import Testing
@testable import Hasami

/// Long-term behavior simulations for the Hasami retention algorithm, used as
/// regression guards: a breaking change to `BackupTree.retainedBackups` that
/// degrades the converged distribution will trip the assertions here.
///
/// Scenario (both tests): a backup is taken every day for 52 weeks; once a week
/// `sukashi --retain 50` is run over everything accumulated so far. This drives
/// the *iterated* pruning path (prune the survivors + the latest week, every
/// week) rather than a single one-shot prune. The two tests differ only in the
/// half-life policy:
///   * `simulateWeeklyRelativeHalfLives` — `--half-lives 4` (H = span/4, scale-free)
///   * `simulateWeeklyAbsoluteHalfLife`  — `--half-life 30d` (H fixed at 30 days)
///
/// Each test prints machine-readable blocks (KEPT_AGES / ONESHOT_AGES /
/// WEEKLY_TRACE / STATS) that the density-visualization step can parse.
struct LongTermSimulationTests {
    static let DAY = 86_400                 // seconds per day
    static let WEEKS = 52
    static let KEEP = 50

    // MARK: - Shared simulation harness

    /// One simulated week's worth of state captured after that week's prune.
    struct WeekSample {
        let week: Int
        let count: Int
        let rmsPct: Double      // RMS deviation from the ideal uniform-in-u curve
    }

    struct SimulationResult {
        let finalAges: [Double]     // surviving ages in days, ascending (newest = 0)
        let oneShotAges: [Double]   // single prune of every daily backup, ascending
        let trace: [WeekSample]
        let lastDay: Int
    }

    /// Ages (in days from the newest backup) of every backup in `tree`, ascending.
    private static func agesInDays(_ tree: BackupTree) -> [Double] {
        guard let newest = tree.mostRecent?.value else { return [] }
        return tree.backups.map { Double(newest - $0.value) / Double(DAY) }.sorted()
    }

    /// RMS deviation, in warp space, of `ages` from a perfectly uniform-in-u set.
    /// `u(age) = 1 - 2^(-age / halfLifeDays)`; the ideal places rank i at
    /// `uMax · i/(n-1)`. Returns the RMS as a fraction of the u-range (uMax).
    private static func rmsPctInWarpSpace(_ ages: [Double], halfLifeDays: Double) -> Double {
        guard ages.count > 1, let span = ages.last, span > 0 else { return 0 }
        let u = { (a: Double) in 1.0 - exp2(-a / halfLifeDays) }
        let uMax = u(span)
        guard uMax > 0 else { return 0 }
        let n = ages.count
        var sse = 0.0
        for (i, a) in ages.enumerated() {
            let ideal = uMax * Double(i) / Double(n - 1)
            sse += (u(a) - ideal) * (u(a) - ideal)
        }
        return sqrt(sse / Double(n)) / uMax * 100
    }

    /// Runs the 52-week daily-backup / weekly-prune scenario.
    ///
    /// - Parameters:
    ///   - prune: applies the week's retention policy to the accumulated tree,
    ///     returning the survivors.
    ///   - halfLifeDays: given the current ages, returns the half-life (in days)
    ///     the policy is using this week, so the fit metric matches the warp the
    ///     algorithm actually applied (span/4 for relative, constant for absolute).
    private static func runScenario(
        prune: (BackupTree) -> [TimeCode],
        halfLifeDays: ([Double]) -> Double
    ) -> SimulationResult {
        var tree = BackupTree()
        var lastDay = 0
        var trace: [WeekSample] = []

        for week in 0..<WEEKS {
            for d in 0..<7 {
                let dayIndex = week * 7 + d
                lastDay = dayIndex
                tree = tree.adding(TimeCode(value: dayIndex * DAY))
            }
            tree = BackupTree(timeCodes: prune(tree))   // weekly `sukashi --retain 50 …`
            let ages = agesInDays(tree)
            trace.append(WeekSample(week: week + 1,
                                    count: tree.count,
                                    rmsPct: rmsPctInWarpSpace(ages, halfLifeDays: halfLifeDays(ages))))
        }

        // One-shot baseline: prune every daily backup ever taken in a single pass.
        let allDays = (0...lastDay).map { TimeCode(value: $0 * DAY) }
        let oneShot = BackupTree(timeCodes: allDays)
        let oneShotAges = agesInDays(BackupTree(timeCodes: prune(oneShot)))

        return SimulationResult(finalAges: agesInDays(tree),
                                oneShotAges: oneShotAges,
                                trace: trace,
                                lastDay: lastDay)
    }

    /// Emits the parseable result blocks consumed by the density-viz step.
    ///
    /// Off by default so it doesn't bury normal `swift test` output; set
    /// `HASAMI_SIM_REPORT=1` in the environment to dump the data blocks
    /// (e.g. `HASAMI_SIM_REPORT=1 swift test --filter LongTermSimulationTests`).
    private static func report(_ label: String, _ r: SimulationResult, halfLifeDays: Double) {
        guard ProcessInfo.processInfo.environment["HASAMI_SIM_REPORT"] != nil else { return }
        func emit(_ tag: String, _ ages: [Double]) {
            print("=== \(tag) BEGIN ===")
            print(ages.map { String(format: "%.4f", $0) }.joined(separator: ","))
            print("=== \(tag) END ===")
        }
        print("########## \(label) ##########")
        emit("KEPT_AGES", r.finalAges)
        emit("ONESHOT_AGES", r.oneShotAges)
        print("=== WEEKLY_TRACE BEGIN ===")
        for s in r.trace { print("week=\(s.week) count=\(s.count) rms_pct=\(String(format: "%.3f", s.rmsPct))") }
        print("=== WEEKLY_TRACE END ===")
        let span = r.finalAges.last ?? 0
        print("=== STATS BEGIN ===")
        print("count=\(r.finalAges.count) span_days=\(String(format: "%.1f", span)) H_days=\(String(format: "%.2f", halfLifeDays)) final_rms_pct=\(String(format: "%.3f", r.trace.last?.rmsPct ?? 0))")
        print("=== STATS END ===")
    }

    /// Adjacent gaps (days) between successive ascending ages.
    private static func gaps(_ ages: [Double]) -> [Double] {
        zip(ages.dropFirst(), ages).map { $0 - $1 }
    }

    // MARK: - Relative half-life: `--half-lives 4`

    @Test func simulateWeeklyRelativeHalfLives() {
        let halfLives = 4.0
        let r = Self.runScenario(
            prune: { $0.retainedBackups(halfLivesAcrossSpan: halfLives, keepCount: Self.KEEP) },
            halfLifeDays: { ages in (ages.last ?? 0) / halfLives }
        )
        Self.report("RELATIVE --half-lives 4", r, halfLifeDays: (r.finalAges.last ?? 0) / halfLives)

        let ages = r.finalAges
        let span = ages.last ?? 0

        // Structure: a full keep-set spanning the whole year, endpoints pinned.
        #expect(ages.count == Self.KEEP)
        #expect(ages.first == 0)                       // newest pinned at age 0
        #expect(span == 363)                           // oldest (day-0 backup) pinned; span = 52w-1d
        #expect(ages == ages.sorted())                 // ascending
        #expect(Set(ages).count == ages.count)         // no duplicates

        // Exponential shape: gaps near "now" are far tighter than gaps in the tail.
        let g = Self.gaps(ages)
        #expect(g.first! <= 3)                          // recent gaps ~ daily/weekly granularity
        #expect(g.last! >= 4 * g.first!)                // tail gaps doubled several times over

        // Convergence + steady state. The set is uniform-ish daily blocks until the
        // 50-cap engages (~week 8); after that it reshapes toward the ideal and stays.
        let final = r.trace.last!
        #expect(final.rmsPct < 3.0)                     // converged tightly to the ideal curve
        let steadyState = r.trace.filter { $0.week >= 20 }
        #expect(steadyState.allSatisfy { $0.rmsPct < 5.0 })   // no drift away from the curve
        // Reshaping genuinely improved the fit versus the unpruned filling phase.
        let fillingPhaseWorst = r.trace.filter { $0.week <= 7 }.map(\.rmsPct).max()!
        #expect(final.rmsPct < fillingPhaseWorst / 4)

        // Iteration is no worse than a one-shot prune (no hysteresis penalty).
        let oneShotRms = Self.rmsPctInWarpSpace(r.oneShotAges, halfLifeDays: span / halfLives)
        #expect(final.rmsPct <= oneShotRms + 0.5)
    }

    // MARK: - Absolute half-life: `--half-life 30d`

    @Test func simulateWeeklyAbsoluteHalfLife() {
        let halfLifeDays = 30.0
        let halfLifeSeconds = halfLifeDays * Double(Self.DAY)
        let r = Self.runScenario(
            prune: { $0.retainedBackups(halfLife: halfLifeSeconds, keepCount: Self.KEEP) },
            halfLifeDays: { _ in halfLifeDays }     // fixed regardless of span
        )
        Self.report("ABSOLUTE --half-life 30d", r, halfLifeDays: halfLifeDays)

        let ages = r.finalAges
        let span = ages.last ?? 0

        // Same endpoint-pinning structure as the relative case.
        #expect(ages.count == Self.KEEP)
        #expect(ages.first == 0)                       // newest pinned
        #expect(span == 363)                           // oldest pinned; span = full year
        #expect(ages == ages.sorted())
        #expect(Set(ages).count == ages.count)

        // A fixed 30-day half-life over a 363-day span is ~12 half-lives, so the
        // curve decays much faster than the relative case: the keep-set is heavily
        // front-loaded. The bulk of the backups sit within the first few months,
        // and the pinned oldest is stranded out past a large tail gap.
        let withinFirst90 = ages.filter { $0 <= 90 }.count
        #expect(withinFirst90 >= 30)                    // recent-heavy clustering
        let g = Self.gaps(ages)
        #expect(g.last! >= 4 * g.first!)                // big tail gap before the pinned oldest

        // Convergence + steady state, measured against the fixed-H curve.
        let final = r.trace.last!
        #expect(final.rmsPct < 5.0)
        let steadyState = r.trace.filter { $0.week >= 25 }
        #expect(steadyState.allSatisfy { $0.rmsPct < 8.0 })

        // Iteration is no worse than a one-shot prune.
        let oneShotRms = Self.rmsPctInWarpSpace(r.oneShotAges, halfLifeDays: halfLifeDays)
        #expect(final.rmsPct <= oneShotRms + 1.0)
    }
}
