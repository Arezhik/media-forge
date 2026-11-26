import XCTest
@testable import MediaUI

final class MediaUITests: XCTestCase {
    func testMarkerCompilesWithoutSwiftUI() {
        XCTAssertEqual(MediaUIMarker.moduleName, "MediaUI")
        #if canImport(SwiftUI)
        XCTAssertTrue(MediaUIMarker.swiftUIAvailable)
        #else
        XCTAssertFalse(MediaUIMarker.swiftUIAvailable)
        #endif
    }
}
