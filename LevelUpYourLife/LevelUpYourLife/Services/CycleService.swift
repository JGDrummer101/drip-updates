import Foundation
import SwiftData

/// Write-side pay-cycle orchestration: turning a confirmed draft into
/// persisted cycles, statuses, transactions, and activity.
@MainActor
enum CycleService {

    struct ConfirmationInput {
        var startDate: Date
        var endDate: Date
        var paycheckDate: Date
        var incomeEntries: [(title: String, amount: Decimal, type: IncomeType, owner: String)]
        var allocation: AllocationResult
        var fundedBills: [PlannedBillFunding]
        var extraLifeUsed: Decimal
        var createdBy: String
    }

    /// Persists a confirmed pay cycle and every side effect that comes with it.
    @discardableResult
    static func confirm(
        _ input: ConfirmationInput,
        household: Household?,
        items: [BudgetItem],
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PayCycle {
        let totalIncome = input.incomeEntries.reduce(Decimal.zero) { $0 + $1.amount }
        let cycle = PayCycle(
            startDate: input.startDate,
            endDate: input.endDate,
            paycheckDate: input.paycheckDate,
            status: .confirmed,
            totalIncome: totalIncome,
            billsReserved: input.allocation.billsReserved,
            splurgeReserved: input.allocation.splurgeReserved,
            bufferReserved: input.allocation.bufferReserved,
            extraLifeReserved: input.allocation.extraLifeReserved,
            availableXP: input.allocation.availableXP,
            createdBy: input.createdBy,
            createdDate: now
        )
        context.insert(cycle)

        for entry in input.incomeEntries {
            let income = IncomeEntry(
                title: entry.title,
                amount: entry.amount,
                type: entry.type,
                date: input.paycheckDate,
                owner: entry.owner
            )
            income.payCycle = cycle
            context.insert(income)
        }

        applyFunding(input.fundedBills, to: items, monthOf: input.paycheckDate, calendar: calendar)

        if input.allocation.extraLifeReserved > 0 {
            context.insert(ExtraLifeTransaction(
                amount: input.allocation.extraLifeReserved,
                type: .contribution,
                date: now,
                reason: "Pay cycle contribution",
                payCycleID: cycle.id
            ))
        }

        if input.extraLifeUsed > 0 {
            context.insert(ExtraLifeTransaction(
                amount: -input.extraLifeUsed,
                type: .withdrawal,
                date: now,
                reason: "Survival Mode — covered a shortfall",
                payCycleID: cycle.id
            ))
            ActivityLog.post(
                context,
                title: "An Extra Life was used",
                subtitle: "That is exactly why you built it.",
                member: input.createdBy,
                type: .extraLifeUsed,
                date: now
            )
        }

        // Earlier cycles retire when a new one takes over.
        markPreviousCyclesCompleted(before: cycle, context: context)

        if let household {
            household.currentStreakCycles += 1
        }

        ActivityLog.post(
            context,
            title: "Pay cycle confirmed",
            subtitle: "\(cycle.dateRangeLabel) · \(input.allocation.availableXP.xpLabel) available",
            member: input.createdBy,
            type: .cycleConfirmed,
            date: now
        )

        return cycle
    }

    /// Updates (or creates) this month's status rows for every funded bill.
    private static func applyFunding(
        _ funded: [PlannedBillFunding],
        to items: [BudgetItem],
        monthOf reference: Date,
        calendar: Calendar
    ) {
        let key = BudgetItemStatus.monthKey(for: reference, calendar: calendar)
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for bill in funded {
            guard let item = byID[bill.id] else { continue }
            if let status = item.status(forMonthKey: key) {
                status.amountReserved += bill.amountDue
                if status.amountReserved >= status.amountNeeded, status.status == .needsFunding || status.status == .upcoming {
                    status.status = .funded
                }
            } else {
                let monthly = FinanceEngine.monthlyEquivalent(amount: item.amount, recurrence: item.recurrence)
                let status = BudgetItemStatus(
                    monthKey: key,
                    amountNeeded: max(monthly, bill.amountDue),
                    amountReserved: bill.amountDue,
                    status: bill.amountDue >= max(monthly, bill.amountDue) ? .funded : .needsFunding
                )
                status.item = item
                item.statuses.append(status)
            }
        }
    }

    private static func markPreviousCyclesCompleted(before cycle: PayCycle, context: ModelContext) {
        let descriptor = FetchDescriptor<PayCycle>()
        guard let all = try? context.fetch(descriptor) else { return }
        for other in all where other.id != cycle.id && other.status == .confirmed && other.startDate < cycle.startDate {
            other.status = .completed
        }
    }
}

extension Decimal {
    /// "1,310 XP" — used anywhere XP is spoken of as a quantity.
    var xpLabel: String {
        let whole = NSDecimalNumber(decimal: CurrencyMath.wholeDollarsFloor(self)).intValue
        return "\(whole.formatted(.number.grouping(.automatic))) XP"
    }
}
