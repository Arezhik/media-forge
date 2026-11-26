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
        // A narrow save bar uses the menu-style picker. The choices are menu items,
        // not segments, until the menu is open.
        if picker.elementType == .popUpButton || picker.elementType == .menuButton {
            picker.clickWhenReady(message: "The Mode picker never showed up")
            app.menuItems[title].clickWhenReady(message: "The \(title) choice never showed up")
            return self
        }
        let predicate = NSPredicate(format: "label == %@ OR title == %@ OR value == %@", title, title, title)
        let segments = [
            picker.buttons.matching(predicate).firstMatch,
            picker.radioButtons.matching(predicate).firstMatch,
            picker.switches.matching(predicate).firstMatch,
            app.mainWindow.radioButtons[title],
            app.mainWindow.buttons[title],
        ]
        if let segment = UITestWait.firstExisting(segments, timeout: UITestTimeout.short) {
            segment.click()
            return self
        }
        // Segmented controls on macOS sometimes have no child buttons.
        // One at a Time is the leading half. Parallel is the trailing half.
        let dx: CGFloat = title == "Parallel" ? 0.75 : 0.25
        picker.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).click()
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
