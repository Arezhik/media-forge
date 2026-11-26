#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// Loads file URLs from a drop's item providers.
///
/// Same steps the MP4 and PGS queue views used: keep providers that are file URLs,
/// load them one at a time, and turn each payload into a URL. The view still decides
/// what to do with the URLs.
public enum FileDrop {
    /// True when the drop includes at least one file URL. `onDrop` returns this immediately.
    @MainActor
    public static func hasFileURL(_ providers: [NSItemProvider]) -> Bool {
        providers.contains { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
    }

    /// File URLs in provider order. A provider that is not a file URL, or that fails to load, is skipped.
    @MainActor
    public static func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await loadURL(from: provider) {
                urls.append(url)
            }
        }
        return urls
    }

    @MainActor
    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = url(from: item)
                once.run {
                    continuation.resume(returning: url)
                }
            }
        }
    }

    /// Pure path parsing. The drop callback is not on the main actor.
    nonisolated static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) { return url }
            if let string = String(data: data, encoding: .utf8) {
                return url(fromPathOrFileURL: string)
            }
        }
        if let string = item as? NSString {
            return url(fromPathOrFileURL: string as String)
        }
        return nil
    }

    private nonisolated static func url(fromPathOrFileURL string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("file:") { return URL(string: trimmed) }
        if trimmed.isEmpty { return nil }
        return URL(fileURLWithPath: trimmed)
    }
}

/// `loadItem` can call its handler more than once. A continuation resumes only once.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        let shouldRun = !done
        done = true
        lock.unlock()
        if shouldRun { body() }
    }
}
#endif
