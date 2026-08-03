import SwiftUI
import SwiftData

/// Ledger of the past: cycles, draws, XP, and Extra Life movements.
struct HistoryView: View {
    enum Tab: String, CaseIterable {
        case cycles = "Cycles"
        case draws = "Draws"
        case xp = "XP"
        case lives = "Lives"
    }

    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query(sort: \AdventureDraw.createdDate, order: .reverse) private var draws: [AdventureDraw]
    @Query(sort: \XPTransaction.date, order: .reverse) private var xpTransactions: [XPTransaction]
    @Query(sort: \ExtraLifeTransaction.date, order: .reverse) private var lifeTransactions: [ExtraLifeTransaction]

    @State private var tab: Tab = .cycles

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .cycles: cyclesSection
                case .draws: drawsSection
                case .xp: xpSection
                case .lives: livesSection
                }
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("History")
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var cyclesSection: some View {
        ForEach(cycles, id: \.id) { cycle in
            JRPGPanel("\(cycle.dateRangeLabel) · \(cycle.status.displayName)") {
                VStack(spacing: 5) {
                    LedgerRow(label: "Income", amount: cycle.totalIncome)
                    LedgerRow(label: "Bills Reserved", amount: cycle.billsReserved)
                    LedgerRow(label: "Splurge", amount: cycle.splurgeReserved)
                    LedgerRow(label: "Buffer", amount: cycle.bufferReserved)
                    LedgerRow(label: "XP Generated", amount: cycle.availableXP, emphasis: true)
                }
            }
        }
        if cycles.isEmpty { emptyNote("No pay cycles yet.") }
    }

    @ViewBuilder
    private var drawsSection: some View {
        ForEach(draws, id: \.id) { draw in
            JRPGPanel("\(draw.createdDate.formatted(.dateTime.month(.abbreviated).day())) · \(draw.resultStatus.displayName)") {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(draw.allSlots, id: \.self) { slot in
                        HStack {
                            Text("\(slot.ownerLabel): \(slot.title)")
                                .font(.questBody)
                                .foregroundStyle(Color.luText)
                            Spacer()
                            if slot.cost > 0 {
                                CurrencyText(slot.cost, font: .questFootnote, color: .luTextDim)
                            } else {
                                Text("Free")
                                    .font(.questFootnote)
                                    .foregroundStyle(Color.luForest)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    LedgerRow(label: "Total", amount: draw.totalEstimatedCost, emphasis: true)
                }
            }
        }
        if draws.isEmpty { emptyNote("No adventure draws yet.") }
    }

    @ViewBuilder
    private var xpSection: some View {
        ForEach(xpTransactions, id: \.id) { txn in
            HStack(alignment: .top, spacing: 8) {
                PixelIcon(.star, size: 15)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(txn.createdBy.isEmpty ? "Someone" : txn.createdBy) → \(txn.goal?.title ?? "a goal")")
                        .font(.questBody)
                        .foregroundStyle(Color.luText)
                    Text(txn.date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.questFootnote)
                        .foregroundStyle(Color.luTextDim)
                }
                Spacer()
                Text("+\(txn.amount.xpLabel)")
                    .font(.questHeading)
                    .monospacedDigit()
                    .foregroundStyle(Color.luSuccess)
            }
            .padding(10)
            .background(Color.luPanel.opacity(0.7))
            .pixelBorder(Color.luGoldDim.opacity(0.5), lineWidth: 1)
            .accessibilityElement(children: .combine)
        }
        if xpTransactions.isEmpty { emptyNote("No XP allocations yet.") }
    }

    @ViewBuilder
    private var livesSection: some View {
        ForEach(lifeTransactions, id: \.id) { txn in
            HStack(alignment: .top, spacing: 8) {
                PixelHeart(fill: txn.amount >= 0 ? 1 : 0.35, size: 15)
                VStack(alignment: .leading, spacing: 1) {
                    Text(txn.reason.isEmpty ? txn.type.displayName : txn.reason)
                        .font(.questBody)
                        .foregroundStyle(Color.luText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(txn.date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.questFootnote)
                        .foregroundStyle(Color.luTextDim)
                }
                Spacer()
                Text(txn.amount.signedCurrencyLabel)
                    .font(.questHeading)
                    .monospacedDigit()
                    .foregroundStyle(txn.amount >= 0 ? Color.luSuccess : Color.luRed)
            }
            .padding(10)
            .background(Color.luPanel.opacity(0.7))
            .pixelBorder(Color.luGoldDim.opacity(0.5), lineWidth: 1)
            .accessibilityElement(children: .combine)
        }
        if lifeTransactions.isEmpty { emptyNote("No Extra Life activity yet.") }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.questBody)
            .foregroundStyle(Color.luTextDim)
            .padding(.top, 20)
    }
}
