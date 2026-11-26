import XCTest
@testable import MediaCore

final class ExternalToolTests: XCTestCase {
    private let spec = ExternalToolSpec(
        name: "Demo",
        executables: ["demo", "demo-extract"],
        appBundlePrefix: "Demo"
    )

    func testHomebrewBeatsAppBundleAndPath() {
        let existing: Set<String> = [
            "/opt/homebrew/bin/demo", "/opt/homebrew/bin/demo-extract",
            "/Applications/Demo.app/Contents/MacOS/demo", "/usr/bin/demo"
        ]
        let paths = ExternalTool.locate(
            spec,
            executableExists: { existing.contains($0) },
            applications: ["Demo.app"],
            searchPath: "/usr/bin"
        )
        XCTAssertEqual(paths?["demo"], "/opt/homebrew/bin/demo")
        XCTAssertEqual(paths?["demo-extract"], "/opt/homebrew/bin/demo-extract")
    }

    func testIntelHomebrewThenAppBundleThenPath() {
        let existing: Set<String> = ["/usr/local/bin/demo", "/Applications/Demo 2.app/Contents/MacOS/demo-extract"]
        let paths = ExternalTool.locate(
            spec,
            executableExists: { existing.contains($0) },
            applications: ["Demo 2.app", "Other.app"],
            searchPath: ""
        )
        XCTAssertEqual(paths?["demo"], "/usr/local/bin/demo")
        XCTAssertEqual(paths?["demo-extract"], "/Applications/Demo 2.app/Contents/MacOS/demo-extract")
    }

    func testPartialInstallCountsAsMissing() {
        let existing: Set<String> = ["/usr/bin/demo"]
        XCTAssertNil(ExternalTool.locate(
            spec,
            executableExists: { existing.contains($0) },
            applications: [],
            searchPath: "/usr/bin"
        ))
    }

    func testSearchDescriptionListsTheFixedOrder() {
        XCTAssertEqual(
            ExternalTool.searchLocations(spec),
            ["/opt/homebrew/bin", "/usr/local/bin", "/Applications/Demo*.app/Contents/MacOS", "PATH"]
        )
        XCTAssertEqual(
            ExternalTool.searchDescription(spec),
            "Looked in /opt/homebrew/bin, /usr/local/bin, /Applications/Demo*.app/Contents/MacOS and PATH."
        )
        let noBundle = ExternalToolSpec(name: "Demo", executables: ["demo"], appBundlePrefix: "")
        XCTAssertEqual(
            ExternalTool.searchDescription(noBundle),
            "Looked in /opt/homebrew/bin, /usr/local/bin and PATH."
        )
    }

    func testChosenExecutableFindsItsSiblings() {
        let existing: Set<String> = [
            "/opt/tools/demo", "/opt/tools/demo-extract",
            "/opt/homebrew/bin/demo", "/opt/homebrew/bin/demo-extract"
        ]
        let paths = ExternalTool.locate(spec, chosen: "/opt/tools/demo", executableExists: { existing.contains($0) })
        XCTAssertEqual(paths?["demo"], "/opt/tools/demo")
        XCTAssertEqual(paths?["demo-extract"], "/opt/tools/demo-extract")
    }

    func testChosenAppBundle() {
        let existing: Set<String> = [
            "/Volumes/X/Demo-103.app/Contents/MacOS/demo",
            "/Volumes/X/Demo-103.app/Contents/MacOS/demo-extract"
        ]
        let paths = ExternalTool.locate(
            spec,
            chosen: "/Volumes/X/Demo-103.app/",
            executableExists: { existing.contains($0) }
        )
        XCTAssertEqual(paths?["demo"], "/Volumes/X/Demo-103.app/Contents/MacOS/demo")
    }

    func testChosenFolder() {
        let existing: Set<String> = ["/opt/local/bin/demo", "/opt/local/bin/demo-extract"]
        XCTAssertEqual(
            ExternalTool.locate(spec, chosen: "/opt/local/bin", executableExists: { existing.contains($0) })?["demo"],
            "/opt/local/bin/demo"
        )
    }

    func testMissingChosenCopyIsNotFoundWithoutFallback() {
        let existing: Set<String> = ["/opt/homebrew/bin/demo", "/opt/homebrew/bin/demo-extract"]
        XCTAssertNil(ExternalTool.locate(
            spec,
            chosen: "/Volumes/Gone/Demo.app",
            executableExists: { existing.contains($0) }
        ))
    }

    func testNoChoiceUsesTheDefaultSearch() {
        XCTAssertEqual(ExternalTool.locate(spec, chosen: nil), ExternalTool.locate(spec))
        XCTAssertEqual(ExternalTool.locate(spec, chosen: ""), ExternalTool.locate(spec))
    }

    func testHomebrewHitDoesNotListApplications() {
        let one = ExternalToolSpec(name: "Demo", executables: ["demo"], appBundlePrefix: "Demo")
        var listed = false
        let paths = ExternalTool.locateInstalled(
            one,
            executableExists: { $0 == "/opt/homebrew/bin/demo" },
            applicationNames: {
                listed = true
                return ["Demo.app"]
            },
            searchPath: "/usr/bin"
        )
        XCTAssertEqual(paths?["demo"], "/opt/homebrew/bin/demo")
        XCTAssertFalse(listed)
    }

    func testAppBundleStillBeatsPathWhenHomebrewIsMissing() {
        let one = ExternalToolSpec(name: "Demo", executables: ["demo"], appBundlePrefix: "Demo")
        let bundle = "/Applications/Demo.app/Contents/MacOS/demo"
        let paths = ExternalTool.locateInstalled(
            one,
            executableExists: { $0 == bundle || $0 == "/usr/bin/demo" },
            applicationNames: { ["Demo.app"] },
            searchPath: "/usr/bin"
        )
        XCTAssertEqual(paths?["demo"], bundle)
    }

    func testRunnableFollowsARelativeSymlinkAndRejectsADirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mediacore-tool-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("demo")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let link = bin.appendingPathComponent("demo")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../demo")
        XCTAssertTrue(ExternalTool.isRunnable(link.path))
        XCTAssertTrue(ExternalTool.isRunnable(target.path))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: target.path)
        XCTAssertFalse(ExternalTool.isRunnable(target.path))
        XCTAssertFalse(ExternalTool.isRunnable(link.path))
        XCTAssertFalse(ExternalTool.isRunnable(bin.path))
    }

    func testCustomPathWinsOverHomebrewAndPath() {
        let one = ExternalToolSpec(name: "Demo", executables: ["demo"], appBundlePrefix: "Demo")
        let custom = "/Users/me/bin/demo"
        let existing: Set<String> = [
            custom,
            "/opt/homebrew/bin/demo",
            "/usr/local/bin/demo",
            "/usr/bin/demo",
            "/Applications/Demo.app/Contents/MacOS/demo"
        ]
        let paths = ExternalTool.locate(
            one,
            customPath: custom,
            executableExists: { existing.contains($0) },
            applications: ["Demo.app"],
            searchPath: "/usr/bin:/opt/homebrew/bin"
        )
        XCTAssertEqual(paths?["demo"], custom)
    }

    func testMissingOrEmptyCustomPathDoesNotUseAutomatic() {
        let one = ExternalToolSpec(name: "Demo", executables: ["demo"], appBundlePrefix: "Demo")
        var listed = false
        let paths = ExternalTool.locateInstalled(
            one,
            customPath: "/Users/me/bin/demo",
            executableExists: { $0 == "/opt/homebrew/bin/demo" || $0 == "/usr/bin/demo" },
            applicationNames: {
                listed = true
                return ["Demo.app"]
            },
            searchPath: "/usr/bin"
        )
        XCTAssertNil(paths)
        XCTAssertFalse(listed)

        let empty = ExternalTool.locateInstalled(
            one,
            customPath: "",
            executableExists: { $0 == "/opt/homebrew/bin/demo" },
            applicationNames: {
                listed = true
                return ["Demo.app"]
            },
            searchPath: "/usr/bin"
        )
        XCTAssertNil(empty)
        XCTAssertFalse(listed)
    }

    func testCustomPathResolvesAppFolderAndFile() {
        func resolve(_ path: String, existing: Set<String>) -> String? {
            ExternalTool.resolveCustom(path, executable: "demo", executableExists: { existing.contains($0) })
        }
        XCTAssertEqual(
            resolve("/Apps/Demo.app", existing: ["/Apps/Demo.app/Contents/MacOS/demo"]),
            "/Apps/Demo.app/Contents/MacOS/demo"
        )
        XCTAssertEqual(
            resolve("/Apps/Demo.app/", existing: ["/Apps/Demo.app/Contents/MacOS/demo"]),
            "/Apps/Demo.app/Contents/MacOS/demo"
        )
        XCTAssertNil(resolve("/Apps/Demo.app", existing: ["/Apps/Demo.app/bin/demo"]))
        XCTAssertEqual(resolve("/Tools", existing: ["/Tools/bin/demo"]), "/Tools/bin/demo")
        XCTAssertEqual(
            resolve("/Tools", existing: ["/Tools/demo", "/Tools/bin/demo"]),
            "/Tools/demo"
        )
        XCTAssertEqual(
            resolve("/Wrapped", existing: ["/Wrapped/Contents/MacOS/demo"]),
            "/Wrapped/Contents/MacOS/demo"
        )
        XCTAssertEqual(
            resolve("/Users/me/bin/demo", existing: ["/Users/me/bin/demo", "/opt/homebrew/bin/demo"]),
            "/Users/me/bin/demo"
        )
        XCTAssertNil(resolve("/empty", existing: ["/opt/homebrew/bin/demo"]))
    }
}
