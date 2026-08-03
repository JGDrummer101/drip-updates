import SwiftUI
import SwiftData

/// Add/edit a goal: box values, priorities, ownership, milestone mode.
struct GoalEditorView: View {
    enum Mode {
        case create
        case edit(Goal)
    }

    var mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var category: GoalCategory = .qualityOfLife
    @State private var target: Decimal = 1_000
    @State private var current: Decimal = 0
    @State private var priority = 3
    @State private var ownership: GoalOwnership = .shared
    @State private var hasTargetDate = false
    @State private var targetDate: Date = .now
    @State private var boxChoice: Decimal = 100
    @State private var customBox: Decimal = 0
    @State private var useMilestones = false
    @State private var loaded = false

    static let boxOptions: [Decimal] = [25, 50, 100, 250, 500, 1_000]

    private var editedGoal: Goal? {
        if case let .edit(goal) = mode { return goal }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quest") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(GoalCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Ownership", selection: $ownership) {
                        ForEach(GoalOwnership.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Stepper("Priority: \(priority)", value: $priority, in: 1...9)
                }
                Section("Amounts") {
                    TextField("Target amount", value: $target, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                    TextField("Starting amount", value: $current, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                }
                Section("Box Visualization") {
                    Picker("Box value", selection: $boxChoice) {
                        ForEach(Self.boxOptions, id: \.self) { value in
                            Text(value.currencyLabel).tag(value)
                        }
                        Text("Custom").tag(Decimal(-1))
                    }
                    if boxChoice == -1 {
                        TextField("Custom box value", value: $customBox, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                    }
                    Toggle("Milestone mode (for large goals)", isOn: $useMilestones)
                    if useMilestones {
                        Text("Milestones are generated in six even steps to \(target.currencyLabel).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Timing") {
                    Toggle("Target date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Aim for", selection: $targetDate, displayedComponents: .date)
                    }
                }
                if let goal = editedGoal {
                    Section {
                        if goal.status == .active {
                            Button("Pause Goal") { goal.status = .paused; done() }
                        }
                        if goal.status == .paused {
                            Button("Resume Goal") { goal.status = .active; done() }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(editedGoal == nil ? "New Goal" : "Edit Goal")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.isEmpty || target <= 0)
                }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    private func load() {
        guard !loaded, let goal = editedGoal else { loaded = true; return }
        loaded = true
        title = goal.title
        category = goal.category
        target = goal.targetAmount
        current = goal.currentAmount
        priority = goal.priority
        ownership = goal.ownership
        hasTargetDate = goal.targetDate != nil
        targetDate = goal.targetDate ?? .now
        useMilestones = goal.useMilestones
        if Self.boxOptions.contains(goal.boxValue) {
            boxChoice = goal.boxValue
        } else {
            boxChoice = -1
            customBox = goal.boxValue
        }
    }

    private var resolvedBoxValue: Decimal {
        boxChoice == -1 ? max(customBox, 1) : boxChoice
    }

    private var generatedMilestones: [Decimal] {
        guard useMilestones, target > 0 else { return [] }
        let step = target / 6
        return (1...6).map { CurrencyMath.ceilToNearest(step * Decimal($0), step: 100) }
    }

    private func save() {
        if let goal = editedGoal {
            goal.title = title
            goal.category = category
            goal.targetAmount = target
            goal.currentAmount = current
            goal.priority = priority
            goal.ownership = ownership
            goal.targetDate = hasTargetDate ? targetDate : nil
            goal.boxValue = resolvedBoxValue
            goal.useMilestones = useMilestones
            goal.milestoneValues = generatedMilestones
            if goal.isFunded, goal.status == .active {
                goal.status = .funded
            }
        } else {
            let goal = Goal(
                title: title,
                category: category,
                targetAmount: target,
                currentAmount: current,
                priority: priority,
                targetDate: hasTargetDate ? targetDate : nil,
                ownership: ownership,
                status: GoalMath.isFunded(current: current, target: target) ? .funded : .active,
                boxValue: resolvedBoxValue,
                useMilestones: useMilestones,
                milestoneValues: generatedMilestones
            )
            context.insert(goal)
        }
        done()
    }

    private func done() {
        try? context.save()
        dismiss()
    }
}
