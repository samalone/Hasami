# Hasami Documentation

Welcome to the Hasami documentation! This guide will help you understand and use the Hasami filesystem pruning utility.

## 📚 Documentation Index

### User Documentation

- **[README.md](../README.md)** - Project overview and quick start guide
- **[sukashi.1.md](../sukashi.1.md)** - Complete command reference (man page style)

### Technical Documentation

- **[algorithm.md](algorithm.md)** - Detailed algorithm implementation and theory

## 🔑 Key Features

### Chronological Consistency

Hasami's sukashi algorithm maintains **chronological consistency**, ensuring that when backups are created in chronological order, no older pruning operation removes files that would be retained by a newer pruning operation. This property makes the algorithm safe for automated backup systems and provides predictable, regret-free pruning behavior.

For detailed technical information about this property and how the `base` parameter affects backup distribution, see **[algorithm.md](algorithm.md)**.

## 🚀 Quick Start

1. **Install**: `swift build`
2. **Test**: `swift run sukashi --help`
3. **Use**: `swift run sukashi /path/to/items --dry-run`

## 📖 Documentation Structure

### For Users
- **README.md**: Start here for project overview and examples
- **sukashi.1.md**: Complete command reference with all options

### For Developers
- **algorithm.md**: Technical details of the sukashi algorithm
- **Source Code**: Well-documented Swift implementation

## 🎯 Documentation Goals

- **Comprehensive**: Cover all features and use cases
- **Accessible**: Clear examples and explanations
- **Technical**: Detailed implementation information
- **User-Focused**: Practical guidance for real-world usage

## 📝 Contributing to Documentation

When contributing to Hasami documentation:

1. **User-First**: Write for the end user, not the developer
2. **Examples**: Include practical, real-world examples
3. **Accuracy**: Ensure documentation matches implementation
4. **Clarity**: Use clear, concise language

## 🔗 Related Resources

- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [ArgumentParser Framework](https://github.com/apple/swift-argument-parser)
- [Swift Collections](https://github.com/apple/swift-collections)

---

*Documentation is a living document. Please help us keep it accurate and helpful!*