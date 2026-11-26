import XCTest
import MediaCore

final class ProgressThrottleTests: XCTestCase {
    func testThrottleAllowsAboutTenUpdatesASecond() {
        var throttle = ProgressThrottle()
        let start = Date(timeIntervalSince1970: 1000)
        var published = 0
        for tick in 0..<100 {
            // 100 ticks over one second, one every 10 ms.
            if throttle.shouldPublish(at: start.addingTimeInterval(Double(tick) * 0.01)) {
                published += 1
            }
        }
        // Floating-point tick times can land a hair under the interval, so allow 9 or 10.
        XCTAssertTrue((9...10).contains(published), "published \(published)")
        XCTAssertTrue(throttle.shouldPublish(at: start.addingTimeInterval(0.995), force: true))
    }

    func testResetPublishesTheNextTickInsideTheInterval() {
        var throttle = ProgressThrottle()
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(throttle.shouldPublish(at: start))
        XCTAssertFalse(throttle.shouldPublish(at: start.addingTimeInterval(0.05)))
        throttle.reset()
        XCTAssertTrue(throttle.shouldPublish(at: start.addingTimeInterval(0.05)))
    }

    func testAZeroIntervalPublishesEveryTick() {
        var throttle = ProgressThrottle(minimumInterval: 0)
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(throttle.shouldPublish(at: start))
        XCTAssertTrue(throttle.shouldPublish(at: start))
        XCTAssertEqual(ProgressThrottle.defaultInterval, 0.1)
    }
}
