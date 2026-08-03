import SwiftUI
import SwiftData

/// SCREEN 4: adventure idea pools and the cycle draw.
struct AdventureView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var ideas: [AdventureIdea]

    @State private var selectedPool: AdventureCategory = .mine
    @State private var editingIdea: AdventureIdea?
    @State private var addingIdea = false
    @State private var showingDraw = false
    @State private var showingFree = false

    private var household: Household? { households.first }
    private var currentCycle: PayCycle? { FinanceService.currentCycle(from: cycles) }

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                budgetPanel

                PrimaryQuestButton(title: "Draw This Cycle's Adventure", icon: "dice.fill") {
                    showingDraw = true
                }
                SecondaryMenuButton(title: "Free Adventure Mode", icon: "leaf.fill") {
                    showingFree = true
                }

                Picker("Pool", selection: $selectedPool) {
                    Text("Mine").tag(AdventureCategory.mine)
                    Text("Partner").tag(AdventureCategory.partner)
                    Text("Ours").tag(AdventureCategory.shared)
                }
                .pickerStyle(.segmented)

                poolSection

                waitingRoomSection
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Adventure")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Idea", systemImage: "plus") { addingIdea = true }
            }
        }
        .sheet(isPresented: $showingDraw) {
            AdventureDrawView()
        }
        .sheet(isPresented: $showingFree) {
            FreeAdventureView()
        }
        .sheet(item: $editingIdea) { idea in
            AdventureIdeaEditorView(mode: .edit(idea))
        }
        .sheet(isPresented: $addingIdea) {
            AdventureIdeaEditorView(mode: .create(defaultCategory: selectedPool))
        }
    }

    private var budgetPanel: some View {
        JRPGPanel("Adventure Budget", titleIcon: "dice.fill") {
            VStack(spacing: 6) {
                LedgerRow(label: "This Cycle's Splurge", amount: currentCycle?.splurgeReserved ?? 0)
                LedgerRow(
                    label: "Still Available",
                    amount: currentCycle?.splurgeRemaining ?? 0,
                    emphasis: true,
                    color: .luSuccess
                )
            }
        }
    }

    @ViewBuilder
    private var poolSection: some View {
        let active = AdventureService.activeIdeas(ideas, in: selectedPool)
        if active.isEmpty {
            EmptyStateQuestCard(
                title: "Empty Pool",
                message: "Add up to five ideas fate can choose from.",
                actionTitle: "Add Idea",
                action: { addingIdea = true }
            )
        } else {
            VStack(spacing: 8) {
                ForEach(active, id: \.id) { idea in
                    ideaRow(idea)
                }
                Text("\(active.count) of \(AdventureService.activePoolLimit) active slots used")
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
            }
        }
    }

    @ViewBuilder
    private var waitingRoomSection: some View {
        let waiting = AdventureService.waitingRoomIdeas(ideas).filter {
            $0.category == selectedPool
        }
        if !waiting.isEmpty {
            GoldSectionHeader("Waiting Room", icon: "hourglass")
            VStack(spacing: 8) {
                ForEach(waiting, id: \.id) { idea in
                    ideaRow(idea)
                }
            }
        }
    }

    private func ideaRow(_ idea: AdventureIdea) -> some View {
        JRPGPanel {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.title)
                        .font(.questHeading)
                        .foregroundStyle(Color.luText)
                    HStack(spacing: 6) {
                        Text("By \(idea.submittedBy)")
                        if idea.timesSelected > 0 {
                            Text("· Drawn \(idea.timesSelected)×")
                        }
                        if idea.status == .waitingRoom {
                            Text("· Waiting Room")
                        }
                    }
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                }
                Spacer()
                CurrencyText(idea.estimatedCost, font: .questValue, color: .luGoldBright)
            }
        }
        .onTapGesture { editingIdea = idea }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editingIdea = idea }
            if idea.status == .waitingRoom {
                Button("Promote to Active", systemImage: "arrow.up.circle") { promote(idea) }
            }
            Button("Archive", systemImage: "archivebox", role: .destructive) {
                idea.status = .archived
                try? context.save()
            }
        }
        .accessibilityHint("Double tap to edit \(idea.title)")
    }

    private func promote(_ idea: AdventureIdea) {
        let active = AdventureService.activeIdeas(ideas, in: idea.category)
        guard active.count < AdventureService.activePoolLimit else { return }
        idea.status = .active
        try? context.save()
    }
}

/// Add/edit one adventure idea.
struct AdventureIdeaEditorView: View {
    enum Mode {
        case create(defaultCategory: AdventureCategory)
        case edit(AdventureIdea)
    }

    var mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]
    @Query private var ideas: [AdventureIdea]

    @State private var title = ""
    @State private var cost: Decimal = 0
    @State private var category: AdventureCategory = .mine
    @State private var freeCategory: FreeAdventureCategory = .atHome
    @State private var notes = ""
    @State private var loaded = false

    private var editedIdea: AdventureIdea? {
        if case let .edit(idea) = mode { return idea }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Idea") {
                    TextField("Title", text: $title)
                    Picker("Pool", selection: $category) {
                        ForEach(AdventureCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if category == .free {
                        Picker("Free Category", selection: $freeCategory) {
                            ForEach(FreeAdventureCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    } else {
                        TextField(
                            "Estimated cost",
                            value: $cost,
                            format: .currency(code: "USD").precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                    }
                }
                Section("Notes") {
                    TextField("Anything future-you should know", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if editedIdea == nil, category != .free, poolIsFull {
                    Section {
                        Label("This pool already has five active ideas — the new one starts in the Waiting Room.", systemImage: "hourglass")
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(editedIdea == nil ? "New Adventure Idea" : "Edit Idea")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    private var poolIsFull: Bool {
        AdventureService.activeIdeas(ideas, in: category).count >= AdventureService.activePoolLimit
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case let .create(defaultCategory):
            category = defaultCategory
        case let .edit(idea):
            title = idea.title
            cost = idea.estimatedCost
            category = idea.category
            freeCategory = idea.freeCategory ?? .atHome
            notes = idea.notes
        }
    }

    private func save() {
        let memberName = appState.viewingMemberName(in: households.first)
        if let idea = editedIdea {
            idea.title = title
            idea.estimatedCost = category == .free ? 0 : cost
            idea.category = category
            idea.freeCategory = category == .free ? freeCategory : nil
            idea.notes = notes
        } else {
            let idea = AdventureIdea(
                title: title,
                estimatedCost: category == .free ? 0 : cost,
                category: category,
                freeCategory: category == .free ? freeCategory : nil,
                status: AdventureService.statusForNewIdea(in: category, existing: ideas),
                submittedBy: memberName,
                notes: notes
            )
            context.insert(idea)
            ActivityLog.post(
                context,
                title: "\(memberName) added \(title) to \(category.displayName)",
                subtitle: category == .free ? freeCategory.displayName : cost.currencyLabel,
                member: memberName,
                type: .adventureAdded
            )
        }
        try? context.save()
        dismiss()
    }
}
