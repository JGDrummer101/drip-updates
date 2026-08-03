import SwiftUI
import SwiftData

// MARK: - Shared controls

/// Stepper + editable currency field, tuned for money entry with Decimal.
struct CurrencyStepperField: View {
    var label: String
    @Binding var value: Decimal
    var step: Decimal = 25
    var maxValue: Decimal = 1_000_000

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.questBody)
                .foregroundStyle(Color.luTextDim)
                .lineLimit(2)
            Spacer(minLength: 4)
            Button {
                value = CurrencyMath.nonNegative(value - step)
            } label: {
                Image(systemName: "minus.square.fill")
                    .font(.title3)
                    .foregroundStyle(Color.luGoldDim)
            }
            .accessibilityLabel("Decrease \(label)")
            TextField("$0", value: $value, format: .currency(code: "USD").precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.questValue)
                .monospacedDigit()
                .foregroundStyle(Color.luText)
                .frame(width: 92)
                .padding(.vertical, 6)
                .background(Color.luNight)
                .pixelBorder(Color.luGoldDim.opacity(0.7), lineWidth: 1)
                .accessibilityLabel(label)
            Button {
                value = min(maxValue, value + step)
            } label: {
                Image(systemName: "plus.square.fill")
                    .font(.title3)
                    .foregroundStyle(Color.luGoldBright)
            }
            .accessibilityLabel("Increase \(label)")
        }
        .frame(minHeight: QuestMetrics.minTapTarget)
    }
}

// MARK: - Step 1: Income

struct IncomeStepView: View {
    @Bindable var draft: PayCycleDraft
    var household: Household?

    var body: some View {
        VStack(spacing: QuestMetrics.cardSpacing) {
            JRPGPanel("Cycle Dates", titleIcon: "calendar") {
                VStack(spacing: 4) {
                    DatePicker("Start", selection: $draft.startDate, displayedComponents: .date)
                    DatePicker("End", selection: $draft.endDate, displayedComponents: .date)
                    DatePicker("Paycheck Date", selection: $draft.paycheckDate, displayedComponents: .date)
                }
                .font(.questBody)
                .foregroundStyle(Color.luText)
            }

            if isThreePaycheckMonth {
                ThreePaycheckNotice()
            }

            JRPGPanel("Paychecks (Post-Tax)", titleIcon: "banknote.fill") {
                VStack(spacing: 8) {
                    CurrencyStepperField(label: draft.member1Name, value: $draft.member1Amount, step: 50)
                    CurrencyStepperField(label: draft.member2Name, value: $draft.member2Amount, step: 50)
                }
            }

            JRPGPanel("Other Income", titleIcon: "plus.circle.fill") {
                VStack(spacing: 10) {
                    ForEach($draft.otherIncome) { $entry in
                        VStack(spacing: 6) {
                            TextField("Source (e.g. Bonus)", text: $entry.title)
                                .font(.questBody)
                                .foregroundStyle(Color.luText)
                                .padding(8)
                                .background(Color.luNight)
                                .pixelBorder(Color.luGoldDim.opacity(0.5), lineWidth: 1)
                            HStack {
                                Picker("Type", selection: $entry.type) {
                                    ForEach(IncomeType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.luGoldBright)
                                Spacer()
                                CurrencyStepperField(label: "", value: $entry.amount, step: 50)
                                    .frame(maxWidth: 200)
                            }
                        }
                    }
                    if !draft.otherIncome.isEmpty {
                        Rectangle().fill(Color.luGold.opacity(0.25)).frame(height: 1)
                    }
                    SecondaryMenuButton(title: "Add Income Source", icon: "plus") {
                        draft.otherIncome.append(PayCycleDraft.OtherIncome())
                    }
                }
            }

            JRPGPanel {
                LedgerRow(label: "Total Income", amount: draft.totalIncome, emphasis: true)
            }
        }
    }

    private var isThreePaycheckMonth: Bool {
        guard let schedule = household?.paydaySchedule else { return false }
        return schedule.isThreePaycheckMonth(monthContaining: draft.paycheckDate, calendar: .current)
    }
}

// MARK: - Step 2: Required funding

struct FundingStepView: View {
    @Bindable var draft: PayCycleDraft
    var items: [BudgetItem]

    var body: some View {
        let plan = draft.fundingPlan(items: items)
        let allocation = draft.baseAllocation(items: items)
        let required = plan.filter(\.isRequired)
        let flexible = plan.filter { !$0.isRequired }

        VStack(spacing: QuestMetrics.cardSpacing) {
            JRPGPanel("Bills This Cycle", titleIcon: "list.bullet.rectangle.fill") {
                if plan.isEmpty {
                    Text("No bills fall inside this cycle window.")
                        .font(.questBody)
                        .foregroundStyle(Color.luTextDim)
                } else {
                    VStack(spacing: 8) {
                        ForEach(required) { bill in
                            billRow(bill)
                        }
                        if !flexible.isEmpty {
                            GoldSectionHeader("Flexible")
                            ForEach(flexible) { bill in
                                billRow(bill)
                            }
                        }
                    }
                }
            }

            JRPGPanel("Funding Summary", titleIcon: "shield.lefthalf.filled") {
                VStack(spacing: 6) {
                    LedgerRow(label: "Required Bills", amount: allocation.requiredReserved + allocation.shortfall)
                    LedgerRow(label: "Flexible Bills", amount: draft.allocationRequest(items: items).flexibleBills)
                    LedgerRow(label: "Buffer Contribution", amount: draft.bufferTarget)
                    Rectangle().fill(Color.luGold.opacity(0.35)).frame(height: 1)
                    if allocation.isShortfall {
                        LedgerRow(label: "Shortfall", amount: allocation.shortfall, emphasis: true, color: .luRed)
                        Text("Survival Mode will open before you confirm.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luRed)
                    } else {
                        LedgerRow(
                            label: "Left After Bills & Buffer",
                            amount: draft.totalIncome - allocation.billsReserved - draft.bufferTarget,
                            emphasis: true,
                            color: .luSuccess
                        )
                    }
                }
            }
        }
    }

    private func billRow(_ bill: PlannedBillFunding) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(bill.title)
                    .font(.questBody)
                    .foregroundStyle(Color.luText)
                HStack(spacing: 5) {
                    if let due = bill.dueDate {
                        Text("Due \(due.formatted(.dateTime.month(.abbreviated).day()))")
                    }
                    if bill.fundingMethod == .smoothed {
                        Text("· Smoothed share")
                    }
                }
                .font(.questFootnote)
                .foregroundStyle(Color.luTextDim)
            }
            Spacer()
            StatusChip(
                text: bill.isRequired ? "Required" : "Flexible",
                color: bill.isRequired ? .luRed.opacity(0.85) : .luRoyal
            )
            CurrencyText(bill.amountDue, font: .questHeading, color: .luGoldBright)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step 3: Fun & protection

struct FunProtectionStepView: View {
    @Bindable var draft: PayCycleDraft
    var items: [BudgetItem]

    var body: some View {
        let allocation = draft.baseAllocation(items: items)

        VStack(spacing: QuestMetrics.cardSpacing) {
            JRPGPanel("Adventure & Protection", titleIcon: "dice.fill") {
                VStack(spacing: 10) {
                    CurrencyStepperField(label: "Splurge Budget", value: $draft.splurgeTarget, step: 25)
                    CurrencyStepperField(label: "Extra Life Contribution", value: $draft.extraLifeTarget, step: 50)
                    CurrencyStepperField(label: "Minimum Buffer", value: $draft.bufferTarget, step: 25)
                }
            }

            JRPGPanel("Effect on XP", titleIcon: "star.fill") {
                VStack(spacing: 6) {
                    LedgerRow(label: "Available XP", amount: allocation.availableXP, emphasis: true)
                    if allocation.hasPlanGap {
                        Text("This plan overshoots your income by \(allocation.planGap.currencyLabel). Survival Mode will help you settle it.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luRed)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Every remaining dollar becomes XP you can allocate to goals.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                    }
                }
            }
        }
    }
}

// MARK: - Step 4: Review

struct ReviewStepView: View {
    @Bindable var draft: PayCycleDraft
    var items: [BudgetItem]
    var extraLifeValue: Decimal

    var body: some View {
        let allocation = draft.effectiveAllocation(items: items, extraLifeValue: extraLifeValue)

        VStack(spacing: QuestMetrics.cardSpacing) {
            JRPGPanel("Cycle Review", titleIcon: "doc.text.magnifyingglass") {
                VStack(spacing: 6) {
                    LedgerRow(label: "Total Income", amount: draft.totalIncome)
                    LedgerRow(label: "Required Expenses", amount: allocation.requiredReserved)
                    LedgerRow(label: "Flexible Expenses", amount: allocation.flexibleReserved)
                    LedgerRow(label: "Splurge Budget", amount: allocation.splurgeReserved)
                    LedgerRow(label: "Extra Life Contribution", amount: allocation.extraLifeReserved)
                    LedgerRow(label: "Buffer", amount: allocation.bufferReserved)
                    Rectangle().fill(Color.luGold.opacity(0.35)).frame(height: 1)
                    LedgerRow(label: "Available XP", amount: allocation.availableXP, emphasis: true)
                }
            }

            if draft.needsSurvival(items: items) {
                JRPGPanel {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.luRed)
                            .accessibilityHidden(true)
                        Text("This plan can't be fully funded yet. Resolve the shortfall to continue.")
                            .font(.questBody)
                            .foregroundStyle(Color.luText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Confirming saves the cycle, reserves every bill above, and unlocks your XP.")
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}
