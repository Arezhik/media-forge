import MediaTesting
import XCTest

// MKVForge queue row. Shared lookup (identifier plus label or value) is
// MediaTesting.QueueRowComponent. Include, Choose Match, and Unmatch stay here.
// Badge copy is the exact label the tests already pass in.

/// One queue row, found by its file stem (the base name, such as `"sample"`).
@MainActor
final class QueueRowComponent: MediaTesting.QueueRowComponent {
    /// The row's checkbox. Accessibility label is `Include <stem>`.
    /// Flagged rows use the same label and stay disabled.
    func clickIncludeCheckbox(
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let checkbox = includeCheckbox(timeout: timeout) else {
            XCTFail(
                "The Include \(stem) checkbox never showed up. \(queueRowSummary())",
                file: file,
                line: line
            )
            return
        }
        checkbox.click()
    }

    func assertIncludeCheckbox(
        enabled: Bool,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var observed = "missing"
        while Date() < deadline {
            if let checkbox = includeCheckbox(timeout: 0.2) {
                observed = "enabled=\(checkbox.isEnabled) \(describe(checkbox))"
                if checkbox.isEnabled == enabled {
                    return
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "Include \(stem) was \(observed), expected enabled \(enabled)",
            file: file,
            line: line
        )
    }

    /// Opens `Choose match for <stem>` and picks `candidateFileName`.
    /// `stem` is the file name on the button, such as `X.mka`.
    /// The menu section is `Pair <stem> with`. A miss fails with the menu items
    /// that were actually visible.
    func chooseMatch(
        _ candidateFileName: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let buttonLabel = "Choose match for \(stem)"
        let sectionTitle = "Pair \(stem) with"
        guard let button = UITestWait.firstExisting([
            app.menuButtons.matching(named(buttonLabel)).firstMatch,
            app.popUpButtons.matching(named(buttonLabel)).firstMatch,
            app.buttons.matching(named(buttonLabel)).firstMatch,
            app.groups.matching(named(buttonLabel)).firstMatch,
        ], timeout: timeout) else {
            XCTFail(
                "\(buttonLabel) never showed up. \(queueRowSummary())",
                file: file,
                line: line
            )
            return
        }
        button.click()

        let item = app.menuItems.matching(named(candidateFileName)).firstMatch
        let nested = app.menus.menuItems.matching(named(candidateFileName)).firstMatch
        let inButtonMenu = button.menus.menuItems.matching(named(candidateFileName)).firstMatch
        let inButton = button.menuItems.matching(named(candidateFileName)).firstMatch
        let deadline = Date().addingTimeInterval(UITestTimeout.standard)
        while Date() < deadline {
            if let pick = firstHit([item, nested, inButtonMenu, inButton]) {
                pick.click()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let sectionPredicate = NSPredicate(format: "label == %@ OR value == %@", sectionTitle, sectionTitle)
        let sectionVisible = UITestQuery.matching(
            sectionPredicate,
            in: app,
            types: [.staticText, .menuItem]
        ).contains { $0.exists }
        XCTFail(
            "Choose Match did not list \(candidateFileName). Section '\(sectionTitle)' visible=\(sectionVisible). Menu items: \(visibleMenuItems())",
            file: file,
            line: line
        )
    }

    /// Clicks `Unmatch <stem> from <audioFileName>`. `stem` is the video base name,
    /// such as `X Extended`. The on-screen title is `Unmatch`.
    ///
    /// Link-style buttons are `links`, not `buttons`. The accessible name is the
    /// full label, so a control titled only `Unmatch` does not match.
    func clickUnmatch(
        audioFileName: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let label = "Unmatch \(stem) from \(audioFileName)"
        guard let button = UITestWait.firstExisting(unmatchCandidates(label: label), timeout: timeout) else {
            XCTFail(
                "\(label) never showed up. \(queueRowSummary()) Unmatch controls: \(unmatchSummary())",
                file: file,
                line: line
            )
            return
        }
        button.click()
    }

    /// Exact accessible name. Identifier alone is not enough: every Unmatch
    /// button shares `unmatchButton`, and the label names the pair.
    private func unmatchCandidates(label: String) -> [XCUIElement] {
        let exact = NSPredicate(
            format: "label == %@ OR value == %@ OR title == %@",
            label, label, label
        )
        return UITestQuery.matching(exact, in: app, types: [.button, .link, .menuButton, .group])
    }

    private func unmatchSummary() -> String {
        let predicate = NSPredicate(
            format: "identifier == %@ OR label CONTAINS %@ OR title CONTAINS %@ OR value CONTAINS %@",
            "unmatchButton", "Unmatch", "Unmatch", "Unmatch"
        )
        let hits = UITestQuery.all(
            matching: predicate,
            in: app,
            types: [.button, .link, .menuButton, .group]
        )
        if hits.isEmpty {
            return "(none)"
        }
        return hits.prefix(6).map { describe($0) }.joined(separator: "; ")
    }

    private func named(_ name: String) -> NSPredicate {
        NSPredicate(format: "label == %@ OR value == %@ OR title == %@", name, name, name)
    }

    /// `Include <stem>`. Checkboxes first, then switches.
    private func includeCheckbox(timeout: TimeInterval) -> XCUIElement? {
        let name = "Include \(stem)"
        return UITestWait.firstExisting([
            app.checkBoxes.matchingLabelOrValue(equalTo: name).firstMatch,
            app.switches.matchingLabelOrValue(equalTo: name).firstMatch,
        ], timeout: timeout)
    }

    private func firstHit(_ elements: [XCUIElement]) -> XCUIElement? {
        elements.first { $0.exists }
    }

    private func visibleMenuItems() -> String {
        let items = app.menuItems.allElementsBoundByIndex.prefix(12).map { element -> String in
            let value = element.value.map { "\($0)" } ?? ""
            return "label='\(element.label)' title='\(element.title)' value='\(value)'"
        }
        if items.isEmpty {
            return "(none)"
        }
        return items.joined(separator: "; ")
    }
}
