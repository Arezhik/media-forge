#if canImport(XCTest) && os(macOS)
import XCTest

// Waits and the macOS SwiftUI text query shared by pages and components.

/// Timeouts for `waitForExistence`. Window and controls use `standard`.
/// A queue row after Scan, or a batch, uses `long` or `batch`.
public enum UITestTimeout {
    public static let short: TimeInterval = 2
    public static let standard: TimeInterval = 5
    public static let long: TimeInterval = 10
    /// One short job, including process startup. Not a long OCR or transcode.
    public static let batch: TimeInterval = 60
}

/// Shallow locators. `descendants(matching: .any)` snapshots the whole tree
/// and times out on macOS. Each candidate is one element type.
@MainActor
public enum UITestQuery {
    /// `XCUIElementQuery` subscript matches identifier, label, or title.
    public static func identified(
        _ identifier: String,
        in root: XCUIElement,
        types: [XCUIElement.ElementType]
    ) -> [XCUIElement] {
        types.map { root.descendants(matching: $0)[identifier] }
    }

    public static func matching(
        _ predicate: NSPredicate,
        in root: XCUIElement,
        types: [XCUIElement.ElementType]
    ) -> [XCUIElement] {
        types.map { root.descendants(matching: $0).matching(predicate).firstMatch }
    }

    public static func count(
        matching predicate: NSPredicate,
        in root: XCUIElement,
        types: [XCUIElement.ElementType]
    ) -> Int {
        types.reduce(0) { partial, type in
            partial + root.descendants(matching: type).matching(predicate).count
        }
    }

    public static func all(
        matching predicate: NSPredicate,
        in root: XCUIElement,
        types: [XCUIElement.ElementType]
    ) -> [XCUIElement] {
        types.flatMap { root.descendants(matching: $0).matching(predicate).allElementsBoundByIndex }
    }
}

@MainActor
extension XCUIApplication {
    /// The main window while Settings may also be open.
    ///
    /// `windows["AppName"]` checks identifier or title. SwiftUI often fails that
    /// check. An empty title still matches this predicate.
    /// PGS2SRT's queue window identifier is `pgs2srt.queue`. Pass that to
    /// `mainWindow(identifier:)` or override `MainWindowPage.root`.
    public var mainWindow: XCUIElement {
        windows.matching(
            NSPredicate(format: "NOT (title CONTAINS[c] %@)", "Settings")
        ).firstMatch
    }

    /// `windows[identifier]` when that window is already up, otherwise `mainWindow`.
    public func mainWindow(identifier: String) -> XCUIElement {
        let marked = windows[identifier]
        if marked.exists { return marked }
        return mainWindow
    }
}

@MainActor
public enum UITestWait {
    /// Returns the first element that exists, polling until `timeout`.
    /// Each element must already be one element type on one window.
    public static func firstExisting(_ elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            for element in elements where element.exists {
                return element
            }
            if Date() >= deadline {
                return nil
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}

@MainActor
public enum UITestPoll {
    /// Polls until `body` is true or the timeout elapses.
    public static func until(_ timeout: TimeInterval, _ body: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if body() {
                return true
            }
            if Date() >= deadline {
                return false
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}

@MainActor
extension XCUIElementQuery {
    /// Elements whose own `label` or `value` contains `text`.
    ///
    /// SwiftUI `Text` on macOS exposes its string as `value`. `label` is often empty.
    /// `containing` searches descendants, so a `StaticText` never matches
    /// `label CONTAINS`. Use `matching` with both keys.
    /// Not for switches or checkboxes. Their `value` is `1` or `0`.
    public func matchingLabelOrValue(containing text: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
    }

    /// Elements whose own `label` or `value` equals `text`.
    public func matchingLabelOrValue(equalTo text: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label == %@ OR value == %@", text, text))
    }
}

@MainActor
extension XCUIElement {
    /// Visible string for MKVForge.
    /// Folder fields set `accessibilityLabel` (`label`). SwiftUI `Text` usually
    /// puts the string in `value` and leaves `label` empty.
    /// Exact checks (the batch caption) depend on this order. Do not fold `title` in.
    /// Menu buttons use `uiMenuText`. Rows that expose both label and value use `uiLabelAndValue`.
    public var uiText: String {
        if !label.isEmpty {
            return label
        }
        if let text = value as? String {
            return text
        }
        return ""
    }

    /// Label, title, and value, skipping blanks and duplicates.
    /// MP4 menu buttons and pop-ups put the chosen title in `title`.
    public var uiMenuText: String {
        let valueText = value as? String ?? ""
        var parts: [String] = []
        for part in [label, title, valueText] where !part.isEmpty && !parts.contains(part) {
            parts.append(part)
        }
        return parts.joined(separator: " ")
    }

    /// Label and value together when both are set and different. Otherwise label, else value.
    /// PGS2SRT static texts use this.
    public var uiLabelAndValue: String {
        let valueText = value as? String ?? ""
        if !label.isEmpty && !valueText.isEmpty && label != valueText {
            return label + " " + valueText
        }
        if !label.isEmpty {
            return label
        }
        return valueText
    }

    @discardableResult
    public func requireExists(
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(waitForExistence(timeout: timeout), message, file: file, line: line)
        return self
    }

    public func clickWhenReady(
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireExists(timeout: timeout, message: message, file: file, line: line)
        click()
    }

    /// Switch and checkbox values. macOS reports `1`/`0` or `on`/`off`.
    public var switchIsOn: Bool? {
        let raw = (value.map { "\($0)" } ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch raw {
        case "1", "on", "true":
            return true
        case "0", "off", "false":
            return false
        default:
            return nil
        }
    }

    /// The Settings bindings write on the next main-actor turn, so poll the value.
    public func waitUntilSwitch(
        isOn expected: Bool,
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if switchIsOn == expected {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("\(message) Value was \(value.map { "\($0)" } ?? "nil").", file: file, line: line)
    }
}
#endif
