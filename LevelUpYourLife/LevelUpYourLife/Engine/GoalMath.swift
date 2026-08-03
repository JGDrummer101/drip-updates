import Foundation

/// RULE 6: goal progress and XP allocation planning. $1 == 1 XP.
enum GoalMath {

    /// Raw completion fraction (can exceed 1 when over-funded).
    static func rawFraction(current: Decimal, target: Decimal) -> Decimal {
        guard target > 0 else { return .zero }
        return current / target
    }

    /// Visual progress, capped at 100%.
    static func progressFraction(current: Decimal, target: Decimal) -> Double {
        min(1.0, max(0.0, rawFraction(current: current, target: target).doubleValue))
    }

    /// A goal at or above 100% is Funded — never automatically Obtained.
    static func isFunded(current: Decimal, target: Decimal) -> Bool {
        target > 0 && current >= target
    }

    static func xpRemaining(current: Decimal, target: Decimal) -> Decimal {
        CurrencyMath.nonNegative(target - current)
    }

    /// Whole-percent display value, capped at 100.
    static func percentDisplay(current: Decimal, target: Decimal) -> Int {
        Int((progressFraction(current: current, target: target) * 100).rounded())
    }

    /// Number of "boxes" filled for the box visualization.
    static func boxesFilled(current: Decimal, boxValue: Decimal) -> Int {
        guard boxValue > 0, current > 0 else { return 0 }
        var quotient = current / boxValue
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .down)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static func boxCount(target: Decimal, boxValue: Decimal) -> Int {
        guard boxValue > 0, target > 0 else { return 0 }
        var quotient = target / boxValue
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .up)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}

// MARK: - XP allocation plan

/// A working plan for splitting one pay cycle's Available XP across goals.
/// The plan is pure state — committing it to storage is the service layer's job.
struct XPAllocationPlan: Equatable, Sendable {

    struct Line: Identifiable, Equatable, Sendable {
        var id: UUID          // goal id
        var goalTitle: String
        var amount: Decimal
    }

    var available: Decimal
    var lines: [Line]

    init(available: Decimal, lines: [Line] = []) {
        self.available = available
        self.lines = lines
    }

    var totalAllocated: Decimal {
        lines.reduce(.zero) { $0 + $1.amount }
    }

    var remaining: Decimal {
        available - totalAllocated
    }

    /// Valid when nothing is negative and the plan never overspends the pool.
    var isValid: Bool {
        remaining >= 0 && lines.allSatisfy { $0.amount >= 0 }
    }

    mutating func setAmount(_ amount: Decimal, forGoal id: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].amount = CurrencyMath.nonNegative(amount)
    }

    /// Suggested split: weight goals by priority (1 = highest), cap each line
    /// at the goal's remaining need, keep whole dollars, and hand leftovers to
    /// the highest-priority goal that still has room.
    static func suggested(
        available: Decimal,
        goals: [(id: UUID, title: String, priority: Int, xpRemaining: Decimal)]
    ) -> XPAllocationPlan {
        let pool = CurrencyMath.wholeDollarsFloor(CurrencyMath.nonNegative(available))
        let open = goals.filter { $0.xpRemaining > 0 }
        guard pool > 0, !open.isEmpty else {
            return XPAllocationPlan(
                available: available,
                lines: goals.map { Line(id: $0.id, goalTitle: $0.title, amount: 0) }
            )
        }

        let maxPriority = open.map(\.priority).max() ?? 1
        let weights = open.map { Decimal(maxPriority + 1 - min($0.priority, maxPriority)) }
        let totalWeight = weights.reduce(Decimal.zero, +)

        var amounts: [UUID: Decimal] = [:]
        var spent = Decimal.zero
        for (goal, weight) in zip(open, weights) {
            let share = CurrencyMath.wholeDollarsFloor(pool * weight / totalWeight)
            let capped = min(share, CurrencyMath.wholeDollarsFloor(goal.xpRemaining))
            amounts[goal.id] = capped
            spent += capped
        }

        // Hand out any remainder in priority order to goals with room left.
        var leftover = pool - spent
        for goal in open.sorted(by: { $0.priority < $1.priority }) where leftover > 0 {
            let current = amounts[goal.id] ?? 0
            let room = CurrencyMath.wholeDollarsFloor(goal.xpRemaining) - current
            guard room > 0 else { continue }
            let add = min(room, leftover)
            amounts[goal.id] = current + add
            leftover -= add
        }

        return XPAllocationPlan(
            available: available,
            lines: goals.map {
                Line(id: $0.id, goalTitle: $0.title, amount: amounts[$0.id] ?? 0)
            }
        )
    }
}
