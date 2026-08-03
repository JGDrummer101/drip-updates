import Foundation
import Testing
@testable import LevelUpYourLife

@Suite("Adventure draw")
struct AdventureDrawTests {

    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func candidate(
        _ title: String,
        timesSelected: Int = 0,
        daysSinceSelected: Int? = nil,
        ageDays: Int = 120
    ) -> DrawCandidate {
        DrawCandidate(
            title: title,
            cost: 50,
            timesSelected: timesSelected,
            lastSelectedDate: daysSinceSelected.map { now.addingTimeInterval(-Double($0) * 86_400) },
            createdDate: now.addingTimeInterval(-Double(ageDays) * 86_400)
        )
    }

    @Test("Seeded draws are deterministic")
    func deterministic() {
        let pool = [candidate("A"), candidate("B"), candidate("C"), candidate("D")]
        var rng1 = SeededGenerator(seed: 42)
        var rng2 = SeededGenerator(seed: 42)
        let first = AdventureDrawEngine.pick(from: pool, asOf: now, using: &rng1)
        let second = AdventureDrawEngine.pick(from: pool, asOf: now, using: &rng2)
        #expect(first?.id == second?.id)
    }

    @Test("The previous cycle's pick is never repeated when alternatives exist")
    func avoidsRepeats() {
        let previous = candidate("Previous")
        let pool = [previous, candidate("B"), candidate("C")]
        for seed in UInt64(0)..<200 {
            var rng = SeededGenerator(seed: seed)
            let pick = AdventureDrawEngine.pick(
                from: pool, excluding: previous.id, asOf: now, using: &rng
            )
            #expect(pick?.id != previous.id)
        }
    }

    @Test("A single-idea pool may repeat — there is no alternative")
    func singleItemFallback() {
        let only = candidate("Only Option")
        var rng = SeededGenerator(seed: 7)
        let pick = AdventureDrawEngine.pick(
            from: [only], excluding: only.id, asOf: now, using: &rng
        )
        #expect(pick?.id == only.id)
    }

    @Test("Never-selected and long-waiting ideas weigh more")
    func staleness() {
        let fresh = candidate("Just Picked", timesSelected: 3, daysSinceSelected: 2)
        let stale = candidate("Waiting Forever", timesSelected: 0, daysSinceSelected: nil, ageDays: 200)
        let freshWeight = AdventureDrawEngine.weight(for: fresh, asOf: now)
        let staleWeight = AdventureDrawEngine.weight(for: stale, asOf: now)
        #expect(staleWeight > freshWeight)
    }

    @Test("A full draw selects one idea per pool")
    func fullDraw() {
        var rng = SeededGenerator(seed: 99)
        let selection = AdventureDrawEngine.draw(
            mine: [candidate("M1"), candidate("M2")],
            partner: [candidate("P1"), candidate("P2")],
            shared: [candidate("S1"), candidate("S2")],
            asOf: now,
            using: &rng
        )
        #expect(selection.mine != nil)
        #expect(selection.partner != nil)
        #expect(selection.shared != nil)
        #expect(selection.totalCost == 150)
    }

    @Test("Empty pools yield empty slots, never a crash")
    func emptyPools() {
        var rng = SeededGenerator(seed: 1)
        let selection = AdventureDrawEngine.draw(
            mine: [], partner: [], shared: [candidate("S1")],
            asOf: now, using: &rng
        )
        #expect(selection.mine == nil)
        #expect(selection.partner == nil)
        #expect(selection.shared != nil)
    }
}
