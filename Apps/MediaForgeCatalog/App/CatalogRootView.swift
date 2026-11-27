import AppKit
import MediaForgeCatalogCore
import SwiftUI

struct CatalogRoot: View {
    @Binding var preview: TilePreview

    var body: some View {
        if UITestingLaunch.isActive {
            TestingCatalogSplit(preview: $preview)
        } else {
            StoredCatalogSplit(preview: $preview)
        }
    }
}

private struct StoredCatalogSplit: View {
    @Binding var preview: TilePreview
    @SceneStorage("catalog.selectedPage") private var storedPage = ""

    var body: some View {
        CatalogSplit(storedPage: $storedPage, preview: $preview)
    }
}

private struct TestingCatalogSplit: View {
    @Binding var preview: TilePreview
    @State private var storedPage = ""

    var body: some View {
        CatalogSplit(storedPage: $storedPage, preview: $preview)
    }
}

struct CatalogSplit: View {
    @Binding var storedPage: String
    @Binding var preview: TilePreview
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var results: [PageID: [ResultLine]] = [:]
    @State private var liveTile: [PageID: String] = [:]
    @AppStorage("clearResultsWhenSwitching") private var clearOnSwitch = false
    @Environment(\.colorScheme) private var colorScheme

    private var selected: CatalogPage? {
        guard let id = PageID(rawValue: storedPage) else { return nil }
        return CatalogIndex.page(id)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [CatalogPage] {
        CatalogIndex.pages(matching: query)
    }

    private var subtitle: String {
        selected?.title ?? "MediaForge Library"
    }

    private var tileScheme: ColorScheme {
        switch preview {
        case .auto: return colorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .accessibilityIdentifier("detail")
        }
        .navigationTitle("MediaForgeCatalog")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Preview", selection: $preview) {
                    ForEach(TilePreview.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .accessibilityIdentifier("previewControl")
                .accessibilityLabel("Preview")
            }
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search components")
        .searchFocused($searchFocused)
        .focusedValue(\.focusCatalogSearch) { searchFocused = true }
        .accessibilityIdentifier("componentSearch")
        .onChange(of: storedPage) { old, new in
            guard clearOnSwitch, old != new, let previous = PageID(rawValue: old) else { return }
            results[previous] = []
        }
    }

    private var sidebar: some View {
        Group {
            if !trimmedQuery.isEmpty && filtered.isEmpty {
                ContentUnavailableView.search(text: trimmedQuery)
                    .accessibilityIdentifier("searchNoResults")
            } else {
                List(selection: listSelection) {
                    ForEach(CatalogSection.allCases, id: \.self) { section in
                        let rows = filtered.filter { $0.section == section }
                        if !rows.isEmpty {
                            Section {
                                ForEach(rows) { page in
                                    sidebarRow(page)
                                        .tag(page.id)
                                }
                            } header: {
                                HStack {
                                    Text(section.rawValue)
                                    Spacer()
                                    Text(section.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .textCase(nil)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .accessibilityIdentifier("sidebar")
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 252, max: 300)
    }

    private func sidebarRow(_ page: CatalogPage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: page.symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            Text(page.title)
                .font(page.monospaceTitle ? .system(.body, design: .monospaced) : .body)
                .lineLimit(1)
            Spacer(minLength: 4)
            if page.showsDocBadge {
                Text("Doc")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.18)))
                    .accessibilityLabel("Reference")
            }
        }
        .accessibilityIdentifier(page.sidebarIdentifier)
    }

    private var listSelection: Binding<PageID?> {
        Binding(
            get: {
                guard let id = PageID(rawValue: storedPage), filtered.contains(where: { $0.id == id }) else {
                    return nil
                }
                return id
            },
            set: { newValue in
                if let newValue {
                    storedPage = newValue.rawValue
                }
            }
        )
    }

    @ViewBuilder
    private var detail: some View {
        if let page = selected {
            switch page.id {
            case .fileDrop:
                FileDropPage(liveTile: liveBinding(page), results: resultBinding(page), tileScheme: tileScheme)
            case .filePanels:
                FilePanelsPage(liveTile: liveBinding(page), results: resultBinding(page), tileScheme: tileScheme)
            case .reveal:
                RevealPage(liveTile: liveBinding(page), results: resultBinding(page), tileScheme: tileScheme)
            case .debugLogExport:
                DebugLogExportPage(liveTile: liveBinding(page), results: resultBinding(page), tileScheme: tileScheme)
            case .base, .pages, .components, .helpers, .fixtures:
                ReferencePageView(page: page) { storedPage = $0.rawValue }
            }
        } else {
            OverviewView { storedPage = $0.rawValue }
        }
    }

    private func resultBinding(_ page: CatalogPage) -> Binding<[ResultLine]> {
        Binding(
            get: { results[page.id] ?? [] },
            set: { results[page.id] = $0 }
        )
    }

    private func liveBinding(_ page: CatalogPage) -> Binding<String> {
        Binding(
            get: { liveTile[page.id] ?? page.defaultTileID },
            set: { liveTile[page.id] = $0 }
        )
    }
}

struct OverviewView: View {
    var onSelect: (PageID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 84, height: 84)
                            .accessibilityIdentifier("overviewIcon")
                        Text("MediaForge Library")
                            .font(.largeTitle)
                            .accessibilityIdentifier("overviewTitle")
                        Text("Live demos of MediaUI and reference pages for MediaTesting.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                HStack(alignment: .top, spacing: 16) {
                    moduleCard(.mediaUI)
                    moduleCard(.mediaTesting)
                }
                Text("Select a component in the sidebar.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Text("Built against MediaForge main · \(CatalogCommit.short)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("overviewFooter")
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("overview")
    }

    private func moduleCard(_ section: CatalogSection) -> some View {
        let pages = CatalogIndex.pages(in: section)
        return VStack(alignment: .leading, spacing: 8) {
            Text(section.rawValue)
                .font(.title2)
            Text("\(pages.count) rows")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(pages) { page in
                Button {
                    onSelect(page.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: page.symbol)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 18)
                        Text(page.title)
                            .font(page.monospaceTitle ? .system(.body, design: .monospaced) : .body)
                        Spacer()
                        Text(section == .mediaUI ? "\(page.stateCount) states" : "\(page.typeCount) types")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overview.\(page.id.rawValue)")
            }
            Text("\(section.markerName) · \(CatalogIndex.markerLine)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }
}
