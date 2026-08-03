import SwiftUI
import SwiftData

/// Full proposal detail: impact, notes, approvals, and the separate
/// approve → apply steps. Only the simulated current member can sign.
struct ProposalDetailView: View {
    @Bindable var proposal: FinancialProposal

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query private var items: [BudgetItem]
    @Query private var goals: [Goal]

    @State private var requestingChanges = false
    @State private var changeNote = ""
    @State private var decisionPulse = 0

    private var household: Household? { households.first }
    private var mySlot: Int { appState.viewingAsSlot }
    private var myName: String { appState.viewingMemberName(in: household) }
    private var myState: ApprovalState {
        mySlot == 0 ? proposal.approvals.first : proposal.approvals.second
    }
    private var memberNames: [String] {
        let members = household?.orderedMembers ?? []
        return [
            members.first?.displayName ?? "Member 1",
            members.count > 1 ? members[1].displayName : "Member 2",
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                JRPGPanel(proposal.title, titleIcon: "person.2.fill") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(proposal.proposalType.displayName)
                            .pixelText(.questLabel, color: .luGoldBright)
                        if !proposal.details.isEmpty {
                            Text(proposal.details)
                                .font(.questBody)
                                .foregroundStyle(Color.luText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 10) {
                            if let recurring = proposal.recurringAmount, recurring != 0 {
                                Label("\(recurring.signedCurrencyLabel)/mo", systemImage: "arrow.triangle.2.circlepath")
                            }
                            if let oneTime = proposal.oneTimeAmount, oneTime > 0 {
                                Label("\(oneTime.currencyLabel) once", systemImage: "bag.fill")
                            }
                        }
                        .font(.questFootnote)
                        .monospacedDigit()
                        .foregroundStyle(Color.luTextDim)
                        Text("Submitted by \(proposal.submittedBy) · Effective \(proposal.effectiveDate.formatted(.dateTime.month(.wide).day()))")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                    }
                }

                if let impact = proposal.impact {
                    ImpactComparisonCard(impact: impact)
                }

                approvalsPanel

                if !proposal.discussionNotes.isEmpty {
                    JRPGPanel("Discussion", titleIcon: "bubble.left.and.bubble.right.fill") {
                        Text(proposal.discussionNotes)
                            .font(.questBody)
                            .foregroundStyle(Color.luText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                actionButtons
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Proposal")
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: decisionPulse)
        .alert("Request Changes", isPresented: $requestingChanges) {
            TextField("What should change?", text: $changeNote)
            Button("Send Back") {
                ProposalService.requestChanges(
                    for: proposal, note: changeNote, memberName: myName, context: context
                )
                try? context.save()
                changeNote = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The proposal returns to draft with your note, and approvals reset.")
        }
    }

    private var approvalsPanel: some View {
        JRPGPanel("Approvals", titleIcon: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ApprovalStatusBadge(state: proposal.approvals.first, name: memberNames[0])
                    ApprovalStatusBadge(state: proposal.approvals.second, name: memberNames[1])
                }
                if proposal.approvals.bothApproved {
                    HStack(spacing: 6) {
                        PixelIcon(.star, size: 16)
                        Text("Both adventurers approved this decision.")
                            .font(.questHeading)
                            .foregroundStyle(Color.luSuccess)
                    }
                } else if proposal.stage == .awaitingApproval || proposal.stage == .draft {
                    Text("Viewing as \(myName). Only the member being simulated can submit their approval.")
                        .font(.questFootnote)
                        .foregroundStyle(Color.luTextDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch proposal.stage {
        case .awaitingApproval, .draft:
            if myState == .pending {
                VStack(spacing: 8) {
                    PrimaryQuestButton(title: "Approve as \(myName)", icon: "checkmark.seal.fill") {
                        decide(.approved)
                    }
                    HStack(spacing: 8) {
                        SecondaryMenuButton(title: "Decline", icon: "xmark") { decide(.declined) }
                        SecondaryMenuButton(title: "Request Changes", icon: "arrow.uturn.left") {
                            requestingChanges = true
                        }
                    }
                }
            } else {
                Text("You've signed. Waiting on \(memberNames[1 - mySlot]) — switch the viewer above to simulate them.")
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                    .multilineTextAlignment(.center)
            }

        case .approved:
            VStack(spacing: 8) {
                PrimaryQuestButton(title: "Apply to Budget", icon: "arrow.down.doc.fill", role: .gold) {
                    apply()
                }
                Text("Approval and application stay separate, so nothing lands by accident.")
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                    .multilineTextAlignment(.center)
            }

        case .declined:
            Text("Declined. It can be revisited any time from a fresh proposal.")
                .font(.questFootnote)
                .foregroundStyle(Color.luTextDim)

        case .applied:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.luSuccess)
                    .accessibilityHidden(true)
                Text("Applied \(proposal.appliedDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "")")
                    .font(.questHeading)
                    .foregroundStyle(Color.luSuccess)
            }
        }
    }

    private func decide(_ state: ApprovalState) {
        ProposalService.record(
            state,
            for: proposal,
            memberSlot: mySlot,
            memberName: myName,
            context: context
        )
        try? context.save()
        decisionPulse += 1
    }

    private func apply() {
        ProposalService.apply(
            proposal,
            household: household,
            items: items,
            goals: goals,
            memberName: myName,
            context: context
        )
        try? context.save()
        decisionPulse += 1
    }
}
