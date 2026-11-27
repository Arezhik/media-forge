import MediaTesting
import XCTest

// One at a Time | Parallel. Identifier `extractionModePicker`.
// The shared helper clicks a segment inside the picker.
// A narrow save bar uses the menu-style picker. The choices are menu items.
// Segmented controls on macOS sometimes have no child buttons.
// One at a Time is the leading half. Parallel is the trailing half.
// Do not click Extract Subtitles.

/// One at a Time | Parallel.
@MainActor
final class ModePickerComponent: MediaTesting.ModePickerComponent {
    override var pickerIdentifier: String { "extractionModePicker" }

    /// MP4's picker has no accessibility label named Mode.
    override var pickerAccessibilityLabel: String? { nil }

    override func usesMenuSelection(for picker: XCUIElement) -> Bool {
        picker.elementType == .popUpButton || picker.elementType == .menuButton
    }

    override func clickSegmentFallback(title: String, picker: XCUIElement) -> Bool {
        let dx: CGFloat = title == "Parallel" ? 0.75 : 0.25
        picker.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).click()
        return true
    }

    func requireValue(
        containing fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            let picker = self.element
            guard picker.exists else { return false }
            return picker.uiMenuText.contains(fragment)
        }
        XCTAssertTrue(found, "Mode never showed \(fragment)", file: file, line: line)
    }
}
