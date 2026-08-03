import Foundation
import Testing
@testable import LevelUpYourLife

@Suite("Decision Lab simulator")
struct DecisionSimulatorTests {

    private var baseline: FinancialBaseline {
        FinancialBaseline(
            requiredMonthlyBudget: 4_700,
            extraLifeBalance: 9_600,
            splurgePerCycle: 300,
            bufferPerCycle: 300,
            extraLifeContributionPerCycle: 0,
            averageIncomePerCycle: 4_850
        )
    }

    @Test("The spec's car-insurance example: +$85/month moves the Extra Life boundary")
    func carInsurance() {
        let result = DecisionSimulator.simulate(
            baseline: baseline,
            change: .addRecurringExpense(monthly: 85, isRequired: true)
        )
        #expect(result.before.requiredMonthlyBudget == 4_700)
        #expect(result.after.requiredMonthlyBudget == 4_785)
        #expect(result.before.extraLifeValue == 4_700)
        #expect(result.after.extraLifeValue == 4_800)
        #expect(result.after.extraLifeCount < result.before.extraLifeCount)
        #expect(result.projectedAnnualCost == 1_020)
        #expect(result.xpPerCycleDelta < 0)
    }

    @Test("Simulations never mutate the baseline they were given")
    func purity() {
        let original = baseline
        let frozen = original
        _ = DecisionSimulator.simulate(
            baseline: original,
            change: .addRecurringExpense(monthly: 500, isRequired: true)
        )
        _ = DecisionSimulator.simulate(baseline: original, change: .extraLifeWithdrawal(amount: 4_600))
        _ = DecisionSimulator.simulate(baseline: original, change: .incomeChange(perCycleDelta: -400))
        #expect(original == frozen)
        #expect(original.requiredMonthlyBudget == 4_700)
        #expect(original.extraLifeBalance == 9_600)
    }

    @Test("An Extra Life withdrawal reduces only the fund")
    func withdrawal() {
        let result = DecisionSimulator.simulate(
            baseline: baseline,
            change: .extraLifeWithdrawal(amount: 4_700)
        )
        #expect(result.after.extraLifeBalance == 4_900)
        #expect(result.after.requiredMonthlyBudget == 4_700)
        #expect(result.oneTimeCost == 4_700)
        #expect(result.impactLevel == .high) // a full life is a big deal
    }

    @Test("Income reduction shrinks XP per cycle")
    func incomeDown() {
        let result = DecisionSimulator.simulate(
            baseline: baseline,
            change: .incomeChange(perCycleDelta: -400)
        )
        #expect(result.after.averageIncomePerCycle == 4_450)
        #expect(result.xpPerCycleDelta == -400)
        #expect(result.projectedGoalDelayCycles >= 0)
    }

    @Test("A small flexible add is labeled Low impact")
    func lowImpact() {
        let result = DecisionSimulator.simulate(
            baseline: baseline,
            change: .addRecurringExpense(monthly: 27, isRequired: false)
        )
        #expect(result.impactLevel == .low)
        #expect(result.after.requiredMonthlyBudget == 4_700) // flexible: no change
        #expect(result.after.extraLifeValue == 4_700)
    }
}

@Suite("Dual approval policy")
struct ApprovalPolicyTests {

    @Test("One approval is never enough to apply")
    func singleApprovalInsufficient() {
        var pair = ApprovalPair()
        #expect(!pair.bothApproved)
        pair = pair.recording(.approved, forSlot: 0)
        #expect(!pair.bothApproved)
        #expect(ApprovalPolicy.stage(afterSubmissionWith: pair) == .awaitingApproval)
        #expect(!ApprovalPolicy.canApply(stage: .awaitingApproval, approvals: pair))
    }

    @Test("Both approvals reach the approved stage — application is a separate step")
    func bothApprove() {
        var pair = ApprovalPair()
        pair = pair.recording(.approved, forSlot: 0)
        pair = pair.recording(.approved, forSlot: 1)
        #expect(pair.bothApproved)
        let stage = ApprovalPolicy.stage(afterSubmissionWith: pair)
        #expect(stage == .approved)
        #expect(ApprovalPolicy.canApply(stage: stage, approvals: pair))
        // Still awaiting? Not applicable, even with both signatures.
        #expect(!ApprovalPolicy.canApply(stage: .awaitingApproval, approvals: pair))
        #expect(!ApprovalPolicy.canApply(stage: .applied, approvals: pair))
    }

    @Test("Any decline is terminal for the round")
    func decline() {
        var pair = ApprovalPair()
        pair = pair.recording(.approved, forSlot: 0)
        pair = pair.recording(.declined, forSlot: 1)
        #expect(pair.anyDeclined)
        #expect(ApprovalPolicy.stage(afterSubmissionWith: pair) == .declined)
        #expect(!ApprovalPolicy.canApply(stage: .declined, approvals: pair))
    }
}
