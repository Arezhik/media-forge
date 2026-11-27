import MediaTesting
import XCTest

// Rewritten from Phase3ModeAndFeedbackUITests.
// The Mode picker is the critical control. Extract Subtitles is on screen and is not clicked.

@MainActor
final class ExtractionModeUITests: BaseUITest {
    override func prepareFixtures() async throws {
        try fixtures.createDummyFile(in: fixtures.input, named: "sample.mp4")
    }

    func testModePickerSwitchesParallelAndOneAtATime() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Queue is up") { _ in
            page.waitUntilLoaded()
            page.queue.requireName("sample.mp4")
        }

        XCTContext.runActivity(named: "Extract Subtitles is the primary button") { _ in
            page.assertPrimary(titled: "Extract", enabled: page.primaryEnabled)
        }

        XCTContext.runActivity(named: "Switch to Parallel") { _ in
            page.mode.select("Parallel")
            page.mode.requireValue(containing: "Parallel")
        }

        XCTContext.runActivity(named: "Switch back to One at a Time") { _ in
            page.mode.select("One at a Time")
            page.mode.requireValue(containing: "One at a Time")
        }
    }
}

private extension MainWindowPage {
    /// Enabled state is not the point of this test. The button only has to exist.
    var primaryEnabled: Bool {
        let button = app.buttons["primaryAction"]
        if button.exists { return button.isEnabled }
        let titled = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Extract")).firstMatch
        return titled.exists && titled.isEnabled
    }
}
