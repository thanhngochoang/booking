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
