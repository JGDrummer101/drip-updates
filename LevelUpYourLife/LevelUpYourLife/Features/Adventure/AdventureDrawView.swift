import SwiftUI
import SwiftData

/// The draw ritual: three reward cards, a budget verdict, and the choices
/// that follow — lock in, replace one, reroll, save, or convert to a goal.
struct AdventureDrawView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var households: [Household]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var ideas: [AdventureIdea]
    @Query(sort: \AdventureDraw.createdDate, order: .reverse) private var draws: [AdventureDraw]

    @State private var selection: DrawSelection?
    @State private var revealedCount = 0
    @State private var drawPulse = 0
    @State private var showFreeMode = false
    @State private var showReplaceDialog = false
    @State private var showConvertDialog = false

    private var household: Household? { households.first }
    private var currentCycle: PayCycle? { FinanceService.currentCycle(from: cycles) }
    private var budget: Decimal { currentCycle?.splurgeRemaining ?? 0 }

    private var memberNames: (mine: String, partner: String) {
        let members = household?.orderedMembers ?? []
        return (
            members.first?.displayName ?? "Member 1",
            members.count > 1 ? members[1].displayName : "Member 2"
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: QuestMetrics.cardSpacing) {
                    if let selection {
                        resultView(selection)
                    } else {
                        introView
                    }
                }
                .padding(QuestMetrics.screenPadding)
            }
            .questScreen()
            .navigationTitle("Adventure Draw")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: drawPulse)
        .sheet(isPresented: $showFreeMode) {
            FreeAdventureView()
        }
    }

    private var introView: some View {
        VStack(spacing: QuestMetrics.cardSpacing) {
            JRPGPanel {
                VStack(spacing: 10) {
                    PairSpriteView(members: household?.orderedMembers ?? [], pixelSize: 6)
                    Text("Let fate — and your budget — decide the fun.")
                        .font(.questBody)
                        .foregroundStyle(Color.luTextDim)
                        .multilineTextAlignment(.center)
                    LedgerRow(label: "Adventure Budget", amount: budget, emphasis: true)
                }
            }
            PrimaryQuestButton(title: "Draw", icon: "dice.fill") { performDraw() }
            SecondaryMenuButton(title: "Not enough budget? Draw a free adventure instead.", icon: "leaf.fill") {
                showFreeMode = true
            }
        }
    }

    @ViewBuilder
    private func resultView(_ selection: DrawSelection) -> some View {
        let total = selection.totalCost
        let overBudget = total > budget

        VStack(spacing: QuestMetrics.cardSpacing) {
            HStack(spacing: 10) {
                AdventureRewardCard(
                    ownerLabel: memberNames.mine,
                    title: selection.mine?.title ?? "—",
                    cost: selection.mine?.cost ?? 0,
                    revealed: revealedCount > 0
                )
                AdventureRewardCard(
                    ownerLabel: memberNames.partner,
                    title: selection.partner?.title ?? "—",
                    cost: selection.partner?.cost ?? 0,
                    revealed: revealedCount > 1
                )
                AdventureRewardCard(
                    ownerLabel: "Together",
                    title: selection.shared?.title ?? "—",
                    cost: selection.shared?.cost ?? 0,
                    revealed: revealedCount > 2
                )
            }

            JRPGPanel {
                VStack(spacing: 6) {
                    LedgerRow(label: "Combined Total", amount: total, emphasis: true)
                    LedgerRow(label: "Adventure Budget", amount: budget)
                    LedgerRow(
                        label: overBudget ? "Over Budget" : "Remaining After",
                        amount: overBudget ? total - budget : budget - total,
                        color: overBudget ? .luRed : .luSuccess
                    )
                    if overBudget {
                        Text("Not enough budget? Draw a free adventure instead — or convert the big one into a goal.")
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if revealedCount >= 3 {
                VStack(spacing: 8) {
                    PrimaryQuestButton(title: "Lock In Adventure", icon: "lock.fill") { lockIn(selection) }
                    HStack(spacing: 8) {
                        SecondaryMenuButton(title: "Replace One", icon: "arrow.2.squarepath") {
                            showReplaceDialog = true
                        }
                        SecondaryMenuButton(title: "Reroll All", icon: "dice") { reroll() }
                    }
                    HStack(spacing: 8) {
                        SecondaryMenuButton(title: "Save for Later", icon: "bookmark") { saveForLater(selection) }
                        SecondaryMenuButton(title: "Convert to Goal", icon: "star") {
                            showConvertDialog = true
                        }
                    }
                    if overBudget {
                        SecondaryMenuButton(title: "Draw a Free Adventure Instead", icon: "leaf.fill") {
                            showFreeMode = true
                        }
                    }
                }
            }
        }
        .confirmationDialog("Replace which pick?", isPresented: $showReplaceDialog, titleVisibility: .visible) {
            Button("\(memberNames.mine): \(selection.mine?.title ?? "—")") { replace(.mine) }
            Button("\(memberNames.partner): \(selection.partner?.title ?? "—")") { replace(.partner) }
            Button("Together: \(selection.shared?.title ?? "—")") { replace(.shared) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Convert which item into a goal?", isPresented: $showConvertDialog, titleVisibility: .visible) {
            ForEach([selection.mine, selection.partner, selection.shared].compactMap { $0 }, id: \.id) { pick in
                Button("\(pick.title) (\(pick.cost.currencyLabel))") { convert(pick) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Actions

    private func performDraw() {
        var rng = SystemRandomNumberGenerator()
        let result = AdventureService.performDraw(
            ideas: ideas,
            previous: AdventureService.latestDraw(draws),
            using: &rng
        )
        drawPulse += 1
        selection = result
        revealedCount = 0
        revealCards()
    }

    private func revealCards() {
        if reduceMotion {
            revealedCount = 3
            return
        }
        Task { @MainActor in
            for step in 1...3 {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.spring(duration: 0.3)) {
                    revealedCount = step
                }
            }
        }
    }

    private func reroll() {
        if let old = selection {
            let record = AdventureService.saveForLater(
                selection: old,
                cycle: currentCycle,
                memberNames: memberNames,
                context: context
            )
            record.resultStatus = .rerolled
        }
        performDraw()
    }

    private enum Slot { case mine, partner, shared }

    private func replace(_ slot: Slot) {
        guard var current = selection else { return }
        var rng = SystemRandomNumberGenerator()
        switch slot {
        case .mine:
            current.mine = AdventureService.redrawSlot(
                category: .mine, ideas: ideas, current: current.mine, using: &rng
            ) ?? current.mine
        case .partner:
            current.partner = AdventureService.redrawSlot(
                category: .partner, ideas: ideas, current: current.partner, using: &rng
            ) ?? current.partner
        case .shared:
            current.shared = AdventureService.redrawSlot(
                category: .shared, ideas: ideas, current: current.shared, using: &rng
            ) ?? current.shared
        }
        drawPulse += 1
        selection = current
    }

    private func lockIn(_ selection: DrawSelection) {
        AdventureService.lockIn(
            selection: selection,
            freePick: nil,
            ideas: ideas,
            cycle: currentCycle,
            memberNames: memberNames,
            budget: budget,
            context: context
        )
        try? context.save()
        drawPulse += 1
        dismiss()
    }

    private func saveForLater(_ selection: DrawSelection) {
        AdventureService.saveForLater(
            selection: selection,
            cycle: currentCycle,
            memberNames: memberNames,
            context: context
        )
        try? context.save()
        dismiss()
    }

    private func convert(_ pick: DrawCandidate) {
        guard let idea = ideas.first(where: { $0.id == pick.id }) else { return }
        AdventureService.convertToGoal(
            idea,
            memberName: appState.viewingMemberName(in: household),
            context: context
        )
        try? context.save()
        dismiss()
    }
}
