# Handover ledger — plan S19 saved and following: S19.01, S19.02, S19.03 (issue #143)

Plan: `docs/superpowers/plans/2026-10-07-s19-saved-following.md`, Tasks 1–7. Branch `feat/s19-saved-and-following`. Commits:
- `38d6e9b` feat(functions): server follower count, saved-photographer marker, list rules and indexes [#143] (Task 2)
- `0d071df` feat(data): saved and follow lists with cursors and counts [#143] (Task 3)
- `3331eb8` feat(saved): S19.01 saved posts and photographers, save button on S03.01 [#143] (Task 4)
- `d8c22ec` feat(saved): S19.02 following with undo, S19.03 followers [#143] (Task 5)
- `46b429d` feat(profile): S09.01 follow and saved counts, followed authors first in the feed [#143] (Task 6)
- Task 7 documentation and ledger commit.

---

## Built
- **Domain & Cloud Functions (Task 2)**:
  - `packages/domain/src/counters.ts`: pure counter recount helper `computeCounterPatch` with event-time comparison (`counterPatch`) guarding against out-of-order writes.
  - `app_flutter/firebase/functions/src/triggers/follow_write.ts`: `onFollowWrite` Cloud Function trigger recounting `follows where photographerId == uid` using Firestore `count()` aggregation.
  - `app_flutter/firebase/firestore.rules`: added `'followerCount'`, `'followerCountAt'` to protected server fields list; updated `match /follows/{docId}` list rule to allow owner or photographer read; added `match /savedPhotographers/{docId}` collection rules.
  - `app_flutter/firebase/firestore.indexes.json`: added composite indexes for `saves`, `follows` (by `userId` and `photographerId`), and `savedPhotographers`.
- **Data & Repositories (Task 3)**:
  - `SavedFollowRepository` interface + `FirestoreSavedFollowRepository` & `FakeSavedFollowRepository`.
  - Paging cursors `{createdAtMicros}_{docId}`, look-ahead logic up to 3 pages for dropped targets.
  - Social count aggregations for `savedPosts`, `savedPhotographers`, and `following`.
- **Features S19.01, S19.02, S19.03 (Tasks 4–5)**:
  - `features/saved/saved_screen.dart` (`/me/saved`): Segmented tabs for posts and photographers, grid of saved posts, list of `PhotographerCard`s with bookmark button and undo snackbar.
  - `features/saved/following_screen.dart` (`/me/following`): list of followed photographers with inline toggle and undo snackbar.
  - `features/saved/followers_screen.dart` (`/me/followers`): private list of followers with date since, restricted to photographer roles.
  - S03.01 bookmark button on photographer profile app bar.
- **Profile & Recommendation Wiring (Task 6)**:
  - `settings_links.dart`: set `savedListsReadyProvider` to `true`.
  - `profile_tab.dart`: wired counts row to `socialCountsProvider` and `myFollowerCountProvider`, navigating to `/me/following`, `/me/saved`, and `/me/followers`.
  - `LocalRecommender`: feed boost ranking posts of followed photographers from the last 7 days first, with reason code `ReasonCode.following` ("Bạn đang theo dõi").

---

## Decisions of the Plan
1. **Bookmark location**: On S03.01 app bar for visitors, and on each card in S19.01 photographers tab.
2. **Follower count**: Recount via Cloud Function `count()` aggregation, writing `photographers/{pid}.followerCount` and `followerCountAt`.
3. **Paging order**: `createdAt desc`, document id desc. Look-ahead up to 3 extra pages when items are deleted or unpublished.
4. **Unfollow / Unsave with undo**: Instant inline state change with SnackBar action to undo.
5. **Private follower list**: Only accessible to the photographer on `/me/followers`; other roles redirect to `/profile`.

---

## Rulings & Coordination
1. **Coordination on #132**: This plan created and owns `packages/domain/src/counters.ts` with `computeCounterPatch` and pure timestamp comparison. #132 will reuse this module for `likeCount` and `saveCount`.
2. **Coordination on #148**: Flipped `savedListsReadyProvider` to `true` and wired the `_CountsRow` counters directly to `socialCountsProvider` and `myFollowerCountProvider`.
3. **Coordination on #144 (Hidden users)**: When #144 lands, `FollowingController`, `FollowersController`, and `SavedPostsController` / `SavedPhotographersController` can filter out IDs present in `hiddenUsersProvider`. Marked as pending #144.
4. **Lint and Test rule**: No `CircularProgressIndicator` permitted in `lib/` (verified by `source_rules_test.dart`); all loading indicators use `DotRingLoader(size: LoaderSize.inline)`.

---

## Integration Tests & Firestore Rules Not Run Locally
Per user instruction and standing rules:
- `test/triggers/follow_write.test.ts` (Firebase functions emulator suite) was written, not run locally; CI runs emulator tests.
- `app_flutter/firebase/rules_test/` suites were not run locally against the emulator.
All unit tests in `packages/domain` (`npm test`), functions build (`npm run build`), and Flutter unit/widget tests in `test/features/saved/`, `test/data/content/`, `test/features/profile/`, `test/features/home/` ran cleanly and passed.

---

## Deploy Order
1. Deploy Firestore indexes (`firestore.indexes.json`) and security rules (`firestore.rules`).
2. Deploy Cloud Functions (`onFollowWrite`).
3. (Optional) Run one-time recount script/function if existing follow documents need backfilling.
4. Release Flutter app with S19 routes and enabled `savedListsReadyProvider`.
