import XCTest
@testable import PGSCore
import MediaCore

/// The walk lives in MediaCore. These checks lock this app's extensions, notice
/// wording, and the document types Finder uses for Open With.
final class FileIntakeTests: XCTestCase {
    func testExplicitMkvIsQueuedAndOtherFilesAreNoted() {
        let result = SubtitleFiles.collect(
            paths: ["/films/Movie.mkv", "/films/Poster.jpg", "/films/Movie.sup", "/films/Movie.sup"],
            listing: MapListing(directories: [:]).listing
        )
        XCTAssertEqual(result.sourcePaths, ["/films/Movie.mkv", "/films/Movie.sup"])
        XCTAssertEqual(result.notices, [
            .unsupported(path: "/films/Poster.jpg")
        ])
        XCTAssertEqual(
            result.notices[0].message(fileDescription: SubtitleFiles.fileDescription),
            "Poster.jpg is not a .sup or .mkv file, so it was skipped."
        )
        XCTAssertTrue(result.notices[0].isFile)
        XCTAssertEqual(result.notices[0].path, "/films/Poster.jpg")
        XCTAssertEqual(SubtitleFiles.acceptedExtensions, ["sup", "mkv"])
    }

    func testEmptyAndUnreadableFolders() {
        let listing = MapListing(
            directories: ["/empty": []],
            unreadable: ["/locked"]
        )
        let empty = SubtitleFiles.collect(paths: ["/empty/"], listing: listing.listing)
        XCTAssertEqual(empty.sourcePaths, [])
        XCTAssertEqual(empty.notices, [.noMatchingFiles(folderName: "empty")])
        XCTAssertEqual(
            empty.notices[0].message(fileDescription: SubtitleFiles.fileDescription),
            "No .sup or .mkv files were found in empty."
        )
        XCTAssertFalse(empty.notices[0].isFile)

        let locked = SubtitleFiles.collect(paths: ["/locked"], listing: listing.listing)
        XCTAssertEqual(locked.notices, [.unreadableFolder(folderName: "locked")])
        XCTAssertEqual(
            locked.notices[0].message(fileDescription: SubtitleFiles.fileDescription),
            "Could not look inside locked."
        )
    }

    func testDockAndOpenWithAcceptSupFilesAndFolders() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let types = plist?["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        let contentTypes = types.flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }
        let extensions = types.flatMap { $0["CFBundleTypeExtensions"] as? [String] ?? [] }
        XCTAssertTrue(contentTypes.contains("com.pgs2srt.pgs-subtitle"))
        XCTAssertTrue(contentTypes.contains("public.folder"))
        XCTAssertTrue(extensions.contains("sup"))
        XCTAssertTrue(extensions.contains("mkv"))
        XCTAssertTrue(contentTypes.contains("org.matroska.mkv"))
        let folder = types.first { ($0["LSItemContentTypes"] as? [String])?.contains("public.folder") == true }
        XCTAssertEqual(folder?["LSHandlerRank"] as? String, "Alternate")
        XCTAssertEqual(folder?["CFBundleTypeRole"] as? String, "Viewer")
        let mkv = types.first { ($0["CFBundleTypeExtensions"] as? [String])?.contains("mkv") == true }
        XCTAssertEqual(mkv?["LSHandlerRank"] as? String, "Alternate")
        XCTAssertEqual(mkv?["CFBundleTypeRole"] as? String, "Viewer")
        XCTAssertEqual(types.first?["CFBundleTypeExtensions"] as? [String], ["sup"])
        XCTAssertGreaterThanOrEqual(types.count, 3)
        XCTAssertEqual(types[1]["LSItemContentTypes"] as? [String], ["public.folder"])
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
