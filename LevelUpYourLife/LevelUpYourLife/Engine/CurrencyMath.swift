import Foundation

/// Decimal helpers for currency math.
///
/// Everything in the finance engine works in `Decimal` to avoid binary
/// floating point drift. `Double` is only ever produced at the very edge,
/// for driving progress bars and weights.
enum CurrencyMath {

    /// Rounds a value to two fractional digits (cents) using plain rounding.
    static func roundedToCents(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    /// Rounds a value down to whole dollars.
    static func wholeDollarsFloor(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .down)
        return output
    }

    /// Rounds `value` upward to the nearest multiple of `step`.
    ///
    /// Exact multiples are preserved: `ceilToNearest(4500, step: 100) == 4500`,
    /// while `ceilToNearest(4501, step: 100) == 4600`.
    /// Non-positive values collapse to zero.
    static func ceilToNearest(_ value: Decimal, step: Decimal = 100) -> Decimal {
        guard value > 0, step > 0 else { return .zero }
        var quotient = value / step
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .up)
        return rounded * step
    }

    /// Clamps a value so it never drops below zero.
    static func nonNegative(_ value: Decimal) -> Decimal {
        value < 0 ? .zero : value
    }
}

extension Decimal {
    /// Bridge for UI work (progress fractions, chart heights). Never used for money math.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
