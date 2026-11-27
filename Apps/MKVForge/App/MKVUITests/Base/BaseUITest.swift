import MediaTesting
import XCTest

// App hook for MKVForge's launch environment.
// Launch, fixture setup, and teardown live on MediaTesting.BaseUITest.
// This subclass only supplies the MKVForge `UITEST_*` keys.
// Tests subclass this type. They do not override setUp or call app.launch().

/// MKVForge UI tests. Source, output, video, and audio folders are seeded.
@MainActor
class BaseUITest: MediaTesting.BaseUITest {
    override func launchEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        UITestFixtures.mkvForgeEnvironment(for: fixtures)
    }
}
