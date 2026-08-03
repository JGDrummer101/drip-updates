import Foundation
import Testing
@testable import LevelUpYourLife

@Suite("Payday schedule and three-paycheck months")
struct PaydayScheduleTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var schedule: PaydaySchedule {
        PaydaySchedule(anchor: date(2026, 1, 2)) // a Friday
    }

    @Test("Biweekly paydays enumerate correctly inside a month")
    func enumeration() {
        let january = schedule.paydays(inMonthContaining: date(2026, 1, 15), calendar: calendar)
        #expect(january.map { calendar.component(.day, from: $0) } == [2, 16, 30])

        let august = schedule.paydays(inMonthContaining: date(2026, 8, 3), calendar: calendar)
        #expect(august.map { calendar.component(.day, from: $0) } == [14, 28])
    }

    @Test("Three-paycheck months are detected; two-paycheck months are not")
    func detection() {
        #expect(schedule.isThreePaycheckMonth(monthContaining: date(2026, 1, 20), calendar: calendar))
        #expect(schedule.isThreePaycheckMonth(monthContaining: date(2026, 7, 10), calendar: calendar))
        #expect(!schedule.isThreePaycheckMonth(monthContaining: date(2026, 2, 10), calendar: calendar))
        #expect(!schedule.isThreePaycheckMonth(monthContaining: date(2026, 8, 10), calendar: calendar))
        #expect(!schedule.isThreePaycheckMonth(monthContaining: date(2026, 12, 10), calendar: calendar))
    }

    @Test("Most recent and next payday bracket any date")
    func neighbors() {
        let recent = schedule.mostRecentPayday(onOrBefore: date(2026, 8, 3), calendar: calendar)
        #expect(calendar.isDate(recent, inSameDayAs: date(2026, 7, 31)))

        let next = schedule.nextPayday(after: date(2026, 8, 3), calendar: calendar)
        #expect(calendar.isDate(next, inSameDayAs: date(2026, 8, 14)))

        let onPayday = schedule.mostRecentPayday(onOrBefore: date(2026, 7, 31), calendar: calendar)
        #expect(calendar.isDate(onPayday, inSameDayAs: date(2026, 7, 31)))

        let beforeAnchor = schedule.mostRecentPayday(onOrBefore: date(2025, 12, 1), calendar: calendar)
        #expect(calendar.isDate(beforeAnchor, inSameDayAs: date(2026, 1, 2)))
    }

    @Test("The next three-paycheck month after August 2026 is January 2027")
    func nextTriple() {
        let next = schedule.nextThreePaycheckMonth(onOrAfter: date(2026, 8, 3), calendar: calendar)
        #expect(next != nil)
        if let next {
            let comps = calendar.dateComponents([.year, .month], from: next)
            #expect(comps.year == 2027 && comps.month == 1)
        }
    }

    @Test("Due dates clamp to short months")
    func dueDayClamping() {
        let due = FinanceEngine.nextDueDate(
            dueDay: 31,
            inWindowFrom: date(2026, 2, 20),
            to: date(2026, 3, 5),
            calendar: calendar
        )
        #expect(due != nil)
        if let due {
            // February 2026 has 28 days — day 31 clamps to the 28th.
            #expect(calendar.isDate(due, inSameDayAs: date(2026, 2, 28)))
        }
    }

    @Test("Smoothed funding spreads a monthly amount across the cycle")
    func smoothedShare() {
        let items = [BudgetItemSpec(
            title: "Auto Fuel",
            amount: 220,
            fundingMethod: .smoothed,
            dueDay: 15
        )]
        let plan = FinanceEngine.fundingPlan(
            items: items,
            cycleStart: date(2026, 7, 31),
            cycleEnd: date(2026, 8, 13),
            calendar: calendar
        )
        #expect(plan.count == 1)
        // 220 × 14 days × 12 / 365 ≈ 101.26
        #expect(abs((plan[0].amountDue - Decimal(string: "101.26")!).doubleValue) < 0.02)
    }
}
