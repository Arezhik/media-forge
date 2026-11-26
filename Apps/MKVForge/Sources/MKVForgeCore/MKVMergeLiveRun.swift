import Foundation
import MediaCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// Live `#GUI#progress` reader for mux. `ToolCommand` collects stdout at exit, which
// is what identify wants. A mux has to see each progress line while mkvmerge is
// still running. `FileHandle.read(upToCount:)` can wait for a full buffer on Darwin,
// so this polls and reads only the bytes already in the pipe. The runner stays here
// until a shared streaming reader is scheduled.

enum MKVMergeLiveRun {
    /// Runs mkvmerge off the main thread. Cancelling the calling task kills the process.
    /// `onStdoutLine` is each complete stdout line, split on `\n` and `\r`, as the bytes
    /// arrive. The returned buffer is still the full stdout.
    static func run(
        executable: String,
        arguments: [String],
        onStdoutLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> ToolCommandResult {
        let runner = LiveCommandRunner()
        return try await withTaskCancellationHandler {
            try await runner.start(executable: executable, arguments: arguments, onStdoutLine: onStdoutLine)
        } onCancel: {
            runner.cancel()
        }
    }
}

/// Owns the running `Process` so a cancel from another task can terminate it.
private final class LiveCommandRunner: @unchecked Sendable {
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
        onStdoutLine: (@Sendable (String) -> Void)?
    ) async throws -> ToolCommandResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ToolCommandResult, Error>) in
            let resume = LiveResumeBox(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try self.blocking(executable: executable, arguments: arguments, onStdoutLine: onStdoutLine) }
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
        onStdoutLine: (@Sendable (String) -> Void)?
    ) throws -> ToolCommandResult {
        let command = ToolCommandFormatting.line(executable: executable, arguments: arguments)
        if isCancelled {
            DebugLog.shared.record(.tool, "command cancelled \(command)")
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
            DebugLog.shared.record(.tool, "command cancelled \(command)")
            throw CancellationError()
        }
        DebugLog.shared.record(.tool, "command \(command)")
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
        let stdout = LivePipeReader(stdoutPipe.fileHandleForReading)
        let stderr = LivePipeReader(stderrPipe.fileHandleForReading)
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdout.readToEnd(onLine: onStdoutLine)
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
        DebugLog.shared.record(.tool, "exit \(status)", isError: failed)
        if let stderrText = ToolCommandFormatting.stderrText(stderr.data) {
            DebugLog.shared.record(.tool, "stderr \(stderrText)", isError: failed)
        } else if failed {
            DebugLog.shared.record(.tool, "stderr was empty", isError: true)
        }
        if isCancelled {
            DebugLog.shared.record(.tool, "command cancelled \(command)")
            throw CancellationError()
        }
        return ToolCommandResult(status: status, standardOutput: stdout.data, standardError: stderr.data)
    }
}

/// Splits stdout chunks on `\n` and `\r` (`\r\n` is one break). A trailing `\r` is held
/// until the next byte, so a split `\r\n` does not become an empty line.
struct StdoutLineSplitter {
    private var pending = Data()

    mutating func append(_ chunk: Data) -> [String] {
        guard !chunk.isEmpty else { return [] }
        pending.append(chunk)
        return pull(flush: false)
    }

    mutating func finish() -> [String] {
        pull(flush: true)
    }

    private mutating func pull(flush: Bool) -> [String] {
        var lines: [String] = []
        var cursor = pending.startIndex
        var lineStart = pending.startIndex
        while cursor < pending.endIndex {
            let byte = pending[cursor]
            let isCR = byte == 13
            let isLF = byte == 10
            if !isCR && !isLF {
                cursor = pending.index(after: cursor)
                continue
            }
            if lineStart < cursor {
                lines.append(Self.decode(pending.subdata(in: lineStart..<cursor)))
            }
            let after = pending.index(after: cursor)
            if isCR, after == pending.endIndex, !flush {
                pending.removeSubrange(..<cursor)
                return lines
            }
            if isCR, after < pending.endIndex, pending[after] == 10 {
                cursor = pending.index(after: after)
            } else {
                cursor = after
            }
            lineStart = cursor
        }
        pending.removeSubrange(..<lineStart)
        if flush, !pending.isEmpty {
            lines.append(Self.decode(pending))
            pending.removeAll()
        }
        return lines
    }

    private static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

/// What one read of a pipe returned. `.end` is a real EOF (zero bytes).
/// `.failed` is not EOF: the next `.bytes` must still be delivered.
enum PipePull: Equatable {
    case bytes(Data)
    case end
    /// `EINTR` or `EAGAIN`. Not EOF, and not a failed read.
    case interrupted
    case failed(Int32)
}

/// Assembles pipe chunks into the full buffer and into lines.
/// A `.failed` pull does not end the stream. The reader stops on `.end`, or after
/// `failureLimit` failures in a row so a dead descriptor cannot hang the batch.
struct PipeAssembler {
    static let failureLimit = 8

    private var splitter = StdoutLineSplitter()
    private var consecutiveFailures = 0
    private(set) var data = Data()

    /// True when the reader should keep going. False on EOF or the failure limit.
    mutating func take(_ pull: PipePull, onLine: ((String) -> Void)?) -> Bool {
        switch pull {
        case .interrupted:
            return true
        case .end:
            finish(onLine)
            return false
        case let .failed(code):
            consecutiveFailures += 1
            DebugLog.shared.record(.error, "Reading the tool pipe failed (errno \(code))", isError: true)
            if consecutiveFailures >= Self.failureLimit {
                finish(onLine)
                return false
            }
            return true
        case let .bytes(chunk):
            consecutiveFailures = 0
            guard !chunk.isEmpty else { return true }
            data.append(chunk)
            guard let onLine else { return true }
            for line in splitter.append(chunk) {
                onLine(line)
            }
            return true
        }
    }

    private mutating func finish(_ onLine: ((String) -> Void)?) {
        guard let onLine else { return }
        for line in splitter.finish() {
            onLine(line)
        }
    }
}

/// One `read` of whatever is already in the pipe. `FileHandle.read(upToCount:)` is not
/// used: on Darwin it can block until `count` bytes or EOF, so a short `#GUI#progress`
/// stream would arrive only when mkvmerge exits. `poll` plus one `read` returns the
/// bytes already available, which is the same rule as `readabilityHandler` /
/// `availableData`. A zero-length read is EOF. A negative read is not.
private enum PipeFile {
    static func preferShortReads(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0 else { return }
        _ = fcntl(fd, F_SETFL, flags | Int32(O_NONBLOCK))
    }

    static func pull(_ fd: Int32) -> PipePull {
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = poll(&pfd, nfds_t(1), -1)
        if ready < 0 {
            if errno == EINTR { return .interrupted }
            return .failed(errno)
        }
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let count = buffer.withUnsafeMutableBytes { raw -> Int in
            guard let base = raw.baseAddress else { return -1 }
            #if canImport(Darwin)
            return Darwin.read(fd, base, raw.count)
            #elseif canImport(Glibc)
            return Int(Glibc.read(fd, base, raw.count))
            #elseif canImport(Musl)
            return Int(Musl.read(fd, base, raw.count))
            #else
            return -1
            #endif
        }
        if count > 0 { return .bytes(Data(buffer.prefix(count))) }
        if count == 0 { return .end }
        let code = errno
        if code == EINTR || code == EAGAIN || code == EWOULDBLOCK { return .interrupted }
        return .failed(code)
    }
}

/// Reads a pipe on a background thread. `Pipe` and `FileHandle` are not sendable, so they stay in here.
private final class LivePipeReader: @unchecked Sendable {
    private let handle: FileHandle
    private(set) var data = Data()

    init(_ handle: FileHandle) {
        self.handle = handle
    }

    /// Reads until a real EOF. The stored bytes are the whole stream. `onLine` sees each
    /// complete line as the chunks arrive; stderr is a different reader. A failed read
    /// does not end the stream.
    func readToEnd(onLine: (@Sendable (String) -> Void)? = nil) {
        let fd = handle.fileDescriptor
        PipeFile.preferShortReads(fd)
        var assembler = PipeAssembler()
        while assembler.take(PipeFile.pull(fd), onLine: onLine) {}
        data = assembler.data
    }
}

/// Resumes a continuation once. The process thread and a failure path must not both resume it.
private final class LiveResumeBox<T: Sendable>: @unchecked Sendable {
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
