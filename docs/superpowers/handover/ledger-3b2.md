# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step3b2-feed-cards.md
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md (reachable)
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| T1→T2,T5,T6 | NetworkPhoto/PhotoImageScope | consumed by name |
| T3 format.dart | existing formatDistance/formatMoney (3a2 fixed 999950→1M) | append only |
| T4→T5,T6 | ReasonChips | ok |
| T5→T6 | PhotoPill | ok |
| T7 idle/blur | exist | keep |
| 3a1/3a2 widgets | AppChip 48dp exact + check when selected; AppButton loading keeps label; AppSkeletonScope | reuse |
| PhotographerSummary | lat/lng now from serviceArea.center (3b1 fix) | no impact |
Ruling: commit trailer per environment, not reviewed.
Task 1: review needs fixes (unbounded width decodes original — plan-mandated; retry hidden from a11y)
Task 1: fix round 1 dispatched
Task 1: fix 289ad0e — controller verified
Task 1: complete 289ad0e (parked: production errorWidget wiring untested — path_provider in tests)
Ruling: batch Tasks 2+3 (small, independent) in one dispatch, one review
Tasks 2+3: review needs fixes (avatar ring invisible — plan-mandated; semantics double announce)
Tasks 2+3: fix round 1 dispatched
Tasks 2+3: fix 5b8bb41 — controller checked stat
Task 2: complete
Task 3: complete 5b8bb41
Task 4: complete a157f27 (approved; final wave: explicit text colour onSurface)
Task 5: review needs fixes (retry under tap layer, split semantics, action 48dp, test warning, scrim contrast)
Ruling: PhotoCard uses NetworkPhoto retry:false — card tap opens detail which retries — a failed tile stays blank until refresh
Task 5: fix round 1 dispatched
Task 5: fix 85152eb — 5 items reported in diff; controller checked stat
Task 5: complete 85152eb (parked: non-PhotoPill pills hidden from semantics)
Task 6: complete 41da597 (approved; final wave: price<=0 → '—' never 0₫, omit unknown price from semantics label, semantics/no-rating tests)
Task 7: complete df2b419 (controller-reviewed; device profiling pending)
Final review (opus): ready with fixes — PhotoCard loading hole, price 0/null, semanticLabel, 3b4 plan edits
Ruling: aspect-aware decode parked (memory vs sharpness) — revisit with blurhash step
Final fix wave dispatched
