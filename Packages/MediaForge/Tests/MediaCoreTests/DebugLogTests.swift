import Foundation
import XCTest
import MediaCore

final class DebugLogTests: XCTestCase {
    private let appName = "PGS2SRT"

    func testCategoriesCoverEveryApp() {
        let raw = Set(DebugLogCategory.allCases.map(\.rawValue))
        XCTAssertEqual(
            raw,
            [
                "lifecycle", "queue", "work", "decode", "ocr",
                "tool", "mkv", "window", "error", "diagnostic",
            ]
        )
    }

    func testHomeFolderBecomesATilde() {
        let home = "/Users/ada"
        XCTAssertEqual(
            PathRedaction.redact("\(home)/Desktop/Movie.sup", homeDirectory: home),
            "~/Desktop/Movie.sup"
        )
        XCTAssertEqual(PathRedaction.redact(home, homeDirectory: home), "~")
        XCTAssertEqual(
            PathRedaction.redact("\(home)/Movies/a.sup", homeDirectory: home + "/"),
            "~/Movies/a.sup"
        )
        XCTAssertEqual(
            PathRedaction.redact("read \(home)/a wrote \(home)/b", homeDirectory: home),
            "read ~/a wrote ~/b"
        )
        XCTAssertEqual(
            PathRedaction.redact("/USERS/ada/Desktop/a.sup", homeDirectory: home),
            "~/Desktop/a.sup"
        )
        XCTAssertEqual(
            PathRedaction.redact("file:///Users/ada/Movies/a.sup", homeDirectory: home),
            "file://~/Movies/a.sup"
        )
        XCTAssertEqual(
            PathRedaction.redact("/Users/ada2/Movie.sup", homeDirectory: home),
            "/Users/ada2/Movie.sup"
        )
        XCTAssertEqual(
            PathRedaction.redact("/Users/ada/Movies/a.file and /Users/ada2/b.file", homeDirectory: home),
            "~/Movies/a.file and /Users/ada2/b.file"
        )
        XCTAssertEqual(PathRedaction.redact("/tmp/Movie.sup", homeDirectory: home), "/tmp/Movie.sup")
        XCTAssertEqual(PathRedaction.redact("\(home)/a", homeDirectory: ""), "\(home)/a")
        XCTAssertEqual(PathRedaction.redact("\(home)/a", homeDirectory: "/"), "\(home)/a")
    }

    func testASymlinkedHomeIsRedactedToo() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("media-home-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let real = root.appendingPathComponent("real", isDirectory: true)
        let link = root.appendingPathComponent("link", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        XCTAssertEqual(
            PathRedaction.redact(link.appendingPathComponent("Movie.sup").path, homeDirectory: link.path),
            "~/Movie.sup"
        )
        let shown = real.appendingPathComponent("Movie.sup").path
        let redacted = PathRedaction.redact(shown, homeDirectory: link.path)
        XCTAssertEqual(redacted, "~/Movie.sup")
        XCTAssertFalse(redacted.contains(real.path))
    }

    func testHeaderListsMachineFactsAndExtraFacts() {
        let environment = DebugEnvironment(
            appVersion: "0.1.0",
            appBuild: "1",
            operatingSystem: "Version 15.8",
            model: "MacPro7,1",
            chip: DebugChip.label(architecture: "x86_64", runningUnderRosetta: false),
            architecture: "x86_64",
            runningUnderRosetta: false,
            facts: [DebugFact("Tool", "/usr/local/bin/tool"), DebugFact("Tool version", "v1")],
            settings: "defaults"
        )
        let header = DebugLogDocument.header(appName: "MKVForge", for: environment)
        XCTAssertTrue(header.hasPrefix("MKVForge debug log"))
        XCTAssertTrue(header.contains("Chip: Intel"))
        XCTAssertTrue(header.contains("Tool version: v1"))
        XCTAssertTrue(header.hasSuffix("Settings: defaults"))
        XCTAssertEqual(DebugChip.label(architecture: "arm64", runningUnderRosetta: false), "Apple silicon")
    }

    func testHeaderRedactsToolPathsAndKeepsMissingToolLines() {
        let present = DebugEnvironment(
            appVersion: "0.1.0",
            appBuild: "1",
            operatingSystem: "Version 14.5 (Build 23F79)",
            model: "MacBookPro18,3",
            chip: DebugChip.label(architecture: "arm64", runningUnderRosetta: false),
            architecture: "arm64",
            runningUnderRosetta: false,
            facts: [
                DebugFact("MKVToolNix", "/Users/ada/bin/mkvmerge"),
                DebugFact("MKVToolNix version", "mkvmerge v86.0 ('Winter') 64-bit"),
            ],
            settings: "language en-US, save folder /Users/ada/Subs"
        )
        let document = DebugLogDocument.document(
            appName: appName,
            environment: present,
            logText: "2026-10-30 [queue] info Added Movie.sup\n",
            homeDirectory: "/Users/ada"
        )
        XCTAssertTrue(document.contains("PGS2SRT debug log"))
        XCTAssertTrue(document.contains("App version: 0.1.0"))
        XCTAssertTrue(document.contains("App build: 1"))
        XCTAssertTrue(document.contains("macOS: Version 14.5 (Build 23F79)"))
        XCTAssertTrue(document.contains("Model: MacBookPro18,3"))
        XCTAssertTrue(document.contains("Chip: Apple silicon"))
        XCTAssertTrue(document.contains("Architecture: arm64"))
        XCTAssertTrue(document.contains("Rosetta: no"))
        XCTAssertTrue(document.contains("MKVToolNix: ~/bin/mkvmerge"))
        XCTAssertTrue(document.contains("MKVToolNix version: mkvmerge v86.0 ('Winter') 64-bit"))
        XCTAssertTrue(document.contains("Settings:"))
        XCTAssertTrue(document.contains("folder ~/Subs"))
        XCTAssertTrue(document.contains("Added Movie.sup"))
        XCTAssertFalse(document.contains("/Users/ada"))
        let settingsRange = document.range(of: "Settings:")
        let logRange = document.range(of: "Added Movie.sup")
        if let settingsRange, let logRange {
            XCTAssertLessThan(settingsRange.lowerBound, logRange.lowerBound)
        }

        let missing = DebugEnvironment(
            appVersion: "0.1.0",
            appBuild: "42",
            operatingSystem: "Version 15.0 (Build 24A335)",
            model: "Mac14,6",
            chip: DebugChip.label(architecture: "x86_64", runningUnderRosetta: true),
            architecture: "x86_64",
            runningUnderRosetta: true,
            facts: [
                DebugFact("MKVToolNix", "not found"),
                DebugFact("MKVToolNix version", "not found"),
            ],
            settings: "language en-US"
        )
        let header = DebugLogDocument.header(appName: appName, for: missing)
        XCTAssertTrue(header.contains("App build: 42"))
        XCTAssertTrue(header.contains("Chip: Apple silicon"))
        XCTAssertTrue(header.contains("Architecture: x86_64"))
        XCTAssertTrue(header.contains("Rosetta: yes"))
        XCTAssertTrue(header.contains("MKVToolNix: not found"))
        XCTAssertTrue(header.contains("MKVToolNix version: not found"))
        XCTAssertEqual(DebugChip.label(architecture: "x86_64", runningUnderRosetta: false), "Intel")
    }

    func testFileNameUsesAppNameAndLocalTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(
            year: 2026,
            month: 10,
            day: 30,
            hour: 17,
            minute: 5,
            second: 9
        ))!
        XCTAssertEqual(
            DebugLogDocument.fileName(appName: "PGS2SRT", at: date, timeZone: TimeZone(secondsFromGMT: 0)!),
            "PGS2SRT-debug-log-2026-10-30-170509.txt"
        )
        XCTAssertEqual(
            DebugLogDocument.fileName(appName: "PGS2SRT", at: date, timeZone: TimeZone(secondsFromGMT: -3600)!),
            "PGS2SRT-debug-log-2026-10-30-160509.txt"
        )
        let epoch = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(
            DebugLogDocument.fileName(appName: "MP4SubRip", at: epoch, timeZone: TimeZone(identifier: "UTC")!),
            "MP4SubRip-debug-log-1970-01-01-000000.txt"
        )
        XCTAssertEqual(
            DebugLogDocument.fileName(appName: "MKVForge", at: epoch, timeZone: TimeZone(identifier: "UTC")!),
            "MKVForge-debug-log-1970-01-01-000000.txt"
        )
    }

    func testLibraryLogsDirectoryUsesTheAppName() {
        let url = DebugLog.libraryLogsDirectory(appName: "MKVForge")
        XCTAssertTrue(url.path.hasSuffix("/Library/Logs/MKVForge"))
        XCTAssertEqual(
            DebugLog.libraryLogsDirectory(appName: "PGS2SRT").lastPathComponent,
            "PGS2SRT"
        )
    }

    func testRecordWritesRedactedLinesAndRotates() throws {
        let folder = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DebugLog(homeDirectory: "/Users/ada", timeZone: TimeZone(identifier: "UTC")!)
        log.configure(appName: appName, directory: folder, maxTotalBytes: 600, fileCount: 3)
        for index in 0..<20 {
            log.record(.queue, "Added /Users/ada/Movies/file\(index).input")
        }
        let text = log.recentText()
        XCTAssertTrue(text.contains("~/Movies/file19.input"))
        XCTAssertFalse(text.contains("/Users/ada/"))
        XCTAssertFalse(text.contains("file0.input"), "the oldest lines rotate out")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertLessThanOrEqual(files.count, 3)
    }

    func testRecordRedactsTheHomeFolderBeforeWriting() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var calendar = Calendar(identifier: .gregorian)
        let zone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = zone
        let date = calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 2,
            hour: 3,
            minute: 4,
            second: 5
        ))!
        let log = DebugLog(homeDirectory: "/Users/ada", timeZone: zone)
        XCTAssertEqual(log.recentText(), "")
        log.record(.queue, "Added /Users/ada/Movies/Movie.sup (12 bytes, sup)", date: date)
        log.configure(appName: appName, directory: directory, homeDirectory: "/Users/ada", timeZone: zone)
        log.record(.queue, "Added /Users/ada/Movies/Movie.sup (12 bytes, sup)", date: date)
        let text = log.recentText()
        XCTAssertTrue(text.contains("2026-01-02 03:04:05"))
        XCTAssertTrue(text.contains("[queue]"))
        XCTAssertTrue(text.contains("~/Movies/Movie.sup"))
        XCTAssertFalse(text.contains("/Users/ada"))
    }

    func testExportLineNamesTheDesktopFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let name = "PGS2SRT-debug-log-2026-10-30-170509.txt"
        let log = DebugLog(homeDirectory: "/Users/ada", timeZone: TimeZone(secondsFromGMT: 0)!)
        log.configure(
            appName: appName,
            directory: directory,
            homeDirectory: "/Users/ada",
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        log.record(.lifecycle, "Exporting debug log to /Users/ada/Desktop/\(name)")
        let text = log.recentText()
        XCTAssertTrue(text.contains("[lifecycle] info Exporting debug log to ~/Desktop/\(name)"))
        XCTAssertFalse(text.contains("/Users/ada"))
    }

    func testAWarningIsMarkedInTheLog() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DebugLog(homeDirectory: "/Users/ada")
        log.configure(appName: appName, directory: directory, homeDirectory: "/Users/ada")
        log.record(.mkv, "Temp folder removal failed PGS2SRT-abc: permission denied", isWarning: true)
        log.record(.error, "command failed", isError: true)
        log.record(.work, "File 1 of 2 started")
        log.record(.tool, "exit 0")
        log.record(.window, "Main window ready")
        log.record(.decode, "read header")
        log.record(.ocr, "OCR finished, 1 cues, 0 failed")
        log.record(.diagnostic, "menu open")
        let text = log.recentText()
        XCTAssertTrue(text.contains("[mkv] warning Temp folder removal failed PGS2SRT-abc: permission denied"))
        XCTAssertFalse(text.contains("[mkv] error"))
        XCTAssertTrue(text.contains("[error] error command failed"))
        XCTAssertTrue(text.contains("[work] info File 1 of 2 started"))
        XCTAssertTrue(text.contains("[tool] info exit 0"))
        XCTAssertTrue(text.contains("[window] info Main window ready"))
        XCTAssertTrue(text.contains("[decode] info read header"))
        XCTAssertTrue(text.contains("[ocr] info OCR finished, 1 cues, 0 failed"))
        XCTAssertTrue(text.contains("[diagnostic] info menu open"))
    }

    func testUnconfiguredLogDoesNothing() {
        let log = DebugLog()
        log.record(.error, "ignored", isError: true)
        XCTAssertEqual(log.recentText(), "")
    }

    func testConcurrentRecordsStayIntact() throws {
        let folder = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DebugLog(homeDirectory: "/Users/ada", timeZone: TimeZone(identifier: "UTC")!)
        log.configure(appName: "MP4SubRip", directory: folder, maxTotalBytes: 5_000_000, fileCount: 3)
        DispatchQueue.concurrentPerform(iterations: 40) { index in
            log.record(.work, "marker \(index) /Users/ada/Movies/clip.mp4")
        }
        let text = log.recentText()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 40)
        for index in 0..<40 {
            XCTAssertEqual(lines.filter { $0.contains("marker \(index) ~/Movies/clip.mp4") }.count, 1)
        }
        XCTAssertFalse(text.contains("/Users/ada/"))
        for line in lines {
            XCTAssertTrue(line.contains("[work] info "))
        }
    }

    func testSharedLogAcceptsConcurrentRecords() throws {
        let folder = temporaryDirectory()
        defer {
            DebugLog.shared.reset()
            try? FileManager.default.removeItem(at: folder)
        }
        DebugLog.shared.reset()
        DebugLog.shared.configure(
            appName: "MP4SubRip",
            directory: folder,
            maxTotalBytes: 5_000_000,
            fileCount: 3,
            homeDirectory: "/Users/ada",
            timeZone: TimeZone(identifier: "UTC")!
        )
        DispatchQueue.concurrentPerform(iterations: 30) { index in
            DebugLog.shared.record(.queue, "shared \(index) /Users/ada/Movies/a.mp4")
        }
        let text = DebugLog.shared.recentText()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 30)
        for index in 0..<30 {
            XCTAssertTrue(text.contains("shared \(index) ~/Movies/a.mp4"))
        }
        XCTAssertFalse(text.contains("/Users/ada/"))
    }

    func testRollingLogStoreAppendsFromSeveralThreads() throws {
        let folder = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = RollingLogStore(directory: folder, appName: "MP4SubRip", maxTotalBytes: 5_000_000, fileCount: 3)
        DispatchQueue.concurrentPerform(iterations: 40) { index in
            store.append("row \(index) payload")
        }
        let text = store.combinedText()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        XCTAssertEqual(lines.count, 40)
        for index in 0..<40 {
            XCTAssertTrue(lines.contains("row \(index) payload"))
        }
        for line in lines {
            XCTAssertTrue(line.hasPrefix("row "))
            XCTAssertTrue(line.hasSuffix("payload"))
            XCTAssertEqual(line.components(separatedBy: "payload").count, 2)
        }
    }

    func testRollingLogDropsTheOldestLinesAndStaysUnderTheCap() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let maxTotal = 300
        let fileCount = 3
        let store = RollingLogStore(directory: directory, appName: appName, maxTotalBytes: maxTotal, fileCount: fileCount)
        XCTAssertEqual(store.activeFileName, "PGS2SRT.log")
        XCTAssertEqual(RollingLogStore.activeFileName(for: "MKVForge"), "MKVForge.log")
        let payload = "0123456789"
        for index in 0..<80 {
            store.append(String(format: "%02d-", index) + payload)
        }
        let text = store.combinedText()
        XCTAssertTrue(text.contains("79-" + payload))
        XCTAssertFalse(text.contains("00-" + payload))
        XCTAssertGreaterThan(text.utf8.count, store.maxFileBytes)
        let lines = text.split(separator: "\n").map(String.init)
        let firstIndex = Int(lines.first?.prefix(2) ?? "")
        let lastIndex = Int(lines.last?.prefix(2) ?? "")
        XCTAssertEqual(lastIndex, 79)
        XCTAssertLessThan(firstIndex ?? 99, lastIndex ?? 0)

        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let allowed: Set<String> = ["PGS2SRT.log", "PGS2SRT.log.1", "PGS2SRT.log.2"]
        XCTAssertEqual(files.count, fileCount)
        var total = 0
        for file in files {
            XCTAssertTrue(allowed.contains(file.lastPathComponent))
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            let size = try XCTUnwrap(attributes[.size] as? NSNumber).intValue
            XCTAssertLessThanOrEqual(size, store.maxFileBytes)
            total += size
        }
        XCTAssertLessThanOrEqual(total, maxTotal)
        XCTAssertTrue(files.contains(where: { $0.lastPathComponent == "PGS2SRT.log" }))
    }

    func testDurationFormatsSeconds() {
        let start = Date(timeIntervalSince1970: 10)
        let end = Date(timeIntervalSince1970: 12.5)
        XCTAssertEqual(DebugLogFormatting.duration(since: start, until: end), "2.50s")
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("media-log-\(UUID().uuidString)", isDirectory: true)
    }
}
