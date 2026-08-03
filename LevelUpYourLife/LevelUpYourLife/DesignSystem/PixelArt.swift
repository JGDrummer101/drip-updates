import SwiftUI

// MARK: - Pixel grid renderer
//
// All "art" in the app is drawn from small character grids — original,
// programmatic, and copyright-free. `PixelGrid` rasterizes a grid with a
// character → color palette using Canvas, with a tiny overlap per cell so
// no hairline seams appear at fractional scales.

struct PixelGrid: View {
    var rows: [String]
    var palette: [Character: Color]

    var body: some View {
        Canvas { context, size in
            let height = rows.count
            let width = rows.map(\.count).max() ?? 0
            guard height > 0, width > 0 else { return }
            let cell = min(size.width / CGFloat(width), size.height / CGFloat(height))
            let xOffset = (size.width - cell * CGFloat(width)) / 2
            let yOffset = (size.height - cell * CGFloat(height)) / 2
            for (y, row) in rows.enumerated() {
                for (x, char) in row.enumerated() {
                    guard let color = palette[char] else { continue }
                    let rect = CGRect(
                        x: xOffset + CGFloat(x) * cell,
                        y: yOffset + CGFloat(y) * cell,
                        width: cell + 0.4,
                        height: cell + 0.4
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Pixel icons

enum PixelIconKind {
    case heart, coin, star, dice, scroll, shield
}

struct PixelIcon: View {
    var kind: PixelIconKind
    var size: CGFloat
    var color: Color?

    init(_ kind: PixelIconKind, size: CGFloat = 16, color: Color? = nil) {
        self.kind = kind
        self.size = size
        self.color = color
    }

    var body: some View {
        PixelGrid(rows: rows, palette: palette)
            .frame(width: size, height: size)
    }

    private var rows: [String] {
        switch kind {
        case .heart: PixelArt.heartRows
        case .coin: [
            ".XXXX.",
            "XSSXXX",
            "XSXXXX",
            "XXXXXX",
            "XXXXXX",
            ".XXXX.",
        ]
        case .star: [
            "...X...",
            "..XXX..",
            "XXXXXXX",
            ".XXXXX.",
            "..XXX..",
            ".X...X.",
        ]
        case .dice: [
            "XXXXXXX",
            "XPXXXPX",
            "XXXXXXX",
            "XXXPXXX",
            "XXXXXXX",
            "XPXXXPX",
            "XXXXXXX",
        ]
        case .scroll: [
            "XXXXXX..",
            "XLLLLX..",
            "XLLLLXX.",
            "XLLLLLLX",
            "XLLLLLLX",
            "XLLLLLLX",
            "XXXXXXXX",
        ]
        case .shield: [
            "XXXXXXX",
            "XLLLLLX",
            "XLLLLLX",
            "XLLLLLX",
            ".XLLLX.",
            "..XLX..",
            "...X...",
        ]
        }
    }

    private var palette: [Character: Color] {
        switch kind {
        case .heart:
            [PixelArt.fillChar: color ?? .luHeart]
        case .coin:
            ["X": color ?? .luGold, "S": .luGoldBright]
        case .star:
            ["X": color ?? .luGoldBright]
        case .dice:
            ["X": .luParchmentLight, "P": .luInk]
        case .scroll:
            ["X": .luInkFaint, "L": .luParchmentLight]
        case .shield:
            ["X": color ?? .luGold, "L": .luRoyal]
        }
    }
}

enum PixelArt {
    static let fillChar: Character = "X"

    static let heartRows: [String] = [
        ".XX.XX.",
        "XXXXXXX",
        "XXXXXXX",
        ".XXXXX.",
        "..XXX..",
        "...X...",
    ]
}

// MARK: - Hearts

/// One pixel heart with a horizontal fill fraction (0 = empty outline,
/// 1 = full). Partial hearts fill left-to-right.
struct PixelHeart: View {
    var fill: Double
    var size: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            PixelGrid(rows: PixelArt.heartRows, palette: ["X": Color.luHeart.opacity(0.22)])
            if fill > 0.01 {
                PixelGrid(rows: PixelArt.heartRows, palette: ["X": Color.luHeart])
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: size * min(1, max(0, fill)))
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// SCREEN 6 centerpiece: a row of hearts showing Extra Life count against a
/// target. Filled, partial, and empty states — and a spoken summary.
struct ExtraLifeHeartRow: View {
    var lives: Decimal
    var target: Int
    var heartSize: CGFloat = 26

    var body: some View {
        let value = lives.doubleValue
        let slots = max(target, Int(value.rounded(.up)), 1)
        HStack(spacing: 6) {
            ForEach(0..<slots, id: \.self) { index in
                PixelHeart(fill: value - Double(index), size: heartSize)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(livesText) of \(target) Extra Lives")
    }

    private var livesText: String {
        let rounded = (lives.doubleValue * 10).rounded() / 10
        return rounded.formatted(.number.precision(.fractionLength(0...1)))
    }
}

// MARK: - XP progress bar

/// Segmented gold progress bar — the "block fill" look without any images.
struct XPProgressBar: View {
    var fraction: Double
    var barColor: Color = .luGoldBright
    var trackColor: Color = Color.luNight.opacity(0.85)
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(trackColor)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [barColor, barColor.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * min(1, max(0, fraction)))
                // Block seams every 8 points.
                HStack(spacing: 7) {
                    ForEach(0..<max(1, Int(width / 8)), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.luNight.opacity(0.35))
                            .frame(width: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: height)
        .overlay {
            Rectangle().strokeBorder(Color.luPanelBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((min(1, max(0, fraction)) * 100).rounded())) percent")
    }
}

/// Goal "box grid" visualization: one square per `boxValue` dollars.
struct BoxGridView: View {
    var filled: Int
    var total: Int
    var fillColor: Color = .luRoyal
    var boxSize: CGFloat = 12

    private let columns = 10

    var body: some View {
        let shown = min(total, 40) // keep giant goals compact
        let rows = (shown + columns - 1) / columns
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < shown {
                            Rectangle()
                                .fill(index < filled ? fillColor : fillColor.opacity(0.15))
                                .frame(width: boxSize, height: boxSize)
                                .overlay {
                                    Rectangle().strokeBorder(
                                        Color.luInk.opacity(0.25), lineWidth: 0.5
                                    )
                                }
                        }
                    }
                }
            }
            if total > shown {
                Text("+\(total - shown) more boxes")
                    .font(.questFootnote)
                    .foregroundStyle(Color.luInkFaint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(total) boxes filled")
    }
}
