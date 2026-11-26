#if canImport(AppKit)
import AppKit

/// Show in Finder. The caller picks the API.
///
/// MKV and MP4 use `selectFile` (a parent folder as the root stretches the Finder window, #31).
/// Debug-log export in MKV and PGS uses `activateFileViewerSelecting`. Each call site keeps its choice.
@MainActor
public enum Reveal {
    /// Selects one file in the frontmost Finder window. An empty root does not open a second window.
    public static func selectFile(path: String) {
        _ = NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    /// Opens a folder with nothing selected.
    public static func selectFolder(path: String) {
        _ = NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    /// Reveals the URLs with `activateFileViewerSelecting`.
    public static func activateViewer(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}
#endif
