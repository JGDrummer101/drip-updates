import Foundation
import SwiftData

/// Demo seed data. Every number here was chosen so the math holds together:
/// required monthly budget $4,510 → one Extra Life $4,600; balance $9,450 →
/// ~2.05 lives; current-cycle income $4,850 − $2,940 bills − $300 splurge −
/// $300 buffer = $1,310 Available XP; lifetime XP $18,400 → Level 14 on the
/// standard curve.
@MainActor
enum SeedService {

    static func seedIfNeeded(context: ModelContext, now: Date = .now) {
        let existing = (try? context.fetchCount(FetchDescriptor<Household>())) ?? 0
        guard existing == 0 else { return }
        seed(context: context, now: now)
    }

    static func resetDemoData(context: ModelContext, now: Date = .now) {
        do {
            try context.delete(model: ActivityEvent.self)
            try context.delete(model: FinancialProposal.self)
            try context.delete(model: ExtraLifeTransaction.self)
            try context.delete(model: XPTransaction.self)
            try context.delete(model: Goal.self)
            try context.delete(model: AdventureDraw.self)
            try context.delete(model: AdventureIdea.self)
            try context.delete(model: BudgetItemStatus.self)
            try context.delete(model: BudgetItem.self)
            try context.delete(model: IncomeEntry.self)
            try context.delete(model: PayCycle.self)
            try context.delete(model: HouseholdMember.self)
            try context.delete(model: Household.self)
            try context.save()
        } catch {
            assertionFailure("Demo reset failed: \(error)")
        }
        seed(context: context, now: now)
    }

    // MARK: - The seed itself

    static func seed(context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2)) ?? now
        let schedule = PaydaySchedule(anchor: anchor)
        let payday = schedule.mostRecentPayday(onOrBefore: now, calendar: calendar)
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        // Household + members -------------------------------------------------
        let jeffrey = HouseholdMember(
            displayName: "Jeffrey",
            role: .primary,
            spriteConfiguration: .adventurerGreen
        )
        let partner = HouseholdMember(
            displayName: "Partner",
            role: .partner,
            spriteConfiguration: .adventurerCrimson
        )
        let household = Household(
            name: "Our Adventure",
            createdDate: daysAgo(320),
            currentLevel: LevelCurve.standard.level(forXP: 18_400),
            lifetimeXP: 18_400,
            minimumBuffer: 300,
            defaultSplurgeBudget: 300,
            activeSeasonName: "Home Stretch",
            activeSeasonObjective: "Build our home renovation fund",
            targetExtraLives: 3,
            freeAdventuresCompleted: 12,
            currentStreakCycles: 8,
            paydayAnchor: anchor,
            paydayIntervalDays: 14
        )
        context.insert(household)
        jeffrey.household = household
        partner.household = household
        context.insert(jeffrey)
        context.insert(partner)
        household.members = [jeffrey, partner]

        // Budget items --------------------------------------------------------
        // Required items total $4,510/month → one Extra Life = $4,600.
        let requiredSpecs: [(String, Decimal, BudgetCategory, Int, Bool)] = [
            // (title, amount, category, dueDay, autopay)
            ("Mortgage", 1_850, .housing, 1, true),
            ("Electricity", 120, .utilities, 3, true),
            ("Internet", 70, .utilities, 5, true),
            ("Car Insurance", 160, .insurance, 7, false),
            ("Water & Sewer", 90, .utilities, 8, false),
            ("Groceries", 450, .food, 10, false),
            ("Trash Service", 30, .utilities, 11, true),
            ("Phone", 120, .utilities, 12, true),
            ("Prescriptions", 50, .health, 13, false),
            ("Gym", 50, .health, 14, true),
            ("Car Payment", 425, .transportation, 16, true),
            ("Student Loan", 280, .other, 18, true),
            ("Health Insurance", 310, .health, 21, false),
            ("Pet Care", 90, .lifestyle, 26, false),
            ("Life Insurance", 45, .insurance, 27, true),
            ("HOA Dues", 150, .housing, 28, false),
        ]
        var items: [BudgetItem] = requiredSpecs.map { spec in
            BudgetItem(
                title: spec.0,
                amount: spec.1,
                category: spec.2,
                dueDay: spec.3,
                recurrence: .monthly,
                fundingMethod: .dueDate,
                isRequired: true,
                isAutopay: spec.4,
                createdBy: "Jeffrey",
                createdDate: daysAgo(300)
            )
        }
        let fuel = BudgetItem(
            title: "Auto Fuel", amount: 220, category: .transportation, dueDay: 15,
            recurrence: .monthly, fundingMethod: .smoothed, isRequired: true,
            createdBy: "Partner", createdDate: daysAgo(300)
        )
        items.append(fuel)

        let flexibleSpecs: [(String, Decimal, BudgetCategory, Int, FundingMethod, Bool)] = [
            ("Streaming Bundle", 45, .subscriptions, 6, .dueDate, true),
            ("Dining Out", 180, .food, 15, .smoothed, false),
            ("Hobby Fund", 60, .lifestyle, 20, .dueDate, false),
            ("Music Subscriptions", 25, .subscriptions, 9, .dueDate, true),
        ]
        for spec in flexibleSpecs {
            items.append(BudgetItem(
                title: spec.0, amount: spec.1, category: spec.2, dueDay: spec.3,
                recurrence: .monthly, fundingMethod: spec.4, isRequired: false,
                isAutopay: spec.5, createdBy: "Partner", createdDate: daysAgo(280)
            ))
        }
        items.forEach(context.insert)

        // This month's statuses: nine in-window items funded (= $2,940),
        // the Mortgage already paid, the rest of the month upcoming.
        let monthKey = BudgetItemStatus.monthKey(for: payday, calendar: calendar)
        let fundedTitles: Set<String> = [
            "Mortgage", "Electricity", "Internet", "Car Insurance", "Water & Sewer",
            "Groceries", "Trash Service", "Phone", "Prescriptions",
        ]
        for item in items {
            let monthly = FinanceEngine.monthlyEquivalent(amount: item.amount, recurrence: item.recurrence)
            let status: BudgetItemStatus
            if item.title == "Mortgage" {
                status = BudgetItemStatus(
                    monthKey: monthKey, amountNeeded: monthly,
                    amountReserved: monthly, amountPaid: monthly, status: .paid
                )
            } else if fundedTitles.contains(item.title) {
                status = BudgetItemStatus(
                    monthKey: monthKey, amountNeeded: monthly,
                    amountReserved: monthly, status: .funded
                )
            } else if !item.isRequired {
                status = BudgetItemStatus(
                    monthKey: monthKey, amountNeeded: monthly, status: .needsFunding
                )
            } else {
                status = BudgetItemStatus(
                    monthKey: monthKey, amountNeeded: monthly, status: .upcoming
                )
            }
            status.item = item
            item.statuses.append(status)
            context.insert(status)
        }

        // Pay cycles ----------------------------------------------------------
        // Seven completed cycles behind the current one → an 8-cycle streak.
        let pastIncomes: [Decimal] = [4_850, 4_850, 5_250, 4_700, 4_850, 4_850, 4_450]
        for (index, income) in pastIncomes.enumerated() {
            let offset = (index + 1) * 14
            let start = calendar.date(byAdding: .day, value: -offset, to: payday) ?? payday
            let end = calendar.date(byAdding: .day, value: 13, to: start) ?? start
            let bills: Decimal = index % 2 == 0 ? 2_940 : 1_570
            let allocation = FinanceEngine.allocate(AllocationRequest(
                totalIncome: income,
                requiredBills: bills,
                bufferTarget: 300,
                splurgeTarget: 300,
                extraLifeTarget: index == 2 ? 600 : 0
            ))
            let cycle = PayCycle(
                startDate: start,
                endDate: end,
                paycheckDate: start,
                status: .completed,
                totalIncome: income,
                billsReserved: allocation.billsReserved,
                splurgeReserved: allocation.splurgeReserved,
                bufferReserved: allocation.bufferReserved,
                extraLifeReserved: allocation.extraLifeReserved,
                availableXP: allocation.availableXP,
                xpAllocated: allocation.availableXP,
                splurgeSpent: 260,
                createdBy: index % 2 == 0 ? "Jeffrey" : "Partner",
                createdDate: start
            )
            context.insert(cycle)
        }

        // The current confirmed cycle: $4,850 in, $1,310 XP to allocate.
        let cycleEnd = calendar.date(byAdding: .day, value: 13, to: payday) ?? payday
        let currentCycle = PayCycle(
            startDate: payday,
            endDate: cycleEnd,
            paycheckDate: payday,
            status: .confirmed,
            totalIncome: 4_850,
            billsReserved: 2_940,
            splurgeReserved: 300,
            bufferReserved: 300,
            extraLifeReserved: 0,
            availableXP: 1_310,
            xpAllocated: 0,
            splurgeSpent: 0,
            createdBy: "Jeffrey",
            createdDate: payday
        )
        context.insert(currentCycle)
        let incomes: [(String, Decimal, IncomeType, String)] = [
            ("Jeffrey — Paycheck", 2_350, .paycheck, "Jeffrey"),
            ("Partner — Paycheck", 2_100, .paycheck, "Partner"),
            ("Freelance Mix Session", 400, .other, "Jeffrey"),
        ]
        for entry in incomes {
            let income = IncomeEntry(title: entry.0, amount: entry.1, type: entry.2, date: payday, owner: entry.3)
            income.payCycle = currentCycle
            context.insert(income)
        }

        // Extra Life fund ------------------------------------------------------
        // Contributions and one honest withdrawal, summing to $9,450.
        let elHistory: [(Decimal, ExtraLifeTransactionType, String, Int)] = [
            (6_000, .contribution, "Starter fund — built over our first season", 300),
            (1_850, .contribution, "Tax refund set-aside", 210),
            (-4_600, .withdrawal, "Transmission repair — that's why we built it", 150),
            (1_200, .contribution, "Three-paycheck month bonus", 120),
            (2_400, .contribution, "Season of small deposits", 75),
            (2_600, .contribution, "Bonus from Jeffrey's studio work", 30),
        ]
        for entry in elHistory {
            context.insert(ExtraLifeTransaction(
                amount: entry.0, type: entry.1, date: daysAgo(entry.3), reason: entry.2
            ))
        }

        // Goals ---------------------------------------------------------------
        let hawaii = Goal(
            title: "Hawaii Vacation", category: .qualityOfLife, targetAmount: 4_000,
            currentAmount: 2_350, priority: 2,
            targetDate: calendar.date(byAdding: .month, value: 5, to: now),
            ownership: .shared, boxValue: 100, createdDate: daysAgo(200)
        )
        let invisalign = Goal(
            title: "Invisalign", category: .committed, targetAmount: 2_500,
            currentAmount: 1_250, priority: 3, ownership: .partner,
            boxValue: 50, createdDate: daysAgo(180)
        )
        let renovation = Goal(
            title: "Home Renovation", category: .home, targetAmount: 10_000,
            currentAmount: 4_200, priority: 1, ownership: .shared,
            boxValue: 250, createdDate: daysAgo(260)
        )
        let newCar = Goal(
            title: "New Car", category: .longTerm, targetAmount: 25_000,
            currentAmount: 3_000, priority: 4, ownership: .shared, boxValue: 500,
            useMilestones: true, milestoneValues: [5_000, 10_000, 15_000, 20_000, 25_000],
            createdDate: daysAgo(240)
        )
        let downPayment = Goal(
            title: "Home Down Payment", category: .longTerm, targetAmount: 150_000,
            currentAmount: 25_000, priority: 5, ownership: .shared, boxValue: 1_000,
            useMilestones: true,
            milestoneValues: [25_000, 50_000, 75_000, 100_000, 125_000, 150_000],
            createdDate: daysAgo(310)
        )
        let obtained: [(String, GoalCategory, Decimal, Int)] = [
            ("Emergency Starter Fund", .foundation, 1_500, 280),
            ("New Laptop", .qualityOfLife, 1_800, 190),
            ("Anniversary Getaway", .family, 1_300, 130),
            ("Electronic Drum Kit", .qualityOfLife, 2_000, 60),
        ]
        var goals = [renovation, hawaii, invisalign, newCar, downPayment]
        for spec in obtained {
            let goal = Goal(
                title: spec.0, category: spec.1, targetAmount: spec.2,
                currentAmount: spec.2, priority: 3, ownership: .shared,
                status: .obtained, boxValue: 100,
                createdDate: daysAgo(spec.3 + 90), completedDate: daysAgo(spec.3)
            )
            goals.append(goal)
        }
        goals.forEach(context.insert)

        // A little XP history so goal detail views feel lived-in.
        let xpHistory: [(Goal, Decimal, Int, String)] = [
            (renovation, 500, 16, "Jeffrey"),
            (hawaii, 500, 16, "Jeffrey"),
            (invisalign, 310, 16, "Partner"),
            (renovation, 650, 30, "Partner"),
            (hawaii, 400, 44, "Jeffrey"),
            (newCar, 300, 44, "Partner"),
            (downPayment, 1_000, 58, "Jeffrey"),
        ]
        for entry in xpHistory {
            let txn = XPTransaction(
                amount: entry.1, date: daysAgo(entry.2),
                sourceCycleLabel: "Earlier cycle", note: "XP allocation", createdBy: entry.3
            )
            txn.goal = entry.0
            context.insert(txn)
        }

        // Adventure ideas -----------------------------------------------------
        func idea(
            _ title: String, _ cost: Decimal, _ category: AdventureCategory,
            by member: String, picked: Int = 0, lastPicked: Int? = nil,
            status: IdeaStatus = .active, free: FreeAdventureCategory? = nil,
            age: Int = 200
        ) -> AdventureIdea {
            AdventureIdea(
                title: title, estimatedCost: cost, category: category,
                freeCategory: free, status: status, submittedBy: member,
                timesSelected: picked,
                lastSelectedDate: lastPicked.map { daysAgo($0) },
                createdDate: daysAgo(age)
            )
        }
        let adventureIdeas: [AdventureIdea] = [
            // Jeffrey
            idea("New Vinyl Record", 35, .mine, by: "Jeffrey", picked: 2, lastPicked: 42),
            idea("Guitar Pedal", 120, .mine, by: "Jeffrey"),
            idea("New Game", 70, .mine, by: "Jeffrey", picked: 1, lastPicked: 17),
            idea("Band Shirt", 30, .mine, by: "Jeffrey"),
            idea("Specialty Dinner", 55, .mine, by: "Jeffrey", picked: 1, lastPicked: 70),
            idea("Concert Tickets", 90, .mine, by: "Jeffrey", status: .waitingRoom, age: 20),
            // Partner
            idea("Spa Afternoon", 85, .partner, by: "Partner", picked: 1, lastPicked: 17),
            idea("New Book Set", 45, .partner, by: "Partner", picked: 1, lastPicked: 56),
            idea("Home Decor Item", 65, .partner, by: "Partner"),
            idea("Clothing Item", 75, .partner, by: "Partner"),
            idea("Craft Supplies", 40, .partner, by: "Partner", picked: 2, lastPicked: 84),
            idea("Pottery Class", 70, .partner, by: "Partner", status: .waitingRoom, age: 12),
            // Shared
            idea("Board Game Night", 35, .shared, by: "Jeffrey", picked: 3, lastPicked: 28),
            idea("Nice Dinner", 120, .shared, by: "Partner", picked: 2, lastPicked: 56),
            idea("Theme Park Day", 250, .shared, by: "Jeffrey"),
            idea("Weekend Breakfast Date", 60, .shared, by: "Partner", picked: 1, lastPicked: 17),
            idea("Movie Theater Night", 55, .shared, by: "Jeffrey", picked: 1, lastPicked: 98),
        ]
        let freeIdeas: [(String, FreeAdventureCategory, String)] = [
            ("Movie Marathon", .atHome, "Partner"),
            ("Homemade Pizza Night", .atHome, "Jeffrey"),
            ("Build a Blanket Fort", .atHome, "Partner"),
            ("Living Room Picnic", .atHome, "Jeffrey"),
            ("Board Game Tournament", .atHome, "Jeffrey"),
            ("Cook a New Recipe", .creative, "Partner"),
            ("Make a Shared Playlist", .creative, "Jeffrey"),
            ("Sunset Walk", .outdoors, "Partner"),
            ("Beach Walk", .outdoors, "Jeffrey"),
            ("Backyard Stargazing", .outdoors, "Partner"),
            ("Explore a New Neighborhood", .aroundTown, "Jeffrey"),
            ("Visit a Bookstore", .aroundTown, "Partner"),
            ("Recreate Your First Date", .relationship, "Jeffrey"),
            ("Plan a Dream Vacation", .relationship, "Partner"),
            ("Look Through Old Photos", .relationship, "Partner"),
        ]
        var allIdeas = adventureIdeas
        for (index, spec) in freeIdeas.enumerated() {
            allIdeas.append(idea(
                spec.0, 0, .free, by: spec.2,
                picked: index % 4 == 0 ? 1 : 0,
                lastPicked: index % 4 == 0 ? 30 + index * 7 : nil,
                free: spec.1, age: 250 - index * 9
            ))
        }
        allIdeas.forEach(context.insert)

        // Last cycle's accepted draw, for repeat-avoidance and history.
        func slot(_ title: String, _ cost: Decimal, _ owner: String) -> DrawSlot? {
            guard let match = allIdeas.first(where: { $0.title == title }) else { return nil }
            return DrawSlot(ideaID: match.id, title: title, cost: cost, ownerLabel: owner)
        }
        let previousDraw = AdventureDraw(
            mineSlot: slot("New Game", 70, "Jeffrey"),
            partnerSlot: slot("Spa Afternoon", 85, "Partner"),
            sharedSlot: slot("Weekend Breakfast Date", 60, "Together"),
            totalEstimatedCost: 215,
            resultStatus: .accepted,
            createdDate: daysAgo(17)
        )
        context.insert(previousDraw)

        // Pending proposal ----------------------------------------------------
        let baseline = FinancialBaseline(
            requiredMonthlyBudget: FinanceEngine.requiredMonthlyBudget(items: items.map(\.spec)),
            extraLifeBalance: 9_450,
            splurgePerCycle: 300,
            bufferPerCycle: 300,
            extraLifeContributionPerCycle: 0,
            averageIncomePerCycle: 4_850
        )
        let disney = FinancialProposal(
            title: "Disney+ Bundle",
            proposalType: .addRecurringExpense,
            details: "Bundle streaming for movie marathon nights. Replaces nothing — a pure add.",
            recurringAmount: 27,
            effectiveDate: calendar.date(byAdding: .day, value: 14, to: now) ?? now,
            submittedBy: "Jeffrey",
            submittedDate: daysAgo(2),
            stage: .awaitingApproval,
            payloadCategory: .subscriptions,
            payloadIsRequired: false
        )
        let result = DecisionSimulator.simulate(
            baseline: baseline,
            change: .addRecurringExpense(monthly: 27, isRequired: false)
        )
        disney.impact = ImpactSnapshot.from(result: result)
        context.insert(disney)

        // Activity feed -------------------------------------------------------
        let feed: [(String, String, String, ActivityEventType, Int)] = [
            ("Pay cycle confirmed", "\(currentCycle.dateRangeLabel) · 1,310 XP available", "Jeffrey", .cycleConfirmed, 0),
            ("Disney+ Bundle proposal is awaiting approval", "Submitted by Jeffrey", "Jeffrey", .proposalSubmitted, 2),
            ("Partner added Movie Marathon to Free Adventures", "At Home idea pool", "Partner", .adventureAdded, 3),
            ("Jeffrey allocated 500 XP to Hawaii Vacation", "59% of $4,000", "Jeffrey", .xpAllocated, 16),
            ("Home Renovation reached 42%", "$4,200 of $10,000", "Partner", .goalProgress, 16),
            ("Adventure locked in", "New Game · Spa Afternoon · Weekend Breakfast Date", "Partner", .adventureDrawn, 17),
            ("Free adventure complete: Sunset Walk", "That's 12 lifetime free adventures.", "Partner", .adventureCompleted, 21),
            ("Household reached Level 14", "Lifetime XP: 18,400 XP", "Jeffrey", .levelUp, 30),
        ]
        for entry in feed {
            ActivityLog.post(
                context, title: entry.0, subtitle: entry.1,
                member: entry.2, type: entry.3, date: daysAgo(entry.4)
            )
        }

        try? context.save()
    }
}
