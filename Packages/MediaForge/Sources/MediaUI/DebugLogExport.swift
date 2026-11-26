#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// Fallback save panel and Finder reveal for the debug log.
///
/// The apps still write the Desktop copy, show the alerts, and pass their own file name and title.
/// Reveal uses whichever API that app already used.
@MainActor
public enum DebugLogExport {
    public struct SaveOptions: Equatable, Sendable {
        public var fileName: String
        public var title: String
        public var prompt: String
        public var message: String
        public var canCreateDirectories: Bool
        public var allowedContentTypes: [UTType]

        public init(
            fileName: String,
            title: String,
            prompt: String,
            message: String,
            canCreateDirectories: Bool = true,
            allowedContentTypes: [UTType] = [.plainText]
        ) {
            self.fileName = fileName
            self.title = title
            self.prompt = prompt
            self.message = message
            self.canCreateDirectories = canCreateDirectories
            self.allowedContentTypes = allowedContentTypes
        }

        /// `NSSavePanel` members are main-actor isolated. Nested types do not inherit
        /// `DebugLogExport`'s isolation, so this writer is marked on its own.
        @MainActor
        public func apply(to panel: NSSavePanel) {
            panel.title = title
            panel.prompt = prompt
            panel.nameFieldStringValue = fileName
            panel.canCreateDirectories = canCreateDirectories
            panel.allowedContentTypes = allowedContentTypes
            panel.message = message
        }
    }

    /// Which Finder call to make after a log is saved. The app chooses.
    public enum RevealChoice: Equatable, Sendable {
        /// `NSWorkspace.selectFile(_:inFileViewerRootedAtPath:)` with an empty root. MP4.
        case selectFile
        /// `NSWorkspace.activateFileViewerSelecting`. MKV and PGS.
        case activateViewer
    }

    /// Modal save panel. Nil when the person cancels.
    public static func chooseDestination(_ options: SaveOptions) -> URL? {
        let panel = NSSavePanel()
        options.apply(to: panel)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public static func reveal(_ url: URL, choice: RevealChoice) {
        switch choice {
        case .selectFile:
            Reveal.selectFile(path: url.path)
        case .activateViewer:
            Reveal.activateViewer([url])
        }
    }
}
#endif
