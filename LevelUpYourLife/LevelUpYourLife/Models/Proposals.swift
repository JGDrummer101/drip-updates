import Foundation
import SwiftData

enum ProposalType: String, Codable, CaseIterable, Sendable {
    case addRecurringExpense
    case increaseRequiredExpense
    case oneTimePurchase
    case incomeChange
    case splurgeChange
    case bufferChange
    case extraLifeWithdrawal
    case newGoal
    case goalWithdrawal
    case pauseGoal

    var displayName: String {
        switch self {
        case .addRecurringExpense: "New Recurring Expense"
        case .increaseRequiredExpense: "Change Required Expense"
        case .oneTimePurchase: "One-Time Purchase"
        case .incomeChange: "Income Change"
        case .splurgeChange: "Splurge Budget Change"
        case .bufferChange: "Minimum Buffer Change"
        case .extraLifeWithdrawal: "Use Extra Life Funds"
        case .newGoal: "New Savings Goal"
        case .goalWithdrawal: "Withdraw From Goal"
        case .pauseGoal: "Pause Goal"
        }
    }
}

/// Frozen before/after comparison attached to a proposal.
struct ImpactSnapshot: Codable, Equatable, Sendable {
    var currentMonthlyBudget: Decimal
    var proposedMonthlyBudget: Decimal
    var currentExtraLifeValue: Decimal
    var proposedExtraLifeValue: Decimal
    var currentExtraLifeCount: Decimal
    var proposedExtraLifeCount: Decimal
    /// Change in average XP per paycheck (negative = less XP).
    var paycheckImpact: Decimal
    var splurgeImpact: Decimal
    var projectedGoalDelayCycles: Int
    var projectedAnnualCost: Decimal
    var oneTimeCost: Decimal
    var impactLevel: ImpactLevel

    static func from(result: SimulationResult) -> ImpactSnapshot {
        ImpactSnapshot(
            currentMonthlyBudget: result.before.requiredMonthlyBudget,
            proposedMonthlyBudget: result.after.requiredMonthlyBudget,
            currentExtraLifeValue: result.before.extraLifeValue,
            proposedExtraLifeValue: result.after.extraLifeValue,
            currentExtraLifeCount: result.before.extraLifeCount,
            proposedExtraLifeCount: result.after.extraLifeCount,
            paycheckImpact: CurrencyMath.roundedToCents(result.xpPerCycleDelta),
            splurgeImpact: result.after.splurgePerCycle - result.before.splurgePerCycle,
            projectedGoalDelayCycles: result.projectedGoalDelayCycles,
            projectedAnnualCost: result.projectedAnnualCost,
            oneTimeCost: result.oneTimeCost,
            impactLevel: result.impactLevel
        )
    }
}

/// A material household change awaiting two-person approval.
@Model
final class FinancialProposal {
    var id: UUID
    var title: String
    var proposalType: ProposalType
    var details: String
    var recurringAmount: Decimal?
    var oneTimeAmount: Decimal?
    var effectiveDate: Date
    var endDate: Date?
    var submittedBy: String
    var submittedDate: Date
    var stage: ProposalStage
    /// Slot 0 = primary member, slot 1 = partner.
    var approvals: ApprovalPair
    var impact: ImpactSnapshot?
    var discussionNotes: String
    var appliedDate: Date?
    /// Payload for application: category used when the proposal creates a budget item.
    var payloadCategory: BudgetCategory?
    var payloadIsRequired: Bool
    /// Existing budget item or goal this proposal modifies, when applicable.
    var payloadTargetID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        proposalType: ProposalType,
        details: String = "",
        recurringAmount: Decimal? = nil,
        oneTimeAmount: Decimal? = nil,
        effectiveDate: Date = .now,
        endDate: Date? = nil,
        submittedBy: String = "",
        submittedDate: Date = .now,
        stage: ProposalStage = .awaitingApproval,
        approvals: ApprovalPair = ApprovalPair(),
        impact: ImpactSnapshot? = nil,
        discussionNotes: String = "",
        appliedDate: Date? = nil,
        payloadCategory: BudgetCategory? = nil,
        payloadIsRequired: Bool = true,
        payloadTargetID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.proposalType = proposalType
        self.details = details
        self.recurringAmount = recurringAmount
        self.oneTimeAmount = oneTimeAmount
        self.effectiveDate = effectiveDate
        self.endDate = endDate
        self.submittedBy = submittedBy
        self.submittedDate = submittedDate
        self.stage = stage
        self.approvals = approvals
        self.impact = impact
        self.discussionNotes = discussionNotes
        self.appliedDate = appliedDate
        self.payloadCategory = payloadCategory
        self.payloadIsRequired = payloadIsRequired
        self.payloadTargetID = payloadTargetID
    }

    var canApply: Bool {
        ApprovalPolicy.canApply(stage: stage, approvals: approvals)
    }
}

enum ActivityEventType: String, Codable, CaseIterable, Sendable {
    case cycleConfirmed, xpAllocated, adventureAdded, adventureDrawn, adventureCompleted
    case proposalSubmitted, proposalApproved, proposalDeclined, proposalApplied
    case goalProgress, goalFunded, goalObtained
    case extraLifeContribution, extraLifeUsed
    case levelUp, spriteUpdated, general

    var iconName: String {
        switch self {
        case .cycleConfirmed: "checkmark.seal.fill"
        case .xpAllocated: "star.fill"
        case .adventureAdded, .adventureDrawn: "die.face.5.fill"
        case .adventureCompleted: "flag.checkered"
        case .proposalSubmitted, .proposalApproved, .proposalApplied: "person.2.fill"
        case .proposalDeclined: "hand.raised.fill"
        case .goalProgress, .goalFunded: "target"
        case .goalObtained: "trophy.fill"
        case .extraLifeContribution, .extraLifeUsed: "heart.fill"
        case .levelUp: "arrow.up.circle.fill"
        case .spriteUpdated: "person.crop.square"
        case .general: "sparkle"
        }
    }
}

/// One row in the shared activity feed.
@Model
final class ActivityEvent {
    var id: UUID
    var title: String
    var subtitle: String
    var date: Date
    var memberName: String
    var eventType: ActivityEventType

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        date: Date = .now,
        memberName: String = "",
        eventType: ActivityEventType = .general
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.memberName = memberName
        self.eventType = eventType
    }
}

/// Every persisted type, in one place — the app and its tests build their
/// containers from this list, and a future CloudKit schema starts here.
enum AppSchema {
    static var models: [any PersistentModel.Type] {
        [
            Household.self, HouseholdMember.self,
            PayCycle.self, IncomeEntry.self,
            BudgetItem.self, BudgetItemStatus.self,
            AdventureIdea.self, AdventureDraw.self,
            Goal.self, XPTransaction.self, ExtraLifeTransaction.self,
            FinancialProposal.self, ActivityEvent.self,
        ]
    }
}
