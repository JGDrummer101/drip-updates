import SwiftUI
import SwiftData

/// Household configuration: names, season, defaults, payday schedule.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var households: [Household]

    var body: some View {
        Group {
            if let household = households.first {
                SettingsForm(household: household)
            } else {
                Text("No household yet — reset demo data from the More tab.")
                    .font(.questBody)
                    .foregroundStyle(Color.luTextDim)
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct SettingsForm: View {
    @Bindable var household: Household
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section("Household") {
                TextField("Household name", text: $household.name)
                TextField("Season name", text: $household.activeSeasonName)
                TextField("Season objective", text: $household.activeSeasonObjective, axis: .vertical)
            }

            Section("Members") {
                ForEach(household.orderedMembers, id: \.id) { member in
                    MemberNameRow(member: member)
                }
            }

            Section("Defaults") {
                HStack {
                    Text("Default splurge budget")
                    Spacer()
                    TextField(
                        "Amount",
                        value: $household.defaultSplurgeBudget,
                        format: .currency(code: "USD").precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                }
                HStack {
                    Text("Minimum buffer")
                    Spacer()
                    TextField(
                        "Amount",
                        value: $household.minimumBuffer,
                        format: .currency(code: "USD").precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                }
                Stepper("Target Extra Lives: \(household.targetExtraLives)", value: $household.targetExtraLives, in: 1...12)
            }

            Section {
                DatePicker(
                    "Anchor payday",
                    selection: Binding(
                        get: { household.paydayAnchor ?? .now },
                        set: { household.paydayAnchor = $0 }
                    ),
                    displayedComponents: .date
                )
                Stepper("Every \(household.paydayIntervalDays) days", value: $household.paydayIntervalDays, in: 7...31)
            } header: {
                Text("Payday Schedule")
            } footer: {
                Text("Any known payday works as the anchor — the schedule repeats from there and powers three-paycheck month detection.")
            }

            Section("About") {
                LabeledContent("Prototype", value: "Level Up Your Life v0.1")
                LabeledContent("Persistence", value: "SwiftData (on device)")
                Text("A shared budgeting adventure for every paycheck. Built for two, designed for life.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .onDisappear { try? context.save() }
    }
}

private struct MemberNameRow: View {
    @Bindable var member: HouseholdMember

    var body: some View {
        HStack(spacing: 10) {
            MemberSpriteView(configuration: member.spriteConfiguration, pixelSize: 3)
            TextField("Name", text: $member.displayName)
        }
    }
}
