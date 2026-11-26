import XCTest

// Page: the queue window. Drop screen when the list is empty, rows otherwise.
// Toolbar titles: Open…, Cancel All, Clear Finished. Conversion starts on drop.
// There is no separate Convert button and no tool-missing banner.

/// The PGS2SRT queue window.
@MainActor
final class MainWindowPage: BasePage {
    override var root: XCUIElement { app.mainWindow }

    var banner: IntakeBannerComponent { IntakeBannerComponent(app: app) }
    var queue: QueueRowComponent { QueueRowComponent(app: app) }
    var footer: FooterSummaryComponent { FooterSummaryComponent(app: app) }

    func waitForDropScreen(timeout: TimeInterval = UITestTimeout.standard) {
        waitUntilLoaded(timeout: timeout)
        requireText("PGS2SRT", timeout: timeout)
        requireText("Drop .sup or .mkv files, or a folder", timeout: timeout)
        openButton().requireExists(timeout: timeout, message: "The Open button never showed up")
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

    func assertToolbar(_ title: String, enabled: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let button = toolbarButton(title)
        button.requireExists(timeout: UITestTimeout.standard, message: "The \(title) button never showed up", file: file, line: line)
        XCTAssertEqual(button.isEnabled, enabled, "\(title) enabled was \(button.isEnabled)", file: file, line: line)
    }

    func dismissBanner() {
        toolbarButton("Dismiss").clickWhenReady(message: "The Dismiss button never showed up")
    }

    func clickClearFinished() {
        toolbarButton("Clear Finished").clickWhenReady(message: "Clear Finished never showed up")
    }

    private func openButton() -> XCUIElement {
        // The title uses the single ellipsis character, not three dots.
        let predicate = NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", "Open", "Open")
        let candidates = [
            root.buttons.matching(predicate).firstMatch,
            root.toolbars.buttons.matching(predicate).firstMatch,
            app.buttons.matching(predicate).firstMatch,
        ]
        return UITestWait.firstExisting(candidates, timeout: UITestTimeout.standard) ?? candidates[0]
    }

    private func toolbarButton(_ title: String) -> XCUIElement {
        let candidates = [
            root.buttons[title],
            root.toolbars.buttons[title],
            app.buttons[title],
        ]
        return UITestWait.firstExisting(candidates, timeout: UITestTimeout.short) ?? candidates[0]
    }
}
