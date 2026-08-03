import Foundation
import Testing
@testable import LevelUpYourLife

@Suite("Required monthly budget")
struct RequiredBudgetTests {

    private func item(
        _ title: String,
        _ amount: Decimal,
        recurrence: RecurrenceRule = .monthly,
        required: Bool = true,
        active: Bool = true
    ) -> BudgetItemSpec {
        BudgetItemSpec(
            title: title,
            amount: amount,
            recurrence: recurrence,
            isRequired: required,
            isActive: active
        )
    }

    @Test("Only required, active items count")
    func filtering() {
        let items = [
            item("Mortgage", 1_850),
            item("Streaming", 45, required: false),
            item("Old Gym", 50, active: false),
            item("Internet", 70),
        ]
        #expect(FinanceEngine.requiredMonthlyBudget(items: items) == 1_920)
    }

    @Test("Recurrence normalizes to monthly equivalents")
    func recurrence() {
        #expect(FinanceEngine.monthlyEquivalent(amount: 120, recurrence: .monthly) == 120)
        #expect(FinanceEngine.monthlyEquivalent(amount: 120, recurrence: .annual) == 10)
        let weekly = FinanceEngine.monthlyEquivalent(amount: 12, recurrence: .weekly)
        #expect(weekly == 52) // 12 × 52 / 12
        let biweekly = FinanceEngine.monthlyEquivalent(amount: 12, recurrence: .biweekly)
        #expect(biweekly == 26) // 12 × 26 / 12
        #expect(FinanceEngine.monthlyEquivalent(amount: 500, recurrence: .oneTime) == 0)
    }

    @Test("Seed data budget sums to $4,510")
    func seedTotal() {
        let amounts: [Decimal] = [1_850, 120, 70, 160, 90, 450, 30, 120, 50, 50, 425, 280, 310, 90, 45, 150, 220]
        let items = amounts.enumerated().map { item("Item \($0.offset)", $0.element) }
        #expect(FinanceEngine.requiredMonthlyBudget(items: items) == 4_510)
    }
}

@Suite("Extra Life value and count")
struct ExtraLifeTests {

    @Test("Rounds upward to the nearest $100, preserving exact multiples")
    func rounding() {
        #expect(FinanceEngine.extraLifeValue(requiredMonthlyBudget: 4_012) == 4_100)
        #expect(FinanceEngine.extraLifeValue(requiredMonthlyBudget: 4_500) == 4_500)
        #expect(FinanceEngine.extraLifeValue(requiredMonthlyBudget: 4_501) == 4_600)
        #expect(FinanceEngine.extraLifeValue(requiredMonthlyBudget: 4_510) == 4_600)
        #expect(FinanceEngine.extraLifeValue(requiredMonthlyBudget: 1) == 100)
        #expect(FinanceEngine.extraLifeValue(requiredMonthlyBudget: 0) == 0)
        #expect(FinanceEngine.extraLifeValue(requiredMonthlyBudget: -50) == 0)
    }

    @Test("Ceil helper handles fractional cents")
    func ceilHelper() {
        #expect(CurrencyMath.ceilToNearest(Decimal(string: "4500.01")!, step: 100) == 4_600)
        #expect(CurrencyMath.ceilToNearest(Decimal(string: "99.99")!, step: 100) == 100)
    }

    @Test("Count divides balance by life value at full precision")
    func count() {
        let count = FinanceEngine.extraLifeCount(balance: 9_450, lifeValue: 4_600)
        #expect(abs((count - Decimal(string: "2.0543")!).doubleValue) < 0.001)
        #expect(FinanceEngine.extraLifeCount(balance: 9_450, lifeValue: 0) == 0)
        #expect(FinanceEngine.extraLifeCount(balance: 0, lifeValue: 4_600) == 0)
        #expect(FinanceEngine.extraLifeCount(balance: 9_200, lifeValue: 4_600) == 2)
    }

    @Test("Distance to the next whole life")
    func nextLife() {
        #expect(FinanceEngine.amountToNextLife(balance: 9_450, lifeValue: 4_600) == 4_350)
        #expect(FinanceEngine.amountToNextLife(balance: 0, lifeValue: 4_600) == 4_600)
        #expect(FinanceEngine.amountToNextLife(balance: 9_450, lifeValue: 0) == 0)
    }
}
