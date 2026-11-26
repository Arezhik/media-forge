import XCTest

// Component: one queued file. Identifier `queueRow` is the container.
// The file name and the status sentence are static texts. SwiftUI puts those
// strings in `value`, so this uses `matchingLabelOrValue`, not raw `containing`.

/// A row in the conversion queue.
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
            self.nameExists(name)
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
            self.statusExists(fragment)
        }
        XCTAssertTrue(
            found,
            "The queue never showed \(fragment). Visible text: \(visibleStatus())",
            file: file,
            line: line
        )
    }

    func assertNoRow(
        named name: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let gone = UITestPoll.until(timeout) {
            !self.nameExists(name)
        }
        XCTAssertTrue(gone, "The queue row \(name) was still on screen", file: file, line: line)
    }

    func assertNoRows(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let window = app.mainWindow
        // One element type. A wide `.other` query times out on macOS.
        let present = window.groups["queueRow"].exists || window.cells["queueRow"].exists
        XCTAssertFalse(present, "A queue row was on screen", file: file, line: line)
    }

    private func nameExists(_ name: String) -> Bool {
        app.mainWindow.staticTexts.matchingLabelOrValue(equalTo: name).firstMatch.exists
    }

    private func statusExists(_ fragment: String) -> Bool {
        app.mainWindow.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists
    }

    private func visibleStatus() -> String {
        let texts = app.mainWindow.staticTexts.allElementsBoundByIndex.prefix(12).map(\.uiText)
        return texts.joined(separator: " | ")
    }
}
