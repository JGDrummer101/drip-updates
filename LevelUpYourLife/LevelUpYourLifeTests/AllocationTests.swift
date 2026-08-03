import Foundation
import Testing
@testable import LevelUpYourLife

@Suite("Pay cycle allocation")
struct AllocationTests {

    @Test("Surplus: the seed cycle yields $1,310 of XP")
    func seedSurplus() {
        let result = FinanceEngine.allocate(AllocationRequest(
            totalIncome: 4_850,
            requiredBills: 2_940,
            bufferTarget: 300,
            splurgeTarget: 300
        ))
        #expect(result.requiredReserved == 2_940)
        #expect(result.bufferReserved == 300)
        #expect(result.splurgeReserved == 300)
        #expect(result.availableXP == 1_310)
        #expect(!result.isShortfall)
        #expect(result.planGap == 0)
    }

    @Test("Waterfall order: buffer before splurge before Extra Life before XP")
    func waterfallOrder() {
        let result = FinanceEngine.allocate(AllocationRequest(
            totalIncome: 3_400,
            requiredBills: 2_940,
            bufferTarget: 300,
            splurgeTarget: 300,
            extraLifeTarget: 200
        ))
        #expect(result.requiredReserved == 2_940)
        #expect(result.bufferReserved == 300)
        #expect(result.splurgeReserved == 160) // partial
        #expect(result.extraLifeReserved == 0)
        #expect(result.availableXP == 0)
        #expect(!result.isShortfall)
        #expect(result.planGap == 340)
    }

    @Test("Shortfall: required bills beyond income never push XP negative")
    func shortfall() {
        let result = FinanceEngine.allocate(AllocationRequest(
            totalIncome: 2_500,
            requiredBills: 2_940,
            bufferTarget: 300,
            splurgeTarget: 300
        ))
        #expect(result.isShortfall)
        #expect(result.shortfall == 440)
        #expect(result.requiredReserved == 2_500)
        #expect(result.bufferReserved == 0)
        #expect(result.splurgeReserved == 0)
        #expect(result.availableXP == 0)
        #expect(result.availableXP >= 0)
    }

    @Test("Zero and negative income collapse safely")
    func degenerateIncome() {
        let zero = FinanceEngine.allocate(AllocationRequest(totalIncome: 0, requiredBills: 100))
        #expect(zero.shortfall == 100)
        #expect(zero.availableXP == 0)
        let negative = FinanceEngine.allocate(AllocationRequest(totalIncome: -50, requiredBills: 100))
        #expect(negative.shortfall == 100)
        #expect(negative.availableXP == 0)
    }
}

@Suite("Survival planner")
struct SurvivalPlannerTests {

    private let request = AllocationRequest(
        totalIncome: 2_500,
        requiredBills: 2_940,
        flexibleBills: 200,
        bufferTarget: 300,
        splurgeTarget: 300
    )

    @Test("Extra Life funds close a hard shortfall")
    func extraLifeCovers() {
        var selection = SurvivalPlanner.Selection()
        selection.extraLifeAmount = 440
        selection.splurgeReduction = 300
        selection.bufferReduction = 300
        selection.delayedFlexibleAmount = 200
        let outcome = SurvivalPlanner.resolve(
            request: request, selection: selection, extraLifeValue: 4_600
        )
        #expect(outcome.isResolved)
        #expect(outcome.remainingRequiredShortfall == 0)
        #expect(outcome.remainingPlanGap == 0)
        #expect(abs((outcome.livesNeededForShortfall - Decimal(string: "0.0956")!).doubleValue) < 0.001)
    }

    @Test("Reductions alone cannot fix a required-bill shortfall")
    func reductionsInsufficient() {
        var selection = SurvivalPlanner.Selection()
        selection.splurgeReduction = 300
        selection.bufferReduction = 300
        selection.delayedFlexibleAmount = 200
        let outcome = SurvivalPlanner.resolve(
            request: request, selection: selection, extraLifeValue: 4_600
        )
        #expect(!outcome.isResolved)
        #expect(outcome.remainingRequiredShortfall == 440)
    }

    @Test("A plan gap without a required shortfall resolves by trimming")
    func softGap() {
        let soft = AllocationRequest(
            totalIncome: 3_400,
            requiredBills: 2_940,
            bufferTarget: 300,
            splurgeTarget: 300
        )
        var selection = SurvivalPlanner.Selection()
        selection.splurgeReduction = 140
        let outcome = SurvivalPlanner.resolve(
            request: soft, selection: selection, extraLifeValue: 4_600
        )
        #expect(outcome.isResolved)
        #expect(outcome.remainingPlanGap == 0)
        #expect(outcome.allocation.splurgeReserved == 160)
    }

    @Test("Required expenses are never reduced by any strategy")
    func requiredUntouchable() {
        var selection = SurvivalPlanner.Selection()
        selection.splurgeReduction = 9_999
        selection.bufferReduction = 9_999
        selection.delayedFlexibleAmount = 9_999
        let outcome = SurvivalPlanner.resolve(
            request: request, selection: selection, extraLifeValue: 4_600
        )
        #expect(outcome.adjustedRequest.requiredBills == request.requiredBills)
    }
}
