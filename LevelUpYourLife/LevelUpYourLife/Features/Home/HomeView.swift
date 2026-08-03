import SwiftUI
import SwiftData

/// SCREEN 1: the quest log at a glance.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var items: [BudgetItem]
    @Query(sort: \ExtraLifeTransaction.date, order: .reverse) private var elTransactions: [ExtraLifeTransaction]
    @Query private var goals: [Goal]
    @Query(sort: \ActivityEvent.date, order: .reverse) private var events: [ActivityEvent]
    @Query private var proposals: [FinancialProposal]

    @State private var showingPayCycleFlow = false

    private var household: Household? { households.first }
    private var currentCycle: PayCycle? { FinanceService.currentCycle(from: cycles) }

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                HomeHeaderView(household: household)

                if isThreePaycheckMonth {
                    ThreePaycheckNotice()
                }

                PrimaryQuestButton(title: "Start New Pay Cycle", icon: "plus.square.fill") {
                    showingPayCycleFlow = true
                }

                if let cycle = currentCycle {
                    CycleSummaryCard(cycle: cycle)
                }

                ExtraLivesCard(
                    balance: FinanceService.extraLifeBalance(transactions: elTransactions),
                    lifeValue: FinanceService.extraLifeValue(items: items),
                    targetLives: household?.targetExtraLives ?? 3
                )

                QuickStatsGrid(
                    stats: FinanceService.quickStats(
                        household: household,
                        goals: goals,
                        extraLifeTransactions: elTransactions
                    )
                )

                UpcomingCard(
                    household: household,
                    items: items,
                    proposals: proposals,
                    goals: goals
                )

                ActivityFeedCard(events: Array(events.prefix(6)))
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Home")
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPayCycleFlow) {
            PayCycleFlowView()
        }
    }

    /// The three-paycheck notice keys off the current cycle's paycheck month.
    private var isThreePaycheckMonth: Bool {
        guard let schedule = household?.paydaySchedule else { return false }
        let reference = currentCycle?.paycheckDate ?? .now
        return schedule.isThreePaycheckMonth(monthContaining: reference, calendar: .current)
    }
}

/// "Three-paycheck month detected." — celebratory but restrained.
struct ThreePaycheckNotice: View {
    var body: some View {
        HStack(spacing: 8) {
            PixelIcon(.coin, size: 16)
            Text("Three-paycheck month detected.")
                .font(.questHeading)
                .foregroundStyle(Color.luGoldBright)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.luForestDeep.opacity(0.6))
        .pixelBorder(Color.luGold, lineWidth: 1)
        .accessibilityElement(children: .combine)
    }
}
