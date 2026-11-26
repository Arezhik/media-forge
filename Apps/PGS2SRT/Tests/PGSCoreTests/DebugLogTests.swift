import Foundation
import MediaCore
import XCTest
@testable import PGSCore

final class DebugLogTests: XCTestCase {
    func testLogDescriptionNamesTheChoices() {
        XCTAssertEqual(
            ConversionPreferences.default.logDescription,
            "language en-US, save next to the source file, if the .srt exists overwrite, 4 pictures at a time, italics off, choose MKV track off, after conversion save right away, notifications when a batch finishes"
        )
        let settings = ConversionPreferences(
            placement: .folder("/Users/ada/Subs"),
            language: "en-US",
            existingFile: .addNumber,
            concurrency: 4,
            experimentalItalics: true,
            chooseMKVTrack: true
        )
        XCTAssertEqual(
            settings.logDescription,
            "language en-US, save folder /Users/ada/Subs, if the .srt exists add a number, 4 pictures at a time, italics on, choose MKV track on, after conversion save right away, notifications when a batch finishes"
        )
        let emptyFolder = ConversionPreferences(
            placement: .folder(""),
            language: "ja-JP",
            existingFile: .skip,
            concurrency: 2,
            experimentalItalics: false,
            chooseMKVTrack: false,
            saveTiming: .afterReview,
            batchNotification: .never
        )
        XCTAssertEqual(
            emptyFolder.logDescription,
            "language ja-JP, save a folder that has not been chosen, if the .srt exists skip, 2 pictures at a time, italics off, choose MKV track off, after conversion hold for review, notifications off"
        )
    }

    func testRecognizedSubtitleTextStaysOutOfTheLog() async throws {
        let directory = temporaryDirectory()
        defer {
            DebugLog.shared.reset()
            try? FileManager.default.removeItem(at: directory)
        }
        DebugLog.shared.configure(appName: AppIdentity.name, directory: directory, homeDirectory: "/Users/ada")
        let phrase = "Zed quin subtitle 9041"
        let pipeline = TranscriptionPipeline(languages: ["en-US"], maxConcurrent: 1)
        let result = try await pipeline.transcribe(
            cues: [DebugLogSample.cue()],
            recognizer: DebugLogSample.Recognizer(text: phrase)
        )
        XCTAssertTrue(result.srt.contains(phrase))
        let log = DebugLog.shared.recentText()
        XCTAssertTrue(log.contains("[ocr]"))
        XCTAssertTrue(log.contains("OCR finished, 1 cues, 0 failed"))
        XCTAssertFalse(log.contains(phrase))
        XCTAssertFalse(log.contains("/Users/ada"))
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("pgs-log-\(UUID().uuidString)", isDirectory: true)
    }
}

private enum DebugLogSample {
    static func cue() -> SubtitleCue {
        SubtitleCue(
            startPTS: 0,
            endPTS: 90_000,
            image: SubtitleImage(
                width: 1,
                height: 1,
                rgba: [0, 0, 0, 0],
                originX: 0,
                originY: 0,
                videoWidth: 100,
                videoHeight: 100
            ),
            forced: false,
            endReason: .clearingDisplaySet
        )
    }

    struct Recognizer: SubtitleRecognizing {
        var text: String
        func recognize(image: SubtitleImage, languages: [String]) async throws -> OCRResult {
            OCRResult(text: text)
        }
    }
}
