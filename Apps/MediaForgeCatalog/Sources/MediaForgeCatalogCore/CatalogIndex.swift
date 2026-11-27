import Foundation

/// Product apps named on used-in chips. Hand-maintained. Not computed from source.
public enum ProductApp: String, CaseIterable, Sendable, Identifiable, Hashable {
    case mkvForge = "MKVForge"
    case mp4SubRip = "MP4SubRip"
    case pgs2srt = "PGS2SRT"

    public var id: String { rawValue }

    /// Chip accent. MKVForge orange, MP4SubRip blue, PGS2SRT violet.
    public var accentHex: String {
        switch self {
        case .mkvForge: return "FF8F26"
        case .mp4SubRip: return "2F6BFF"
        case .pgs2srt: return "8B6CFF"
        }
    }
}

/// Where a type or member is called from. A none-chip carries the dashed label.
public enum Adoption: Equatable, Sendable {
    case apps([ProductApp])
    case none(String)

    public static let allThree: Adoption = .apps([.mkvForge, .mp4SubRip, .pgs2srt])
    public static let notCalledDirectly: Adoption = .none("Not called directly")
    public static let noAppUsesThis: Adoption = .none("No app uses this")
}

public enum CatalogSection: String, Sendable, Hashable, CaseIterable {
    case mediaUI = "MediaUI"
    case mediaTesting = "MediaTesting"

    public var caption: String {
        switch self {
        case .mediaUI: return "Live demos"
        case .mediaTesting: return "Reference"
        }
    }

    public var markerName: String {
        switch self {
        case .mediaUI: return "MediaUIMarker"
        case .mediaTesting: return "MediaTestingMarker"
        }
    }
}

public enum PageID: String, CaseIterable, Sendable, Identifiable, Hashable, Codable {
    case fileDrop
    case filePanels
    case reveal
    case debugLogExport
    case base
    case pages
    case components
    case helpers
    case fixtures

    public var id: String { rawValue }
}

public struct StateTileSpec: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let call: String
    public let caption: String
    public let chips: Adoption?
}

public struct TypeRowSpec: Equatable, Sendable, Identifiable {
    public let type: String
    public let role: String
    public let buildsOn: String
    public let usedIn: Adoption

    public var id: String { type }
}

public struct ExtensionMemberSpec: Equatable, Sendable, Identifiable {
    public let name: String
    public let usedIn: Adoption

    public var id: String { name }
}

public enum DiagramColumn: String, CaseIterable, Sendable, Hashable {
    case test = "Test"
    case pages = "Pages"
    case components = "Components"
    case helpers = "Helpers"
}

public struct RelatedLink: Equatable, Sendable, Identifiable {
    public let title: String
    public let page: PageID

    public var id: String { title }
}

public struct CatalogPage: Equatable, Sendable, Identifiable {
    public let id: PageID
    public let section: CatalogSection
    public let title: String
    public let symbol: String
    public let monospaceTitle: Bool
    public let showsDocBadge: Bool
    public let purpose: String
    public let badge: String
    public let apiMembers: [String]
    public let usedIn: Adoption
    public let tiles: [StateTileSpec]
    public let types: [TypeRowSpec]
    public let extensions: [ExtensionMemberSpec]
    public let diagramHighlight: DiagramColumn?
    public let related: [RelatedLink]
    public let extraSearch: [String]

    public var sidebarIdentifier: String { "sidebar.\(id.rawValue)" }
    public var stateCount: Int { tiles.count }
    public var typeCount: Int { types.count }
    public var defaultTileID: String { tiles.first?.id ?? "" }

    public func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if needle.isEmpty { return true }
        let parts = [title] + apiMembers + types.map(\.type) + extensions.map(\.name) + extraSearch
        return parts.contains { $0.lowercased().contains(needle) }
    }
}

/// Hand-maintained catalog. Update this table when an app adopts or drops a type.
public enum CatalogIndex {
    public static let markerLine = "Module marker · no demo page"
    public static let pages: [CatalogPage] = makePages()

    public static func page(_ id: PageID) -> CatalogPage? {
        pages.first { $0.id == id }
    }

    public static func pages(in section: CatalogSection) -> [CatalogPage] {
        pages.filter { $0.section == section }
    }

    /// Empty and whitespace queries return every row. Matching is case-insensitive
    /// and covers the row label, API members, MediaTesting type names, and extension members.
    public static func pages(matching query: String) -> [CatalogPage] {
        pages.filter { $0.matches(query) }
    }
}

private func tile(
    _ id: String,
    _ title: String,
    _ call: String,
    _ caption: String,
    _ chips: Adoption? = nil
) -> StateTileSpec {
    StateTileSpec(id: id, title: title, call: call, caption: caption, chips: chips)
}

private func typeRow(
    _ type: String,
    _ role: String,
    _ buildsOn: String,
    _ usedIn: Adoption
) -> TypeRowSpec {
    TypeRowSpec(type: type, role: role, buildsOn: buildsOn, usedIn: usedIn)
}

private func makePages() -> [CatalogPage] {
    [
        CatalogPage(
            id: .fileDrop,
            section: .mediaUI,
            title: "FileDrop",
            symbol: "square.and.arrow.down",
            monospaceTitle: true,
            showsDocBadge: false,
            purpose: "Loads file URLs from a drop's item providers.",
            badge: "MediaUI",
            apiMembers: ["hasFileURL(_:)", "loadFileURLs(from:)"],
            usedIn: .apps([.mp4SubRip, .pgs2srt]),
            tiles: [
                tile("idle", "Idle", "—", "A dashed outline, the drop symbol, and “Drop media files here”."),
                tile("hover", "Hover · accepts", "hasFileURL(_:) → true", "A solid accent outline, “Release to add N files”, and a count on the drag."),
                tile("accepted", "Accepted", "loadFileURLs(from:)", "Dropped names (first 3, then “+N more”) and “Added N files”. Returns to Idle after 2 s."),
                tile("rejected", "Rejected", "hasFileURL(_:) → false", "No highlight while hovering. A rejected drop shows nosign and “Only files can be dropped here” for 2 s."),
            ],
            types: [],
            extensions: [],
            diagramHighlight: nil,
            related: [RelatedLink(title: "FilePanels", page: .filePanels)],
            extraSearch: []
        ),
        CatalogPage(
            id: .filePanels,
            section: .mediaUI,
            title: "FilePanels",
            symbol: "folder",
            monospaceTitle: true,
            showsDocBadge: false,
            purpose: "NSOpenPanel presets for a folder, files, or one tool.",
            badge: "MediaUI",
            apiMembers: ["chooseFolder", "chooseFiles", "chooseTool"],
            usedIn: Adoption.allThree,
            tiles: [
                tile("folder", "Folder · .folder(…)", "chooseFolder", "Folders selectable, files greyed out.", Adoption.allThree),
                tile("files", "Files · .files(…)", "chooseFiles", "Multi-select files.", .apps([.mp4SubRip, .pgs2srt])),
                tile("tool", "Tool · .tool(…)", "chooseTool", "One executable selected.", .apps([.mkvForge, .mp4SubRip])),
                tile("cancel", "Cancel", "any preset, Cancel → nil", "Cancelled · no URL returned."),
            ],
            types: [],
            extensions: [],
            diagramHighlight: nil,
            related: [RelatedLink(title: "FileDrop", page: .fileDrop)],
            extraSearch: ["OpenPanelOptions"]
        ),
        CatalogPage(
            id: .reveal,
            section: .mediaUI,
            title: "Reveal",
            symbol: "magnifyingglass",
            monospaceTitle: true,
            showsDocBadge: false,
            purpose: "Show in Finder. The caller picks the API.",
            badge: "MediaUI",
            apiMembers: ["selectFile(path:)", "selectFolder(path:)", "activateViewer(_:)"],
            usedIn: Adoption.allThree,
            tiles: [
                tile("selectFile", "Select file", "selectFile(path:)", "Finder with the file highlighted.", Adoption.allThree),
                tile("selectFolder", "Select folder", "selectFolder(path:)", "Finder showing the folder.", .apps([.mkvForge, .mp4SubRip])),
                tile(
                    "activateViewer",
                    "Activate viewer",
                    "activateViewer(_:)",
                    "Apps reach it only via DebugLogExport .activateViewer.",
                    .notCalledDirectly
                ),
                tile("missing", "Missing path", "Catalog-only pre-check", "nosign and a disabled Reveal button."),
            ],
            types: [],
            extensions: [],
            diagramHighlight: nil,
            related: [RelatedLink(title: "DebugLogExport", page: .debugLogExport)],
            extraSearch: []
        ),
        CatalogPage(
            id: .debugLogExport,
            section: .mediaUI,
            title: "DebugLogExport",
            symbol: "doc.text",
            monospaceTitle: true,
            showsDocBadge: false,
            purpose: "Fallback save panel and Finder reveal for the debug log.",
            badge: "MediaUI",
            apiMembers: ["SaveOptions", "RevealChoice", "chooseDestination(_:)", "reveal(_:choice:)"],
            usedIn: Adoption.allThree,
            tiles: [
                tile("save", "Save panel", "chooseDestination(_:)", "Save As and Where, defaults from SaveOptions.", Adoption.allThree),
                tile("selectFile", "Saved · .selectFile", "reveal(_:choice:)", "A Finder window opens with the log selected.", .apps([.mp4SubRip])),
                tile("activateViewer", "Saved · .activateViewer", "reveal(_:choice:)", "Finder comes forward selecting the log.", .apps([.mkvForge, .pgs2srt])),
                tile("cancel", "Cancel", "chooseDestination(_:) → nil", "Cancelled · nothing written."),
            ],
            types: [],
            extensions: [],
            diagramHighlight: nil,
            related: [RelatedLink(title: "Reveal", page: .reveal)],
            extraSearch: ["selectFile", "activateViewer"]
        ),
        CatalogPage(
            id: .base,
            section: .mediaTesting,
            title: "Base",
            symbol: "square.stack",
            monospaceTitle: false,
            showsDocBadge: true,
            purpose: "Launch and page base types for every app UI test.",
            badge: "MediaTesting · Reference",
            apiMembers: ["BaseUITest", "BasePage"],
            usedIn: Adoption.allThree,
            tiles: [],
            types: [
                typeRow(
                    "BaseUITest",
                    "Launches the app under test against a fresh UITestFixtureBuilder root.",
                    "XCTestCase",
                    Adoption.allThree
                ),
                typeRow(
                    "BasePage",
                    "Shared holder for XCUIApplication and the screen root.",
                    "—",
                    Adoption.allThree
                ),
            ],
            extensions: [],
            diagramHighlight: .test,
            related: [RelatedLink(title: "Pages", page: .pages)],
            extraSearch: []
        ),
        CatalogPage(
            id: .pages,
            section: .mediaTesting,
            title: "Pages",
            symbol: "doc.on.doc",
            monospaceTitle: false,
            showsDocBadge: true,
            purpose: "Main window and Settings page objects.",
            badge: "MediaTesting · Reference",
            apiMembers: ["MainWindowPage", "SettingsPage"],
            usedIn: Adoption.allThree,
            tiles: [],
            types: [
                typeRow(
                    "MainWindowPage",
                    "Main window chrome. App pages subclass this and add their own controls.",
                    "BasePage",
                    Adoption.allThree
                ),
                typeRow(
                    "SettingsPage",
                    "Settings window. Locators assume the window is up, except open(in:).",
                    "BasePage",
                    Adoption.allThree
                ),
            ],
            extensions: [],
            diagramHighlight: .pages,
            related: [
                RelatedLink(title: "Base", page: .base),
                RelatedLink(title: "Components", page: .components),
            ],
            extraSearch: []
        ),
        CatalogPage(
            id: .components,
            section: .mediaTesting,
            title: "Components",
            symbol: "square.grid.2x2",
            monospaceTitle: false,
            showsDocBadge: true,
            purpose: "Shared controls: intake banner, mode picker, and queue row.",
            badge: "MediaTesting · Reference",
            apiMembers: ["IntakeBannerComponent", "ModePickerComponent", "QueueRowComponent"],
            usedIn: Adoption.allThree,
            tiles: [],
            types: [
                typeRow(
                    "IntakeBannerComponent",
                    "The notice shown for an empty folder or a file the app does not queue.",
                    "—",
                    .apps([.mp4SubRip, .pgs2srt])
                ),
                typeRow(
                    "ModePickerComponent",
                    "Segmented mode control. App components add the titles and the page they return.",
                    "—",
                    .apps([.mkvForge, .mp4SubRip])
                ),
                typeRow(
                    "QueueRowComponent",
                    "One queue row, found by identifier and by a label or value fragment.",
                    "—",
                    Adoption.allThree
                ),
            ],
            extensions: [],
            diagramHighlight: .components,
            related: [
                RelatedLink(title: "Pages", page: .pages),
                RelatedLink(title: "Helpers", page: .helpers),
            ],
            extraSearch: []
        ),
        CatalogPage(
            id: .helpers,
            section: .mediaTesting,
            title: "Helpers",
            symbol: "wrench.adjustable",
            monospaceTitle: false,
            showsDocBadge: true,
            purpose: "Timeouts, queries, waits, and the XCUIElement extensions.",
            badge: "MediaTesting · Reference",
            apiMembers: ["UITestFixtures", "UITestTimeout", "UITestQuery", "UITestWait", "UITestPoll"],
            usedIn: Adoption.allThree,
            tiles: [],
            types: [
                typeRow(
                    "UITestFixtures",
                    "Creates and cleans the temp fixture root, and builds the UITEST_* environment.",
                    "—",
                    Adoption.allThree
                ),
                typeRow("UITestTimeout", "Timeouts for waitForExistence.", "—", Adoption.allThree),
                typeRow(
                    "UITestQuery",
                    "Shallow locators. Avoids descendants(matching: .any).",
                    "—",
                    Adoption.allThree
                ),
                typeRow(
                    "UITestWait",
                    "Returns the first element that exists, polling until the timeout.",
                    "—",
                    Adoption.allThree
                ),
                typeRow(
                    "UITestPoll",
                    "Polls until a condition is true or the timeout elapses.",
                    "—",
                    .apps([.mp4SubRip, .pgs2srt])
                ),
            ],
            extensions: [
                ExtensionMemberSpec(name: "matchingLabelOrValue", usedIn: Adoption.allThree),
                ExtensionMemberSpec(name: "requireExists", usedIn: Adoption.allThree),
                ExtensionMemberSpec(name: "clickWhenReady", usedIn: .apps([.mp4SubRip, .pgs2srt])),
                ExtensionMemberSpec(name: "uiText", usedIn: .apps([.mkvForge])),
                ExtensionMemberSpec(name: "uiMenuText", usedIn: .apps([.mp4SubRip])),
                ExtensionMemberSpec(name: "uiLabelAndValue", usedIn: .apps([.pgs2srt])),
                ExtensionMemberSpec(name: "switchIsOn", usedIn: .apps([.mkvForge])),
                ExtensionMemberSpec(name: "waitUntilSwitch", usedIn: .apps([.mkvForge, .pgs2srt])),
                ExtensionMemberSpec(
                    name: "app.mainWindow · mainWindow(identifier:)",
                    usedIn: .apps([.mp4SubRip, .pgs2srt])
                ),
            ],
            diagramHighlight: .helpers,
            related: [
                RelatedLink(title: "Components", page: .components),
                RelatedLink(title: "Fixtures", page: .fixtures),
            ],
            extraSearch: []
        ),
        CatalogPage(
            id: .fixtures,
            section: .mediaTesting,
            title: "Fixtures",
            symbol: "shippingbox",
            monospaceTitle: false,
            showsDocBadge: true,
            purpose: "Temporary folders and synthetic media files for XCUITest.",
            badge: "MediaTesting · Reference",
            apiMembers: ["UITestFixtureBuilder", "UITestFixtureBuilderError"],
            usedIn: Adoption.allThree,
            tiles: [],
            types: [
                typeRow(
                    "UITestFixtureBuilder",
                    "Temporary folders and tiny media files for XCUITest. Each test gets its own root.",
                    "—",
                    Adoption.allThree
                ),
                typeRow(
                    "UITestFixtureBuilderError",
                    "Error when ffmpeg is missing or a fixture command fails. Package tests only.",
                    "Error",
                    .noAppUsesThis
                ),
            ],
            extensions: [],
            diagramHighlight: nil,
            related: [
                RelatedLink(title: "Helpers", page: .helpers),
                RelatedLink(title: "Base", page: .base),
            ],
            extraSearch: []
        ),
    ]
}
