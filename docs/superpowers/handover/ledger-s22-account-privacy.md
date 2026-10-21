# Handover ledger — S22 Account Deletion & Privacy (issue #205)

Plan: `docs/superpowers/plans/2026-10-07-s22-payments-account.md`, Tasks 1–5. Branch `plan/205-s22-xoa-tai-khoan-quyen-rieng-tu`. Target merge: `develop`.

## Built per Task

### Task 1: Mock check, screen specs, and S22 code table
- Added `ScreenCodes`: `deleteAccount = 'S22.02'`, `privacy = 'S22.03'`, `restoreAccount = 'S22.05'`.
- Verified mock parity for `#S22.02`, `#S22.02-confirm`, `#S22.03`, `#S22.05`, and `#S09.02`.

### Task 2: Domain + Functions
- **Domain (`packages/domain`)**:
  - `account_deletion.ts`: `AccountDeletionStatus`, `AccountStatus`, `ACCOUNT_RESTORE_DAYS = 30`, `ACCOUNT_DATA_MAP`, `BLOCKER_KINDS`, `accountDeletionBlockers`, `tombstoneOf`, `DeletionDeps`, `PurgeDeps`.
  - `data_export.ts`: `EXPORT_LIMITS`, `buildExportDocument`, `exportUsableUntil`, `exportCooldownUntil`, `ExportDeps`.
  - Exported in `packages/domain/src/index.ts`.
  - Unit tests: `account_deletion.test.ts`, `data_export.test.ts` passing.
- **Functions (`app_flutter/firebase/functions`)**:
  - `src/account_deletion_firestore.ts`: `requestAccountDeletion`, `restoreAccount`, `requestDataExport`, `startDueAccountPurges`, `runAccountPurge`.
  - `src/callables/account_callables.ts`: `requestAccountDeletion`, `restoreAccount`, `requestDataExport`, `getAccountDeletionBlockers`.
  - `src/triggers/account_deletion_updated.ts`: `onAccountDeletionUpdated` trigger running purge upon status moving to `purging`.
  - `src/clock/prune_data_exports.ts`: cleaning expired export files older than 7 days.
  - `src/clock/prune_notifications.ts`: added step running `startDueAccountPurges` and `pruneDataExports`.
  - Unit tests: `account_callables.test.ts`, `account_purge.test.ts`, `account_readers.test.ts`, `prune_data_exports.test.ts`, `start_account_purges.test.ts` passing.
- **Firestore & Storage Rules**:
  - `firestore.rules`: added `'hiddenFromDiscovery'` to `photographerClientFields()`, ensured bool type check, added `'deletionPending'` to untouched server fields, blocked client writes to `deleted`, `deletedAt`, `accountStatus`, `restoreUntil`, blocked client read/write to `account_deletions/{uid}`.
  - `storage.rules`: added `exports/{uid}/{exportId}` rule allowing owner read (until expiration) and no client writes.
  - Updated `rules.test.mjs` with rules tests.

### Task 3: App data — account repository and discovery fields
- `app_flutter/lib/data/account/`:
  - `account_repository.dart`: `AccountRepository`, `DeletionBlocker`, `BlockerKind`, `DataExport`, `AccountLock`, `AccountException`.
  - `firebase_account_repository.dart`: implementation calling callables and streams `users/{uid}`, `users/{uid}/private/dataExport`, `photographers/{uid}`.
  - `account_providers.dart`: Riverpod providers `accountRepositoryProvider`, `accountLockProvider`, `dataExportProvider`.
- `photographer_summary.dart` & `firestore_photographer_repository.dart`: added `hiddenFromDiscovery` and `deletionPending`.
- Unit tests: `test/data/account/account_repository_test.dart` passing.

### Task 4: App UI & Router
- `lib/core/theme/app_icons.dart`: added `privacy`, `download`, `restore`.
- `lib/l10n/app_vi.arb`: added all S22.02, S22.03, S22.05, and S09.02 strings. Generated with `flutter gen-l10n`.
- `services/recommender/api/openapi.yaml`: noted exclusion of hidden / deletionPending candidates.
- `lib/features/find/find_controller.dart`: `_visible` drops `hiddenFromDiscovery || deletionPending`.
- `lib/data/recommendation/local_recommender.dart`: candidate filtering in `recommendPhotographers` and `similar` drops `hiddenFromDiscovery || deletionPending`.
- `lib/app/router.dart`: added `/settings/privacy`, `/settings/delete-account`, `/account/restore`. Router redirect intercepts locked users (`accountLockProvider`) and forces `/account/restore`.
- `lib/features/account/`:
  - `delete_account_screen.dart` & `delete_account_controller.dart` (S22.02).
  - `privacy_screen.dart` & `privacy_controller.dart` (S22.03).
  - `restore_account_screen.dart` & `restore_account_controller.dart` (S22.05).
- `lib/features/settings/settings_screen.dart`: inserted section `settings-group-paymentsData` with "Quyền riêng tư & dữ liệu" (`settings-privacy`).
- Unit & widget tests:
  - `test/features/account/delete_account_screen_test.dart`
  - `test/features/account/privacy_screen_test.dart`
  - `test/features/account/restore_account_screen_test.dart`
  - `test/app/account_lock_redirect_test.dart`
  - `test/features/find/find_controller_test.dart`
  - `test/data/recommendation/local_recommender_test.dart`
  - `test/features/photographer_profile/photographer_profile_screen_test.dart`
  - `test/features/settings/settings_test.dart`

---

## Decisions & Rulings Taken

1. **30-Day Restore Window (Owner 2026-10-07; Decision 11):**
   - Deletion request immediately sets `accountStatus = 'deletion_pending'`, `restoreUntil = requestedAt + 30 days`, revokes refresh tokens via `revokeRefreshTokens`, and sets `photographers/{uid}.deletionPending = true`.
   - The Auth user is NOT disabled so that the user can authenticate and reach S22.05 to restore.
   - Signing in within 30 days triggers the router guard redirect to S22.05 (`/account/restore`).
   - "Khôi phục tài khoản" atomically resets `accountStatus` to `active`, clears `restoreUntil`, and un-hides `photographers/{uid}.deletionPending`.
2. **Direct Blocker Queries (Decision 12):**
   - Read directly from collections (`payments`, `refunds`, `bookings`, `events`, `jobs`, `quotes`, `studio_members`, `studio_collaborations`, `earnings`). Does not depend on #141's payer history projection.
3. **Soft Blocker Sources:**
   - Queries against collections whose plans have not yet merged (e.g. `jobs`, `quotes`, `studio_members`) return empty lists and do not block deletion until their features populate data.
4. **Data Export via In-App Download Link (Decision 9 & 10):**
   - No email vendor exists; export generates a JSON file written to Firebase Storage `exports/{uid}/{exportId}.json` with signed download URL accessible for 7 days.
   - 24-hour rate limit on exports (`exportCooldownUntil`).
   - Export is not permitted while account deletion is pending (`not_eligible`).
5. **Tombstone Strategy (Decision 11):**
   - After 30 days, `users/{uid}` is not deleted, but replaced with an anonymous tombstone (`displayName: 'Người dùng đã xoá'`, `avatarUrl: null`, `deleted: true`, `deletedAt`). Auth user is deleted last.
6. **Hide from Discovery (Decision 13):**
   - Photographers can toggle `hiddenFromDiscovery` in S22.03.
   - Excluded from search (`FindController`) and recommendations (`LocalRecommender`), but direct links and existing customer chats/bookings continue to work.

---

## Skipped Emulator Suites
Per standing instruction for this plan, rules tests and integration tests were authored and syntax-checked, but execution is deferred to CI:
- `firestore.rules` and `storage.rules` emulator suite (`rules.test.mjs`)
- Functions integration suite (`account.test.ts`)

---

## Deploy Order
1. **Firestore rules and indexes:**
   - Deploy `firestore.rules`.
   - Index overrides: `account_deletions (status ASC, restoreUntil ASC)`, `payments (payerId ASC, createdAt DESC)`.
2. **Storage rules (Manual deploy required):**
   - `npm run deploy:storage:dev` (or Firebase deploy with Storage enabled) to permit owner read for `exports/{uid}/*`.
3. **Cloud Functions:**
   - Deploy `requestAccountDeletion`, `restoreAccount`, `requestDataExport`, `getAccountDeletionBlockers`, `onAccountDeletionUpdated`.
   - Updated `pruneNotifications` scheduled job (includes `startDueAccountPurges` and `pruneDataExports`).
4. **App (Flutter):**
   - Release Flutter client containing S22.02, S22.03, S22.05, settings group, router guard, and discovery filter.

---

## Carry / Deferred
- Any later feature adding new models that hold customer/photographer obligations must register its blocker kind in `accountDeletionBlockers` and entry in `ACCOUNT_DATA_MAP`.
- Google Play web account deletion request page (public web form) is deferred as part of web portal rollout.
