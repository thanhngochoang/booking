# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step3a2-explore-screens.md
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md (reachable)
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| T1→T2,T3,T4,T6,T7 | clockProvider, AreaOption/SavedArea, builtin taxonomy | names consistent in Produces blocks |
| T2→T3,T4,T7 | ExploreOrigin.cellPrefix, exploreResolutionProvider | consistent; T3/T4 updated to geohashQueryFor(rings) after 3a1 final review (a83d97a) |
| T3,T6,T7 app_vi.arb | additive | ok |
| T5→T6,T7 | ErrorState, AppSkeleton, text_fold | consistent |
| T6 creates test/support/screen_host.dart → T7,T8 | helper | ok |
| T8 idle/blur | already exist (3a1) | keep existing |
| 3a1 AppChip | now 48dp exact, check icon when selected, AppButton loading keeps label semantics | tests in 3a2 that count Icons or rely on chip height may need adapting |
Ruling: inCells limit=100 stays (fake only here); events plan adapter must filter by distance before any limit — noted for events plan — over-fetch only.
Ruling: Auto Backup restoring locationAsked accepted for now (user sees choose-area chip + can still request) — low impact — revisit in device testing.
Ruling: commit trailer per environment, not reviewed.
Task 1: complete 2d19bd5 (approved; parked: uppercase geohash normalise in fromJson, test tightness)
Task 2: review needs fixes (area dropped on deniedForever — plan-mandated; unguarded permissionStatus; vacuous keep-fix test)
Ruling: area is kept unless a granted device fix arrives — spec 'manual area wins' — none
Task 2: fix round 1 dispatched (+ in-flight locate, clock pass-through, loaded check)
Task 2: re-review approved f492e62
Task 2: complete f492e62 (parked: stale fix can drop area in useDeviceLocation; no revoke-in-flight / serviceOff tests)
Task 3: complete 7fd133e (approved; final wave: port doc 'return all matches or page' wording, formatMoney 999950 short -> 1M + doc that callers show FreeTag for 0)
Task 4: review needs fixes (badge lingers during reload)
Task 4: fix round 1 dispatched
Task 4: fix rounds 221c624 + 8f9f8bd — controller verified (reload hides badge; persist-then-state)
Task 4: complete 8f9f8bd (parked: markSeen only on tab tap, not deep link)
Task 5: review needs fixes (per-bone tickers plan-mandated; reduced motion mid-pulse)
Ruling: add AppSkeletonScope sharing one controller; bones without scope self-animate — battery constraint — small API addition, later screens wrap loading layouts in AppSkeletonScope
Task 5: fix round 1 dispatched
Task 5: fix 7c1065f — controller verified scope/FadeTransition/reduced motion
Task 5: complete 7c1065f (parked: bone leaving+re-leaving a scope would create a 2nd ticker under SingleTickerProviderStateMixin — switch to TickerProviderStateMixin if it ever happens)
Task 6: review needs fixes (false no-match while loading, stuck spinner on missing id, silent close on failed device location, keyboard layout)
Task 6: fix round 1 dispatched
Task 6: re-review approved 1427800
Task 6: complete 1427800 (final wave: search TextField needs a State-held controller so a recreated field shows the query)
Ruling: S13 order follows spec+mock (search, tabs, tile grid, LocationPromptCard, events); S35 events first then the rest (spec). Tests scroll instead of reordering — spec binding — prompt sits below the grid
Task 7: review needs fixes (S13 order, double skeleton scope, wasted fetch while loading, date a11y)
Ruling: S13 search box deferred to 3b4 (needs S04 query route) — plan silent — S13 lacks search until 3b4
Task 7: fix round 1 dispatched
Task 7: re-review approved 1c6ba4d
Task 7: complete 1c6ba4d (final wave: vacuous 'events section disappears' test must scroll / skipOffstage:false)
Task 8: complete 9984221 (controller-reviewed; device profiling pending)
Final review (opus): ready with fixes — I1 refresh on tab entry + resume only when active, I2 S36 feedback, I3 stale fix, I4 doc, M1-M4
Ruling: keep the one low-power coarse fix at cold start (badge needs local cells) — product call surfaced to user — if wrong, build() reads permission only and badge waits for first Explore visit
Final fix wave dispatched
