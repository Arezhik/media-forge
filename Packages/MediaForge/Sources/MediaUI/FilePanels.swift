#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// Values the apps already set on `NSOpenPanel`, copied across in one place.
///
/// Optional strings and content types are left untouched when nil, so a panel keeps
/// AppKit's own title, message, prompt, directory, and allowed types unless the app set them.
public struct OpenPanelOptions: Equatable, Sendable {
    public var title: String?
    public var message: String?
    public var prompt: String?
    public var canChooseFiles: Bool
    public var canChooseDirectories: Bool
    public var allowsMultipleSelection: Bool
    public var canCreateDirectories: Bool
    public var treatsFilePackagesAsDirectories: Bool
    public var resolvesAliases: Bool
    public var allowedContentTypes: [UTType]?
    public var directoryURL: URL?

    public init(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canChooseFiles: Bool = true,
        canChooseDirectories: Bool = false,
        allowsMultipleSelection: Bool = false,
        canCreateDirectories: Bool = false,
        treatsFilePackagesAsDirectories: Bool = false,
        resolvesAliases: Bool = true,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil
    ) {
        self.title = title
        self.message = message
        self.prompt = prompt
        self.canChooseFiles = canChooseFiles
        self.canChooseDirectories = canChooseDirectories
        self.allowsMultipleSelection = allowsMultipleSelection
        self.canCreateDirectories = canCreateDirectories
        self.treatsFilePackagesAsDirectories = treatsFilePackagesAsDirectories
        self.resolvesAliases = resolvesAliases
        self.allowedContentTypes = allowedContentTypes
        self.directoryURL = directoryURL
    }

    /// Directory only. Matches the folder choosers (output folder, MKV Choose…).
    public static func folder(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canCreateDirectories: Bool = false,
        directoryURL: URL? = nil
    ) -> OpenPanelOptions {
        OpenPanelOptions(
            title: title,
            message: message,
            prompt: prompt,
            canChooseFiles: false,
            canChooseDirectories: true,
            allowsMultipleSelection: false,
            canCreateDirectories: canCreateDirectories,
            directoryURL: directoryURL
        )
    }

    /// Files, folders, or both. Matches Open… on MP4 and PGS.
    public static func files(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canChooseDirectories: Bool = true,
        allowsMultipleSelection: Bool = true,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil
    ) -> OpenPanelOptions {
        OpenPanelOptions(
            title: title,
            message: message,
            prompt: prompt,
            canChooseFiles: true,
            canChooseDirectories: canChooseDirectories,
            allowsMultipleSelection: allowsMultipleSelection,
            allowedContentTypes: allowedContentTypes,
            directoryURL: directoryURL
        )
    }

    /// One executable, app, or (when asked) folder. Matches the tool choosers.
    public static func tool(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canChooseDirectories: Bool = false,
        treatsFilePackagesAsDirectories: Bool = false,
        resolvesAliases: Bool = true,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil
    ) -> OpenPanelOptions {
        OpenPanelOptions(
            title: title,
            message: message,
            prompt: prompt,
            canChooseFiles: true,
            canChooseDirectories: canChooseDirectories,
            allowsMultipleSelection: false,
            treatsFilePackagesAsDirectories: treatsFilePackagesAsDirectories,
            resolvesAliases: resolvesAliases,
            allowedContentTypes: allowedContentTypes,
            directoryURL: directoryURL
        )
    }

    public func apply(to panel: NSOpenPanel) {
        if let title { panel.title = title }
        if let message { panel.message = message }
        if let prompt { panel.prompt = prompt }
        panel.canChooseFiles = canChooseFiles
        panel.canChooseDirectories = canChooseDirectories
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canCreateDirectories = canCreateDirectories
        panel.treatsFilePackagesAsDirectories = treatsFilePackagesAsDirectories
        panel.resolvesAliases = resolvesAliases
        if let allowedContentTypes { panel.allowedContentTypes = allowedContentTypes }
        if let directoryURL { panel.directoryURL = directoryURL }
    }
}

/// `NSOpenPanel` for the three apps. Strings and flags come from the call site.
///
/// A nil window runs the panel with `runModal` and invokes `completion` before returning.
/// A window presents the same panel as a sheet, and `completion` runs when the sheet ends.
/// MKV uses the sheet; MP4 and PGS use the modal return value.
@MainActor
public enum FilePanels {
    public static func chooseFolder(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canCreateDirectories: Bool = false,
        directoryURL: URL? = nil
    ) -> URL? {
        var chosen: URL?
        chooseFolder(
            title: title,
            message: message,
            prompt: prompt,
            canCreateDirectories: canCreateDirectories,
            directoryURL: directoryURL,
            attachedTo: nil
        ) { chosen = $0 }
        return chosen
    }

    public static func chooseFolder(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canCreateDirectories: Bool = false,
        directoryURL: URL? = nil,
        attachedTo window: NSWindow?,
        completion: @escaping @MainActor (URL?) -> Void
    ) {
        let options = OpenPanelOptions.folder(
            title: title,
            message: message,
            prompt: prompt,
            canCreateDirectories: canCreateDirectories,
            directoryURL: directoryURL
        )
        run(options, attachedTo: window) { response, panel in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            completion(url)
        }
    }

    public static func chooseFiles(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canChooseDirectories: Bool = true,
        allowsMultipleSelection: Bool = true,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil
    ) -> [URL]? {
        var chosen: [URL]?
        chooseFiles(
            title: title,
            message: message,
            prompt: prompt,
            canChooseDirectories: canChooseDirectories,
            allowsMultipleSelection: allowsMultipleSelection,
            allowedContentTypes: allowedContentTypes,
            directoryURL: directoryURL,
            attachedTo: nil
        ) { chosen = $0 }
        return chosen
    }

    public static func chooseFiles(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canChooseDirectories: Bool = true,
        allowsMultipleSelection: Bool = true,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil,
        attachedTo window: NSWindow?,
        completion: @escaping @MainActor ([URL]?) -> Void
    ) {
        let options = OpenPanelOptions.files(
            title: title,
            message: message,
            prompt: prompt,
            canChooseDirectories: canChooseDirectories,
            allowsMultipleSelection: allowsMultipleSelection,
            allowedContentTypes: allowedContentTypes,
            directoryURL: directoryURL
        )
        run(options, attachedTo: window) { response, panel in
            guard response == .OK else {
                completion(nil)
                return
            }
            completion(panel.urls)
        }
    }

    public static func chooseTool(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canChooseDirectories: Bool = false,
        treatsFilePackagesAsDirectories: Bool = false,
        resolvesAliases: Bool = true,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil
    ) -> URL? {
        var chosen: URL?
        chooseTool(
            title: title,
            message: message,
            prompt: prompt,
            canChooseDirectories: canChooseDirectories,
            treatsFilePackagesAsDirectories: treatsFilePackagesAsDirectories,
            resolvesAliases: resolvesAliases,
            allowedContentTypes: allowedContentTypes,
            directoryURL: directoryURL,
            attachedTo: nil
        ) { chosen = $0 }
        return chosen
    }

    public static func chooseTool(
        title: String? = nil,
        message: String? = nil,
        prompt: String? = nil,
        canChooseDirectories: Bool = false,
        treatsFilePackagesAsDirectories: Bool = false,
        resolvesAliases: Bool = true,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil,
        attachedTo window: NSWindow?,
        completion: @escaping @MainActor (URL?) -> Void
    ) {
        let options = OpenPanelOptions.tool(
            title: title,
            message: message,
            prompt: prompt,
            canChooseDirectories: canChooseDirectories,
            treatsFilePackagesAsDirectories: treatsFilePackagesAsDirectories,
            resolvesAliases: resolvesAliases,
            allowedContentTypes: allowedContentTypes,
            directoryURL: directoryURL
        )
        run(options, attachedTo: window) { response, panel in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            completion(url)
        }
    }

    /// Holds the panel so the sheet callback can be `@Sendable` without moving AppKit state early.
    private final class PanelBox: @unchecked Sendable {
        let panel: NSOpenPanel
        init(_ panel: NSOpenPanel) { self.panel = panel }
    }

    private static func run(
        _ options: OpenPanelOptions,
        attachedTo window: NSWindow?,
        completion: @escaping @MainActor (NSApplication.ModalResponse, NSOpenPanel) -> Void
    ) {
        let panel = NSOpenPanel()
        options.apply(to: panel)
        let box = PanelBox(panel)
        let finish: @Sendable (NSApplication.ModalResponse) -> Void = { response in
            MainActor.assumeIsolated {
                completion(response, box.panel)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }
}
#endif
