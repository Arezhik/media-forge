import Foundation

/// ffmpeg failures. `notInstalled` uses the same words as a skipped closed-caption
/// track, so a later caller cannot drift. MediaCore's `ToolFailure` stays generic.
public enum FFmpegFailure: Error, Equatable, LocalizedError {
    case notInstalled(String)
    case couldNotStart(String)
    case failed(tool: String, status: Int32)

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            return FFmpegSettings.installationMessage(customPath: FFmpegSettings.customPath())
        case let .couldNotStart(name):
            return "\(name) could not be started."
        case let .failed(tool, status):
            return "\(tool) stopped with exit code \(status). Export the debug log for details."
        }
    }
}
