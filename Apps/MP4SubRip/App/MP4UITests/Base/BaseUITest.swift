import MediaTesting
import XCTest

// App hook for MP4SubRip's launch environment.
// Launch, fixture setup, and teardown live on MediaTesting.BaseUITest.
// This subclass only supplies the MP4SubRip `UITEST_*` keys.
// Tests subclass this type. They do not override setUp or call app.launch().

/// MP4SubRip UI tests. Input is ingested like a drop. Output is the Save to folder.
@MainActor
class BaseUITest: MediaTesting.BaseUITest {
    override func launchEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        UITestFixtures.inputOutputEnvironment(for: fixtures)
    }
}
