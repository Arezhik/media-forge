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
        XCTAssertTrue(found, "Save to never showed \(fragment). \(describe())", file: file, line: line)
    }

    private func matches(_ fragment: String) -> Bool {
        let window = app.mainWindow
        let types: [XCUIElement.ElementType] = [.menuButton, .button, .popUpButton, .staticText]
        for element in UITestQuery.identified("saveToMenu", in: window, types: types) where element.exists {
            if element.uiText.localizedCaseInsensitiveContains(fragment) {
                return true
            }
            // The path is a Text inside the menu button. The button's own title can be empty.
            if element.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists {
                return true
            }
        }
        return window.menuButtons.matchingLabelOrValue(containing: fragment).firstMatch.exists
    }

    private func describe() -> String {
        let types: [XCUIElement.ElementType] = [.menuButton, .button, .popUpButton]
        let identified = UITestQuery.identified("saveToMenu", in: app.mainWindow, types: types)
        guard let element = identified.first(where: \.exists) else {
            return "saveToMenu was not on screen."
        }
        let children = element.staticTexts.allElementsBoundByIndex.prefix(4).map(\.uiText).joined(separator: " | ")
        return "Menu showed \(element.uiText). Children \(children)."
    }
}
