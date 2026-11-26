import XCTest
@testable import MediaCore

final class ToolCommandTests: XCTestCase {
    func testStderrIsFlattenedAndCut() {
        let long = String(repeating: "x", count: 2500)
        XCTAssertEqual(ToolCommandFormatting.stderrText(Data("a\nb\n".utf8)), "a b")
        XCTAssertEqual(ToolCommandFormatting.stderrText(Data(long.utf8))?.count, 2001)
        XCTAssertNil(ToolCommandFormatting.stderrText(Data()))
    }

    func testToolsAlwaysGetAUTF8Locale() {
        let environment = ToolEnvironment.forTools(inheriting: ["PATH": "/usr/bin", "LC_ALL": "C", "LANG": "de_DE.UTF-8"])
        XCTAssertEqual(environment["LC_ALL"], ToolEnvironment.utf8Locale)
        XCTAssertEqual(environment["PATH"], "/usr/bin")
        XCTAssertEqual(environment["LANG"], "de_DE.UTF-8")
        XCTAssertEqual(ToolEnvironment.forTools(inheriting: [:])["LC_ALL"], ToolEnvironment.utf8Locale)
        XCTAssertTrue(ToolEnvironment.utf8Locale.hasSuffix(".UTF-8"))
    }

    func testFailureDescriptionsNameTheTool() {
        XCTAssertEqual(
            ToolFailure.notInstalled("demo").errorDescription,
            "demo is not installed. Install it with Homebrew or from its website, then try again."
        )
        XCTAssertEqual(ToolFailure.couldNotStart("demo").errorDescription, "demo could not be started.")
        XCTAssertEqual(
            ToolFailure.failed(tool: "demo", status: 2).errorDescription,
            "demo stopped with exit code 2. Export the debug log for details."
        )
    }

    #if !os(Windows)
    func testRunReportsExitCodeAndCancels() async throws {
        let result = try await ToolCommand.run(executable: "/bin/sh", arguments: ["-c", "echo out; echo err >&2; exit 3"])
        XCTAssertEqual(result.status, 3)
        XCTAssertEqual(String(decoding: result.standardOutput, as: UTF8.self), "out\n")
        XCTAssertTrue(String(decoding: result.standardError, as: UTF8.self).contains("err"))

        let locale = try await ToolCommand.run(executable: "/bin/sh", arguments: ["-c", "printf '%s' \"$LC_ALL\""])
        XCTAssertEqual(locale.status, 0)
        XCTAssertEqual(String(decoding: locale.standardOutput, as: UTF8.self), ToolEnvironment.utf8Locale)

        let echo = executable(["/bin/echo", "/usr/bin/echo"])
        XCTAssertEqual(ExternalTool.version(of: echo, arguments: ["hello-version"]), "hello-version")

        let task = Task { try await ToolCommand.run(executable: "/bin/sleep", arguments: ["30"]) }
        try await Task.sleep(nanoseconds: 200_000_000)
        let started = Date()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("cancel should throw")
        } catch is CancellationError {
            XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        }
    }

    func testAMissingToolDoesNotHang() async {
        do {
            _ = try await ToolCommand.run(executable: "/no/such/demo-tool", arguments: ["--version"])
            XCTFail("expected the launch to fail")
        } catch let error as ToolFailure {
            guard case .couldNotStart(let name) = error else {
                return XCTFail("unexpected \(error)")
            }
            XCTAssertEqual(name, "demo-tool")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    private func executable(_ candidates: [String]) -> String {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
    }
    #endif
}
