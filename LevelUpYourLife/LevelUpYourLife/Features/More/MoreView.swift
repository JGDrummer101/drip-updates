import SwiftUI
import SwiftData

/// The More tab: everything that isn't a daily-driver screen.
struct MoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]

    @State private var confirmReset = false

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
        List {
            Section {
                Picker("Viewing as", selection: $appState.viewingAsSlot) {
                    Text(memberNames[0]).tag(0)
                    Text(memberNames[1]).tag(1)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Simulating Device Owner")
            } footer: {
                Text("The prototype runs on one device — switch here to act as either adventurer.")
            }

            Section("Tools") {
                NavigationLink { DecisionLabView() } label: {
                    Label("Decision Lab", systemImage: "testtube.2")
                }
                NavigationLink { ExtraLivesView() } label: {
                    Label("Extra Lives", systemImage: "heart.fill")
                }
                NavigationLink { DecisionsInboxView() } label: {
                    Label("Household Decisions", systemImage: "person.2.fill")
                }
                NavigationLink { SpriteCustomizationView() } label: {
                    Label("Sprite Customization", systemImage: "person.crop.square")
                }
            }

            Section("Records") {
                NavigationLink { HistoryView() } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink { SettingsView() } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Label("Reset Demo Data", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Restores the sample household, budget, goals, and history.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("More")
        .toolbarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset all demo data?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                SeedService.resetDemoData(context: context)
                appState.viewingAsSlot = 0
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current data is deleted and the sample adventure returns.")
        }
    }
}
