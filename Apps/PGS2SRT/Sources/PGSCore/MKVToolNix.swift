import Foundation
import MediaCore

extension ExternalToolSpec {
    /// `mkvmerge` and `mkvextract` together. A partial install counts as missing.
    /// PGS has no chosen-path override; it always searches.
    public static let mkvToolNix = ExternalToolSpec(
        name: "MKVToolNix",
        executables: ["mkvmerge", "mkvextract"],
        appBundlePrefix: "MKVToolNix",
        versionArguments: ["--version"]
    )
}

/// Paths to the two MKVToolNix commands this app shells out to.
public struct MKVToolPaths: Equatable, Sendable {
    public var mkvmerge: String
    public var mkvextract: String

    public init(mkvmerge: String, mkvextract: String) {
        self.mkvmerge = mkvmerge
        self.mkvextract = mkvextract
    }
}

/// A failure while asking MKVToolNix about a file or pulling a track out of it.
public enum MKVFailure: Error, Equatable, LocalizedError {
    case unreadableTracks
    case extractFailed
    case couldNotStartTool

    public var errorDescription: String? {
        switch self {
        case .unreadableTracks:
            return "Could not read the subtitle tracks in this MKV."
        case .extractFailed:
            return "Could not extract the PGS subtitles from this MKV."
        case .couldNotStartTool:
            return "MKVToolNix could not be started."
        }
    }
}

/// Where `mkvmerge` and `mkvextract` are on this Mac.
public enum MKVToolNix {
    /// Looks in Homebrew's usual folders, an MKVToolNix app bundle, then `PATH`.
    /// Both tools have to be found. A partial install is treated as missing.
    public static func locate() -> MKVToolPaths? {
        paths(ExternalTool.locate(.mkvToolNix))
    }

    /// `applications` is the names inside `/Applications`, such as `MKVToolNix.app`.
    public static func locate(
        executableExists: (String) -> Bool,
        applications: [String],
        searchPath: String
    ) -> MKVToolPaths? {
        paths(ExternalTool.locate(
            .mkvToolNix,
            executableExists: executableExists,
            applications: applications,
            searchPath: searchPath
        ))
    }

    /// The first line of `mkvmerge --version`, such as `mkvmerge v86.0 ('Winter') 64-bit`.
    public static func version(of executable: String) -> String? {
        ExternalTool.version(of: executable, arguments: ExternalToolSpec.mkvToolNix.versionArguments)
    }

    private static func paths(_ located: ExternalToolPaths?) -> MKVToolPaths? {
        guard let mkvmerge = located?["mkvmerge"], let mkvextract = located?["mkvextract"] else {
            return nil
        }
        return MKVToolPaths(mkvmerge: mkvmerge, mkvextract: mkvextract)
    }
}

/// One run of an external command. Cancelling the calling task terminates the process.
public struct MKVCommandResult: Equatable, Sendable {
    public var status: Int32
    public var standardOutput: Data
    public var standardError: Data

    public init(status: Int32, standardOutput: Data, standardError: Data) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum MKVCommand {
    /// Runs through MediaCore. The log category stays `.mkv`. A launch failure
    /// stays `MKVFailure.couldNotStartTool` so the sentence the queue shows does not change.
    /// `LC_ALL` comes from `ToolCommand`. An empty stderr line is not added; PGS did not log one.
    public static func run(executable: String, arguments: [String]) async throws -> MKVCommandResult {
        let result: ToolCommandResult
        do {
            result = try await ToolCommand.run(
                executable: executable,
                arguments: arguments,
                logCategory: .mkv,
                logEmptyStandardError: false
            )
        } catch ToolFailure.couldNotStart {
            throw MKVFailure.couldNotStartTool
        }
        return MKVCommandResult(
            status: result.status,
            standardOutput: result.standardOutput,
            standardError: result.standardError
        )
    }

    /// `mkvmerge -J <file>`. The returned data is the JSON document.
    public static func identify(tool: String, file: String) async throws -> Data {
        let result = try await run(executable: tool, arguments: ["-J", file])
        guard result.status == 0 else { throw MKVFailure.unreadableTracks }
        return result.standardOutput
    }

    /// `mkvextract <file> tracks <id>:<destination>` for one track.
    public static func extract(tool: String, file: String, trackID: Int, destination: String) async throws {
        try await extract(tool: tool, file: file, tracks: [(trackID, destination)])
    }

    /// One `mkvextract` invocation for every selected track.
    public static func extract(tool: String, file: String, tracks: [(Int, String)]) async throws {
        var arguments = [file, "tracks"]
        arguments.append(contentsOf: tracks.map { "\($0.0):\($0.1)" })
        let result = try await run(executable: tool, arguments: arguments)
        let wroteAll = tracks.allSatisfy { FileManager.default.fileExists(atPath: $0.1) }
        guard result.status == 0, wroteAll else {
            throw MKVFailure.extractFailed
        }
    }
}

/// Locate, list tracks, and extract. Tests substitute their own.
public struct MKVClient: Sendable {
    public var locate: @Sendable () -> MKVToolPaths?
    public var identify: @Sendable (String, String) async throws -> Data
    public var extract: @Sendable (String, String, Int, String) async throws -> Void
    /// One call extracts every track. The default runs `extract` once per track.
    public var extractMany: @Sendable (String, String, [(Int, String)]) async throws -> Void

    public init(
        locate: @escaping @Sendable () -> MKVToolPaths?,
        identify: @escaping @Sendable (String, String) async throws -> Data,
        extract: @escaping @Sendable (String, String, Int, String) async throws -> Void,
        extractMany: (@Sendable (String, String, [(Int, String)]) async throws -> Void)? = nil
    ) {
        self.locate = locate
        self.identify = identify
        self.extract = extract
        self.extractMany = extractMany ?? { tool, file, pairs in
            for pair in pairs {
                try await extract(tool, file, pair.0, pair.1)
            }
        }
    }

    public static let live = MKVClient(
        locate: { MKVToolNix.locate() },
        identify: { tool, file in
            try await MKVCommand.identify(tool: tool, file: file)
        },
        extract: { tool, file, trackID, destination in
            try await MKVCommand.extract(tool: tool, file: file, trackID: trackID, destination: destination)
        },
        extractMany: { tool, file, tracks in
            try await MKVCommand.extract(tool: tool, file: file, tracks: tracks)
        }
    )

    /// No MKVToolNix. An MKV row is skipped instead of converted.
    public static let unavailable = MKVClient(
        locate: { nil },
        identify: { _, _ in throw MKVFailure.couldNotStartTool },
        extract: { _, _, _, _ in throw MKVFailure.couldNotStartTool }
    )
}

/// Lists PGS tracks and extracts the selected ones. Tests substitute their own.
public struct MKVNativeClient: Sendable {
    public var listTracks: @Sendable (String) throws -> [PGSSubtitleTrack]
    public var extract: @Sendable (String, Set<Int>, @escaping @Sendable (Int64, Int64) -> Void) throws -> [Int: Data]

    public init(
        listTracks: @escaping @Sendable (String) throws -> [PGSSubtitleTrack],
        extract: @escaping @Sendable (String, Set<Int>, @escaping @Sendable (Int64, Int64) -> Void) throws -> [Int: Data]
    ) {
        self.listTracks = listTracks
        self.extract = extract
    }

    public static let live = MKVNativeClient(
        listTracks: { path in
            try MKVReader.listTracks(at: path)
        },
        extract: { path, trackIDs, progress in
            try MKVReader.extract(at: path, trackIDs: trackIDs, onProgress: progress)
        }
    )
}
