import Foundation
import Testing
@testable import LevelUpYourLife

@Suite("Household level curve")
struct LevelCurveTests {

    @Test("Standard curve puts the demo household at Level 14")
    func standardCurve() {
        let curve = LevelCurve.standard
        #expect(curve.level(forXP: 0) == 1)
        #expect(curve.level(forXP: 499) == 1)
        #expect(curve.level(forXP: 500) == 2)
        #expect(curve.level(forXP: 18_299) == 13)
        #expect(curve.level(forXP: 18_400) == 14)
        #expect(curve.level(forXP: 21_000) == 15)
    }

    @Test("Classic preset matches the suggested thresholds")
    func classicCurve() {
        let curve = LevelCurve.classic
        #expect(curve.level(forXP: 0) == 1)
        #expect(curve.level(forXP: 4_999) == 1)
        #expect(curve.level(forXP: 5_000) == 2)
        #expect(curve.level(forXP: 15_000) == 3)
        #expect(curve.level(forXP: 35_000) == 4)
        #expect(curve.level(forXP: 75_000) == 5)
        #expect(curve.level(forXP: 150_000) == 6)
    }

    @Test("Thresholds beyond the table grow progressively larger")
    func extension_() {
        let curve = LevelCurve.classic
        var previousGap = Decimal.zero
        for level in 2...12 {
            let gap = curve.threshold(forLevel: level + 1) - curve.threshold(forLevel: level)
            #expect(gap >= previousGap)
            previousGap = gap
        }
        #expect(curve.level(forXP: 10_000_000) > 6)
    }

    @Test("Progress fraction stays in bounds")
    func progress() {
        let progress = LevelCurve.standard.progress(forXP: 18_400)
        #expect(progress.level == 14)
        #expect(progress.earnedInLevel == 100)
        #expect(progress.neededForNextLevel == 2_700)
        #expect(progress.fraction >= 0 && progress.fraction <= 1)
        #expect(LevelCurve.standard.progress(forXP: -10).fraction == 0)
    }
}

@Suite("Goal math")
struct GoalMathTests {

    @Test("Percentage caps at 100% for display")
    func percentage() {
        #expect(abs(GoalMath.progressFraction(current: 2_350, target: 4_000) - 0.5875) < 0.0001)
        #expect(GoalMath.progressFraction(current: 5_000, target: 4_000) == 1.0)
        #expect(GoalMath.progressFraction(current: 0, target: 4_000) == 0)
        #expect(GoalMath.progressFraction(current: 100, target: 0) == 0)
        #expect(GoalMath.percentDisplay(current: 2_350, target: 4_000) == 59)
    }

    @Test("At or above target means Funded, never automatically Obtained")
    func fundedNotObtained() {
        #expect(GoalMath.isFunded(current: 4_000, target: 4_000))
        #expect(GoalMath.isFunded(current: 4_100, target: 4_000))
        #expect(!GoalMath.isFunded(current: 3_999, target: 4_000))
        #expect(!GoalMath.isFunded(current: 0, target: 0))
        #expect(GoalMath.xpRemaining(current: 4_100, target: 4_000) == 0)
        #expect(GoalMath.xpRemaining(current: 2_350, target: 4_000) == 1_650)
    }

    @Test("Box math floors filled boxes and ceils totals")
    func boxes() {
        #expect(GoalMath.boxesFilled(current: 2_350, boxValue: 100) == 23)
        #expect(GoalMath.boxCount(target: 4_050, boxValue: 100) == 41)
        #expect(GoalMath.boxesFilled(current: 100, boxValue: 0) == 0)
    }
}

@Suite("XP allocation planning")
struct XPAllocationPlanTests {

    private let goalA = UUID()
    private let goalB = UUID()
    private let goalC = UUID()

    @Test("A plan can never spend more XP than it has")
    func overspendInvalid() {
        var plan = XPAllocationPlan(
            available: 1_310,
            lines: [
                .init(id: goalA, goalTitle: "Hawaii", amount: 0),
                .init(id: goalB, goalTitle: "New Car", amount: 0),
            ]
        )
        plan.setAmount(1_000, forGoal: goalA)
        plan.setAmount(300, forGoal: goalB)
        #expect(plan.isValid)
        #expect(plan.totalAllocated == 1_300)
        #expect(plan.remaining == 10)

        plan.setAmount(400, forGoal: goalB)
        #expect(!plan.isValid)

        plan.setAmount(-50, forGoal: goalB)
        #expect(plan.lines.first { $0.id == goalB }?.amount == 0)
    }

    @Test("Suggested split respects priority weighting and remaining need")
    func suggested() {
        let plan = XPAllocationPlan.suggested(
            available: 1_310,
            goals: [
                (id: goalA, title: "Renovation", priority: 1, xpRemaining: 5_800),
                (id: goalB, title: "Hawaii", priority: 2, xpRemaining: 1_650),
                (id: goalC, title: "Almost Done", priority: 3, xpRemaining: 40),
            ]
        )
        #expect(plan.isValid)
        #expect(plan.totalAllocated <= 1_310)
        let a = plan.lines.first { $0.id == goalA }?.amount ?? 0
        let b = plan.lines.first { $0.id == goalB }?.amount ?? 0
        let c = plan.lines.first { $0.id == goalC }?.amount ?? 0
        #expect(a >= b) // higher priority never gets less
        #expect(c <= 40) // capped by remaining need
        #expect(a + b + c == plan.totalAllocated)
    }

    @Test("Fully funded goals draw nothing")
    func fundedGoalsSkipped() {
        let plan = XPAllocationPlan.suggested(
            available: 500,
            goals: [(id: goalA, title: "Done", priority: 1, xpRemaining: 0)]
        )
        #expect(plan.totalAllocated == 0)
    }
}
