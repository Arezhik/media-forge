#if canImport(XCTest) && os(macOS)
import XCTest

// Base fixture for every app UI test.
// Launch arguments are `--uitesting` only. Do not add `-ApplePersistenceIgnoreState YES`:
// together with `--uitesting` it suppresses the SwiftUI main window.
// The class is `@MainActor` because it owns `XCUIApplication`.
// Synchronous `setUp` is nonisolated on XCTestCase, so this overrides the async one.

/// Launches the app under test against a fresh `UITestFixtureBuilder` root.
@MainActor
open class BaseUITest: XCTestCase {
    public private(set) var app: XCUIApplication!
    public private(set) var fixtures: UITestFixtureBuilder!

    open override func setUp() async throws {
        continueAfterFailure = false
        fixtures = try UITestFixtures.make()
        try await prepareFixtures()
        let application = XCUIApplication()
        // Replace, do not append. The only argument is `--uitesting`.
        application.launchArguments = ["--uitesting"]
        application.launchEnvironment = launchEnvironment(for: fixtures)
        application.launch()
        app = application
    }

    open override func tearDown() async throws {
        UITestFixtures.cleanup(fixtures)
        fixtures = nil
        app = nil
    }

    /// Seed files before launch. The base does not create any.
    /// Do not launch the app here, and do not override `setUp`.
    open func prepareFixtures() async throws {}

    /// App-specific `UITEST_*` keys. The default is MKVForge (source, output, video, audio).
    /// MP4SubRip and PGS2SRT override this and return `UITestFixtures.inputOutputEnvironment(for:)`.
    open func launchEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        UITestFixtures.mkvForgeEnvironment(for: fixtures)
    }
}
#endif
