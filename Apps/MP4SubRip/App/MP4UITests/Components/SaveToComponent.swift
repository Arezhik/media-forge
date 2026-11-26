import XCTest

// Component: the Save to menu. Identifier `saveToMenu`.
// During a UI test the title is the abbreviated UITEST_OUTPUT_DIR path.

/// Where the .srt files are written.
@MainActor
struct SaveToComponent {
    let app: XCUIApplication

    func requireShows(
        _ fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            self.matches(fragment)
        }
        XCTAssertTrue(found, "Save to never showed \(fragment)", file: file, line: line)
    }

    private func matches(_ fragment: String) -> Bool {
        let window = app.mainWindow
        let types: [XCUIElement.ElementType] = [.menuButton, .button, .popUpButton, .staticText]
        for element in UITestQuery.identified("saveToMenu", in: window, types: types) where element.exists {
            if element.uiText.contains(fragment) {
                return true
            }
        }
        return window.menuButtons.matchingLabelOrValue(containing: fragment).firstMatch.exists
    }
}
