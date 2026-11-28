import MediaTesting
import XCTest

// Option relabels the toolbar Cancel button to Force Cancel while a Split run is active.
// The setting stays off (the cleared UI-test default). One settled file with audio and
// subtitles, same shape as SplitReady. Locators stay on pages.

@MainActor
final class ForceCancelOptionUITests: BaseUITest {
    private static let fileName = "force-cancel-sample.mkv"

    override func prepareFixtures() async throws {
        let source = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: Self.fileName,
            includeAudio: true,
            includeSubtitles: true
        )
        try fixtures.settle(source)
    }

    func testOptionRelabelsCancelToForceCancel() throws {
        let page = try scanUntilReady()

        XCTContext.runActivity(named: "Run Split") { _ in
            page.clickPrimaryAction(titled: "Split")
        }

        XCTContext.runActivity(named: "Cancel is the toolbar title while the batch runs") { _ in
            page.assertPrimary(titled: "Cancel", enabled: true, timeout: UITestTimeout.batch)
        }

        XCTContext.runActivity(named: "Holding Option relabels Cancel to Force Cancel") { _ in
            page.assertPrimaryWhileHoldingOption(titled: "Force Cancel", timeout: UITestTimeout.batch)
        }
    }

    private func scanUntilReady() throws -> SplitPage {
        let stem = (Self.fileName as NSString).deletingPathExtension
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Main window appears") { _ in
            page.waitForSplitChrome()
        }

        XCTContext.runActivity(named: "Source folder shows the input fixture") { _ in
            page.sourceFolder.assertShowsPathFragment("input")
        }

        try XCTContext.runActivity(named: "Scan the Source folder") { _ in
            try page.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Row is Ready") { _ in
            page.queueRow(stem: stem).requireExactLabel("\(stem), Ready, No chapters found")
        }

        return page
    }
}
