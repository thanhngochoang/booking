# SDD ledger — plan: docs/superpowers/plans/2026-10-01-step3b1-feed-data.md
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md (reachable)
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| T1→T2..T5 | read models + fixtures | consumed by name; check in review |
| T2 contract test → T3,T4 | shared contract run against fakes and Firestore adapters (fake_cloud_firestore) | ok |
| T3,T4 pubspec | T3 adds fake_cloud_firestore | ok |
| T5 rules | firestore.rules already has users/private/contact, photographers contactChannels/serviceArea (2b) | must merge, not overwrite; controller runs emulator |
| existing lib/data/photographer (2b: photographer_contact.dart) | PhotographerSummary new in lib/data/content | no clash; keep separate |
Ruling: commit trailer per environment, not reviewed.
Ruling: emulator rules tests run by controller (sandbox).
Task 1: complete 47b752e (approved; parked: adapters must drop posts with no images — cover uses images.first)
Task 2: review needs fixes (contract too weak: ties, idempotency, VN day, filtered cursors, limits)
Ruling: post order createdAt desc then id desc; stale cursor -> empty page; activeFor limit 50; candidates is the one 200-cap exception; summaries chunk 30 — global 'bounded reads' + adapter correctness — Tasks 3-4 adapters must follow (carry in dispatch)
Ruling: counters-untouched check lives in Task 3 adapter test
Task 2: fix round 1 dispatched
Task 2: fix round 2 d8eb887+a936f42 — controller verified clamp present
Task 2: complete a936f42
Ruling: impl-common gains 'verify each edit landed' after 2 silent-edit misses
Task 3: review needs fixes (cursor vs skipped docs; wrong-typed field crashes page)
Ruling: adapter tops up (≤3 extra rounds) to keep 'cursor exactly when more follow' — contract authority — extra reads only when docs are skipped
Carry to Task 5: posts indexes (kind,createdAt desc), (specialty,createdAt desc), (kind,specialty,createdAt desc), (photographerId,createdAt desc); likes/saves rules must allow idempotent set() on an existing marker (update with same fields)
Task 3: fix round 1 dispatched
Task 3: fix e22cb66 — controller verified top-up loop
Task 3: complete e22cb66 (parked: savedAmong one get per id — 20 reads/page)
Task 4: review needs fixes (missing rating invariant, duplicated chunk logic, invalid ids)
Ruling: server always writes stats.rating (0) with nextFreeDate — keeps correct limit-boundary order — functions plan must honour it
Carry to Task 5: photographers index (onboardingComplete ASC, stats.nextFreeDate ASC, stats.rating DESC, __name__ ASC) replaces the plan's 2-field one
Task 4: fix round 1 dispatched
Task 4: fix 2aae1a7 — controller verified
Task 4: complete 2aae1a7
Task 5: controller emulator run 40/40 pass
Task 5: complete 533c2d1 (approved; final wave: allow get + list false on markers, uid-prefix check without regex + resource.userId, non-vacuous counter test, explicit update test)
Task 6: complete 87ac834 (controller-reviewed; device profiling pending)
Final review (opus): ready with fixes — serviceArea.center (plan used stale 'geo'), marker rules hardening, savedAmong query, real counter test, id guards, docs
Ruling: take savedAmong whereIn query + own-only list rule — halves Home reads — needs rules test
Carry to Functions plan: counters only on marker create/delete (not on set-update); denormalise displayName/avatar onto photographers and posts
Final fix wave dispatched
Final fix ff4c612+3801020 — emulator 43/43, suite 663
Ruling: marker prefix via split('_')[0] assumes uids have no '_' (Firebase uids are alnum) — documented — revisit for self-hosted ids
