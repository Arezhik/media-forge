import Foundation
import MediaCore

extension ExternalToolSpec {
    /// ffmpeg. A chosen path is flexible: the file itself, a `.app`, or a folder
    /// (`<dir>/ffmpeg`, `<dir>/bin/ffmpeg`, or `<dir>/Contents/MacOS/ffmpeg`).
    /// `nil` custom path keeps the automatic search. An empty or missing custom
    /// path does not fall back.
    public static let primary = ExternalToolSpec(
        name: "ffmpeg",
        executables: ["ffmpeg"],
        appBundlePrefix: "ffmpeg",
        versionArguments: ["-version"]
    )
}

/// Where a located binary came from. Automatic is the Homebrew search.
public enum ToolSource: Equatable, Sendable {
    case automatic
    case chosenInSettings
}

/// Path and version from one lookup. The launch line and the debug-log header
/// both print this, so they can't describe two different results.
public struct LocatedTool: Equatable, Sendable {
    public var name: String
    public var path: String
    public var version: String
    public var source: ToolSource

    public init(name: String, path: String, version: String, source: ToolSource = .automatic) {
        self.name = name
        self.path = path
        self.version = version
        self.source = source
    }
}

/// One `describe` result, including a custom path that could not be run.
/// The launch line and the debug-log header both take this, so a missing
/// chosen file is described the same way in both places.
public struct ToolReport: Equatable, Sendable {
    public var located: LocatedTool?
    /// `nil` is automatic. An empty string is custom with nothing chosen.
    public var customPath: String?

    public init(located: LocatedTool?, customPath: String?) {
        self.located = located
        self.customPath = customPath
    }
}

/// Wording shared by the launch log and the exported debug-log header.
public enum ToolDetection {
    public struct Line: Equatable, Sendable {
        public var message: String
        public var isError: Bool

        public init(message: String, isError: Bool) {
            self.message = message
            self.isError = isError
        }
    }

    public static func logLine(
        spec: ExternalToolSpec,
        located: LocatedTool?,
        customPath: String? = nil
    ) -> Line {
        if let located {
            return Line(
                message: "\(located.name) found (\(sourcePhrase(located.source))) \(located.path), version \(located.version)",
                isError: false
            )
        }
        if let customPath {
            if customPath.isEmpty {
                return Line(message: "\(spec.name) not chosen", isError: true)
            }
            return Line(
                message: "\(spec.name) not found (chosen in Settings) \(customPath); automatic was not used",
                isError: true
            )
        }
        return Line(message: "\(spec.name) not found", isError: true)
    }

    public static func facts(
        spec: ExternalToolSpec,
        located: LocatedTool?,
        customPath: String? = nil
    ) -> [DebugFact] {
        if let located {
            return [
                DebugFact(spec.name, "(\(sourcePhrase(located.source))) \(located.path)"),
                DebugFact("\(spec.name) version", located.version)
            ]
        }
        if let customPath {
            if customPath.isEmpty {
                return [
                    DebugFact(spec.name, "not chosen"),
                    DebugFact("\(spec.name) version", "not found")
                ]
            }
            return [
                DebugFact(spec.name, "not found (chosen in Settings) \(customPath); automatic was not used"),
                DebugFact("\(spec.name) version", "not found")
            ]
        }
        return [
            DebugFact(spec.name, "not found"),
            DebugFact("\(spec.name) version", "not found")
        ]
    }

    private static func sourcePhrase(_ source: ToolSource) -> String {
        switch source {
        case .automatic:
            return "automatic"
        case .chosenInSettings:
            return "chosen in Settings"
        }
    }
}

extension ExternalTool {
    /// Locates ffmpeg and reads its version. The saved Settings choice is used
    /// unless `customPath` is passed. `nil` there means automatic.
    public static func describe(_ spec: ExternalToolSpec = .primary) -> ToolReport {
        describe(spec, customPath: FFmpegSettings.customPath())
    }

    public static func describe(_ spec: ExternalToolSpec, customPath: String?) -> ToolReport {
        let executable = spec.executables.first ?? spec.name
        guard let path = locate(spec, customPath: customPath)?[executable] else {
            return ToolReport(located: nil, customPath: customPath)
        }
        let version = version(of: path, arguments: spec.versionArguments) ?? "unknown"
        let source: ToolSource = customPath == nil ? .automatic : .chosenInSettings
        return ToolReport(
            located: LocatedTool(name: spec.name, path: path, version: version, source: source),
            customPath: customPath
        )
    }
}

/// Saved ffmpeg choice. Automatic keeps the Homebrew search. A custom path is
/// used alone; a missing file does not fall back.
public enum FFmpegSettings {
    public static let placementKey = "ffmpegPlacement"
    public static let pathKey = "ffmpegPath"
    public static let automatic = "automatic"
    public static let custom = "custom"

    /// Defaults used when a caller does not pass a store. The app points this
    /// at the UI-testing suite when launched with `--uitesting`, and leaves it
    /// as `UserDefaults.standard` otherwise. Set once at launch.
    public nonisolated(unsafe) static var defaultsStore: UserDefaults = .standard

    /// `nil` is automatic. An empty string is custom with nothing chosen.
    public static func customPath(in defaults: UserDefaults = FFmpegSettings.defaultsStore) -> String? {
        let placement = defaults.string(forKey: placementKey) ?? automatic
        guard placement == custom else { return nil }
        return defaults.string(forKey: pathKey) ?? ""
    }

    public static func summary(customPath: String?, resolvedPath: String?) -> String {
        if let customPath {
            if customPath.isEmpty { return "ffmpeg not chosen" }
            return "ffmpeg chosen \(customPath)"
        }
        if let resolvedPath {
            return "ffmpeg automatic \(resolvedPath)"
        }
        return "ffmpeg not found"
    }

    static func installationMessage(customPath: String?) -> String {
        guard let customPath else {
            return "Closed-caption extraction needs ffmpeg. Install it with Homebrew, or choose it in Settings."
        }
        if customPath.isEmpty {
            return "Choose ffmpeg in Settings."
        }
        return "The ffmpeg chosen in Settings can't be found. Choose it again in Settings."
    }

    /// The executable a chosen file, app, or folder points at, when it can be run.
    public static func runnableExecutable(at path: String) -> String? {
        let name = ExternalToolSpec.primary.executables.first ?? "ffmpeg"
        return ExternalTool.resolveCustom(path, executable: name, executableExists: ExternalTool.isRunnable)
    }

    /// Pick-time check. The resolved program must run, and its first version line must mention ffmpeg.
    public static func validatedExecutable(at path: String) -> String? {
        guard let resolved = runnableExecutable(at: path) else { return nil }
        guard let line = ExternalTool.version(of: resolved, arguments: ExternalToolSpec.primary.versionArguments) else {
            return nil
        }
        guard line.range(of: "ffmpeg", options: .caseInsensitive) != nil else { return nil }
        return resolved
    }
}
