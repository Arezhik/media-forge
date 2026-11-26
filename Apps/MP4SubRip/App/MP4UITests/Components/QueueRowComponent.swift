import XCTest

// Component: one queued file. `queueFileName` is the file name.
// `queueStatus` is the status cell. SwiftUI puts the words in `value`.

/// A row in the extraction queue.
@MainActor
struct QueueRowComponent {
    let app: XCUIApplication

    func requireName(
        _ name: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            self.textExists(name, identifier: "queueFileName")
        }
        XCTAssertTrue(found, "The queue row \(name) never showed up", file: file, line: line)
    }

    func requireStatus(
        containing fragment: String,
        timeout: TimeInterval = UITestTimeout.batch,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            app.mainWindow.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists
        }
        XCTAssertTrue(found, "The queue never showed \(fragment)", file: file, line: line)
    }

    /// Probe of a dummy file ends as Pending or as a terminal status. Reading is not terminal.
    func waitForProbe(
        timeout: TimeInterval = UITestTimeout.batch,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        let fragments = ["Pending", "Failed", "No subtitles", "Image subs"]
        let found = UITestPoll.until(timeout) {
            fragments.contains { self.statusExists($0) }
        }
        XCTAssertTrue(found, "The row never left Reading tracks. \(visible())", file: file, line: line)
        return fragments.first { statusExists($0) } ?? ""
    }

    func assertNoRow(
        named name: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let gone = UITestPoll.until(timeout) {
            !self.textExists(name, identifier: "queueFileName")
        }
        XCTAssertTrue(gone, "The queue row \(name) was still on screen", file: file, line: line)
    }

    private func textExists(_ name: String, identifier: String) -> Bool {
        let window = app.mainWindow
        let identified = window.staticTexts[identifier]
        if identified.exists && identified.uiText.contains(name) {
            return true
        }
        return window.staticTexts.matchingLabelOrValue(equalTo: name).firstMatch.exists
    }

    private func statusExists(_ fragment: String) -> Bool {
        let window = app.mainWindow
        let identified = window.staticTexts["queueStatus"]
        if identified.exists && identified.uiText.contains(fragment) {
            return true
        }
        return window.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists
    }

    private func visible() -> String {
        app.mainWindow.staticTexts.allElementsBoundByIndex.prefix(12).map(\.uiText).joined(separator: " | ")
    }
}
