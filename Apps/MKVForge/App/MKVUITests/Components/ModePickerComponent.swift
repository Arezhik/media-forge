import MediaTesting
import XCTest

// Split | Remux. The shared helper clicks a segment inside identifier `modePicker`.
// The toolbar primary button is also titled Split or Remux. Do not click that button here.

/// Split | Remux segmented control in the toolbar.
@MainActor
final class ModePickerComponent: MediaTesting.ModePickerComponent {
    /// Switches the main window to Remux and returns that page.
    @discardableResult
    func selectRemux() -> RemuxPage {
        select("Remux")
        return RemuxPage(app: app)
    }

    /// Switches the main window to Split and returns that page.
    @discardableResult
    func selectSplit() -> SplitPage {
        select("Split")
        return SplitPage(app: app)
    }
}
