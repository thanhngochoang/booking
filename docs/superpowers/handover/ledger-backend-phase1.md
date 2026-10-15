# SDD ledger — plan: docs/superpowers/plans/2026-10-01-backend-phase1-firebase-local.md
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md (contact 3b, 3e) + docs/superpowers/specs/2026-10-02-photographer-write-function-design.md (Tasks 10–14); data-model/README.md. Reachable.
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| T1→T2,T3,T10 | packages/domain scaffold, ErrorCode, ids | consumed by name |
| T3→T4,T6 | getContactLink use case/ports | ok |
| T4→T5,T6,T11 | functions project, config REGION/options, db(), build | T11 consumes CALLABLE-style options for a trigger; spec lists its own trigger options (30s) — T11 text uses spec values |
| T5→T6,T11 | emulator harness | integration tests CI-only |
| T7↔T14 | flutter.yml / firebase-deploy.yml | T14 moves T7's functions steps into a separate job (plan says so) |
| T8 | Flutter → emulators | device/Genymotion steps deferred to final plan (standing rule) |
| T10→T11,T13 | skills rules, score, next code | add percentAfter (see ruling) |
| T11↔T12 | server-owned fields | add completenessNextAfter to the pinned list |
| T13↔mock S38 | hint copy "để lên N%" | plan drops N% and T14 edits the mock — conflicts with user rule "do not change the mock" |
| T14 | docs, mock line, plan 2d2 patch, FIREBASE-SETUP §11 | drop the mock edit |
| T5–T7 text | "run emulator tests locally (outside sandbox)" | conflicts with the 2026-10-02 CI-only rule |
Ruling: keep the mock's "để lên N%" — Function also writes `skills.completenessNextAfter` (int, score once the next step is done; null at 100); T10 computes it (same as the old Dart percentAfter), T11 writes it, T12 pins it, T13 shows it, T14 does NOT edit ui-mock.html — user rule: mock not changed — cost if wrong: one more server field
Ruling: every emulator run (rules-test npm test, test:integration, emulators:exec, scripts/backend-local.sh starts) is CI-only in all tasks, incl. T4–T7; write the tests/scripts, verify locally with typecheck/lint/unit tests; ledger each skipped Expected — user rule 2026-10-02 + sandbox — cost if wrong: emulator bugs surface on CI after push
Ruling: T8 device/Genymotion/iOS steps skipped (final plan + iOS last); Flutter unit/widget steps run — standing rules — cost if wrong: device issues found late
Ruling: CI deploy to dev happens on push once FIREBASE_PROJECT_ID + Blaze + IAM exist; job skips otherwise (plan T14) — user asked deploy via CI — cost if wrong: failed deploy job until setup is done
Ruling: commit trailer per environment; push with gh over HTTPS after each task's review (user prefers I push) — cost if wrong: CI runs per push
Task 1: BASE 3bcfe7d
Task 1: 665109e DONE (not reviewed yet) — PAUSED: user asked 'undo hết', scope being clarified
User 2026-10-02: no undo; continue everything; run many subagents in parallel. Ruling: pipeline — review Task N while Task N+1 implements (domain tasks are additive); parallel track B = plan 2d1 in its own worktree with a sub-controller — cost if wrong: rework if a review of N changes an interface N+1 used
Task 1: review dispatched; Task 2: BASE 665109e, implementer dispatched in parallel
Task 1: ⚠️ phone vectors vs app_flutter/test/core/phone_test.dart — checked: file exists; cross-language parity left to final review (sample check below)
Task 1: minor (deferred): purity test regex misses side-effect/dynamic imports and require; eslint list lacks bare node builtins (purity test catches)
Task 1: complete (commits 3bcfe7d..665109e, review clean)
Task 2: c97f3b5 DONE; review dispatched. Task 3: BASE c97f3b5, implementer dispatched in parallel
Task 3: 6233086 DONE (no RED seen — reviewer asked to check test strength); review dispatched. Task 4: BASE 6233086, implementer dispatched
Task 2: ⚠️ resolved — controller re-ran domain typecheck/lint/test at 6233086
Task 2: minor (deferred): empty-string zaloPhone not normalised to null (fails closed, same as Dart); ports.ts comment names a path that does not exist yet
Task 2: complete (commits 665109e..c97f3b5, review clean)
Task 3: mutation review: all key mutations caught; gaps: lock-before-owner reorder (would leak lock state to non-owners), duplicate log row on refusal
Task 3: minor (deferred): add non-owner + locked booking test (permission_denied) and logs.length===1 on refusals; doc that infra read errors write no log row; granted registration log subjectType unasserted
Task 3: complete (commits c97f3b5..6233086, review clean)
Task 4: 965e991 DONE_WITH_CONCERNS
Task 4: Ruling: keep the existing owner-only storage.rules instead of the brief's deny-all — real rules already ship; deny-all would break avatar/album uploads — cost if wrong: none
Task 4: Ruling: subagent trailer "Claude Sonnet 5.5" accepted (trailer per environment, ledger ruling) — cost if wrong: cosmetic
Task 4: note: npm audit 19 dev-only vulnerabilities (firebase-tools tree) — not addressed
Task 4: review dispatched. Task 5: BASE 965e991, implementer dispatched
Task 4: minor (deferred): firestoreUserContactReader passes phone unvalidated (domain requirePhone rejects non-strings → phone_required, so safe); no adapter unit tests with a fake db; engines.node "22" warns on newer local Node
Task 4: complete (commits 6233086..965e991, review clean)
Task 5: bcfc66d DONE; review dispatched. Task 6: BASE bcfc66d, implementer dispatched
Task 5: review approved; Ruling: re-grade Minor 1 → Important — applySeed / integration test have no local-emulator guard; run outside emulators:exec with ADC + a real GCLOUD_PROJECT they write seed users with a known password into the real project (security effect) — cost if wrong: one small fix
Task 5: fix round 1 queued until Task 6's implementer finishes (same package, emulator_client.ts) — shared assertLocalEmulators() (anchored local-host regex for all three emulator hosts) called from emulatorProject()/applySeed, require project id to start with demo-
Task 5: minor (deferred): seed omits avatarUrl/skills/stats/startingPrice/serviceArea.center; writes booking fields adapters don't read
Task 6: 9c37777 DONE; review dispatched. Task 5: fix round 1 dispatched (FIX_BASE 9c37777)
Task 5: fix round 1 6b8882b (guard; seed.ts allowAnyProject because dev script uses the google-services project id; hosts still enforced); re-review dispatched. Task 7: BASE 6b8882b, implementer dispatched
Task 6: ⚠️ requested unlocks contact — spec: draft→requested only on payment paid (domain-model §5, remaining-screens 293/296), so the rule is right; Ruling: tracked — bookings must not let a client write status requested without a paid payment; owned by the payments plan (i6) / transitionBooking — cost if wrong: contact unlock without deposit if rules allow it
Task 6: ⚠️ enforceAppCheck false — deferred to the deploy/App Check work as documented; tracked
Task 6: minor (deferred): refusal bodies not all scanned for digits; no integration test for unknown booking id / invalid stored number; rules test lacks list/update/delete on contact_access_log; read_budget source scan cwd-relative and narrow regex; unauthenticated test checks status only
Task 6: complete (commits bcfc66d..9c37777, review clean)
Task 6: ⚠️ requested — verified firestore.rules:285 bookings allow write: if false (Functions only), client cannot set requested; item closed
Task 5: fix round 1/5 (1 addressed, 0 open; commits 9c37777..6b8882b)
Task 5: minor (deferred): signIn/resetEmulators read host env directly without their own guard; guard written before its test (no RED)
Task 5: complete (commits 965e991..6b8882b, 1 fix round)
Task 7: 4aba820 DONE (controller verified typecheck/lint scripts exist + CLAUDE.md CI-only line kept); review dispatched. Task 8: BASE 4aba820, implementer dispatched
Task 7: minor (deferred): unset GOOGLE_APPLICATION_CREDENTIALS before emulators start (project id is the real one from google-services.json); seed waiter probes only Firestore/Auth; --lan exposes Emulator UI/hub with no warning; README iOS host claim depends on Task 8
Task 7: complete (commits 6b8882b..4aba820, review clean)
Task 8: BLOCKED (firebase_storage missing; pub.dev blocked for subagent). Controller ran `flutter pub add firebase_storage:^13.6.0` with allowed_domains pub.dev — uncommitted pubspec.yaml/lock (lock also carries 2 pre-existing transitive bumps jni 1.1.0, package_info_plus 10.2.2). Ruling: implementer commits pubspec changes with Task 8 — cost if wrong: two unrelated transitive bumps ride along
Task 8: 4b84326 DONE (suite 983); review dispatched. Task 10: BASE 4b84326, implementer dispatched (Task 9 moved — nothing to do)
Task 10: 7b369e1 DONE (nextAfter + SERVER_SKILL_FIELDS 5 entries incl completenessNextAfter); review dispatched. Task 11: BASE 7b369e1, implementer dispatched
Task 11: a30f501 DONE; review dispatched. Task 12: BASE a30f501, implementer dispatched
Task 8: minor (deferred): plan-2b doc line not wrapped like dart format; main.dart comment "runs before any other Firebase call" loose; lock bumps not named in commit body
Task 8: complete (commits 4aba820..4b84326, review clean)
Task 10: review needs fixes (Important: nextAfter for the evidence step fixes only the first level-3 genre without posts; Dart fixes all → 80 vs 100 with two such genres)
Task 10: minor (deferred): 'levels' branch of withStepDone unreachable (comment or mirror Dart); evidenceIds slice(0,18) relies on rules caps (check T12); integer() accepts 6.0
Task 10: fix round 1 dispatched (resume implementer); Task 12 waits for it (one implementer at a time)
Task 10: fix round 1 69ed64c; re-review dispatched. Task 12: BASE 69ed64c, implementer dispatched
Task 10: fix round 1/5 (1 addressed, 0 open; commits a30f501..69ed64c)
Task 10: complete (commits 4b84326..69ed64c, 1 fix round)
Carry to Task 13: the evidence hint names a genre ("cho Chân dung") — server stores only the step code; Ruling: the app picks the genre for display as the first level-3 genre without evidence in the saved skills (display only, no score computed on device) — cost if wrong: genre name could differ from what the server meant if specialties order changes
Task 12: d3e7bf7 DONE (budget unverified until CI); review dispatched. Task 13: BASE d3e7bf7, implementer dispatched (opus)
Task 11: review approved. Ruling: re-grade Minor 1 → Important — retry:true rethrows permanent errors (INVALID_ARGUMENT, undefined field) → retried ~7 days, burning invocations; fix: drop events older than ~1h (event.time) with an error log (uid only), and treat codes 3/7 as non-retryable — carried into the final-review fix wave (an implementer is busy on Task 13) — cost if wrong: one small change
Task 11: minor (deferred): writer's written/stale paths lack unit tests with a fake Firestore; no emulator test for the stale race; negative integration tests rely on fixed sleeps
Task 11: complete (commits 7b369e1..a30f501, review clean; 1 item carried to final wave)
Task 12: ⚠️ rules tests pass + no "Exceeded maximum number of expressions" — CI-only; check CI after push (est. ~886/1000)
Task 12: minor (deferred): completenessNextAfter test data uses strings; reused doc ids k12–k14 across tests; no dotted-path set assert for the new fields; stale fullProfileOwner comment; costliest path (create / skills+serviceArea+contactChannels) not budget-tested
Task 12: complete (commits 69ed64c..d3e7bf7, review clean)
Task 13: 2a4f142 DONE (suite 991); review dispatched. Task 14: BASE 2a4f142, implementer dispatched
Task 14: 0f11c36 DONE (mock not edited per ruling); review dispatched
Task 13: ⚠️ copy for no-score / unsaved / removal states comes from spec §3 (mock shows only the scored state) — consistent; Function writes completenessNextAfter as int|null (Task 11 tests)
Task 13: minor (deferred): "Lưu để cập nhật độ khớp" right after a save while S38 is still mounted (S38 leaves after save, so barely visible); spurious "save to update" on open when the saved map parses empty or an evidence post was deleted before the Function cleaned it; long doc comment line; concatenated l10n fragment
Task 13: complete (commits d3e7bf7..2a4f142, review clean)
Task 14: review approved with 1 Important — FIREBASE-SETUP §11 IAM list likely incomplete for the first --force deploy (Cloud Functions Admin, Artifact Registry Administrator, Cloud Build builder role) → carried into the final fix wave
Task 14: Ruling: re-grade "--force deletes functions not in src/index.ts" Minor → Important (can delete hand-deployed functions in booking-c1922) → final fix wave: doc warning + check before first deploy — cost if wrong: one doc change
Task 14: minor (deferred): duplicate functions path filter; functions checks run twice per push; second production approval for deploy-functions undocumented; no `permissions: contents: read`
Task 14: complete (commits 2a4f142..0f11c36, review clean; 2 items carried)
Final review: dispatched (opus), range 3bcfe7d..0f11c36
Final review: opus — 1 Critical (integration tests need FUNCTIONS_EMULATOR_HOST), 3 Important (stale/unchanged race leaves profile unscored; rules deploy job red pre-existing; try:contact doc broken), queued a/b/c agreed; Minors triaged
Final: Ruling: include reviewer-recommended cheap items (unset ADC, --lan warning, permissions block, internal error name/code log, drop dead test:perf) in the single fix wave — cost if wrong: small extra diff
Final: minor (deferred): iOS NSAllowsLocalNetworking in release Info.plist; S38 may show a stale score as current until the Function runs; deploy may install devDependencies (firebase-tools) — verify on first deploy
Final: closed: evidenceIds slice(0,18) (rules cap 6×3); empty zaloPhone (rules reject '')
Final: fix wave dispatched (FIX_BASE 0f11c36)
Final: fix wave 0f11c36..c97514c (7 commits, domain 93, functions 45); re-review dispatched
Final: re-review — all 10 addressed, no new Critical/Important; CI expected green (not run)
Final: minor (deferred): stale-path re-read skips the pure unchanged check (one extra getAll); a dropped event that only swapped evidence ids to a foreign post keeps them until the next skills edit; spec §2 "Bỏ qua" list lacks completenessNextAfter; alert on code-7 drop logs; allowAnyProject test covers refusals only
Plan backend-phase1-firebase-local: DONE
