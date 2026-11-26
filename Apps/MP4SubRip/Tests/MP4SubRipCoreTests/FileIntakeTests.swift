import XCTest
@testable import MP4SubRipCore
import MediaCore

/// The walk lives in MediaCore. This checks the words and extensions this app passes in.
final class FileIntakeTests: XCTestCase {
    func testMP4ExtensionsAndWording() {
        let listing = DirectoryListing(
            isDirectory: { _ in false },
            children: { _ in [] }
        )
        let result = FileIntake.collect(
            paths: ["/films/Movie.mp4", "/films/Poster.jpg", "/films/Movie.MP4"],
            accepted: AppIdentity.inputExtensions,
            listing: listing
        )
        XCTAssertEqual(result.sourcePaths, ["/films/Movie.mp4", "/films/Movie.MP4"])
        XCTAssertEqual(result.notices, [.unsupported(path: "/films/Poster.jpg")])
        XCTAssertEqual(
            result.notices[0].message(fileDescription: AppIdentity.inputDescription),
            "Poster.jpg is not a .mp4 file, so it was skipped."
        )
        XCTAssertEqual(AppIdentity.inputExtensions, ["mp4"])
        XCTAssertEqual(AppIdentity.inputDescription, ".mp4")
    }
}
