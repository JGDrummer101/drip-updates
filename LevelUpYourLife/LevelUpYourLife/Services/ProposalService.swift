import Foundation
import SwiftData

/// Proposal lifecycle: creation from Decision Lab, dual approval, application.
/// Nothing a proposal describes touches live data until `apply` runs.
@MainActor
enum ProposalService {

    /// Builds the engine change a proposal represents, for simulation.
    static func change(for proposal: FinancialProposal) -> SimulationChange? {
        switch proposal.proposalType {
        case .addRecurringExpense:
            guard let monthly = proposal.recurringAmount else { return nil }
            return .addRecurringExpense(monthly: monthly, isRequired: proposal.payloadIsRequired)
        case .increaseRequiredExpense:
            guard let delta = proposal.recurringAmount else { return nil }
            return .changeRequiredExpense(monthlyDelta: delta)
        case .oneTimePurchase:
            guard let amount = proposal.oneTimeAmount else { return nil }
            return .oneTimePurchase(amount: amount)
        case .incomeChange:
            guard let delta = proposal.recurringAmount else { return nil }
            return .incomeChange(perCycleDelta: delta * FinanceEngine.monthlyToPerCycleFactor)
        case .splurgeChange:
            guard let delta = proposal.recurringAmount else { return nil }
            return .splurgeChange(perCycleDelta: delta)
        case .bufferChange:
            guard let delta = proposal.recurringAmount else { return nil }
            return .bufferChange(perCycleDelta: delta)
        case .extraLifeWithdrawal, .goalWithdrawal:
            guard let amount = proposal.oneTimeAmount else { return nil }
            return .extraLifeWithdrawal(amount: amount)
        case .newGoal:
            guard let target = proposal.oneTimeAmount else { return nil }
            return .newGoal(target: target, perCycleCommitment: proposal.recurringAmount ?? 0)
        case .pauseGoal:
            return nil
        }
    }

    /// Creates a proposal with a frozen impact snapshot.
    @discardableResult
    static func submit(
        title: String,
        type: ProposalType,
        details: String,
        recurringAmount: Decimal?,
        oneTimeAmount: Decimal?,
        effectiveDate: Date,
        submittedBy: String,
        baseline: FinancialBaseline,
        payloadCategory: BudgetCategory? = nil,
        payloadIsRequired: Bool = true,
        payloadTargetID: UUID? = nil,
        stage: ProposalStage = .awaitingApproval,
        context: ModelContext,
        now: Date = .now
    ) -> FinancialProposal {
        let proposal = FinancialProposal(
            title: title,
            proposalType: type,
            details: details,
            recurringAmount: recurringAmount,
            oneTimeAmount: oneTimeAmount,
            effectiveDate: effectiveDate,
            submittedBy: submittedBy,
            submittedDate: now,
            stage: stage,
            payloadCategory: payloadCategory,
            payloadIsRequired: payloadIsRequired,
            payloadTargetID: payloadTargetID
        )
        if let change = change(for: proposal) {
            let result = DecisionSimulator.simulate(baseline: baseline, change: change)
            proposal.impact = ImpactSnapshot.from(result: result)
        }
        context.insert(proposal)
        if stage == .awaitingApproval {
            ActivityLog.post(
                context,
                title: "\(title) proposal is awaiting approval",
                subtitle: "Submitted by \(submittedBy)",
                member: submittedBy,
                type: .proposalSubmitted,
                date: now
            )
        }
        return proposal
    }

    /// Records one member's decision and advances the stage.
    static func record(
        _ decision: ApprovalState,
        for proposal: FinancialProposal,
        memberSlot: Int,
        memberName: String,
        context: ModelContext,
        now: Date = .now
    ) {
        guard proposal.stage == .awaitingApproval || proposal.stage == .draft else { return }
        proposal.approvals = proposal.approvals.recording(decision, forSlot: memberSlot)
        proposal.stage = ApprovalPolicy.stage(afterSubmissionWith: proposal.approvals)

        switch proposal.stage {
        case .approved:
            ActivityLog.post(
                context,
                title: "Both adventurers approved \(proposal.title)",
                subtitle: "Ready to apply to the budget.",
                member: memberName,
                type: .proposalApproved,
                date: now
            )
        case .declined:
            ActivityLog.post(
                context,
                title: "\(proposal.title) was declined",
                subtitle: "Declined by \(memberName)",
                member: memberName,
                type: .proposalDeclined,
                date: now
            )
        default:
            break
        }
    }

    /// Sends a proposal back to draft with a note ("Request Changes").
    static func requestChanges(
        for proposal: FinancialProposal,
        note: String,
        memberName: String,
        context: ModelContext
    ) {
        proposal.stage = .draft
        proposal.approvals = ApprovalPair()
        if !note.isEmpty {
            let stamp = proposal.discussionNotes.isEmpty ? "" : "\n"
            proposal.discussionNotes += "\(stamp)\(memberName): \(note)"
        }
    }

    /// Applies an approved proposal to live data. The only door in.
    static func apply(
        _ proposal: FinancialProposal,
        household: Household?,
        items: [BudgetItem],
        goals: [Goal],
        memberName: String,
        context: ModelContext,
        now: Date = .now
    ) {
        guard proposal.canApply else { return }

        switch proposal.proposalType {
        case .addRecurringExpense:
            let item = BudgetItem(
                title: proposal.title,
                amount: proposal.recurringAmount ?? 0,
                category: proposal.payloadCategory ?? .other,
                dueDay: Calendar.current.component(.day, from: proposal.effectiveDate),
                recurrence: .monthly,
                fundingMethod: .dueDate,
                isRequired: proposal.payloadIsRequired,
                createdBy: proposal.submittedBy,
                createdDate: now
            )
            context.insert(item)

        case .increaseRequiredExpense:
            if let target = items.first(where: { $0.id == proposal.payloadTargetID }) {
                target.amount += proposal.recurringAmount ?? 0
            }

        case .splurgeChange:
            household?.defaultSplurgeBudget = CurrencyMath.nonNegative(
                (household?.defaultSplurgeBudget ?? 0) + (proposal.recurringAmount ?? 0)
            )

        case .bufferChange:
            household?.minimumBuffer = CurrencyMath.nonNegative(
                (household?.minimumBuffer ?? 0) + (proposal.recurringAmount ?? 0)
            )

        case .extraLifeWithdrawal:
            context.insert(ExtraLifeTransaction(
                amount: -(proposal.oneTimeAmount ?? 0),
                type: .withdrawal,
                date: now,
                reason: proposal.title
            ))

        case .newGoal:
            context.insert(Goal(
                title: proposal.title,
                targetAmount: proposal.oneTimeAmount ?? 0,
                createdDate: now
            ))

        case .goalWithdrawal:
            if let goal = goals.first(where: { $0.id == proposal.payloadTargetID }) {
                goal.currentAmount = CurrencyMath.nonNegative(
                    goal.currentAmount - (proposal.oneTimeAmount ?? 0)
                )
                if goal.status == .funded && !goal.isFunded { goal.status = .active }
            }

        case .pauseGoal:
            if let goal = goals.first(where: { $0.id == proposal.payloadTargetID }) {
                goal.status = .paused
            }

        case .oneTimePurchase, .incomeChange:
            break // informational: they change plans, not stored structures
        }

        proposal.stage = .applied
        proposal.appliedDate = now
        ActivityLog.post(
            context,
            title: "\(proposal.title) applied to the budget",
            subtitle: "Approved by both adventurers.",
            member: memberName,
            type: .proposalApplied,
            date: now
        )
    }
}
