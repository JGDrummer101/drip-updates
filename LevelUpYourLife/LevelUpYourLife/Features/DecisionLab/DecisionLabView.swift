import SwiftUI
import SwiftData

/// SCREEN 8: the sandbox. Pick a template, tune numbers, see before/after.
/// Nothing here can touch live data — simulations run on frozen snapshots.
struct DecisionLabView: View {
    struct Template: Identifiable {
        let id: String
        let title: String
        let icon: String
        let type: ProposalType
    }

    static let templates: [Template] = [
        Template(id: "new-expense", title: "New Recurring Expense", icon: "plus.rectangle.fill", type: .addRecurringExpense),
        Template(id: "increase", title: "Increase Recurring Expense", icon: "arrow.up.right.square.fill", type: .increaseRequiredExpense),
        Template(id: "one-time", title: "One-Time Purchase", icon: "bag.fill", type: .oneTimePurchase),
        Template(id: "car", title: "New Car Payment", icon: "car.fill", type: .addRecurringExpense),
        Template(id: "income-down", title: "Income Reduction", icon: "arrow.down.circle.fill", type: .incomeChange),
        Template(id: "income-up", title: "Income Increase", icon: "arrow.up.circle.fill", type: .incomeChange),
        Template(id: "splurge", title: "Change Splurge Budget", icon: "dice.fill", type: .splurgeChange),
        Template(id: "buffer", title: "Change Minimum Buffer", icon: "shield.fill", type: .bufferChange),
        Template(id: "extra-life", title: "Extra Life Withdrawal", icon: "heart.slash.fill", type: .extraLifeWithdrawal),
        Template(id: "goal", title: "New Savings Goal", icon: "star.fill", type: .newGoal),
    ]

    @State private var activeTemplate: Template?

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                ParchmentCard("The Lab") {
                    Text("Test any change before committing. Simulations never touch your real budget — only approved proposals do.")
                        .font(.questBody)
                        .foregroundStyle(Color.luInkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Self.templates) { template in
                    Button {
                        activeTemplate = template
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: template.icon)
                                .font(.subheadline)
                                .foregroundStyle(Color.luGold)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text(template.title)
                                .font(.questHeading)
                                .foregroundStyle(Color.luText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.luTextDim)
                                .accessibilityHidden(true)
                        }
                        .padding(12)
                        .frame(minHeight: QuestMetrics.minTapTarget)
                        .background(Color.luPanel)
                        .pixelBorder(Color.luGoldDim.opacity(0.7), lineWidth: 1)
                    }
                    .buttonStyle(QuestPressStyle())
                }
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Decision Lab")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $activeTemplate) { template in
            SimulationFormView(template: template)
        }
    }
}
