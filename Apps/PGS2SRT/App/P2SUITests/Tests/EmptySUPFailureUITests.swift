import MediaTesting
import XCTest

// A 0-byte .sup is ingested and fails before OCR.
// Do not seed createValidPGSFile here. That file starts recognition.

@MainActor
final class EmptySUPFailureUITests: BaseUITest {
    override func prepareFixtures() async throws {
        try fixtures.createDummyFile(in: fixtures.input, named: "sample.sup")
    }

    func testEmptySUPFailsAndClearFinishedReturnsToDropScreen() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Row appears") { _ in
            page.waitUntilLoaded()
            page.queue.requireName("sample.sup")
        }

        XCTContext.runActivity(named: "Empty file fails before OCR") { _ in
            page.queue.requireStatus(containing: "The PGS file is empty.")
            page.footer.requireBatchLine(containing: "1 failed")
        }

        XCTContext.runActivity(named: "Clear Finished is on and Cancel All is off") { _ in
            page.assertToolbar("Clear Finished", enabled: true)
            page.assertToolbar("Cancel All", enabled: false)
        }

        XCTContext.runActivity(named: "Clear Finished returns to the drop screen") { _ in
            page.clickClearFinished()
            page.queue.assertNoRow(named: "sample.sup")
            page.requireText("Drop .sup or .mkv files, or a folder")
        }
    }
}
