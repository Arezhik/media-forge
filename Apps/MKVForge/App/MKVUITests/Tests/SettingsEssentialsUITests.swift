import MediaTesting
import XCTest

// UIT-P0-05. Settings shows the tool, the match switch, Scan child folders, the
// Cancel switch, and the finish switches. No media. `--uitesting` clears the defaults,
// so Match on MKA Name and the two finish switches start on. Scan child folders and
// Cancel stops the current file immediately start off.
// Does not click Choose…, Get MKVToolNix, or Open System Settings….

@MainActor
final class SettingsEssentialsUITests: BaseUITest {
    override func prepareFixtures() async throws {
        // No media. The cleared UI-test defaults are the fixture.
    }

    func testSettingsShowsToolMatchSwitchAndFinishSwitches() throws {
        let settings = XCTContext.runActivity(named: "Open Settings") { _ in
            SettingsPage.open(in: app)
        }

        XCTContext.runActivity(named: "Settings window and navigation title") { _ in
            settings.waitForSettingsChrome()
        }

        XCTContext.runActivity(named: "MKVToolNix section and status") { _ in
            settings.requireMKVToolNixSection()
            settings.assertToolStatusFoundOrNotFound()
            settings.assertUseAutomaticDisabled()
            settings.assertChooseButtonPresent()
        }

        XCTContext.runActivity(named: "Match on MKA Name is on screen and starts on") { _ in
            settings.requireMatchOnMKANameToggle()
            settings.waitUntilSwitch(named: "Match on MKA Name", isOn: true)
        }

        XCTContext.runActivity(named: "Scan child folders is on screen and starts off") { _ in
            settings.requireScanChildFoldersToggle()
            settings.waitUntilSwitch(named: "Scan child folders", isOn: false)
            settings.clickScanChildFolders()
            settings.waitUntilSwitch(named: "Scan child folders", isOn: true)
            settings.clickScanChildFolders()
            settings.waitUntilSwitch(named: "Scan child folders", isOn: false)
        }

        XCTContext.runActivity(named: "Cancel stops immediately is on screen and starts off") { _ in
            settings.requireCancelStopsImmediatelyToggle()
            settings.waitUntilSwitch(named: "Cancel stops the current file immediately", isOn: false)
            settings.clickCancelStopsImmediately()
            settings.waitUntilSwitch(named: "Cancel stops the current file immediately", isOn: true)
            settings.clickCancelStopsImmediately()
            settings.waitUntilSwitch(named: "Cancel stops the current file immediately", isOn: false)
        }

        XCTContext.runActivity(named: "Finish switches are on screen and start on") { _ in
            settings.requireSendNotificationToggle()
            settings.requireBounceDockIconToggle()
            settings.waitUntilSwitch(named: "Send a notification", isOn: true)
            settings.waitUntilSwitch(named: "Bounce the Dock icon", isOn: true)
        }

        XCTContext.runActivity(named: "Send a notification toggles off and back on") { _ in
            settings.clickSendNotification()
            settings.waitUntilSwitch(named: "Send a notification", isOn: false)
            settings.clickSendNotification()
            settings.waitUntilSwitch(named: "Send a notification", isOn: true)
        }
    }
}
