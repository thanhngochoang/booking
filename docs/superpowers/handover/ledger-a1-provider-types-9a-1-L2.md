# Handover ledger — 9a/1-L2 (A1 provider types: domain, Functions, rules, Postgres, data, core widgets)

Unit: `9a/1-L2` (plan `docs/superpowers/plans/2026-10-05-a1-provider-types.md`, Tasks 1–5). Branch `plan/9a-1-L2-provider-types-core` from `d6c034b`. Opens gate **GA1** for unit 9a lane 1 (Tasks 6–7) and for plan B1 (row 9c).

## What landed

| Task | Commit | Summary |
|---|---|---|
| 1 | 0271879 | `packages/domain`: `ProviderType`, `providerTypeOf`, `chosenTypeOf`, ports, memory store, `setProviderType`, `validateStudioAddress`, `setStudioAddress` |
| 2 | c1e78de | Functions callables `setProviderType`, `setStudioAddress` (`FirestoreProviderStore`, `liveProviderDeps` with the no-op `recomputeArtistTier` hook for B1); rules: server-only provider fields, studio finish gate; indexes `bookings (photographerId,status)`, `payments (payeeId,escrowStatus)`; seed studio CUC (+ private address) and artist DUNG |
| 3 | 1d61816 | `services/api`: migration `1791158400001_provider_type.sql` (columns + `studio_addresses`), Kysely types, Firestore import (export/map/load) |
| 4 | aa50901 | App data: `ProviderType`/`ProviderChoice`, `PhotographerSummary.providerType/approvedAwardCount/studioDistrict`, `ProviderRepository` (+ fake, callable adapter, providers) |
| 5 | eb9fcf9 | Gold tokens (light/dark), `ProviderMark`, `ProviderTag`, `ProviderName`, `providerMarkOf`, `VerifiedName` deprecated wrapper, `PhotographerCard` marks/tags/semantics, arb keys, gallery tile |
| final fixes | 76dfafd, a633b0a, 8bf8f3a | open-work check always on; `partially_refunded` counts as held; real integration tests; rules refuse `onboardingComplete` true→false; unverified studio announced as Studio; tag tokens + briefcase icon; callable timeout 15 s; `studio_addresses` updated_at trigger; data-model docs |

## Rulings

- Task 5 adds the arb keys its widgets need (`providerArtist`, `providerStudio`, `providerArtistMark`, `providerStudioMark`, `providerArtistAwards`, `providerStudioDistrict`, plus `providerAwardsCount` for the card's screen-reader header); lane-1 Task 7 reuses them.
- The unit ran before row 8e is done: its files share nothing with the 8e/7-L1 claim.
- An onboarded individual who switches to studio keeps `onboardingComplete: true` without an address (rules gate only false→true): **lane-1 Task 7 must open the studio address form right after a successful switch to studio.**
- Postgres DB tests (Testcontainers) and the Functions/rules emulator tests were not run in the sandbox; CI (`api.yml`, `flutter.yml`/`firebase-deploy.yml`) runs them.
- **Departs from plan Decision 2** (plan text updated): the open-work check runs on every switch, setup included, and rules refuse `onboardingComplete` true→false — the flag is client-writable, so skipping the check during setup was a bypass.
- Held money = `escrowStatus` `held | partially_refunded | disputed`.
- The ~42 skipped Flutter tests pre-exist (golden/selfhosted tags).

## Deferred (minor)

- No test that an artist is `not_eligible` for `setStudioAddress`; recompute-not-called covered only for some paths; small test tidy-ups (import order, combined assertions).
- `recomputeArtistTier` throwing after commit surfaces an error although the type changed — **plan B1 should make its hook idempotent and log, not throw.**
- Private `studioAddress` doc also stores a GeoPoint `point` (matches `point?` in the data model).
- Non-`FirebaseFunctionsException` (network) errors escape `CallableProviderRepository` unwrapped — **lane-1 Task 7 must show a generic error for them.**
- Artist mark uses a Material check icon while the seal strokes its own check (slight weight difference).
- Seed artist DUNG has no `approvedAwardCount` (plan B1 seeds awards).
- Integration test "an accepted booking makes the switch not_eligible" asserts `providerType` undefined for AN; if the seed ever sets it, loosen to `individual`.

## Cross-lane requests (lane 1, Tasks 6–7)

- Features still call the deprecated `VerifiedName` (`home_screen.dart`, `profile_header.dart`, `photo_detail_screen.dart`); Task 6 migrates them to `ProviderName`.
- Task 7: after switching to studio, open the studio address form; handle network errors from `ProviderRepository` as a generic failure.
