/// Marker for the thin AppKit helpers (drop, open panels, reveal, debug-log export).
///
/// Those helpers stay behind `canImport(AppKit)` so this target still builds on Linux,
/// where CI runs `swift test`. Nothing here draws a new layout.
public enum MediaUIMarker: Sendable {
    public static let moduleName = "MediaUI"

    #if canImport(SwiftUI)
    public static let swiftUIAvailable = true
    #else
    public static let swiftUIAvailable = false
    #endif
}
