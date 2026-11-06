# Firebase backend → booking-be (#299) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this repo the unit runs through the `run-next-plan` skill (claim #299, branch `plan/299-<slug>` from `project.py claim`, PR into `develop`). The same branch name is used in booking-be (D5). This unit moves code between two repositories. It has **two PRs, and the booking-be PR merges first**. A few steps belong to the owner (secrets, rulesets, environments); they are listed under "Owner steps" and the agent stops and asks for them.

**Goal:** booking-be becomes the home of the whole backend: the Cloud Functions (with seed, tools CLI and tests), the Firestore/Storage rules and indexes, `rules-test`, `firebase.json`/`.firebaserc`, `packages/domain`, and the Firebase CI (deploy with the `BLAZE_ENABLED` switch). The history comes along, as it did for `services/api` in #286. The app repo keeps `firebase_options.dart`, the Dart adapters, the contract snapshot and every doc (D2). The 7 app tests that read backend files read them from a pinned sparse checkout of booking-be (`backend.lock`, D6). The domain now lives in the same repo as the API, so booking-be drops `domain.lock`/`sync-domain.sh` (D7).

**Architecture:**
- **booking-be layout after the move** (the API stays at the root, where #286 put it):

  ```
  booking-be/
    api/ src/ test/ tools/ migrations/ docker/ …   Fastify API (unchanged)
    firebase/                                       was booking app_flutter/firebase/
      firebase.json .firebaserc firestore.rules firestore.indexes.json storage.rules .gitignore
      functions/   (src, seed, tools, test/unit, test/integration, assets, build.mjs, package.json …)
      rules-test/
    packages/domain/                                was booking packages/domain/ (same path)
    scripts/backend-local.sh spots-local.sh awards-local.sh verifications-local.sh   (from booking scripts/)
    .github/workflows/ci.yml firebase-deploy.yml, .github/dependabot.yml
  ```

  `packages/domain` keeps its path, so every `packages/domain/...` path in the specs, the data model and code comments stays correct. `app_flutter/firebase/X` becomes `firebase/X`.
- **History:** `git subtree split` of `app_flutter/firebase` and `packages/domain` in booking. Then `git subtree add --prefix=firebase` and `--prefix=packages/domain` in booking-be. Both folders were created at these paths (2026-10-01/02), so their whole history comes along. The booking-be PR is merged with **a merge commit**. Squash or rebase would flatten or drop the imported history.
- **Domain in one repo (D7):** the API keeps importing through `src/domain/index.ts`, now from `../../packages/domain/src/index.js`, which is a tracked folder. The Functions keep their tsconfig alias `@photobooking/domain`, now pointing at `../../packages/domain/src/index`.
- **App side (D6):** `backend.lock` (`repo=`, `branch=`, `ref=`) and `scripts/sync-backend.sh` (sparse, blob-less clone) fill the gitignored `.backend/` at the repo root with only the files the app tests read. The tests read `../.backend/<booking-be path>` with literal `File(...)` paths. They call a shared guard that fails with a hint when the snapshot is missing or not at the locked commit. The guard reads `../backend.lock` literally, so `tool/affected_test.dart` selects every test that imports it whenever the lock changes.
- **Local emulators:** the four scripts move to booking-be. booking keeps thin wrappers with the same names. They set the repo's JDK, CA certificates and `HOME`, find the booking-be checkout (`$BOOKING_BE_DIR`, default the sibling `../booking-be`) and `exec` its script. They warn when that checkout does not contain the commit in `backend.lock`.

**Tech Stack:** git subtree, GitHub Actions, npm (four separate packages, no workspaces), Bash, Dart (`flutter_test`, `tool/affected_test.dart`), Python 3 (`land.py`).

**Issue:** thanhngochoang/booking#299 (scope, D1–D7 approved by the owner 2026-10-27). Earlier split: #286 (services/api → booking-be). Docs-only preparation: #311.

**Depends on:**
- **#320 (dependency upgrade) must be merged before this unit starts.** It touches every `package.json`/lockfile and workflow moved here. It merged into `develop` as `d68927cd` (2026-11-04). If you are reading this on a branch where it is not yet in `origin/develop`, stop: the subtree split must be cut from a `develop` that already has it. Otherwise the move would carry pre-upgrade lockfiles and #320 would have to be redone in booking-be.
- #139, #207 and #223 (the units that edited Functions/rules/domain, D4) are merged and closed. Before Task A1, check again that no open PR in booking touches `app_flutter/firebase/**` or `packages/**` (Task A1, step 1).

## Global Constraints

**Moving code**
- No behaviour change. Files move with their history, and only paths, CI, scripts and docs change. The single code change in booking-be is D7's error-status mapping (Task A3) plus the seed test that read app Dart (Task A2).
- **Freeze:** between the subtree split (Task A1) and the merge of the booking PR (Part B), nobody changes `app_flutter/firebase/**` or `packages/domain/**` in booking. Task B1 checks that these paths are identical at the split commit and on the `origin/develop` the booking PR is based on.
- The booking-be PR is merged with **"Create a merge commit"** (the repo allows it), never squash or rebase.
- Four npm packages stay separate, each with its own lockfile: root API, `packages/domain`, `firebase/functions`, `firebase/rules-test`. No npm workspaces: the Functions deploy reads `firebase/functions/package.json` + lockfile as they are.

**Deploy safety**
- The Blaze switch stays exactly as it is: Cloud Functions and Storage deploy only when the environment variable `BLAZE_ENABLED` is `true`, and a missing `FIREBASE_PROJECT_ID` skips every deploy. The owner keeps Blaze off.
- Only one repo may deploy at a time. booking-be gets its environments (`dev`, `production`) and secrets **only after the booking PR has merged and removed `firebase-deploy.yml`** (Owner step O5). Until then, booking-be's deploy job runs and skips with the "FIREBASE_PROJECT_ID is not set" warning.
- Never run `firebase deploy`, `firebase login` or anything against a real project from the plan. CI deploys.

**Secrets and accounts**
- Agents never handle secret values: deploy keys, service-account JSON or tokens. Creating them, and every Settings change (environments, rulesets, deploy keys, Dependabot secrets), is an owner step.
- booking-be is **private** and booking is **public**. booking CI reads booking-be through a read-only deploy key (`BOOKING_BE_DEPLOY_KEY`). Fork PRs to booking get no secrets, so their test job fails at the sync step. That is accepted: only the owner's machines open PRs.

**Project rules**
- Commits in booking end with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`. Commits in booking-be follow `type(scope): summary [#299]` with the same trailer, and the booking-be PR body says `thanhngochoang/booking#299` (D5: `[#299]` in the title does not link across repos).
- Handoff log in each repo (`python3 .agents/skills/agent-handoff/scripts/handoff.py status` first; both repos have the skill).
- The sandbox cannot run the emulator suites (`rules-test`, Functions `test:integration`); CI runs them. Say so in both PRs.
- Worktrees go in the session scratchpad, not inside `booking/` (`.idea/` is not writable). For booking, symlink `.flutter`, `.jdk`, `.android-sdk`, `.home` and `.pub-cache` from the main checkout before running Flutter.

## Decisions taken in this plan

- **P1 · Target paths:** `firebase/` and `packages/domain/` at the booking-be root (the issue's example). Paths inside `firebase/` stay the same, so `--config ../firebase.json`, `../firestore.rules` in `rules-test`, `../../.firebaserc` in `tools/payouts.ts` and `../../../firestore.indexes.json` in the Functions tests need no edit.
- **P2 · Error statuses (D7):** 13 domain codes have no `HTTP_STATUS` in the API today. The issue named 2; #139/#207/#223/#141 added the rest. Map them by the convention already in `src/errors.ts`: a state the request cannot enter → 409; a permission → 403; a refused value → 422; a cap → 429.

  | code | status | | code | status |
  |--|--|--|--|--|
  | `collab_full` | 429 | | `not_your_pass` | 403 |
  | `recruit_blocked` | 403 | | `wrong_day` | 422 |
  | `spot_managed` | 409 | | `too_early` | 422 |
  | `not_spot_manager` | 403 | | `already_checked_in` | 409 |
  | `day_closed` | 409 | | `venue_consent_required` | 409 |
  | `sold_out_day` | 409 | | `business_required` | 403 |
  | `refunded` | 409 | | | |

  Typecheck lists any code missing at execution time (the map is exhaustive by type). Codes added later than this table get a status by the same convention, and a line in the PR body.
- **P3 · Emulators from the booking-be checkout, not from `.backend/`:** whoever changes the backend works in that checkout anyway, and a full `npm ci` of the Functions inside a gitignored snapshot would be a second, stale copy. `.backend/` holds only the files the tests read.
- **P4 · CI access to the private repo:** a read-only deploy key on booking-be (not a personal token: a deploy key is scoped to one repo and does not expire with a user). It is stored as an Actions secret **and** a Dependabot secret in booking, because Dependabot's pub PRs run `flutter.yml` without Actions secrets.
- **P5 · CodeQL:** booking keeps CodeQL for Python only (no TypeScript is left). Code scanning on the private booking-be needs GitHub Code Security, which is not enabled (`code-scanning/default-setup` answers 403). So booking-be gets no `codeql.yml` in this unit; the owner decides (O7).
- **P6 · The seed test that read app Dart:** `firebase/functions/test/unit/seed_fixtures.test.ts` ("instant config areas are the built-in areas of the app") reads `app_flutter/lib/data/location/area.dart`, which booking-be does not have. In booking-be it compares the seed's centres with `RECRUIT_AREAS` (`packages/domain/src/recruit_areas.ts`, same repo, same order). The names check moves to the app's `area_sync_test.dart`, which reads the seed from `.backend/`. The chain Dart ↔ domain ↔ seed stays closed.

## Review Focus

1. **History survives the merge.** After the booking-be PR merges, `git log --follow firebase/firestore.rules` and `git log -- packages/domain/src/errors.ts` in booking-be show the October 2026 commits, not one import commit. If the PR was squashed, the history is lost; the fix is to revert and redo it with a merge commit.
2. **No double deploy, no gap that loses rules.** A push to booking `develop` after the booking PR must not trigger any Firebase deploy (the workflow is gone). booking-be deploys only after O5. The first booking-be deploy (O6, manual `workflow_dispatch` to `dev`) deploys the same rules that are live, because of the freeze.
3. **Blaze switch unchanged.** In booking-be's `firebase-deploy.yml`, with `BLAZE_ENABLED` unset, the run deploys rules + indexes only and prints both warnings (Functions, Storage). Compare the job conditions line by line with booking's file at the split commit.
4. **The 8 app tests fail loudly, never skip,** when `.backend/` is missing or stale, and `dart run tool/affected_test.dart` selects all 8 when only `backend.lock` changes (Task B4 has the test).
5. **API still typechecks against the newest domain** (TypeScript 5.x root vs domain's `~6.0.3`): `npm run typecheck` at the booking-be root, after the error-status mapping.
6. **booking's required checks:** the ruleset on `develop` requires `firestore-rules` and `functions`, which this unit deletes. Without O3 the booking PR can never merge.

## Owner steps (non-code)

The agent prepares everything else and asks at the point marked in each task.

| # | When | What | Where |
|--|--|--|--|
| O1 | before Task A4 | Check that booking-be (private) can have **environments with secrets** on the owner's GitHub plan (GitHub Free does not offer environments in private repos). If not, say so: Task A4 then uses the fallback (repo-level `*_DEV`/`*_PROD` variables and secrets). | booking-be Settings → Environments |
| O2 | before Task B5 | Create a deploy key: `ssh-keygen -t ed25519 -N '' -C booking-ci-read -f booking_be_ci`. Add `booking_be_ci.pub` to booking-be → Settings → Deploy keys (read-only). Add the private key as the secret `BOOKING_BE_DEPLOY_KEY` in booking → Settings → Secrets → **Actions** and → **Dependabot**. | both repos |
| O3 | before merging the booking PR | Ruleset "protect develop" (id 24398363) in booking: remove the required checks `firestore-rules` and `functions`. Keep `analyze` and `report`. | booking Settings → Rules |
| O4 | optional, after A merges | Ruleset on booking-be `develop` requiring `test`, `docker`, `domain`, `functions`, `firestore-rules` (squash and merge-commit both allowed; this unit needs merge commit). | booking-be Settings → Rules |
| O5 | after the booking PR merges | In booking-be create environments `dev` and `production`. Add the variable `FIREBASE_PROJECT_ID` (dev = `booking-c1922`; production as in booking) and the secret `FIREBASE_SERVICE_ACCOUNT`. Leave `BLAZE_ENABLED` unset. booking keeps the service account as a repo-level secret today; in booking-be put it in each environment. | booking-be Settings → Environments |
| O6 | after O5 | Run `firebase-deploy` by hand in booking-be (target `dev`, storage off). Check in the Firebase console that the rules' publish time changed and the content is the same. | booking-be Actions |
| O7 | any time | CodeQL for TypeScript in booking-be: enable GitHub Code Security (then add `codeql.yml`, copy of booking's), or accept no TS scanning. | owner decision |
| O8 | after O6 | Optional: delete booking's environments `dev`/`production` and the repo secret `FIREBASE_SERVICE_ACCOUNT` (nothing in booking uses them any more). | booking Settings |

## File map

| Repo | Create | Modify | Delete |
|---|---|---|---|
| booking-be | `firebase/**`, `packages/domain/**` (subtree, with history); `scripts/backend-local.sh`, `scripts/spots-local.sh`, `scripts/awards-local.sh`, `scripts/verifications-local.sh`; `.github/workflows/firebase-deploy.yml` | `firebase/functions/tsconfig.json`, 23 files in `firebase/functions/test/unit/` (domain import depth), `firebase/functions/build.mjs` (comment), `firebase/functions/seed/seed.ts` (log line), `firebase/functions/test/unit/seed_fixtures.test.ts` (P6), `firebase/functions/seed/README.md`, `src/domain/index.ts` (comment), `src/errors.ts`, `test/domain-shim.test.ts`, `.gitignore`, `Dockerfile`, `docker-compose.yml`, `.github/workflows/ci.yml`, `.github/dependabot.yml`, `AGENTS.md`, `README.md` | `domain.lock`, `scripts/sync-domain.sh`, `.agents/skills/domain-sync/`, `.claude/skills/domain-sync` |
| booking | `backend.lock`, `scripts/sync-backend.sh`, `scripts/bin/_booking-be.sh`, `app_flutter/test/support/backend_snapshot.dart` | the 7 tests + `area_sync_test.dart` names test, `app_flutter/tool/affected_test.dart`, `app_flutter/test/tool/affected/analysis_test.dart`, `docs/testing/affected-tests.md`, `.gitignore`, `.github/workflows/flutter.yml`, `.github/workflows/codeql.yml`, `.github/dependabot.yml`, `scripts/backend-local.sh`, `spots-local.sh`, `awards-local.sh`, `verifications-local.sh` (wrappers), `scripts/adb-reverse.sh` (comment), `.vscode/launch.json` + `tasks.json` (comments), `.agents/skills/run-next-plan/SKILL.md`, `.agents/skills/run-next-plan/scripts/land.py`, `AGENTS.md`, `docs/FIREBASE-SETUP.md`, `docs/SETUP.md`, `app_flutter/README.md`, `services/README.md`, `docs/superpowers/plans/RUN-ORDER.md` (standing rules), path comments in `app_flutter/lib` + `test` | `app_flutter/firebase/`, `packages/domain/` (and `packages/`), `.github/workflows/firebase-deploy.yml` |

## Order

1. Part A, booking-be PR (Tasks A1–A7). Merged with a merge commit.
2. Part B, booking PR (Tasks B1–B9). `backend.lock` pins the booking-be `develop` commit that contains Part A's merge. Merged (squash, as always in booking) after O3.
3. Part C: O5, O6, then cleanup (Task C1).

The booking PR cannot be opened for review before A merges: its `backend.lock` needs Part A's merge commit, and its tests read the moved paths. It may be prepared on its branch in parallel.

---

## Part A · booking-be PR

### Task A1: Branch, freeze check, import with history

**Files:** booking-be `firebase/**`, `packages/domain/**` (new, by subtree).

- [ ] **Step 1: Preconditions.** In booking:

  ```bash
  git fetch origin
  git merge-base --is-ancestor d68927cd origin/develop && echo "#320 in develop"
  gh pr list --repo thanhngochoang/booking --state open --json number,title,files \
    --jq '.[] | select(any(.files[]; .path | test("^(app_flutter/firebase|packages)/"))) | "\(.number) \(.title)"'
  ```

  The first must print `#320 in develop`. The second must print nothing; if it lists PRs (Dependabot npm PRs included), stop and ask the user, because each such PR has to land or close before the split. Claim the unit (`project.py claim 299`); note the branch name it prints (`plan/299-<slug>`).
- [ ] **Step 2: Split in booking** (from the main checkout; `subtree split` reads history and does not touch the worktree):

  ```bash
  SRC=$(git rev-parse origin/develop)
  git subtree split --prefix=app_flutter/firebase "$SRC" -b split/299-firebase
  git subtree split --prefix=packages/domain "$SRC" -b split/299-domain
  echo "$SRC"   # keep it: Task B1 compares against it
  ```

  `handoff.py note "split from booking $SRC"`. The split branches stay local (never push them to booking).
- [ ] **Step 3: Branch in booking-be.** Make a worktree in the scratchpad from `origin/develop` (not `main`: `develop` has the Node 24 change) on the same `plan/299-<slug>` name. Push the empty branch. Start the handoff log there.
- [ ] **Step 4: Import.** In the booking-be worktree (`../booking` = the booking main checkout, adjust the path):

  ```bash
  git subtree add --prefix=firebase /path/to/booking split/299-firebase \
    -m "chore(firebase): import app_flutter/firebase from booking with history [#299]" -m "Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>"
  git subtree add --prefix=packages/domain /path/to/booking split/299-domain \
    -m "chore(domain): import packages/domain from booking with history [#299]" -m "Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>"
  ```

  `.gitignore` still ignores `packages/`. Before the second command, remove the `packages/` line and its comment in a commit `chore: track packages/domain in this repository [#299]`. Otherwise new files added there later would be silently ignored, and `git status` hides the folder.
- [ ] **Step 5: Check.** `git log --oneline -- firebase/firestore.rules | wc -l` and `git log --oneline -- packages/domain/src/errors.ts | wc -l` are more than 1. `diff -r` of `firebase/` against booking's `app_flutter/firebase` at `$SRC` (and of `packages/domain`) shows no difference: `git -C /path/to/booking archive "$SRC" app_flutter/firebase | tar -x -C "$TMPDIR/src"` and then `diff -r`, ignoring `node_modules`.

### Task A2: Path fixes after the move

**Files:** `firebase/functions/tsconfig.json`, `firebase/functions/test/unit/*.test.ts` (23 files), `firebase/functions/build.mjs`, `firebase/functions/seed/seed.ts`, `firebase/functions/seed/README.md`, `firebase/functions/test/unit/seed_fixtures.test.ts`.

- [ ] **Step 1: tsconfig alias.** `"@photobooking/domain": ["../../packages/domain/src/index"]` (was `../../../`).
- [ ] **Step 2: Relative domain imports in tests** (41 occurrences, all `../../../../../packages/domain/` from `test/unit/`; one level less now):

  ```bash
  git grep -l '\.\./\.\./\.\./\.\./\.\./packages/domain/' -- firebase/functions \
    | xargs sed -i '' 's#\.\./\.\./\.\./\.\./\.\./packages/domain/#../../../../packages/domain/#g'
  git grep -nE '(\.\./){5}packages/domain' -- firebase   # must print nothing
  ```

- [ ] **Step 3: Remaining app paths.** `git grep -n 'app_flutter' -- firebase packages/domain` and fix code and log lines. Comments that only cite where something lived in the app (e.g. `recruit_areas.ts` naming `app_flutter/lib/data/location/area.dart`) become `booking app_flutter/...`. Known hits: `seed/seed.ts:22` (log `Accounts: firebase/functions/seed/README.md`), `build.mjs` comment (`../../../packages` → `../../packages`), and the seed README's own paths and script names (`scripts/backend-local.sh` of this repo).
- [ ] **Step 4: P6, the seed areas test.** In `seed_fixtures.test.ts` replace the test that reads `../../../../lib/data/location/area.dart` with:

  ```ts
  test('instant config areas have the centres of RECRUIT_AREAS, in order (the app test checks the names)', () => {
    assert.deepEqual(
      SEED_INSTANT_CONFIG.areas.map((a) => [a.lat, a.lng]),
      RECRUIT_AREAS.map((a) => [a.lat, a.lng]),
    );
  });
  ```

  Import `RECRUIT_AREAS` from `@photobooking/domain` (export it from the domain index if it is not exported yet; it is pure data). The names check moves to the app (Task B3, step 3). Run the test before and after; it passes both times.
- [ ] **Step 5: Verify** in `packages/domain`: `npm ci && npm run typecheck && npm run lint && npm test`. In `firebase/functions`: `npm ci && npm run lint && npm run typecheck && npm test && node build.mjs`. Paste the counts in the ledger (#320 measured 2751 domain and 994 Functions unit tests). `rules-test` and `test:integration` cannot run in the sandbox; CI runs them (Task A4).
- [ ] **Step 6: Commit** `fix(functions): domain paths after the move to booking-be [#299]`.

### Task A3: Domain in the same repo (D7)

**Files:** delete `domain.lock`, `scripts/sync-domain.sh`, `.agents/skills/domain-sync/`, `.claude/skills/domain-sync`. Modify `src/domain/index.ts`, `src/errors.ts`, `test/domain-shim.test.ts`, `Dockerfile`, `docker-compose.yml`, `.dockerignore` (check only), `README.md`.

- [ ] **Step 1:** `git rm -r domain.lock scripts/sync-domain.sh .agents/skills/domain-sync .claude/skills/domain-sync`.
- [ ] **Step 2:** `src/domain/index.ts`: same import path (`../../packages/domain/src/index.js`). Rewrite the header comment: the domain lives in this repo's `packages/domain`, shared with the Cloud Functions in `firebase/functions`; this file stays the only API file that imports it.
- [ ] **Step 3:** `npm run typecheck` at the root. It fails on `HTTP_STATUS` for every unmapped code. Add the codes of P2 in `src/errors.ts` under a comment per origin (`// Collaboration codes (#151)`, `// Organizer, entry and pass codes (#223)`, …), in the style of the existing groups. If the domain does not compile under the root's TypeScript 5.x, bump the root `typescript` to `~6.0.3` (same as the domain and Functions) in its own commit, and say why in the PR.
- [ ] **Step 4:** `test/domain-shim.test.ts`: the sorted catalogue list becomes the domain's current `ERROR_CODES`. Keep the rest unchanged.
- [ ] **Step 5:** `Dockerfile`: remove the `packages/domain is missing: run scripts/sync-domain.sh first` check and its comment (the folder is tracked now). `docker-compose.yml`: remove "needs packages/domain present". `.dockerignore` already allows `packages/domain/**` and excludes its `node_modules`: no change. Run `docker build -t booking-be:ci .` if Docker is available; otherwise CI's `docker` job checks it.
- [ ] **Step 6:** `git grep -nE 'sync-domain|domain\.lock|domain-sync|DOMAIN_REPO'` prints nothing outside old commit messages. Fix any hit in `README.md`, `.agents/skills/*/SKILL.md` and `.github/`.
- [ ] **Step 7:** `npm ci && npm run gen:types && git diff --exit-code src/generated/api.ts && npm run typecheck && npm run build && npm test` (`npm test` needs Docker/Testcontainers or `TEST_DATABASE_URL`; if neither is available, say so and leave it to CI).
- [ ] **Step 8: Commit** `refactor(domain): import the domain from this repository, drop domain.lock [#299]`.

### Task A4: CI and Dependabot in booking-be

**Files:** `.github/workflows/ci.yml`, `.github/workflows/firebase-deploy.yml` (new), `.github/dependabot.yml`.

- [ ] **Step 1: O1.** Ask the owner whether environments work in private booking-be. With environments, step 3 is a copy of booking's file. Without, use the fallback in step 4.
- [ ] **Step 2: `ci.yml`.** Remove the `sync-domain.sh` steps from `test` and `docker`. Add three jobs, copied from booking's `flutter.yml` at `$SRC` with paths adjusted:
  - `domain`: `working-directory: packages/domain`, `npm ci && npm run typecheck && npm run lint && npm test`
  - `functions`: `working-directory: firebase/functions`, `npm ci && npm run lint && npm run typecheck && npm test`
  - `firestore-rules`: Java 21 + Node 24, `working-directory: firebase/rules-test`, `npm ci && npm test`

  `ci.yml` has no `paths` filter, so the API job also runs when the domain changes; keep it that way.
- [ ] **Step 3: `firebase-deploy.yml`.** Copy booking's file at `$SRC`. Change only:
  - `on.push.branches: [develop, main]` (booking-be has no `flutter-rewrite`)
  - `on.push.paths: ['firebase/**', 'packages/domain/**', '.github/workflows/firebase-deploy.yml']`
  - every `working-directory: app_flutter/firebase/...` → `firebase/...`, and `packages/domain` unchanged
  - the header comment: "Deploys Firestore rules + indexes from firebase/ …"; setup reference stays `docs/FIREBASE-SETUP.md section 10` **of the app repository** (link the URL)

  Keep every `BLAZE`/`ON`/`PROJECT_ID` condition, `--force` and its warning, the concurrency group, and the `environment:` expressions byte for byte. Check with `diff <(git -C /path/to/booking show "$SRC":.github/workflows/firebase-deploy.yml) .github/workflows/firebase-deploy.yml`: only the lines above differ.
- [ ] **Step 4: Fallback without environments** (only if O1 says so). Drop the `environment:` keys. Add a job-level `env` that picks repo-level names by target: `TARGET: ${{ github.event_name == 'workflow_dispatch' && inputs.target || (github.ref_name == 'main' && 'production' || 'dev') }}`, `PROJECT_ID: ${{ env.TARGET == 'production' && vars.FIREBASE_PROJECT_ID_PROD || vars.FIREBASE_PROJECT_ID_DEV }}`, and the same for `BLAZE_ENABLED_*` and `secrets.FIREBASE_SERVICE_ACCOUNT_*`. A job-level `env` cannot read another `env` key, so compute `TARGET` in a first step to `$GITHUB_ENV`, or repeat the expression. Write the owner step O5 with those names in the PR body.
- [ ] **Step 5: `dependabot.yml`.** Add an npm entry for `directories: [/packages/domain, /firebase/functions, /firebase/rules-test]` with the groups and the two `ignore` rules from booking's file at `$SRC` (TypeScript `>=6.1`, `@types/node` majors), with their comments. Keep the root `/` npm entry separate: the API has its own TypeScript/`@types/node` line. If the owner prefers one entry, add `/` to `directories`.
- [ ] **Step 6:** `actionlint` if installed (`brew install actionlint` is outside the sandbox; skip and say so otherwise). Commit `ci: domain, Functions and rules jobs, Firebase deploy with the Blaze switch [#299]`.

### Task A5: Local emulator scripts in booking-be

**Files:** `scripts/backend-local.sh`, `scripts/spots-local.sh`, `scripts/awards-local.sh`, `scripts/verifications-local.sh` (new; content from booking's `scripts/` at `$SRC`).

- [ ] **Step 1:** Copy the four scripts. In each:
  - `FB="$ROOT/firebase"`, `FN="$FB/functions"`, `DOMAIN="$ROOT/packages/domain"`
  - remove `source "$ROOT/scripts/env.sh"` and `export HOME=…`. The caller's environment is used: the booking wrappers set the JDK, CA and `HOME`, and a plain shell uses the system's. Check that `java` is on `PATH` (the Firestore emulator needs JDK 21+) and exit with a hint otherwise, like the Node 24 check.
  - project id: `$FIREBASE_PROJECT`, else `project_info.project_id` of `$APP_DIR/android/app/google-services.json` (`APP_DIR` default `$ROOT/../booking/app_flutter`), else `demo-nag`
  - usage text: data in `firebase/.emulator-data`; seed accounts in `firebase/functions/seed/README.md`; the app commands stay ("from booking app_flutter/: flutter run --dart-define=USE_EMULATORS=true …")
- [ ] **Step 2:** `bash -n` on each, then `scripts/backend-local.sh --help`, `scripts/spots-local.sh --help`, `scripts/awards-local.sh --help`. Starting the emulators needs ports and Java outside the sandbox; say whether it was tried.
- [ ] **Step 3: Commit** `build(firebase): local emulator and CLI scripts [#299]`.

### Task A6: booking-be docs

**Files:** `AGENTS.md`, `README.md`, `firebase/functions/seed/README.md` (if Task A2 did not already fix it).

- [ ] **Step 1: `AGENTS.md`.**
  - "What this is": the repo holds three parts. (1) The Fastify API at the root. (2) `firebase/`: Cloud Functions (thin adapters, region `asia-southeast1`), Firestore/Storage rules, indexes, `rules-test`, seed and tools CLI. (3) `packages/domain`: the business rules shared by both (pure TypeScript, no Firebase or Node imports, enforced by its lint and `test/purity.test.ts`). Imported, never copied. Say that it came from the app repo on the merge date, history included (#299), as for the API (2026-10-23).
  - Replace the `domain.lock`/`sync-domain.sh` bullet with "API and Functions use the domain in this repo; `src/domain/index.ts` is the only API file that imports it, the Functions use the `@photobooking/domain` alias".
  - Skills line: drop `domain-sync`.
  - Commands: add blocks for `packages/domain`, `firebase/functions` (unit, `test:integration` outside the sandbox, `build`, the tools scripts), `firebase/rules-test` (`npm test`, `deploy:rules:*`/`deploy:storage:*` with the Blaze check), and the four `scripts/*-local.sh`. Remove both `sync-domain.sh` lines.
  - "CI and branches": the three new jobs and `firebase-deploy.yml`, moving the Blaze-switch paragraph from booking's `AGENTS.md`: deploy to `dev` on `develop`, `production` on `main`; `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT`, `BLAZE_ENABLED`; "Do not add a deploy, service or spec step that needs Blaze without putting it behind this switch". Docs stay in the app repo (D2): cite `docs/FIREBASE-SETUP.md` there.
  - Seed accounts note: `firebase/functions/seed/README.md` (test values only).
  - Unit workflow (D5): issues live in thanhngochoang/booking; a unit that changes the backend has a branch of the same name here, and its PR body says `thanhngochoang/booking#<issue>`; it merges before the app PR, which bumps `backend.lock`.
- [ ] **Step 2: `README.md`:** same changes in short form.
- [ ] **Step 3: Commit** `docs: Firebase backend and shared domain in this repository [#299]`.

### Task A7: Verify, PR, merge with a merge commit

- [ ] **Step 1:** Rerun Task A2 step 5 and Task A3 step 7 on the final branch. `git status` is clean.
- [ ] **Step 2:** Push and open the PR into `develop`: title `chore(firebase): move the Firebase backend and packages/domain here [#299]`. Body:
  - first line: `Part 1 of 2 of thanhngochoang/booking#299. Merge with "Create a merge commit": the subtree history is lost by squash or rebase.`
  - what moved, from which booking commit (`$SRC`)
  - D7 error mapping (table from P2)
  - what was not run locally (rules emulator, Functions integration, Docker if absent)
  - the owner steps that follow (O3–O6, O7)
- [ ] **Step 3:** Wait for CI (the new `firestore-rules` job and `firebase-deploy`'s tests run only on push after merge; the PR runs `ci.yml`). After the merge, the push to `develop` runs `firebase-deploy`. Its deploy jobs must end with the "FIREBASE_PROJECT_ID is not set" warning. If they deploy, environments exist already: stop and tell the owner.
- [ ] **Step 4:** After the merge, record booking-be's `develop` SHA (it contains the merge commit). Part B pins it.

---

## Part B · booking PR

Work on the claimed `plan/299-<slug>` branch in booking (worktree in the scratchpad, toolchain symlinked).

### Task B1: Remove the backend from booking

**Files:** delete `app_flutter/firebase/`, `packages/` (only `packages/domain` is tracked). Modify `.gitignore`.

- [ ] **Step 1: Freeze check.**

  ```bash
  git fetch origin
  git diff --stat "$SRC" origin/develop -- app_flutter/firebase packages   # must print nothing
  ```

  If it prints anything, a change landed after the split: stop. The fix is a follow-up PR in booking-be that applies the same diff (`git diff "$SRC" origin/develop -- app_flutter/firebase | git -C booking-be apply --directory=… -p3`), which must merge before this task continues.
- [ ] **Step 2:** `git rm -r -q app_flutter/firebase packages`.
- [ ] **Step 3: `.gitignore`.** Remove `packages/*`, `!packages/domain`, `!packages/domain/**`. Add:

  ```
  # booking-be files the app tests read, at the commit in backend.lock (scripts/sync-backend.sh)
  /.backend/
  ```

- [ ] **Step 4:** Untracked leftovers stay on disk: `app_flutter/firebase/functions/node_modules`, `.emulator-data` and `.firebase.lan.json`. Do not delete them. The PR body tells the owner they can be removed, and that the saved emulator data moves with `mv app_flutter/firebase/.emulator-data ../booking-be/firebase/`.
- [ ] **Step 5: Commit** `chore(backend): remove the Firebase backend and packages/domain, now in booking-be [#299]`. Do this together with Task B2 if CI on the intermediate commit matters; it does not, the PR is squashed.

### Task B2: `backend.lock`, `sync-backend.sh`, the snapshot guard

**Files:** create `backend.lock`, `scripts/sync-backend.sh`, `app_flutter/test/support/backend_snapshot.dart`.

- [ ] **Step 1: `backend.lock`** (the format of booking-be's former `domain.lock`):

  ```
  # booking-be (Firebase backend, packages/domain, API) at the commit the app is tested against.
  # scripts/sync-backend.sh checks the files the app tests read out into .backend/ (gitignored);
  # CI runs the same script. A unit that changes the backend bumps this in its app PR:
  #   scripts/sync-backend.sh --update      (pins the current tip of `branch`)
  repo=https://github.com/thanhngochoang/booking-be.git
  branch=develop
  ref=<booking-be develop SHA from Task A7 step 4>
  ```

- [ ] **Step 2: `scripts/sync-backend.sh`.** Model it on booking-be's `sync-domain.sh` at its last commit (`git -C ../booking-be show <A1 base>:scripts/sync-domain.sh`): `--update`, a `.backend-ref` marker that turns a second run into a no-op, `mktemp` + `trap`. Differences:
  - source: `${BACKEND_REPO:-$repo}`. CI passes the SSH URL, the offline/sandbox form is `BACKEND_REPO=$PWD/../booking-be`.
  - non-cone sparse checkout of exactly the paths the tests read (one list, in the script):

    ```bash
    PATHS=(
      firebase/firebase.json
      firebase/firestore.rules
      firebase/storage.rules
      firebase/functions/src/config.ts
      firebase/functions/seed/fixtures.ts
      packages/domain/src/vn_banks.ts
      packages/domain/src/recruit_areas.ts
      packages/domain/test/fixtures/booking_policy.json
      packages/domain/test/fixtures/payout_account.json
    )
    git -C "$tmp" sparse-checkout set --no-cone "${PATHS[@]}"
    ```

  - destination `$ROOT/.backend` (replaced as a whole), marker `.backend/.backend-ref`
  - check after checkout that every path in `PATHS` exists. A rename in booking-be must fail here with the path, not later in a Dart test.

  Run it: `BACKEND_REPO=$PWD/../booking-be scripts/sync-backend.sh`, then again (prints "already at"). Then `--update` against the local clone and `git diff backend.lock`: the same ref, or the newer tip if booking-be moved.
- [ ] **Step 3: `test/support/backend_snapshot.dart`:**

  ```dart
  import 'dart:io';

  import 'package:flutter_test/flutter_test.dart';

  /// Fails (never skips) when `../.backend` is missing or not at the commit pinned
  /// in `../backend.lock`. The paths are literal on purpose: tool/affected_test.dart
  /// selects every test that imports this file when backend.lock or the sync script
  /// changes (docs/testing/affected-tests.md).
  void requireBackendSnapshot() {
    final lock = File('../backend.lock').readAsStringSync();
    final script = File('../scripts/sync-backend.sh');
    final marker = File('../.backend/.backend-ref');
    final ref = RegExp(r'^ref=(\S+)', multiLine: true).firstMatch(lock)?.group(1);
    final have = marker.existsSync() ? marker.readAsStringSync().trim() : null;
    if (ref == null || have != ref) {
      fail('booking-be snapshot ${have == null ? 'missing' : 'at $have'}, backend.lock wants $ref: '
          'run ${script.path} from the repo root '
          '(offline: BACKEND_REPO=\$PWD/../booking-be scripts/sync-backend.sh)');
    }
  }
  ```

- [ ] **Step 4: Commit** `build(test): backend.lock and sync-backend.sh for the booking-be files the tests read [#299]`.

### Task B3: Repoint the tests

**Files:** `test/data/backend/backend_config_test.dart`, `test/data/media/storage_rules_limits_sync_test.dart`, `test/data/skills/rules_catalogue_sync_test.dart`, `test/data/booking/booking_rules_test.dart`, `test/data/earnings/payout_account_rules_test.dart`, `test/data/earnings/vn_banks_sync_test.dart`, `test/data/recruit/area_sync_test.dart`.

- [ ] **Step 1: Paths.** In each file add `setUpAll(requireBackendSnapshot);` at the top of `main`, import `'../../support/backend_snapshot.dart'` (relative, as the other `test/support` imports are), and change the literal:

  | test | before | after |
  |--|--|--|
  | `backend_config_test.dart` | `firebase/firebase.json`, `firebase/functions/src/config.ts` | `../.backend/firebase/firebase.json`, `../.backend/firebase/functions/src/config.ts` |
  | `storage_rules_limits_sync_test.dart` | `firebase/storage.rules` | `../.backend/firebase/storage.rules` |
  | `rules_catalogue_sync_test.dart` | `firebase/firestore.rules` | `../.backend/firebase/firestore.rules` |
  | `booking_rules_test.dart` | `../packages/domain/test/fixtures/booking_policy.json` | `../.backend/packages/domain/test/fixtures/booking_policy.json` |
  | `payout_account_rules_test.dart` | `../packages/domain/test/fixtures/payout_account.json` | `../.backend/packages/domain/test/fixtures/payout_account.json` |
  | `vn_banks_sync_test.dart` | `../packages/domain/src/vn_banks.ts` | `../.backend/packages/domain/src/vn_banks.ts` |
  | `area_sync_test.dart` | `../packages/domain/src/recruit_areas.ts` | `../.backend/packages/domain/src/recruit_areas.ts` |

  Update test names and reasons that mention the old paths (e.g. "ports match booking-be firebase/firebase.json").
- [ ] **Step 2: Prove the guard.** With `.backend/` removed (`mv .backend "$TMPDIR/backend.off"`), `flutter test test/data/backend/backend_config_test.dart` fails with the hint. Put it back and the test passes. Change one character of `ref=` locally and the guard fails with "at <sha>, backend.lock wants …"; revert.
- [ ] **Step 3: P6, the names in the seed.** Add a second test to `area_sync_test.dart`: the `areas: [` block of `SEED_INSTANT_CONFIG` in `../.backend/firebase/functions/seed/fixtures.ts` has the names and centres of `builtInAreas`, in order. Use the same regex the removed TypeScript test used, in reverse: parse the TS objects (`name: '…', lat: …, lng: …`) and compare with `builtInAreas` `(name, lat, lng)`. Also extend the first test to compare the centres of `RECRUIT_AREAS` with `builtInAreas`, not only the ids. Run it; if the seed's field order differs, adjust the regex and say so.
- [ ] **Step 4:** `flutter test` on the 7 files. All pass.
- [ ] **Step 5: Commit** `test(data): read backend files from the booking-be snapshot [#299]`.

### Task B4: Affected-test tool

**Files:** `app_flutter/tool/affected_test.dart`, `app_flutter/test/tool/affected/analysis_test.dart`, `docs/testing/affected-tests.md`.

- [ ] **Step 1: Test first.** In `analysis_test.dart` add a case in the style of the existing disk-read cases. A support file `test/support/snap.dart` contains `File('../backend.lock')`, a test imports it, the changed files are `['backend.lock']`, and the result is `Scope.affected` with that test selected through the support file. A second case does the same with `File('../scripts/sync-backend.sh')` and the changed file `scripts/sync-backend.sh`. Run the tests. They probably already pass with today's rules, because reads in a support file seed the reverse graph. Keep them as the regression tests for this unit.
- [ ] **Step 2: Rules.** Remove `'firebase/**'` from `passiveFiles` in `tool/affected_test.dart`; `app_flutter/firebase/` no longer exists. No new rule is needed: the guard's literal reads of `../backend.lock` and `../scripts/sync-backend.sh` select the 8 tests. Write that as a comment above `passiveFiles`.
- [ ] **Step 3: Docs.** `docs/testing/affected-tests.md`: in item 3 replace `../packages/domain/test/fixtures/…` with `../.backend/…`. In the table drop `firebase/**` from the first row and `packages/domain` from the second, and add a row: "`backend.lock`, `scripts/sync-backend.sh` → the tests that import `test/support/backend_snapshot.dart` (they read booking-be files from `.backend/`)".
- [ ] **Step 4:** `dart run tool/affected_test.dart origin/develop --list` on the branch: the 8 tests (and the affected-tool tests) are listed. `flutter test test/tool/affected`.
- [ ] **Step 5: Commit** `test(tool): affected tests follow backend.lock [#299]`.

### Task B5: CI, Dependabot, CodeQL in booking

**Files:** `.github/workflows/flutter.yml`, delete `.github/workflows/firebase-deploy.yml`, `.github/dependabot.yml`, `.github/workflows/codeql.yml`.

- [ ] **Step 1: O2.** Ask the owner to create the deploy key and both `BOOKING_BE_DEPLOY_KEY` secrets (Actions and Dependabot). Continue with the file edits meanwhile; the PR's CI needs the secret.
- [ ] **Step 2: `flutter.yml`.**
  - `pull_request.paths`: remove `'packages/**'`, add `'backend.lock'`, `'scripts/sync-backend.sh'`. Update the comment: tests read the main spec and the booking-be snapshot.
  - delete the jobs `firestore-rules` (3), `domain` (5) and `functions` (6), and renumber the section comments
  - in `test`, after `flutter pub get`:

    ```yaml
          - name: booking-be files the tests read (backend.lock)
            if: steps.detect.outputs.scope != 'NONE'
            working-directory: .
            env:
              DEPLOY_KEY: ${{ secrets.BOOKING_BE_DEPLOY_KEY }}
            run: |
              key="$RUNNER_TEMP/booking-be-key"
              install -m 600 /dev/null "$key" && printf '%s\n' "$DEPLOY_KEY" > "$key"
              GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
                BACKEND_REPO=git@github.com:thanhngochoang/booking-be.git scripts/sync-backend.sh
    ```

  - `analyze` does not need the snapshot (no test runs there)
- [ ] **Step 3:** `git rm .github/workflows/firebase-deploy.yml`.
- [ ] **Step 4: `dependabot.yml`.** Remove the npm entry and its two `ignore` rules (they now live in booking-be, Task A4 step 5). Rewrite the header: "The npm packages (domain, Functions, rules-test) moved to booking-be (#299); its own dependabot.yml updates them".
- [ ] **Step 5: `codeql.yml`.** Remove `javascript-typescript` from the matrix (P5). Header: "CodeQL for the Python scripts. The TypeScript (domain, Cloud Functions) moved to booking-be (#299)".
- [ ] **Step 6: Commit** `ci: Firebase jobs and deploy move to booking-be; tests sync backend.lock [#299]`.

### Task B6: Local scripts and VS Code

**Files:** `scripts/bin/_booking-be.sh` (new), `scripts/backend-local.sh`, `scripts/spots-local.sh`, `scripts/awards-local.sh`, `scripts/verifications-local.sh`, `scripts/adb-reverse.sh`, `.vscode/launch.json`, `.vscode/tasks.json`.

- [ ] **Step 1: `scripts/bin/_booking-be.sh`** (sourced, like `_jvm-env.sh`): sets `ROOT`, `BE="${BOOKING_BE_DIR:-$ROOT/../booking-be}"` (absolute via `cd … && pwd` when it exists). If `$BE/firebase/firebase.json` is missing, it exits 1 with `booking-be checkout not found at $BE: git clone https://github.com/thanhngochoang/booking-be.git "$BE" (or set BOOKING_BE_DIR)`. It sources `scripts/env.sh` with `set +eu` (as `backend-local.sh` does today), exports `HOME="$ROOT/.home"` and `APP_DIR="$ROOT/app_flutter"`, and warns (does not fail) when `git -C "$BE" merge-base --is-ancestor <ref of backend.lock> HEAD` is false: "booking-be at <HEAD> does not contain backend.lock's <ref>; the emulators may run an older backend than the app expects".
- [ ] **Step 2: Wrappers.** Each of the four scripts becomes: a comment saying the real script is booking-be's `scripts/<same name>`, `source "$(dirname "$0")/bin/_booking-be.sh"`, `exec "$BE/scripts/<same name>" "$@"`. `--help` is passed through.
- [ ] **Step 3:** `scripts/adb-reverse.sh` comment: ports of booking-be's `firebase/firebase.json`. `.vscode/launch.json` and `tasks.json`: the comments that say "chạy ../scripts/backend-local.sh trước" now say it starts the emulators of the booking-be checkout (`BOOKING_BE_DIR`, default `../booking-be`). Configurations, `toolArgs` and tasks are unchanged.
- [ ] **Step 4:** `bash -n` on all five. `scripts/backend-local.sh --help` with booking-be present prints booking-be's usage. With `BOOKING_BE_DIR=/nonexistent` it prints the clone hint and exits 1.
- [ ] **Step 5: Commit** `build(scripts): local backend scripts run the booking-be checkout [#299]`.

### Task B7: Two-repo tooling (D5)

**Files:** `.agents/skills/run-next-plan/scripts/land.py`, `.agents/skills/run-next-plan/SKILL.md`.

- [ ] **Step 1: `land.py --repo`.** `land.py <issue> --pr <n> --repo thanhngochoang/booking-be` runs these gates against that repo and its `develop`: title, up to date, CI, mergeable. Then it squash-merges and deletes the branch. It does **not** set the project item Done or close the issue (the app PR does). The overlap gate (3) for `--repo booking-be` compares the files of this branch with booking-be's `plan/*` branches whose issue is In Progress/In Review in Project 4 (issue number from the branch name). Keep the `SHARED_OK` list per repo (booking-be: none yet).
- [ ] **Step 2: Cross-repo gate.** Without `--repo` (an app PR), add a gate before merging: if booking-be has an **open** PR whose head is `plan/<issue>-*`, exit with a new code (7, "the booking-be PR of this unit is not merged yet") and its URL. Document exit 7 in the docstring and in SKILL.md's gate list.
- [ ] **Step 3: SKILL.md.**
  - the end-of-unit verification commands for domain/Functions run in the booking-be checkout (`(cd ../booking-be/packages/domain && npm test)`, `(cd ../booking-be/firebase/functions && npm test)`)
  - the Firebase skills table rows say the code is in booking-be `firebase/…` and the skills are still read from this repo's `.agents/skills/`
  - a "Units that change the backend" section: same branch name in booking-be, booking-be PR first (body `thanhngochoang/booking#<issue>`), `land.py --repo thanhngochoang/booking-be`, then `scripts/sync-backend.sh --update` in the app PR, then land the app PR
- [ ] **Step 4: Check.** `python3 -m py_compile` on both scripts. `land.py --help`. `land.py 299 --pr <booking PR> --dry-run` once the PR exists (Task B9). It must stop at gate 7 while the booking-be PR is open, if A has not merged yet. Say what was run.
- [ ] **Step 5: Commit** `chore(skills): run-next-plan lands booking-be PRs and checks them before the app PR [#299]`.

### Task B8: booking docs

**Files:** `AGENTS.md`, `docs/FIREBASE-SETUP.md`, `docs/SETUP.md`, `app_flutter/README.md`, `services/README.md`, `docs/superpowers/plans/RUN-ORDER.md`, comments in `app_flutter/lib/**` and `app_flutter/test/**`.

- [ ] **Step 1: `AGENTS.md`.**
  - "Server code": Cloud Functions, rules, indexes, seed and `packages/domain` live in booking-be (`firebase/`, `packages/domain/`); this repo keeps the Dart adapters, `firebase_options.dart` and the contract snapshot. Drop "#299 moves … until it lands".
  - "Self-hosted backend": booking-be holds the API **and** the Firebase backend. The app tests read the files in `backend.lock` through `scripts/sync-backend.sh` (once per clone and after every bump; offline `BACKEND_REPO=$PWD/../booking-be`). A unit that changes the backend lands its booking-be PR first and bumps `backend.lock` in its app PR.
  - "Parallel work": one line on D5 (same branch name in booking-be, booking-be PR first, `land.py --repo`).
  - Commands: remove the `packages/domain` and `firebase/functions` lines. Add `../scripts/sync-backend.sh` before `flutter test`. Note that `../scripts/backend-local.sh` runs the booking-be checkout. Replace the Firebase rules/CI paragraph with two sentences: rules, deploy and the Blaze switch are in booking-be (its `AGENTS.md`, `firebase-deploy.yml`); setup steps stay in `docs/FIREBASE-SETUP.md`. Keep "Do not add a deploy, service or spec step that needs Blaze without putting it behind this switch".
- [ ] **Step 2: `docs/FIREBASE-SETUP.md`** (stays here, D2): every `app_flutter/firebase/…` → booking-be `firebase/…`; `cd app_flutter/firebase/rules-test` → `cd ../booking-be/firebase/rules-test` (from the booking root). Sections 10 and 11: the workflow and environments are in booking-be, with the trigger table updated (branches `develop`/`main`, paths `firebase/**`, `packages/domain/**`). Add the deploy key (O2) to section 10.
- [ ] **Step 3:** `docs/SETUP.md` (backend local needs the booking-be clone; one line with the clone command), `app_flutter/README.md` (lines 46, 56–65, 93–94: commands move to booking-be, the wrapper stays), `services/README.md` (booking-be now also holds the Firebase backend, since #299), `RUN-ORDER.md` standing rules (rules tests live in booking-be; each machine runs `../scripts/backend-local.sh`, which needs the booking-be clone).
- [ ] **Step 4: Comments.** `git grep -nE 'packages/domain|firebase/(functions|firestore|storage)' -- app_flutter/lib app_flutter/test`: prefix the path with "booking-be " in comments. Do not touch code. Specs, ledgers and executed plans keep their old paths (they are history).
- [ ] **Step 5:** `git grep -nE 'app_flutter/firebase|\.\./packages/domain' -- ':!docs/superpowers/plans/**' ':!docs/superpowers/specs/**' ':!docs/superpowers/handover/**' ':!graphify-out/**'` prints nothing, apart from deliberate history sentences.
- [ ] **Step 6:** `graphify update .` if graphify is installed. Commit `docs: the Firebase backend lives in booking-be [#299]`.

### Task B9: Verify, PR, land

- [ ] **Step 1:** From `app_flutter/` (env and PATH as in AGENTS.md): `../scripts/sync-backend.sh` (or the `BACKEND_REPO` form), `flutter analyze`, `flutter test`. Compare the count with #320's 5861 passed / 42 skipped: the same, plus the new tests of B3/B4.
- [ ] **Step 2:** Push. Open the PR into `develop`: title `chore(backend): move the Firebase backend to booking-be [#299]`. Body:
  - "Part 2 of 2; part 1: <booking-be PR URL> (merged, `backend.lock` = its develop commit)"
  - what was removed, the freeze check output
  - D6 snapshot and the guard
  - CI changes and the deploy-key secret
  - O3 (required checks) **before merge**, then O5/O6
  - leftovers on disk (Task B1 step 4)
- [ ] **Step 3:** Ask the owner for O3. CI must be green (`analyze`, the shards with the sync step, `report`).
- [ ] **Step 4:** Land with `land.py 299 --pr <n>`, now with the cross-repo gate. Then move the issue to Done (land.py does it).

---

## Part C · After both PRs

### Task C1: Switch deploys, clean up

- [ ] **Step 1:** Ask the owner for O5 and O6. Check the `firebase-deploy` run in booking-be: `deploy` deployed rules + indexes; `deploy-functions` printed the Blaze warning. Note the run URL on the issue.
- [ ] **Step 2:** `gh pr list --repo thanhngochoang/booking --state open --author app/dependabot`. Close any npm PR on the removed directories with a comment that booking-be's Dependabot reopens it there. There should be none: #320 closed them.
- [ ] **Step 3:** Outside both repos: the workspace `CLAUDE.md` one folder above (`Booking-app/CLAUDE.md`) describes the planned move and `domain.lock`. Tell the user what to change ("How the two repos connect": domain and Firebase backend in booking-be, `backend.lock` in booking; drop "Planned move (#299)"). It is not in git, so edit it only if the user says so.
- [ ] **Step 4:** Ask the owner about O7 and O8. Close the handoff logs in both repos.
