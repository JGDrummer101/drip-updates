import Foundation

/// RULE 4: recurring biweekly payday math and three-paycheck-month detection.
///
/// The schedule is anchored to any known payday; every payday is
/// `anchor + k × intervalDays`. All math runs through an injected `Calendar`
/// so tests can pin time zone and behavior.
struct PaydaySchedule: Sendable {
    var anchor: Date
    var intervalDays: Int

    init(anchor: Date, intervalDays: Int = 14) {
        self.anchor = anchor
        self.intervalDays = max(1, intervalDays)
    }

    /// The most recent payday on or before `date`. If `date` precedes the
    /// anchor, the anchor itself is returned.
    func mostRecentPayday(onOrBefore date: Date, calendar: Calendar) -> Date {
        let anchorDay = calendar.startOfDay(for: anchor)
        let targetDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
        guard days >= 0 else { return anchorDay }
        let periods = days / intervalDays
        return calendar.date(byAdding: .day, value: periods * intervalDays, to: anchorDay) ?? anchorDay
    }

    /// The first payday strictly after `date`.
    func nextPayday(after date: Date, calendar: Calendar) -> Date {
        let recent = mostRecentPayday(onOrBefore: date, calendar: calendar)
        let candidate = calendar.date(byAdding: .day, value: intervalDays, to: recent) ?? recent
        if calendar.startOfDay(for: date) < calendar.startOfDay(for: recent) {
            // date precedes the anchor: the anchor is the next payday
            return recent
        }
        return candidate
    }

    /// Every payday inside the calendar month containing `date`.
    func paydays(inMonthContaining date: Date, calendar: Calendar) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        var results: [Date] = []
        var probe = mostRecentPayday(onOrBefore: interval.start, calendar: calendar)
        if probe < interval.start {
            probe = calendar.date(byAdding: .day, value: intervalDays, to: probe) ?? probe
        }
        while probe < interval.end {
            if probe >= interval.start {
                results.append(probe)
            }
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: probe) else { break }
            probe = next
        }
        return results
    }

    /// True when the month containing `date` holds three paydays.
    func isThreePaycheckMonth(monthContaining date: Date, calendar: Calendar) -> Bool {
        paydays(inMonthContaining: date, calendar: calendar).count >= 3
    }

    /// The start of the next month (moving forward from `date`, inclusive)
    /// that contains three paydays. Searches up to 24 months out.
    func nextThreePaycheckMonth(onOrAfter date: Date, calendar: Calendar) -> Date? {
        var probe = date
        for _ in 0..<24 {
            if isThreePaycheckMonth(monthContaining: probe, calendar: calendar) {
                return calendar.dateInterval(of: .month, for: probe)?.start
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: probe) else { return nil }
            probe = next
        }
        return nil
    }
}
