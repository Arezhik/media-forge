import XCTest

// Component: one intake notice under the header.
// Identifier `intakeBanner` is on the notice text. The sentence is the value.
// Do not walk `descendants(matching: .any)`.

/// The notice shown for an empty folder or a file that is not a subtitle.
@MainActor
struct IntakeBannerComponent {
    let app: XCUIApplication

    func requireFragment(
        _ fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            self.matches(fragment)
        }
        XCTAssertTrue(found, "The intake banner never showed \(fragment)", file: file, line: line)
    }

    func assertAbsent(
        _ fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let gone = UITestPoll.until(timeout) {
            !self.matches(fragment)
        }
        XCTAssertTrue(gone, "The intake banner still showed \(fragment)", file: file, line: line)
    }

    private func matches(_ fragment: String) -> Bool {
        let window = app.mainWindow
        let identified = window.staticTexts["intakeBanner"]
        if identified.exists && identified.uiText.contains(fragment) {
            return true
        }
        return window.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists
    }
}
