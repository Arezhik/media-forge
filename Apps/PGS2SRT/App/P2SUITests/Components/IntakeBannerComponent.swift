import MediaTesting
import XCTest

// One intake notice. Identifier `intakeBanner` is on the notice text.
// The sentence is the value. PGS joins label and value (`uiLabelAndValue`).
// The queue window is `queueWindow`: Settings titles the selected pane,
// so `app.mainWindow`'s title filter can land on that pane.

/// The notice shown for an empty folder or a file that is not a subtitle.
@MainActor
final class IntakeBannerComponent: MediaTesting.IntakeBannerComponent {
    override func requireFragment(
        _ fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            self.matchesFragment(fragment)
        }
        XCTAssertTrue(
            found,
            "The intake banner never showed \(fragment). It showed \(visibleBannerText())",
            file: file,
            line: line
        )
    }

    override func assertAbsent(
        _ fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let gone = UITestPoll.until(timeout) {
            !self.matchesFragment(fragment)
        }
        XCTAssertTrue(gone, "The intake banner still showed \(fragment)", file: file, line: line)
    }

    private func matchesFragment(_ fragment: String) -> Bool {
        let window = app.queueWindow
        let identified = window.staticTexts[bannerIdentifier]
        if identified.exists && identified.uiLabelAndValue.contains(fragment) {
            return true
        }
        return window.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists
    }

    private func visibleBannerText() -> String {
        let identified = app.queueWindow.staticTexts[bannerIdentifier]
        guard identified.exists else { return "" }
        return identified.uiLabelAndValue
    }
}
