import Foundation

/// SCREEN 4 engine: the adventure drawing.
///
/// Randomness is isolated behind `RandomNumberGenerator` so tests inject a
/// seeded generator and get reproducible draws. Weighting favors ideas that
/// have waited longer; picks avoid repeating the previous cycle's selection
/// whenever an alternative exists.
struct DrawCandidate: Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var cost: Decimal
    var timesSelected: Int
    var lastSelectedDate: Date?
    var createdDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        cost: Decimal = 0,
        timesSelected: Int = 0,
        lastSelectedDate: Date? = nil,
        createdDate: Date
    ) {
        self.id = id
        self.title = title
        self.cost = cost
        self.timesSelected = timesSelected
        self.lastSelectedDate = lastSelectedDate
        self.createdDate = createdDate
    }
}

struct DrawSelection: Equatable, Sendable {
    var mine: DrawCandidate?
    var partner: DrawCandidate?
    var shared: DrawCandidate?

    var totalCost: Decimal {
        [mine, partner, shared].compactMap { $0?.cost }.reduce(.zero, +)
    }
}

/// SplitMix64 — tiny, deterministic, seedable PRNG for testable draws.
struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum AdventureDrawEngine {

    /// Selection weight for one candidate. Older, less-picked ideas weigh more.
    /// Deterministic, so it can be unit tested directly.
    static func weight(for candidate: DrawCandidate, asOf now: Date) -> Double {
        var weight = 1.0
        if let last = candidate.lastSelectedDate {
            let cyclesSince = max(0.0, now.timeIntervalSince(last) / (14 * 24 * 3600))
            weight += min(4.0, cyclesSince) * 0.5
        } else {
            // Never selected: a full bonus plus a nudge for how long it has waited.
            weight += 1.0
            let cyclesWaiting = max(0.0, now.timeIntervalSince(candidate.createdDate) / (14 * 24 * 3600))
            weight += min(2.0, cyclesWaiting * 0.25)
        }
        weight += max(0.0, 1.0 - Double(candidate.timesSelected) * 0.25) * 0.5
        return weight
    }

    /// Weighted pick from a pool, excluding `excluding` (the previous cycle's
    /// selection) whenever the pool offers an alternative.
    static func pick(
        from pool: [DrawCandidate],
        excluding: UUID? = nil,
        asOf now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> DrawCandidate? {
        guard !pool.isEmpty else { return nil }
        var candidates = pool
        if let excluding, pool.count > 1 {
            let filtered = pool.filter { $0.id != excluding }
            if !filtered.isEmpty { candidates = filtered }
        }

        let weights = candidates.map { weight(for: $0, asOf: now) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return candidates.randomElement(using: &rng) }

        var roll = Double.random(in: 0..<total, using: &rng)
        for (candidate, weight) in zip(candidates, weights) {
            roll -= weight
            if roll < 0 { return candidate }
        }
        return candidates.last
    }

    /// Draws one idea per pool: mine, partner, shared.
    static func draw(
        mine: [DrawCandidate],
        partner: [DrawCandidate],
        shared: [DrawCandidate],
        previousMineID: UUID? = nil,
        previousPartnerID: UUID? = nil,
        previousSharedID: UUID? = nil,
        asOf now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> DrawSelection {
        DrawSelection(
            mine: pick(from: mine, excluding: previousMineID, asOf: now, using: &rng),
            partner: pick(from: partner, excluding: previousPartnerID, asOf: now, using: &rng),
            shared: pick(from: shared, excluding: previousSharedID, asOf: now, using: &rng)
        )
    }
}
