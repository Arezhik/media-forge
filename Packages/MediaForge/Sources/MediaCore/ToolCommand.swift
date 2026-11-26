import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// Shared command runner. Collects stdout and stderr, then returns. A non-zero
// exit is a result, not a throw. Cancel sends SIGKILL. Live line streaming stays
// in the app that already reads it (MKV Forge's mux progress reader).

/// The environment every tool run gets: the app's own, with `LC_ALL` forced to a
/// UTF-8 locale that exists on this platform. mkvmerge converts arguments and file
/// names with the locale's character set. Under C or POSIX it silently cuts a
/// non-ASCII name and still exits 0, and an LC_* value naming a locale that isn't
/// installed makes it abort. macOS has no C.UTF-8 and minimal Linux images have no
/// en_US.UTF-8, hence one name each.
public enum ToolEnvironment {
    #if canImport(Darwin)
    public static let utf8Locale = "en_US.UTF-8"
    #else
    public static let utf8Locale = "C.UTF-8"
    #endif

    public static func forTools(inheriting inherited: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = inherited
        environment["LC_ALL"] = utf8Locale
        return environment
    }
}

public enum ToolFailure: Error, Equatable, LocalizedError {
    case notInstalled(String)
    case couldNotStart(String)
    case failed(tool: String, status: Int32)

    public var errorDescription: String? {
        switch self {
        case let .notInstalled(name):
            return "\(name) is not installed. Install it with Homebrew or from its website, then try again."
        case let .couldNotStart(name):
            return "\(name) could not be started."
        case let .failed(tool, status):
            return "\(tool) stopped with exit code \(status). Export the debug log for details."
        }
    }
}

/// One finished run. `status` is the process exit code, including non-zero.
public struct ToolCommandResult: Equatable, Sendable {
    public var status: Int32
    public var standardOutput: Data
    public var standardError: Data

    public init(status: Int32, standardOutput: Data, standardError: Data) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum ToolCommand {
    /// Runs the tool off the main thread. Cancelling the calling task kills the process.
    /// Does not throw when the tool exits non-zero. `logCategory` is the debug-log
    /// category for the command, the exit line, and stderr. `logEmptyStandardError`
    /// records "stderr was empty" when a non-zero exit produced no stderr text.
    public static func run(
        executable: String,
        arguments: [String],
        logCategory: DebugLogCategory = .tool,
        logEmptyStandardError: Bool = true
    ) async throws -> ToolCommandResult {
        let runner = CommandRunner()
        return try await withTaskCancellationHandler {
            try await runner.start(
                executable: executable,
                arguments: arguments,
                logCategory: logCategory,
                logEmptyStandardError: logEmptyStandardError
            )
        } onCancel: {
            runner.cancel()
        }
    }
}

/// How a tool invocation is written into the debug log. Standard output stays out.
public enum ToolCommandFormatting {
    public static let standardErrorLimit = 2000

    public static func line(executable: String, arguments: [String]) -> String {
        ([executable] + arguments).map { part in
            if part.contains(where: { $0 == " " || $0 == "\"" }) {
                return "\"\(part.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return part
        }.joined(separator: " ")
    }

    public static func stderrText(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let raw = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let flat = raw.split(whereSeparator: \.isNewline).joined(separator: " ")
        let trimmed = flat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= standardErrorLimit { return trimmed }
        return String(trimmed.prefix(standardErrorLimit)) + "…"
    }
}

/// Owns the running `Process` so a cancel from another task can terminate it.
private final class CommandRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        let process = self.process
        lock.unlock()
        guard let process else { return }
        stop(process)
    }

    func start(
        executable: String,
        arguments: [String],
        logCategory: DebugLogCategory,
        logEmptyStandardError: Bool
    ) async throws -> ToolCommandResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ToolCommandResult, Error>) in
            let resume = ResumeBox(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    try self.blocking(
                        executable: executable,
                        arguments: arguments,
                        logCategory: logCategory,
                        logEmptyStandardError: logEmptyStandardError
                    )
                }
                resume.resume(result)
            }
        }
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// Stores the process. Returns false when cancel already won.
    private func adopt(_ process: Process) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if cancelled { return false }
        self.process = process
        return true
    }

    /// `terminate()` is not enough on Linux when it is called off the thread that
    /// launched the tool. SIGKILL makes Cancel stop the tool immediately.
    private func stop(_ process: Process) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate()
        if pid > 0 {
            kill(pid, SIGKILL)
        }
    }

    private func forget() {
        lock.lock()
        process = nil
        lock.unlock()
    }

    private func blocking(
        executable: String,
        arguments: [String],
        logCategory: DebugLogCategory,
        logEmptyStandardError: Bool
    ) throws -> ToolCommandResult {
        let command = ToolCommandFormatting.line(executable: executable, arguments: arguments)
        if isCancelled {
            DebugLog.shared.record(logCategory, "command cancelled \(command)")
            throw CancellationError()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ToolEnvironment.forTools()
        process.standardInput = FileHandle.nullDevice
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        guard adopt(process) else {
            DebugLog.shared.record(logCategory, "command cancelled \(command)")
            throw CancellationError()
        }
        DebugLog.shared.record(logCategory, "command \(command)")
        do {
            try process.run()
        } catch {
            forget()
            DebugLog.shared.record(.error, "command \(command) could not start", isError: true)
            throw ToolFailure.couldNotStart((executable as NSString).lastPathComponent)
        }
        if isCancelled {
            stop(process)
        }
        let stdout = PipeReader(stdoutPipe.fileHandleForReading)
        let stderr = PipeReader(stderrPipe.fileHandleForReading)
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdout.readToEnd()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderr.readToEnd()
            group.leave()
        }
        process.waitUntilExit()
        group.wait()
        let status = process.terminationStatus
        forget()
        let failed = status != 0
        DebugLog.shared.record(logCategory, "exit \(status)", isError: failed)
        if let stderrText = ToolCommandFormatting.stderrText(stderr.data) {
            DebugLog.shared.record(logCategory, "stderr \(stderrText)", isError: failed)
        } else if failed && logEmptyStandardError {
            DebugLog.shared.record(logCategory, "stderr was empty", isError: true)
        }
        if isCancelled {
            DebugLog.shared.record(logCategory, "command cancelled \(command)")
            throw CancellationError()
        }
        return ToolCommandResult(status: status, standardOutput: stdout.data, standardError: stderr.data)
    }
}

/// Reads a pipe on a background thread. `Pipe` and `FileHandle` are not sendable, so they stay in here.
private final class PipeReader: @unchecked Sendable {
    private let handle: FileHandle
    private(set) var data = Data()

    init(_ handle: FileHandle) {
        self.handle = handle
    }

    func readToEnd() {
        data = (try? handle.readToEnd()) ?? Data()
    }
}

/// Resumes a continuation once. The process thread and a failure path must not both resume it.
private final class ResumeBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<T, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
