import MediaTesting
import XCTest

// Empty input folder. The banner is the fixture. Extract stays off.
// Does not seed a movie and does not click Extract Subtitles.

@MainActor
final class MainWindowSmokeUITests: BaseUITest {
    func testMainWindowShowsDropScreenAndEmptyFolderBanner() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Drop screen") { _ in
            page.waitForDropScreen()
        }

        XCTContext.runActivity(named: "Empty input folder banner") { _ in
            page.banner.requireFragment("No .mp4 files were found in")
        }

        XCTContext.runActivity(named: "Extract stays off with nothing queued") { _ in
            page.assertPrimary(titled: "Extract", enabled: false)
        }

        XCTContext.runActivity(named: "Dismiss the banner") { _ in
            page.dismissBanner()
            page.banner.assertAbsent("No .mp4 files were found in")
            page.requireText("Drop .mp4 files here")
        }
    }
}
