import Foundation
import SwiftData

/// The shared household — one per install in this prototype.
///
/// Structured so a future CloudKit-backed sync can treat `Household` as the
/// root shared record: no unique constraints, no non-optional relationships.
@Model
final class Household {
    var id: UUID
    var name: String
    var createdDate: Date
    var currentLevel: Int
    var lifetimeXP: Decimal
    var minimumBuffer: Decimal
    var defaultSplurgeBudget: Decimal
    var activeSeasonName: String
    var activeSeasonObjective: String

    /// Extra Lives configuration + lifetime stats.
    var targetExtraLives: Int
    var freeAdventuresCompleted: Int
    var currentStreakCycles: Int

    /// Recurring payday configuration (any known payday anchors the schedule).
    var paydayAnchor: Date?
    var paydayIntervalDays: Int

    @Relationship(deleteRule: .cascade, inverse: \HouseholdMember.household)
    var members: [HouseholdMember]

    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = .now,
        currentLevel: Int = 1,
        lifetimeXP: Decimal = 0,
        minimumBuffer: Decimal = 300,
        defaultSplurgeBudget: Decimal = 300,
        activeSeasonName: String = "",
        activeSeasonObjective: String = "",
        targetExtraLives: Int = 3,
        freeAdventuresCompleted: Int = 0,
        currentStreakCycles: Int = 0,
        paydayAnchor: Date? = nil,
        paydayIntervalDays: Int = 14,
        members: [HouseholdMember] = []
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.currentLevel = currentLevel
        self.lifetimeXP = lifetimeXP
        self.minimumBuffer = minimumBuffer
        self.defaultSplurgeBudget = defaultSplurgeBudget
        self.activeSeasonName = activeSeasonName
        self.activeSeasonObjective = activeSeasonObjective
        self.targetExtraLives = targetExtraLives
        self.freeAdventuresCompleted = freeAdventuresCompleted
        self.currentStreakCycles = currentStreakCycles
        self.paydayAnchor = paydayAnchor
        self.paydayIntervalDays = paydayIntervalDays
        self.members = members
    }

    /// Members in stable display order (primary first).
    var orderedMembers: [HouseholdMember] {
        members.sorted { lhs, rhs in
            if lhs.role == rhs.role { return lhs.displayName < rhs.displayName }
            return lhs.role == .primary
        }
    }

    var paydaySchedule: PaydaySchedule? {
        paydayAnchor.map { PaydaySchedule(anchor: $0, intervalDays: paydayIntervalDays) }
    }
}

enum MemberRole: String, Codable, CaseIterable, Sendable {
    case primary
    case partner
}

@Model
final class HouseholdMember {
    var id: UUID
    var displayName: String
    var role: MemberRole
    var spriteConfiguration: SpriteConfiguration
    var household: Household?

    init(
        id: UUID = UUID(),
        displayName: String,
        role: MemberRole,
        spriteConfiguration: SpriteConfiguration = SpriteConfiguration()
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.spriteConfiguration = spriteConfiguration
    }
}
