import MediaTesting
import XCTest

// Base fixture. Playwright's test fixture / `beforeEach`.
// Subclasses get a launched app and temp folders. They do not launch the app again.
//
// Launch arguments are `--uitesting` only. Do not add `-ApplePersistenceIgnoreState YES`:
// together with `--uitesting` it suppresses the SwiftUI main Window.
// The class is `@MainActor` because it owns `XCUIApplication`.

/// Launches PGS2SRT against a fresh `UITestFixtureBuilder` root.
@MainActor
class BaseUITest: XCTestCase {
    private(set) var app: XCUIApplication!
    private(set) var fixtures: UITestFixtureBuilder!

    /// Async so this `@MainActor` type can override setUp. XCTest's synchronous
    /// `setUp` / `setUpWithError` are nonisolated.
    override func setUp() async throws {
        continueAfterFailure = false
        fixtures = try UITestFixtures.make()
        try await prepareFixtures()
        let application = XCUIApplication()
        // Replace, do not append. The only argument is `--uitesting`.
        application.launchArguments = ["--uitesting"]
        application.launchEnvironment = UITestFixtures.launchEnvironment(for: fixtures)
        application.launch()
        app = application
    }

    override func tearDown() async throws {
        UITestFixtures.cleanup(fixtures)
        fixtures = nil
        app = nil
    }

    /// Seed files before launch. The base does not create any.
    /// A drop-screen smoke needs none. Do not launch the app here, and do not override `setUp`.
    func prepareFixtures() async throws {}
}
