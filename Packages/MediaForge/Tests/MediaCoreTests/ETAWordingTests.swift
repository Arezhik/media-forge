import XCTest
import MediaCore

final class ETAWordingTests: XCTestCase {
    func testSentenceRoundsToSecondsMinutesAndHours() {
        XCTAssertEqual(ETAWording.sentence(0), "About 1 second left")
        XCTAssertEqual(ETAWording.sentence(0.4), "About 1 second left")
        XCTAssertEqual(ETAWording.sentence(1), "About 1 second left")
        XCTAssertEqual(ETAWording.sentence(2), "About 2 seconds left")
        XCTAssertEqual(ETAWording.sentence(59.4), "About 59 seconds left")
        XCTAssertEqual(ETAWording.sentence(59.6), "About 1 minute left")
        XCTAssertEqual(ETAWording.sentence(60), "About 1 minute left")
        XCTAssertEqual(ETAWording.sentence(90), "About 2 minutes left")
        XCTAssertEqual(ETAWording.sentence(3_599), "About 1 hour left")
        XCTAssertEqual(ETAWording.sentence(3_600), "About 1 hour left")
        XCTAssertEqual(ETAWording.sentence(3_660), "About 1 hour 1 minute left")
        XCTAssertEqual(ETAWording.sentence(5_400), "About 1 hour 30 minutes left")
        XCTAssertEqual(ETAWording.sentence(7_200), "About 2 hours left")
        XCTAssertEqual(ETAWording.sentence(7_320), "About 2 hours 2 minutes left")
        XCTAssertEqual(ETAWording.sentence(-1), "")
        XCTAssertEqual(ETAWording.sentence(.infinity), "")
        XCTAssertEqual(ETAWording.sentence(.nan), "")
    }
}
