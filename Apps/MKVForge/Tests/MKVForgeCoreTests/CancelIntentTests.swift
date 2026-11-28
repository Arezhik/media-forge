import XCTest
@testable import MKVForgeCore

/// Setting × Option. The label stays `Cancel` until Option is held (issue #57).
final class CancelIntentTests: XCTestCase {
    func testTruthTable() {
        let offUp = CancelIntent.resolve(cancelStopsImmediately: false, optionHeld: false)
        XCTAssertEqual(offUp.behavior, .finishCurrent)
        XCTAssertEqual(offUp.buttonLabel, "Cancel")
        XCTAssertEqual(offUp.help, "Finish the current file, then stop. Hold Option to stop immediately and delete the unfinished file.")

        let offHeld = CancelIntent.resolve(cancelStopsImmediately: false, optionHeld: true)
        XCTAssertEqual(offHeld.behavior, .immediate)
        XCTAssertEqual(offHeld.buttonLabel, "Force Cancel")
        XCTAssertEqual(offHeld.help, "Stop immediately and delete the unfinished file.")

        let onUp = CancelIntent.resolve(cancelStopsImmediately: true, optionHeld: false)
        XCTAssertEqual(onUp.behavior, .immediate)
        XCTAssertEqual(onUp.buttonLabel, "Cancel")
        XCTAssertEqual(onUp.help, "Stop immediately and delete the unfinished file. Hold Option to finish the current file first.")

        let onHeld = CancelIntent.resolve(cancelStopsImmediately: true, optionHeld: true)
        XCTAssertEqual(onHeld.behavior, .finishCurrent)
        XCTAssertEqual(onHeld.buttonLabel, "Finish Current")
        XCTAssertEqual(onHeld.help, "Finish the current file, then stop.")
    }

    /// The next click reads the setting again. A cancel already chosen does not.
    func testALaterResolveSeesTheNewSetting() {
        let first = CancelIntent.resolve(cancelStopsImmediately: false, optionHeld: false)
        XCTAssertEqual(first.behavior, .finishCurrent)
        let next = CancelIntent.resolve(cancelStopsImmediately: true, optionHeld: false)
        XCTAssertEqual(next.behavior, .immediate)
        XCTAssertEqual(next.buttonLabel, "Cancel")
        XCTAssertEqual(first.behavior, .finishCurrent, "the earlier choice is unchanged")
    }

    func testStoppingAnnouncementNamesTheFile() {
        XCTAssertEqual(CancelIntent.stoppingAnnouncement(fileName: "Show.mkv"), "Stopping Show.mkv.")
    }

    func testSettingsCopy() {
        XCTAssertEqual(CancelStopsImmediately.section, "Cancel")
        XCTAssertEqual(CancelStopsImmediately.label, "Cancel stops the current file immediately")
        XCTAssertEqual(CancelStopsImmediately.identifier, "cancelStopsImmediatelyToggle")
        XCTAssertTrue(CancelStopsImmediately.helpLine1.contains("haven’t started"))
        XCTAssertEqual(CancelStopsImmediately.helpLine2, "Hold Option to use the other behavior for one click.")
    }
}
