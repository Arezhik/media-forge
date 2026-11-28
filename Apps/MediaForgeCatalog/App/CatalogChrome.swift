import AppKit
import MediaForgeCatalogCore
import SwiftUI

struct ResultLine: Identifiable, Equatable {
    let id = UUID()
    let date = Date()
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var timeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

extension ProductApp {
    var color: Color {
        let hex = accentHex
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return .accentColor }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

struct WrappingHStack: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 640
        let rows = rows(in: width, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY
        var index = 0
        for row in rows {
            var x = bounds.minX
            for _ in row.indexes {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indexes: [Int]
        var height: CGFloat
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var current = Row(indexes: [], height: 0)
        var x: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                result.append(current)
                current = Row(indexes: [], height: 0)
                x = 0
            }
            current.indexes.append(index)
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.indexes.isEmpty { result.append(current) }
        return result
    }
}

struct AppChip: View {
    let app: ProductApp
    var height: CGFloat = 18

    var body: some View {
        Text(app.rawValue)
            .font(.system(size: max(height - 7, 9), weight: .semibold))
            .foregroundStyle(app.color)
            .padding(.horizontal, 7)
            .frame(height: height)
            .background(Capsule().fill(app.color.opacity(0.16)))
            .overlay(Capsule().stroke(app.color.opacity(0.7), lineWidth: 1))
            .accessibilityLabel(app.rawValue)
    }
}

struct NoneChip: View {
    let text: String
    var height: CGFloat = 18

    var body: some View {
        Text(text)
            .italic()
            .font(.system(size: max(height - 7, 9)))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .frame(height: height)
            .overlay(
                Capsule().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .foregroundStyle(.secondary)
            )
    }
}

struct AdoptionChips: View {
    let adoption: Adoption
    var height: CGFloat = 18

    var body: some View {
        switch adoption {
        case .apps(let apps):
            HStack(spacing: 4) {
                ForEach(apps) { app in
                    AppChip(app: app, height: height)
                }
            }
        case .none(let text):
            NoneChip(text: text, height: height)
        }
    }
}

struct APIChips: View {
    let names: [String]

    var body: some View {
        WrappingHStack(spacing: 6) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
        }
    }
}

struct DemoHeader: View {
    let page: CatalogPage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(page.title)
                    .font(page.monospaceTitle ? .system(.largeTitle, design: .monospaced) : .largeTitle)
                    .accessibilityIdentifier("detailTitle")
                Text(page.badge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }
            Text(page.purpose)
                .foregroundStyle(.secondary)
            APIChips(names: page.apiMembers)
            HStack(alignment: .center, spacing: 8) {
                Text("Used in")
                    .font(.subheadline.weight(.semibold))
                AdoptionChips(adoption: page.usedIn)
            }
            .accessibilityIdentifier("usedInRow")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StateTileGrid<Well: View>: View {
    let pageID: PageID
    let tiles: [StateTileSpec]
    let liveID: String
    var tileScheme: ColorScheme
    @ViewBuilder var well: (StateTileSpec) -> Well

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(tiles) { tile in
                tileCard(tile)
            }
        }
        .environment(\.colorScheme, tileScheme)
        .accessibilityIdentifier("stateTiles")
    }

    private func tileCard(_ tile: StateTileSpec) -> some View {
        let isLive = tile.id == liveID
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
                well(tile)
                    .padding(8)
            }
            .frame(height: 116)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            Text(tile.title)
                .font(.headline)
                .lineLimit(2)
            Text(tile.call)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(tile.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let chips = tile.chips {
                AdoptionChips(adoption: chips, height: 15)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isLive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .accessibilityIdentifier("tile.\(pageID.rawValue).\(tile.id)")
        .accessibilityLabel(isLive ? "\(tile.title), current" : tile.title)
    }
}

struct ResultsPane: View {
    @Binding var lines: [ResultLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Results")
                    .font(.headline)
                Spacer()
                Button("Clear") { lines = [] }
                    .disabled(lines.isEmpty)
            }
            if lines.isEmpty {
                Text("Calls and outcomes show up here. Newest first.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(lines) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(line.timeText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(line.text)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
        .accessibilityIdentifier("results")
    }
}

func appendResult(_ lines: Binding<[ResultLine]>, _ text: String) {
    var copy = lines.wrappedValue
    copy.insert(ResultLine(text), at: 0)
    lines.wrappedValue = copy
}
