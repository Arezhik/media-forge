import XCTest

// A 0-byte .mkv cannot be read. Without MKVToolNix the row says it is not
// Matroska. With MKVToolNix, mkvmerge reports its own error, or the file has
// no PGS track. Either way the footer settles to failed or skipped.

@MainActor
final class EmptyMKVFailureUITests: BaseUITest {
    override func prepareFixtures() async throws {
        try fixtures.createDummyFile(in: fixtures.input, named: "sample.mkv")
    }

    func testEmptyMKVSettlesAsFailedOrSkipped() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Row appears") { _ in
            page.waitUntilLoaded()
            page.queue.requireName("sample.mkv")
        }

        XCTContext.runActivity(named: "Row settles") { _ in
            let settled = UITestPoll.until(UITestTimeout.batch) {
                page.footer.batchSettled
            }
            XCTAssertTrue(settled, "The MKV row never settled to failed or skipped")
        }

        XCTContext.runActivity(named: "Clear Finished is available") { _ in
            page.assertToolbar("Clear Finished", enabled: true)
        }
    }
}

private extension FooterSummaryComponent {
    /// True when the batch line reports a terminal count.
    var batchSettled: Bool {
        let line = settledLine
        return line.contains("failed") || line.contains("skipped")
    }

    private var settledLine: String {
        let element = app.mainWindow.staticTexts["batchLine"]
        guard element.exists else { return "" }
        return element.uiText
    }
}
