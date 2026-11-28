import MediaTesting
import XCTest

// App hook for MediaForgeCatalog's launch environment.
// Launch, fixture setup, and teardown live on MediaTesting.BaseUITest.
// This subclass supplies an empty environment. The catalog does not read UITEST_* keys.
// Tests subclass this type. They do not override setUp or call app.launch().

@MainActor
class BaseUITest: MediaTesting.BaseUITest {
    override func launchEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        [:]
    }
}
