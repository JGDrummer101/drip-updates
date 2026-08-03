import SwiftUI
import SwiftData

/// SCREEN 6: the Extra Lives fund — hearts, milestones, history, and
/// supportive withdrawals.
struct ExtraLivesView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query private var items: [BudgetItem]
    @Query(sort: \ExtraLifeTransaction.date, order: .reverse) private var transactions: [ExtraLifeTransaction]

    @State private var addingContribution = false
    @State private var recordingWithdrawal = false
    @State private var pulse = 0

    private var household: Household? { households.first }
    private var requiredMonthly: Decimal { FinanceService.requiredMonthlyBudget(items: items) }
    private var lifeValue: Decimal { FinanceEngine.extraLifeValue(requiredMonthlyBudget: requiredMonthly) }
    private var balance: Decimal { FinanceService.extraLifeBalance(transactions: transactions) }
    private var lives: Decimal { FinanceEngine.extraLifeCount(balance: balance, lifeValue: lifeValue) }

    private static let milestones: [(Int, String)] = [
        (1, "One difficult month covered"),
        (2, "Short-term disruption protection"),
        (3, "Strong household resilience"),
        (6, "Extended runway"),
        (12, "Long-term resilience"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                JRPGPanel {
                    VStack(spacing: 10) {
                        ExtraLifeHeartRow(
                            lives: lives,
                            target: household?.targetExtraLives ?? 3,
                            heartSize: 30
                        )
                        Text("\(lives.livesLabel) Lives")
                            .font(.questTitle)
                            .monospacedDigit()
                            .foregroundStyle(Color.luText)
                        VStack(spacing: 5) {
                            LedgerRow(label: "Fund Balance", amount: balance, emphasis: true)
                            LedgerRow(label: "Required Monthly Budget", amount: requiredMonthly)
                            LedgerRow(label: "One Extra Life (rounded up)", amount: lifeValue)
                        }
                        XPProgressBar(fraction: progressToNext, barColor: .luHeart, height: 9)
                        Text("\(FinanceEngine.amountToNextLife(balance: balance, lifeValue: lifeValue).currencyLabel) more restores the next life")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                            .monospacedDigit()
                    }
                }

                HStack(spacing: 8) {
                    PrimaryQuestButton(title: "Add Contribution", icon: "plus.circle.fill") {
                        addingContribution = true
                    }
                    SecondaryMenuButton(title: "Record Withdrawal", icon: "minus.circle") {
                        recordingWithdrawal = true
                    }
                }

                targetPanel

                JRPGPanel("Milestones", titleIcon: "flag.fill") {
                    VStack(spacing: 8) {
                        ForEach(Self.milestones, id: \.0) { milestone in
                            HStack(spacing: 8) {
                                PixelHeart(fill: lives.doubleValue >= Double(milestone.0) ? 1 : 0, size: 16)
                                Text("\(milestone.0) \(milestone.0 == 1 ? "Life" : "Lives")")
                                    .font(.questHeading)
                                    .monospacedDigit()
                                    .foregroundStyle(
                                        lives.doubleValue >= Double(milestone.0) ? Color.luGoldBright : Color.luTextDim
                                    )
                                    .frame(width: 76, alignment: .leading)
                                Text(milestone.1)
                                    .font(.questFootnote)
                                    .foregroundStyle(Color.luTextDim)
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Text("Motivational labels, not financial advice. Rename the journey however you like.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim.opacity(0.8))
                    }
                }

                JRPGPanel("History", titleIcon: "clock.fill") {
                    if transactions.isEmpty {
                        Text("No transactions yet.")
                            .font(.questBody)
                            .foregroundStyle(Color.luTextDim)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(transactions, id: \.id) { txn in
                                HStack(alignment: .top, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(txn.reason.isEmpty ? txn.type.displayName : txn.reason)
                                            .font(.questBody)
                                            .foregroundStyle(Color.luText)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(txn.date.formatted(.dateTime.month(.abbreviated).year()))
                                            .font(.questFootnote)
                                            .foregroundStyle(Color.luTextDim)
                                    }
                                    Spacer()
                                    Text(txn.amount.signedCurrencyLabel)
                                        .font(.questHeading)
                                        .monospacedDigit()
                                        .foregroundStyle(txn.amount >= 0 ? Color.luSuccess : Color.luRed)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Extra Lives")
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $addingContribution) {
            ExtraLifeTransactionSheet(kind: .contribution)
        }
        .sheet(isPresented: $recordingWithdrawal) {
            ExtraLifeTransactionSheet(kind: .withdrawal)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pulse)
    }

    private var progressToNext: Double {
        let value = lives.doubleValue
        return value - value.rounded(.down)
    }

    private var targetPanel: some View {
        JRPGPanel("Target", titleIcon: "target") {
            HStack {
                Text("Aim for")
                    .font(.questBody)
                    .foregroundStyle(Color.luTextDim)
                Spacer()
                Stepper(
                    "\(household?.targetExtraLives ?? 3) lives",
                    value: Binding(
                        get: { household?.targetExtraLives ?? 3 },
                        set: { household?.targetExtraLives = max(1, min(12, $0)); try? context.save() }
                    ),
                    in: 1...12
                )
                .font(.questHeading)
                .foregroundStyle(Color.luText)
                .fixedSize()
            }
        }
    }
}

/// Contribution / withdrawal entry with the right emotional register.
struct ExtraLifeTransactionSheet: View {
    var kind: ExtraLifeTransactionType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]

    @State private var amount: Decimal = 0
    @State private var reason = ""
    @State private var confirmWithdrawal = false

    var body: some View {
        NavigationStack {
            Form {
                Section(kind == .contribution ? "Add to the fund" : "Use the fund") {
                    TextField("Amount", value: $amount, format: .currency(code: "USD").precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                    TextField("Reason", text: $reason)
                }
                if kind == .withdrawal {
                    Section {
                        Label(
                            "An Extra Life exists for exactly this. Using one is the plan working — not the plan failing.",
                            systemImage: "heart.fill"
                        )
                        .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(kind == .contribution ? "Add Contribution" : "Record Withdrawal")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if kind == .withdrawal {
                            confirmWithdrawal = true
                        } else {
                            save()
                        }
                    }
                    .disabled(amount <= 0)
                }
            }
            .confirmationDialog(
                "Use Extra Life funds?",
                isPresented: $confirmWithdrawal,
                titleVisibility: .visible
            ) {
                Button("Yes, record the withdrawal") { save() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("That is exactly why you built it.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let signed = kind == .withdrawal ? -amount : amount
        context.insert(ExtraLifeTransaction(amount: signed, type: kind, reason: reason))
        let member = appState.viewingMemberName(in: households.first)
        if kind == .withdrawal {
            ActivityLog.post(
                context,
                title: "An Extra Life was used",
                subtitle: "That is exactly why you built it.",
                member: member,
                type: .extraLifeUsed
            )
        } else {
            ActivityLog.post(
                context,
                title: "\(amount.currencyLabel) added to Extra Lives",
                subtitle: reason,
                member: member,
                type: .extraLifeContribution
            )
        }
        try? context.save()
        dismiss()
    }
}
