import Foundation
import XCTest
@testable import MediaTesting

final class MediaTestingTests: XCTestCase {
    func testMarkerName() {
        XCTAssertEqual(MediaTestingMarker.moduleName, "MediaTesting")
    }

    func testDummyFileByteCountAndSettle() throws {
        let builder = try UITestFixtureBuilder()
        defer { builder.cleanup() }
        XCTAssertNil(builder.byteCount(at: builder.input.appendingPathComponent("missing.mkv")))
        let file = try builder.createDummyFile(in: builder.input, named: "a.mkv")
        XCTAssertEqual(builder.byteCount(at: file), 0)
        let srt = try builder.createValidSRTFile(in: builder.output, named: "a.srt", lines: ["Hello"])
        let srtText = try String(contentsOf: srt, encoding: .utf8)
        XCTAssertTrue(srtText.contains("00:00:00,000 --> 00:00:01,000"))
        XCTAssertTrue(srtText.contains("Hello"))
        let sup = try builder.createValidPGSFile(in: builder.input, named: "a.sup")
        let supBytes = try Data(contentsOf: sup)
        XCTAssertEqual(Array(supBytes.prefix(2)), [0x50, 0x47])
        XCTAssertGreaterThan(builder.byteCount(at: sup) ?? 0, 0)
        try builder.settle(file)
        let values = try FileManager.default.attributesOfItem(atPath: file.path)
        let modified = try XCTUnwrap(values[.modificationDate] as? Date)
        XCTAssertLessThan(modified.timeIntervalSinceNow, -60)
    }

    func testMissingFFmpegThrowsWhenTheToolIsAbsent() throws {
        let homebrew = "/opt/homebrew/bin/ffmpeg"
        let local = "/usr/local/bin/ffmpeg"
        if FileManager.default.isExecutableFile(atPath: homebrew)
            || FileManager.default.isExecutableFile(atPath: local) {
            throw XCTSkip("ffmpeg is installed; the missing-tool path is not exercised")
        }
        let builder = try UITestFixtureBuilder()
        defer { builder.cleanup() }
        XCTAssertThrowsError(try builder.createValidMediaFile(in: builder.video, named: "a.mkv")) { error in
            XCTAssertTrue(String(describing: error).contains("ffmpeg was not found"))
        }
    }
}
