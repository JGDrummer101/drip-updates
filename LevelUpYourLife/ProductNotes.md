# Product Notes — Level Up Your Life (Prototype 0.1)

## Current user flow

1. **Home** greets the party: both sprites, season, household level, lifetime
   XP progress, the current cycle's numbers, Extra Lives, quick stats,
   upcoming items, and the shared activity feed. `START NEW PAY CYCLE` is the
   primary action.
2. **Pay Cycle flow** (sheet): Income → Required Funding → Fun & Protection →
   Review. The engine computes which bills the cycle must fund (due-date or
   smoothed), then allocates income in strict order: required bills → flexible
   bills → buffer → splurge → Extra Life contribution → **Available XP**
   (never negative). If the plan can't be funded, **Survival Mode** routes in
   before confirmation: reduce splurge/buffer, delay flexible expenses, drop
   the Extra Life contribution, or spend Extra Life funds (explicit
   confirmation + both simulated approvals required). Confirming saves the
   cycle, reserves bills, logs activity, fires haptics, and shows the
   "Cycle Ready" toast.
3. **Budget** groups this month's items by Needs Funding / Funded / Paid /
   Upcoming. Adding or materially increasing a *required* item asks
   "Add directly as a draft proposal?" and routes through Household Decisions
   instead of editing live data. Flexible items edit directly (prototype
   convenience).
4. **Adventure** holds three five-slot pools (Mine / Partner / Ours) plus a
   Waiting Room. The draw picks one idea per pool — weighted toward older,
   less-picked ideas, avoiding last cycle's picks when alternatives exist —
   and presents three reward cards with a budget verdict. Lock In / Replace
   One / Reroll All / Save for Later / Convert to Goal. **Free Adventure
   Mode** draws from five categories of $0 ideas and feeds a lifetime
   counter.
5. **Goals** groups quests by category with box-grid or milestone
   visualizations. **Allocate XP** splits the cycle's XP with steppers, a
   priority-weighted suggested split, and a live summary. Committing writes
   XP transactions, updates goals and lifetime XP, recalculates the level
   (with a restrained level-up overlay), and marks goals **Funded** at 100% —
   **Obtained** stays a separate human step.
6. **Extra Lives** shows the fund as hearts (full/partial/empty), the exact
   math (required monthly budget → value of one life, rounded up to $100),
   progress to the next life, customizable milestone labels, target lives,
   history, and supportive contribution/withdrawal flows.
7. **Decision Lab** simulates changes on a frozen baseline — never live data —
   with before/after cards and a neutral Low/Moderate/High impact label.
   "Save as Proposal" routes into **Household Decisions**, where the
   "Viewing as" switcher simulates each partner. Both must approve; applying
   is a separate explicit step.
8. **Sprite Customization** builds each hero from inclusive frames (A/B/C),
   5 skin tones, 6 hairstyles, 6 hair colors, 5 outfits, 8 outfit colors,
   6 accessories, and 5 poses — all programmatic pixel grids.

## Financial assumptions

- **$1 = 1 XP.** Lifetime XP only ever grows; spending goal funds later never
  subtracts it.
- **One Extra Life** = total *required, active* monthly budget, normalized to
  monthly equivalents (weekly ×52/12, biweekly ×26/12, annual ÷12), rounded
  **up** to the nearest $100. Seed: $4,510 → $4,600.
- **Extra Life count** = balance ÷ life value, computed at full precision,
  shown to one decimal in primary UI (seed: $9,450 ÷ $4,600 ≈ 2.05 → "2.1"
  rounds to 2.1 via one-decimal rounding).
- **Allocation order** is a strict waterfall; a *shortfall* means required
  bills alone exceed income, while a *plan gap* means the full plan does.
  Survival Mode opens for either; only Extra Life funds can close a true
  shortfall — required expenses are never silently removed.
- **Three-paycheck months** are detected from an anchored biweekly schedule.
  The third paycheck is not treated as disposable; it flows through the same
  waterfall.
- **Smoothed funding** approximates a cycle's share as
  `monthly × cycleDays × 12 / 365` (documented in `FinanceEngine`).
- **Impact levels** are magnitude heuristics (recurring change relative to
  the required budget; one-time cost relative to one Extra Life) — neutral,
  never moralizing.
- Seed-data reconciliation: goal balances predating the app (e.g. $24K of the
  down payment) are not part of lifetime XP, which counts in-app allocations
  only. The default level curve is tuned so $18,400 → Level 14; the spec's
  suggested thresholds remain available as `LevelCurve.classic`.

## Features intentionally deferred

- Real two-device households (accounts, invitations, presence)
- CloudKit/any sync; push notifications; widgets/live activities
- Bank integration and transaction import
- Editable discussion threads on proposals (placeholder note field today)
- Recurring Extra Life auto-contributions; goal auto-funding rules
- Multi-currency, localization, iPad/landscape layouts
- Historical reporting/charts beyond the History lists
- Undo/rollback of applied proposals

## Recommended V2 roadmap

1. **Household sync** (CloudKit shared zone) — the real product core.
2. **True dual approval** with per-user identity, notifications, and an
   activity inbox.
3. **Cycle intelligence:** carry-over of underfunded items, per-cycle bill
   forecasting across months, richer three-paycheck planning.
4. **Adventure history & memories:** photos/notes on completed adventures;
   streaks and gentle achievements.
5. **Reporting:** season recaps, XP-over-time, category trends (Charts).
6. **Onboarding:** guided first-run that builds the budget and payday anchor
   from scratch (the seed flow already isolates everything needed).

## CloudKit migration considerations

- `AppSchema.models` centralizes the schema; models avoid `.unique`
  constraints and non-optional relationships — both CloudKit requirements.
- Cross-entity references that would strain sync (e.g. draw slots,
  XP source cycles) are stored as denormalized IDs + labels, which survives
  eventual consistency well.
- Suggested layout: one shared `CKRecordZone` per household; `Household` as
  root record; use `CKShare` for the partner invitation. Local SwiftData
  remains the cache; a thin sync engine reconciles.
- Conflict policy: last-writer-wins for cosmetic fields; append-only for
  transactions/events (they're immutable facts); proposals resolve by stage
  precedence (applied > declined > approved > awaiting).

## Security considerations for a production financial app

Even without bank credentials, a real release should add:

- **Data protection:** enable complete file protection for the store;
  consider SQLCipher-level encryption if requirements demand it.
- **Access control:** Face ID/passcode gate (LocalAuthentication) with a
  privacy screen when backgrounded.
- **Sync privacy:** CloudKit private/shared databases only; no third-party
  analytics on financial fields; strip amounts from logs.
- **Approval integrity:** signatures on approvals (per-user keys) so one
  device cannot forge the partner's consent — today's simulator switch is
  explicitly a prototype affordance.
- **Backups & export:** encrypted export; clear data-deletion path.
- **Supply chain:** keep the zero-dependency stance where possible; pin and
  audit anything added.
- If bank aggregation ever lands, isolate tokens in the Keychain, use a
  server-side vault, and treat aggregator scopes as least-privilege.
