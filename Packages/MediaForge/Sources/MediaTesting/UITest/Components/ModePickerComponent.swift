#if canImport(XCTest) && os(macOS)
import XCTest

// Shared click-a-segment helper. Titles are passed in.
// MKVForge: identifier `modePicker`, accessibility label "Mode", segments Split and Remux.
// MP4SubRip: override `pickerIdentifier` (`extractionModePicker`), set
// `pickerAccessibilityLabel` to nil, and override `usesMenuSelection` plus
// `clickSegmentFallback` for the menu-style picker and the half-width click.
// The toolbar primary button can share a segment's title. Click inside the picker.

/// Segmented mode control. App components add the titles and the page they return.
@MainActor
open class ModePickerComponent {
    public let app: XCUIApplication

    /// Identifier on the control. MKVForge uses `modePicker`.
    open var pickerIdentifier: String { "modePicker" }

    /// Accessibility label fallback. MKVForge uses `Mode`. Nil skips that lookup.
    open var pickerAccessibilityLabel: String? { "Mode" }

    public init(app: XCUIApplication) {
        self.app = app
    }

    /// The mode control. Prefers the identifier, then the accessibility label.
    public var element: XCUIElement {
        let candidates = pickerCandidates()
        return candidates.first { $0.exists } ?? candidates[0]
    }

    /// Clicks the segment titled `title` inside the picker.
    /// A menu-style control is used only when `usesMenuSelection(for:)` is true.
    @discardableResult
    open func select(_ title: String, timeout: TimeInterval = UITestTimeout.standard) -> Self {
        let picker = resolvedPicker(timeout: timeout)
        if usesMenuSelection(for: picker) {
            picker.clickWhenReady(message: "The Mode picker never showed up")
            app.menuItems[title].clickWhenReady(message: "The \(title) choice never showed up")
            return self
        }
        let segments = segmentCandidates(titled: title, in: picker)
        if let segment = UITestWait.firstExisting(segments, timeout: UITestTimeout.short) {
            segment.click()
            return self
        }
        if clickSegmentFallback(title: title, picker: picker) {
            return self
        }
        XCTFail("The \(title) segment in the Mode picker never showed up")
        return self
    }

    /// MP4's narrow save bar uses a menu. MKVForge's segmented control does not.
    open func usesMenuSelection(for picker: XCUIElement) -> Bool {
        false
    }

    /// Segments inside the picker. One element type each.
    open func segmentCandidates(titled title: String, in picker: XCUIElement) -> [XCUIElement] {
        let predicate = NSPredicate(format: "label == %@ OR title == %@ OR value == %@", title, title, title)
        return [
            picker.buttons.matching(predicate).firstMatch,
            picker.radioButtons.matching(predicate).firstMatch,
            picker.checkBoxes.matching(predicate).firstMatch,
            picker.switches.matching(predicate).firstMatch,
            picker.segmentedControls.buttons.matching(predicate).firstMatch,
            picker.radioGroups.radioButtons.matching(predicate).firstMatch,
        ]
    }

    /// MP4 clicks the leading or trailing half when the control has no child buttons.
    /// Return true after handling `title`. The default does not click.
    open func clickSegmentFallback(title: String, picker: XCUIElement) -> Bool {
        false
    }

    /// Identifier, toolbar, then the accessibility label. Order matches MKVForge.
    open func pickerCandidates() -> [XCUIElement] {
        let types: [XCUIElement.ElementType] = [.segmentedControl, .radioGroup, .group, .popUpButton, .other]
        let identified = UITestQuery.identified(pickerIdentifier, in: app, types: types)
        let inToolbar = UITestQuery.identified(pickerIdentifier, in: app.toolbars.firstMatch, types: types)
        guard let pickerAccessibilityLabel else {
            return identified + inToolbar
        }
        let labeled = UITestQuery.matching(
            NSPredicate(format: "label == %@", pickerAccessibilityLabel),
            in: app,
            types: [.segmentedControl, .radioGroup, .group, .other]
        )
        return identified
            + [app.segmentedControls[pickerAccessibilityLabel], app.radioGroups[pickerAccessibilityLabel]]
            + inToolbar
            + labeled
    }

    /// The picker, or the first candidate after a failure so the caller still has an element.
    public func resolvedPicker(timeout: TimeInterval) -> XCUIElement {
        let candidates = pickerCandidates()
        if let picker = UITestWait.firstExisting(candidates, timeout: timeout) {
            return picker
        }
        XCTFail("The Mode picker never showed up")
        return candidates[0]
    }
}
#endif
