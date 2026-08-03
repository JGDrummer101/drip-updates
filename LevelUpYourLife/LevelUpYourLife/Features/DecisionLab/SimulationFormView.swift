import SwiftUI
import SwiftData

/// One simulation: inputs on top, live before/after below, and a
/// "Save as Proposal" exit that routes into Household Decisions.
struct SimulationFormView: View {
    var template: DecisionLabView.Template

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query private var households: [Household]
    @Query private var items: [BudgetItem]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var elTransactions: [ExtraLifeTransaction]
    @Query(sort: \Goal.priority) private var goals: [Goal]

    @State private var title = ""
    @State private var monthlyAmount: Decimal = 0
    @State private var oneTimeAmount: Decimal = 0
    @State private var isRequired = true
    @State private var isDecrease = false
    @State private var effectiveDate: Date = .now
    @State private var targetItemID: UUID?
    @State private var seeded = false

    private var household: Household? { households.first }

    private var baseline: FinancialBaseline {
        FinanceService.baseline(
            items: items,
            extraLifeTransactions: elTransactions,
            cycles: cycles,
            household: household
        )
    }

    private var representativeGoalRemaining: Decimal {
        goals.first { $0.status == .active && $0.xpRemaining > 0 }?.xpRemaining ?? 4_000
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: QuestMetrics.cardSpacing) {
                    inputPanel

                    if let change = simulationChange {
                        let result = DecisionSimulator.simulate(
                            baseline: baseline,
                            change: change,
                            representativeGoalRemaining: representativeGoalRemaining
                        )
                        ImpactComparisonCard(impact: ImpactSnapshot.from(result: result))

                        PrimaryQuestButton(title: "Save as Proposal", icon: "person.2.fill") {
                            saveProposal()
                        }
                        .opacity(canSave ? 1 : 0.55)
                        Text("Saving sends this to Household Decisions for both approvals. Nothing changes until it's applied.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                            .multilineTextAlignment(.center)
                    } else {
                        ParchmentCard {
                            Text("Enter an amount above to see the impact.")
                                .font(.questBody)
                                .foregroundStyle(Color.luInkFaint)
                        }
                    }
                }
                .padding(QuestMetrics.screenPadding)
            }
            .questScreen()
            .navigationTitle(template.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: seedDefaults)
        }
        .preferredColorScheme(.dark)
    }

    private var inputPanel: some View {
        JRPGPanel("Simulation Inputs", titleIcon: "slider.horizontal.3") {
            VStack(spacing: 10) {
                TextField("Title (e.g. \(placeholderTitle))", text: $title)
                    .font(.questBody)
                    .foregroundStyle(Color.luText)
                    .padding(8)
                    .background(Color.luNight)
                    .pixelBorder(Color.luGoldDim.opacity(0.5), lineWidth: 1)

                switch template.type {
                case .addRecurringExpense:
                    CurrencyStepperField(label: "Monthly amount", value: $monthlyAmount, step: 5)
                    Toggle("Counts as required (must-have)", isOn: $isRequired)
                        .tint(Color.luRed)
                        .font(.questBody)
                        .foregroundStyle(Color.luText)

                case .increaseRequiredExpense:
                    Picker("Which expense", selection: $targetItemID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(items.filter { $0.isRequired && $0.isActive }, id: \.id) { item in
                            Text("\(item.title) (\(item.amount.currencyLabel))").tag(UUID?.some(item.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.luGoldBright)
                    CurrencyStepperField(label: "Monthly increase", value: $monthlyAmount, step: 5)

                case .oneTimePurchase, .extraLifeWithdrawal:
                    CurrencyStepperField(label: "Amount", value: $oneTimeAmount, step: 50)

                case .incomeChange:
                    Toggle("This is a reduction", isOn: $isDecrease)
                        .tint(Color.luRed)
                        .font(.questBody)
                        .foregroundStyle(Color.luText)
                    CurrencyStepperField(label: "Change per month", value: $monthlyAmount, step: 50)

                case .splurgeChange, .bufferChange:
                    Toggle("This is a reduction", isOn: $isDecrease)
                        .tint(Color.luRed)
                        .font(.questBody)
                        .foregroundStyle(Color.luText)
                    CurrencyStepperField(label: "Change per cycle", value: $monthlyAmount, step: 25)

                case .newGoal:
                    CurrencyStepperField(label: "Goal target", value: $oneTimeAmount, step: 250)
                    CurrencyStepperField(label: "XP commitment per cycle", value: $monthlyAmount, step: 25)

                case .goalWithdrawal, .pauseGoal:
                    CurrencyStepperField(label: "Amount", value: $oneTimeAmount, step: 50)
                }

                DatePicker("Effective date", selection: $effectiveDate, displayedComponents: .date)
                    .font(.questBody)
                    .foregroundStyle(Color.luText)
            }
        }
    }

    private var placeholderTitle: String {
        switch template.id {
        case "car": "New Car Insurance"
        case "extra-life": "Cover the repair"
        default: template.title
        }
    }

    private var signedMonthly: Decimal {
        isDecrease ? -monthlyAmount : monthlyAmount
    }

    private var simulationChange: SimulationChange? {
        switch template.type {
        case .addRecurringExpense:
            guard monthlyAmount > 0 else { return nil }
            return .addRecurringExpense(monthly: monthlyAmount, isRequired: isRequired)
        case .increaseRequiredExpense:
            guard monthlyAmount > 0 else { return nil }
            return .changeRequiredExpense(monthlyDelta: monthlyAmount)
        case .oneTimePurchase:
            guard oneTimeAmount > 0 else { return nil }
            return .oneTimePurchase(amount: oneTimeAmount)
        case .incomeChange:
            guard monthlyAmount > 0 else { return nil }
            return .incomeChange(perCycleDelta: signedMonthly * FinanceEngine.monthlyToPerCycleFactor)
        case .splurgeChange:
            guard monthlyAmount > 0 else { return nil }
            return .splurgeChange(perCycleDelta: signedMonthly)
        case .bufferChange:
            guard monthlyAmount > 0 else { return nil }
            return .bufferChange(perCycleDelta: signedMonthly)
        case .extraLifeWithdrawal:
            guard oneTimeAmount > 0 else { return nil }
            return .extraLifeWithdrawal(amount: oneTimeAmount)
        case .newGoal:
            guard oneTimeAmount > 0 else { return nil }
            return .newGoal(target: oneTimeAmount, perCycleCommitment: monthlyAmount)
        case .goalWithdrawal, .pauseGoal:
            return nil
        }
    }

    private var canSave: Bool {
        simulationChange != nil && !resolvedTitle.isEmpty
            && (template.type != .increaseRequiredExpense || targetItemID != nil)
    }

    private var resolvedTitle: String {
        if !title.isEmpty { return title }
        if template.type == .increaseRequiredExpense,
           let item = items.first(where: { $0.id == targetItemID }) {
            return "\(item.title) increase"
        }
        return template.id == "car" ? "" : template.title
    }

    private func seedDefaults() {
        guard !seeded else { return }
        seeded = true
        if template.id == "car" {
            title = "New Car Insurance"
            monthlyAmount = 85
        }
    }

    private func saveProposal() {
        guard canSave else { return }
        ProposalService.submit(
            title: resolvedTitle,
            type: template.type,
            details: "Simulated in the Decision Lab.",
            recurringAmount: template.type == .oneTimePurchase || template.type == .extraLifeWithdrawal
                ? nil
                : signedMonthly,
            oneTimeAmount: oneTimeAmount > 0 ? oneTimeAmount : nil,
            effectiveDate: effectiveDate,
            submittedBy: appState.viewingMemberName(in: household),
            baseline: baseline,
            payloadCategory: template.id == "car" ? .insurance : .other,
            payloadIsRequired: isRequired,
            payloadTargetID: targetItemID,
            context: context
        )
        try? context.save()
        dismiss()
    }
}
