import Foundation
import MediaCore

/// `.sup` and `.mkv` intake for this app. The walk lives in MediaCore.
enum SubtitleFiles {
    static let acceptedExtensions: Set<String> = ["sup", "mkv"]
    /// Words already used in skip and empty-folder notices.
    static let fileDescription = ".sup or .mkv"

    static func collect(paths: [String], listing: DirectoryListing) -> IntakeResult {
        FileIntake.collect(paths: paths, accepted: acceptedExtensions, listing: listing)
    }

    static func isSup(_ path: String) -> Bool {
        FileIntake.isAccepted(path, ["sup"])
    }

    static func isMkv(_ path: String) -> Bool {
        FileIntake.isAccepted(path, ["mkv"])
    }
}
