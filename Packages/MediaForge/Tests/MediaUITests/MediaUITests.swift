import XCTest
@testable import MediaUI

final class MediaUITests: XCTestCase {
    func testMarkerCompilesWithoutSwiftUI() {
        XCTAssertEqual(MediaUIMarker.moduleName, "MediaUI")
        #if canImport(SwiftUI)
        XCTAssertTrue(MediaUIMarker.swiftUIAvailable)
        #else
        XCTAssertFalse(MediaUIMarker.swiftUIAvailable)
        #endif
    }
}

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

@MainActor
final class OpenPanelOptionsTests: XCTestCase {
    func testFolderOptionsMapOntoThePanel() {
        let directory = URL(fileURLWithPath: "/Users/me/Movies", isDirectory: true)
        let options = OpenPanelOptions.folder(
            title: "Output Folder",
            message: "Converted .srt files will be written in this folder.",
            prompt: "Choose",
            canCreateDirectories: true,
            directoryURL: directory
        )
        let panel = NSOpenPanel()
        options.apply(to: panel)

        XCTAssertEqual(panel.title, "Output Folder")
        XCTAssertEqual(panel.message, "Converted .srt files will be written in this folder.")
        XCTAssertEqual(panel.prompt, "Choose")
        XCTAssertFalse(panel.canChooseFiles)
        XCTAssertTrue(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertTrue(panel.canCreateDirectories)
        XCTAssertFalse(panel.treatsFilePackagesAsDirectories)
        XCTAssertTrue(panel.resolvesAliases)
        XCTAssertEqual(panel.directoryURL, directory)
    }

    func testFilesOptionsMapOntoThePanel() {
        let options = OpenPanelOptions.files(
            title: "Add Files",
            prompt: "Add",
            canChooseDirectories: true,
            allowsMultipleSelection: true,
            allowedContentTypes: [.folder, .mpeg4Movie]
        )
        let panel = NSOpenPanel()
        options.apply(to: panel)

        XCTAssertEqual(panel.title, "Add Files")
        XCTAssertEqual(panel.prompt, "Add")
        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertTrue(panel.canChooseDirectories)
        XCTAssertTrue(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.canCreateDirectories)
        XCTAssertEqual(panel.allowedContentTypes, [.folder, .mpeg4Movie])
    }

    func testToolOptionsMapOntoThePanel() {
        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let options = OpenPanelOptions.tool(
            message: "Choose the MKVToolNix app or the mkvmerge program.",
            prompt: "Choose",
            canChooseDirectories: false,
            treatsFilePackagesAsDirectories: false,
            resolvesAliases: false,
            allowedContentTypes: [.unixExecutable, .application, .folder],
            directoryURL: applications
        )
        let panel = NSOpenPanel()
        options.apply(to: panel)

        XCTAssertEqual(panel.message, "Choose the MKVToolNix app or the mkvmerge program.")
        XCTAssertEqual(panel.prompt, "Choose")
        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.treatsFilePackagesAsDirectories)
        XCTAssertFalse(panel.resolvesAliases)
        XCTAssertEqual(panel.allowedContentTypes, [.unixExecutable, .application, .folder])
        XCTAssertEqual(panel.directoryURL, applications)
    }

    func testApplyLeavesUnsetOptionals() {
        let panel = NSOpenPanel()
        panel.title = "Keep"
        panel.message = "Keep message"
        panel.prompt = "Keep prompt"
        let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)
        panel.directoryURL = directory
        panel.allowedContentTypes = [.folder]

        OpenPanelOptions.folder(canCreateDirectories: true).apply(to: panel)

        XCTAssertEqual(panel.title, "Keep")
        XCTAssertEqual(panel.message, "Keep message")
        XCTAssertEqual(panel.prompt, "Keep prompt")
        XCTAssertEqual(panel.directoryURL, directory)
        XCTAssertEqual(panel.allowedContentTypes, [.folder])
        XCTAssertFalse(panel.canChooseFiles)
        XCTAssertTrue(panel.canChooseDirectories)
        XCTAssertTrue(panel.canCreateDirectories)
    }

    func testFolderAndFilesDisagreeOnChoosingFiles() {
        XCTAssertFalse(OpenPanelOptions.folder().canChooseFiles)
        XCTAssertTrue(OpenPanelOptions.files().canChooseFiles)
        XCTAssertFalse(OpenPanelOptions.tool().allowsMultipleSelection)
        XCTAssertTrue(OpenPanelOptions.files().allowsMultipleSelection)
    }
}

final class FileDropParsingTests: XCTestCase {
    func testURLPassesThrough() {
        // loadItem hands back NSSecureCoding. URL does not conform; NSURL does and bridges to URL.
        let original = URL(fileURLWithPath: "/tmp/clip.mp4")
        XCTAssertEqual(FileDrop.url(from: original as NSURL), original)
    }

    func testDataPathString() {
        let data = Data("  /tmp/clip.mp4\n".utf8)
        XCTAssertEqual(FileDrop.url(from: data as NSData)?.path, "/tmp/clip.mp4")
    }

    func testFileURLString() {
        let url = FileDrop.url(from: "file:///tmp/clip.mp4" as NSString)
        XCTAssertEqual(url?.path, "/tmp/clip.mp4")
    }

    func testPathStringTrimsWhitespace() {
        let url = FileDrop.url(from: "  /tmp/clip.mp4\n" as NSString)
        XCTAssertEqual(url?.path, "/tmp/clip.mp4")
    }

    func testEmptyStringIsNil() {
        XCTAssertNil(FileDrop.url(from: "   " as NSString))
        XCTAssertNil(FileDrop.url(from: "" as NSString))
        XCTAssertNil(FileDrop.url(from: nil))
    }

    func testDataRoundTrip() {
        let original = URL(fileURLWithPath: "/tmp/clip.mp4")
        let url = FileDrop.url(from: original.dataRepresentation as NSData)
        XCTAssertEqual(url?.path, original.path)
    }

    func testDataFileURLString() {
        let data = Data("file:///tmp/clip.mp4".utf8)
        XCTAssertEqual(FileDrop.url(from: data as NSData)?.path, "/tmp/clip.mp4")
    }
}

@MainActor
final class DebugLogSaveOptionsTests: XCTestCase {
    func testSaveOptionsMapOntoThePanel() {
        let options = DebugLogExport.SaveOptions(
            fileName: "MKVForge-debug.txt",
            title: "Export Debug Log",
            prompt: "Save",
            message: "The Desktop could not be written. disk full"
        )
        let panel = NSSavePanel()
        options.apply(to: panel)

        XCTAssertEqual(panel.title, "Export Debug Log")
        XCTAssertEqual(panel.prompt, "Save")
        XCTAssertEqual(panel.nameFieldStringValue, "MKVForge-debug.txt")
        XCTAssertEqual(panel.message, "The Desktop could not be written. disk full")
        XCTAssertTrue(panel.canCreateDirectories)
        XCTAssertEqual(panel.allowedContentTypes, [.plainText])
    }

    func testRevealChoicesStayDistinct() {
        XCTAssertNotEqual(DebugLogExport.RevealChoice.selectFile, .activateViewer)
    }
}
#endif
