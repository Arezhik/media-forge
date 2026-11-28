import AppKit
import MediaForgeCatalogCore
import MediaUI
import SwiftUI

enum TilePreview: String, CaseIterable, Identifiable, Hashable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .auto: return "1"
        case .light: return "2"
        case .dark: return "3"
        }
    }
}

enum CatalogCommit {
    static var short: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MFCatalogCommit") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    static var aboutCredits: String {
        "MediaForge main · \(short)\nInternal developer catalog · not shipped"
    }

    static func showAbout() {
        let credits = NSAttributedString(
            string: aboutCredits,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
        ])
    }
}

enum SampleFiles {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("MediaForgeCatalog", isDirectory: true)
            .appendingPathComponent("Samples", isDirectory: true)
    }

    static var file: URL { directory.appendingPathComponent("clip.txt") }
    static var folder: URL { directory.appendingPathComponent("SampleFolder", isDirectory: true) }

    static var fileExists: Bool {
        FileManager.default.fileExists(atPath: file.path)
    }

    static var folderExists: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static var abbreviatedDirectory: String { abbreviate(directory) }

    static func abbreviate(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    static func ensure() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: file.path) {
            try Data("MediaForgeCatalog sample file\n".utf8).write(to: file)
        }
        let note = folder.appendingPathComponent("readme.txt")
        if !fileManager.fileExists(atPath: note.path) {
            try Data("Sample folder for Reveal.selectFolder.\n".utf8).write(to: note)
        }
    }

    static func recreate() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try ensure()
    }

    @MainActor
    static func showInFinder() {
        try? ensure()
        Reveal.selectFolder(path: directory.path)
    }
}

struct FocusCatalogSearchKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var focusCatalogSearch: (() -> Void)? {
        get { self[FocusCatalogSearchKey.self] }
        set { self[FocusCatalogSearchKey.self] = newValue }
    }
}

@main
struct MediaForgeCatalogApp: App {
    @State private var preview: TilePreview = .auto
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            CatalogRoot(preview: $preview)
                .defaultAppStorage(UITestingLaunch.defaults)
                .frame(minWidth: 900, minHeight: 600)
                .background(WindowMinSize(width: 900, height: 600))
        }
        .defaultSize(width: 1080, height: 700)
        .commands {
            CatalogCommands(preview: $preview)
        }

        Settings {
            GeneralSettingsView()
                .defaultAppStorage(UITestingLaunch.defaults)
                .frame(width: 520, height: 270)
                .background(SettingsWindowFix())
        }
        .defaultSize(width: 520, height: 270)
        .windowResizability(.contentSize)
    }
}

struct CatalogCommands: Commands {
    @Binding var preview: TilePreview
    @FocusedValue(\.focusCatalogSearch) private var focusSearch

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About MediaForgeCatalog") {
                CatalogCommit.showAbout()
            }
        }

        CommandGroup(after: .pasteboard) {
            Button("Find…") {
                focusSearch?()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(focusSearch == nil)
        }

        CommandGroup(after: .sidebar) {
            Menu("Preview") {
                ForEach(TilePreview.allCases) { mode in
                    Toggle(mode.title, isOn: Binding(
                        get: { preview == mode },
                        set: { isOn in
                            if isOn { preview = mode }
                        }
                    ))
                    .keyboardShortcut(mode.shortcut, modifiers: [.command, .option])
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var testingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? SampleFiles.ensure()
        guard UITestingLaunch.isActive else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.presentTestingWindowIfNeeded()
        }
    }

    /// XCTest leaves this process with no SwiftUI window (`NSApp.windows` stays
    /// empty), so the smoke tests never see Overview. `-ApplePersistenceIgnoreState`
    /// is not used: together with `--uitesting` it suppresses the window too.
    @MainActor
    private func presentTestingWindowIfNeeded() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MediaForgeCatalog"
        window.contentViewController = NSHostingController(rootView: TestingCatalogWindow())
        window.minSize = NSSize(width: 900, height: 600)
        window.setContentSize(NSSize(width: 1080, height: 700))
        window.center()
        window.makeKeyAndOrderFront(nil)
        testingWindow = window
    }
}

private struct TestingCatalogWindow: View {
    @State private var preview: TilePreview = .auto

    var body: some View {
        CatalogRoot(preview: $preview)
            .defaultAppStorage(UITestingLaunch.defaults)
            .frame(minWidth: 900, minHeight: 600)
    }
}

struct WindowMinSize: NSViewRepresentable {
    var width: CGFloat
    var height: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView) }
    }

    private func apply(to view: NSView) {
        view.window?.minSize = NSSize(width: width, height: height)
    }
}

struct SettingsWindowFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView) }
    }

    private func apply(to view: NSView) {
        guard let window = view.window else { return }
        window.title = "General"
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}

struct GeneralSettingsView: View {
    @AppStorage("clearResultsWhenSwitching") private var clearOnSwitch = false
    @State private var confirmRecreate = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Sample files") {
                LabeledContent("Location") {
                    Text(SampleFiles.abbreviatedDirectory)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityIdentifier("settings.sampleLocation")
                }
                HStack {
                    Button("Show in Finder") {
                        SampleFiles.showInFinder()
                    }
                    Spacer()
                    Button("Recreate…") {
                        confirmRecreate = true
                    }
                    .accessibilityIdentifier("settings.recreate")
                }
                Text("Restores the files the Reveal and FileDrop demos use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Results") {
                Toggle("Clear results when switching pages", isOn: $clearOnSwitch)
                    .accessibilityIdentifier("settings.clearResults")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Recreate sample files?",
            isPresented: $confirmRecreate,
            titleVisibility: .visible
        ) {
            Button("Recreate", role: .destructive) {
                do {
                    try SampleFiles.recreate()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restores the files the Reveal and FileDrop demos use.")
        }
        .alert(
            "Could not recreate samples",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
