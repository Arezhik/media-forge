import MediaTesting
import XCTest

final class HelloWorldUITests: XCTestCase {
    private var fixtures: UITestFixtureBuilder!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // MediaTesting cannot always import XCTest. Install the skip here so a
        // missing ffmpeg still skips the UI test instead of failing it.
        UITestFixtureBuilder.setMissingFFmpegHandler { message in
            XCTSkip(message)
        }
        fixtures = try UITestFixtureBuilder()
        // Intake shows the file in the queue. Extraction does not start until Extract Subtitles.
        try fixtures.createDummyFile(in: fixtures.input, named: "sample.mp4")
    }

    override func tearDownWithError() throws {
        fixtures?.cleanup()
        fixtures = nil
    }

    func testAppOpensMainWindow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = [
            "UITEST_INPUT_DIR": fixtures.input.path,
            "UITEST_OUTPUT_DIR": fixtures.output.path,
        ]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "The main application window never showed up")

        let item = app.staticTexts["sample.mp4"]
        XCTAssertTrue(item.waitForExistence(timeout: 5),
                      "The seeded sample.mp4 row never showed up")

        XCTAssertTrue(app.buttons["Extract Subtitles"].waitForExistence(timeout: 2),
                      "The Extract Subtitles button never showed up")
    }
}
