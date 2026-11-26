import XCTest
@testable import MediaCore

final class FileIntakeTests: XCTestCase {
    private let accepted: Set<String> = ["in"]

    private func listing(_ tree: [String: [String]], unreadable: Set<String> = []) -> DirectoryListing {
        DirectoryListing(
            isDirectory: { tree[$0] != nil || unreadable.contains($0) },
            children: { path in
                if unreadable.contains(path) { throw CocoaError(.fileReadNoPermission) }
                return tree[path] ?? []
            }
        )
    }

    func testFolderIsWalkedIncludingSubfolders() {
        let disk = listing([
            "/m": ["/m/a.in", "/m/notes.txt", "/m/sub"],
            "/m/sub": ["/m/sub/b.IN"]
        ])
        let result = FileIntake.collect(paths: ["/m/"], accepted: accepted, listing: disk)
        XCTAssertEqual(result.sourcePaths, ["/m/a.in", "/m/sub/b.IN"])
        XCTAssertEqual(result.notices, [])
    }

    func testUnsupportedFileBecomesANotice() {
        let result = FileIntake.collect(paths: ["/x/photo.jpg"], accepted: accepted, listing: listing([:]))
        XCTAssertEqual(result.sourcePaths, [])
        XCTAssertEqual(result.notices, [.unsupported(path: "/x/photo.jpg")])
        XCTAssertEqual(
            result.notices[0].message(fileDescription: ".in"),
            "photo.jpg is not a .in file, so it was skipped."
        )
        XCTAssertTrue(result.notices[0].isFile)
        XCTAssertEqual(result.notices[0].path, "/x/photo.jpg")
    }

    func testEmptyAndUnreadableFolders() {
        let disk = listing(["/empty": []], unreadable: ["/locked"])
        let result = FileIntake.collect(paths: ["/empty", "/locked"], accepted: accepted, listing: disk)
        XCTAssertEqual(result.notices, [.noMatchingFiles(folderName: "empty"), .unreadableFolder(folderName: "locked")])
        XCTAssertEqual(
            result.notices[0].message(fileDescription: ".sup or .mkv"),
            "No .sup or .mkv files were found in empty."
        )
        XCTAssertEqual(
            result.notices[1].message(fileDescription: ".mp4"),
            "Could not look inside locked."
        )
        XCTAssertFalse(result.notices[0].isFile)
        XCTAssertNil(result.notices[1].path)
    }

    func testDuplicatesAreAddedOnce() {
        let disk = listing(["/m": ["/m/a.in"]])
        let result = FileIntake.collect(paths: ["/m/a.in", "/m"], accepted: accepted, listing: disk)
        XCTAssertEqual(result.sourcePaths, ["/m/a.in"])
    }

    func testSeveralExtensionsAreAcceptedTogether() {
        let listing = MapListing(directories: [
            "/films": ["/films/Movie.sup", "/films/nested", "/films/Extra.mkv", "/films/notes.txt"],
            "/films/nested": ["/films/nested/Two.SUP"]
        ])
        let result = FileIntake.collect(
            paths: ["/films"],
            accepted: ["sup", "mkv"],
            listing: listing.listing
        )
        XCTAssertEqual(result.sourcePaths, ["/films/Movie.sup", "/films/nested/Two.SUP", "/films/Extra.mkv"])
        XCTAssertEqual(result.notices, [])
    }

    func testADirectoryLinkBackToItsParentDoesNotLoop() {
        let listing = MapListing(
            directories: [
                "/films": ["/films/Movie.sup", "/films/loop"],
                "/films/loop": ["/films/loop"]
            ],
            identities: ["/films/loop": "/films"]
        )
        let result = FileIntake.collect(
            paths: ["/films", "/films"],
            accepted: ["sup", "mkv"],
            listing: listing.listing
        )
        XCTAssertEqual(result.sourcePaths, ["/films/Movie.sup"])
        XCTAssertEqual(result.notices, [])
        XCTAssertEqual(listing.reads, ["/films"])
    }

    func testLiveListingFindsNestedFilesAndSkipsHiddenOnes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("intake-\(UUID().uuidString)")
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(FileManager.default.createFile(atPath: root.appendingPathComponent("A.sup").path, contents: Data([1])))
        XCTAssertTrue(FileManager.default.createFile(atPath: nested.appendingPathComponent("B.SUP").path, contents: Data([2])))
        XCTAssertTrue(FileManager.default.createFile(atPath: root.appendingPathComponent("C.mkv").path, contents: Data([3])))
        XCTAssertTrue(FileManager.default.createFile(atPath: root.appendingPathComponent(".hidden.sup").path, contents: Data([4])))
        XCTAssertTrue(FileManager.default.createFile(atPath: root.appendingPathComponent("notes.txt").path, contents: Data([5])))

        let result = FileIntake.collect(paths: [root.path], accepted: ["sup", "mkv"], listing: .live)
        XCTAssertEqual(result.sourcePaths.sorted(), [
            root.appendingPathComponent("A.sup").path,
            root.appendingPathComponent("C.mkv").path,
            nested.appendingPathComponent("B.SUP").path
        ].sorted())
        XCTAssertEqual(result.notices, [])
    }

    func testExtensionCheckIsCaseInsensitive() {
        XCTAssertTrue(FileIntake.isAccepted("/a/Movie.MKV", ["mkv"]))
        XCTAssertFalse(FileIntake.isAccepted("/a/Movie.mp4", ["sup", "mkv"]))
        XCTAssertEqual(FileIntake.lastComponent("/films/Movie.sup"), "Movie.sup")
        XCTAssertEqual(FileIntake.lastComponent(""), "")
    }
}

private final class MapListing: @unchecked Sendable {
    var directories: [String: [String]]
    var unreadable: Set<String>
    var identities: [String: String]
    private(set) var reads: [String] = []

    init(
        directories: [String: [String]],
        unreadable: Set<String> = [],
        identities: [String: String] = [:]
    ) {
        self.directories = directories
        self.unreadable = unreadable
        self.identities = identities
    }

    var listing: DirectoryListing {
        DirectoryListing(
            isDirectory: { path in
                self.directories[path] != nil || self.unreadable.contains(path)
            },
            children: { path in
                self.reads.append(path)
                if self.unreadable.contains(path) {
                    throw CocoaError(.fileReadNoPermission)
                }
                return self.directories[path] ?? []
            },
            identity: { self.identities[$0] ?? $0 }
        )
    }
}
