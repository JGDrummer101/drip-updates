import SwiftUI
import SwiftData

/// SCREEN 5: goals grouped by category, with the XP header and trophy room.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query(sort: \Goal.priority) private var goals: [Goal]

    @State private var allocating = false
    @State private var editingGoal: Goal?
    @State private var addingGoal = false
    @State private var obtainPulse = 0

    private var household: Household? { households.first }
    private var currentCycle: PayCycle? { FinanceService.currentCycle(from: cycles) }
    private var openGoals: [Goal] {
        goals.filter { $0.status == .active || $0.status == .funded || $0.status == .paused }
    }
    private var trophyGoals: [Goal] {
        goals.filter { $0.status == .obtained || $0.status == .completed }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                headerPanel

                ForEach(categoriesInUse, id: \.self) { category in
                    GoldSectionHeader(category.displayName, icon: "star.fill")
                    ForEach(openGoals.filter { $0.category == category }, id: \.id) { goal in
                        GoalProgressCard(goal: goal) {
                            markObtained(goal)
                        }
                        .onTapGesture { editingGoal = goal }
                        .accessibilityHint("Double tap to edit \(goal.title)")
                    }
                }

                if openGoals.isEmpty {
                    EmptyStateQuestCard(
                        title: "No Quests Yet",
                        message: "Every adventure needs a destination. Add your first goal.",
                        actionTitle: "Add Goal",
                        action: { addingGoal = true }
                    )
                }

                if !trophyGoals.isEmpty {
                    GoldSectionHeader("Trophy Room", icon: "trophy.fill")
                    ForEach(trophyGoals, id: \.id) { goal in
                        HStack(spacing: 8) {
                            PixelIcon(.star, size: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(goal.title)
                                    .font(.questHeading)
                                    .foregroundStyle(Color.luText)
                                if let date = goal.completedDate {
                                    Text("Obtained \(date.formatted(.dateTime.month(.abbreviated).year()))")
                                        .font(.questFootnote)
                                        .foregroundStyle(Color.luTextDim)
                                }
                            }
                            Spacer()
                            CurrencyText(goal.targetAmount, font: .questHeading, color: .luGoldBright)
                        }
                        .padding(10)
                        .background(Color.luPanel.opacity(0.7))
                        .pixelBorder(Color.luGoldDim.opacity(0.7), lineWidth: 1)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Goals")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Goal", systemImage: "plus") { addingGoal = true }
            }
        }
        .sheet(isPresented: $allocating) {
            XPAllocationView()
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorView(mode: .edit(goal))
        }
        .sheet(isPresented: $addingGoal) {
            GoalEditorView(mode: .create)
        }
        .sensoryFeedback(.success, trigger: obtainPulse)
    }

    private var headerPanel: some View {
        JRPGPanel {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Available XP")
                            .pixelText(.questLabel, color: .luTextDim)
                        Text((currentCycle?.xpRemaining ?? 0).xpLabel)
                            .font(.questTitle)
                            .monospacedDigit()
                            .foregroundStyle(Color.luGoldBright)
                    }
                    Spacer()
                    StatusChip(text: "Level \(household?.currentLevel ?? 1)", color: .luRoyal)
                }
                PrimaryQuestButton(title: "Allocate XP", icon: "star.fill") {
                    allocating = true
                }
            }
        }
    }

    private var categoriesInUse: [GoalCategory] {
        let used = Set(openGoals.map(\.category))
        return GoalCategory.allCases
            .filter { used.contains($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func markObtained(_ goal: Goal) {
        XPService.markObtained(
            goal,
            memberName: appState.viewingMemberName(in: household),
            context: context
        )
        try? context.save()
        obtainPulse += 1
    }
}
