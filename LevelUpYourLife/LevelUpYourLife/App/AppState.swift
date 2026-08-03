import Foundation
import Observation

/// Session-level UI state: which member the device is simulating, plus
/// app-wide celebration overlays. Nothing here persists.
@Observable
@MainActor
final class AppState {

    /// 0 = primary member, 1 = partner. Used by the approval workflow so one
    /// device can act as either adventurer.
    var viewingAsSlot: Int = 0

    /// Set after a confirmed pay cycle; RootView shows the toast briefly.
    var showCycleReadyToast: Bool = false

    /// Set when an XP commit crosses a level threshold.
    var celebrateLevel: Int?

    func viewingMember(in household: Household?) -> HouseholdMember? {
        guard let members = household?.orderedMembers, !members.isEmpty else { return nil }
        return members[min(viewingAsSlot, members.count - 1)]
    }

    func viewingMemberName(in household: Household?) -> String {
        viewingMember(in: household)?.displayName ?? "Adventurer"
    }
}
