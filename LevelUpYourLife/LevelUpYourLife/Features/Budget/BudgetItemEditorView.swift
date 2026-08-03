import SwiftUI
import SwiftData

/// Add/edit form for budget items. Material changes to *required* spending
/// never touch the live budget directly — they become draft proposals in the
/// Decision Lab flow, which both adventurers must approve.
struct BudgetItemEditorView: View {
    enum Mode {
        case create
        case edit(BudgetItem)
    }

    var mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query private var allItems: [BudgetItem]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var elTransactions: [ExtraLifeTransaction]

    @State private var title = ""
    @State private var amount: Decimal = 0
    @State private var category: BudgetCategory = .other
    @State private var dueDay = 1
    @State private var recurrence: RecurrenceRule = .monthly
    @State private var fundingMethod: FundingMethod = .dueDate
    @State private var isRequired = true
    @State private var isAutopay = false
    @State private var paidFromAccount = "Joint Checking"
    @State private var askProposal = false
    @State private var loaded = false

    private var household: Household? { households.first }

    private var editedItem: BudgetItem? {
        if case let .edit(item) = mode { return item }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .currency(code: "USD").precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(BudgetCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Schedule") {
                    Stepper("Due day: \(dueDay)", value: $dueDay, in: 1...31)
                    Picker("Recurrence", selection: $recurrence) {
                        ForEach(RecurrenceRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Funding method", selection: $fundingMethod) {
                        ForEach(FundingMethod.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Nature") {
                    Toggle("Required (must-have)", isOn: $isRequired)
                    Toggle("Autopay", isOn: $isAutopay)
                    TextField("Paid from account", text: $paidFromAccount)
                }
                if requiresProposal {
                    Section {
                        Label(
                            "Required-budget changes are household decisions. Saving will ask whether to submit this as a draft proposal.",
                            systemImage: "person.2.fill"
                        )
                        .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(editedItem == nil ? "New Budget Item" : "Edit Item")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.isEmpty || amount <= 0)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog(
                "Add directly as a draft proposal?",
                isPresented: $askProposal,
                titleVisibility: .visible
            ) {
                Button("Create Proposal (recommended)") { saveAsProposal() }
                Button("Apply Without Approval", role: .destructive) { saveDirectly() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This changes the required budget, which moves your Extra Life value. Proposals let both adventurers weigh in first.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func load() {
        guard !loaded, let item = editedItem else { loaded = true; return }
        loaded = true
        title = item.title
        amount = item.amount
        category = item.category
        dueDay = item.dueDay
        recurrence = item.recurrence
        fundingMethod = item.fundingMethod
        isRequired = item.isRequired
        isAutopay = item.isAutopay
        paidFromAccount = item.paidFromAccount
    }

    /// New required items, or required items whose amount grows, need approval.
    private var requiresProposal: Bool {
        if let item = editedItem {
            return isRequired && (amount > item.amount || (!item.isRequired && isRequired))
        }
        return isRequired
    }

    private func save() {
        if requiresProposal {
            askProposal = true
        } else {
            saveDirectly()
        }
    }

    private func saveDirectly() {
        if let item = editedItem {
            item.title = title
            item.amount = amount
            item.category = category
            item.dueDay = dueDay
            item.recurrence = recurrence
            item.fundingMethod = fundingMethod
            item.isRequired = isRequired
            item.isAutopay = isAutopay
            item.paidFromAccount = paidFromAccount
        } else {
            let item = BudgetItem(
                title: title,
                amount: amount,
                category: category,
                dueDay: dueDay,
                recurrence: recurrence,
                fundingMethod: fundingMethod,
                isRequired: isRequired,
                isAutopay: isAutopay,
                paidFromAccount: paidFromAccount,
                createdBy: appState.viewingMemberName(in: household)
            )
            let monthly = FinanceEngine.monthlyEquivalent(amount: amount, recurrence: recurrence)
            let status = BudgetItemStatus(
                monthKey: BudgetItemStatus.monthKey(for: .now),
                amountNeeded: monthly,
                status: isRequired ? .needsFunding : .upcoming
            )
            status.item = item
            item.statuses.append(status)
            context.insert(item)
        }
        try? context.save()
        dismiss()
    }

    private func saveAsProposal() {
        let memberName = appState.viewingMemberName(in: household)
        let baseline = FinanceService.baseline(
            items: allItems,
            extraLifeTransactions: elTransactions,
            cycles: cycles,
            household: household
        )
        let monthly = FinanceEngine.monthlyEquivalent(amount: amount, recurrence: recurrence)
        if let item = editedItem {
            ProposalService.submit(
                title: "\(title) increase",
                type: .increaseRequiredExpense,
                details: "Change \(item.title) from \(item.amount.currencyLabel) to \(amount.currencyLabel) per \(recurrence.displayName.lowercased()).",
                recurringAmount: monthly - FinanceEngine.monthlyEquivalent(amount: item.amount, recurrence: item.recurrence),
                oneTimeAmount: nil,
                effectiveDate: .now,
                submittedBy: memberName,
                baseline: baseline,
                payloadCategory: category,
                payloadIsRequired: true,
                payloadTargetID: item.id,
                context: context
            )
        } else {
            ProposalService.submit(
                title: title,
                type: .addRecurringExpense,
                details: "New required item: \(title), \(amount.currencyLabel) per \(recurrence.displayName.lowercased()), due day \(dueDay).",
                recurringAmount: monthly,
                oneTimeAmount: nil,
                effectiveDate: .now,
                submittedBy: memberName,
                baseline: baseline,
                payloadCategory: category,
                payloadIsRequired: true,
                context: context
            )
        }
        try? context.save()
        dismiss()
    }
}
