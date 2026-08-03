import Foundation

/// SCREEN 8 engine: Decision Lab simulations.
///
/// Simulations run entirely on value-type snapshots. Nothing here can reach
/// live storage, so by construction a simulation cannot mutate real data —
/// a guarantee the unit tests still assert explicitly.
enum ImpactLevel: String, Codable, CaseIterable, Sendable {
    case low, moderate, high

    var displayName: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        }
    }
}

/// The household's financial position, frozen at simulation time.
struct FinancialBaseline: Equatable, Sendable {
    var requiredMonthlyBudget: Decimal
    var extraLifeBalance: Decimal
    var splurgePerCycle: Decimal
    var bufferPerCycle: Decimal
    var extraLifeContributionPerCycle: Decimal
    var averageIncomePerCycle: Decimal

    var extraLifeValue: Decimal {
        FinanceEngine.extraLifeValue(requiredMonthlyBudget: requiredMonthlyBudget)
    }

    var extraLifeCount: Decimal {
        FinanceEngine.extraLifeCount(balance: extraLifeBalance, lifeValue: extraLifeValue)
    }

    /// Approximate XP left per paycheck after the plan funds everything.
    /// Bills are approximated as the monthly requirement spread across 26
    /// paychecks a year — good enough for comparing before vs. after.
    var averageXPPerCycle: Decimal {
        let bills = requiredMonthlyBudget * FinanceEngine.monthlyToPerCycleFactor
        let leftover = averageIncomePerCycle - bills - splurgePerCycle - bufferPerCycle - extraLifeContributionPerCycle
        return CurrencyMath.roundedToCents(leftover)
    }
}

/// The change being tested.
enum SimulationChange: Equatable, Sendable {
    /// Add a new recurring expense (monthly equivalent).
    case addRecurringExpense(monthly: Decimal, isRequired: Bool)
    /// Increase (or decrease, negative) an existing required expense.
    case changeRequiredExpense(monthlyDelta: Decimal)
    /// One-time purchase paid out of pocket this cycle.
    case oneTimePurchase(amount: Decimal)
    /// Income change per paycheck (negative for a reduction).
    case incomeChange(perCycleDelta: Decimal)
    /// Change the splurge budget per cycle.
    case splurgeChange(perCycleDelta: Decimal)
    /// Change the minimum buffer per cycle.
    case bufferChange(perCycleDelta: Decimal)
    /// Withdraw from the Extra Life fund.
    case extraLifeWithdrawal(amount: Decimal)
    /// New savings goal with a per-cycle commitment.
    case newGoal(target: Decimal, perCycleCommitment: Decimal)
}

struct SimulationResult: Equatable, Sendable {
    var before: FinancialBaseline
    var after: FinancialBaseline

    var monthlyBudgetDelta: Decimal { after.requiredMonthlyBudget - before.requiredMonthlyBudget }
    var xpPerCycleDelta: Decimal { after.averageXPPerCycle - before.averageXPPerCycle }
    /// Recurring changes expressed as cost over a year (one-time costs pass through).
    var projectedAnnualCost: Decimal
    var oneTimeCost: Decimal
    /// Cycles of delay added to a representative goal, at the before/after XP rates.
    var projectedGoalDelayCycles: Int
    var impactLevel: ImpactLevel
}

enum DecisionSimulator {

    /// Runs a simulation against a frozen baseline. Pure function: the caller's
    /// baseline is untouched; only the returned copies differ.
    static func simulate(
        baseline: FinancialBaseline,
        change: SimulationChange,
        representativeGoalRemaining: Decimal = 4_000
    ) -> SimulationResult {
        var after = baseline
        var annualCost = Decimal.zero
        var oneTime = Decimal.zero

        switch change {
        case let .addRecurringExpense(monthly, isRequired):
            if isRequired {
                after.requiredMonthlyBudget += monthly
            }
            annualCost = monthly * 12
            if !isRequired {
                // Flexible spending still crowds out XP even if it never
                // changes the required budget.
                after.averageIncomePerCycle -= monthly * FinanceEngine.monthlyToPerCycleFactor
            }

        case let .changeRequiredExpense(delta):
            after.requiredMonthlyBudget = CurrencyMath.nonNegative(after.requiredMonthlyBudget + delta)
            annualCost = delta * 12

        case let .oneTimePurchase(amount):
            oneTime = amount

        case let .incomeChange(delta):
            after.averageIncomePerCycle += delta
            annualCost = -delta * 26

        case let .splurgeChange(delta):
            after.splurgePerCycle = CurrencyMath.nonNegative(after.splurgePerCycle + delta)
            annualCost = delta * 26

        case let .bufferChange(delta):
            after.bufferPerCycle = CurrencyMath.nonNegative(after.bufferPerCycle + delta)
            annualCost = delta * 26

        case let .extraLifeWithdrawal(amount):
            after.extraLifeBalance = CurrencyMath.nonNegative(after.extraLifeBalance - amount)
            oneTime = amount

        case let .newGoal(_, perCycleCommitment):
            // A goal commitment leaves the required budget untouched but
            // crowds out the XP that was previously free to allocate anywhere.
            annualCost = perCycleCommitment * 26
            after.averageIncomePerCycle -= perCycleCommitment
        }

        let delayCycles = goalDelayCycles(
            before: baseline.averageXPPerCycle,
            after: after.averageXPPerCycle,
            goalRemaining: representativeGoalRemaining
        )

        let level = impactLevel(baseline: baseline, after: after, oneTime: oneTime)

        return SimulationResult(
            before: baseline,
            after: after,
            projectedAnnualCost: CurrencyMath.roundedToCents(annualCost),
            oneTimeCost: oneTime,
            projectedGoalDelayCycles: delayCycles,
            impactLevel: level
        )
    }

    /// Extra pay cycles needed to finish a representative goal after the change.
    static func goalDelayCycles(before: Decimal, after: Decimal, goalRemaining: Decimal) -> Int {
        guard goalRemaining > 0 else { return 0 }
        let beforeCycles = cyclesToFinish(rate: before, remaining: goalRemaining)
        let afterCycles = cyclesToFinish(rate: after, remaining: goalRemaining)
        switch (beforeCycles, afterCycles) {
        case let (b?, a?): return max(0, a - b)
        case (_?, nil): return 26 // effectively stalled: show a year of delay
        default: return 0
        }
    }

    private static func cyclesToFinish(rate: Decimal, remaining: Decimal) -> Int? {
        guard rate > 0 else { return nil }
        var quotient = remaining / rate
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .up)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// Neutral classification of how big the change is, relative to the
    /// household's required budget and Extra Life value. Never a moral verdict.
    static func impactLevel(
        baseline: FinancialBaseline,
        after: FinancialBaseline,
        oneTime: Decimal
    ) -> ImpactLevel {
        let requiredBase = max(baseline.requiredMonthlyBudget, 1)
        let monthlyMagnitude = abs(after.requiredMonthlyBudget - baseline.requiredMonthlyBudget)
            + abs(after.splurgePerCycle - baseline.splurgePerCycle) * Decimal(26) / Decimal(12)
            + abs(after.bufferPerCycle - baseline.bufferPerCycle) * Decimal(26) / Decimal(12)
            + abs(after.averageIncomePerCycle - baseline.averageIncomePerCycle) * Decimal(26) / Decimal(12)
        let monthlyRatio = monthlyMagnitude / requiredBase

        let lifeValue = max(baseline.extraLifeValue, 1)
        // An Extra Life withdrawal shows up both as a one-time cost and as a
        // balance drop — the same dollars, so take the larger, never the sum.
        let oneTimeRatio = max(oneTime, CurrencyMath.nonNegative(baseline.extraLifeBalance - after.extraLifeBalance)) / lifeValue

        if monthlyRatio >= Decimal(string: "0.05")! || oneTimeRatio >= Decimal(string: "0.75")! {
            return .high
        }
        if monthlyRatio >= Decimal(string: "0.015")! || oneTimeRatio >= Decimal(string: "0.25")! {
            return .moderate
        }
        return .low
    }
}
