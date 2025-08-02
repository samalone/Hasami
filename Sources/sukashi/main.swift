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
        
        Like pruning a bonsai tree, the algorithm treats items as base-N numbers based on their creation 
        timestamps, favoring more recent items while maintaining some representation from older periods - 
        letting the most important items "shine through."
        
        By default, processes all non-hidden files and directories. Use --files-only or --directories-only 
        to restrict the type of items processed. Use --include-hidden to process hidden items.
        
        Use --dry-run to see what would happen without actually moving anything to Trash.
        """
    )
    
    @Argument(help: "The directory containing items to prune")
    var backupDirectory: String
    
    @Option(name: .shortAndLong, help: "Number of items to retain")
    var retain: Int = 10
    
    @Option(name: .shortAndLong, help: "Base for the pruning algorithm")
    var base: Int = 2
    
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
    
    func run() throws {
        // Validate conflicting flags
        if filesOnly && directoriesOnly {
            throw ValidationError("Cannot specify both --files-only and --directories-only")
        }
        
        let url = URL(fileURLWithPath: backupDirectory)
        
        // Verify the directory exists
        guard FileManager.default.fileExists(atPath: backupDirectory) else {
            throw ValidationError("Directory '\(backupDirectory)' does not exist")
        }
        
        // Get all items with their creation dates
        let backupItems = try getBackupItems(at: url)
        
        if backupItems.isEmpty {
            let itemType = filesOnly ? "files" : (directoriesOnly ? "directories" : "items")
            print("No backup \(itemType) found in '\(backupDirectory)'")
            return
        }
        
        if verbose {
            let itemType = filesOnly ? "files" : (directoriesOnly ? "directories" : "items")
            print("Found \(backupItems.count) backup \(itemType):")
            for (name, date) in backupItems {
                print("  \(name) (created: \(formatDate(date)))")
            }
            print()
        }
        
        // Convert creation dates to TimeCodes (seconds since Unix epoch)
        let timeCodes = backupItems.map { (name, date) in
            (name: name, timeCode: TimeCode(date: date))
        }
        
        // Create BackupTree and run pruning algorithm
        let tree = BackupTree(timeCodes: timeCodes.map { $0.timeCode })
        let retained = tree.retainedBackups(base: base, retain: retain)
        let retainedSet = Set(retained)
        
        if verbose {
            print("Pruning algorithm (base \(base), retain \(retain)):")
            print("Tree representation:")
            print(tree.description(base: base))
            print()
        }
        
        // Separate retained and deleted items
        var retainedItems: [(String, Date)] = []
        var deletedItems: [(String, Date)] = []
        
        for (name, date) in backupItems {
            let timeCode = TimeCode(date: date)
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
        let itemType = filesOnly ? "files" : (directoriesOnly ? "directories" : "items")
        let actionVerb = dryRun ? "WOULD RETAIN" : "RETAINING"
        print("\(actionVerb) (\(retainedItems.count) \(itemType)):")
        for (name, date) in retainedItems {
            print("  \(name) (created: \(formatDate(date)))")
        }
        
        let deleteVerb = dryRun ? "WOULD MOVE TO TRASH" : "MOVING TO TRASH"
        print("\n\(deleteVerb) (\(deletedItems.count) \(itemType)):")
        for (name, date) in deletedItems {
            print("  \(name) (created: \(formatDate(date)))")
        }
        
        if !dryRun && !deletedItems.isEmpty {
            print("\nProceeding with sukashi (透かし) - moving \(deletedItems.count) \(itemType) to Trash...")
            
            var successCount = 0
            var failureCount = 0
            
            for (name, _) in deletedItems {
                let itemURL = url.appendingPathComponent(name)
                do {
                    try FileManager.default.trashItem(at: itemURL, resultingItemURL: nil)
                    successCount += 1
                    if verbose {
                        print("  ✓ Moved \(name) to Trash")
                    }
                } catch {
                    print("  ✗ Failed to move \(name) to Trash: \(error.localizedDescription)")
                    failureCount += 1
                }
            }
            
            print("\nSukashi completed: \(successCount) moved to Trash, \(failureCount) failed")
            if failureCount > 0 {
                print("Note: Failed items remain in the backup directory")
            }
        } else if dryRun {
            print("\nDry run completed - no \(itemType) were moved")
        }
        
        print("\nSummary: \(retainedItems.count) retained, \(deletedItems.count) \(dryRun ? "would be moved to Trash" : "moved to Trash")")
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
                    continue  // Skip directories when files-only is requested
                }
                if directoriesOnly && !isDirectory {
                    continue  // Skip files when directories-only is requested
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}