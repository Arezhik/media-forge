import MediaTesting
import XCTest

// Scan child folders (issue #19). Off (the `--uitesting` default) lists only the
// top-level MKV. On lists nested files, skips a dot-folder, flags a duplicate base
// name, and Split writes the Ready rows flat into Output.
// One duplicate issue, so the Reason is `Duplicate name in Source folder` with no
// `(+1 more)`. Settled files with audio and subtitles and no chapters are
// `Ready, No chapters found`, same as SplitReadyUITests.

@MainActor
final class SplitChildFolderScanUITests: BaseUITest {
    private static let readyReason = "Ready, No chapters found"
    private static let duplicateReason = "Issue, Duplicate name in Source folder"

    override func prepareFixtures() async throws {
        let season1 = try makeDirectory("Season 1", in: fixtures.input)
        let bonus = try makeDirectory("Bonus", in: season1)
        let season2 = try makeDirectory("Season 2", in: fixtures.input)
        let hidden = try makeDirectory(".folder", in: fixtures.input)

        try seed("Top.mkv", in: fixtures.input)
        try seed("Episode.mkv", in: season1)
        try seed("Extra.mkv", in: bonus)
        try seed("Hidden.mkv", in: hidden)
        try seed("Same.mkv", in: season1)
        try seed("Same.mkv", in: season2)
    }

    func testScanChildFoldersOffThenOnAndSplitWritesFlatMKA() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Split chrome and seeded folders") { _ in
            page.waitForSplitChrome()
            page.sourceFolder.assertShowsPathFragment("input")
            page.outputFolder.assertShowsPathFragment("output")
        }

        try XCTContext.runActivity(named: "Scan with child folders off") { _ in
            try page.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Only the top-level file is listed") { _ in
            page.queueRow(stem: "Top").requireExactLabel(ready("Top"))
            page.queueRow(stem: "Episode").assertExactLabelAbsent(ready("Episode"))
            page.queueRow(stem: "Extra").assertExactLabelAbsent(ready("Extra"))
            page.queueRow(stem: "Hidden").assertExactLabelAbsent(ready("Hidden"))
            page.queueRow(stem: "Same").assertExactLabelAbsent(ready("Same"))
            page.queueRow(stem: "Same").assertExactLabelAbsent(duplicate("Same"))
            page.assertScanStatus(containing: " \u{00B7} 1 MKV file")
            page.assertPrimary(titled: "Split", enabled: true)
        }

        XCTContext.runActivity(named: "Turn Scan child folders on") { _ in
            let settings = SettingsPage.open(in: app)
            settings.waitForSettingsChrome()
            settings.waitUntilSwitch(named: "Scan child folders", isOn: false)
            settings.clickScanChildFolders()
            settings.waitUntilSwitch(named: "Scan child folders", isOn: true)
        }

        XCTContext.runActivity(named: "Return to the MKVForge window") { _ in
            page.activateMainWindow()
            page.assertScanStatus(equalTo: "Not scanned yet")
        }

        try XCTContext.runActivity(named: "Scan again with child folders on") { _ in
            try page.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Nested files are listed and the duplicate is flagged") { _ in
            page.queueRow(stem: "Top").requireExactLabel(ready("Top"))
            page.queueRow(stem: "Episode").requireExactLabel(ready("Episode"))
            page.queueRow(stem: "Extra").requireExactLabel(ready("Extra"))
            page.queueRow(stem: "Same").requireExactLabel(duplicate("Same"))
            page.queueRow(stem: "Hidden").assertExactLabelAbsent(ready("Hidden"))
            page.assertScanStatus(containing: " \u{00B7} 4 MKV files")
            page.assertPrimary(titled: "Split", enabled: true)
        }

        XCTContext.runActivity(named: "Run Split on the Ready rows") { _ in
            page.clickPrimaryAction(titled: "Split")
        }

        XCTContext.runActivity(named: "Ready rows finish and the duplicate stays flagged") { _ in
            page.queueRow(stem: "Top").requireExactLabel("Top, Done", timeout: UITestTimeout.batch)
            page.queueRow(stem: "Episode").requireExactLabel("Episode, Done", timeout: UITestTimeout.batch)
            page.queueRow(stem: "Extra").requireExactLabel("Extra, Done", timeout: UITestTimeout.batch)
            page.queueRow(stem: "Same").requireExactLabel(
                duplicate("Same"),
                timeout: UITestTimeout.batch
            )
        }

        XCTContext.runActivity(named: "Bottom bar counts three done and one flagged") { _ in
            page.bottomBar.assertSummary(
                "Finished \u{00B7} 3 done \u{00B7} 1 flagged",
                timeout: UITestTimeout.batch
            )
            page.bottomBar.assertProgress(
                value: "3 of 3 complete",
                caption: "3 .mka saved",
                timeout: UITestTimeout.batch
            )
        }

        try XCTContext.runActivity(named: "Outputs are flat in the Output folder") { _ in
            try assertOutputsAreFlat()
        }
    }

    private func ready(_ stem: String) -> String {
        "\(stem), \(Self.readyReason)"
    }

    private func duplicate(_ stem: String) -> String {
        "\(stem), \(Self.duplicateReason)"
    }

    private func makeDirectory(_ name: String, in parent: URL) throws -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `createValidMediaFile` throws `XCTSkip` when ffmpeg is missing.
    private func seed(_ name: String, in directory: URL) throws {
        let url = try fixtures.createValidMediaFile(
            in: directory,
            named: name,
            includeAudio: true,
            includeSubtitles: true
        )
        try fixtures.settle(url)
    }

    private func assertOutputsAreFlat() throws {
        for name in ["Top.mka", "Episode.mka", "Extra.mka"] {
            let url = fixtures.output.appendingPathComponent(name)
            XCTAssertGreaterThan(fixtures.byteCount(at: url) ?? 0, 0, "\(name) is missing or empty")
        }
        XCTAssertNil(fixtures.byteCount(at: fixtures.output.appendingPathComponent("Same.mka")))
        XCTAssertNil(fixtures.byteCount(at: fixtures.output.appendingPathComponent("Hidden.mka")))

        let children = try FileManager.default.contentsOfDirectory(
            at: fixtures.output,
            includingPropertiesForKeys: nil,
            options: []
        )
        let names = Set(children.map(\.lastPathComponent))
        XCTAssertFalse(names.contains("Season 1"), "Output contains Season 1")
        XCTAssertFalse(names.contains("Season 2"), "Output contains Season 2")
        XCTAssertFalse(names.contains(".folder"), "Output contains .folder")
    }
}
