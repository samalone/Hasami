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
ones, fitting the retained set to an exponential-decay curve so that gaps between
retained items grow with age.

The algorithm warps each backup's age into a coordinate where the target
retention density is uniform, then greedily removes the most redundant backups
until exactly `--retain` remain (always keeping the newest and oldest). See the
ALGORITHM section below.

## OPTIONS

### Basic Options

- `-r, --retain <number>`

  - Number of items to retain (default: 10)
  - Must be a non-negative integer

- `--half-life <duration>`
  - Absolute half-life: retention density halves every `<duration>` of age
  - Accepts `s`/`m`/`h`/`d`/`w` suffixes (e.g. `30d`, `12h`, `2w`); a bare number
    is seconds
  - Mutually exclusive with `--half-lives`

- `--half-lives <number>`
  - Relative half-life: how many half-lives fit across the full history span
    (e.g. `4` means `span / 4`)
  - Scale-free — the retained shape is the same regardless of how long the
    history is
  - Mutually exclusive with `--half-life`
  - Used by default with a value of 4 when neither half-life option is given
  - Must be positive

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

# Prune with custom retention and an absolute 2-week half-life
sukashi /path/to/backups --retain 20 --half-life 2w

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

# A short half-life thins older backups more aggressively
sukashi /path/to/backups --half-lives 8 --retain 30

# Safe testing with dry run
sukashi /important/backups --dry-run --verbose --retain 5
```

## ALGORITHM

The sukashi algorithm works as follows:

1. **Age Computation**: Each item's creation timestamp is converted to an age
   relative to the newest timestamp in the set. The newest item has age 0.

2. **CDF Warp**: Each age `t` is warped into `u(t) = 1 − 2^(−t / H)`, the CDF of
   the exponential-decay retention curve with half-life `H`. In the `u`
   coordinate, the target retention density is uniform.

3. **Greedy Thinning**: With the newest and oldest items pinned, the item whose
   removal would merge the smallest `u`-gap (the most redundant one) is removed
   repeatedly until exactly `--retain` items remain.

This produces a distribution where:
- The newest backup (age 0) and the oldest backup are always retained
- Recent backups are dense and older backups are sparse
- Gaps between retained backups grow with age, fitting an exponential-decay curve
- No wall-clock time is consulted — the output is a pure function of the input

## BEHAVIOR

### Default Behavior

- Processes all non-hidden files and directories
- Sorts output alphabetically by name
- Moves unwanted items to macOS Trash (not permanent deletion)
- Uses a relative half-life of `span / 4`
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
