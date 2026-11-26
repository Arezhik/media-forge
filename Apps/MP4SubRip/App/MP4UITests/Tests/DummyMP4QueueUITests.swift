import XCTest

// A 0-byte .mp4 is queued. Probe may fail it. Extraction does not start
// until Extract Subtitles, and this test does not click that button.

@MainActor
final class DummyMP4QueueUITests: BaseUITest {
    override func prepareFixtures() async throws {
        try fixtures.createDummyFile(in: fixtures.input, named: "sample.mp4")
    }

    func testDummyMP4ShowsRowSaveToAndExtractState() {
        let page = MainWindowPage(app: app)

        XCTContext.runActivity(named: "Row appears") { _ in
            page.waitUntilLoaded()
            page.queue.requireName("sample.mp4")
        }

        XCTContext.runActivity(named: "Save to shows the output folder") { _ in
            page.saveTo.requireShows("output")
        }

        let status = XCTContext.runActivity(named: "Probe settles") { _ in
            page.queue.waitForProbe()
        }

        XCTContext.runActivity(named: "Extract matches the row") { _ in
            let terminal = status == "Failed" || status == "No subtitles" || status == "Image subs"
            page.assertPrimary(titled: "Extract", enabled: !terminal)
        }
    }
}
