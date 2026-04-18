# Hasami

**Intelligent Filesystem Pruning with Japanese Precision**

Hasami is a Swift utility that implements the sukashi (透かし) algorithm for intelligent filesystem pruning. Like pruning a bonsai tree to let light through, Hasami carefully thins collections of files and directories, retaining more recent backups and progressively fewer older ones so that gaps between retained backups grow geometrically with age.

The project ships two executables that share the same `Hasami` library:

- **`sukashi`** — prunes a local directory, reading creation dates from the
  filesystem and moving unwanted items to the macOS Trash (or force-deleting
  them). This is the right tool for on-disk backup pruning.
- **`sukashi-plan`** — reads `<unix-timestamp><TAB><key>` lines from stdin and
  writes the keep-list or prune-list to stdout. It has no filesystem or
  platform dependencies, so it composes into Unix pipelines to prune cloud
  object storage, database rows, or anything else keyed by timestamp.

## What is Sukashi?

Sukashi (透かし) means "thinning" or "letting light through" in Japanese gardening. The algorithm uses radix-based priority selection to rank backups by age, producing a distribution where recent backups are kept densely and older backups are kept at exponentially increasing intervals.

### Key Features

- **Deterministic**: Same input always produces same output
- **Works with irregular schedules**: No assumption about backup frequency
- **Safe**: Moves to macOS Trash by default, not permanent deletion
- **Flexible**: Works with files, directories, or both
- **Simple**: The core is a sort with a custom key function, followed by truncation

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

# Custom retention and radix
swift run sukashi /path/to/backups --retain 20 --radix 3
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

The algorithm computes each backup's age relative to the current time, then assigns a priority key based on radix digit reversal. Sorting by this key interleaves representatives from every time scale (hours, days, weeks, months) before filling in detail at any single scale. The result: recent backups are dense, older backups are sparse, and gaps grow geometrically.

For the full algorithm specification, see [docs/backup-pruning-algorithm.md](docs/backup-pruning-algorithm.md).

### Example Distribution

180 daily backups, radix 2, keep 20:

```
Kept (days ago): 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128, 160
Gaps (days):     1, 1, 1, 1, 1, 2, 2, 2, 4, 4, 4, 8, 8, 8, 16, 16, 16, 32, 32
```

## Command Line Options

### Basic Options

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --retain <number>` | Items to retain | 10 |
| `-x, --radix <number>` | Radix for pruning (2 = gaps double, 3 = gaps triple) | 2 |
| `--base <number>` | Alias for `--radix` | |
| `--slot-duration <seconds>` | Minimum time resolution for deduplication | 1 |
| `--dry-run` | Preview without changes | false |

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
  | sukashi-plan --retain 30 --radix 2 --mode prune \
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
