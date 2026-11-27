#if canImport(XCTest) && os(macOS)
import XCTest

// Shared chrome: the window that is not Settings, and toolbar button lookup.
// Folder fields, the mode picker, Scan, and the primary action stay on the app page.

/// Main window chrome. App pages subclass this and add their own controls.
@MainActor
open class MainWindowPage: BasePage {
    /// Accessibility identifier of the main window, when the app sets one.
    /// Nil uses `XCUIApplication.mainWindow` (title does not contain Settings).
    /// PGS2SRT sets `pgs2srt.queue` and can still override `root` for its chrome fallback.
    open var mainWindowIdentifier: String? { nil }

    open override var root: XCUIElement {
        guard let mainWindowIdentifier else { return app.mainWindow }
        return app.mainWindow(identifier: mainWindowIdentifier)
    }

    /// Exact toolbar title on the window, then the window toolbar, then the app.
    open func toolbarButton(exact title: String, timeout: TimeInterval = UITestTimeout.short) -> XCUIElement {
        let candidates = [root.buttons[title], root.toolbars.buttons[title], app.buttons[title]]
        return UITestWait.firstExisting(candidates, timeout: timeout) ?? candidates[0]
    }

    /// Toolbar button whose label or title begins with `prefix`.
    open func toolbarButton(prefix: String, timeout: TimeInterval = UITestTimeout.standard) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", prefix, prefix)
        let candidates = [
            root.buttons.matching(predicate).firstMatch,
            root.toolbars.buttons.matching(predicate).firstMatch,
            app.buttons.matching(predicate).firstMatch,
        ]
        return UITestWait.firstExisting(candidates, timeout: timeout) ?? candidates[0]
    }
}
#endif
