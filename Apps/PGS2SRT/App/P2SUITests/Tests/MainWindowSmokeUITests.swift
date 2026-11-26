import XCTest

// Thin test. Launch and teardown live on BaseUITest.
// The input folder is empty, so the empty-folder banner is the fixture.
// This does not seed a .sup. A real .sup would start OCR.

@MainActor
final class MainWindowSmokeUITests: BaseUITest {
    func testMainWindowShowsDropScreenAndEmptyFolderBanner() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Drop screen") { _ in
            page.waitForDropScreen()
        }

        XCTContext.runActivity(named: "Empty input folder banner") { _ in
            page.banner.requireFragment("No .sup or .mkv files were found in")
        }

        XCTContext.runActivity(named: "Seeded output folder in the footer") { _ in
            page.footer.requireSummary(containing: "English")
            page.footer.requireSummary(containing: "output")
            page.footer.requireSummary(containing: "4 pictures")
        }

        XCTContext.runActivity(named: "Cancel All and Clear Finished are off") { _ in
            page.assertToolbar("Cancel All", enabled: false)
            page.assertToolbar("Clear Finished", enabled: false)
        }

        XCTContext.runActivity(named: "Dismiss the banner") { _ in
            page.dismissBanner()
            page.banner.assertAbsent("No .sup or .mkv files were found in")
            page.requireText("Drop .sup or .mkv files, or a folder")
        }
    }
}
