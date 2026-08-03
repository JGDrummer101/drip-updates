import Foundation

/// RULE 8 companion: the two-person approval state machine.
///
/// A proposal moves through: draft → awaitingApproval → approved → applied,
/// with declined as a terminal branch. Both members must approve before a
/// proposal can be applied; approval and application stay separate steps.
enum ApprovalState: String, Codable, CaseIterable, Sendable {
    case pending, approved, declined

    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .approved: "Approved"
        case .declined: "Declined"
        }
    }
}

enum ProposalStage: String, Codable, CaseIterable, Sendable {
    case draft, awaitingApproval, approved, declined, applied

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .awaitingApproval: "Awaiting Approval"
        case .approved: "Approved"
        case .declined: "Declined"
        case .applied: "Applied"
        }
    }
}

struct ApprovalPair: Codable, Equatable, Sendable {
    var first: ApprovalState
    var second: ApprovalState

    init(first: ApprovalState = .pending, second: ApprovalState = .pending) {
        self.first = first
        self.second = second
    }

    var bothApproved: Bool { first == .approved && second == .approved }
    var anyDeclined: Bool { first == .declined || second == .declined }

    /// Records one member's decision. Slot 0 is the first member, 1 the second.
    func recording(_ state: ApprovalState, forSlot slot: Int) -> ApprovalPair {
        var copy = self
        if slot == 0 { copy.first = state } else { copy.second = state }
        return copy
    }
}

enum ApprovalPolicy {

    /// The stage a submitted proposal should be in, given its approvals.
    static func stage(afterSubmissionWith pair: ApprovalPair) -> ProposalStage {
        if pair.anyDeclined { return .declined }
        if pair.bothApproved { return .approved }
        return .awaitingApproval
    }

    /// Application is only ever legal from `approved` with both approvals present.
    static func canApply(stage: ProposalStage, approvals: ApprovalPair) -> Bool {
        stage == .approved && approvals.bothApproved
    }
}
