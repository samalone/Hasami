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
timestamps, favoring more recent items while maintaining representation from
older periods.

The algorithm treats items as base-N numbers based on their creation timestamps,
using a deterministic recursive tree algorithm that allocates retention slots
among subtrees, favoring more recent backups (larger digits) while ensuring some
representation from older periods.

## OPTIONS

### Basic Options

- `-r, --retain <number>`

  - Number of items to retain (default: 10)
  - Must be a positive integer

- `-b, --base <number>`
  - Base for the pruning algorithm (default: 2)
  - Must be greater than 1
  - Common values: 2 (binary), 10 (decimal), 16 (hexadecimal)

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
  - Displays tree representation and creation dates

- `--sort-by-date`

  - Sort output by creation date instead of name
  - Default sorting is alphabetical by name

- `--dry-run`
  - Show what would be done without actually moving anything to Trash
  - Recommended for testing before actual pruning

## EXAMPLES

### Basic Usage

```bash
# Prune a backup directory, keeping 10 items
sukashi /path/to/backups

# Prune with custom retention and base
sukashi /path/to/backups --retain 20 --base 10

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
# Prune download folder with mixed content
sukashi ~/Downloads --retain 50 --base 16 --verbose

# Process log files with date sorting
sukashi /var/log --files-only --sort-by-date --retain 10

# Safe testing with dry run
sukashi /important/backups --dry-run --verbose --retain 5
```

## ALGORITHM

The sukashi algorithm works as follows:

1. **TimeCode Conversion**: Each item's creation timestamp is converted to a
   TimeCode (seconds since Unix epoch)

2. **Base-N Representation**: TimeCodes are treated as base-N numbers where N is
   the specified base

3. **Recursive Tree Algorithm**:

   - Determines the most significant digit that varies among TimeCodes
   - Recursively processes subtrees at each digit level
   - Allocates retention slots among subtrees using geometric distribution

4. **Retention Allocation**:

   - More recent items (larger digits) receive more retention slots
   - Older items (smaller digits) receive fewer slots but maintain
     representation
   - Uses a two-pass system to ensure exact allocation matches requested count

5. **Deterministic Results**:
   - Same input always produces same output
   - Algorithm is independent of file system order

## BEHAVIOR

### Default Behavior

- Processes all non-hidden files and directories
- Sorts output alphabetically by name
- Moves unwanted items to macOS Trash (not permanent deletion)
- Uses base 2 (binary) algorithm
- Retains 10 items by default

### Item Selection

The tool processes items in the specified directory based on:

1. **File Type Filtering**: If `--files-only` or `--directories-only` is
   specified
2. **Hidden Item Filtering**: Hidden items (starting with '.') are excluded
   unless `--include-hidden` is used
3. **Creation Date**: Uses the item's creation timestamp for TimeCode conversion

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

### Verbose Output

With `--verbose`, additional information is displayed:

```
Found 5 backup items:
  item1 (created: Jan 1, 2024 at 12:00:00 PM)
  item2 (created: Jun 1, 2024 at 12:00:00 PM)
  ...

Pruning algorithm (base 2, retain 3):
Tree representation:
1100111010011001001011000010000
1100110010110110100010110000000
...
```

## SAFETY FEATURES

### Dry Run Mode

Always use `--dry-run` first to see what would happen:

```bash
sukashi /path/to/items --dry-run --verbose
```

### Trash Instead of Deletion

Items are moved to macOS Trash, not permanently deleted:

- Items can be recovered from Trash
- Failed operations leave items in place
- Clear feedback on success/failure counts

### Validation

The tool validates inputs and prevents errors:

- Conflicting flags (`--files-only` + `--directories-only`)
- Invalid base values (must be > 1)
- Non-existent directories
- Missing creation dates

## EXIT CODES

- `0`: Success
- `64`: Usage error (invalid arguments, conflicting flags)
- `65`: Data format error
- `70`: Software error

## FILES

The tool operates on filesystem items and doesn't create or modify configuration
files.

## ENVIRONMENT

No environment variables are used.

## BUGS

Report bugs to the Hasami project repository.

## AUTHOR

Hasami Project - A Swift utility library for intelligent filesystem pruning.

## SEE ALSO

- `rm(1)` - Remove files and directories
- `find(1)` - Find files by criteria
- `ls(1)` - List directory contents

## HISTORY

Sukashi is part of the Hasami project, named after bonsai scissors. The
algorithm implements a deterministic pruning strategy inspired by Japanese
gardening techniques, where careful thinning allows the most important elements
to shine through.

The name "sukashi" (透かし) means "thinning" or "letting light through" in
Japanese gardening terminology.
