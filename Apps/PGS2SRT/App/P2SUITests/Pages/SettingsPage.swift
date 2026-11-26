import XCTest

// Page: the Settings window (General, Recognition, Notifications).
// Open it from the PGS2SRT application menu. Do not click Choose… or Open System Settings.
// Controls are this window's buttons, pop-ups, switches, and steppers.
// Do not query `app.descendants`. That snapshot includes the main window and times out.

/// Settings window. Locators assume the window is up, except `open(in:)`.
@MainActor
final class SettingsPage: BasePage {
    override var root: XCUIElement {
        app.windows.matching(
            NSPredicate(format: "title CONTAINS[c] %@ OR label CONTAINS[c] %@", "Settings", "Settings")
        ).firstMatch
    }

    @discardableResult
    static func open(in app: XCUIApplication) -> SettingsPage {
        let appMenu = app.menuBars.firstMatch.menuBarItems["PGS2SRT"]
        appMenu.clickWhenReady(message: "The PGS2SRT application menu never showed up")
        let item = appMenu.menuItems.matching(
            NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@", "Settings", "Settings")
        ).firstMatch
        item.clickWhenReady(message: "The Settings menu item never showed up")
        return SettingsPage(app: app)
    }

    func waitForSettingsChrome(timeout: TimeInterval = UITestTimeout.standard) {
        let page = self
        let found = UITestPoll.until(timeout) {
            page.root.exists && page.root.staticTexts.matchingLabelOrValue(containing: "Output").firstMatch.exists
        }
        XCTAssertTrue(found, "The Settings window never showed the Output section. \(diagnostics())")
    }

    func selectTab(_ title: String) {
        let predicate = NSPredicate(format: "label == %@ OR title == %@ OR value == %@", title, title, title)
        let candidates = [
            root.buttons[title],
            root.tabs[title],
            root.radioButtons[title],
            root.toolbars.buttons[title],
            root.segmentedControls.buttons.matching(predicate).firstMatch,
            root.radioGroups.radioButtons.matching(predicate).firstMatch,
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
        XCTAssertTrue(popup.uiText.contains(fragment), "Existing-file picker showed \(popup.uiText)", file: file, line: line)
    }

    func chooseExistingFile(_ title: String) {
        let popup = existingFilePopup()
        popup.clickWhenReady(message: "The existing-file picker never showed up")
        let item = app.menuItems[title]
        item.clickWhenReady(message: "The \(title) choice never showed up")
        let shown = UITestPoll.until(UITestTimeout.standard) {
            self.existingFilePopup().uiText.contains(title.components(separatedBy: " ").first ?? title)
        }
        XCTAssertTrue(shown, "The existing-file picker did not show \(title). It showed \(existingFilePopup().uiText)")
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
        switchControl("chooseMKVTrackToggle", fallback: "Choose subtitle tracks")
            .clickWhenReady(message: "The MKV track switch never showed up")
    }

    func requireLanguageEnglish(file: StaticString = #filePath, line: UInt = #line) {
        let popup = identified("languagePicker", types: [.popUpButton, .button, .menuButton])
            ?? root.popUpButtons.firstMatch
        popup.requireExists(timeout: UITestTimeout.standard, message: "The language picker never showed up", file: file, line: line)
        XCTAssertTrue(popup.uiText.contains("English"), "Language picker showed \(popup.uiText)", file: file, line: line)
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
        switchControl("italicsToggle", fallback: "Detect italics")
            .clickWhenReady(message: "The italics switch never showed up")
    }

    func incrementPictures() {
        let stepper = identified("concurrencyStepper", types: [.stepper, .group, .other]) ?? root.steppers.firstMatch
        stepper.requireExists(timeout: UITestTimeout.standard, message: "The pictures stepper never showed up")
        let increment = firstButton(named: ["Increment", "increment", "Increase"], in: stepper)
            ?? firstButton(named: ["Increment", "increment", "Increase"], in: root)
        guard let increment else {
            XCTFail("The pictures stepper increment never showed up")
            return
        }
        increment.click()
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

    private func firstButton(named titles: [String], in root: XCUIElement) -> XCUIElement? {
        for title in titles {
            let candidates = [root.buttons[title], root.steppers.buttons[title]]
            if let found = UITestWait.firstExisting(candidates, timeout: UITestTimeout.short) {
                return found
            }
        }
        return nil
    }

    private func diagnostics() -> String {
        guard root.exists else { return "No Settings window." }
        return "Window title '\(root.title)' label '\(root.label)'."
    }
}
