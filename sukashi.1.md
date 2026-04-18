# SUKASHI(1) - Hasami Filesystem Pruning Utility

## NAME

sukashi - Prune files and directories using the Hasami sukashi algorithm

## SYNOPSIS

```bash
sukashi <directory> [OPTIONS]
```

## DESCRIPTION

Sukashi (透かし) is a filesystem pruning utility that implements the Hasami
sukashi algorithm. Like pruning a bonsai tree to let light through, this tool
intelligently thins collections of files and directories based on their creation
timestamps. It retains more recent items densely and progressively fewer older
ones, so that gaps between retained items grow geometrically with age.

The algorithm uses radix-based priority selection: each backup's age is converted
to a priority key via digit reversal, then backups are sorted by priority and the
top N are kept. This produces well-spaced representatives across all time scales.

## OPTIONS

### Basic Options

- `-r, --retain <number>`

  - Number of items to retain (default: 10)
  - Must be a non-negative integer

- `-x, --radix <number>`
  - Radix for the pruning algorithm (default: 2)
  - Controls how aggressively older backups thin out
  - With radix 2, gaps roughly double; with radix 3, they roughly triple
  - Must be at least 2

- `--base <number>`
  - Alias for `--radix` (for backward compatibility)

- `--slot-duration <seconds>`
  - Minimum time resolution in seconds (default: 1)
  - Backups closer together than this are deduplicated (most recent kept)
  - Set to a value smaller than the minimum expected interval between backups

### Filtering Options

- `--files-only`

  - Process only files (exclude directories)
  - Mutually exclusive with `--directories-only`

- `--directories-only`

  - Process only directories (exclude files)
  - Mutually exclusive with `--files-only`

- `--include-hidden`
  - Include hidden items (those starting with '.')
  - By default, hidden items are excluded

### Output Options

- `-v, --verbose`

  - Show verbose output with algorithm details
  - Displays item creation dates and pruning parameters

- `--sort-by-date`

  - Sort output by creation date instead of name
  - Default sorting is alphabetical by name

- `--dry-run`
  - Show what would be done without actually moving anything to Trash
  - Recommended for testing before actual pruning

### Deletion Options

- `--force-delete`
  - Force immediate deletion instead of moving to Trash
  - Useful for network volumes where Trash is not available

## EXAMPLES

### Basic Usage

```bash
# Prune a backup directory, keeping 10 items
sukashi /path/to/backups

# Prune with custom retention and radix
sukashi /path/to/backups --retain 20 --radix 3

# Dry run to see what would happen
sukashi /path/to/backups --dry-run --verbose
```

### File Type Filtering

```bash
# Process only files
sukashi /path/to/logs --files-only --retain 5

# Process only directories
sukashi /path/to/backups --directories-only --retain 15

# Include hidden items
sukashi /path/to/development --include-hidden --retain 8
```

### Advanced Usage

```bash
# Network volume: force delete instead of Trash
sukashi /Volumes/NAS/backups --force-delete --retain 20

# Hourly backups with 1-minute deduplication window
sukashi /path/to/hourly --slot-duration 60 --retain 30

# Safe testing with dry run
sukashi /important/backups --dry-run --verbose --retain 5
```

## ALGORITHM

The sukashi algorithm works as follows:

1. **Age Computation**: Each item's creation timestamp is converted to an age
   relative to the current time, measured in units of `slot_duration`.

2. **Deduplication**: If multiple items map to the same age slot, only the most
   recent is kept.

3. **Priority Key**: Each age is converted to a priority key `(reversed_value,
   tier)` by extracting digits in the given radix, counting them (tier), and
   reversing their order (reversed_value).

4. **Selection**: Items are sorted by priority key (ascending) and the first
   `retain` items are kept.

This produces a distribution where:
- The most recent backup (age 0) always has highest priority
- Each "round" of selection picks one representative from each time tier
- Gaps between retained backups grow geometrically with age

## BEHAVIOR

### Default Behavior

- Processes all non-hidden files and directories
- Sorts output alphabetically by name
- Moves unwanted items to macOS Trash (not permanent deletion)
- Uses radix 2 with slot duration 1 second
- Retains 10 items by default

### Output Format

```
WOULD RETAIN (3 items):
  item1 (created: Jan 1, 2024 at 12:00:00 PM)
  item2 (created: Jun 1, 2024 at 12:00:00 PM)
  item3 (created: Dec 1, 2024 at 12:00:00 PM)

WOULD MOVE TO TRASH (2 items):
  item4 (created: Mar 1, 2024 at 12:00:00 PM)
  item5 (created: Sep 1, 2024 at 12:00:00 PM)
```

## EXIT CODES

- `0`: Success
- `64`: Usage error (invalid arguments, conflicting flags)
- `65`: Data format error
- `70`: Software error

## SEE ALSO

- `sukashi-plan(1)` - stdin/stdout variant of the same algorithm for pruning
  non-filesystem collections (cloud object storage, database rows, anything
  keyed by timestamp).
- `rm(1)` - Remove files and directories
- `find(1)` - Find files by criteria
- [Algorithm Specification](docs/backup-pruning-algorithm.md)
