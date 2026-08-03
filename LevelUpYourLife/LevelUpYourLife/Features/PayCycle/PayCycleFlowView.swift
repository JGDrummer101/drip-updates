import SwiftUI
import SwiftData

/// SCREEN 2: guided four-step pay cycle flow, with Survival Mode routing
/// in front of confirmation whenever the plan can't be fully funded.
struct PayCycleFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query private var households: [Household]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var items: [BudgetItem]
    @Query(sort: \ExtraLifeTransaction.date, order: .reverse) private var elTransactions: [ExtraLifeTransaction]

    @State private var draft: PayCycleDraft?
    @State private var step: Step = .income
    @State private var confirmPulse = 0

    enum Step: Int, CaseIterable {
        case income, funding, fun, review, survival

        var title: String {
            switch self {
            case .income: "Income"
            case .funding: "Required Funding"
            case .fun: "Fun & Protection"
            case .review: "Review"
            case .survival: "Survival Mode"
            }
        }
    }

    private var household: Household? { households.first }
    private var activeItems: [BudgetItem] { items.filter(\.isActive) }
    private var extraLifeValue: Decimal { FinanceService.extraLifeValue(items: items) }
    private var extraLifeBalance: Decimal { FinanceService.extraLifeBalance(transactions: elTransactions) }

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    VStack(spacing: 0) {
                        stepIndicator
                        ScrollView {
                            stepContent(draft: draft)
                                .padding(QuestMetrics.screenPadding)
                        }
                        controlBar(draft: draft)
                    }
                } else {
                    ProgressView()
                }
            }
            .questScreen()
            .navigationTitle(step.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled()
        .sensoryFeedback(.success, trigger: confirmPulse)
        .onAppear {
            if draft == nil {
                draft = PayCycleDraft(
                    household: household,
                    lastCycle: cycles.first { $0.status != .draft }
                )
            }
        }
    }

    @ViewBuilder
    private func stepContent(draft: PayCycleDraft) -> some View {
        switch step {
        case .income:
            IncomeStepView(draft: draft, household: household)
        case .funding:
            FundingStepView(draft: draft, items: activeItems)
        case .fun:
            FunProtectionStepView(draft: draft, items: activeItems)
        case .review:
            ReviewStepView(draft: draft, items: activeItems, extraLifeValue: extraLifeValue)
        case .survival:
            SurvivalModeView(
                draft: draft,
                items: activeItems,
                extraLifeValue: extraLifeValue,
                extraLifeBalance: extraLifeBalance
            )
        }
    }

    // MARK: Navigation chrome

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array([Step.income, .funding, .fun, .review].enumerated()), id: \.offset) { index, marker in
                Rectangle()
                    .fill(markerColor(marker))
                    .frame(width: 26, height: 5)
                    .accessibilityHidden(true)
                if index < 3 { Spacer().frame(maxWidth: 12) }
            }
            if step == .survival {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.luRed)
                    .accessibilityLabel("Survival mode")
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.luNight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(min(step.rawValue + 1, 4)) of 4: \(step.title)")
    }

    private func markerColor(_ marker: Step) -> Color {
        marker.rawValue < step.rawValue ? .luGold
            : marker == step ? .luGoldBright
            : .luCharcoal
    }

    private func controlBar(draft: PayCycleDraft) -> some View {
        HStack(spacing: 10) {
            if step != .income {
                SecondaryMenuButton(title: "Back", icon: "chevron.left") { goBack() }
                    .frame(width: 110)
            }
            switch step {
            case .income, .funding:
                PrimaryQuestButton(title: "Continue", icon: "chevron.right") { advance() }
            case .fun:
                PrimaryQuestButton(title: "Review Cycle", icon: "doc.text.magnifyingglass") { advance() }
            case .review:
                if draft.needsSurvival(items: activeItems) {
                    PrimaryQuestButton(title: "Resolve Shortfall", icon: "exclamationmark.triangle.fill", role: .danger) {
                        step = .survival
                    }
                } else {
                    PrimaryQuestButton(title: "Confirm Pay Cycle", icon: "checkmark.seal.fill") {
                        confirm(draft: draft)
                    }
                }
            case .survival:
                let outcome = draft.survivalOutcome(items: activeItems, extraLifeValue: extraLifeValue)
                PrimaryQuestButton(
                    title: outcome.isResolved ? "Confirm Pay Cycle" : "Shortfall Remains",
                    icon: outcome.isResolved ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                    role: outcome.isResolved ? .royal : .danger
                ) {
                    if outcome.isResolved && draft.extraLifeUseIsApproved {
                        confirm(draft: draft)
                    }
                }
                .opacity(outcome.isResolved && draft.extraLifeUseIsApproved ? 1 : 0.55)
            }
        }
        .padding(.horizontal, QuestMetrics.screenPadding)
        .padding(.vertical, 10)
        .background(Color.luNight)
    }

    private func advance() {
        switch step {
        case .income: step = .funding
        case .funding: step = .fun
        case .fun: step = .review
        default: break
        }
    }

    private func goBack() {
        switch step {
        case .funding: step = .income
        case .fun: step = .funding
        case .review: step = .fun
        case .survival: step = .review
        case .income: break
        }
    }

    // MARK: Confirmation

    private func confirm(draft: PayCycleDraft) {
        let survivalActive = draft.needsSurvival(items: activeItems)
        let allocation = draft.effectiveAllocation(items: activeItems, extraLifeValue: extraLifeValue)
        guard !allocation.isShortfall else { return }

        let input = CycleService.ConfirmationInput(
            startDate: draft.startDate,
            endDate: draft.endDate,
            paycheckDate: draft.paycheckDate,
            incomeEntries: draft.incomeEntries(),
            allocation: allocation,
            fundedBills: draft.fundedBills(items: activeItems),
            extraLifeUsed: survivalActive && draft.useExtraLife ? draft.extraLifeAmount : 0,
            createdBy: appState.viewingMemberName(in: household)
        )
        CycleService.confirm(input, household: household, items: activeItems, context: context)
        try? context.save()

        confirmPulse += 1
        appState.showCycleReadyToast = true
        dismiss()
    }
}
