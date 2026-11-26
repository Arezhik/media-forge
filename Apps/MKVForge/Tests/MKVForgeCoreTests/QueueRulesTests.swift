import XCTest
@testable import MKVForgeCore

final class QueueRulesTests: XCTestCase {
    func testOnlyWaitingAndWorkingAreActive() {
        XCTAssertTrue(JobStatus.waiting.isActive)
        XCTAssertTrue(JobStatus.working.isActive)
        XCTAssertFalse(JobStatus.done(outputPath: "/a").isActive)
        XCTAssertFalse(JobStatus.doneWithWarning(outputPath: "/a", warnings: []).isActive)
        XCTAssertFalse(JobStatus.failed(reason: "x", detail: "").isActive)
        XCTAssertFalse(JobStatus.notRun.isActive)
        XCTAssertFalse(JobStatus.canceled.isActive)
    }

    func testStatusTextsFollowTheContract() {
        XCTAssertEqual(JobStatus.waiting.statusText(mode: .split), "Waiting")
        XCTAssertEqual(JobStatus.working.statusText(mode: .split), "Splitting…")
        XCTAssertEqual(JobStatus.working.statusText(mode: .remux), "Remuxing…")
        XCTAssertEqual(JobStatus.notRun.statusText(mode: .split), "Ready")
        XCTAssertEqual(JobStatus.doneWithWarning(outputPath: "/a", warnings: []).statusText(mode: .remux), "Done · warning")
    }

    func testProgressTickIsWorkingToWorkingOnly() {
        let working = JobStatus.working
        XCTAssertTrue(working.isProgressTick(to: .working))
        XCTAssertFalse(working.isProgressTick(to: .done(outputPath: "/a")))
        XCTAssertFalse(JobStatus.waiting.isProgressTick(to: working))
    }

}
