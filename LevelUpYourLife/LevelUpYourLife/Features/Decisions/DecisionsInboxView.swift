import SwiftUI
import SwiftData

/// SCREEN 9: the shared approval inbox, with a device-side user switch so
/// one phone can act as either adventurer.
struct DecisionsInboxView: View {
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query(sort: \FinancialProposal.submittedDate, order: .reverse) private var proposals: [FinancialProposal]

    private var household: Household? { households.first }
    private var memberNames: [String] {
        let members = household?.orderedMembers ?? []
        return [
            members.first?.displayName ?? "Member 1",
            members.count > 1 ? members[1].displayName : "Member 2",
        ]
    }

    var body: some View {
        @Bindable var appState = appState
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                JRPGPanel("Viewing As", titleIcon: "person.crop.square") {
                    Picker("Viewing as", selection: $appState.viewingAsSlot) {
                        Text(memberNames[0]).tag(0)
                        Text(memberNames[1]).tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                section("Awaiting My Approval", proposals: awaitingMine, emptyText: "Nothing needs your signature right now.")
                section("Awaiting Partner Approval", proposals: awaitingPartner, emptyText: nil)
                section("Approved", proposals: byStage(.approved), emptyText: nil)
                section("Declined", proposals: byStage(.declined), emptyText: nil)
                section("Applied", proposals: byStage(.applied), emptyText: nil)

                if proposals.isEmpty {
                    EmptyStateQuestCard(
                        title: "No Decisions Yet",
                        message: "Proposals from the Decision Lab and budget changes will gather here for both approvals.",
                        actionTitle: nil,
                        action: nil
                    )
                }
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Household Decisions")
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var mySlot: Int { appState.viewingAsSlot }

    private func approvalState(_ proposal: FinancialProposal, slot: Int) -> ApprovalState {
        slot == 0 ? proposal.approvals.first : proposal.approvals.second
    }

    private var awaitingMine: [FinancialProposal] {
        proposals.filter {
            ($0.stage == .awaitingApproval || $0.stage == .draft)
                && approvalState($0, slot: mySlot) == .pending
        }
    }

    private var awaitingPartner: [FinancialProposal] {
        proposals.filter {
            ($0.stage == .awaitingApproval || $0.stage == .draft)
                && approvalState($0, slot: mySlot) != .pending
                && approvalState($0, slot: 1 - mySlot) == .pending
        }
    }

    private func byStage(_ stage: ProposalStage) -> [FinancialProposal] {
        proposals.filter { $0.stage == stage }
    }

    @ViewBuilder
    private func section(_ title: String, proposals: [FinancialProposal], emptyText: String?) -> some View {
        if !proposals.isEmpty || emptyText != nil {
            GoldSectionHeader(title, icon: "person.2.fill")
            if proposals.isEmpty, let emptyText {
                Text(emptyText)
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(proposals, id: \.id) { proposal in
                NavigationLink {
                    ProposalDetailView(proposal: proposal)
                } label: {
                    ProposalCard(proposal: proposal, memberNames: memberNames)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Summary card in the inbox list.
struct ProposalCard: View {
    var proposal: FinancialProposal
    var memberNames: [String]

    var body: some View {
        JRPGPanel {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(proposal.title)
                        .font(.questHeading)
                        .foregroundStyle(Color.luText)
                    Spacer()
                    if let impact = proposal.impact {
                        StatusChip(text: impact.impactLevel.displayName, color: impactColor(impact.impactLevel))
                    }
                }
                HStack(spacing: 8) {
                    if let recurring = proposal.recurringAmount, recurring != 0 {
                        Text("\(recurring.signedCurrencyLabel)/mo")
                    }
                    if let oneTime = proposal.oneTimeAmount, oneTime > 0 {
                        Text("\(oneTime.currencyLabel) once")
                    }
                    Text("· Effective \(proposal.effectiveDate.formatted(.dateTime.month(.abbreviated).day()))")
                }
                .font(.questFootnote)
                .monospacedDigit()
                .foregroundStyle(Color.luTextDim)
                Text("Submitted by \(proposal.submittedBy) · \(proposal.submittedDate.formatted(.relative(presentation: .named)))")
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                HStack(spacing: 6) {
                    ApprovalStatusBadge(state: proposal.approvals.first, name: memberNames[0])
                    ApprovalStatusBadge(state: proposal.approvals.second, name: memberNames[1])
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func impactColor(_ level: ImpactLevel) -> Color {
        switch level {
        case .low: .luForest
        case .moderate: .luGoldDim
        case .high: .luRed
        }
    }
}
