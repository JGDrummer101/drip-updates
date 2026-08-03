import Foundation

/// RULE 7: household level from lifetime allocated XP.
///
/// Lifetime XP only ever grows — spending goal funds never lowers it.
/// The curve is configurable; two presets ship:
///
/// - `standard`: tuned so the demo household ($18,400 lifetime XP) sits at
///   Level 14, matching the concept art. Gaps grow monotonically.
/// - `classic`: the coarse suggested curve ($0 / 5K / 15K / 35K / 75K / 150K).
///
/// Beyond the explicit table, thresholds extend forever: each new gap is the
/// previous gap × 1.25, rounded up to the nearest $100.
struct LevelCurve: Sendable {

    /// `thresholds[i]` is the lifetime XP needed to *be* level `i + 1`.
    /// Always starts at 0 (everyone is at least Level 1).
    let thresholds: [Decimal]

    static let standard = LevelCurve(thresholds: [
        0, 500, 1_200, 2_000, 2_900, 3_900, 5_000, 6_300,
        7_800, 9_500, 11_400, 13_500, 15_800, 18_300, 21_000,
    ])

    static let classic = LevelCurve(thresholds: [
        0, 5_000, 15_000, 35_000, 75_000, 150_000,
    ])

    init(thresholds: [Decimal]) {
        precondition(!thresholds.isEmpty, "A level curve needs at least one threshold")
        self.thresholds = thresholds
    }

    /// Lifetime XP required to reach a given level (1-based).
    /// Levels past the table extend with growing gaps.
    func threshold(forLevel level: Int) -> Decimal {
        guard level > 1 else { return .zero }
        if level <= thresholds.count {
            return thresholds[level - 1]
        }
        var last = thresholds[thresholds.count - 1]
        var gap = lastTableGap
        for _ in thresholds.count..<level {
            gap = CurrencyMath.ceilToNearest(gap * Decimal(125) / Decimal(100), step: 100)
            last += gap
        }
        return last
    }

    private var lastTableGap: Decimal {
        guard thresholds.count >= 2 else { return max(thresholds[0], 100) }
        return max(thresholds[thresholds.count - 1] - thresholds[thresholds.count - 2], 100)
    }

    /// Current level for a lifetime XP total. Never below 1, capped at 200.
    func level(forXP xp: Decimal) -> Int {
        let clamped = CurrencyMath.nonNegative(xp)
        var level = 1
        while level < 200, threshold(forLevel: level + 1) <= clamped {
            level += 1
        }
        return level
    }

    struct Progress: Equatable, Sendable {
        var level: Int
        /// XP earned inside the current level band.
        var earnedInLevel: Decimal
        /// Total XP span of the current level band.
        var neededForNextLevel: Decimal
        var fraction: Double
    }

    func progress(forXP xp: Decimal) -> Progress {
        let clamped = CurrencyMath.nonNegative(xp)
        let level = level(forXP: clamped)
        let floor = threshold(forLevel: level)
        let ceiling = threshold(forLevel: level + 1)
        let span = ceiling - floor
        let earned = clamped - floor
        let fraction = span > 0 ? min(1.0, max(0.0, (earned / span).doubleValue)) : 1.0
        return Progress(level: level, earnedInLevel: earned, neededForNextLevel: span, fraction: fraction)
    }
}
