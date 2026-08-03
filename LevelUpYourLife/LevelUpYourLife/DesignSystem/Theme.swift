import SwiftUI

// MARK: - Typography
//
// System fonts only, for Dynamic Type. The "pixel text" voice comes from
// monospaced design, heavy weights, wide tracking, and uppercase — not from
// a bitmap font.

extension Font {
    static let questTitle = Font.system(.title3, design: .monospaced).weight(.heavy)
    static let questHeading = Font.system(.subheadline, design: .monospaced).weight(.bold)
    static let questLabel = Font.system(.caption, design: .monospaced).weight(.bold)
    static let questValue = Font.system(.headline, design: .monospaced).weight(.heavy)
    static let questBody = Font.system(.subheadline, design: .rounded)
    static let questFootnote = Font.system(.footnote, design: .rounded)
}

/// Uppercase, tracked, monospaced — the standard "menu text" voice.
struct PixelTextStyle: ViewModifier {
    var font: Font = .questHeading
    var color: Color = .luText

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

extension View {
    func pixelText(_ font: Font = .questHeading, color: Color = .luText) -> some View {
        modifier(PixelTextStyle(font: font, color: color))
    }
}

// MARK: - App background

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.luNight, Color(hex: 0x0A0F19)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// Standard screen chrome: dark background, hidden scroll background.
    func questScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackground())
    }
}

// MARK: - Gold section header

struct GoldSectionHeader: View {
    var title: String
    var icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            dividerLine
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(Color.luGold)
                    .accessibilityHidden(true)
            }
            Text(title)
                .pixelText(.questLabel, color: .luGold)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(Color.luGold)
                .accessibilityHidden(true)
            dividerLine
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var dividerLine: some View {
        LinearGradient(
            colors: [Color.luGold.opacity(0.05), Color.luGold.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Currency text

/// Currency display with tabular digits and a clean spoken label.
struct CurrencyText: View {
    var amount: Decimal
    var font: Font
    var color: Color

    init(_ amount: Decimal, font: Font = .questValue, color: Color = .luText) {
        self.amount = amount
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(amount.currencyLabel)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .accessibilityLabel(Text(amount.formatted(.currency(code: "USD"))))
    }
}

// MARK: - Layout constants

enum QuestMetrics {
    static let cardPadding: CGFloat = 14
    static let screenPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 14
    static let minTapTarget: CGFloat = 44
}
