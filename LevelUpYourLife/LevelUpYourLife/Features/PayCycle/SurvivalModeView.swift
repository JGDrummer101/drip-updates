import SwiftUI

/// SCREEN 7: Survival Mode. Strategies recalculate the remaining gap live.
/// Required expenses can never be silently removed; Extra Life use needs an
/// explicit confirmation and both simulated approvals.
struct SurvivalModeView: View {
    @Bindable var draft: PayCycleDraft
    var items: [BudgetItem]
    var extraLifeValue: Decimal
    var extraLifeBalance: Decimal

    @State private var showExtraLifeConfirm = false

    var body: some View {
        let request = draft.allocationRequest(items: items)
        let base = FinanceEngine.allocate(request)
        let outcome = draft.survivalOutcome(items: items, extraLifeValue: extraLifeValue)
        let plan = draft.fundingPlan(items: items)
        let flexible = plan.filter { !$0.isRequired }

        VStack(spacing: QuestMetrics.cardSpacing) {
            // Header
            VStack(spacing: 8) {
                Text("Shortfall Detected")
                    .pixelText(.questTitle, color: .luParchmentLight)
                VStack(spacing: 5) {
                    LedgerRow(label: "Total Income", amount: request.totalIncome)
                    LedgerRow(label: "Planned Funding", amount: plannedTotal(request))
                    LedgerRow(label: "Gap to Close", amount: base.planGap, emphasis: true, color: .luParchmentLight)
                    if base.isShortfall {
                        Text("Required bills alone exceed income by \(base.shortfall.currencyLabel) — about \(livesText(base.shortfall)) of an Extra Life.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luParchmentLight.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(QuestMetrics.cardPadding)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color.luRed, Color.luRed.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            )
            .pixelBorder(Color.luGoldBright, lineWidth: 1.5)

            // Strategy: Extra Life funds
            JRPGPanel("Use Extra Life Funds", titleIcon: "heart.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $draft.useExtraLife) {
                        Text("Spend from the Extra Life fund")
                            .font(.questBody)
                            .foregroundStyle(Color.luText)
                    }
                    .tint(Color.luHeart)
                    .onChange(of: draft.useExtraLife) { _, isOn in
                        if isOn {
                            showExtraLifeConfirm = true
                            if draft.extraLifeAmount == 0 {
                                draft.extraLifeAmount = min(base.planGap, extraLifeBalance)
                            }
                        } else {
                            draft.extraLifeAmount = 0
                            draft.extraLifeApprovals = ApprovalPair()
                        }
                    }

                    if draft.useExtraLife {
                        CurrencyStepperField(
                            label: "Amount",
                            value: $draft.extraLifeAmount,
                            step: 50,
                            maxValue: extraLifeBalance
                        )
                        Text("Spends \(livesText(draft.extraLifeAmount)) of an Extra Life · Balance \(extraLifeBalance.currencyLabel)")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)

                        Text("Using Extra Life funds is a household decision. Both adventurers must approve:")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            approvalButton(slot: 0, name: draft.member1Name)
                            approvalButton(slot: 1, name: draft.member2Name)
                        }
                    }
                }
            }

            // Strategy: reductions
            JRPGPanel("Reduce This Cycle's Plan", titleIcon: "minus.circle.fill") {
                VStack(spacing: 10) {
                    CurrencyStepperField(
                        label: "Reduce Splurge (of \(draft.splurgeTarget.currencyLabel))",
                        value: $draft.splurgeReduction,
                        step: 25,
                        maxValue: draft.splurgeTarget
                    )
                    CurrencyStepperField(
                        label: "Reduce Buffer (of \(draft.bufferTarget.currencyLabel))",
                        value: $draft.bufferReduction,
                        step: 25,
                        maxValue: draft.bufferTarget
                    )
                    if draft.extraLifeTarget > 0 {
                        Toggle(isOn: $draft.dropExtraLifeContribution) {
                            Text("Delay this cycle's Extra Life contribution (\(draft.extraLifeTarget.currencyLabel))")
                                .font(.questBody)
                                .foregroundStyle(Color.luText)
                        }
                        .tint(Color.luGold)
                    }
                }
            }

            // Strategy: delay flexible expenses
            if !flexible.isEmpty {
                JRPGPanel("Delay Flexible Expenses", titleIcon: "clock.fill") {
                    VStack(spacing: 8) {
                        ForEach(flexible) { bill in
                            Toggle(isOn: delayBinding(for: bill.id)) {
                                HStack {
                                    Text(bill.title)
                                        .font(.questBody)
                                        .foregroundStyle(Color.luText)
                                    Spacer()
                                    CurrencyText(bill.amountDue, font: .questHeading, color: .luTextDim)
                                }
                            }
                            .tint(Color.luRoyal)
                        }
                        Text("Required expenses are never removed here.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                    }
                }
            }

            // Live outcome
            JRPGPanel("After Your Choices", titleIcon: "arrow.triangle.2.circlepath") {
                VStack(spacing: 6) {
                    LedgerRow(
                        label: "Remaining Gap",
                        amount: outcome.remainingPlanGap,
                        emphasis: true,
                        color: outcome.remainingPlanGap > 0 ? .luRed : .luSuccess
                    )
                    LedgerRow(label: "Available XP", amount: outcome.allocation.availableXP)
                    if outcome.isResolved && outcome.remainingPlanGap <= 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.luSuccess)
                                .accessibilityHidden(true)
                            Text("Plan balanced. You found a way through — together.")
                                .font(.questFootnote)
                                .foregroundStyle(Color.luSuccess)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Use Extra Life funds?",
            isPresented: $showExtraLifeConfirm,
            titleVisibility: .visible
        ) {
            Button("Yes — that's what they're for") {}
            Button("Not this time", role: .cancel) {
                draft.useExtraLife = false
            }
        } message: {
            Text("An Extra Life exists exactly for cycles like this one. Both adventurers will confirm below.")
        }
    }

    private func approvalButton(slot: Int, name: String) -> some View {
        let state = slot == 0 ? draft.extraLifeApprovals.first : draft.extraLifeApprovals.second
        return Button {
            draft.extraLifeApprovals = draft.extraLifeApprovals.recording(
                state == .approved ? .pending : .approved,
                forSlot: slot
            )
        } label: {
            HStack(spacing: 5) {
                Image(systemName: state == .approved ? "checkmark.seal.fill" : "seal")
                    .accessibilityHidden(true)
                Text("\(name) \(state == .approved ? "approved" : "approves")")
                    .font(.questLabel)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(state == .approved ? Color.luParchmentLight : Color.luGoldBright)
            .background(state == .approved ? Color.luSuccess : Color.luPanel)
            .pixelBorder(state == .approved ? Color.luForestDeep : Color.luGoldDim, lineWidth: 1)
        }
        .buttonStyle(QuestPressStyle())
    }

    private func delayBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { draft.delayedFlexibleIDs.contains(id) },
            set: { isOn in
                if isOn {
                    draft.delayedFlexibleIDs.insert(id)
                } else {
                    draft.delayedFlexibleIDs.remove(id)
                }
            }
        )
    }

    private func plannedTotal(_ request: AllocationRequest) -> Decimal {
        request.requiredBills + request.flexibleBills + request.bufferTarget
            + request.splurgeTarget + request.extraLifeTarget
    }

    private func livesText(_ amount: Decimal) -> String {
        guard extraLifeValue > 0 else { return "0" }
        let fraction = (amount / extraLifeValue).doubleValue
        return fraction.formatted(.number.precision(.fractionLength(0...2)))
    }
}
