# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step3a1-location-foundations.md
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md (reachable)
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| T1–T5 core.dart | additive exports | ok (append only) |
| T2→T5 | AppChip consumed by LocationPromptCard | names match (AppChip, AppChipKind) |
| T5,T6 app_vi.arb | additive keys | ok |
| T7 idle.dart | exists from screen-codes | plan says create only if missing: ok, keep existing |
| T1..T7 self-consistency | tests vs code | to be caught in review |
Ruling: commit trailer per environment (Opus 5.5) not plan's Sonnet — trailer not reviewed — none.
Task 1: complete a7e1a98 (approved; parked minors: geo.dart:211 comment 625km, core.dart export order, empty-hash guard)
Task 2: review needs fixes (AppChip 48dp hit area plan-mandated defect)
Ruling: global 48dp touch-target constraint beats brief code — spec binding — small rework if wrong
Task 2: fix round 1 dispatched (hit area, label overflow, isButton)
Task 2: fix round 1 09b1675 — controller re-review: all 3 addressed, no new breakage
Task 2: complete 09b1675 (parked minors: selected chip colour-only cue, vacuous one-line segment test, segment ink radius)
Task 3: complete b8e66e1 (approved; parked minors: sheet scroll test at 1.3x, viewInsets test, MediaQuery.sizeOf)
Task 4: complete 45777a8 (approved; parked minors: 600/599 boundary test, integer ceil)
Task 5: complete 3d27ec1 (approved; parked: AppButton loading has no accessible name -> final wave; requesting test weak; 18.4 magic)
Task 6: review needs fixes (merged FOREGROUND_SERVICE_LOCATION, catch-all swallows Errors)
Ruling: strip plugin foreground-service permission/service via tools:node=remove — spec 'approximate, when-in-use only' — if a later feature needs background location (instant-booking photographer tracking) it re-adds it deliberately
Task 6: fix round 1 dispatched
Task 6: fix round 1 392c624 — controller re-review: all 6 addressed
Task 6: complete 392c624 (parked: Android deniedForever reporting, Auto Backup restoring locationAsked -> 3a2 controller)
Task 7: complete 8276d7d (controller-reviewed: idle/blur/manifest audits ok; device profiling pending)
Final review (opus): ready with fixes — chip heightFactor, loading a11y label, check icon on selected chip, minHeight 32, query area, tab role
Ruling: add geohashCells(rings:) + geohashQuery(radiusKm) choosing precision 4 rings 2 for <=39km — cuts 25km query from ~470km box to ~195km — 3a2 must call the new helper (note added to 3a2 brief later)
Final fix wave dispatched
