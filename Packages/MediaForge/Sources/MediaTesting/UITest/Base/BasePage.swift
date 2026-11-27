#if canImport(XCTest) && os(macOS)
import XCTest

// Base page. A page owns the locators and actions for one screen.
// Navigation methods return the next page or component.

/// Shared holder for `XCUIApplication` and the screen root.
@MainActor
open class BasePage {
    public let app: XCUIApplication

    public init(app: XCUIApplication) {
        self.app = app
    }

    /// The screen root. Subclasses override this when they own another window.
    open var root: XCUIElement {
        app.windows.firstMatch
    }

    @discardableResult
    open func waitUntilLoaded(timeout: TimeInterval = UITestTimeout.standard) -> XCUIElement {
        root.requireExists(timeout: timeout, message: "The window never showed up")
    }
}
#endif
