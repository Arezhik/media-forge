import AppKit
import MediaForgeCatalogCore
import MediaUI
import SwiftUI
import UniformTypeIdentifiers

struct FileDropPage: View {
    @Binding var liveTile: String
    @Binding var results: [ResultLine]
    var tileScheme: ColorScheme
    @State private var phase = "idle"
    @State private var hoverCount = 0
    @State private var acceptedNames: [String] = []
    @State private var resetToken = UUID()

    private var page: CatalogPage { CatalogIndex.page(.fileDrop)! }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoHeader(page: page)
                StateTileGrid(pageID: .fileDrop, tiles: page.tiles, liveID: liveTile, tileScheme: tileScheme) { tile in
                    fileDropWell(tile.id)
                }
                HStack(alignment: .top, spacing: 16) {
                    tryIt
                    ResultsPane(lines: $results)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            phase = liveTile
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it")
                .font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(phase == "hover" ? Color.accentColor.opacity(0.12) : Color(nsColor: .textBackgroundColor))
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        phase == "hover" ? Color.accentColor : Color.secondary,
                        style: StrokeStyle(lineWidth: phase == "hover" ? 2 : 1.5, dash: phase == "hover" ? [] : [7, 4])
                    )
                fileDropWell(phase)
                    .padding(16)
            }
            .frame(minHeight: 180)
            .onDrop(
                of: [UTType.fileURL, UTType.data, UTType.item],
                delegate: FileDropDelegate(
                    onHover: { accepts, count in
                        hoverCount = count
                        if accepts {
                            phase = "hover"
                            liveTile = "hover"
                            appendResult($results, "hasFileURL(_:) → true")
                        } else {
                            phase = "idle"
                            liveTile = "idle"
                        }
                    },
                    onExit: {
                        if phase == "hover" {
                            phase = "idle"
                            liveTile = "idle"
                        }
                    },
                    onPerform: { providers in
                        let accepts = FileDrop.hasFileURL(providers)
                        appendResult($results, "hasFileURL(_:) → \(accepts)")
                        guard accepts else {
                            phase = "rejected"
                            liveTile = "rejected"
                            appendResult($results, "Rejected. Only files can be dropped here.")
                            scheduleIdle()
                            return false
                        }
                        Task { @MainActor in
                            let urls = await FileDrop.loadFileURLs(from: providers)
                            accept(urls, call: "loadFileURLs(from:)")
                        }
                        return true
                    }
                )
            )
            .accessibilityIdentifier("fileDrop.zone")
            Button("Choose Files…") {
                let urls = FilePanels.chooseFiles(title: "Choose Files", prompt: "Choose")
                if let urls {
                    accept(urls, call: "FilePanels.chooseFiles")
                } else {
                    appendResult($results, "FilePanels.chooseFiles → nil")
                }
            }
            Text("Choose Files… calls FilePanels.chooseFiles. The zone calls FileDrop.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func fileDropWell(_ id: String) -> some View {
        VStack(spacing: 6) {
            switch id {
            case "hover":
                Image(systemName: "square.and.arrow.down")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                Text(hoverCount > 0 ? "Release to add \(hoverCount) files" : "Release to add files")
                    .font(.callout)
                    .multilineTextAlignment(.center)
            case "accepted":
                Image(systemName: "checkmark.circle")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                Text(acceptedSummary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            case "rejected":
                Image(systemName: "nosign")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Only files can be dropped here")
                    .font(.callout)
                    .multilineTextAlignment(.center)
            default:
                Image(systemName: "square.and.arrow.down")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Drop media files here")
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var acceptedSummary: String {
        guard !acceptedNames.isEmpty else { return "Added N files" }
        let head = acceptedNames.prefix(3).joined(separator: ", ")
        let more = acceptedNames.count > 3 ? " +\(acceptedNames.count - 3) more" : ""
        return "\(head)\(more)\nAdded \(acceptedNames.count) files"
    }

    private func accept(_ urls: [URL], call: String) {
        acceptedNames = urls.map(\.lastPathComponent)
        phase = "accepted"
        liveTile = "accepted"
        let listed = acceptedNames.isEmpty ? "no file URLs" : acceptedNames.joined(separator: ", ")
        appendResult($results, "\(call) → \(listed)")
        scheduleIdle()
    }

    private func scheduleIdle() {
        let token = UUID()
        resetToken = token
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard resetToken == token else { return }
            phase = "idle"
            liveTile = "idle"
        }
    }
}

private struct FileDropDelegate: DropDelegate {
    var onHover: (Bool, Int) -> Void
    var onExit: () -> Void
    var onPerform: ([NSItemProvider]) -> Bool

    func dropEntered(info: DropInfo) {
        MainActor.assumeIsolated {
            let providers = info.itemProviders(for: [UTType.fileURL, UTType.data, UTType.item])
            let accepts = FileDrop.hasFileURL(providers)
            let count = providers.filter {
                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }.count
            onHover(accepts, count)
        }
    }

    func dropExited(info: DropInfo) {
        MainActor.assumeIsolated { onExit() }
    }

    func validateDrop(info: DropInfo) -> Bool { true }

    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated {
            let providers = info.itemProviders(for: [UTType.fileURL, UTType.data, UTType.item])
            return onPerform(providers)
        }
    }
}

struct FilePanelsPage: View {
    @Binding var liveTile: String
    @Binding var results: [ResultLine]
    var tileScheme: ColorScheme
    @State private var preset: PanelPreset = .folder

    private var page: CatalogPage { CatalogIndex.page(.filePanels)! }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoHeader(page: page)
                StateTileGrid(pageID: .filePanels, tiles: page.tiles, liveID: liveTile, tileScheme: tileScheme) { tile in
                    panelWell(tile.id)
                }
                HStack(alignment: .top, spacing: 16) {
                    tryIt
                    ResultsPane(lines: $results)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it")
                .font(.headline)
            Text("OpenPanelOptions preset")
                .font(.subheadline.weight(.semibold))
            Picker("Preset", selection: $preset) {
                ForEach(PanelPreset.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: preset) { _, newValue in
                liveTile = newValue.rawValue
            }
            Button(preset.buttonTitle) { openPreset() }
            Text("Values from \(preset.label). The button calls \(preset.callName).")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenPanelOptions")
                    .font(.subheadline.weight(.semibold))
                ForEach(preset.fields) { field in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(field.name)
                            .frame(width: 230, alignment: .leading)
                        Text(field.typeName)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(field.value)
                            .foregroundStyle(field.isBool ? Color.accentColor : (field.isNil ? Color.secondary : Color.primary))
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .accessibilityIdentifier("openPanelFields")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openPreset() {
        switch preset {
        case .folder:
            if let url = FilePanels.chooseFolder() {
                liveTile = "folder"
                appendResult($results, "chooseFolder → \(url.path)")
            } else {
                liveTile = "cancel"
                appendResult($results, "chooseFolder → nil")
            }
        case .files:
            if let urls = FilePanels.chooseFiles() {
                liveTile = "files"
                let names = urls.map(\.lastPathComponent).joined(separator: ", ")
                appendResult($results, "chooseFiles → \(names.isEmpty ? "[]" : names)")
            } else {
                liveTile = "cancel"
                appendResult($results, "chooseFiles → nil")
            }
        case .tool:
            if let url = FilePanels.chooseTool() {
                liveTile = "tool"
                appendResult($results, "chooseTool → \(url.path)")
            } else {
                liveTile = "cancel"
                appendResult($results, "chooseTool → nil")
            }
        }
    }

    @ViewBuilder
    private func panelWell(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch id {
            case "folder":
                Text("Open").font(.caption.weight(.semibold))
                Label("Folders", systemImage: "folder")
                Text("Files greyed out").font(.caption2).foregroundStyle(.tertiary)
            case "files":
                Text("Open").font(.caption.weight(.semibold))
                Label("clip.txt", systemImage: "doc")
                Label("notes.txt", systemImage: "doc")
                Text("Multi-select").font(.caption2).foregroundStyle(.secondary)
            case "tool":
                Text("Open").font(.caption.weight(.semibold))
                Label("ffmpeg", systemImage: "terminal")
                Text("One executable").font(.caption2).foregroundStyle(.secondary)
            default:
                Image(systemName: "nosign").foregroundStyle(.secondary)
                Text("Cancelled · no URL returned")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum PanelPreset: String, CaseIterable, Identifiable, Hashable {
    case folder
    case files
    case tool

    var id: String { rawValue }

    var label: String {
        switch self {
        case .folder: return ".folder(…)"
        case .files: return ".files(…)"
        case .tool: return ".tool(…)"
        }
    }

    var buttonTitle: String {
        switch self {
        case .folder: return "Choose Folder…"
        case .files: return "Choose Files…"
        case .tool: return "Choose Tool…"
        }
    }

    var callName: String {
        switch self {
        case .folder: return "chooseFolder"
        case .files: return "chooseFiles"
        case .tool: return "chooseTool"
        }
    }

    var options: OpenPanelOptions {
        switch self {
        case .folder: return OpenPanelOptions.folder()
        case .files: return OpenPanelOptions.files()
        case .tool: return OpenPanelOptions.tool()
        }
    }

    var fields: [OptionField] {
        let options = self.options
        return [
            OptionField("title", "String?", options.title),
            OptionField("message", "String?", options.message),
            OptionField("prompt", "String?", options.prompt),
            OptionField("canChooseFiles", "Bool", options.canChooseFiles),
            OptionField("canChooseDirectories", "Bool", options.canChooseDirectories),
            OptionField("allowsMultipleSelection", "Bool", options.allowsMultipleSelection),
            OptionField("canCreateDirectories", "Bool", options.canCreateDirectories),
            OptionField("treatsFilePackagesAsDirectories", "Bool", options.treatsFilePackagesAsDirectories),
            OptionField("resolvesAliases", "Bool", options.resolvesAliases),
            OptionField("allowedContentTypes", "[UTType]?", options.allowedContentTypes),
            OptionField("directoryURL", "URL?", options.directoryURL),
        ]
    }
}

private struct OptionField: Identifiable {
    let name: String
    let typeName: String
    let value: String
    let isBool: Bool
    let isNil: Bool
    var id: String { name }

    init(_ name: String, _ typeName: String, _ value: String?) {
        self.name = name
        self.typeName = typeName
        if let value {
            self.value = value
            self.isNil = false
        } else {
            self.value = "nil"
            self.isNil = true
        }
        self.isBool = false
    }

    init(_ name: String, _ typeName: String, _ value: Bool) {
        self.name = name
        self.typeName = typeName
        self.value = value ? "true" : "false"
        self.isBool = true
        self.isNil = false
    }

    init(_ name: String, _ typeName: String, _ types: [UTType]?) {
        self.name = name
        self.typeName = typeName
        if let types {
            self.value = types.map(\.identifier).joined(separator: ", ")
            self.isNil = false
        } else {
            self.value = "nil"
            self.isNil = true
        }
        self.isBool = false
    }

    init(_ name: String, _ typeName: String, _ url: URL?) {
        self.name = name
        self.typeName = typeName
        if let url {
            self.value = SampleFiles.abbreviate(url)
            self.isNil = false
        } else {
            self.value = "nil"
            self.isNil = true
        }
        self.isBool = false
    }
}

struct RevealPage: View {
    @Binding var liveTile: String
    @Binding var results: [ResultLine]
    var tileScheme: ColorScheme

    private var page: CatalogPage { CatalogIndex.page(.reveal)! }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoHeader(page: page)
                StateTileGrid(pageID: .reveal, tiles: page.tiles, liveID: liveTile, tileScheme: tileScheme) { tile in
                    revealWell(tile.id)
                }
                HStack(alignment: .top, spacing: 16) {
                    tryIt
                    ResultsPane(lines: $results)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if !SampleFiles.fileExists || !SampleFiles.folderExists {
                liveTile = "missing"
            }
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it")
                .font(.headline)
            Text(SampleFiles.abbreviatedDirectory)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            labeledButton("File", "Reveal File", enabled: SampleFiles.fileExists) {
                revealFile()
            }
            labeledButton("Folder", "Show Folder", enabled: SampleFiles.folderExists) {
                revealFolder()
            }
            labeledButton("Items", "Activate Finder", enabled: SampleFiles.fileExists) {
                activate()
            }
            Text("Missing paths are a catalog pre-check. The Reveal call is skipped.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledButton(_ kind: String, _ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(kind)
                .font(.subheadline.weight(.semibold))
                .frame(width: 56, alignment: .leading)
            Button(title, action: action)
                .disabled(!enabled)
        }
    }

    private func revealFile() {
        let path = SampleFiles.file.path
        guard SampleFiles.fileExists else {
            liveTile = "missing"
            appendResult($results, "Missing path. selectFile(path:) not called.")
            return
        }
        Reveal.selectFile(path: path)
        liveTile = "selectFile"
        appendResult($results, "selectFile(path:) \(path)")
    }

    private func revealFolder() {
        let path = SampleFiles.folder.path
        guard SampleFiles.folderExists else {
            liveTile = "missing"
            appendResult($results, "Missing path. selectFolder(path:) not called.")
            return
        }
        Reveal.selectFolder(path: path)
        liveTile = "selectFolder"
        appendResult($results, "selectFolder(path:) \(path)")
    }

    private func activate() {
        let url = SampleFiles.file
        guard SampleFiles.fileExists else {
            liveTile = "missing"
            appendResult($results, "Missing path. activateViewer(_:) not called.")
            return
        }
        Reveal.activateViewer([url])
        liveTile = "activateViewer"
        appendResult($results, "activateViewer(_:) \(url.path)")
    }

    @ViewBuilder
    private func revealWell(_ id: String) -> some View {
        VStack(spacing: 6) {
            switch id {
            case "selectFile":
                Image(systemName: "doc.text.magnifyingglass")
                Text("File highlighted").font(.caption)
            case "selectFolder":
                Image(systemName: "folder")
                Text("Folder open").font(.caption)
            case "activateViewer":
                Image(systemName: "macwindow")
                Text("Finder in front").font(.caption)
            default:
                Image(systemName: "nosign").foregroundStyle(.secondary)
                Text("Reveal disabled").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DebugLogExportPage: View {
    @Binding var liveTile: String
    @Binding var results: [ResultLine]
    var tileScheme: ColorScheme
    @State private var revealAfter = true
    @State private var choice: DebugLogExport.RevealChoice = .selectFile

    private var page: CatalogPage { CatalogIndex.page(.debugLogExport)! }

    private var saveOptions: DebugLogExport.SaveOptions {
        DebugLogExport.SaveOptions(
            fileName: "debug-\(Self.dayStamp).log",
            title: "Export Debug Log",
            prompt: "Save",
            message: "Synthetic MediaForgeCatalog sample. Not a user debug log."
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoHeader(page: page)
                StateTileGrid(pageID: .debugLogExport, tiles: page.tiles, liveID: liveTile, tileScheme: tileScheme) { tile in
                    exportWell(tile.id)
                }
                HStack(alignment: .top, spacing: 16) {
                    tryIt
                    ResultsPane(lines: $results)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it")
                .font(.headline)
            Button("Export Debug Log…") { export() }
            Text("Default file name \(saveOptions.fileName). Writes a synthetic sample, never a user log.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Reveal after saving", isOn: $revealAfter)
                .accessibilityIdentifier("revealAfterSaving")
            Text("Catalog option. Not a RevealChoice case. Off means reveal(_:choice:) is not called.")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                choiceRow(.selectFile, ".selectFile", [.mp4SubRip])
                choiceRow(.activateViewer, ".activateViewer", [.mkvForge, .pgs2srt])
            }
            .disabled(!revealAfter)
            .padding(.leading, 16)
            Text("Both cases reveal in Finder.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choiceRow(
        _ value: DebugLogExport.RevealChoice,
        _ label: String,
        _ apps: [ProductApp]
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                choice = value
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: choice == value ? "largecircle.fill.circle" : "circle")
                    Text(label)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .buttonStyle(.plain)
            .disabled(!revealAfter)
            AdoptionChips(adoption: .apps(apps), height: 15)
        }
    }

    private func export() {
        let options = saveOptions
        guard let url = DebugLogExport.chooseDestination(options) else {
            liveTile = "cancel"
            appendResult($results, "chooseDestination(_:) → nil")
            return
        }
        let body = "MediaForgeCatalog synthetic debug log\nCreated \(ISO8601DateFormatter().string(from: Date()))\n"
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            appendResult($results, "write failed: \(error.localizedDescription)")
            return
        }
        guard revealAfter else {
            liveTile = "save"
            appendResult($results, "saved · reveal not called (option off)")
            return
        }
        DebugLogExport.reveal(url, choice: choice)
        switch choice {
        case .selectFile:
            liveTile = "selectFile"
            appendResult($results, "reveal(_:choice:) .selectFile \(url.lastPathComponent)")
        case .activateViewer:
            liveTile = "activateViewer"
            appendResult($results, "reveal(_:choice:) .activateViewer \(url.lastPathComponent)")
        }
    }

    @ViewBuilder
    private func exportWell(_ id: String) -> some View {
        VStack(spacing: 6) {
            switch id {
            case "save":
                Text("Save As").font(.caption.weight(.semibold))
                Text(saveOptions.fileName).font(.caption2).lineLimit(1)
                Text("Where").font(.caption2).foregroundStyle(.secondary)
            case "selectFile":
                Image(systemName: "doc.text.magnifyingglass")
                Text(".selectFile").font(.caption)
            case "activateViewer":
                Image(systemName: "macwindow")
                Text(".activateViewer").font(.caption)
            default:
                Image(systemName: "nosign").foregroundStyle(.secondary)
                Text("Cancelled · nothing written").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static var dayStamp: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
