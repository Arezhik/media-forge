import AppKit
import MediaForgeCatalogCore
import SwiftUI

struct ReferencePageView: View {
    let page: CatalogPage
    var onOpen: (PageID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoHeader(page: page)
                typesTable
                if !page.extensions.isEmpty {
                    extensionsBlock
                }
                diagram
                if !page.related.isEmpty {
                    related
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var typesTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Types")
                .font(.title3)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    header("Type")
                    header("Role")
                    header("Builds on")
                    header("Used in")
                }
                ForEach(page.types) { row in
                    GridRow {
                        Text(row.type)
                            .font(.system(.body, design: .monospaced))
                        Text(row.role)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 180, alignment: .leading)
                        Text(row.buildsOn)
                            .font(.system(.body, design: .monospaced))
                        AdoptionChips(adoption: row.usedIn)
                    }
                }
            }
        }
        .accessibilityIdentifier("typesTable")
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var extensionsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extensions")
                .font(.title3)
            Text("XCUIElement and XCUIApplication in XCUIElement+UITest.swift")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(page.extensions) { member in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(member.name)
                            .font(.system(.callout, design: .monospaced))
                        AdoptionChips(adoption: member.usedIn, height: 15)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
                }
            }
        }
        .accessibilityIdentifier("extensionsBlock")
    }

    private var diagram: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where \(page.title) sits")
                .font(.title3)
            HStack(spacing: 8) {
                ForEach(Array(DiagramColumn.allCases.enumerated()), id: \.element) { index, column in
                    let highlighted = page.diagramHighlight == column
                    Text(column.rawValue)
                        .font(.callout.weight(highlighted ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(highlighted ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: highlighted ? 2 : 1)
                        )
                    if index < DiagramColumn.allCases.count - 1 {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            Text(diagramCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("whereDiagram")
    }

    private var diagramCaption: String {
        if let highlight = page.diagramHighlight {
            let names = page.types.map(\.type).joined(separator: ", ")
            return "\(names) sit with \(highlight.rawValue)."
        }
        return "UITestFixtureBuilder feeds the test before launch. It is not a box in this chain."
    }

    private var related: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related")
                .font(.title3)
            WrappingHStack {
                ForEach(page.related) { link in
                    Button(link.title) { onOpen(link.page) }
                }
            }
        }
    }
}
