import Foundation
import SwiftData

/// Adventure pools, draws, and free adventures.
@MainActor
enum AdventureService {

    static let activePoolLimit = 5

    static func activeIdeas(_ ideas: [AdventureIdea], in category: AdventureCategory) -> [AdventureIdea] {
        ideas
            .filter { $0.category == category && $0.status == .active }
            .sorted { $0.createdDate < $1.createdDate }
    }

    static func waitingRoomIdeas(_ ideas: [AdventureIdea]) -> [AdventureIdea] {
        ideas
            .filter { $0.status == .waitingRoom }
            .sorted { $0.createdDate < $1.createdDate }
    }

    /// New ideas overflow into the Waiting Room once a pool holds five.
    static func statusForNewIdea(in category: AdventureCategory, existing: [AdventureIdea]) -> IdeaStatus {
        guard category != .free else { return .active }
        return activeIdeas(existing, in: category).count < activePoolLimit ? .active : .waitingRoom
    }

    /// The previous draw for repeat avoidance: the latest accepted/saved draw.
    static func latestDraw(_ draws: [AdventureDraw]) -> AdventureDraw? {
        draws.sorted { $0.createdDate > $1.createdDate }.first
    }

    /// Performs this cycle's paid draw. Randomness comes from the caller so
    /// the UI can pass a system RNG while tests pass a seeded one.
    static func performDraw(
        ideas: [AdventureIdea],
        previous: AdventureDraw?,
        now: Date = .now,
        using rng: inout some RandomNumberGenerator
    ) -> DrawSelection {
        AdventureDrawEngine.draw(
            mine: activeIdeas(ideas, in: .mine).map(\.drawCandidate),
            partner: activeIdeas(ideas, in: .partner).map(\.drawCandidate),
            shared: activeIdeas(ideas, in: .shared).map(\.drawCandidate),
            previousMineID: previous?.mineSlot?.ideaID,
            previousPartnerID: previous?.partnerSlot?.ideaID,
            previousSharedID: previous?.sharedSlot?.ideaID,
            asOf: now,
            using: &rng
        )
    }

    /// Redraws a single slot, avoiding the currently shown candidate.
    static func redrawSlot(
        category: AdventureCategory,
        ideas: [AdventureIdea],
        current: DrawCandidate?,
        now: Date = .now,
        using rng: inout some RandomNumberGenerator
    ) -> DrawCandidate? {
        AdventureDrawEngine.pick(
            from: activeIdeas(ideas, in: category).map(\.drawCandidate),
            excluding: current?.id,
            asOf: now,
            using: &rng
        )
    }

    /// Weighted free-adventure pick, avoiding the last free pick.
    static func drawFree(
        ideas: [AdventureIdea],
        category: FreeAdventureCategory?,
        excluding: UUID?,
        now: Date = .now,
        using rng: inout some RandomNumberGenerator
    ) -> AdventureIdea? {
        var pool = ideas.filter { $0.category == .free && $0.status == .active }
        if let category {
            pool = pool.filter { $0.freeCategory == category }
        }
        guard let candidate = AdventureDrawEngine.pick(
            from: pool.map(\.drawCandidate),
            excluding: excluding,
            asOf: now,
            using: &rng
        ) else { return nil }
        return pool.first { $0.id == candidate.id }
    }

    /// Locks a paid draw in: snapshots slots, updates idea stats, spends splurge.
    @discardableResult
    static func lockIn(
        selection: DrawSelection,
        freePick: AdventureIdea?,
        ideas: [AdventureIdea],
        cycle: PayCycle?,
        memberNames: (mine: String, partner: String),
        budget: Decimal,
        context: ModelContext,
        now: Date = .now
    ) -> AdventureDraw {
        let total = selection.totalCost
        let draw = AdventureDraw(
            payCycleID: cycle?.id,
            mineSlot: selection.mine.map { DrawSlot(ideaID: $0.id, title: $0.title, cost: $0.cost, ownerLabel: memberNames.mine) },
            partnerSlot: selection.partner.map { DrawSlot(ideaID: $0.id, title: $0.title, cost: $0.cost, ownerLabel: memberNames.partner) },
            sharedSlot: selection.shared.map { DrawSlot(ideaID: $0.id, title: $0.title, cost: $0.cost, ownerLabel: "Together") },
            freeSlot: freePick.map { DrawSlot(ideaID: $0.id, title: $0.title, cost: 0, ownerLabel: "Free") },
            totalEstimatedCost: total,
            resultStatus: .accepted,
            createdDate: now
        )
        context.insert(draw)

        let pickedIDs = draw.allSlots.map(\.ideaID)
        for idea in ideas where pickedIDs.contains(idea.id) {
            idea.timesSelected += 1
            idea.lastSelectedDate = now
        }

        cycle?.splurgeSpent += min(total, budget)

        ActivityLog.post(
            context,
            title: "Adventure locked in",
            subtitle: draw.allSlots.map(\.title).joined(separator: " · "),
            type: .adventureDrawn,
            date: now
        )
        return draw
    }

    /// Saves a draw without spending anything.
    @discardableResult
    static func saveForLater(
        selection: DrawSelection,
        cycle: PayCycle?,
        memberNames: (mine: String, partner: String),
        context: ModelContext,
        now: Date = .now
    ) -> AdventureDraw {
        let draw = AdventureDraw(
            payCycleID: cycle?.id,
            mineSlot: selection.mine.map { DrawSlot(ideaID: $0.id, title: $0.title, cost: $0.cost, ownerLabel: memberNames.mine) },
            partnerSlot: selection.partner.map { DrawSlot(ideaID: $0.id, title: $0.title, cost: $0.cost, ownerLabel: memberNames.partner) },
            sharedSlot: selection.shared.map { DrawSlot(ideaID: $0.id, title: $0.title, cost: $0.cost, ownerLabel: "Together") },
            totalEstimatedCost: selection.totalCost,
            resultStatus: .saved,
            createdDate: now
        )
        context.insert(draw)
        return draw
    }

    /// A completed free adventure feeds the lifetime counter.
    static func completeFreeAdventure(
        _ idea: AdventureIdea,
        household: Household?,
        memberName: String,
        context: ModelContext,
        now: Date = .now
    ) {
        idea.timesSelected += 1
        idea.lastSelectedDate = now
        household?.freeAdventuresCompleted += 1
        ActivityLog.post(
            context,
            title: "Free adventure complete: \(idea.title)",
            subtitle: "That's \(household?.freeAdventuresCompleted ?? 0) lifetime free adventures.",
            member: memberName,
            type: .adventureCompleted,
            date: now
        )
    }

    /// "Convert Expensive Item to Goal" — the idea graduates into a savings goal.
    @discardableResult
    static func convertToGoal(
        _ idea: AdventureIdea,
        memberName: String,
        context: ModelContext,
        now: Date = .now
    ) -> Goal {
        let goal = Goal(
            title: idea.title,
            category: .qualityOfLife,
            targetAmount: idea.estimatedCost,
            currentAmount: 0,
            priority: 3,
            ownership: idea.category == .partner ? .partner : (idea.category == .mine ? .mine : .shared),
            boxValue: max(25, CurrencyMath.ceilToNearest(idea.estimatedCost / 20, step: 25)),
            createdDate: now
        )
        context.insert(goal)
        idea.status = .archived
        ActivityLog.post(
            context,
            title: "\(idea.title) became a goal",
            subtitle: "Too big for one cycle — now it's a quest.",
            member: memberName,
            type: .goalProgress,
            date: now
        )
        return goal
    }
}
