import Foundation
import SwiftData

/// Committing XP allocation plans: transactions, goal updates, lifetime XP,
/// level recalculation, and funded detection all happen in one place.
@MainActor
enum XPService {

    struct CommitResult {
        var totalAllocated: Decimal
        var newLevel: Int?
        var newlyFundedGoals: [Goal]
    }

    @discardableResult
    static func commit(
        plan: XPAllocationPlan,
        goals: [Goal],
        cycle: PayCycle?,
        household: Household?,
        memberName: String,
        context: ModelContext,
        curve: LevelCurve = .standard,
        now: Date = .now
    ) -> CommitResult {
        guard plan.isValid else {
            return CommitResult(totalAllocated: 0, newLevel: nil, newlyFundedGoals: [])
        }

        let byID = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
        var allocated = Decimal.zero
        var newlyFunded: [Goal] = []

        for line in plan.lines where line.amount > 0 {
            guard let goal = byID[line.id] else { continue }
            let wasFunded = goal.isFunded

            let transaction = XPTransaction(
                amount: line.amount,
                date: now,
                sourceCycleID: cycle?.id,
                sourceCycleLabel: cycle?.dateRangeLabel ?? "",
                note: "XP allocation",
                createdBy: memberName
            )
            transaction.goal = goal
            context.insert(transaction)

            goal.currentAmount += line.amount
            allocated += line.amount

            if goal.isFunded && !wasFunded {
                goal.status = .funded
                newlyFunded.append(goal)
                ActivityLog.post(
                    context,
                    title: "\(goal.title) is fully funded",
                    subtitle: "Mark it obtained when the moment comes.",
                    member: memberName,
                    type: .goalFunded,
                    date: now
                )
            } else {
                ActivityLog.post(
                    context,
                    title: "\(memberName) allocated \(line.amount.xpLabel) to \(goal.title)",
                    subtitle: "\(goal.percentDisplay)% of \(goal.targetAmount.currencyLabel)",
                    member: memberName,
                    type: .xpAllocated,
                    date: now
                )
            }
        }

        guard allocated > 0 else {
            return CommitResult(totalAllocated: 0, newLevel: nil, newlyFundedGoals: [])
        }

        cycle?.xpAllocated += allocated

        var newLevel: Int?
        if let household {
            let oldLevel = curve.level(forXP: household.lifetimeXP)
            household.lifetimeXP += allocated
            let level = curve.level(forXP: household.lifetimeXP)
            household.currentLevel = level
            if level > oldLevel {
                newLevel = level
                ActivityLog.post(
                    context,
                    title: "Household reached Level \(level)",
                    subtitle: "Lifetime XP: \(household.lifetimeXP.xpLabel)",
                    member: memberName,
                    type: .levelUp,
                    date: now
                )
            }
        }

        return CommitResult(totalAllocated: allocated, newLevel: newLevel, newlyFundedGoals: newlyFunded)
    }

    /// Funded → Obtained is always an explicit human step.
    static func markObtained(_ goal: Goal, memberName: String, context: ModelContext, now: Date = .now) {
        guard goal.status == .funded || goal.isFunded else { return }
        goal.status = .obtained
        goal.completedDate = now
        ActivityLog.post(
            context,
            title: "\(goal.title) obtained!",
            subtitle: "A quest complete. Onward.",
            member: memberName,
            type: .goalObtained,
            date: now
        )
    }
}

extension Decimal {
    /// "$4,600" for whole amounts, "$4,612.50" otherwise.
    var currencyLabel: String {
        let value = self
        let isWhole = CurrencyMath.wholeDollarsFloor(value) == value
        return value.formatted(
            .currency(code: "USD").precision(.fractionLength(isWhole ? 0 : 2))
        )
    }
}
