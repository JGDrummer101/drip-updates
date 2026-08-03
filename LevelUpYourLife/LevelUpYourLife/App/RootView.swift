import SwiftUI
import SwiftData

/// Five-tab shell plus app-wide celebration overlays.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Query private var households: [Household]

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack { HomeView() }
            }
            Tab("Budget", systemImage: "shield.lefthalf.filled") {
                NavigationStack { BudgetView() }
            }
            Tab("Adventure", systemImage: "dice.fill") {
                NavigationStack { AdventureView() }
            }
            Tab("Goals", systemImage: "star.fill") {
                NavigationStack { GoalsView() }
            }
            Tab("More", systemImage: "line.3.horizontal") {
                NavigationStack { MoreView() }
            }
        }
        .overlay(alignment: .top) {
            if appState.showCycleReadyToast {
                CycleReadyToast()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation(.easeOut(duration: 0.25)) {
                            appState.showCycleReadyToast = false
                        }
                    }
            }
        }
        .overlay {
            if let level = appState.celebrateLevel {
                LevelUpOverlay(
                    level: level,
                    members: households.first?.orderedMembers ?? []
                ) {
                    appState.celebrateLevel = nil
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.showCycleReadyToast)
    }
}
