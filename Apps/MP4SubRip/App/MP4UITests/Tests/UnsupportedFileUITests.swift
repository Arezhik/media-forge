import XCTest

// `notes.txt` is inside the launched input folder. A folder drop ignores
// files that are not .mp4, so this file is not a skipped row and does not
// get its own banner. The folder has no movie, so the empty-folder banner
// is the notice.

@MainActor
final class UnsupportedFileUITests: BaseUITest {
    override func prepareFixtures() async throws {
        try fixtures.createDummyFile(in: fixtures.input, named: "notes.txt")
    }

    func testUnsupportedFileInsideFolderShowsEmptyBannerAndNoRow() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Drop screen stays up") { _ in
            page.waitForDropScreen()
        }

        XCTContext.runActivity(named: "Empty-folder banner, not a per-file skip") { _ in
            page.banner.requireFragment("No .mp4 files were found in input.")
            page.banner.assertAbsent("notes.txt is not a .mp4 file")
        }

        XCTContext.runActivity(named: "No queue row") { _ in
            page.queue.assertNoRow(named: "notes.txt")
        }
    }
}
