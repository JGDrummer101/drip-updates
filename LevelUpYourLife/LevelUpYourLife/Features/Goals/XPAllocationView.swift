import SwiftUI
import SwiftData

/// The XP allocation flow: split this cycle's XP across goals with live
/// totals, a suggested split, and a confirm step that commits everything.
struct XPAllocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query private var households: [Household]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query(sort: \Goal.priority) private var goals: [Goal]

    @State private var plan: XPAllocationPlan?
    @State private var commitPulse = 0

    private var household: Household? { households.first }
    private var currentCycle: PayCycle? { FinanceService.currentCycle(from: cycles) }
    private var eligibleGoals: [Goal] { goals.filter(\.acceptsXP) }
    private var available: Decimal { currentCycle?.xpRemaining ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: QuestMetrics.cardSpacing) {
                    JRPGPanel {
                        VStack(spacing: 4) {
                            Text("You have \(available.xpLabel) to allocate.")
                                .pixelText(.questHeading, color: .luGoldBright)
                                .frame(maxWidth: .infinity)
                            Text("One dollar saved is one XP earned.")
                                .font(.questFootnote)
                                .foregroundStyle(Color.luTextDim)
                        }
                    }

                    HStack(spacing: 8) {
                        SecondaryMenuButton(title: "Suggested Split", icon: "wand.and.stars") { applySuggested() }
                        SecondaryMenuButton(title: "Clear", icon: "xmark") { clear() }
                    }

                    if eligibleGoals.isEmpty {
                        EmptyStateQuestCard(
                            title: "No Open Goals",
                            message: "Add a goal first — XP needs somewhere to go.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else if let plan {
                        ForEach(eligibleGoals, id: \.id) { goal in
                            goalLine(goal: goal, plan: plan)
                        }

                        summaryPanel(plan)

                        PrimaryQuestButton(title: "Confirm Allocation", icon: "checkmark.seal.fill") {
                            commit(plan)
                        }
                        .opacity(plan.isValid && plan.totalAllocated > 0 ? 1 : 0.55)

                        Text("Unallocated XP simply waits for you — no pressure.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                    }
                }
                .padding(QuestMetrics.screenPadding)
            }
            .questScreen()
            .navigationTitle("Allocate XP")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: buildPlan)
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: commitPulse)
    }

    private func goalLine(goal: Goal, plan: XPAllocationPlan) -> some View {
        JRPGPanel {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(goal.title)
                            .font(.questHeading)
                            .foregroundStyle(Color.luText)
                        Text("\(goal.percentDisplay)% · \(goal.xpRemaining.xpLabel) to go · Priority \(goal.priority)")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                    }
                    Spacer()
                }
                CurrencyStepperField(
                    label: "Add XP",
                    value: amountBinding(goal: goal),
                    step: 50,
                    maxValue: min(goal.xpRemaining, plan.available)
                )
            }
        }
    }

    private func amountBinding(goal: Goal) -> Binding<Decimal> {
        Binding(
            get: { plan?.lines.first { $0.id == goal.id }?.amount ?? 0 },
            set: { newValue in
                guard var updated = plan else { return }
                let others = updated.totalAllocated - (updated.lines.first { $0.id == goal.id }?.amount ?? 0)
                let capped = min(newValue, min(goal.xpRemaining, updated.available - others))
                updated.setAmount(capped, forGoal: goal.id)
                plan = updated
            }
        )
    }

    private func summaryPanel(_ plan: XPAllocationPlan) -> some View {
        JRPGPanel("Summary", titleIcon: "star.fill") {
            VStack(spacing: 5) {
                ForEach(plan.lines.filter { $0.amount > 0 }) { line in
                    HStack {
                        Text(line.goalTitle)
                            .font(.questBody)
                            .foregroundStyle(Color.luText)
                        Spacer()
                        Text("+\(line.amount.xpLabel)")
                            .font(.questHeading)
                            .monospacedDigit()
                            .foregroundStyle(Color.luSuccess)
                    }
                    .accessibilityElement(children: .combine)
                }
                Rectangle().fill(Color.luGold.opacity(0.35)).frame(height: 1)
                LedgerRow(label: "Remaining XP", amount: plan.remaining, emphasis: true)
            }
        }
    }

    // MARK: Actions

    private func buildPlan() {
        guard plan == nil else { return }
        plan = XPAllocationPlan(
            available: available,
            lines: eligibleGoals.map {
                XPAllocationPlan.Line(id: $0.id, goalTitle: $0.title, amount: 0)
            }
        )
    }

    private func applySuggested() {
        plan = XPAllocationPlan.suggested(
            available: available,
            goals: eligibleGoals.map { ($0.id, $0.title, $0.priority, $0.xpRemaining) }
        )
    }

    private func clear() {
        plan = XPAllocationPlan(
            available: available,
            lines: eligibleGoals.map {
                XPAllocationPlan.Line(id: $0.id, goalTitle: $0.title, amount: 0)
            }
        )
    }

    private func commit(_ plan: XPAllocationPlan) {
        guard plan.isValid, plan.totalAllocated > 0 else { return }
        let result = XPService.commit(
            plan: plan,
            goals: eligibleGoals,
            cycle: currentCycle,
            household: household,
            memberName: appState.viewingMemberName(in: household),
            context: context
        )
        try? context.save()
        commitPulse += 1
        if let level = result.newLevel {
            appState.celebrateLevel = level
        }
        dismiss()
    }
}
