import MediaTesting
import XCTest

// Settings essentials. The UI-test defaults are cleared on launch, then the
// output folder is applied from UITEST_OUTPUT_DIR. No media, so nothing converts.
// Does not click Choose… or Open System Settings.

@MainActor
final class SettingsEssentialsUITests: BaseUITest {
    func testSettingsShowsOutputLanguageItalicsAndNotification() {
        let main = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Footer shows the seeded output folder") { _ in
            main.waitForDropScreen()
            main.footer.requireSummary(containing: "output")
            main.footer.requireSummary(containing: "4 pictures")
        }

        let settings = XCTContext.runActivity(named: "Open Settings") { _ in
            SettingsPage.open(in: app)
        }

        XCTContext.runActivity(named: "Output section and existing-file picker") { _ in
            settings.waitForSettingsChrome()
            settings.requireExistingFile(contains: "Overwrite")
            settings.chooseExistingFile("Skip that file")
            settings.chooseExistingFile("Overwrite it")
        }

        XCTContext.runActivity(named: "MKV track switch toggles") { _ in
            settings.requireChooseMKVTrack(isOn: false)
            settings.clickChooseMKVTrack()
            settings.requireChooseMKVTrack(isOn: true)
            settings.clickChooseMKVTrack()
            settings.requireChooseMKVTrack(isOn: false)
        }

        XCTContext.runActivity(named: "Recognition language, italics, and pictures") { _ in
            settings.selectTab("Recognition")
            settings.requireLanguageEnglish()
            settings.requireItalics(isOn: false)
            settings.clickItalics()
            settings.requireItalics(isOn: true)
            settings.clickItalics()
            settings.requireItalics(isOn: false)
            settings.incrementPictures()
        }

        XCTContext.runActivity(named: "Footer shows 5 pictures at a time") { _ in
            main.footer.requireSummary(containing: "5 pictures")
        }

        XCTContext.runActivity(named: "Notification picker") { _ in
            settings.selectTab("Notifications")
            settings.requireNotificationChoice()
        }
    }
}
