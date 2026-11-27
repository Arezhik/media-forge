import MediaTesting
import XCTest

// Page: the queue window. Drop screen when the list is empty, rows otherwise.
// Toolbar titles: Open…, Cancel All, Clear Finished. Conversion starts on drop.
// There is no separate Convert button and no tool-missing banner.
// `root` is `queueWindow` (`pgs2srt.queue`, then the drop screen or footer).
// Settings titles the selected pane, so a title filter is not enough.

/// The PGS2SRT queue window.
@MainActor
final class MainWindowPage: MediaTesting.MainWindowPage {
    override var root: XCUIElement { app.queueWindow }

    var banner: IntakeBannerComponent { IntakeBannerComponent(app: app) }
    var queue: QueueRowComponent { QueueRowComponent(app: app) }
    var footer: FooterSummaryComponent { FooterSummaryComponent(app: app) }

    func waitForDropScreen(timeout: TimeInterval = UITestTimeout.standard) {
        waitUntilLoaded(timeout: timeout)
        requireText("PGS2SRT", timeout: timeout)
        requireText("Drop .sup or .mkv files, or a folder", timeout: timeout)
        toolbarButton(prefix: "Open").requireExists(timeout: timeout, message: "The Open button never showed up")
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
        let button = toolbarButton(exact: title)
        button.requireExists(timeout: UITestTimeout.standard, message: "The \(title) button never showed up", file: file, line: line)
        XCTAssertEqual(button.isEnabled, enabled, "\(title) enabled was \(button.isEnabled)", file: file, line: line)
    }

    func dismissBanner() {
        toolbarButton(exact: "Dismiss").clickWhenReady(message: "The Dismiss button never showed up")
    }

    func clickClearFinished() {
        toolbarButton(exact: "Clear Finished").clickWhenReady(message: "Clear Finished never showed up")
    }
}

@MainActor
extension XCUIApplication {
    /// Queue window while Settings may also be open.
    ///
    /// Identifier `pgs2srt.queue`, then the drop screen or the footer.
    /// The Settings title bar names the selected pane, so `mainWindow`'s title filter is not enough.
    var queueWindow: XCUIElement {
        let marked = windows["pgs2srt.queue"]
        if marked.exists { return marked }
        if let queue = windows.allElementsBoundByIndex.first(where: { window in
            window.staticTexts["settingsSummary"].exists
                || window.groups["emptyDrop"].exists
                || window.otherElements["emptyDrop"].exists
        }) {
            return queue
        }
        return mainWindow(identifier: "pgs2srt.queue")
    }
}
