#if canImport(XCTest) && os(macOS)
import XCTest

// Shared queue-row lookup: identifier plus label or value.
// Badge sentences ("Ready", "Issue", file names) stay on the app component.
// Lookups use groups, cells, static texts, other elements, and outline rows.
// `descendants(matching: .any)` snapshots the whole tree and times out on macOS.

/// One queue row, found by identifier and by a label or value fragment.
@MainActor
open class QueueRowComponent {
    /// Element types that can carry `queueRow` or the name-cell string.
    public static let elementTypes: [XCUIElement.ElementType] = [
        .group, .cell, .staticText, .other, .outlineRow,
    ]

    public let app: XCUIApplication
    public let stem: String

    /// Accessibility identifier on the row. MKVForge and PGS2SRT use `queueRow`.
    open var rowIdentifier: String { "queueRow" }

    public init(app: XCUIApplication, stem: String) {
        self.app = app
        self.stem = stem
    }

    /// `queueRow` whose label or value contains the stem.
    public var identifiedElement: XCUIElement {
        let matches = rows(matching: identifierContains(stem))
        return matches.first { $0.exists } ?? matches[0]
    }

    /// Name-cell fallback. `matching`, not `containing`.
    public var stemElement: XCUIElement {
        let candidates = textRows(containing: stem)
        return candidates.first { $0.exists } ?? candidates[0]
    }

    /// The row to read. Prefers `queueRow` when that element is already on screen.
    public var element: XCUIElement {
        identifiedElement.exists ? identifiedElement : stemElement
    }

    @discardableResult
    open func requireExists(
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let identified = rows(matching: identifierContains(stem))
        if let row = UITestWait.firstExisting(identified + textRows(containing: stem), timeout: timeout) {
            return row
        }
        XCTFail(
            "The queue row for \(stem) never showed up. Observed: \(observedQueueTexts()). \(queueRowSummary())",
            file: file,
            line: line
        )
        return stemElement
    }

    /// Exact VoiceOver string on `queueRow`, then a name-cell fallback.
    /// Primary match is `identifier == rowIdentifier AND (label == expected OR value == expected)`.
    @discardableResult
    open func requireExactLabel(
        _ expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let identified = rows(matching: identifierEquals(expected))
        let fallback = textRows(equalTo: expected)
        guard let row = UITestWait.firstExisting(identified + fallback, timeout: timeout) else {
            XCTFail(
                "The queue row \(expected) never showed up. Observed: \(observedQueueTexts()). \(queueRowSummary())",
                file: file,
                line: line
            )
            return fallback[0]
        }
        return row
    }

    /// Waits until no queue row still shows `expected`.
    open func assertExactLabelAbsent(
        _ expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identified = rows(matching: identifierEquals(expected))
        let fallback = textRows(equalTo: expected)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !identified.contains(where: \.exists), !fallback.contains(where: \.exists) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "The queue row \(expected) was still on screen. \(queueRowSummary())",
            file: file,
            line: line
        )
    }

    public func rows(matching predicate: NSPredicate) -> [XCUIElement] {
        UITestQuery.matching(predicate, in: app, types: Self.elementTypes)
    }

    public func textRows(containing text: String) -> [XCUIElement] {
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        return UITestQuery.matching(predicate, in: app, types: Self.elementTypes)
    }

    public func textRows(equalTo text: String) -> [XCUIElement] {
        let predicate = NSPredicate(format: "label == %@ OR value == %@", text, text)
        return UITestQuery.matching(predicate, in: app, types: Self.elementTypes)
    }

    /// `queueRow` labels, plus each row's label and value.
    public func queueRowSummary() -> String {
        let listed = UITestQuery.all(
            matching: NSPredicate(format: "identifier == %@", rowIdentifier),
            in: app,
            types: Self.elementTypes
        )
        let labels = listed.map(\.label)
        let described = listed.map { describe($0) }
        return "queueRow labels: \(labels). queueRow texts: [\(described.joined(separator: "; "))]"
    }

    public func describe(_ element: XCUIElement) -> String {
        let value = element.value.map { "\($0)" } ?? ""
        return "label='\(element.label)' value='\(value)'"
    }

    public func named(_ name: String) -> NSPredicate {
        NSPredicate(format: "label == %@ OR value == %@ OR title == %@", name, name, name)
    }

    /// Labels and values from the queue outline, for a failed row assertion.
    public func observedQueueTexts() -> String {
        let outline = app.outlines.firstMatch
        guard outline.exists else {
            return "no outline; " + summarizedStaticTexts(app.staticTexts)
        }
        let outlineRows = outline.descendants(matching: .outlineRow).allElementsBoundByIndex
        guard !outlineRows.isEmpty else {
            return "outline with 0 rows; " + summarizedStaticTexts(outline.descendants(matching: .staticText))
        }
        let described = outlineRows.prefix(6).map { row -> String in
            let texts = row.descendants(matching: .staticText).allElementsBoundByIndex.map { describe($0) }
            return "row(\(describe(row)) texts=[\(texts.joined(separator: "; "))])"
        }
        return described.joined(separator: " | ")
    }

    private func identifierContains(_ text: String) -> NSPredicate {
        NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            rowIdentifier, text, text
        )
    }

    private func identifierEquals(_ text: String) -> NSPredicate {
        NSPredicate(
            format: "identifier == %@ AND (label == %@ OR value == %@)",
            rowIdentifier, text, text
        )
    }

    private func summarizedStaticTexts(_ query: XCUIElementQuery) -> String {
        let texts = query.allElementsBoundByIndex.prefix(12).map { describe($0) }
        return "staticTexts=[\(texts.joined(separator: "; "))]"
    }
}
#endif
