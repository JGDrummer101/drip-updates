import SwiftUI
import SwiftData

/// Free Adventure Mode: five categories of zero-dollar quests, a weighted
/// draw, and a lifetime completion counter.
struct FreeAdventureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query private var households: [Household]
    @Query private var ideas: [AdventureIdea]

    @State private var selectedCategory: FreeAdventureCategory?
    @State private var pick: AdventureIdea?
    @State private var completePulse = 0
    @State private var addingIdea = false

    private var household: Household? { households.first }
    private var freeIdeas: [AdventureIdea] {
        ideas.filter { $0.category == .free && $0.status == .active }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: QuestMetrics.cardSpacing) {
                    JRPGPanel {
                        VStack(spacing: 8) {
                            PixelIcon(.star, size: 26)
                            Text("The best adventures are free.")
                                .font(.questBody)
                                .foregroundStyle(Color.luTextDim)
                            Text("\(household?.freeAdventuresCompleted ?? 0) free adventures completed together")
                                .pixelText(.questLabel, color: .luGoldBright)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    categoryChips

                    PrimaryQuestButton(title: "Draw Free Adventure", icon: "leaf.fill") { draw() }

                    if let pick {
                        AdventureRewardCard(
                            ownerLabel: pick.freeCategory?.displayName ?? "Free",
                            title: pick.title,
                            cost: 0,
                            revealed: true
                        )
                        PrimaryQuestButton(title: "We Did This One!", icon: "flag.checkered", role: .gold) {
                            complete(pick)
                        }
                    }

                    GoldSectionHeader("Free Idea Pool", icon: "leaf.fill")
                    ForEach(filteredIdeas, id: \.id) { idea in
                        HStack(spacing: 8) {
                            Image(systemName: idea.freeCategory?.iconName ?? "leaf.fill")
                                .font(.footnote)
                                .foregroundStyle(Color.luForest)
                                .frame(width: 18)
                                .accessibilityHidden(true)
                            Text(idea.title)
                                .font(.questBody)
                                .foregroundStyle(Color.luText)
                            Spacer()
                            if idea.timesSelected > 0 {
                                Text("\(idea.timesSelected)×")
                                    .font(.questFootnote)
                                    .foregroundStyle(Color.luTextDim)
                            }
                        }
                        .padding(10)
                        .background(Color.luPanel.opacity(0.7))
                        .pixelBorder(Color.luForestDeep, lineWidth: 1)
                        .accessibilityElement(children: .combine)
                    }

                    SecondaryMenuButton(title: "Add Free Idea", icon: "plus") { addingIdea = true }
                }
                .padding(QuestMetrics.screenPadding)
            }
            .questScreen()
            .navigationTitle("Free Adventures")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: completePulse)
        .sheet(isPresented: $addingIdea) {
            AdventureIdeaEditorView(mode: .create(defaultCategory: .free))
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Any", isOn: selectedCategory == nil) { selectedCategory = nil }
                ForEach(FreeAdventureCategory.allCases, id: \.self) { category in
                    chip(title: category.displayName, isOn: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.questLabel)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? Color.luNight : Color.luGoldBright)
                .background(isOn ? Color.luGoldBright : Color.luPanel)
                .pixelBorder(Color.luGoldDim, lineWidth: 1)
        }
        .buttonStyle(QuestPressStyle())
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var filteredIdeas: [AdventureIdea] {
        guard let selectedCategory else { return freeIdeas }
        return freeIdeas.filter { $0.freeCategory == selectedCategory }
    }

    private func draw() {
        var rng = SystemRandomNumberGenerator()
        pick = AdventureService.drawFree(
            ideas: ideas,
            category: selectedCategory,
            excluding: pick?.id,
            using: &rng
        )
        completePulse += 1
    }

    private func complete(_ idea: AdventureIdea) {
        AdventureService.completeFreeAdventure(
            idea,
            household: household,
            memberName: appState.viewingMemberName(in: household),
            context: context
        )
        try? context.save()
        completePulse += 1
        pick = nil
    }
}
