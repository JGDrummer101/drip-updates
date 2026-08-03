import SwiftUI
import SwiftData

// MARK: - Header

struct HomeHeaderView: View {
    var household: Household?

    var body: some View {
        JRPGPanel {
            VStack(spacing: 10) {
                Text("Welcome, Adventurers")
                    .pixelText(.questTitle, color: .luGoldBright)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                PairSpriteView(members: household?.orderedMembers ?? [], pixelSize: 7)

                if let household {
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            StatusChip(text: "Level \(household.currentLevel)", color: .luRoyal)
                            Text("Season: \(household.activeSeasonName)")
                                .pixelText(.questLabel, color: .luTextDim)
                        }
                        Text(household.activeSeasonObjective)
                            .font(.questFootnote)
                            .foregroundStyle(Color.luTextDim)
                            .multilineTextAlignment(.center)

                        let progress = LevelCurve.standard.progress(forXP: household.lifetimeXP)
                        XPProgressBar(fraction: progress.fraction)
                        HStack {
                            Text("Lifetime \(household.lifetimeXP.xpLabel)")
                            Spacer()
                            Text("\(progress.earnedInLevel.xpLabel) / \(progress.neededForNextLevel.xpLabel) to Level \(household.currentLevel + 1)")
                        }
                        .font(.questFootnote)
                        .foregroundStyle(Color.luTextDim)
                        .monospacedDigit()
                    }
                }
            }
        }
    }
}

// MARK: - Cycle summary

struct CycleSummaryCard: View {
    var cycle: PayCycle

    var body: some View {
        JRPGPanel("This Cycle · \(cycle.dateRangeLabel)", titleIcon: "calendar") {
            VStack(spacing: 6) {
                LedgerRow(label: "Income Received", amount: cycle.totalIncome)
                LedgerRow(label: "Bills Reserved", amount: cycle.billsReserved)
                LedgerRow(label: "Splurge Reserved", amount: cycle.splurgeReserved)
                LedgerRow(label: "Buffer Reserved", amount: cycle.bufferReserved)
                if cycle.extraLifeReserved > 0 {
                    LedgerRow(label: "Extra Life Contribution", amount: cycle.extraLifeReserved)
                }
                Rectangle().fill(Color.luGold.opacity(0.35)).frame(height: 1)
                LedgerRow(label: "Available XP", amount: cycle.xpRemaining, emphasis: true)
                if cycle.unallocatedBalance != cycle.xpRemaining {
                    LedgerRow(label: "Unallocated Balance", amount: cycle.unallocatedBalance, color: .luTextDim)
                }
            }
        }
    }
}

// MARK: - Extra Lives

struct ExtraLivesCard: View {
    var balance: Decimal
    var lifeValue: Decimal
    var targetLives: Int

    private var lives: Decimal {
        FinanceEngine.extraLifeCount(balance: balance, lifeValue: lifeValue)
    }

    var body: some View {
        NavigationLink {
            ExtraLivesView()
        } label: {
            JRPGPanel("Extra Lives", titleIcon: "heart.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    ExtraLifeHeartRow(lives: lives, target: targetLives)

                    HStack(alignment: .firstTextBaseline) {
                        Text("\(lives.livesLabel) Lives")
                            .font(.questValue)
                            .foregroundStyle(Color.luText)
                        Spacer()
                        Text("\(balance.currencyLabel) / \((lifeValue * Decimal(targetLives)).currencyLabel)")
                            .font(.questFootnote)
                            .monospacedDigit()
                            .foregroundStyle(Color.luTextDim)
                    }

                    XPProgressBar(
                        fraction: progressToNextLife,
                        barColor: .luHeart,
                        height: 8
                    )
                    HStack {
                        Text("One Extra Life = \(lifeValue.currencyLabel)")
                        Spacer()
                        Text("\(FinanceEngine.amountToNextLife(balance: balance, lifeValue: lifeValue).currencyLabel) to next life")
                    }
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                    .monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Extra Lives screen")
    }

    private var progressToNextLife: Double {
        guard lifeValue > 0 else { return 0 }
        let fraction = FinanceEngine.extraLifeCount(balance: balance, lifeValue: lifeValue).doubleValue
        return fraction - fraction.rounded(.down)
    }
}

// MARK: - Quick stats

struct QuickStatsGrid: View {
    var stats: FinanceService.QuickStats

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GoldSectionHeader("Quick Stats", icon: "chart.bar.fill")
            LazyVGrid(columns: columns, spacing: 8) {
                StatTile(value: "\(stats.goalsCompleted)", label: "Goals Completed", icon: "checkmark.seal.fill")
                StatTile(value: "\(stats.itemsObtained)", label: "Items Obtained", icon: "trophy.fill")
                StatTile(value: stats.lifetimeXP.xpLabel, label: "Lifetime XP", icon: "star.fill")
                StatTile(value: "\(stats.freeAdventures)", label: "Free Adventures", icon: "leaf.fill")
                StatTile(value: "\(stats.streakCycles) cycles", label: "Current Streak", icon: "flame.fill")
                StatTile(value: stats.totalSaved.currencyLabel, label: "Total Saved", icon: "banknote.fill")
            }
        }
    }
}

// MARK: - Upcoming

struct UpcomingCard: View {
    var household: Household?
    var items: [BudgetItem]
    var proposals: [FinancialProposal]
    var goals: [Goal]

    var body: some View {
        JRPGPanel("Upcoming", titleIcon: "hourglass") {
            VStack(alignment: .leading, spacing: 8) {
                if let nextPayday {
                    upcomingRow(
                        icon: "banknote.fill",
                        title: "Next paycheck",
                        detail: nextPayday.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                    )
                }

                let due = billsBeforeNextPayday
                if !due.isEmpty {
                    upcomingRow(
                        icon: "list.bullet.rectangle.fill",
                        title: "\(due.count) bill\(due.count == 1 ? "" : "s") due before payday",
                        detail: due.prefix(3).map(\.title).joined(separator: ", ")
                            + (due.count > 3 ? "…" : "")
                    )
                }

                let pending = proposals.filter { $0.stage == .awaitingApproval }
                if !pending.isEmpty {
                    upcomingRow(
                        icon: "person.2.fill",
                        title: "\(pending.count) decision\(pending.count == 1 ? "" : "s") awaiting approval",
                        detail: pending.map(\.title).joined(separator: ", ")
                    )
                }

                if let closest = closestGoal {
                    upcomingRow(
                        icon: "target",
                        title: "Closest goal: \(closest.title)",
                        detail: "\(closest.percentDisplay)% · \(closest.xpRemaining.xpLabel) to go"
                    )
                }
            }
        }
    }

    private func upcomingRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(Color.luGold)
                .frame(width: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.questHeading)
                    .foregroundStyle(Color.luText)
                Text(detail)
                    .font(.questFootnote)
                    .foregroundStyle(Color.luTextDim)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var nextPayday: Date? {
        household?.paydaySchedule?.nextPayday(after: .now, calendar: .current)
    }

    private var billsBeforeNextPayday: [PlannedBillFunding] {
        guard let nextPayday else { return [] }
        return FinanceService.billsDueSoon(items: items, from: .now, until: nextPayday)
    }

    private var closestGoal: Goal? {
        goals
            .filter { $0.status == .active && $0.xpRemaining > 0 }
            .max { $0.progressFraction < $1.progressFraction }
    }
}

// MARK: - Activity feed

struct ActivityFeedCard: View {
    var events: [ActivityEvent]

    var body: some View {
        JRPGPanel("Recent Activity", titleIcon: "sparkles") {
            if events.isEmpty {
                Text("Quiet so far. Confirm a cycle or allocate XP to write your story.")
                    .font(.questBody)
                    .foregroundStyle(Color.luTextDim)
            } else {
                VStack(spacing: 10) {
                    ForEach(events, id: \.id) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: event.eventType.iconName)
                                .font(.footnote)
                                .foregroundStyle(Color.luGold)
                                .frame(width: 18)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.questBody)
                                    .foregroundStyle(Color.luText)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 4) {
                                    if !event.subtitle.isEmpty {
                                        Text(event.subtitle)
                                    }
                                    Text(event.date.formatted(.relative(presentation: .named)))
                                }
                                .font(.questFootnote)
                                .foregroundStyle(Color.luTextDim)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
