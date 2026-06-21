import ArgumentParser
import Foundation
import Hasami

@main
struct SukashiCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sukashi",
        abstract: "Prune backup files and directories using the Hasami sukashi (透かし) algorithm - letting important items shine through.",
        discussion: """
        Sukashi (透かし) means "thinning" or "letting light through" in Japanese gardening. This tool prunes
        files and directories using the Hasami sukashi algorithm, moving unwanted items to the macOS Trash
        for safety.

        The algorithm retains more recent backups and progressively fewer older ones, fitting the retained
        set to an exponential-decay curve so that gaps between retained backups grow with age. It works with
        backups taken on irregular schedules and is deterministic.

        Use --half-life to set an absolute half-life (retention density halves every <duration> of age, e.g.
        --half-life 30d). Use --half-lives to set a half-life relative to the history span (--half-lives 4
        means span/4), which keeps the same shape at any scale. The two are mutually exclusive; the default
        is --half-lives 4.

        By default, processes all non-hidden files and directories. Use --files-only or --directories-only
        to restrict the type of items processed. Use --include-hidden to process hidden items.

        Use --dry-run to see what would happen without actually moving anything to Trash.
        Use --force-delete to immediately delete items instead of moving them to Trash (useful for network volumes).
        """
    )

    @Argument(help: "The directory containing items to prune")
    var backupDirectory: String

    @Option(name: .shortAndLong, help: "Number of items to retain")
    var retain: Int = 10

    @Option(name: .long, help: "Absolute half-life: retention density halves every <duration> of age. Accepts s/m/h/d/w suffixes (e.g. 30d); a bare number is seconds. Mutually exclusive with --half-lives.")
    var halfLife: String?

    @Option(name: .long, help: "Relative half-life: how many half-lives span the full history (e.g. 4 means span/4). Scale-free. Mutually exclusive with --half-life. Default: 4.")
    var halfLives: Double?

    @Flag(name: .shortAndLong, help: "Show verbose output with algorithm details")
    var verbose: Bool = false

    @Flag(name: .long, help: "Sort output by creation date instead of name")
    var sortByDate: Bool = false

    @Flag(name: .long, help: "Show what would be done without actually moving anything to Trash")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Include hidden items (those starting with '.')")
    var includeHidden: Bool = false

    @Flag(name: .long, help: "Process only files (exclude directories)")
    var filesOnly: Bool = false

    @Flag(name: .long, help: "Process only directories (exclude files)")
    var directoriesOnly: Bool = false

    @Flag(name: .long, help: "Force immediate deletion instead of moving to Trash (useful for network volumes)")
    var forceDelete: Bool = false

    private var itemType: String {
        filesOnly ? "files" : (directoriesOnly ? "directories" : "items")
    }

    func run() throws {
        // Validate conflicting flags
        if filesOnly && directoriesOnly {
            throw ValidationError("Cannot specify both --files-only and --directories-only")
        }
        if halfLife != nil && halfLives != nil {
            throw ValidationError("Cannot specify both --half-life and --half-lives")
        }

        // Resolve the retention policy from the half-life options.
        let halfLifeSeconds: Double?
        if let halfLife {
            guard let seconds = DurationParser.seconds(from: halfLife) else {
                throw ValidationError("Invalid --half-life value '\(halfLife)'. Use e.g. 30d, 12h, 90m, 2w, or a number of seconds.")
            }
            halfLifeSeconds = seconds
        } else {
            halfLifeSeconds = nil
        }
        let halfLivesAcrossSpan = halfLives ?? 4.0
        if halfLifeSeconds == nil && halfLivesAcrossSpan <= 0 {
            throw ValidationError("--half-lives must be positive")
        }

        let url = URL(fileURLWithPath: backupDirectory)

        // Verify the directory exists
        guard FileManager.default.fileExists(atPath: backupDirectory) else {
            throw ValidationError("Directory '\(backupDirectory)' does not exist")
        }

        // Get all items with their creation dates
        let backupItems = try getBackupItems(at: url)

        if backupItems.isEmpty {
            print("No backup \(itemType) found in '\(backupDirectory)'")
            return
        }

        if verbose {
            print("Found \(backupItems.count) backup \(itemType):")
            for (name, date) in backupItems {
                print("  \(name) (created: \(formatDate(date)))")
            }
            print()
        }

        // Convert creation dates to TimeCodes (seconds since Unix epoch)
        var timeCodeForDate: [Date: TimeCode] = [:]
        let timeCodes = backupItems.map { (name, date) -> TimeCode in
            if let existing = timeCodeForDate[date] { return existing }
            let tc = TimeCode(date: date)
            timeCodeForDate[date] = tc
            return tc
        }

        // Create BackupTree and run pruning algorithm
        let tree = BackupTree(timeCodes: timeCodes)
        let retained: [TimeCode]
        let policyDescription: String
        if let halfLifeSeconds {
            retained = tree.retainedBackups(halfLife: halfLifeSeconds, keepCount: retain)
            policyDescription = "half-life \(formatDuration(halfLifeSeconds))"
        } else {
            retained = tree.retainedBackups(halfLivesAcrossSpan: halfLivesAcrossSpan, keepCount: retain)
            policyDescription = "\(halfLivesAcrossSpan) half-lives across span"
        }
        let retainedSet = Set(retained)

        if verbose {
            print("Pruning algorithm (\(policyDescription), retain \(retain)):")
            print()
        }

        // Separate retained and deleted items
        var retainedItems: [(String, Date)] = []
        var deletedItems: [(String, Date)] = []

        for (name, date) in backupItems {
            let timeCode = timeCodeForDate[date] ?? TimeCode(date: date)
            if retainedSet.contains(timeCode) {
                retainedItems.append((name, date))
            } else {
                deletedItems.append((name, date))
            }
        }

        // Sort by date if requested
        if sortByDate {
            retainedItems.sort { $0.1 < $1.1 }
            deletedItems.sort { $0.1 < $1.1 }
        } else {
            retainedItems.sort { $0.0 < $1.0 }
            deletedItems.sort { $0.0 < $1.0 }
        }

        // Print results
        let actionVerb = dryRun ? "WOULD RETAIN" : "RETAINING"
        print("\(actionVerb) (\(retainedItems.count) \(itemType)):")
        for (name, date) in retainedItems {
            print("  \(name) (created: \(formatDate(date)))")
        }

        let deleteAction = forceDelete ? "DELETE" : "MOVE TO TRASH"
        let deleteVerb = dryRun ? "WOULD \(deleteAction)" : deleteAction
        print("\n\(deleteVerb) (\(deletedItems.count) \(itemType)):")
        for (name, date) in deletedItems {
            print("  \(name) (created: \(formatDate(date)))")
        }

        if !dryRun && !deletedItems.isEmpty {
            let actionVerb = forceDelete ? "deleting" : "moving to Trash"
            print("\nProceeding with sukashi (透かし) - \(actionVerb) \(deletedItems.count) \(itemType)...")

            var successCount = 0
            var failureCount = 0

            for (name, _) in deletedItems {
                let itemURL = url.appendingPathComponent(name)
                do {
                    if forceDelete {
                        try FileManager.default.removeItem(at: itemURL)
                    } else {
                        try FileManager.default.trashItem(at: itemURL, resultingItemURL: nil)
                    }
                    successCount += 1
                    if verbose {
                        let verb = forceDelete ? "Deleted" : "Moved to Trash"
                        print("  \(verb): \(name)")
                    }
                } catch {
                    let errorAction = forceDelete ? "delete" : "move to Trash"
                    print("  Failed to \(errorAction) \(name): \(error.localizedDescription)")
                    failureCount += 1
                }
            }

            let completionAction = forceDelete ? "deleted" : "moved to Trash"
            print("\nSukashi completed: \(successCount) \(completionAction), \(failureCount) failed")
            if failureCount > 0 {
                print("Note: Failed items remain in the backup directory")
            }
        } else if dryRun {
            let dryRunAction = forceDelete ? "deleted" : "moved to Trash"
            print("\nDry run completed - no \(itemType) were \(dryRunAction)")
        }

        let summaryAction = forceDelete ? "deleted" : "moved to Trash"
        print("\nSummary: \(retainedItems.count) retained, \(deletedItems.count) \(dryRun ? "would be \(summaryAction)" : summaryAction)")
    }

    private func getBackupItems(at url: URL) throws -> [(String, Date)] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey])

        var backupItems: [(String, Date)] = []

        for itemURL in contents {
            let itemName = itemURL.lastPathComponent

            // Skip hidden items by default
            if !includeHidden && itemName.hasPrefix(".") {
                continue
            }

            let resourceValues = try itemURL.resourceValues(forKeys: [.creationDateKey, .isDirectoryKey])

            // Apply file/directory filtering
            if let isDirectory = resourceValues.isDirectory {
                if filesOnly && isDirectory {
                    continue
                }
                if directoriesOnly && !isDirectory {
                    continue
                }
            }

            // Get creation date
            guard let creationDate = resourceValues.creationDate else {
                if verbose {
                    print("Warning: Could not get creation date for '\(itemName)'")
                }
                continue
            }

            backupItems.append((itemName, creationDate))
        }

        return backupItems
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let units: [(name: String, size: Double)] = [
            ("w", 604800), ("d", 86400), ("h", 3600), ("m", 60), ("s", 1),
        ]
        for unit in units where seconds >= unit.size {
            let value = seconds / unit.size
            return value == value.rounded()
                ? "\(Int(value))\(unit.name)"
                : String(format: "%.2f%@", value, unit.name)
        }
        return "\(seconds)s"
    }
}
