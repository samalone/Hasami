# Hasami

**Intelligent Filesystem Pruning with Japanese Precision**

Hasami is a Swift utility that implements the sukashi (透かし) algorithm for intelligent filesystem pruning. Like pruning a bonsai tree to let light through, Hasami carefully thins collections of files and directories, fitting the retained backups to an exponential-decay curve: recent backups are kept densely, and the spacing between retained backups grows with age.

The project ships two executables that share the same `Hasami` library:

- **`sukashi`** — prunes a local directory, reading creation dates from the
  filesystem and moving unwanted items to the macOS Trash (or force-deleting
  them). This is the right tool for on-disk backup pruning.
- **`sukashi-plan`** — reads `<unix-timestamp><TAB><key>` lines from stdin and
  writes the keep-list or prune-list to stdout. It has no filesystem or
  platform dependencies, so it composes into Unix pipelines to prune cloud
  object storage, database rows, or anything else keyed by timestamp.

## What is Sukashi?

Sukashi (透かし) means "thinning" or "letting light through" in Japanese gardening. The algorithm warps each backup's age into a coordinate where the target retention density is uniform, then greedily removes the most redundant backups, producing a distribution where recent backups are kept densely and older backups are kept at exponentially increasing intervals.

### Key Features

- **Deterministic**: Same input always produces same output
- **Works with irregular schedules**: No assumption about backup frequency
- **Safe**: Moves to macOS Trash by default, not permanent deletion
- **Flexible**: Works with files, directories, or both
- **Exact count**: Keeps precisely the requested number of backups, with no fractional-budget rounding

## Quick Start

### Installation

```bash
git clone https://github.com/your-username/hasami.git
cd hasami
swift build
swift run sukashi --help
```

### Basic Usage

```bash
# Prune a backup directory (keep 10 items)
swift run sukashi /path/to/backups

# See what would happen first
swift run sukashi /path/to/backups --dry-run --verbose

# Custom retention with an absolute 2-week half-life
swift run sukashi /path/to/backups --retain 20 --half-life 2w
```

## Examples

### Backup Management

```bash
# Prune backup directories, keeping 15
swift run sukashi ~/Backups --directories-only --retain 15

# Dry run to preview changes
swift run sukashi ~/Backups --dry-run --verbose
```

### Log File Cleanup

```bash
# Keep only 5 most recent log files
swift run sukashi /var/log --files-only --retain 5

# Include hidden log files
swift run sukashi /var/log --files-only --include-hidden --retain 10
```

## How It Works

The algorithm computes each backup's age relative to the newest backup in the set, then warps that age through the retention curve's CDF, `u(t) = 1 − 2^(−t/H)`, into a coordinate where the target density is uniform. It then greedily removes the most redundant backup — the one whose neighbors are closest in `u` — until exactly `--retain` remain, always keeping the newest and oldest. The result: recent backups are dense, older backups are sparse, and gaps grow with age — and because ages are measured from the newest item, not the wall clock, the output is a pure function of the input.

The half-life `H` can be set as an absolute duration (`--half-life 30d`) or as a fraction of the history span (`--half-lives 4`, meaning `span/4`, which is scale-free and the default).

For the full algorithm specification, see [docs/backup-pruning-algorithm.md](docs/backup-pruning-algorithm.md).

### Example Distribution

180 daily backups, half-life = span/4, keep 20 (ages in days, measured from the newest):

```
Kept (days ago): 0, 3, 7, 11, 15, 19, 23, 27, 31, 35, 43, 51, 59, 67, 75, 83, 99, 115, 147, 179
Gaps (days):       3, 4, 4, 4, 4, 4, 4, 4, 4, 8, 8, 8, 8, 8, 8, 16, 16, 32, 32
```

## Command Line Options

### Basic Options

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --retain <number>` | Items to retain | 10 |
| `--half-life <duration>` | Absolute half-life; density halves every `<duration>` of age (s/m/h/d/w suffixes, e.g. `30d`) | — |
| `--half-lives <number>` | Relative half-life: how many half-lives span the history (`span/N`); scale-free | 4 |
| `--dry-run` | Preview without changes | false |

`--half-life` and `--half-lives` are mutually exclusive; with neither, the default is `--half-lives 4`.

### Filtering Options

| Option | Description |
|--------|-------------|
| `--files-only` | Process only files |
| `--directories-only` | Process only directories |
| `--include-hidden` | Include hidden items |

### Output Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show algorithm details |
| `--sort-by-date` | Sort by creation date |

### Deletion Options

| Option | Description |
|--------|-------------|
| `--force-delete` | Permanently delete instead of moving to Trash |

## Safety Features

### Dry Run Mode

Always test first:

```bash
swift run sukashi /important/data --dry-run --verbose
```

### Trash Instead of Deletion

Items are moved to macOS Trash by default (not permanently deleted). Use `--force-delete` for network volumes where Trash is not available.

## Pipeline Pruning with `sukashi-plan`

For pruning collections that aren't rooted in the filesystem, use
`sukashi-plan`. It reads `<unix-timestamp><TAB><key>` lines on stdin and emits
either the keep-list or the prune-list on stdout, governed by a required
`--mode` flag.

```bash
# Prune dated S3 prefixes, keeping 30, via rclone
rclone lsjson ess:ess-backups/snapshots/ --dirs-only \
  | jq -r '.[] | "\(.ModTime | fromdateiso8601)\t\(.Name)"' \
  | sukashi-plan --retain 30 --half-lives 4 --mode prune \
  | xargs -r -I{} rclone purge "ess:ess-backups/snapshots/{}"
```

There is no default for `--mode`: the caller must pick `keep` or `prune` each
invocation. That friction is deliberate — it prevents accidentally piping a
retain-list into a delete command.

## Documentation

- [sukashi man page](sukashi.1.md) - Filesystem pruning command reference
- [sukashi-plan man page](sukashi-plan.1.md) - Pipeline pruning command reference
- [Algorithm Specification](docs/backup-pruning-algorithm.md) - Full algorithm details

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
