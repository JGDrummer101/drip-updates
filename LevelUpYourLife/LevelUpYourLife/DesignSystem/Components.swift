import SwiftUI

// MARK: - Pixel border

/// Layered square border with notched corner blocks — the JRPG frame.
/// Sharp corners on purpose; the "pixels" are the point.
struct PixelBorder: ViewModifier {
    var color: Color = .luGold
    var lineWidth: CGFloat = 1.5
    var cornerSize: CGFloat = 5

    func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .strokeBorder(Color.luPanelBorder, lineWidth: lineWidth + 1.5)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(color.opacity(0.85), lineWidth: lineWidth)
                    .padding(lineWidth + 1.5)
            }
            .overlay(alignment: .topLeading) { cornerBlock }
            .overlay(alignment: .topTrailing) { cornerBlock }
            .overlay(alignment: .bottomLeading) { cornerBlock }
            .overlay(alignment: .bottomTrailing) { cornerBlock }
    }

    private var cornerBlock: some View {
        Rectangle()
            .fill(color)
            .frame(width: cornerSize, height: cornerSize)
            .padding(1)
            .accessibilityHidden(true)
    }
}

extension View {
    func pixelBorder(_ color: Color = .luGold, lineWidth: CGFloat = 1.5) -> some View {
        modifier(PixelBorder(color: color, lineWidth: lineWidth))
    }
}

// MARK: - Panels and cards

/// Dark fantasy menu panel with an optional banner title.
struct JRPGPanel<Content: View>: View {
    var title: String?
    var titleIcon: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, titleIcon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.titleIcon = titleIcon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 6) {
                    if let titleIcon {
                        Image(systemName: titleIcon)
                            .font(.caption)
                            .foregroundStyle(Color.luGold)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .pixelText(.questHeading, color: .luGoldBright)
                    Spacer(minLength: 0)
                }
                .accessibilityAddTraits(.isHeader)
                Rectangle()
                    .fill(Color.luGold.opacity(0.4))
                    .frame(height: 1)
            }
            content
        }
        .padding(QuestMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.luPanelRaised, Color.luPanel],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .pixelBorder()
    }
}

/// Parchment card for values, quests, and rewards. Dark ink text inside.
struct ParchmentCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .pixelText(.questLabel, color: .luInkFaint)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .padding(QuestMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color.luInk)
        .background(
            LinearGradient(
                colors: [Color.luParchmentLight, Color.luParchment],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .pixelBorder(Color.luParchmentShadow, lineWidth: 1.5)
    }
}

// MARK: - Buttons

/// The big call-to-action: royal blue, parchment text, pixel frame.
struct PrimaryQuestButton: View {
    var title: String
    var icon: String?
    var role: Role = .royal
    var action: () -> Void

    enum Role {
        case royal, gold, danger

        var background: Color {
            switch self {
            case .royal: .luRoyal
            case .gold: .luGoldDim
            case .danger: .luRed
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .pixelText(.questHeading, color: .luParchmentLight)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: QuestMetrics.minTapTarget)
            .foregroundStyle(Color.luParchmentLight)
            .background(
                LinearGradient(
                    colors: [role.background.opacity(0.95), role.background.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .pixelBorder(Color.luGoldBright, lineWidth: 1.5)
        }
        .buttonStyle(QuestPressStyle())
    }
}

/// Quieter menu action: dark panel, gold text.
struct SecondaryMenuButton: View {
    var title: String
    var icon: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .pixelText(.questLabel, color: .luGoldBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
            .background(Color.luPanel)
            .pixelBorder(Color.luGoldDim, lineWidth: 1)
        }
        .buttonStyle(QuestPressStyle())
    }
}

struct QuestPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Small pieces

/// One stat in the quick-stats grid.
struct StatTile: View {
    var value: String
    var label: String
    var icon: String?

    var body: some View {
        VStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.luGold)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(.questValue)
                .monospacedDigit()
                .foregroundStyle(Color.luText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.questFootnote)
                .foregroundStyle(Color.luTextDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color.luPanel.opacity(0.7))
        .pixelBorder(Color.luGoldDim.opacity(0.6), lineWidth: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Text-plus-color status chip. Status is always written out, never color-only.
struct ApprovalStatusBadge: View {
    var state: ApprovalState
    var name: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .black))
                .accessibilityHidden(true)
            Text(name.map { "\($0): \(state.displayName)" } ?? state.displayName)
                .font(.questLabel)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.luParchmentLight)
        .background(color)
        .pixelBorder(color.opacity(0.5), lineWidth: 1)
    }

    private var color: Color {
        switch state {
        case .pending: .luGoldDim
        case .approved: .luSuccess
        case .declined: .luRed
        }
    }

    private var iconName: String {
        switch state {
        case .pending: "hourglass"
        case .approved: "checkmark"
        case .declined: "xmark"
        }
    }
}

/// Generic labeled status chip for funding states, cycle states, etc.
struct StatusChip: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.questLabel)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(Color.luParchmentLight)
            .background(color)
            .pixelBorder(color.opacity(0.4), lineWidth: 1)
    }
}

extension FundingStatus {
    var chipColor: Color {
        switch self {
        case .needsFunding: .luRed
        case .funded: .luSuccess
        case .paid: .luRoyal
        case .upcoming: .luGoldDim
        }
    }
}

/// Empty state framed as an open quest.
struct EmptyStateQuestCard: View {
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ParchmentCard {
            VStack(spacing: 10) {
                PixelIcon(.scroll, size: 34)
                Text(title)
                    .pixelText(.questHeading, color: .luInk)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.questBody)
                    .foregroundStyle(Color.luInkFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    SecondaryMenuButton(title: actionTitle, icon: "plus", action: action)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Standard labeled row inside panels: "Income Received .... $4,850".
struct LedgerRow: View {
    var label: String
    var amount: Decimal
    var emphasis: Bool = false
    var color: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(emphasis ? .questHeading : .questBody)
                .foregroundStyle(emphasis ? Color.luText : Color.luTextDim)
            Spacer(minLength: 8)
            CurrencyText(
                amount,
                font: emphasis ? .questValue : .questHeading,
                color: color ?? (emphasis ? .luGoldBright : .luText)
            )
        }
        .accessibilityElement(children: .combine)
    }
}
