import Foundation
import SwiftData

/// Who an adventure idea belongs to. The spec's `freeAtHome`/`freeOut` split
/// widened into a single `free` ownership plus a five-way `FreeAdventureCategory`.
enum AdventureCategory: String, Codable, CaseIterable, Sendable {
    case mine, partner, shared, free

    var displayName: String {
        switch self {
        case .mine: "My Ideas"
        case .partner: "Partner Ideas"
        case .shared: "Our Ideas"
        case .free: "Free Adventures"
        }
    }
}

enum FreeAdventureCategory: String, Codable, CaseIterable, Sendable {
    case atHome, aroundTown, relationship, creative, outdoors

    var displayName: String {
        switch self {
        case .atHome: "At Home"
        case .aroundTown: "Around Town"
        case .relationship: "Relationship"
        case .creative: "Creative"
        case .outdoors: "Outdoors"
        }
    }

    var iconName: String {
        switch self {
        case .atHome: "house.fill"
        case .aroundTown: "building.2.fill"
        case .relationship: "heart.fill"
        case .creative: "paintpalette.fill"
        case .outdoors: "leaf.fill"
        }
    }
}

enum IdeaStatus: String, Codable, CaseIterable, Sendable {
    case waitingRoom, active, paused, completed, archived

    var displayName: String {
        switch self {
        case .waitingRoom: "Waiting Room"
        case .active: "Active"
        case .paused: "Paused"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }
}

@Model
final class AdventureIdea {
    var id: UUID
    var title: String
    var estimatedCost: Decimal
    var category: AdventureCategory
    var freeCategory: FreeAdventureCategory?
    var status: IdeaStatus
    var submittedBy: String
    var timesSelected: Int
    var lastSelectedDate: Date?
    var notes: String
    var createdDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        estimatedCost: Decimal = 0,
        category: AdventureCategory,
        freeCategory: FreeAdventureCategory? = nil,
        status: IdeaStatus = .active,
        submittedBy: String = "",
        timesSelected: Int = 0,
        lastSelectedDate: Date? = nil,
        notes: String = "",
        createdDate: Date = .now
    ) {
        self.id = id
        self.title = title
        self.estimatedCost = estimatedCost
        self.category = category
        self.freeCategory = freeCategory
        self.status = status
        self.submittedBy = submittedBy
        self.timesSelected = timesSelected
        self.lastSelectedDate = lastSelectedDate
        self.notes = notes
        self.createdDate = createdDate
    }

    /// Engine-facing snapshot for the draw.
    var drawCandidate: DrawCandidate {
        DrawCandidate(
            id: id,
            title: title,
            cost: estimatedCost,
            timesSelected: timesSelected,
            lastSelectedDate: lastSelectedDate,
            createdDate: createdDate
        )
    }
}

enum DrawResultStatus: String, Codable, CaseIterable, Sendable {
    case affordable, partiallyAffordable, freeMode, accepted, rerolled, saved

    var displayName: String {
        switch self {
        case .affordable: "Within Budget"
        case .partiallyAffordable: "Over Budget"
        case .freeMode: "Free Adventure"
        case .accepted: "Locked In"
        case .rerolled: "Rerolled"
        case .saved: "Saved for Later"
        }
    }
}

/// A denormalized copy of one drawn idea. Snapshotting title/cost keeps the
/// history intact even if the idea is later edited or archived.
struct DrawSlot: Codable, Equatable, Hashable, Sendable {
    var ideaID: UUID
    var title: String
    var cost: Decimal
    var ownerLabel: String
}

@Model
final class AdventureDraw {
    var id: UUID
    var payCycleID: UUID?
    var mineSlot: DrawSlot?
    var partnerSlot: DrawSlot?
    var sharedSlot: DrawSlot?
    var freeSlot: DrawSlot?
    var totalEstimatedCost: Decimal
    var resultStatus: DrawResultStatus
    var createdDate: Date

    init(
        id: UUID = UUID(),
        payCycleID: UUID? = nil,
        mineSlot: DrawSlot? = nil,
        partnerSlot: DrawSlot? = nil,
        sharedSlot: DrawSlot? = nil,
        freeSlot: DrawSlot? = nil,
        totalEstimatedCost: Decimal = 0,
        resultStatus: DrawResultStatus = .affordable,
        createdDate: Date = .now
    ) {
        self.id = id
        self.payCycleID = payCycleID
        self.mineSlot = mineSlot
        self.partnerSlot = partnerSlot
        self.sharedSlot = sharedSlot
        self.freeSlot = freeSlot
        self.totalEstimatedCost = totalEstimatedCost
        self.resultStatus = resultStatus
        self.createdDate = createdDate
    }

    var allSlots: [DrawSlot] {
        [mineSlot, partnerSlot, sharedSlot, freeSlot].compactMap { $0 }
    }
}
