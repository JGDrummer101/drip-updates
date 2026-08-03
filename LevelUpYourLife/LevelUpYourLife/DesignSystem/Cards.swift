import SwiftUI

// MARK: - Goal progress card

struct GoalProgressCard: View {
    var goal: Goal
    var onMarkObtained: (() -> Void)?

    init(goal: Goal, onMarkObtained: (() -> Void)? = nil) {
        self.goal = goal
        self.onMarkObtained = onMarkObtained
    }

    var body: some View {
        ParchmentCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(goal.title)
                        .font(.questHeading)
                        .foregroundStyle(Color.luInk)
                    Spacer()
                    StatusChip(text: goal.status.displayName, color: statusColor)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    CurrencyText(goal.currentAmount, font: .questValue, color: .luInk)
                    Text("of")
                        .font(.questFootnote)
                        .foregroundStyle(Color.luInkFaint)
                    CurrencyText(goal.targetAmount, font: .questHeading, color: .luInkFaint)
                    Spacer()
                    Text("\(goal.percentDisplay)%")
                        .font(.questValue)
                        .monospacedDigit()
                        .foregroundStyle(Color.luForest)
                }

                XPProgressBar(
                    fraction: goal.progressFraction,
                    barColor: goal.isFunded ? .luSuccess : .luRoyal,
                    trackColor: Color.luInk.opacity(0.14),
                    height: 10
                )

                if goal.useMilestones, !goal.milestoneValues.isEmpty {
                    milestoneRow
                } else if goal.boxValue > 0, GoalMath.boxCount(target: goal.targetAmount, boxValue: goal.boxValue) <= 40 {
                    BoxGridView(
                        filled: GoalMath.boxesFilled(current: goal.currentAmount, boxValue: goal.boxValue),
                        total: GoalMath.boxCount(target: goal.targetAmount, boxValue: goal.boxValue),
                        fillColor: .luRoyal
                    )
                }

                HStack(spacing: 10) {
                    Label("Priority \(goal.priority)", systemImage: "flag.fill")
                    if goal.xpRemaining > 0 {
                        Label("\(goal.xpRemaining.xpLabel) to go", systemImage: "star")
                    }
                    if let date = goal.targetDate {
                        Label(date.formatted(.dateTime.month(.abbreviated).year()), systemImage: "calendar")
                    }
                    Spacer(minLength: 0)
                }
                .font(.questFootnote)
                .foregroundStyle(Color.luInkFaint)

                if goal.status == .funded, let onMarkObtained {
                    PrimaryQuestButton(title: "Mark as Obtained", icon: "trophy.fill", role: .gold, action: onMarkObtained)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var milestoneRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(goal.milestoneValues.enumerated()), id: \.offset) { _, value in
                    let reached = goal.currentAmount >= value
                    Text(value.compactLabel)
                        .font(.questLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(reached ? Color.luParchmentLight : Color.luInkFaint)
                        .background(reached ? Color.luForest : Color.luInk.opacity(0.08))
                        .pixelBorder(reached ? Color.luForestDeep : Color.luInk.opacity(0.2), lineWidth: 1)
                        .accessibilityLabel("\(value.currencyLabel) milestone \(reached ? "reached" : "not reached")")
                }
            }
        }
    }

    private var statusColor: Color {
        switch goal.status {
        case .active: .luRoyal
        case .funded: .luSuccess
        case .obtained: .luGoldDim
        case .paused: .luCharcoal
        case .completed: .luForest
        }
    }
}

extension Decimal {
    /// "$25K" style label for milestone chips.
    var compactLabel: String {
        let value = doubleValue
        if value >= 1_000, value.truncatingRemainder(dividingBy: 1_000) == 0 {
            return "$\(Int(value / 1_000))K"
        }
        return currencyLabel
    }
}

// MARK: - Budget item row

struct BudgetItemRow: View {
    var item: BudgetItem
    var status: BudgetItemStatus?

    var body: some View {
        JRPGPanel {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: item.category.iconName)
                        .font(.footnote)
                        .foregroundStyle(Color.luGold)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    Text(item.title)
                        .font(.questHeading)
                        .foregroundStyle(Color.luText)
                        .lineLimit(1)
                    Spacer()
                    CurrencyText(item.amount, font: .questValue, color: .luGoldBright)
                }

                HStack(spacing: 6) {
                    StatusChip(
                        text: item.isRequired ? "Required" : "Flexible",
                        color: item.isRequired ? .luRed.opacity(0.85) : .luRoyal
                    )
                    StatusChip(text: item.fundingMethod.displayName, color: .luCharcoal)
                    if item.isAutopay {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8, weight: .bold))
                                .accessibilityHidden(true)
                            Text("Autopay")
                                .font(.questLabel)
                        }
                        .foregroundStyle(Color.luTextDim)
                    }
                    Spacer()
                    if let status {
                        StatusChip(text: status.status.displayName, color: status.status.chipColor)
                    }
                }

                HStack {
                    Text("Due day \(item.dueDay) · \(item.recurrence.displayName)")
                        .font(.questFootnote)
                        .foregroundStyle(Color.luTextDim)
                    Spacer()
                    if let status, status.amountNeeded > 0 {
                        Text("\(status.amountReserved.currencyLabel) of \(status.amountNeeded.currencyLabel)")
                            .font(.questFootnote)
                            .monospacedDigit()
                            .foregroundStyle(Color.luTextDim)
                    }
                }

                if let status, status.amountNeeded > 0 {
                    XPProgressBar(
                        fraction: (status.amountReserved / status.amountNeeded).doubleValue,
                        barColor: status.status == .paid ? .luRoyalBright : .luSuccess,
                        height: 7
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Adventure reward card

struct AdventureRewardCard: View {
    var ownerLabel: String
    var title: String
    var cost: Decimal
    var revealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            Text(ownerLabel)
                .pixelText(.questLabel, color: .luGold)
            ZStack {
                if revealed {
                    VStack(spacing: 6) {
                        PixelIcon(.star, size: 22)
                        Text(title)
                            .font(.questHeading)
                            .foregroundStyle(Color.luInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if cost > 0 {
                            CurrencyText(cost, font: .questValue, color: .luForest)
                        } else {
                            Text("FREE")
                                .pixelText(.questLabel, color: .luForest)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(
                        LinearGradient(
                            colors: [Color.luParchmentLight, Color.luParchment],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                } else {
                    VStack(spacing: 6) {
                        PixelIcon(.dice, size: 26)
                        Text("?")
                            .font(.questTitle)
                            .foregroundStyle(Color.luGoldBright)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(Color.luPanelRaised)
                }
            }
            .pixelBorder(revealed ? Color.luGold : Color.luGoldDim, lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            revealed
                ? "\(ownerLabel): \(title), \(cost > 0 ? cost.currencyLabel : "free")"
                : "\(ownerLabel): unrevealed"
        )
    }
}

// MARK: - Impact comparison

struct ImpactComparisonCard: View {
    var impact: ImpactSnapshot

    var body: some View {
        ParchmentCard("Impact Preview") {
            VStack(alignment: .leading, spacing: 6) {
                comparisonRow(
                    "Monthly Required",
                    before: impact.currentMonthlyBudget.currencyLabel,
                    after: impact.proposedMonthlyBudget.currencyLabel,
                    worse: impact.proposedMonthlyBudget > impact.currentMonthlyBudget
                )
                comparisonRow(
                    "One Extra Life",
                    before: impact.currentExtraLifeValue.currencyLabel,
                    after: impact.proposedExtraLifeValue.currencyLabel,
                    worse: impact.proposedExtraLifeValue > impact.currentExtraLifeValue
                )
                comparisonRow(
                    "Extra Lives",
                    before: impact.currentExtraLifeCount.livesLabel,
                    after: impact.proposedExtraLifeCount.livesLabel,
                    worse: impact.proposedExtraLifeCount < impact.currentExtraLifeCount
                )

                Divider().overlay(Color.luInk.opacity(0.2))

                detailRow("XP per paycheck", value: impact.paycheckImpact.signedCurrencyLabel)
                if impact.projectedAnnualCost != 0 {
                    detailRow("Annual cost", value: impact.projectedAnnualCost.currencyLabel)
                }
                if impact.oneTimeCost > 0 {
                    detailRow("One-time cost", value: impact.oneTimeCost.currencyLabel)
                }
                if impact.projectedGoalDelayCycles > 0 {
                    detailRow("Goal delay", value: "≈ \(impact.projectedGoalDelayCycles) paychecks")
                }

                HStack {
                    Text("Overall Impact")
                        .font(.questHeading)
                        .foregroundStyle(Color.luInk)
                    Spacer()
                    StatusChip(text: impact.impactLevel.displayName, color: impactColor)
                }
                .padding(.top, 2)
            }
        }
    }

    private func comparisonRow(_ label: String, before: String, after: String, worse: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.questBody)
                .foregroundStyle(Color.luInkFaint)
            Spacer(minLength: 6)
            Text(before)
                .font(.questFootnote)
                .monospacedDigit()
                .foregroundStyle(Color.luInkFaint)
                .strikethrough(before != after, color: Color.luInkFaint.opacity(0.6))
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.luInkFaint)
                .accessibilityLabel("becomes")
            Text(after)
                .font(.questHeading)
                .monospacedDigit()
                .foregroundStyle(before == after ? Color.luInk : (worse ? Color.luRed : Color.luForest))
        }
        .accessibilityElement(children: .combine)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.questBody)
                .foregroundStyle(Color.luInkFaint)
            Spacer()
            Text(value)
                .font(.questHeading)
                .monospacedDigit()
                .foregroundStyle(Color.luInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var impactColor: Color {
        switch impact.impactLevel {
        case .low: .luForest
        case .moderate: .luGoldDim
        case .high: .luRed
        }
    }
}

extension Decimal {
    /// "2.1" — Extra Life counts shown to one decimal in primary UI.
    var livesLabel: String {
        ((doubleValue * 10).rounded() / 10).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "+$12.46" / "−$42.50"
    var signedCurrencyLabel: String {
        self >= 0 ? "+\(currencyLabel)" : "−\((-self).currencyLabel)"
    }
}

// MARK: - Celebration overlays

/// Restrained level-up moment: dark veil, parchment banner, both heroes.
struct LevelUpOverlay: View {
    var level: Int
    var members: [HouseholdMember]
    var dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 14) {
                PixelIcon(.star, size: 30)
                Text("Level Up")
                    .pixelText(.questTitle, color: .luInk)
                Text("Your household reached Level \(level)")
                    .font(.questBody)
                    .foregroundStyle(Color.luInkFaint)
                    .multilineTextAlignment(.center)
                PairSpriteView(members: members, pixelSize: 7)
                PrimaryQuestButton(title: "Onward", icon: "arrow.right", role: .gold, action: dismiss)
            }
            .padding(22)
            .background(
                LinearGradient(
                    colors: [Color.luParchmentLight, Color.luParchment],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .pixelBorder(Color.luGold, lineWidth: 2)
            .padding(.horizontal, 36)
            .scaleEffect(shown || reduceMotion ? 1 : 0.9)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(duration: 0.35)) {
                shown = true
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// "Cycle Ready" toast shown after confirming a pay cycle.
struct CycleReadyToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.luSuccess)
                .accessibilityHidden(true)
            Text("Cycle Ready")
                .pixelText(.questHeading, color: .luText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.luPanelRaised)
        .pixelBorder(Color.luSuccess, lineWidth: 1.5)
        .accessibilityElement(children: .combine)
    }
}
