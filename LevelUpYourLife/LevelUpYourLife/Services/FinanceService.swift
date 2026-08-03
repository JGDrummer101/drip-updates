import Foundation
import SwiftData

/// Read-side finance helpers: snapshots of live models mapped into engine
/// value types. All mutation lives in the more specific services.
@MainActor
enum FinanceService {

    static func requiredMonthlyBudget(items: [BudgetItem]) -> Decimal {
        FinanceEngine.requiredMonthlyBudget(items: items.map(\.spec))
    }

    static func extraLifeValue(items: [BudgetItem]) -> Decimal {
        FinanceEngine.extraLifeValue(requiredMonthlyBudget: requiredMonthlyBudget(items: items))
    }

    static func extraLifeBalance(transactions: [ExtraLifeTransaction]) -> Decimal {
        transactions.reduce(.zero) { $0 + $1.amount }
    }

    static func extraLifeCount(items: [BudgetItem], transactions: [ExtraLifeTransaction]) -> Decimal {
        FinanceEngine.extraLifeCount(
            balance: extraLifeBalance(transactions: transactions),
            lifeValue: extraLifeValue(items: items)
        )
    }

    /// The cycle covering today, else the most recent confirmed one.
    static func currentCycle(from cycles: [PayCycle], now: Date = .now) -> PayCycle? {
        let confirmed = cycles
            .filter { $0.status != .draft }
            .sorted { $0.startDate > $1.startDate }
        if let covering = confirmed.first(where: { $0.startDate <= now && now <= $0.endDate.addingTimeInterval(86_399) }) {
            return covering
        }
        return confirmed.first
    }

    /// Average income across recent non-draft cycles; falls back to the most
    /// recent cycle, then to a sensible default so simulations stay useful.
    static func averageIncomePerCycle(cycles: [PayCycle]) -> Decimal {
        let recent = cycles
            .filter { $0.status != .draft && $0.totalIncome > 0 }
            .sorted { $0.startDate > $1.startDate }
            .prefix(6)
        guard !recent.isEmpty else { return 4_850 }
        let total = recent.reduce(Decimal.zero) { $0 + $1.totalIncome }
        return CurrencyMath.roundedToCents(total / Decimal(recent.count))
    }

    /// Frozen baseline for Decision Lab and proposal impact snapshots.
    static func baseline(
        items: [BudgetItem],
        extraLifeTransactions: [ExtraLifeTransaction],
        cycles: [PayCycle],
        household: Household?
    ) -> FinancialBaseline {
        FinancialBaseline(
            requiredMonthlyBudget: requiredMonthlyBudget(items: items),
            extraLifeBalance: extraLifeBalance(transactions: extraLifeTransactions),
            splurgePerCycle: household?.defaultSplurgeBudget ?? 300,
            bufferPerCycle: household?.minimumBuffer ?? 300,
            extraLifeContributionPerCycle: 0,
            averageIncomePerCycle: averageIncomePerCycle(cycles: cycles)
        )
    }

    struct QuickStats {
        var goalsCompleted: Int
        var itemsObtained: Int
        var lifetimeXP: Decimal
        var freeAdventures: Int
        var streakCycles: Int
        var totalSaved: Decimal
    }

    static func quickStats(
        household: Household?,
        goals: [Goal],
        extraLifeTransactions: [ExtraLifeTransaction]
    ) -> QuickStats {
        let done = goals.filter { $0.status == .obtained || $0.status == .completed }
        let contributions = extraLifeTransactions
            .filter { $0.amount > 0 }
            .reduce(Decimal.zero) { $0 + $1.amount }
        return QuickStats(
            goalsCompleted: done.count,
            itemsObtained: goals.filter { $0.status == .obtained }.count,
            lifetimeXP: household?.lifetimeXP ?? 0,
            freeAdventures: household?.freeAdventuresCompleted ?? 0,
            streakCycles: household?.currentStreakCycles ?? 0,
            totalSaved: (household?.lifetimeXP ?? 0) + contributions
        )
    }

    /// Bills due between now and the next paycheck — the Home "Upcoming" card.
    static func billsDueSoon(
        items: [BudgetItem],
        from now: Date,
        until nextPaycheck: Date,
        calendar: Calendar = .current
    ) -> [PlannedBillFunding] {
        FinanceEngine.fundingPlan(
            items: items.filter { $0.isActive && $0.fundingMethod == .dueDate }.map(\.spec),
            cycleStart: now,
            cycleEnd: nextPaycheck,
            calendar: calendar
        )
    }
}

/// One-line writes to the shared activity feed.
@MainActor
enum ActivityLog {
    static func post(
        _ context: ModelContext,
        title: String,
        subtitle: String = "",
        member: String = "",
        type: ActivityEventType = .general,
        date: Date = .now
    ) {
        context.insert(ActivityEvent(
            title: title,
            subtitle: subtitle,
            date: date,
            memberName: member,
            eventType: type
        ))
    }
}
