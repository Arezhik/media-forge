import XCTest

// Helpers: waits and the macOS SwiftUI text query shared by pages and components.

/// Timeouts for `waitForExistence`. Window and controls use `standard`.
/// A queue row that fails after intake uses `batch`.
enum UITestTimeout {
    static let short: TimeInterval = 2
    static let standard: TimeInterval = 5
    static let long: TimeInterval = 10
    /// Empty-file intake finishes well inside this. OCR is not part of these tests.
    static let batch: TimeInterval = 60
}

/// Shallow locators. `descendants(matching: .any)` and a wide `.other` snapshot
/// time out on macOS ("Timed out while evaluating UI query").
/// Each candidate is one element type on one window.
enum UITestQuery {
    /// `XCUIElementQuery` subscript matches identifier, label, or title.
    @MainActor
    static func identified(
        _ identifier: String,
        in root: XCUIElement,
        types: [XCUIElement.ElementType]
    ) -> [XCUIElement] {
        types.map { root.descendants(matching: $0)[identifier] }
    }

    @MainActor
    static func matching(
        _ predicate: NSPredicate,
        in root: XCUIElement,
        types: [XCUIElement.ElementType]
    ) -> [XCUIElement] {
        types.map { root.descendants(matching: $0).matching(predicate).firstMatch }
    }
}

@MainActor
extension XCUIApplication {
    /// The queue window while Settings may also be open.
    ///
    /// The queue window's accessibility identifier is `pgs2srt.queue`.
    /// The Settings title bar names the selected pane, so a title filter is not enough.
    var mainWindow: XCUIElement {
        let marked = windows["pgs2srt.queue"]
        if marked.exists { return marked }
        if let queue = windows.allElementsBoundByIndex.first(where: { window in
            window.staticTexts["settingsSummary"].exists
                || window.groups["emptyDrop"].exists
                || window.otherElements["emptyDrop"].exists
        }) {
            return queue
        }
        return windows.matching(
            NSPredicate(format: "NOT (title CONTAINS[c] %@)", "Settings")
        ).firstMatch
    }
}

enum UITestWait {
    /// Returns the first element that exists, polling until `timeout`.
    /// Each element must already be one element type on one window.
    @MainActor
    static func firstExisting(_ elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
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

enum UITestPoll {
    /// Polls until `body` is true or the timeout elapses.
    @MainActor
    static func until(_ timeout: TimeInterval, _ body: () -> Bool) -> Bool {
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
    func matchingLabelOrValue(containing text: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
    }

    /// Elements whose own `label` or `value` equals `text`.
    func matchingLabelOrValue(equalTo text: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label == %@ OR value == %@", text, text))
    }
}

@MainActor
extension XCUIElement {
    /// Visible string. Controls that set `accessibilityLabel` expose `label`.
    /// SwiftUI `Text` usually puts the string in `value` and leaves `label` empty.
    var uiText: String {
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
    func requireExists(
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(waitForExistence(timeout: timeout), message, file: file, line: line)
        return self
    }

    func clickWhenReady(
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireExists(timeout: timeout, message: message, file: file, line: line)
        click()
    }

    /// Switch and checkbox values. macOS reports `1`/`0` or `on`/`off`.
    var switchIsOn: Bool? {
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
    func waitUntilSwitch(
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
