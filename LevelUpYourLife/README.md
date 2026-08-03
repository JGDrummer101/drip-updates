# Level Up Your Life

A shared couples budgeting app for iPhone that turns household finances into a
cooperative, semi-retro JRPG adventure. Plan each paycheck together, cover the
must-haves first, let fate pick the fun, allocate XP (dollars) to goals, and
build Extra Lives — your runway for life's unexpected battles.

**Built for two. Designed for life.**

This is a first functional prototype: fully navigable, seeded with a living
demo household, persisting locally with SwiftData.

## Requirements

| | |
|---|---|
| Xcode | 16.0 or newer (project uses Xcode 16 folder-synchronized groups) |
| iOS deployment target | 18.0 |
| Devices | iPhone (portrait) |
| Dependencies | None — no packages, API keys, accounts, or network access |

## Open and run

1. Open `LevelUpYourLife.xcodeproj` in Xcode 16+.
2. Select the **LevelUpYourLife** scheme and an iPhone simulator (or a device
   — set your team under *Signing & Capabilities* first; the bundle ID
   `com.jgdrummer101.LevelUpYourLife` can be changed freely).
3. **Run.** The app launches into a fully populated demo household
   ("Our Adventure": Jeffrey & Partner, Level 14, mid pay-cycle).

### Run the tests

- **In Xcode:** Product ▸ Test (⌘U). The unit test target runs the finance
  engine suites in the iPhone simulator.
- **From a terminal (no simulator needed):** the pure engine plus all tests
  also build as a Swift package:

  ```sh
  cd LevelUpYourLife
  swift test
  ```

  This works on any Mac (or Linux box) with a Swift 6 toolchain because the
  finance engine is Foundation-only. The SPM target is intentionally named
  `LevelUpYourLife` so the same `@testable import` works in both worlds.

## Architecture

```
LevelUpYourLife/
├── App/            Entry point, model container + seeding, tab shell, session state
├── Engine/         PURE Swift finance engine — no SwiftUI, no SwiftData
│   ├── FinanceEngine     Extra Life value/count, funding plans, allocation waterfall
│   ├── SurvivalPlanner   Shortfall strategies with live recalculation
│   ├── LevelCurve        Configurable XP → household level curves
│   ├── PaydaySchedule    Biweekly paydays, three-paycheck month detection
│   ├── GoalMath          Goal %, funded state, XP allocation plans
│   ├── DecisionSimulator Before/after simulations on frozen snapshots
│   ├── ApprovalPolicy    Two-person approval state machine
│   └── AdventureDrawEngine Weighted, seedable adventure draws
├── Models/         SwiftData @Model types (Household, PayCycle, Goal, …)
├── Services/       Mutation layer bridging models ↔ engine (+ seed data)
├── DesignSystem/   JRPG components: panels, parchment, pixel borders, sprites
└── Features/       One folder per screen (Home, PayCycle, Budget, Adventure,
                    Goals, ExtraLives, DecisionLab, Decisions, Sprites, More)
```

Principles:

- **Financial rules live in `Engine/` only.** Views never do money math; they
  map models to engine value types and render results. `Decimal` everywhere.
- **Services own mutation.** Confirming a cycle, committing XP, applying a
  proposal — each is a single service call that also writes activity events.
- **Randomness is injected.** The adventure draw takes any
  `RandomNumberGenerator`, so tests use a seeded one and the UI uses the
  system one.
- **All art is programmatic.** Sprites, hearts, and icons render from
  character grids via `Canvas` — no image assets, nothing copyrighted.

## Persistence

SwiftData with a local store; every model is listed in `AppSchema.models`.
On first launch (or when no household exists) `SeedService` builds the demo
world. The schema avoids unique constraints and keeps relationships shallow so
a CloudKit-backed shared container can be added later without redesign
(see `ProductNotes.md`).

## Reset demo data

**More ▸ Reset Demo Data** deletes everything and re-seeds the sample
household. Deleting the app from the simulator/device does the same on next
install.

## Known prototype limitations

- Single device: both partners are simulated via the "Viewing as" switcher
  (More tab / Household Decisions). No real accounts, sync, or notifications.
- Budget item statuses are tracked per calendar month with simplified
  carry-over; smoothed funding uses a documented approximation
  (`monthly × cycleDays × 12 / 365`).
- Applying an approved proposal handles the common cases (new expense, expense
  increase, splurge/buffer change, Extra Life withdrawal, new goal, goal
  withdrawal/pause); one-time purchases and income changes are informational.
- The level-curve default is tuned so the demo household's $18,400 lifetime XP
  lands at Level 14 (matching the concept art); the spec's coarser suggested
  thresholds ship as `LevelCurve.classic`.
- No currency/locale switching (USD), no iPad layout, no widgets.
