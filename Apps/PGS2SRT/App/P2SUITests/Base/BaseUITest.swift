import MediaTesting
import XCTest

// App hook for PGS2SRT's launch environment.
// Launch, fixture setup, and teardown live on MediaTesting.BaseUITest.
// This subclass only supplies the PGS2SRT `UITEST_*` keys.
// Tests subclass this type. They do not override setUp or call app.launch().

/// PGS2SRT UI tests. Input is ingested like a drop. Output is the chosen folder.
@MainActor
class BaseUITest: MediaTesting.BaseUITest {
    override func launchEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        UITestFixtures.inputOutputEnvironment(for: fixtures)
    }
}
