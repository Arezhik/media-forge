import XCTest

// Component: the Mode control in the save bar.
// Identifier `extractionModePicker`. Segments are One at a Time and Parallel.
// Click a segment inside the picker. Do not click Extract Subtitles.

/// One at a Time | Parallel.
@MainActor
struct ModePickerComponent {
    let app: XCUIApplication

    @discardableResult
    func select(_ title: String, timeout: TimeInterval = UITestTimeout.standard) -> Self {
        let picker = resolved(timeout: timeout)
        let predicate = NSPredicate(format: "label == %@ OR title == %@ OR value == %@", title, title, title)
        let segments = [
            picker.buttons.matching(predicate).firstMatch,
            picker.radioButtons.matching(predicate).firstMatch,
            picker.switches.matching(predicate).firstMatch,
            app.mainWindow.radioButtons[title],
            app.mainWindow.buttons[title],
        ]
        guard let segment = UITestWait.firstExisting(segments, timeout: UITestTimeout.standard) else {
            XCTFail("The \(title) segment never showed up")
            return self
        }
        segment.click()
        return self
    }

    func requireValue(
        containing fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            guard let picker = self.existing() else { return false }
            return picker.uiText.contains(fragment)
        }
        XCTAssertTrue(found, "Mode never showed \(fragment)", file: file, line: line)
    }

    private func resolved(timeout: TimeInterval) -> XCUIElement {
        if let picker = existing(timeout: timeout) {
            return picker
        }
        XCTFail("The Mode picker never showed up")
        return app.mainWindow.segmentedControls.firstMatch
    }

    private func existing(timeout: TimeInterval = UITestTimeout.short) -> XCUIElement? {
        let types: [XCUIElement.ElementType] = [.segmentedControl, .radioGroup, .group, .popUpButton]
        return UITestWait.firstExisting(
            UITestQuery.identified("extractionModePicker", in: app.mainWindow, types: types),
            timeout: timeout
        )
    }
}
