import Foundation
import SwiftData

enum CycleStatus: String, Codable, CaseIterable, Sendable {
    case draft, confirmed, completed

    var displayName: String { rawValue.capitalized }
}

enum IncomeType: String, Codable, CaseIterable, Sendable {
    case paycheck, commission, bonus, reimbursement, other

    var displayName: String { rawValue.capitalized }
}

/// One pay cycle — normally the 14 days that a paycheck has to cover.
@Model
final class PayCycle {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var paycheckDate: Date
    var status: CycleStatus

    @Relationship(deleteRule: .cascade, inverse: \IncomeEntry.payCycle)
    var incomeEntries: [IncomeEntry]

    /// Allocation results frozen at confirmation time.
    var totalIncome: Decimal
    var billsReserved: Decimal
    var splurgeReserved: Decimal
    var bufferReserved: Decimal
    var extraLifeReserved: Decimal
    var availableXP: Decimal
    /// XP already moved into goals from this cycle.
    var xpAllocated: Decimal
    /// Splurge already committed to locked adventures this cycle.
    var splurgeSpent: Decimal

    var createdBy: String
    var createdDate: Date

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        paycheckDate: Date,
        status: CycleStatus = .draft,
        incomeEntries: [IncomeEntry] = [],
        totalIncome: Decimal = 0,
        billsReserved: Decimal = 0,
        splurgeReserved: Decimal = 0,
        bufferReserved: Decimal = 0,
        extraLifeReserved: Decimal = 0,
        availableXP: Decimal = 0,
        xpAllocated: Decimal = 0,
        splurgeSpent: Decimal = 0,
        createdBy: String = "",
        createdDate: Date = .now
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.paycheckDate = paycheckDate
        self.status = status
        self.incomeEntries = incomeEntries
        self.totalIncome = totalIncome
        self.billsReserved = billsReserved
        self.splurgeReserved = splurgeReserved
        self.bufferReserved = bufferReserved
        self.extraLifeReserved = extraLifeReserved
        self.availableXP = availableXP
        self.xpAllocated = xpAllocated
        self.splurgeSpent = splurgeSpent
        self.createdBy = createdBy
        self.createdDate = createdDate
    }

    /// XP still free to allocate from this cycle.
    var xpRemaining: Decimal {
        CurrencyMath.nonNegative(availableXP - xpAllocated)
    }

    /// Splurge budget still open for adventures.
    var splurgeRemaining: Decimal {
        CurrencyMath.nonNegative(splurgeReserved - splurgeSpent)
    }

    var unallocatedBalance: Decimal {
        CurrencyMath.nonNegative(
            totalIncome - billsReserved - splurgeReserved - bufferReserved - extraLifeReserved - xpAllocated
        )
    }

    var dateRangeLabel: String {
        let formatter = Date.FormatStyle().month(.abbreviated).day()
        return "\(startDate.formatted(formatter)) – \(endDate.formatted(formatter))"
    }
}

@Model
final class IncomeEntry {
    var id: UUID
    var title: String
    var amount: Decimal
    var type: IncomeType
    var date: Date
    /// Display name of the member this income belongs to.
    var owner: String
    var payCycle: PayCycle?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        type: IncomeType = .paycheck,
        date: Date = .now,
        owner: String = ""
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.date = date
        self.owner = owner
    }
}
