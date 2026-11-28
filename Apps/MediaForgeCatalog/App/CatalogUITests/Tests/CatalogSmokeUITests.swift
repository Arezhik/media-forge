import MediaTesting
import XCTest

// First launch shows the Overview. A sidebar row swaps the detail.
// A nonsense query shows the sidebar's no-results state. Does not open panels.

@MainActor
final class CatalogSmokeUITests: BaseUITest {
    func testLaunchShowsOverview() {
        let page = CatalogPage(app: app)
        page.waitForOverview()
    }

    func testSelectingSidebarRowChangesDetail() {
        let page = CatalogPage(app: app)
        page.waitForOverview()
        page.selectSidebarRow("sidebar.fileDrop")
        page.requireDetailTitle("FileDrop")
    }

    func testSearchWithNonsenseShowsNoMatches() {
        let page = CatalogPage(app: app)
        page.waitForOverview()
        page.search("zzzz-not-a-component")
        page.requireNoSearchResults()
    }
}
