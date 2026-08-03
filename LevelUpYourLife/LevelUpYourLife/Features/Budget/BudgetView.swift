import SwiftUI
import SwiftData

/// SCREEN 3: the monthly budget, grouped by funding status.
struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query(sort: \BudgetItem.dueDay) private var items: [BudgetItem]

    @State private var selectedStatus: FundingStatus = .needsFunding
    @State private var editingItem: BudgetItem?
    @State private var addingItem = false
    @State private var paidPulse = 0

    private var household: Household? { households.first }
    private var monthKey: String { BudgetItemStatus.monthKey(for: .now) }
    private var visibleItems: [BudgetItem] { items.filter { $0.isActive } }

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                summaryPanel

                Picker("Status", selection: $selectedStatus) {
                    ForEach(FundingStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                let filtered = itemsWithStatus(selectedStatus)
                if filtered.isEmpty {
                    EmptyStateQuestCard(
                        title: "Nothing \(selectedStatus.displayName)",
                        message: emptyMessage,
                        actionTitle: "Add Budget Item",
                        action: { addingItem = true }
                    )
                } else {
                    ForEach(filtered, id: \.id) { item in
                        BudgetItemRow(item: item, status: item.status(forMonthKey: monthKey))
                            .onTapGesture { editingItem = item }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editingItem = item }
                                if let status = item.status(forMonthKey: monthKey), status.status != .paid {
                                    Button("Mark Paid", systemImage: "checkmark.circle") { markPaid(item) }
                                }
                                Button("Pause", systemImage: "pause.circle") { pause(item) }
                                Button("Archive", systemImage: "archivebox", role: .destructive) { archive(item) }
                            }
                            .accessibilityHint("Double tap to edit. \(item.title).")
                    }
                }

                pausedSection
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Budget")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Item", systemImage: "plus") { addingItem = true }
            }
        }
        .sheet(item: $editingItem) { item in
            BudgetItemEditorView(mode: .edit(item))
        }
        .sheet(isPresented: $addingItem) {
            BudgetItemEditorView(mode: .create)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: paidPulse)
    }

    private var summaryPanel: some View {
        let requiredMonthly = FinanceService.requiredMonthlyBudget(items: items)
        let statuses = visibleItems.compactMap { $0.status(forMonthKey: monthKey) }
        let funded = statuses.reduce(Decimal.zero) { $0 + max($1.amountReserved, $1.amountPaid) }
        let needed = statuses.reduce(Decimal.zero) { $0 + $1.amountNeeded }
        return JRPGPanel("This Month", titleIcon: "shield.lefthalf.filled") {
            VStack(spacing: 6) {
                LedgerRow(label: "Required Monthly Budget", amount: requiredMonthly)
                LedgerRow(label: "Funded This Month", amount: funded, color: .luSuccess)
                LedgerRow(label: "Remaining This Month", amount: CurrencyMath.nonNegative(needed - funded))
                Rectangle().fill(Color.luGold.opacity(0.35)).frame(height: 1)
                LedgerRow(
                    label: "One Extra Life",
                    amount: FinanceEngine.extraLifeValue(requiredMonthlyBudget: requiredMonthly),
                    emphasis: true
                )
            }
        }
    }

    @ViewBuilder
    private var pausedSection: some View {
        let paused = items.filter { !$0.isActive }
        if !paused.isEmpty {
            GoldSectionHeader("Paused & Archived", icon: "pause.circle")
            ForEach(paused, id: \.id) { item in
                HStack {
                    Text(item.title)
                        .font(.questBody)
                        .foregroundStyle(Color.luTextDim)
                    Spacer()
                    CurrencyText(item.amount, font: .questHeading, color: .luTextDim)
                    Button("Resume") { item.isActive = true; try? context.save() }
                        .font(.questLabel)
                        .foregroundStyle(Color.luGoldBright)
                }
                .padding(10)
                .background(Color.luPanel.opacity(0.5))
                .pixelBorder(Color.luCharcoal, lineWidth: 1)
            }
        }
    }

    private func itemsWithStatus(_ status: FundingStatus) -> [BudgetItem] {
        visibleItems.filter { item in
            (item.status(forMonthKey: monthKey)?.status ?? .upcoming) == status
        }
    }

    private var emptyMessage: String {
        switch selectedStatus {
        case .needsFunding: "Every bill in this section is covered. A quiet victory."
        case .funded: "Nothing funded yet this month. Confirm a pay cycle to reserve bills."
        case .paid: "No bills marked paid yet this month."
        case .upcoming: "No upcoming bills for the rest of this month."
        }
    }

    private func markPaid(_ item: BudgetItem) {
        let status = ensureStatus(for: item)
        status.amountPaid = max(status.amountNeeded, status.amountReserved)
        status.status = .paid
        ActivityLog.post(
            context,
            title: "\(item.title) paid",
            subtitle: item.amount.currencyLabel,
            member: appState.viewingMemberName(in: household),
            type: .general
        )
        paidPulse += 1
        try? context.save()
    }

    private func pause(_ item: BudgetItem) {
        item.isActive = false
        try? context.save()
    }

    private func archive(_ item: BudgetItem) {
        item.isActive = false
        item.statuses.removeAll()
        try? context.save()
    }

    private func ensureStatus(for item: BudgetItem) -> BudgetItemStatus {
        if let status = item.status(forMonthKey: monthKey) { return status }
        let monthly = FinanceEngine.monthlyEquivalent(amount: item.amount, recurrence: item.recurrence)
        let status = BudgetItemStatus(monthKey: monthKey, amountNeeded: monthly)
        status.item = item
        item.statuses.append(status)
        context.insert(status)
        return status
    }
}
