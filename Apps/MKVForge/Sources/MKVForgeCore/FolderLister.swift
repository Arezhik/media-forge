import Foundation

/// One file a scan can see. `name` is the file name at the top level (`Show.mkv`).
/// A recursive listing stores the path relative to the scanned folder
/// (`Season 1/Episode.mkv`) so the file is opened where it actually is. The base
/// name stays the file's own name, so output is flat and two `Show.mkv` files in
/// different folders are the same name. Symbolic links are followed.
public struct FileEntry: Equatable, Sendable {
    public var name: String
    public var isRegularFile: Bool
    public var size: Int64
    public var modified: Date
    public var isReadable: Bool

    public init(name: String, isRegularFile: Bool = true, size: Int64 = 1, modified: Date = .distantPast, isReadable: Bool = true) {
        self.name = name
        self.isRegularFile = isRegularFile
        self.size = size
        self.modified = modified
        self.isReadable = isReadable
    }

    /// The last path component. Equals `name` for a top-level entry.
    public var fileName: String { (name as NSString).lastPathComponent }

    /// The file name without its last extension. Matching uses it exactly (no case
    /// folding); Swift string equality already treats NFC and NFD names as equal.
    public var baseName: String { (fileName as NSString).deletingPathExtension }

    public var pathExtension: String { (fileName as NSString).pathExtension }
}

/// Folder access for scans. `LocalFolderLister` reads the disk; tests use a fake.
public protocol FolderListing: Sendable {
    /// The top-level entries of `folder`, unfiltered. Throws when the folder can't be read.
    /// Subfolders are entries with `isRegularFile == false`. Their contents are not listed.
    func entries(in folder: String) throws -> [FileEntry]
    /// Files under `folder` at any depth. `FileEntry.name` is the path relative to
    /// `folder`. Hidden folders (dot-prefixed, including `._`) are not descended into.
    /// Package and bundle directories are not descended into (see `PackageDirectory`).
    /// Symbolic links are followed. A link that points at a folder already being
    /// walked is skipped, so a cycle cannot loop. Throws when `folder` itself can't
    /// be read. An unreadable nested folder is skipped.
    func recursiveEntries(in folder: String) throws -> [FileEntry]
    func fileExists(atPath path: String) -> Bool
}

/// Apple package and bundle directories, recognized by the directory's extension.
/// No AppKit: this list is the whole check, so Linux tests use the same rule as the Mac.
/// Comparison is case-insensitive. A matching directory is not a media folder.
public enum PackageDirectory {
    /// Directory extensions that are packages or bundles. Stored lowercased.
    public static let extensions: Set<String> = [
        "app", "appex", "bundle", "framework", "plugin", "kext", "xctest",
        "qlgenerator", "saver", "mdimporter", "prefpane", "service",
        "component", "pkg", "mpkg", "photoslibrary", "tvlibrary",
        "musiclibrary", "imovielibrary", "aplibrary", "playground", "playgroundbook",
        "xcodeproj", "xcworkspace", "xcframework", "dsym", "rtfd",
        "band", "logicx", "fcpbundle", "key", "pages", "numbers",
        "scptd", "workflow", "action", "icon", "wdgt", "sparsebundle", "docset",
    ]

    /// True when `name` (a directory's name, or a relative path) names a package.
    public static func isPackage(named name: String) -> Bool {
        let ext = ((name as NSString).lastPathComponent as NSString).pathExtension
        guard !ext.isEmpty else { return false }
        return extensions.contains(ext.lowercased())
    }
}

public struct LocalFolderLister: FolderListing {
    public init() {}

    public func entries(in folder: String) throws -> [FileEntry] {
        let fileManager = FileManager.default
        let names = try fileManager.contentsOfDirectory(atPath: folder)
        return names.map { name in
            let path = (folder as NSString).appendingPathComponent(name)
            return Self.entry(name: name, atPath: path, fileManager: fileManager)
        }
    }

    public func recursiveEntries(in folder: String) throws -> [FileEntry] {
        let fileManager = FileManager.default
        var visited: Set<String> = []
        var found: [FileEntry] = []
        try walk(folder: folder, relative: "", fileManager: fileManager, visited: &visited, found: &found)
        return found
    }

    public func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// `relative` empty means `folder` is the scan root. A cycle (a symlink back to a
    /// folder already on this walk) returns without reading it again.
    private func walk(folder: String, relative: String, fileManager: FileManager, visited: inout Set<String>, found: inout [FileEntry]) throws {
        try Task.checkCancellation()
        let resolved = URL(fileURLWithPath: folder).standardizedFileURL.resolvingSymlinksInPath().path
        guard visited.insert(resolved).inserted else { return }
        let names: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: folder)
        } catch {
            if relative.isEmpty { throw error }
            return
        }
        for name in names {
            try Task.checkCancellation()
            // Hidden files and hidden folders, including `._` AppleDouble sidecars.
            if name.hasPrefix(".") { continue }
            let child = (folder as NSString).appendingPathComponent(name)
            let relativePath = relative.isEmpty ? name : (relative as NSString).appendingPathComponent(name)
            let resolvedChild = URL(fileURLWithPath: child).resolvingSymlinksInPath().path
            guard let attributes = try? fileManager.attributesOfItem(atPath: resolvedChild) else {
                found.append(FileEntry(name: relativePath, isRegularFile: false, size: 0, isReadable: false))
                continue
            }
            let type = attributes[.type] as? FileAttributeType
            if type == .typeDirectory {
                // The name we see decides. A folder called `Shown.app` is a package
                // even when it is a symlink. Its contents are not media files.
                if PackageDirectory.isPackage(named: name) { continue }
                try walk(folder: child, relative: relativePath, fileManager: fileManager, visited: &visited, found: &found)
                continue
            }
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            found.append(FileEntry(
                name: relativePath,
                isRegularFile: type == .typeRegular,
                size: size,
                modified: attributes[.modificationDate] as? Date ?? .distantPast,
                isReadable: fileManager.isReadableFile(atPath: resolvedChild)
            ))
        }
    }

    private static func entry(name: String, atPath path: String, fileManager: FileManager) -> FileEntry {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard let attributes = try? fileManager.attributesOfItem(atPath: resolved) else {
            return FileEntry(name: name, isRegularFile: false, size: 0, isReadable: false)
        }
        let type = attributes[.type] as? FileAttributeType
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return FileEntry(
            name: name,
            isRegularFile: type == .typeRegular,
            size: size,
            modified: attributes[.modificationDate] as? Date ?? .distantPast,
            isReadable: fileManager.isReadableFile(atPath: resolved)
        )
    }
}

public enum ScanFilter {
    /// Regular files with the given extension (any letter case), skipping hidden files,
    /// which includes macOS `._` AppleDouble files at any depth. A dot-prefixed path
    /// component is hidden too. A file inside a package or bundle directory
    /// (`Shown.app`, `Notes.rtfd`) is skipped as well. Subfolders are not files.
    public static func candidates(_ entries: [FileEntry], fileExtension: String) -> [FileEntry] {
        entries.filter { entry in
            !isHidden(entry.name)
                && !containsPackage(entry.name)
                && entry.isRegularFile
                && entry.pathExtension.lowercased() == fileExtension.lowercased()
                && !entry.baseName.isEmpty
        }
    }

    /// True when a parent of `relativePath` is a package or bundle directory.
    static func containsPackage(_ relativePath: String) -> Bool {
        let parts = (relativePath as NSString).pathComponents
        guard parts.count > 1 else { return false }
        return parts.dropLast().contains { PackageDirectory.isPackage(named: $0) }
    }

    /// True when any path component is dot-prefixed (hidden files and folders).
    static func isHidden(_ relativePath: String) -> Bool {
        (relativePath as NSString).pathComponents.contains { part in
            part.hasPrefix(".") && part != "." && part != ".."
        }
    }

    /// Candidates grouped by exact base name. More than one entry means a duplicate name.
    public static func byBaseName(_ entries: [FileEntry]) -> [String: [FileEntry]] {
        var groups: [String: [FileEntry]] = [:]
        for entry in entries {
            groups[entry.baseName, default: []].append(entry)
        }
        for key in groups.keys {
            groups[key]?.sort { $0.name < $1.name }
        }
        return groups
    }
}
