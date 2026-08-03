import Foundation
import SwiftData

enum BudgetCategory: String, Codable, CaseIterable, Sendable {
    case housing, utilities, transportation, food, health, insurance
    case subscriptions, lifestyle, savings, other

    var displayName: String {
        switch self {
        case .housing: "Housing"
        case .utilities: "Utilities"
        case .transportation: "Transportation"
        case .food: "Food"
        case .health: "Health"
        case .insurance: "Insurance"
        case .subscriptions: "Subscriptions"
        case .lifestyle: "Lifestyle"
        case .savings: "Savings"
        case .other: "Other"
        }
    }

    var iconName: String {
        switch self {
        case .housing: "house.fill"
        case .utilities: "bolt.fill"
        case .transportation: "car.fill"
        case .food: "fork.knife"
        case .health: "cross.case.fill"
        case .insurance: "shield.fill"
        case .subscriptions: "tv.fill"
        case .lifestyle: "sparkles"
        case .savings: "banknote.fill"
        case .other: "square.grid.2x2.fill"
        }
    }
}

enum FundingStatus: String, Codable, CaseIterable, Sendable {
    case needsFunding, funded, paid, upcoming

    var displayName: String {
        switch self {
        case .needsFunding: "Needs Funding"
        case .funded: "Funded"
        case .paid: "Paid"
        case .upcoming: "Upcoming"
        }
    }
}

/// A recurring (or one-time) budget line.
@Model
final class BudgetItem {
    var id: UUID
    var title: String
    /// Amount per recurrence period.
    var amount: Decimal
    var category: BudgetCategory
    /// Day of month the item is due (clamped to month length).
    var dueDay: Int
    var recurrence: RecurrenceRule
    var fundingMethod: FundingMethod
    var isRequired: Bool
    var isActive: Bool
    var isAutopay: Bool
    var paidFromAccount: String
    var createdBy: String
    var createdDate: Date

    @Relationship(deleteRule: .cascade, inverse: \BudgetItemStatus.item)
    var statuses: [BudgetItemStatus]

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        category: BudgetCategory = .other,
        dueDay: Int = 1,
        recurrence: RecurrenceRule = .monthly,
        fundingMethod: FundingMethod = .dueDate,
        isRequired: Bool = true,
        isActive: Bool = true,
        isAutopay: Bool = false,
        paidFromAccount: String = "Joint Checking",
        createdBy: String = "",
        createdDate: Date = .now,
        statuses: [BudgetItemStatus] = []
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.dueDay = dueDay
        self.recurrence = recurrence
        self.fundingMethod = fundingMethod
        self.isRequired = isRequired
        self.isActive = isActive
        self.isAutopay = isAutopay
        self.paidFromAccount = paidFromAccount
        self.createdBy = createdBy
        self.createdDate = createdDate
        self.statuses = statuses
    }

    /// Engine-facing snapshot of this item.
    var spec: BudgetItemSpec {
        BudgetItemSpec(
            id: id,
            title: title,
            amount: amount,
            recurrence: recurrence,
            fundingMethod: fundingMethod,
            isRequired: isRequired,
            isActive: isActive,
            dueDay: dueDay
        )
    }

    func status(forMonthKey key: String) -> BudgetItemStatus? {
        statuses.first { $0.monthKey == key }
    }
}

/// Tracks one item's funding inside a specific month ("2026-08").
@Model
final class BudgetItemStatus {
    var id: UUID
    var monthKey: String
    var amountNeeded: Decimal
    var amountReserved: Decimal
    var amountPaid: Decimal
    var status: FundingStatus
    var item: BudgetItem?

    init(
        id: UUID = UUID(),
        monthKey: String,
        amountNeeded: Decimal,
        amountReserved: Decimal = 0,
        amountPaid: Decimal = 0,
        status: FundingStatus = .upcoming
    ) {
        self.id = id
        self.monthKey = monthKey
        self.amountNeeded = amountNeeded
        self.amountReserved = amountReserved
        self.amountPaid = amountPaid
        self.status = status
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 2000, comps.month ?? 1)
    }
}
