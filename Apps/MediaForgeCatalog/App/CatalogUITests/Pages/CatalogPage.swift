import MediaTesting
import XCTest

@MainActor
final class CatalogPage: BasePage {
    func waitForOverview() {
        app.groups["overview"].requireExists(message: "Overview never showed")
        app.staticTexts["overviewTitle"].requireExists(message: "Overview title never showed")
    }

    func selectSidebarRow(_ identifier: String) {
        sidebarRow(identifier).clickWhenReady(message: "Sidebar row \(identifier) never showed")
    }

    func sidebarRow(_ identifier: String) -> XCUIElement {
        let types: [XCUIElement.ElementType] = [.outlineRow, .cell, .group, .button, .staticText]
        let matches = UITestQuery.identified(identifier, in: app, types: types)
        return UITestWait.firstExisting(matches, timeout: UITestTimeout.standard) ?? matches[0]
    }

    func requireDetailTitle(_ title: String) {
        let element = app.groups["detail"].staticTexts["detailTitle"]
        element.requireExists(message: "Detail title never showed \(title)")
        XCTAssertTrue(
            element.uiText == title || (element.value as? String) == title,
            "Detail title was \(element.uiText), expected \(title)"
        )
    }

    func search(_ text: String) {
        let field = searchField()
        field.clickWhenReady(message: "Search field never showed")
        field.typeText(text)
    }

    func searchField() -> XCUIElement {
        let named = app.searchFields["Search components"]
        if named.exists { return named }
        let identified = app.searchFields["componentSearch"]
        if identified.exists { return identified }
        return app.searchFields.firstMatch
    }

    func requireNoSearchResults() {
        let types: [XCUIElement.ElementType] = [.group, .staticText, .other]
        let matches = UITestQuery.identified("searchNoResults", in: app, types: types)
        if UITestWait.firstExisting(matches, timeout: UITestTimeout.standard) != nil {
            return
        }
        app.staticTexts.matchingLabelOrValue(containing: "No Results").firstMatch
            .requireExists(message: "No-results state never showed")
    }
}
