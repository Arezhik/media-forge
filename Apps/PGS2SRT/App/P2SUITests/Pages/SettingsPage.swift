import MediaTesting
import XCTest

// Page: the Settings window (General, Recognition, Notifications).
// Opening the window and finding it live on `MediaTesting.SettingsPage`.
// Open it from the PGS2SRT application menu. Do not click Choose… or Open System Settings.
// The title bar names the selected pane, so `root` keeps the `pgs2srt.settings` lookup.
// Controls are this window's buttons, pop-ups, switches, and steppers.
// Do not query `app.descendants`. That snapshot includes the main window and times out.

/// Settings window. Locators assume the window is up, except `open(in:)`.
@MainActor
final class SettingsPage: MediaTesting.SettingsPage {
    override class var menuTitle: String { "PGS2SRT" }

    /// Window identifier. The title is the selected pane, not "Settings".
    override var settingsWindowIdentifier: String? { "pgs2srt.settings" }

    override var root: XCUIElement {
        SettingsWindowQuery.resolve(in: app)
            ?? app.windows.matching(SettingsWindowQuery.titlePredicate).firstMatch
    }

    func waitForSettingsChrome(timeout: TimeInterval = UITestTimeout.standard) {
        let found = UITestPoll.until(timeout) {
            SettingsWindowQuery.resolve(in: self.app) != nil
        }
        XCTAssertTrue(found, "The Settings window never showed up. \(diagnostics())")
    }

    func selectTab(_ title: String) {
        let predicate = NSPredicate(format: "label == %@ OR title == %@ OR value == %@", title, title, title)
        let candidates = [
            root.buttons[title],
            root.tabs[title],
            root.radioButtons[title],
            root.toolbars.buttons[title],
            root.toolbars.radioButtons[title],
            root.tabBars.buttons[title],
            root.tabBars.radioButtons[title],
            root.segmentedControls.buttons.matching(predicate).firstMatch,
            root.radioGroups.radioButtons.matching(predicate).firstMatch,
            root.outlines.buttons.matching(predicate).firstMatch,
            root.collectionViews.buttons.matching(predicate).firstMatch,
        ]
        guard let tab = UITestWait.firstExisting(candidates, timeout: UITestTimeout.standard) else {
            XCTFail("The \(title) tab never showed up")
            return
        }
        tab.click()
    }

    func requireExistingFile(contains fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        let popup = existingFilePopup()
        popup.requireExists(timeout: UITestTimeout.standard, message: "The existing-file picker never showed up", file: file, line: line)
        XCTAssertTrue(popup.uiLabelAndValue.contains(fragment), "Existing-file picker showed \(popup.uiLabelAndValue)", file: file, line: line)
    }

    func chooseExistingFile(_ title: String) {
        let popup = existingFilePopup()
        popup.clickWhenReady(message: "The existing-file picker never showed up")
        let item = app.menuItems[title]
        item.clickWhenReady(message: "The \(title) choice never showed up")
        let shown = UITestPoll.until(UITestTimeout.standard) {
            self.existingFilePopup().uiLabelAndValue.contains(title.components(separatedBy: " ").first ?? title)
        }
        XCTAssertTrue(shown, "The existing-file picker did not show \(title). It showed \(existingFilePopup().uiLabelAndValue)")
    }

    func requireChooseMKVTrack(isOn: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let toggle = switchControl("chooseMKVTrackToggle", fallback: "Choose subtitle tracks")
        toggle.requireExists(timeout: UITestTimeout.standard, message: "The MKV track switch never showed up", file: file, line: line)
        toggle.waitUntilSwitch(
            isOn: isOn,
            message: "The MKV track switch did not become \(isOn ? "on" : "off")",
            file: file,
            line: line
        )
    }

    func clickChooseMKVTrack() {
        clickSwitch(
            "chooseMKVTrackToggle",
            fallback: "Choose subtitle tracks",
            message: "The MKV track switch never showed up"
        )
    }

    func requireLanguageEnglish(file: StaticString = #filePath, line: UInt = #line) {
        let popup = identified("languagePicker", types: [.popUpButton, .button, .menuButton])
            ?? root.popUpButtons.firstMatch
        popup.requireExists(timeout: UITestTimeout.standard, message: "The language picker never showed up", file: file, line: line)
        XCTAssertTrue(popup.uiLabelAndValue.contains("English"), "Language picker showed \(popup.uiLabelAndValue)", file: file, line: line)
    }

    func requireItalics(isOn: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let toggle = switchControl("italicsToggle", fallback: "Detect italics")
        toggle.requireExists(timeout: UITestTimeout.standard, message: "The italics switch never showed up", file: file, line: line)
        toggle.waitUntilSwitch(
            isOn: isOn,
            message: "The italics switch did not become \(isOn ? "on" : "off")",
            file: file,
            line: line
        )
    }

    func clickItalics() {
        clickSwitch(
            "italicsToggle",
            fallback: "Detect italics",
            message: "The italics switch never showed up"
        )
    }

    func incrementPictures() {
        let stepper = identified("concurrencyStepper", types: [.stepper, .group, .other]) ?? root.steppers.firstMatch
        stepper.requireExists(timeout: UITestTimeout.standard, message: "The pictures stepper never showed up")
        reveal(stepper)
        let buttons = stepper.buttons.allElementsBoundByIndex
        if buttons.count >= 2 {
            // A vertical stepper's upper button increments. A horizontal one's trailing button does.
            let spreadY = abs(buttons[0].frame.midY - buttons[1].frame.midY)
            let spreadX = abs(buttons[0].frame.midX - buttons[1].frame.midX)
            let increment: XCUIElement
            if spreadY >= spreadX {
                increment = buttons.min { $0.frame.midY < $1.frame.midY } ?? buttons[0]
            } else {
                increment = buttons.max { $0.frame.midX < $1.frame.midX } ?? buttons[0]
            }
            clickHittable(increment)
            return
        }
        // The stepper's own top half is the increment segment when it has no child buttons.
        stepper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).click()
    }

    func requireNotificationChoice(file: StaticString = #filePath, line: UInt = #line) {
        var candidates: [XCUIElement] = []
        if let popup = identified("batchNotificationPicker", types: [.popUpButton, .button, .menuButton]) {
            candidates.append(popup)
        }
        candidates.append(root.staticTexts.matchingLabelOrValue(containing: "When a batch finishes").firstMatch)
        candidates.append(root.staticTexts.matchingLabelOrValue(containing: "Send a notification").firstMatch)
        guard UITestWait.firstExisting(candidates, timeout: UITestTimeout.standard) != nil else {
            XCTFail("The notification picker never showed up", file: file, line: line)
            return
        }
    }

    private func existingFilePopup() -> XCUIElement {
        if let popup = identified("existingFilePicker", types: [.popUpButton, .button, .menuButton]) {
            return popup
        }
        return root.popUpButtons.firstMatch
    }

    /// Mini switches exist and report a value, but `click()` says they are not hittable
    /// while the General pane is clipped. Scroll the form, then click the label or the knob.
    private func clickSwitch(_ identifier: String, fallback: String, message: String) {
        let toggle = switchControl(identifier, fallback: fallback)
        toggle.requireExists(timeout: UITestTimeout.standard, message: message)
        reveal(toggle)
        if toggle.isHittable {
            toggle.click()
            return
        }
        let label = root.staticTexts.matchingLabelOrValue(containing: fallback).firstMatch
        if label.exists {
            reveal(label)
            if label.isHittable {
                label.click()
                return
            }
        }
        clickHittable(toggle)
    }

    private func reveal(_ element: XCUIElement) {
        guard !element.isHittable else { return }
        let scroll = root.scrollViews.firstMatch
        var attempt = 0
        while !element.isHittable && scroll.exists && attempt < 3 {
            scroll.swipeUp()
            attempt += 1
        }
    }

    /// `click()` scrolls the wrong view when a control is clipped, then fails as not hittable.
    /// A coordinate click hits the control's frame without that scroll.
    private func clickHittable(_ element: XCUIElement) {
        if element.isHittable {
            element.click()
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    private func switchControl(_ identifier: String, fallback: String) -> XCUIElement {
        if let control = identified(identifier, types: [.switch, .checkBox]) {
            return control
        }
        let predicate = NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@", fallback, fallback)
        return root.switches.matching(predicate).firstMatch
    }

    private func identified(_ identifier: String, types: [XCUIElement.ElementType]) -> XCUIElement? {
        UITestWait.firstExisting(UITestQuery.identified(identifier, in: root, types: types), timeout: UITestTimeout.short)
    }

    private func diagnostics() -> String {
        let windows = app.windows.allElementsBoundByIndex.map { window in
            "window title '\(window.title)' label '\(window.label)' id '\(window.identifier)'"
        }
        let dialogs = app.dialogs.allElementsBoundByIndex.map { dialog in
            "dialog title '\(dialog.title)' label '\(dialog.label)' id '\(dialog.identifier)'"
        }
        let described = windows + dialogs
        if described.isEmpty { return "No windows." }
        return described.joined(separator: "; ")
    }
}

/// Finds the Settings window when its title is the selected pane, not "Settings".
@MainActor
private enum SettingsWindowQuery {
    static let titlePredicate = NSPredicate(
        format: "title CONTAINS[c] %@ OR label CONTAINS[c] %@ OR identifier == %@",
        "Settings",
        "Settings",
        "pgs2srt.settings"
    )

    static func resolve(in app: XCUIApplication) -> XCUIElement? {
        let identified = app.windows["pgs2srt.settings"]
        if identified.exists { return identified }
        let titled = app.windows.matching(titlePredicate).firstMatch
        if titled.exists { return titled }
        if let match = app.windows.allElementsBoundByIndex.first(where: containsSettingsChrome) {
            return match
        }
        let dialog = app.dialogs["pgs2srt.settings"]
        if dialog.exists { return dialog }
        let titledDialog = app.dialogs.matching(titlePredicate).firstMatch
        if titledDialog.exists { return titledDialog }
        return nil
    }

    private static func containsSettingsChrome(_ window: XCUIElement) -> Bool {
        if window.popUpButtons["existingFilePicker"].exists { return true }
        if window.menuButtons["existingFilePicker"].exists { return true }
        if window.buttons["existingFilePicker"].exists { return true }
        if window.staticTexts.matchingLabelOrValue(containing: "Save .srt files").firstMatch.exists {
            return true
        }
        if window.staticTexts.matchingLabelOrValue(containing: "If the .srt already exists").firstMatch.exists {
            return true
        }
        return window.staticTexts.matchingLabelOrValue(containing: "Output").firstMatch.exists
    }
}
