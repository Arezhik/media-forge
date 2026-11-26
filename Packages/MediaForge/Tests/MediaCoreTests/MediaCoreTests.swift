import XCTest
@testable import MediaCore

final class MediaCoreTests: XCTestCase {
    func testMarkerName() {
        XCTAssertEqual(MediaCoreMarker.moduleName, "MediaCore")
    }
}
