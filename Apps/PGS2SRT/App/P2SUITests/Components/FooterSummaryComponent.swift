import MediaTesting
import XCTest

// Component: the footer under the queue.
// `settingsSummary` is the language / folder / pictures line.
// `batchLine` appears after a batch finishes, such as `1 failed in 0s`.
// Static text joins label and value. The queue window is `queueWindow`.

/// Footer summary and the batch result line.
@MainActor
struct FooterSummaryComponent {
    let app: XCUIApplication

    func requireSummary(
        containing fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            self.summaryText().contains(fragment)
        }
        XCTAssertTrue(
            found,
            "The footer never showed \(fragment). It showed \(summaryText())",
            file: file,
            line: line
        )
    }

    func requireBatchLine(
        containing fragment: String,
        timeout: TimeInterval = UITestTimeout.batch,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = UITestPoll.until(timeout) {
            self.batchText().contains(fragment)
        }
        XCTAssertTrue(
            found,
            "The batch line never showed \(fragment). It showed \(batchText())",
            file: file,
            line: line
        )
    }

    private func summaryText() -> String {
        let element = app.queueWindow.staticTexts["settingsSummary"]
        guard element.exists else { return "" }
        return element.uiLabelAndValue
    }

    private func batchText() -> String {
        let identified = app.queueWindow.staticTexts["batchLine"]
        if identified.exists {
            return identified.uiLabelAndValue
        }
        return ""
    }
}
