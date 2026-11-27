import MediaTesting
import XCTest

// Settings essentials. UITEST_OUTPUT_DIR is the chosen folder.
// Existing-file default is Skip. ffmpeg shows a path or Not found.
// Does not click Choose… and does not start an extract.

@MainActor
final class SettingsEssentialsUITests: BaseUITest {
    func testSettingsShowsOutputPolicyAndFFmpeg() {
        let main = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Drop screen is up") { _ in
            main.waitForDropScreen()
        }

        let settings = XCTContext.runActivity(named: "Open Settings") { _ in
            SettingsPage.open(in: app)
        }

        XCTContext.runActivity(named: "Output folder and existing-file picker") { _ in
            settings.waitForSettingsChrome()
            settings.requireOutputPath(contains: "/output")
            settings.requireExistingFile(contains: "Skip")
            settings.chooseExistingFile("Overwrite it")
            settings.chooseExistingFile("Skip that file")
        }

        XCTContext.runActivity(named: "ffmpeg row settles") { _ in
            settings.requireFFmpegSettled()
        }
    }
}
