# Hasami

Backup pruning utility inspired by Japanese bonsai gardening (鋏 = scissors).

## Project Structure

- **Hasami** (library): Core pruning algorithm and data types
  - `TimeCode` — Integer wrapper representing a point in time (Unix epoch seconds).
  - `BackupTree` — Sorted collection of `TimeCode`s backed by `SortedSet`. Provides set operations and exponential-decay retention pruning.
  - `RetentionPolicy` — Absolute vs. span-relative half-life, plus a shared `resolve(halfLife:halfLives:)` factory for the CLIs. `DurationParser` parses `s/m/h/d/w` half-life strings.
- **sukashi** (CLI executable): Prunes files/directories in a given folder using the Hasami algorithm. Moves pruned items to macOS Trash (or force-deletes). Uses swift-argument-parser.
- **HasamiTests**: Tests for TimeCode, BackupTree set operations, the retention algorithm, and the duration/policy parsing.

## Build & Test

```sh
swift build
swift test
swift run sukashi --help
```

Requires macOS 13+ and Swift 6.0+ (the test suite uses swift-testing, which
ships with Swift 6.0 and later).

## Dependencies

- [swift-collections](https://github.com/apple/swift-collections) (SortedCollections) — used for `SortedSet` in `BackupTree`
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) — CLI parsing for `sukashi`

## Testing

Uses Swift Testing framework (`import Testing`, `@Test`, `#expect`). Not XCTest.

## Key Design Notes

- `BackupTree` is a value type (struct). All mutation methods return new instances.
- The pruning algorithm lives in `BackupTree.retainedBackups(halfLife:keepCount:)` and `retainedBackups(halfLivesAcrossSpan:keepCount:)` (with a `retainedBackups(policy:keepCount:)` dispatch). It warps each backup's age through the retention curve's CDF and greedily thins the most redundant backup. Ages are measured from the newest timestamp in the tree; no wall-clock time is consulted.
- The CLI (`sukashi`) converts file creation dates to `TimeCode` values and feeds them through `BackupTree`.
- The algorithm spec is documented in `docs/backup-pruning-algorithm.md`.
