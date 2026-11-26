import XCTest

// Page: Settings. Output placement, existing-file policy, and ffmpeg.
// Open it from the MP4SubRip menu. Do not click Choose… or Choose Folder.

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
        let appMenu = app.menuBars.firstMatch.menuBarItems["MP4SubRip"]
        appMenu.clickWhenReady(message: "The MP4SubRip application menu never showed up")
        let item = appMenu.menuItems.matching(
            NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@", "Settings", "Settings")
        ).firstMatch
        item.clickWhenReady(message: "The Settings menu item never showed up")
        return SettingsPage(app: app)
    }

    func waitForSettingsChrome(timeout: TimeInterval = UITestTimeout.standard) {
        let page = self
        let found = UITestPoll.until(timeout) {
            page.showsSettingsChrome()
        }
        XCTAssertTrue(found, "Settings never showed the output controls. \(diagnostics())")
    }

    /// The grouped-form header "Output" is not always its own static text.
    /// The radio label and the existing-file picker are.
    private func showsSettingsChrome() -> Bool {
        guard root.exists else { return false }
        if root.staticTexts.matchingLabelOrValue(containing: "Save the output").firstMatch.exists {
            return true
        }
        if root.radioButtons.matchingLabelOrValue(containing: "Next to the source").firstMatch.exists {
            return true
        }
        let header = NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@ OR title CONTAINS[c] %@", "Output", "Output", "Output")
        if root.staticTexts.matching(header).firstMatch.exists || root.groups.matching(header).firstMatch.exists {
            return true
        }
        let picker = UITestQuery.identified("existingFilePicker", in: root, types: [.popUpButton, .button, .menuButton])
        return picker.contains(where: \.exists)
    }

    func requireExistingFile(contains fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        let popup = existingFilePopup()
        popup.requireExists(timeout: UITestTimeout.standard, message: "The existing-file picker never showed up", file: file, line: line)
        XCTAssertTrue(popup.uiText.contains(fragment), "Existing-file picker showed \(popup.uiText)", file: file, line: line)
    }

    func chooseExistingFile(_ title: String) {
        existingFilePopup().clickWhenReady(message: "The existing-file picker never showed up")
        app.menuItems[title].clickWhenReady(message: "The \(title) choice never showed up")
        let needle = title.components(separatedBy: " ").first ?? title
        let shown = UITestPoll.until(UITestTimeout.standard) {
            self.existingFilePopup().uiText.contains(needle)
        }
        XCTAssertTrue(shown, "Existing-file picker did not show \(title). It showed \(existingFilePopup().uiText)")
    }

    func requireOutputPath(contains fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        let found = UITestPoll.until(UITestTimeout.standard) {
            self.root.staticTexts.matchingLabelOrValue(containing: fragment).firstMatch.exists
        }
        XCTAssertTrue(found, "Settings never showed the output path \(fragment)", file: file, line: line)
    }

    /// Automatic ffmpeg lookup finishes as a path or as Not found. Either is a settled tool row.
    func requireFFmpegSettled(file: StaticString = #filePath, line: UInt = #line) {
        let sectionCandidates = [
            root.staticTexts["ffmpegSection"],
            root.staticTexts.matchingLabelOrValue(equalTo: "ffmpeg").firstMatch,
            root.radioButtons.matchingLabelOrValue(containing: "Find it automatically").firstMatch,
            root.staticTexts.matchingLabelOrValue(containing: "Find it automatically").firstMatch,
        ]
        guard UITestWait.firstExisting(sectionCandidates, timeout: UITestTimeout.standard) != nil else {
            XCTFail("The ffmpeg section never showed up. \(diagnostics())", file: file, line: line)
            return
        }
        let settled = UITestPoll.until(UITestTimeout.long) {
            let checking = self.root.staticTexts.matchingLabelOrValue(equalTo: "Checking…").firstMatch.exists
            if checking { return false }
            let missing = self.root.staticTexts.matchingLabelOrValue(equalTo: "Not found").firstMatch.exists
            let path = self.root.staticTexts.matchingLabelOrValue(containing: "/").firstMatch.exists
            return missing || path
        }
        XCTAssertTrue(settled, "ffmpeg status never settled. \(diagnostics())", file: file, line: line)
    }

    private func existingFilePopup() -> XCUIElement {
        let found = UITestWait.firstExisting(
            UITestQuery.identified("existingFilePicker", in: root, types: [.popUpButton, .button, .menuButton]),
            timeout: UITestTimeout.short
        )
        return found ?? root.popUpButtons.firstMatch
    }

    private func diagnostics() -> String {
        guard root.exists else { return "No Settings window." }
        let texts = root.staticTexts.allElementsBoundByIndex.prefix(8).map(\.uiText).joined(separator: " | ")
        return "Window title '\(root.title)' label '\(root.label)'. Texts: \(texts)."
    }
}
