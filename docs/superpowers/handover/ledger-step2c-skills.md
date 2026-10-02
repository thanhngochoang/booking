# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step2c-skills.md
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md §3e (reachable)
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| prerequisites | 3a1/3a2/3b1/3b2 names | all exist (testPhotoScope in test/support/photo_scope.dart) |
| T1→T2..T12 | TaxonomyCatalog/(group,id) | consumed by name |
| T2→T3,T4,T5 | PhotographerSkills model/map | ok |
| T5 adapter ↔ T6 rules | skills map field names | review must cross-check |
| T6 rules | photographerClientFields allowlist (2b) must gain `skills`; completeness/updatedAt server-only | merge; controller runs emulator |
| T7–T9 widgets → T11,T12 | SkillChip/CompletenessMeter/LevelSelector/EvidencePicker | ok |
| T11 S40 | PostRepository.byPhotographer (3b1: createdAt desc then id desc; cursor rules), NetworkPhoto | ok |
| T12 routes | /profile/skills, /setup/4 (2b) | ok |
| 3a1/3b2 widgets | AppChip 48dp exact + check when selected; AppAvatar decorative; PhotoCard retry:false + semanticLabel; AppSkeletonScope | reuse |
Ruling: commit trailer per environment, not reviewed. Emulator run by controller.
Ruling: batch pure-Dart Tasks 1+2 and 3+4 (same shape, sequential deps) — one review each pair
Task 1: complete 3d032d7
Task 2: complete ddc2711 (approved; final wave: num levels/years accepted via toInt; out-of-range years handled by validation)
Task 3: complete
Task 4: complete ca23687 (approved; final wave: tests for retired genre, retired in toggles, years 0/-1 per genre, downgrade keeps evidence, completeness step table; comment _done catalogue-free)
Ruling: downgrading from level 3 keeps evidence posts — avoids data loss on toggle; limit 0–3 still holds
Task 5: complete fac15bb (approved)
Carry to Task 6: add skills to photographerClientFields; merged skills map includes server keys completeness/updatedAt → allowlist them and pin unchanged vs resource; yearsExperience null|0..50; per-specialty keys id,level,evidencePostIds,years?; emulator test merge over doc with existing completeness
Task 6: 3b59026 emulator 47/52 — skills rules exceed 1000-expression limit
Task 6: fix round 1 dispatched (budget redesign, evaluate only when skills touched)
Task 6: fix 6811bae — controller emulator 53/53; ~800/1000 expressions for max profile
Task 6: review needs fixes (evidence ids with separators bypass regex)
Task 6: fix round 2 dispatched
USER (2026-10-02): UI must match the committed artifact (docs/design/ui-mock.html) — added to impl/review rules; mock-parity audit of already-built screens after 2c
Task 6: fix 620b768 — emulator 55/55, re-review approved (combined serviceArea+contact+6-genre write exceeds budget; app writes them separately — comment in final wave)
Task 6: complete 620b768
USER rulings 2026-10-02: PhotographerCard gets a small gradient 'Đặt' (mock wins; one-primary rule = screen CTA only); PhoneField = 2 boxes ('Mã' +84 + number)
Ruling: pause 2c after Task 6; run mock-parity plan for built screens first (AppButton sizes etc. are needed by 2c UI tasks), then resume 2c at Task 7
Resumed 2026-10-02 (SDD) from handover copy; next Task 7. Mock-parity-1 done (AppButton sizes, AppOptionTile, AppFooterBar exist). Rules emulator tests not run (user, acca7aa).
## Preflight (resume, Tasks 7–13)
| Pair/Task | Shared | Finding |
|---|---|---|
| Global "AppButton.primary fixed 52dp" ↔ mock-parity c54eaae | controlHeight | now 48; AppButtonSize small/xsmall exist |
| T7–T12 ↔ AppChip (mock-parity 68f7809) | chip visuals | AppChip has no check icon now; kinds filter/context |
| T11 S40 sheet / T12 S38/S39 ↔ AppOptionTile, AppFooterBar, theme AppBar (centred serif 17 sub-screens) | shared widgets | reuse instead of new equivalents |
| T6 rules tests | emulator | not run locally (user acca7aa); CI runs |
Ruling: "52dp/controlHeight" in plan text means controlHeight (48 since mock parity) — cost if wrong: none, token-driven
Ruling: UI tasks follow the committed mock S38/S39/S40 over plan visuals; behaviour per plan/spec — CLAUDE.md rule — cost if wrong: visual rework
Ruling: AppChip "check when selected" assumption is obsolete; selected state via fill/border + semantics — cost if wrong: test expectation tweak
Task 7: BASE acca7aa; implementer dispatched (sonnet)
Task 7: 3dc10a6 DONE_WITH_CONCERNS (meter text sizes via theme vs mock 12.5/13); review dispatched
Task 7: ⚠️ resolved — colorScheme.secondary = surfaceMuted = mock --field (app_theme.dart)
Task 7: minor (deferred): CompletenessMeter title/percent use bodyMedium vs mock 12.5/13px — tune in S38 task (T12)
Task 7: minor (deferred): core.dart export order skill_chip after stat_tile
Task 7: complete (commits acca7aa..3dc10a6, review clean)
Task 8: BASE 3dc10a6
Task 8: 05d62c9 DONE; review dispatched
Task 8: ⚠️ resolved — controller re-ran full suite (907 pass); scheme.secondary = field
Task 8: minor (deferred): light-mode dimmed "Chuyên sâu" (#AEAEAE on field) low contrast; title wrap test asserts no exception only
Task 8: complete (commits 3dc10a6..05d62c9, review clean)
Task 9: BASE 05d62c9
Task 9: 7136dbf DONE; review dispatched
Task 9: ⚠️ resolved — cacheWidth asserted by evidence_picker_test (implementer GREEN 6/6, suite 913)
Task 9: minor (deferred): SystemSound not asserted; tile radius AppRadius.sm 4 vs mock 6 (no token)
Carry to Task 11: EvidencePicker.onEndReached fires on every scroll notification near the end — S40 must guard (loading/hasMore flag)
Task 9: complete (commits 05d62c9..7136dbf, review clean)
Task 10: BASE 7136dbf
Task 10: f102383 DONE; review dispatched
Task 10: review needs fixes (Important: unchanged submit leaves dirty true; ⚠️ 18-lookup cap not enforced for malformed drafts)
Task 10: Ruling: fix the plan-mandated unchanged-submit branch (reset start=draft) — leave guard would ask after a successful save; spec intent is "dirty = unsaved edits" — cost if wrong: none
Task 10: Ruling: ⚠️ cap — confirmed gap; truncate evidence lookups to 18 (brief says "at most 18") — cost if wrong: none
Task 10: Ruling: ⚠️ plain Provider for analytics/draft store accepted — synchronous, no async retry; brief mandates the code — cost if wrong: none
Task 10: minor (deferred): failed save restores pre-save snapshot (discardDraft during save reverted in memory); invalidate skipped if editor closed mid-save; concurrent submit returns failed; cleaned-evidence baseline mismatch; retry test does not prove its title
Task 10: fix round 1 dispatched (resume implementer)
Task 10: fix round 1/5 (2 addressed, 0 open; commits f102383..6b7f591)
Task 10: complete (commits 7136dbf..6b7f591, review clean)
Task 11: BASE 6b7f591
Task 11: 3812c49, dcb9d9f DONE; review dispatched
Task 11: review needs fixes (Important: fetch-once and no-retry tests cannot fail — need a call counter on FakePostRepository)
Task 11: Ruling: strengthen the plan-mandated "not retried by scrolling" test with a call counter — doesn't contradict the plan, makes it prove its title — cost if wrong: none
Task 11: minor (deferred): skillsCount(…, 3) hard-coded vs SkillLimits.maxEvidence; skeleton height 100 not square; test title says 52dp; redundant SizedBox(controlHeight); no inline "couldn't load more" row
Task 11: fix round 1 dispatched (resume implementer)
Task 11: fix round 1/5 (2 addressed, 0 open; commits dcb9d9f..ae2ac0a)
Task 11: complete (commits 6b7f591..ae2ac0a, review clean)
Task 12: BASE ae2ac0a
Task 12: 128a471 DONE_WITH_CONCERNS (/setup/2 not routed → setup back with no history hits error page; nothing links to /setup/3 yet; footer labels clip at large scale); review dispatched
Task 12: ⚠️ entry links — nothing links to /setup/3 or /profile/skills yet; Ruling: carried to plan 2d1 (S24 setup flow → /setup/3) and the S30/S42 photographer links (audit R6) — brief does not ask for them — cost if wrong: screens unreachable until those plans run
Task 12: minor (deferred): system back during save opens the leave sheet (discard races the save); /setup/2 fallback is an unrouted dead route on cold deep links; AppButton label has no maxLines (clips at large scale); test gaps (real system back, unknown skill= id, setup back with changes); no AppBar back on cold deep link to /profile/skills/evidence
Task 12: complete (commits ae2ac0a..128a471, review clean)
Task 13: BASE 128a471
Task 13: 862810e DONE; review dispatched
Task 13: ⚠️ resolved — onPhotographerWrite (completeness + evidence ownership re-check) is named in the spec but no plan builds it (not in backend-phase1). Ruling: docs keep "khi có Function" wording; gap reported to user — cost if wrong: evidence ownership never enforced server-side, completeness stays device-only
Task 13: minor (deferred): §3e.3 older bullet still says rules check taxonomy + evidence ownership (contradicts new bullet); photographer.md S38 stale "lỗi tải danh mục" line and "· Chưa có" tags; §3e.2 "Do Function tính" wording
Task 13: complete (commits 128a471..862810e, review clean)
Task 14: moved to final battery/performance plan — nothing to do
Final review: opus, 0 Critical, 4 Important (S40 paging, discard during save, spec contradiction, evidence ownership gap → Function design), 9 Minor. Ruling: Minor 1 (double-tap push S34) re-graded Important — user-visible — cost if wrong: one small fix. Important 4 handled by the onPhotographerWrite design the user requested. Fix wave dispatched (FIX_BASE 862810e)
Final: fix wave a0b7e5c..cfd034b — re-review: 2,3,4 ADDRESSED; 1 partly (a,b,d done; c open)
Final: parked — S40 stall: when a load adds no own thumbs (or only same-row tiles) and hasMore stays true, no ScrollMetricsNotification fires, so loading stops with a blank/short grid — Ruling: real, user-visible, not load-bearing for other tasks; no second fix wave per process → surfaced to user with a proposed follow-up (controller keeps fetching while < pageSize own thumbs and a cursor remains, or post-frame re-check) — cost if wrong: photographers whose recent pages are mostly customer posts cannot pick evidence
Final: minor (deferred): S40 retry row not in mock (spec updated; mock not edited per user); blank grid with no spinner while paging; retry row disappears during retry with no indicator
