# Hasami 🌸

**Intelligent Filesystem Pruning with Japanese Precision**

Hasami is a Swift utility library that implements the sukashi (透かし) algorithm for intelligent filesystem pruning. Like pruning a bonsai tree to let light through, Hasami carefully thins collections of files and directories, favoring more recent items while maintaining representation from older periods.

## What is Sukashi?

Sukashi (透かし) means "thinning" or "letting light through" in Japanese gardening. The algorithm treats filesystem items as base-N numbers based on their creation timestamps, using a deterministic recursive tree algorithm that intelligently allocates retention slots.

### Key Features

- **🎯 Deterministic**: Same input always produces same output
- **🌱 Intelligent**: Favors recent items while preserving history
- **🛡️ Safe**: Moves to Trash, not permanent deletion
- **🔧 Flexible**: Works with files, directories, or both
- **⚡ Fast**: Efficient Swift implementation

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/hasami.git
cd hasami

# Build the project
swift build

# Run sukashi
swift run sukashi --help
```

### Basic Usage

```bash
# Prune a backup directory (keep 10 items)
swift run sukashi /path/to/backups

# See what would happen first
swift run sukashi /path/to/backups --dry-run --verbose

# Custom retention and base
swift run sukashi /path/to/backups --retain 20 --base 10
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

### Download Folder Organization

```bash
# Prune downloads, keeping 50 items
swift run sukashi ~/Downloads --retain 50 --base 16

# Sort by date for better overview
swift run sukashi ~/Downloads --sort-by-date --retain 30
```

## How It Works

### The Algorithm

1. **TimeCode Conversion**: Each item's creation timestamp becomes a TimeCode
2. **Base-N Representation**: TimeCodes are treated as base-N numbers
3. **Recursive Tree Processing**: Algorithm works digit by digit
4. **Geometric Distribution**: More recent items get more retention slots
5. **Deterministic Results**: Same input always produces same output

### Example with Base 2

```
Items with timestamps:
- item1: 1704067200 (2024-01-01)
- item2: 1717200000 (2024-06-01)  
- item3: 1735689600 (2024-12-01)

Binary representation:
- item1: 1100111010011001001011000010000
- item2: 1100110010110110100010110000000
- item3: 1100101100100101110111110010000

Algorithm retains: item1, item3 (favoring recent while keeping history)
```

## Command Line Options

### Basic Options

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --retain <number>` | Items to retain | 10 |
| `-b, --base <number>` | Algorithm base | 2 |
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

## Safety Features

### 🛡️ Dry Run Mode

Always test first:

```bash
swift run sukashi /important/data --dry-run --verbose
```

### 🗑️ Trash Instead of Deletion

Items are moved to macOS Trash, not permanently deleted:

- Recoverable from Trash
- Failed operations leave items in place
- Clear success/failure feedback

### ✅ Validation

The tool prevents common errors:

- Conflicting flags
- Invalid base values
- Non-existent directories
- Missing creation dates

## Use Cases

### Backup Management
- Keep recent backups while maintaining historical representation
- Automate cleanup of backup directories
- Maintain backup rotation schedules

### Log File Cleanup
- Prevent log directories from growing too large
- Keep recent logs while preserving older ones
- Automate log rotation

### Download Organization
- Keep recent downloads while maintaining variety
- Prevent download folders from becoming unwieldy
- Maintain download history

### Development Artifacts
- Clean up build artifacts and temporary files
- Maintain recent development snapshots
- Organize project backups

## Advanced Usage

### Custom Bases

Different bases affect the algorithm's behavior:

```bash
# Binary (base 2) - most aggressive pruning
swift run sukashi /path --base 2 --retain 5

# Decimal (base 10) - balanced approach  
swift run sukashi /path --base 10 --retain 10

# Hexadecimal (base 16) - more conservative
swift run sukashi /path --base 16 --retain 20
```

### Verbose Output

See the algorithm in action:

```bash
swift run sukashi /path --verbose --dry-run
```

Output includes:
- Item creation dates
- Tree representation
- Algorithm parameters
- Retention decisions

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Clone and setup
git clone https://github.com/your-username/hasami.git
cd hasami

# Build and test
swift build
swift test

# Run with development version
swift run sukashi --help
```

## Documentation

- [Man Page](sukashi.1.md) - Complete command reference
- [API Documentation](docs/) - Library documentation
- [Algorithm Details](docs/algorithm.md) - Technical implementation

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by Japanese bonsai pruning techniques
- Built with Swift and the ArgumentParser framework
- Uses swift-collections for efficient data structures

---

**Hasami** - Where precision meets pruning 🌸✂️ 