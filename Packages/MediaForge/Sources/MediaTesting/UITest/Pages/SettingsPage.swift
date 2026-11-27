#if canImport(XCTest) && os(macOS)
import XCTest

// Shared Settings open: the application menu item whose title contains "Settings",
// and a window whose title or label contains "Settings".
// Sections, toggles, and pickers stay on the app page.
// PGS2SRT's title bar names the selected pane. Override `root` (and
// `settingsWindowIdentifier`, `pgs2srt.settings`) for that lookup.

/// Settings window. Locators assume the window is up, except `open(in:)`.
@MainActor
open class SettingsPage: BasePage {
    /// Application menu title (`MKVForge`, `MP4SubRip`, `PGS2SRT`). Subclasses override this.
    open class var menuTitle: String { "" }

    /// Window identifier when the title is not "Settings". Nil keeps the title lookup.
    open var settingsWindowIdentifier: String? { nil }

    /// `Self.init` in `open(in:)` needs a required initializer. Subclasses inherit this.
    /// `BasePage` already declares `init(app:)`, so this override must say so.
    public required override init(app: XCUIApplication) {
        super.init(app: app)
    }

    /// A window whose title or label contains Settings, or `settingsWindowIdentifier` when set.
    open override var root: XCUIElement {
        if let settingsWindowIdentifier {
            let marked = app.windows[settingsWindowIdentifier]
            if marked.exists { return marked }
        }
        return app.windows.matching(
            NSPredicate(format: "title CONTAINS[c] %@ OR label CONTAINS[c] %@", "Settings", "Settings")
        ).firstMatch
    }

    /// Opens Settings from the application menu and returns this page.
    @discardableResult
    open class func open(in app: XCUIApplication) -> Self {
        let page = Self(app: app)
        page.openFromApplicationMenu()
        return page
    }

    /// Clicks the application menu, then the item whose label or title contains Settings.
    open func openFromApplicationMenu() {
        let applicationMenuTitle = Self.menuTitle
        let appMenu = app.menuBars.firstMatch.menuBarItems[applicationMenuTitle]
        appMenu.clickWhenReady(message: "The \(applicationMenuTitle) application menu never showed up")
        let item = appMenu.menuItems.matching(
            NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@", "Settings", "Settings")
        ).firstMatch
        item.clickWhenReady(message: "The Settings menu item never showed up")
    }
}
#endif
