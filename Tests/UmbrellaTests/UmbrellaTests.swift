import XCTest
import MediaCore
import MediaTesting
import MediaUI

final class UmbrellaTests: XCTestCase {
    func testCanonicalProductsLink() {
        XCTAssertEqual(MediaCoreMarker.moduleName, "MediaCore")
        XCTAssertEqual(MediaUIMarker.moduleName, "MediaUI")
        XCTAssertEqual(MediaTestingMarker.moduleName, "MediaTesting")
    }
}
