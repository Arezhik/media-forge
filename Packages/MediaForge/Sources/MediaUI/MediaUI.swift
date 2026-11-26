#if canImport(SwiftUI)
import SwiftUI
#endif

/// Placeholder for MediaUI.
///
/// SwiftUI stays behind `canImport(SwiftUI)` so this target builds on Linux,
/// where CI runs `swift test`. The view below is compiled only where SwiftUI exists.
public enum MediaUIMarker: Sendable {
    public static let moduleName = "MediaUI"

    #if canImport(SwiftUI)
    public static let swiftUIAvailable = true
    #else
    public static let swiftUIAvailable = false
    #endif
}

#if canImport(SwiftUI)
@MainActor
public struct MediaUIPlaceholder: View {
    public init() {}

    public var body: some View {
        EmptyView()
    }
}
#endif
