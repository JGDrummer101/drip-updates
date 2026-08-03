import Foundation

// MARK: - Shared engine value types
//
// The engine never touches SwiftData. Views and services map persisted models
// into these plain value types, run the math, and write results back. That
// keeps every rule below deterministic and unit-testable on any platform.

enum RecurrenceRule: String, Codable, CaseIterable, Sendable {
    case monthly, biweekly, weekly, annual, oneTime

    var displayName: String {
        switch self {
        case .monthly: "Monthly"
        case .biweekly: "Biweekly"
        case .weekly: "Weekly"
        case .annual: "Annual"
        case .oneTime: "One-Time"
        }
    }
}

enum FundingMethod: String, Codable, CaseIterable, Sendable {
    case dueDate, smoothed

    var displayName: String {
        switch self {
        case .dueDate: "Due Date"
        case .smoothed: "Smoothed"
        }
    }
}

/// A snapshot of one budget item, as the engine sees it.
struct BudgetItemSpec: Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    /// Amount per recurrence period (e.g. $70 per month, $600 per year).
    var amount: Decimal
    var recurrence: RecurrenceRule
    var fundingMethod: FundingMethod
    var isRequired: Bool
    var isActive: Bool
    /// Day of month the item is due (1...31, clamped to month length).
    var dueDay: Int

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        recurrence: RecurrenceRule = .monthly,
        fundingMethod: FundingMethod = .dueDate,
        isRequired: Bool = true,
        isActive: Bool = true,
        dueDay: Int = 1
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.recurrence = recurrence
        self.fundingMethod = fundingMethod
        self.isRequired = isRequired
        self.isActive = isActive
        self.dueDay = dueDay
    }
}

/// One bill's planned funding inside a specific pay cycle.
struct PlannedBillFunding: Identifiable, Hashable, Sendable {
    var id: UUID          // matches the BudgetItemSpec id
    var title: String
    var amountDue: Decimal
    var dueDate: Date?
    var isRequired: Bool
    var fundingMethod: FundingMethod
}

/// Inputs for the pay-cycle allocation waterfall.
struct AllocationRequest: Equatable, Sendable {
    var totalIncome: Decimal
    var requiredBills: Decimal
    var flexibleBills: Decimal
    var bufferTarget: Decimal
    var splurgeTarget: Decimal
    var extraLifeTarget: Decimal

    init(
        totalIncome: Decimal,
        requiredBills: Decimal,
        flexibleBills: Decimal = 0,
        bufferTarget: Decimal = 0,
        splurgeTarget: Decimal = 0,
        extraLifeTarget: Decimal = 0
    ) {
        self.totalIncome = totalIncome
        self.requiredBills = requiredBills
        self.flexibleBills = flexibleBills
        self.bufferTarget = bufferTarget
        self.splurgeTarget = splurgeTarget
        self.extraLifeTarget = extraLifeTarget
    }
}

/// Result of the allocation waterfall. Available XP can never be negative.
struct AllocationResult: Equatable, Sendable {
    var requiredReserved: Decimal
    var flexibleReserved: Decimal
    var bufferReserved: Decimal
    var splurgeReserved: Decimal
    var extraLifeReserved: Decimal
    var availableXP: Decimal
    /// How much the income fell short of *required bills alone*. > 0 means Survival Mode.
    var shortfall: Decimal
    /// How much the income fell short of the full plan (bills + buffer + splurge + extra life).
    var planGap: Decimal

    var billsReserved: Decimal { requiredReserved + flexibleReserved }
    var isShortfall: Bool { shortfall > 0 }
    var hasPlanGap: Bool { planGap > 0 }
}

// MARK: - Finance engine

enum FinanceEngine {

    /// Factor for converting a monthly amount into a biweekly pay-cycle share.
    /// 12 months of expense are spread across 26 paychecks.
    static let monthlyToPerCycleFactor: Decimal = Decimal(12) / Decimal(26)

    /// Normalizes an item's per-period amount to a monthly equivalent.
    /// One-time items carry no recurring monthly weight.
    static func monthlyEquivalent(amount: Decimal, recurrence: RecurrenceRule) -> Decimal {
        switch recurrence {
        case .monthly: amount
        case .biweekly: amount * Decimal(26) / Decimal(12)
        case .weekly: amount * Decimal(52) / Decimal(12)
        case .annual: amount / Decimal(12)
        case .oneTime: .zero
        }
    }

    /// RULE 1 input: total monthly required budget.
    /// Only items that are both required and active count.
    static func requiredMonthlyBudget(items: [BudgetItemSpec]) -> Decimal {
        let total = items
            .filter { $0.isRequired && $0.isActive }
            .reduce(Decimal.zero) { $0 + monthlyEquivalent(amount: $1.amount, recurrence: $1.recurrence) }
        return CurrencyMath.roundedToCents(total)
    }

    /// RULE 1: One Extra Life = required monthly budget rounded up to the nearest $100.
    static func extraLifeValue(requiredMonthlyBudget: Decimal) -> Decimal {
        CurrencyMath.ceilToNearest(requiredMonthlyBudget, step: 100)
    }

    /// RULE 2: Extra Life count = fund balance / value of one life.
    /// Full precision is preserved; the UI decides how many digits to show.
    static func extraLifeCount(balance: Decimal, lifeValue: Decimal) -> Decimal {
        guard lifeValue > 0, balance > 0 else { return .zero }
        return balance / lifeValue
    }

    /// Money (or XP) still needed to reach the next whole Extra Life.
    static func amountToNextLife(balance: Decimal, lifeValue: Decimal) -> Decimal {
        guard lifeValue > 0 else { return .zero }
        let count = extraLifeCount(balance: balance, lifeValue: lifeValue)
        var wholeLives = Decimal()
        var mutable = count
        NSDecimalRound(&wholeLives, &mutable, 0, .down)
        let nextTarget = (wholeLives + 1) * lifeValue
        return CurrencyMath.nonNegative(nextTarget - balance)
    }

    // MARK: Cycle funding plan (RULE 5)

    /// Builds the list of bills a specific pay cycle should fund.
    ///
    /// Due Date funding: the item is funded by the cycle whose window contains
    /// its next due date (the paycheck immediately preceding the due date).
    /// Smoothed funding: the monthly equivalent is spread across cycles in
    /// proportion to the cycle's length (documented approximation:
    /// `monthly × cycleDays × 12 / 365`).
    static func fundingPlan(
        items: [BudgetItemSpec],
        cycleStart: Date,
        cycleEnd: Date,
        calendar: Calendar
    ) -> [PlannedBillFunding] {
        let start = calendar.startOfDay(for: cycleStart)
        let end = calendar.startOfDay(for: cycleEnd)
        guard start <= end else { return [] }
        let cycleDays = (calendar.dateComponents([.day], from: start, to: end).day ?? 13) + 1

        var plan: [PlannedBillFunding] = []
        for item in items where item.isActive {
            switch item.fundingMethod {
            case .dueDate:
                if let due = nextDueDate(dueDay: item.dueDay, inWindowFrom: start, to: end, calendar: calendar) {
                    plan.append(PlannedBillFunding(
                        id: item.id,
                        title: item.title,
                        amountDue: CurrencyMath.roundedToCents(dueAmount(for: item)),
                        dueDate: due,
                        isRequired: item.isRequired,
                        fundingMethod: .dueDate
                    ))
                }
            case .smoothed:
                let monthly = monthlyEquivalent(amount: item.amount, recurrence: item.recurrence)
                guard monthly > 0 else { continue }
                let share = monthly * Decimal(cycleDays) * Decimal(12) / Decimal(365)
                plan.append(PlannedBillFunding(
                    id: item.id,
                    title: item.title,
                    amountDue: CurrencyMath.roundedToCents(share),
                    dueDate: nextDueDate(dueDay: item.dueDay, inWindowFrom: start, to: end, calendar: calendar),
                    isRequired: item.isRequired,
                    fundingMethod: .smoothed
                ))
            }
        }
        return plan.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): l == r ? lhs.title < rhs.title : l < r
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): lhs.title < rhs.title
            }
        }
    }

    /// Amount owed at a single due-date occurrence.
    /// Annual items pay their full annual amount on the due date once a year;
    /// for the prototype we treat an in-window occurrence as the payment event.
    private static func dueAmount(for item: BudgetItemSpec) -> Decimal {
        switch item.recurrence {
        case .monthly, .annual, .oneTime: item.amount
        case .biweekly: item.amount
        case .weekly: item.amount
        }
    }

    /// Finds the first calendar date with the given due day inside [start, end].
    /// Due days beyond a month's length clamp to the month's last day.
    static func nextDueDate(dueDay: Int, inWindowFrom start: Date, to end: Date, calendar: Calendar) -> Date? {
        var probe = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
        for _ in 0..<3 { // a biweekly window spans at most 2 distinct months
            if let due = date(forDay: dueDay, inMonthOf: probe, calendar: calendar),
               due >= start, due <= end {
                return due
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: probe) else { break }
            probe = next
        }
        return nil
    }

    private static func date(forDay day: Int, inMonthOf reference: Date, calendar: Calendar) -> Date? {
        guard let range = calendar.range(of: .day, in: .month, for: reference) else { return nil }
        var comps = calendar.dateComponents([.year, .month], from: reference)
        comps.day = min(max(1, day), range.count)
        return calendar.date(from: comps).map(calendar.startOfDay(for:))
    }

    // MARK: Allocation waterfall (RULE 3)

    /// Allocates income in strict priority order:
    /// A. required bills, then flexible bills planned this cycle,
    /// B. household minimum buffer,
    /// C. splurge budget,
    /// D. Extra Life contribution,
    /// E. everything left becomes Available XP (never negative).
    static func allocate(_ request: AllocationRequest) -> AllocationResult {
        var remaining = CurrencyMath.nonNegative(request.totalIncome)

        let requiredNeeded = CurrencyMath.nonNegative(request.requiredBills)
        let requiredReserved = min(remaining, requiredNeeded)
        let shortfall = CurrencyMath.nonNegative(requiredNeeded - remaining)
        remaining -= requiredReserved

        let flexibleReserved = min(remaining, CurrencyMath.nonNegative(request.flexibleBills))
        remaining -= flexibleReserved

        let bufferReserved = min(remaining, CurrencyMath.nonNegative(request.bufferTarget))
        remaining -= bufferReserved

        let splurgeReserved = min(remaining, CurrencyMath.nonNegative(request.splurgeTarget))
        remaining -= splurgeReserved

        let extraLifeReserved = min(remaining, CurrencyMath.nonNegative(request.extraLifeTarget))
        remaining -= extraLifeReserved

        let fullPlan = requiredNeeded
            + CurrencyMath.nonNegative(request.flexibleBills)
            + CurrencyMath.nonNegative(request.bufferTarget)
            + CurrencyMath.nonNegative(request.splurgeTarget)
            + CurrencyMath.nonNegative(request.extraLifeTarget)
        let planGap = CurrencyMath.nonNegative(fullPlan - CurrencyMath.nonNegative(request.totalIncome))

        return AllocationResult(
            requiredReserved: requiredReserved,
            flexibleReserved: flexibleReserved,
            bufferReserved: bufferReserved,
            splurgeReserved: splurgeReserved,
            extraLifeReserved: extraLifeReserved,
            availableXP: CurrencyMath.nonNegative(remaining),
            shortfall: shortfall,
            planGap: planGap
        )
    }
}
