import XCTest
import MediaCore
@testable import MP4SubRipCore

/// ffmpeg detection wording, the Settings choice, and the pick-time version check.
/// Locator search order, custom-path resolution, and the process runner live in MediaCoreTests.
final class ExternalToolTests: XCTestCase {
    func testDetectionLineAndHeaderShareOneResult() {
        let spec = ExternalToolSpec.primary
        let located = LocatedTool(
            name: "ffmpeg",
            path: "/opt/homebrew/bin/ffmpeg",
            version: "ffmpeg version 9.0.2",
            source: .automatic
        )
        let line = ToolDetection.logLine(spec: spec, located: located, customPath: nil)
        XCTAssertFalse(line.isError)
        XCTAssertEqual(
            line.message,
            "ffmpeg found (automatic) /opt/homebrew/bin/ffmpeg, version ffmpeg version 9.0.2"
        )
        XCTAssertFalse(line.message.contains("not found"))
        let facts = ToolDetection.facts(spec: spec, located: located, customPath: nil)
        XCTAssertEqual(facts.map(\.label), ["ffmpeg", "ffmpeg version"])
        XCTAssertEqual(facts.map(\.value), ["(automatic) /opt/homebrew/bin/ffmpeg", "ffmpeg version 9.0.2"])

        let chosen = LocatedTool(
            name: "ffmpeg",
            path: "/Users/me/bin/ffmpeg",
            version: "ffmpeg version 9.0.2",
            source: .chosenInSettings
        )
        let chosenLine = ToolDetection.logLine(spec: spec, located: chosen, customPath: chosen.path)
        let chosenFacts = ToolDetection.facts(spec: spec, located: chosen, customPath: chosen.path)
        XCTAssertEqual(
            chosenLine.message,
            "ffmpeg found (chosen in Settings) /Users/me/bin/ffmpeg, version ffmpeg version 9.0.2"
        )
        XCTAssertEqual(chosenFacts.map(\.label), ["ffmpeg", "ffmpeg version"])
        XCTAssertEqual(
            chosenFacts.map(\.value),
            ["(chosen in Settings) /Users/me/bin/ffmpeg", "ffmpeg version 9.0.2"]
        )

        let missing = ToolDetection.logLine(spec: spec, located: nil)
        XCTAssertTrue(missing.isError)
        XCTAssertEqual(missing.message, "ffmpeg not found")
        XCTAssertEqual(ToolDetection.facts(spec: spec, located: nil).map(\.value), ["not found", "not found"])

        let stale = "/Users/me/bin/ffmpeg"
        let staleLine = ToolDetection.logLine(spec: spec, located: nil, customPath: stale)
        let staleFacts = ToolDetection.facts(spec: spec, located: nil, customPath: stale)
        XCTAssertEqual(
            staleLine.message,
            "ffmpeg not found (chosen in Settings) \(stale); automatic was not used"
        )
        XCTAssertFalse(staleLine.message.contains("/opt/homebrew"))
        XCTAssertEqual(
            staleFacts.map(\.value),
            ["not found (chosen in Settings) \(stale); automatic was not used", "not found"]
        )

        let unchosenLine = ToolDetection.logLine(spec: spec, located: nil, customPath: "")
        let unchosenFacts = ToolDetection.facts(spec: spec, located: nil, customPath: "")
        XCTAssertEqual(unchosenLine.message, "ffmpeg not chosen")
        XCTAssertEqual(unchosenFacts.map(\.value), ["not chosen", "not found"])
    }

    func testChosenExecutableMustReportFFmpeg() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mp4subrip-ffmpeg-choice-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bad = root.appendingPathComponent("ffmpeg")
        try Data("#!/bin/sh\necho hello\n".utf8).write(to: bad)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bad.path)
        XCTAssertNil(FFmpegSettings.validatedExecutable(at: bad.path))
        XCTAssertEqual(
            ExternalTool.resolveCustom(bad.path, executable: "ffmpeg", executableExists: ExternalTool.isRunnable),
            bad.path
        )

        let appPath = root.appendingPathComponent("ffmpeg.app").path
        let innerPath = appPath + "/Contents/MacOS/ffmpeg"
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: innerPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\necho ffmpeg version test\n".utf8).write(to: URL(fileURLWithPath: innerPath))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: innerPath)
        XCTAssertEqual(FFmpegSettings.validatedExecutable(at: appPath), innerPath)

        let folderPath = root.appendingPathComponent("dist").path
        let goodPath = folderPath + "/bin/ffmpeg"
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: goodPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\necho FFMPEG version 1\n".utf8).write(to: URL(fileURLWithPath: goodPath))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: goodPath)
        XCTAssertEqual(FFmpegSettings.validatedExecutable(at: folderPath), goodPath)

        let report = ExternalTool.describe(.primary, customPath: innerPath)
        XCTAssertEqual(report.customPath, innerPath)
        XCTAssertEqual(report.located?.source, .chosenInSettings)
        XCTAssertEqual(report.located?.path, innerPath)
        XCTAssertEqual(report.located?.version, "ffmpeg version test")
        let line = ToolDetection.logLine(spec: .primary, located: report.located, customPath: report.customPath)
        let facts = ToolDetection.facts(spec: .primary, located: report.located, customPath: report.customPath)
        XCTAssertEqual(
            line.message,
            "ffmpeg found (chosen in Settings) \(innerPath), version ffmpeg version test"
        )
        XCTAssertEqual(facts.map(\.value), ["(chosen in Settings) \(innerPath)", "ffmpeg version test"])

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: goodPath)
        XCTAssertNil(FFmpegSettings.validatedExecutable(at: goodPath))
        XCTAssertNil(FFmpegSettings.runnableExecutable(at: goodPath))
    }

    func testFFmpegSummaryAndSkipMessages() {
        XCTAssertEqual(
            FFmpegSettings.summary(customPath: nil, resolvedPath: "/opt/homebrew/bin/ffmpeg"),
            "ffmpeg automatic /opt/homebrew/bin/ffmpeg"
        )
        XCTAssertEqual(FFmpegSettings.summary(customPath: nil, resolvedPath: nil), "ffmpeg not found")
        XCTAssertEqual(FFmpegSettings.summary(customPath: "", resolvedPath: nil), "ffmpeg not chosen")
        XCTAssertEqual(
            FFmpegSettings.summary(customPath: "/Users/me/bin/ffmpeg", resolvedPath: nil),
            "ffmpeg chosen /Users/me/bin/ffmpeg"
        )
        XCTAssertEqual(
            FFmpegSettings.installationMessage(customPath: nil),
            "Closed-caption extraction needs ffmpeg. Install it with Homebrew, or choose it in Settings."
        )
        XCTAssertEqual(FFmpegSettings.installationMessage(customPath: ""), "Choose ffmpeg in Settings.")
        XCTAssertEqual(
            FFmpegSettings.installationMessage(customPath: "/Users/me/bin/ffmpeg"),
            "The ffmpeg chosen in Settings can't be found. Choose it again in Settings."
        )
        XCTAssertEqual(
            FFmpegFailure.notInstalled("ffmpeg").errorDescription,
            SubtitleSkipReason.needsFFmpeg.message as String?
        )
    }
}
