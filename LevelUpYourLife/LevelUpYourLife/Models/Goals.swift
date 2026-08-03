import Foundation
import SwiftData

enum GoalCategory: String, Codable, CaseIterable, Sendable {
    case foundation, committed, qualityOfLife, family, home, longTerm

    var displayName: String {
        switch self {
        case .foundation: "Foundation"
        case .committed: "Committed"
        case .qualityOfLife: "Quality of Life"
        case .family: "Family"
        case .home: "Home"
        case .longTerm: "Long-Term"
        }
    }

    var sortOrder: Int {
        switch self {
        case .foundation: 0
        case .committed: 1
        case .qualityOfLife: 2
        case .family: 3
        case .home: 4
        case .longTerm: 5
        }
    }
}

enum GoalOwnership: String, Codable, CaseIterable, Sendable {
    case shared, mine, partner

    var displayName: String {
        switch self {
        case .shared: "Shared"
        case .mine: "Mine"
        case .partner: "Partner"
        }
    }
}

enum GoalStatus: String, Codable, CaseIterable, Sendable {
    case active, funded, obtained, paused, completed

    var displayName: String {
        switch self {
        case .active: "Active"
        case .funded: "Funded"
        case .obtained: "Obtained"
        case .paused: "Paused"
        case .completed: "Completed"
        }
    }
}

/// A savings goal. One dollar in equals one XP earned.
@Model
final class Goal {
    var id: UUID
    var title: String
    var category: GoalCategory
    var targetAmount: Decimal
    var currentAmount: Decimal
    /// 1 = highest priority.
    var priority: Int
    var targetDate: Date?
    var ownership: GoalOwnership
    var status: GoalStatus
    /// Dollar value of one box in the box-grid visualization.
    var boxValue: Decimal
    var useMilestones: Bool
    var milestoneValues: [Decimal]
    var createdDate: Date
    var completedDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \XPTransaction.goal)
    var transactions: [XPTransaction]

    init(
        id: UUID = UUID(),
        title: String,
        category: GoalCategory = .qualityOfLife,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        priority: Int = 3,
        targetDate: Date? = nil,
        ownership: GoalOwnership = .shared,
        status: GoalStatus = .active,
        boxValue: Decimal = 100,
        useMilestones: Bool = false,
        milestoneValues: [Decimal] = [],
        createdDate: Date = .now,
        completedDate: Date? = nil,
        transactions: [XPTransaction] = []
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.priority = priority
        self.targetDate = targetDate
        self.ownership = ownership
        self.status = status
        self.boxValue = boxValue
        self.useMilestones = useMilestones
        self.milestoneValues = milestoneValues
        self.createdDate = createdDate
        self.completedDate = completedDate
        self.transactions = transactions
    }

    var progressFraction: Double {
        GoalMath.progressFraction(current: currentAmount, target: targetAmount)
    }

    var percentDisplay: Int {
        GoalMath.percentDisplay(current: currentAmount, target: targetAmount)
    }

    var xpRemaining: Decimal {
        GoalMath.xpRemaining(current: currentAmount, target: targetAmount)
    }

    var isFunded: Bool {
        GoalMath.isFunded(current: currentAmount, target: targetAmount)
    }

    var acceptsXP: Bool {
        (status == .active || status == .funded) && xpRemaining > 0
    }
}

@Model
final class XPTransaction {
    var id: UUID
    var amount: Decimal
    var date: Date
    /// The cycle this XP came from, if any (denormalized to avoid an inverse web).
    var sourceCycleID: UUID?
    var sourceCycleLabel: String
    var note: String
    var createdBy: String
    var goal: Goal?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date = .now,
        sourceCycleID: UUID? = nil,
        sourceCycleLabel: String = "",
        note: String = "",
        createdBy: String = ""
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.sourceCycleID = sourceCycleID
        self.sourceCycleLabel = sourceCycleLabel
        self.note = note
        self.createdBy = createdBy
    }
}

enum ExtraLifeTransactionType: String, Codable, CaseIterable, Sendable {
    case contribution, withdrawal, adjustment

    var displayName: String { rawValue.capitalized }
}

@Model
final class ExtraLifeTransaction {
    var id: UUID
    /// Positive for contributions, negative for withdrawals.
    var amount: Decimal
    var type: ExtraLifeTransactionType
    var date: Date
    var reason: String
    var payCycleID: UUID?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: ExtraLifeTransactionType,
        date: Date = .now,
        reason: String = "",
        payCycleID: UUID? = nil
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.date = date
        self.reason = reason
        self.payCycleID = payCycleID
    }
}
