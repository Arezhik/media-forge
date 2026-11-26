import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// Shared command-line tool locator. Apps pass an `ExternalToolSpec`; this file
// does not name mkvmerge, mkvextract, or ffmpeg. Rules, matching the apps:
// - Search order: /opt/homebrew/bin (Apple silicon Homebrew), /usr/local/bin
//   (Intel Homebrew), /Applications/<Prefix>*.app/Contents/MacOS, then PATH.
//   An app launched from Finder gets a short PATH, so the fixed folders come first.
// - Every executable in the spec must be found. A partial install counts as missing.
// - A chosen copy is used alone. A missing chosen file does not fall back to the search.
// - Two chosen-path shapes: sibling executables (an executable, a `.app`, or a folder)
//   and a flexible file (the file itself, `.app`, `<dir>/<name>`, `<dir>/bin/<name>`,
//   or `<dir>/Contents/MacOS/<name>`). Each app calls the shape it already used.

/// What to look for. The app owns the concrete spec (name, executables, bundle prefix).
public struct ExternalToolSpec: Equatable, Sendable {
    /// Display name, such as the tool the app shows in Settings.
    public var name: String
    /// Every executable the app needs. All must be found.
    public var executables: [String]
    /// App bundles in /Applications whose names start with this.
    public var appBundlePrefix: String?
    /// Arguments that print a version on the first line, such as ["--version"] or ["-version"].
    public var versionArguments: [String]

    public init(
        name: String,
        executables: [String],
        appBundlePrefix: String? = nil,
        versionArguments: [String] = ["--version"]
    ) {
        self.name = name
        self.executables = executables
        self.appBundlePrefix = appBundlePrefix
        self.versionArguments = versionArguments
    }
}

/// Executable name to full path, for every executable in the spec.
public struct ExternalToolPaths: Equatable, Sendable {
    public var paths: [String: String]

    public init(paths: [String: String]) {
        self.paths = paths
    }

    public subscript(_ executable: String) -> String? { paths[executable] }
}

public enum ExternalTool {
    /// The fixed folders searched first, in order (Apple silicon Homebrew, then Intel Homebrew).
    public static let fixedFolders = ["/opt/homebrew/bin", "/usr/local/bin"]

    /// The search order as people read it in Settings. Same order `locate` uses.
    public static func searchLocations(_ spec: ExternalToolSpec) -> [String] {
        var places = fixedFolders
        if let prefix = spec.appBundlePrefix, !prefix.isEmpty {
            places.append("/Applications/\(prefix)*.app/Contents/MacOS")
        }
        places.append("PATH")
        return places
    }

    /// `Looked in /opt/homebrew/bin, /usr/local/bin, /Applications/Demo*.app/Contents/MacOS and PATH.`
    public static func searchDescription(_ spec: ExternalToolSpec) -> String {
        let places = searchLocations(spec)
        guard let last = places.last else { return "" }
        let head = places.dropLast().joined(separator: ", ")
        return head.isEmpty ? "Looked in \(last)." : "Looked in \(head) and \(last)."
    }

    /// Automatic search on this machine. Uses `FileManager.isExecutableFile` and lists
    /// `/Applications` before walking the candidates.
    public static func locate(_ spec: ExternalToolSpec) -> ExternalToolPaths? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? []
        return locate(
            spec,
            executableExists: { FileManager.default.isExecutableFile(atPath: $0) },
            applications: names,
            searchPath: ProcessInfo.processInfo.environment["PATH"] ?? ""
        )
    }

    /// `applications` is the names inside `/Applications`, such as `Demo.app`.
    /// `customPath` nil keeps the automatic search. An empty or missing custom path
    /// returns nil and does not search. A non-nil custom path uses `resolveCustom`
    /// and ignores `applications` and `searchPath`.
    public static func locate(
        _ spec: ExternalToolSpec,
        customPath: String? = nil,
        executableExists: (String) -> Bool,
        applications: [String],
        searchPath: String
    ) -> ExternalToolPaths? {
        if let customPath {
            return customPaths(spec, customPath: customPath, executableExists: executableExists)
        }
        let bundles = bundleNames(spec, applications: applications)
        func find(_ name: String) -> String? {
            for folder in fixedFolders {
                let path = "\(folder)/\(name)"
                if executableExists(path) { return path }
            }
            for bundle in bundles {
                let path = "/Applications/\(bundle)/Contents/MacOS/\(name)"
                if executableExists(path) { return path }
            }
            for directory in searchPath.split(separator: ":", omittingEmptySubsequences: true) {
                let path = (String(directory) as NSString).appendingPathComponent(name)
                if executableExists(path) { return path }
            }
            return nil
        }
        return paths(for: spec, find: find)
    }

    /// The copy chosen as a sibling set. `chosen` may be one executable, an app bundle,
    /// or the folder that holds the executables. A missing file is not found: there is
    /// no silent fallback. Nil or "" uses the automatic search.
    public static func locate(_ spec: ExternalToolSpec, chosen: String?) -> ExternalToolPaths? {
        guard let chosen, !chosen.isEmpty else { return locate(spec) }
        return locate(spec, chosen: chosen, executableExists: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    public static func locate(
        _ spec: ExternalToolSpec,
        chosen: String,
        executableExists: (String) -> Bool
    ) -> ExternalToolPaths? {
        let trimmed = chosen.hasSuffix("/") && chosen.count > 1 ? String(chosen.dropLast()) : chosen
        let folder: String
        if spec.executables.contains((trimmed as NSString).lastPathComponent) {
            folder = (trimmed as NSString).deletingLastPathComponent
        } else if trimmed.hasSuffix(".app") {
            folder = trimmed + "/Contents/MacOS"
        } else {
            folder = trimmed
        }
        return paths(for: spec) { executable in
            let path = (folder as NSString).appendingPathComponent(executable)
            return executableExists(path) ? path : nil
        }
    }

    /// Homebrew and `/usr/local/bin` are checked before `/Applications` is listed.
    /// A hit there returns immediately. `customPath` nil searches. Any other value,
    /// including an empty string, uses only that path.
    public static func locateInstalled(
        _ spec: ExternalToolSpec,
        customPath: String? = nil,
        executableExists: (String) -> Bool,
        applicationNames: () -> [String],
        searchPath: String
    ) -> ExternalToolPaths? {
        if customPath != nil {
            return locate(
                spec,
                customPath: customPath,
                executableExists: executableExists,
                applications: [],
                searchPath: ""
            )
        }
        if let found = locate(spec, executableExists: executableExists, applications: [], searchPath: "") {
            return found
        }
        return locate(
            spec,
            executableExists: executableExists,
            applications: applicationNames(),
            searchPath: searchPath
        )
    }

    /// Live flexible lookup. Nil `customPath` searches with `isRunnable`. Any other
    /// value, including an empty string, uses only that path.
    public static func locate(_ spec: ExternalToolSpec, customPath: String?) -> ExternalToolPaths? {
        locateInstalled(
            spec,
            customPath: customPath,
            executableExists: isRunnable,
            applicationNames: {
                (try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? []
            },
            searchPath: ProcessInfo.processInfo.environment["PATH"] ?? ""
        )
    }

    /// A regular file, or a symlink to one, that can be executed. Directories are
    /// rejected even when they are searchable. `access` follows a relative symlink
    /// from the link's own directory.
    public static func isRunnable(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue { return false }
        if access(path, X_OK) == 0 { return true }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    /// A runnable file is used as-is. A `.app` resolves to `Contents/MacOS/<name>`.
    /// A directory tries `<dir>/<name>`, `<dir>/bin/<name>`, then
    /// `<dir>/Contents/MacOS/<name>`. Anything else is rejected.
    public static func resolveCustom(
        _ path: String,
        executable: String,
        executableExists: (String) -> Bool
    ) -> String? {
        var trimmed = path
        while trimmed.count > 1 && trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.isEmpty { return nil }
        if executableExists(trimmed) { return trimmed }
        let base = trimmed as NSString
        if base.pathExtension.lowercased() == "app" {
            let inside = trimmed + "/Contents/MacOS/" + executable
            return executableExists(inside) ? inside : nil
        }
        let candidates = [
            trimmed + "/" + executable,
            trimmed + "/bin/" + executable,
            trimmed + "/Contents/MacOS/" + executable
        ]
        return candidates.first(where: executableExists)
    }

    /// The first line the tool prints for its version arguments. The child gets
    /// `ToolEnvironment.forTools()` so the locale matches a real run.
    public static func version(of executable: String, arguments: [String] = ["--version"]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ToolEnvironment.forTools()
        process.standardInput = FileHandle.nullDevice
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = (try? stdout.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let line, !line.isEmpty else { return nil }
        return line
    }

    private static func bundleNames(_ spec: ExternalToolSpec, applications: [String]) -> [String] {
        guard let prefix = spec.appBundlePrefix, !prefix.isEmpty else { return [] }
        return applications.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".app") }.sorted()
    }

    private static func paths(for spec: ExternalToolSpec, find: (String) -> String?) -> ExternalToolPaths? {
        var found: [String: String] = [:]
        for executable in spec.executables {
            guard let path = find(executable) else { return nil }
            found[executable] = path
        }
        return found.isEmpty ? nil : ExternalToolPaths(paths: found)
    }

    private static func customPaths(
        _ spec: ExternalToolSpec,
        customPath: String,
        executableExists: (String) -> Bool
    ) -> ExternalToolPaths? {
        if customPath.isEmpty { return nil }
        return paths(for: spec) { executable in
            resolveCustom(customPath, executable: executable, executableExists: executableExists)
        }
    }
}
