import XCTest
@testable import MediaTesting

final class MediaTestingTests: XCTestCase {
    func testMarkerName() {
        XCTAssertEqual(MediaTestingMarker.moduleName, "MediaTesting")
    }
}
