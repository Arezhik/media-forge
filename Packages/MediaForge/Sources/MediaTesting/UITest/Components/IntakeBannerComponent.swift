#if canImport(XCTest) && os(macOS)
import XCTest

// One intake notice. Identifier `intakeBanner` is on the notice text.
// The sentence is the value. MP4SubRip and PGS2SRT share this.
// MKVForge uses ToolBannerComponent instead. Do not walk `descendants(matching: .any)`.

/// The notice shown for an empty folder or a file the app does not queue.
@MainActor
open class IntakeBannerComponent {
    public let app: XCUIApplication

    /// Identifier on the notice. Both apps use `intakeBanner`.
    open var bannerIdentifier: String { "intakeBanner" }

    public init(app: XCUIApplication) {
        self.app = app
    }

    open func requireFragment(
        _ fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            self.matches(fragment)
        }
        XCTAssertTrue(found, missingMessage(fragment), file: file, line: line)
    }

    open func assertAbsent(
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

    /// Failure text when the fragment never appears. Includes the notice when it is up.
    open func missingMessage(_ fragment: String) -> String {
        let shown = visibleText()
        if shown.isEmpty {
            return "The intake banner never showed \(fragment)"
        }
        return "The intake banner never showed \(fragment). It showed \(shown)"
    }

    /// True when the identified notice or any static text on the main window contains `fragment`.
    public func matches(_ fragment: String) -> Bool {
        let window = app.mainWindow
        let identified = window.staticTexts[bannerIdentifier]
        // `uiMenuText` covers label, title, and value, which is what MP4 reads.
        // PGS puts the sentence in `value` and sometimes also in `label`.
        if identified.exists && identified.uiMenuText.contains(fragment) {
            return true
        }
        return window.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists
    }

    public func visibleText() -> String {
        let identified = app.mainWindow.staticTexts[bannerIdentifier]
        guard identified.exists else { return "" }
        return identified.uiMenuText
    }
}
#endif
