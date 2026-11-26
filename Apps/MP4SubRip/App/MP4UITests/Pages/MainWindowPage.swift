import XCTest

// Page: the queue window. Drop screen when empty, table otherwise.
// Extract Subtitles does not run until it is clicked. These tests do not click it.

/// The MP4SubRip queue window.
@MainActor
final class MainWindowPage: BasePage {
    override var root: XCUIElement { app.mainWindow }

    var banner: IntakeBannerComponent { IntakeBannerComponent(app: app) }
    var queue: QueueRowComponent { QueueRowComponent(app: app) }
    var mode: ModePickerComponent { ModePickerComponent(app: app) }
    var saveTo: SaveToComponent { SaveToComponent(app: app) }

    func waitForDropScreen(timeout: TimeInterval = UITestTimeout.standard) {
        waitUntilLoaded(timeout: timeout)
        requireText("Drop .mp4 files here", timeout: timeout)
        toolbarButton(prefix: "Add Files").requireExists(timeout: timeout, message: "Add Files never showed up")
    }

    func requireText(
        _ text: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exact = root.staticTexts.matchingLabelOrValue(equalTo: text).firstMatch
        let partial = root.staticTexts.matchingLabelOrValue(containing: text).firstMatch
        guard UITestWait.firstExisting([exact, partial], timeout: timeout) != nil else {
            XCTFail("Text '\(text)' never showed up", file: file, line: line)
            return
        }
    }

    func assertPrimary(titled fragment: String, enabled: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let button = primaryButton()
        button.requireExists(timeout: UITestTimeout.standard, message: "The primary button never showed up", file: file, line: line)
        XCTAssertTrue(button.uiText.contains(fragment), "Primary button showed \(button.uiText)", file: file, line: line)
        XCTAssertEqual(button.isEnabled, enabled, "Primary enabled was \(button.isEnabled)", file: file, line: line)
    }

    func dismissBanner() {
        toolbarButton(exact: "Dismiss").clickWhenReady(message: "The Dismiss button never showed up")
    }

    private func primaryButton() -> XCUIElement {
        let types: [XCUIElement.ElementType] = [.button]
        let identified = UITestQuery.identified("primaryAction", in: root, types: types)
            + UITestQuery.identified("primaryAction", in: app, types: types)
        if let found = UITestWait.firstExisting(identified, timeout: UITestTimeout.short) {
            return found
        }
        return toolbarButton(prefix: "Extract")
    }

    private func toolbarButton(exact: String? = nil, prefix: String? = nil) -> XCUIElement {
        if let exact {
            let candidates = [root.buttons[exact], root.toolbars.buttons[exact], app.buttons[exact]]
            return UITestWait.firstExisting(candidates, timeout: UITestTimeout.short) ?? candidates[0]
        }
        let prefix = prefix ?? ""
        let predicate = NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", prefix, prefix)
        let candidates = [
            root.buttons.matching(predicate).firstMatch,
            root.toolbars.buttons.matching(predicate).firstMatch,
            app.buttons.matching(predicate).firstMatch,
        ]
        return UITestWait.firstExisting(candidates, timeout: UITestTimeout.standard) ?? candidates[0]
    }
}
