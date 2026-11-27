import XCTest
import MediaForgeCatalogCore

final class CatalogIndexTests: XCTestCase {
    func testNineRowsInTwoSections() {
        XCTAssertEqual(CatalogIndex.pages.count, 9)
        XCTAssertEqual(CatalogIndex.pages(in: .mediaUI).map(\.id), [
            .fileDrop, .filePanels, .reveal, .debugLogExport,
        ])
        XCTAssertEqual(CatalogIndex.pages(in: .mediaTesting).map(\.id), [
            .base, .pages, .components, .helpers, .fixtures,
        ])
    }

    func testMediaUIRowsAreMonospacedDemos() {
        for page in CatalogIndex.pages(in: .mediaUI) {
            XCTAssertTrue(page.monospaceTitle, page.title)
            XCTAssertFalse(page.showsDocBadge, page.title)
            XCTAssertEqual(page.stateCount, 4, page.title)
            XCTAssertEqual(page.badge, "MediaUI")
        }
    }

    func testMediaTestingRowsAreReference() {
        for page in CatalogIndex.pages(in: .mediaTesting) {
            XCTAssertFalse(page.monospaceTitle, page.title)
            XCTAssertTrue(page.showsDocBadge, page.title)
            XCTAssertTrue(page.tiles.isEmpty, page.title)
            XCTAssertGreaterThan(page.typeCount, 0, page.title)
            XCTAssertEqual(page.badge, "MediaTesting · Reference")
        }
    }

    func testEmptyQueryReturnsEveryRow() {
        XCTAssertEqual(CatalogIndex.pages(matching: "").count, 9)
        XCTAssertEqual(CatalogIndex.pages(matching: "   ").count, 9)
    }

    func testChooseToolFindsFilePanels() {
        XCTAssertEqual(CatalogIndex.pages(matching: "chooseTool").map(\.id), [.filePanels])
        XCTAssertEqual(CatalogIndex.pages(matching: "OpenPanelOptions").map(\.id), [.filePanels])
    }

    func testNonsenseMatchesNothing() {
        XCTAssertTrue(CatalogIndex.pages(matching: "zzzz-not-a-component").isEmpty)
    }

    func testSearchIsCaseInsensitiveAndMatchesTypes() {
        XCTAssertEqual(CatalogIndex.pages(matching: "FILEDROP").map(\.id), [.fileDrop])
        XCTAssertEqual(CatalogIndex.pages(matching: "QueueRowComponent").map(\.id), [.components])
        XCTAssertEqual(CatalogIndex.pages(matching: "clickWhenReady").map(\.id), [.helpers])
        XCTAssertEqual(CatalogIndex.pages(matching: "mainWindow").map(\.id), [.pages, .helpers])
        let selectFile = Set(CatalogIndex.pages(matching: "selectFile").map(\.id))
        XCTAssertEqual(selectFile, [.reveal, .debugLogExport])
    }

    func testUsedInMapping() throws {
        let fileDrop = try XCTUnwrap(CatalogIndex.page(.fileDrop))
        let filePanels = try XCTUnwrap(CatalogIndex.page(.filePanels))
        let reveal = try XCTUnwrap(CatalogIndex.page(.reveal))
        let export = try XCTUnwrap(CatalogIndex.page(.debugLogExport))
        XCTAssertEqual(fileDrop.usedIn, .apps([.mp4SubRip, .pgs2srt]))
        XCTAssertEqual(filePanels.usedIn, Adoption.allThree)
        XCTAssertEqual(reveal.usedIn, Adoption.allThree)
        XCTAssertEqual(export.usedIn, Adoption.allThree)

        XCTAssertEqual(chips(.reveal, "activateViewer"), .notCalledDirectly as Adoption?)
        XCTAssertEqual(chips(.reveal, "selectFolder"), .apps([.mkvForge, .mp4SubRip]) as Adoption?)
        XCTAssertEqual(chips(.filePanels, "tool"), .apps([.mkvForge, .mp4SubRip]) as Adoption?)
        XCTAssertNil(chips(.filePanels, "cancel"))
        XCTAssertEqual(chips(.debugLogExport, "selectFile"), .apps([.mp4SubRip]) as Adoption?)
        XCTAssertEqual(chips(.debugLogExport, "activateViewer"), .apps([.mkvForge, .pgs2srt]) as Adoption?)
    }

    private func chips(_ page: PageID, _ tile: String) -> Adoption? {
        CatalogIndex.page(page)?.tiles.first { $0.id == tile }?.chips
    }

    func testFixtureErrorHasNoApp() throws {
        let row = try XCTUnwrap(CatalogIndex.page(.fixtures)?.types.first { $0.type == "UITestFixtureBuilderError" })
        XCTAssertEqual(row.usedIn, Adoption.noAppUsesThis)
        XCTAssertEqual(row.buildsOn, "Error")
    }

    func testHelperExtensions() {
        let names = CatalogIndex.page(.helpers)?.extensions.map(\.name)
        XCTAssertEqual(names, [
            "matchingLabelOrValue",
            "requireExists",
            "clickWhenReady",
            "uiText",
            "uiMenuText",
            "uiLabelAndValue",
            "switchIsOn",
            "waitUntilSwitch",
            "app.mainWindow · mainWindow(identifier:)",
        ])
        XCTAssertEqual(
            CatalogIndex.page(.helpers)?.extensions.first { $0.name == "uiText" }?.usedIn,
            .apps([.mkvForge]) as Adoption?
        )
        XCTAssertEqual(
            CatalogIndex.page(.helpers)?.extensions.first { $0.name == "uiLabelAndValue" }?.usedIn,
            .apps([.pgs2srt]) as Adoption?
        )
    }

    func testSidebarIdentifiersAreStable() {
        XCTAssertEqual(CatalogIndex.page(.fileDrop)?.sidebarIdentifier, "sidebar.fileDrop")
        XCTAssertEqual(CatalogIndex.page(.helpers)?.sidebarIdentifier, "sidebar.helpers")
    }

    func testAccents() {
        XCTAssertEqual(ProductApp.mkvForge.accentHex, "FF8F26")
        XCTAssertEqual(ProductApp.mp4SubRip.accentHex, "2F6BFF")
        XCTAssertEqual(ProductApp.pgs2srt.accentHex, "8B6CFF")
    }
}
