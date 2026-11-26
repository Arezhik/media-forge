import XCTest

// A file that is not .sup or .mkv becomes a banner, not a queue row.
// The folder still has no subtitle, so the empty-folder sentence can appear too.

@MainActor
final class UnsupportedFileUITests: BaseUITest {
    override func prepareFixtures() async throws {
        try fixtures.createDummyFile(in: fixtures.input, named: "notes.txt")
    }

    func testUnsupportedFileShowsSkipBannerAndNoRow() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Drop screen stays up") { _ in
            page.waitForDropScreen()
        }

        XCTContext.runActivity(named: "Skip banner names the file") { _ in
            page.banner.requireFragment("notes.txt is not a .sup or .mkv file, so it was skipped.")
        }

        XCTContext.runActivity(named: "No queue row") { _ in
            page.queue.assertNoRows()
            page.queue.assertNoRow(named: "notes.txt")
        }
    }
}
