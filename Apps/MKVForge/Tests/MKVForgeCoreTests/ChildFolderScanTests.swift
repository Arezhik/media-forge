import XCTest
@testable import MKVForgeCore

/// Issue #19. Child-folder scans stay Linux-runnable: a fake listing checks the scan,
/// and `LocalFolderLister` checks the real walk (hidden folders, packages, cycles).
final class ChildFolderScanTests: XCTestCase {
    private typealias F = ScanFixture
    private let src = "/media/Rips"
    private let out = "/media/Audio"
    private let video = "/v/Video"
    private let audio = "/v/Audio"
    private let finished = "/v/Finished"

    func testRelativeNameKeepsTheFolderOnTheSourceAndTheFileNameOnTheOutput() {
        let entry = FileEntry(name: "Season 1/Episode.mkv")
        XCTAssertEqual(entry.fileName, "Episode.mkv")
        XCTAssertEqual(entry.baseName, "Episode")
        XCTAssertEqual(entry.pathExtension, "mkv")
        XCTAssertEqual(FolderScanner.join("/src", entry.name), "/src/Season 1/Episode.mkv")
        XCTAssertEqual(FolderScanner.join("/out", entry.baseName + ".mka"), "/out/Episode.mka")
    }

    func testCandidatesSkipHiddenComponentsAndPackages() {
        let entries = [
            F.file("Top.mkv"),
            F.file("Season 1/Episode.mkv"),
            F.file(".Hidden/Secret.mkv"),
            F.file("Season 1/.keep/Nope.mkv"),
            F.file("._sidecar/Nope.mkv"),
            F.file("Shown.app/Inside.mkv"),
            F.file("SHOWN.APP/Also.mkv"),
            F.file("Library.photoslibrary/Clip.mkv"),
            F.file("Notes.rtfd/Inside.mkv"),
        ]
        XCTAssertEqual(
            ScanFilter.candidates(entries, fileExtension: "mkv").map(\.name).sorted(),
            ["Season 1/Episode.mkv", "Top.mkv"]
        )
    }

    func testNestedSplitScanUsesTheRelativeSourceAndAFlatOutput() async throws {
        let lister = FakeLister(
            folders: [src: [F.file("Top.mkv")]],
            recursive: [src: [
                F.file("Top.mkv"),
                F.file("Season 1/Episode.mkv"),
                F.file(".Hidden/Secret.mkv"),
                F.file("Shown.app/Inside.mkv"),
                F.file("Season 1/Show.mkv"),
                F.file("Season 2/Show.mkv"),
            ]]
        )
        let episode = FolderScanner.join(src, "Season 1/Episode.mkv")
        let top = FolderScanner.join(src, "Top.mkv")
        let media = F.media(.video, .audio, chapterEditions: 1)
        let identifier = FakeIdentifier([episode: media, top: media])
        let result = try await F.scanner(lister, identifier).scanSplit(source: src, output: out, scanChildFolders: true)

        let nested = try XCTUnwrap(result.item("Episode"))
        XCTAssertTrue(nested.isReady)
        XCTAssertEqual(nested.sourcePath, episode)
        XCTAssertEqual(nested.outputPath, FolderScanner.join(out, "Episode.mka"))
        XCTAssertFalse(nested.outputPath.contains("Season"))

        XCTAssertEqual(result.item("Top")?.sourcePath, top)
        XCTAssertEqual(result.item("Top")?.outputPath, FolderScanner.join(out, "Top.mka"))
        XCTAssertNil(result.item("Secret"))
        XCTAssertNil(result.item("Inside"))

        let duplicate = try XCTUnwrap(result.item("Show"))
        XCTAssertEqual(duplicate.issues, [.duplicateName(.source, fileNames: ["Season 1/Show.mkv", "Season 2/Show.mkv"])])
        XCTAssertEqual(duplicate.reasonText, "Duplicate name in Source folder")
        XCTAssertFalse(duplicate.isReady)
        XCTAssertTrue(RunJob.jobs(from: result, checked: ["Show", "Episode", "Top"]).map(\.baseName).sorted() == ["Episode", "Top"])

        let calls = await identifier.calls
        XCTAssertEqual(Set(calls), [episode, top])
    }

    /// The default argument is off: a nested file the recursive listing would return stays unseen.
    func testDefaultScanStaysTopLevel() async throws {
        let lister = FakeLister(
            folders: [src: [F.file("Top.mkv")]],
            recursive: [src: [F.file("Top.mkv"), F.file("Season 1/Episode.mkv")]]
        )
        let top = FolderScanner.join(src, "Top.mkv")
        let identifier = FakeIdentifier([top: F.media(.video, .audio, chapterEditions: 1)])
        let result = try await F.scanner(lister, identifier).scanSplit(source: src, output: out)
        XCTAssertEqual(result.items.map(\.baseName), ["Top"])
        XCTAssertNil(result.item("Episode"))
        XCTAssertEqual(result.item("Top")?.outputPath, FolderScanner.join(out, "Top.mka"))
        let calls = await identifier.calls
        XCTAssertEqual(calls, [top])
    }

    func testRemuxMatchesAcrossTheTreeAndKeepsOutputFlat() async throws {
        let lister = FakeLister(
            folders: [video: [], audio: []],
            recursive: [
                video: [F.file("Season 1/Show.mkv")],
                audio: [F.file("CD/Show.mka")],
            ]
        )
        let videoPath = FolderScanner.join(video, "Season 1/Show.mkv")
        let audioPath = FolderScanner.join(audio, "CD/Show.mka")
        let probes = [videoPath: F.media(.video), audioPath: F.media(.audio, .subtitles)]

        let off = try await F.scanner(lister, FakeIdentifier()).scanRemux(video: video, audio: audio, output: finished)
        XCTAssertTrue(off.items.isEmpty, "the default stays top-level, and this tree has nothing at the top")

        let identifier = FakeIdentifier(probes)
        let result = try await F.scanner(lister, identifier).scanRemux(video: video, audio: audio, output: finished, scanChildFolders: true)
        let item = try XCTUnwrap(result.item("Show"))
        XCTAssertTrue(item.isReady)
        XCTAssertEqual(item.sourcePath, videoPath)
        XCTAssertEqual(item.mkaPath, audioPath)
        XCTAssertEqual(item.outputPath, FolderScanner.join(finished, "Show.mkv"))
        XCTAssertNil(item.counterpartName)
        XCTAssertFalse(item.outputPath.contains("Season"))
        XCTAssertFalse(item.outputPath.contains("CD"))
        let calls = await identifier.calls
        XCTAssertEqual(Set(calls), [videoPath, audioPath])
    }

    func testRemuxMatchOnMKANamePairsAcrossTheTree() async throws {
        let lister = FakeLister(
            folders: [video: [], audio: []],
            recursive: [
                video: [F.file("Season 1/Show Extended.mkv")],
                audio: [F.file("Disc 1/Show.mka")],
            ]
        )
        let videoPath = FolderScanner.join(video, "Season 1/Show Extended.mkv")
        let audioPath = FolderScanner.join(audio, "Disc 1/Show.mka")
        let identifier = FakeIdentifier([
            videoPath: F.media(.video),
            audioPath: F.media(.audio, .subtitles),
        ])
        let result = try await F.scanner(lister, identifier).scanRemux(
            video: video, audio: audio, output: finished, matchOnMKAName: true, scanChildFolders: true
        )
        let item = try XCTUnwrap(result.item("Show Extended"))
        XCTAssertTrue(item.isReady)
        XCTAssertEqual(item.sourcePath, videoPath)
        XCTAssertEqual(item.mkaPath, audioPath)
        XCTAssertEqual(item.outputPath, FolderScanner.join(finished, "Show Extended.mkv"))
        XCTAssertEqual(item.counterpartName, "Show.mka")
        XCTAssertEqual(result.readyCount, 1)
        XCTAssertEqual(result.items.count, 1)
    }

    func testDuplicateBaseNamesAreFlaggedInRemuxIncludingMatchOnMKAName() async throws {
        let videos = [F.file("Season 1/Show.mkv"), F.file("Season 2/Show.mkv")]
        let audios = [F.file("A/Show.mka"), F.file("B/Show.mka")]
        let lister = FakeLister(
            folders: [video: [], audio: []],
            recursive: [video: videos, audio: audios]
        )
        let exact = try await F.scanner(lister, FakeIdentifier()).scanRemux(
            video: video, audio: audio, output: finished, scanChildFolders: true
        )
        let exactItem = try XCTUnwrap(exact.item("Show"))
        XCTAssertEqual(exactItem.issues, [
            .duplicateName(.video, fileNames: ["Season 1/Show.mkv", "Season 2/Show.mkv"]),
            .duplicateName(.audio, fileNames: ["A/Show.mka", "B/Show.mka"]),
        ])
        XCTAssertEqual(exactItem.reasonText, "Duplicate name in Video folder (+1 more)")
        XCTAssertFalse(exactItem.isReady)
        XCTAssertTrue(exactItem.outputPath.hasSuffix("/Show.mkv"))
        XCTAssertFalse(exactItem.outputPath.contains("Season"))

        let matching = try await F.scanner(lister, FakeIdentifier()).scanRemux(
            video: video, audio: audio, output: finished, matchOnMKAName: true, scanChildFolders: true
        )
        let matchingItem = try XCTUnwrap(matching.item("Show"))
        XCTAssertEqual(matchingItem.reasonText, "Duplicate name in Video folder (+1 more)")
        XCTAssertTrue(matchingItem.issues.contains(.duplicateName(.audio, fileNames: ["A/Show.mka", "B/Show.mka"])))
        XCTAssertFalse(matchingItem.isReady)
        XCTAssertTrue(RunJob.jobs(from: matching, checked: ["Show"]).isEmpty)
    }

    func testChildFolderSettingClearsBothQueuesAndRemuxPicks() {
        var split = UIFixture.state([UIFixture.ready("A")])
        let splitSource = split.folder(.source)
        split.childFolderSettingChanged()
        XCTAssertNil(split.scan)
        XCTAssertTrue(split.rows.isEmpty)
        XCTAssertNil(split.lastSummary)
        XCTAssertEqual(split.folder(.source), splitSource)

        var remux = ModeState(mode: .remux)
        remux.setFolder("/v", for: .video)
        let pick = RemuxPick(audioPath: "/a/A.mka", videoPath: "/v/A.mkv")
        remux.applyScan(ScanResult(
            mode: .remux,
            scannedAt: UIFixture.time,
            items: [UIFixture.ready("A", mode: .remux)],
            picks: [pick]
        ))
        XCTAssertEqual(remux.picks, [pick])
        remux.childFolderSettingChanged()
        XCTAssertNil(remux.scan)
        XCTAssertTrue(remux.rows.isEmpty)
        XCTAssertTrue(remux.picks.isEmpty)
        XCTAssertEqual(remux.folder(.video), "/v")

        var leftAlone = UIFixture.state([UIFixture.ready("A")])
        leftAlone.matchSettingChanged()
        XCTAssertNotNil(leftAlone.scan, "Match on MKA Name still leaves Split alone")
    }

    func testScanChildFoldersLockTracksAnyBusyActivity() {
        XCTAssertFalse(ScanChildFoldersLock.isLocked(activity: .idle))
        XCTAssertTrue(ScanChildFoldersLock.isLocked(activity: .scanning(.listing)))
        XCTAssertTrue(ScanChildFoldersLock.isLocked(activity: .scanning(.reading(current: 1, total: 2))))
        XCTAssertTrue(ScanChildFoldersLock.isLocked(activity: .running))
        XCTAssertTrue(ScanChildFoldersLock.isLocked(activity: .cancelling))
    }
}

/// The real folder walk. Hidden folders and packages are not opened. A symlink cycle stops.
final class ChildFolderListingTests: XCTestCase {
    private var root = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-child-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: root)
    }

    func testRecursiveListingFindsNestedFilesAndSkipsHiddenFoldersAndPackages() async throws {
        let source = try makeDir("Source")
        let output = try makeDir("Output")
        try write(in: source, relative: "Top.mkv")
        try write(in: source, relative: "Season 1/Episode.mkv")
        try write(in: source, relative: "A/B/C/Deep.mkv")
        try write(in: source, relative: "Extra/Copy.mkv")
        try write(in: source, relative: "Season 2/Copy.mkv")
        try write(in: source, relative: ".Hidden/Secret.mkv")
        try write(in: source, relative: "Shown.app/Inside.mkv")
        try write(in: source, relative: "Notes.rtfd/Page.mkv")

        let lister = LocalFolderLister()
        let names = Set(try lister.recursiveEntries(in: source).map(\.name))
        XCTAssertEqual(names, ["Top.mkv", "Season 1/Episode.mkv", "A/B/C/Deep.mkv", "Extra/Copy.mkv", "Season 2/Copy.mkv"])
        let topLevel = try lister.entries(in: source).map(\.name)
        XCTAssertFalse(topLevel.contains { $0.contains("/") })
        XCTAssertTrue(topLevel.contains("Top.mkv"))
        XCTAssertFalse(topLevel.contains("Season 1/Episode.mkv"))

        let media = ScanFixture.media(.video, .audio, chapterEditions: 1)
        let episode = FolderScanner.join(source, "Season 1/Episode.mkv")
        let deep = FolderScanner.join(source, "A/B/C/Deep.mkv")
        let top = FolderScanner.join(source, "Top.mkv")
        let identifier = FakeIdentifier([top: media, episode: media, deep: media])
        let scanner = FolderScanner(lister: lister, identifier: identifier, now: { Date() })
        let on = try await scanner.scanSplit(source: source, output: output, scanChildFolders: true)

        XCTAssertEqual(on.item("Episode")?.sourcePath, episode)
        XCTAssertEqual(on.item("Episode")?.outputPath, FolderScanner.join(output, "Episode.mka"))
        XCTAssertEqual(on.item("Deep")?.sourcePath, deep)
        XCTAssertEqual(on.item("Deep")?.outputPath, FolderScanner.join(output, "Deep.mka"))
        XCTAssertTrue(on.item("Episode")?.isReady ?? false)
        XCTAssertTrue(on.item("Deep")?.isReady ?? false)
        XCTAssertNil(on.item("Secret"))
        XCTAssertNil(on.item("Inside"))
        XCTAssertNil(on.item("Page"))

        let copy = try XCTUnwrap(on.item("Copy"))
        XCTAssertEqual(copy.reasonText, "Duplicate name in Source folder")
        XCTAssertEqual(copy.issues, [.duplicateName(.source, fileNames: ["Extra/Copy.mkv", "Season 2/Copy.mkv"])])
        XCTAssertEqual(copy.outputPath, FolderScanner.join(output, "Copy.mka"))
        XCTAssertFalse(copy.isReady)

        let calls = await identifier.calls
        XCTAssertEqual(Set(calls), [top, episode, deep])

        let offIdentifier = FakeIdentifier([top: media])
        let offScanner = FolderScanner(lister: lister, identifier: offIdentifier, now: { Date() })
        let off = try await offScanner.scanSplit(source: source, output: output)
        XCTAssertEqual(off.items.map(\.baseName), ["Top"])
        XCTAssertEqual(off.item("Top")?.outputPath, FolderScanner.join(output, "Top.mka"))
        XCTAssertNil(off.item("Episode"))
        XCTAssertNil(off.item("Deep"))
    }

    func testSymlinkCycleDoesNotLoop() throws {
        let real = try makeDir("real")
        try write(in: real, relative: "A.mkv")
        try FileManager.default.createSymbolicLink(atPath: FolderScanner.join(root, "link"), withDestinationPath: real)
        try FileManager.default.createSymbolicLink(atPath: FolderScanner.join(real, "back"), withDestinationPath: root)

        let names = try LocalFolderLister().recursiveEntries(in: root).map(\.name)
        let mkvs = names.filter { $0.hasSuffix("A.mkv") }
        XCTAssertEqual(mkvs.count, 1)
        XCTAssertTrue(mkvs[0] == "real/A.mkv" || mkvs[0] == "link/A.mkv")
        XCTAssertFalse(names.contains { $0.contains("back") })
    }

    private func makeDir(_ name: String) throws -> String {
        let path = FolderScanner.join(root, name)
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func write(in folder: String, relative: String) throws {
        let path = FolderScanner.join(folder, relative)
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try Data("mkv".utf8).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: path)
    }
}
