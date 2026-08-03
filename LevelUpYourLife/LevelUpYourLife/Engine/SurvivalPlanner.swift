import Foundation

/// Survival Mode math (SCREEN 7).
///
/// When a pay cycle cannot cover its plan, the household picks strategies.
/// The planner recomputes the remaining gap live as strategies are toggled.
/// Required expenses can never be silently removed — only covered by
/// Extra Life funds or left as an explicit remaining shortfall.
enum SurvivalPlanner {

    struct Selection: Equatable, Sendable {
        /// Extra Life funds explicitly confirmed for use this cycle.
        var extraLifeAmount: Decimal = 0
        /// How much the splurge target is reduced by.
        var splurgeReduction: Decimal = 0
        /// How much the buffer contribution is reduced by.
        var bufferReduction: Decimal = 0
        /// Planned Extra Life contribution dropped ("delay goal XP / protection").
        var dropExtraLifeContribution: Bool = false
        /// Total of flexible bills delayed to a later cycle.
        var delayedFlexibleAmount: Decimal = 0

        init() {}
    }

    struct Outcome: Equatable, Sendable {
        var adjustedRequest: AllocationRequest
        var allocation: AllocationResult
        /// Gap still open against required bills after applying every strategy.
        var remainingRequiredShortfall: Decimal
        /// Gap still open against the adjusted full plan.
        var remainingPlanGap: Decimal
        /// Fraction of one Extra Life the *original* required shortfall represents.
        var livesNeededForShortfall: Decimal

        var isResolved: Bool { remainingRequiredShortfall <= 0 }
    }

    /// Applies the chosen strategies to the original request and recomputes.
    static func resolve(
        request: AllocationRequest,
        selection: Selection,
        extraLifeValue: Decimal
    ) -> Outcome {
        var adjusted = request
        adjusted.totalIncome = request.totalIncome + CurrencyMath.nonNegative(selection.extraLifeAmount)
        adjusted.splurgeTarget = CurrencyMath.nonNegative(request.splurgeTarget - selection.splurgeReduction)
        adjusted.bufferTarget = CurrencyMath.nonNegative(request.bufferTarget - selection.bufferReduction)
        adjusted.flexibleBills = CurrencyMath.nonNegative(request.flexibleBills - selection.delayedFlexibleAmount)
        if selection.dropExtraLifeContribution {
            adjusted.extraLifeTarget = 0
        }

        let allocation = FinanceEngine.allocate(adjusted)
        let originalShortfall = FinanceEngine.allocate(request).shortfall
        let livesNeeded: Decimal
        if extraLifeValue > 0 {
            livesNeeded = originalShortfall / extraLifeValue
        } else {
            livesNeeded = .zero
        }

        return Outcome(
            adjustedRequest: adjusted,
            allocation: allocation,
            remainingRequiredShortfall: allocation.shortfall,
            remainingPlanGap: allocation.planGap,
            livesNeededForShortfall: livesNeeded
        )
    }
}
