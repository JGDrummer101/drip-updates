import Foundation
import Observation

/// SCREEN 2 working state: everything the guided flow edits, plus live
/// engine math. Nothing persists until the user confirms.
@Observable
@MainActor
final class PayCycleDraft {

    struct OtherIncome: Identifiable {
        let id = UUID()
        var title: String = ""
        var amount: Decimal = 0
        var type: IncomeType = .other
        var owner: String = ""
    }

    // Step 1: income
    var startDate: Date
    var endDate: Date
    var paycheckDate: Date
    var member1Name: String
    var member2Name: String
    var member1Amount: Decimal
    var member2Amount: Decimal
    var otherIncome: [OtherIncome] = []

    // Step 3: fun & protection
    var splurgeTarget: Decimal
    var bufferTarget: Decimal
    var extraLifeTarget: Decimal = 0

    // Survival Mode selections
    var useExtraLife = false
    var extraLifeAmount: Decimal = 0
    var splurgeReduction: Decimal = 0
    var bufferReduction: Decimal = 0
    var dropExtraLifeContribution = false
    var delayedFlexibleIDs: Set<UUID> = []
    /// Prototype stand-in for the second member's device: using Extra Life
    /// funds requires both simulated approvals.
    var extraLifeApprovals = ApprovalPair()

    init(household: Household?, lastCycle: PayCycle?, now: Date = .now) {
        let calendar = Calendar.current
        if let schedule = household?.paydaySchedule {
            let next = schedule.nextPayday(after: lastCycle?.paycheckDate ?? now, calendar: calendar)
            paycheckDate = next
            startDate = next
            endDate = calendar.date(byAdding: .day, value: 13, to: next) ?? next
        } else {
            paycheckDate = now
            startDate = now
            endDate = calendar.date(byAdding: .day, value: 13, to: now) ?? now
        }

        let members = household?.orderedMembers ?? []
        // Locals, not properties: referencing a property inside the closures
        // below would capture `self` before initialization completes.
        let firstName = members.first?.displayName ?? "Member 1"
        let secondName = members.count > 1 ? members[1].displayName : "Member 2"
        member1Name = firstName
        member2Name = secondName

        let paychecks = lastCycle?.incomeEntries.filter { $0.type == .paycheck } ?? []
        member1Amount = paychecks.first { $0.owner == firstName }?.amount ?? 2_350
        member2Amount = paychecks.first { $0.owner == secondName }?.amount ?? 2_100

        splurgeTarget = household?.defaultSplurgeBudget ?? 300
        bufferTarget = household?.minimumBuffer ?? 300
    }

    // MARK: Derived income

    var totalIncome: Decimal {
        member1Amount + member2Amount + otherIncome.reduce(.zero) { $0 + $1.amount }
    }

    // MARK: Engine bridges

    func fundingPlan(items: [BudgetItem], calendar: Calendar = .current) -> [PlannedBillFunding] {
        FinanceEngine.fundingPlan(
            items: items.map(\.spec),
            cycleStart: startDate,
            cycleEnd: endDate,
            calendar: calendar
        )
    }

    func allocationRequest(items: [BudgetItem]) -> AllocationRequest {
        let plan = fundingPlan(items: items)
        let required = plan.filter(\.isRequired).reduce(Decimal.zero) { $0 + $1.amountDue }
        let flexible = plan.filter { !$0.isRequired }.reduce(Decimal.zero) { $0 + $1.amountDue }
        return AllocationRequest(
            totalIncome: totalIncome,
            requiredBills: required,
            flexibleBills: flexible,
            bufferTarget: bufferTarget,
            splurgeTarget: splurgeTarget,
            extraLifeTarget: extraLifeTarget
        )
    }

    func baseAllocation(items: [BudgetItem]) -> AllocationResult {
        FinanceEngine.allocate(allocationRequest(items: items))
    }

    /// Survival Mode routes in whenever the full plan can't be funded.
    func needsSurvival(items: [BudgetItem]) -> Bool {
        baseAllocation(items: items).planGap > 0
    }

    func survivalSelection(items: [BudgetItem]) -> SurvivalPlanner.Selection {
        var selection = SurvivalPlanner.Selection()
        selection.extraLifeAmount = useExtraLife ? extraLifeAmount : 0
        selection.splurgeReduction = splurgeReduction
        selection.bufferReduction = bufferReduction
        selection.dropExtraLifeContribution = dropExtraLifeContribution
        let plan = fundingPlan(items: items)
        selection.delayedFlexibleAmount = plan
            .filter { !$0.isRequired && delayedFlexibleIDs.contains($0.id) }
            .reduce(.zero) { $0 + $1.amountDue }
        return selection
    }

    func survivalOutcome(items: [BudgetItem], extraLifeValue: Decimal) -> SurvivalPlanner.Outcome {
        SurvivalPlanner.resolve(
            request: allocationRequest(items: items),
            selection: survivalSelection(items: items),
            extraLifeValue: extraLifeValue
        )
    }

    /// The allocation that will actually be saved.
    func effectiveAllocation(items: [BudgetItem], extraLifeValue: Decimal) -> AllocationResult {
        if needsSurvival(items: items) {
            return survivalOutcome(items: items, extraLifeValue: extraLifeValue).allocation
        }
        return baseAllocation(items: items)
    }

    /// Bills the confirmed cycle will actually fund (delayed ones drop out).
    func fundedBills(items: [BudgetItem]) -> [PlannedBillFunding] {
        fundingPlan(items: items).filter { bill in
            bill.isRequired || !delayedFlexibleIDs.contains(bill.id)
        }
    }

    var extraLifeUseIsApproved: Bool {
        !useExtraLife || extraLifeAmount == 0 || extraLifeApprovals.bothApproved
    }

    func incomeEntries() -> [(title: String, amount: Decimal, type: IncomeType, owner: String)] {
        var entries: [(title: String, amount: Decimal, type: IncomeType, owner: String)] = []
        if member1Amount > 0 {
            entries.append(("\(member1Name) — Paycheck", member1Amount, .paycheck, member1Name))
        }
        if member2Amount > 0 {
            entries.append(("\(member2Name) — Paycheck", member2Amount, .paycheck, member2Name))
        }
        for extra in otherIncome where extra.amount > 0 {
            entries.append((
                extra.title.isEmpty ? extra.type.displayName : extra.title,
                extra.amount,
                extra.type,
                extra.owner.isEmpty ? member1Name : extra.owner
            ))
        }
        return entries
    }
}
