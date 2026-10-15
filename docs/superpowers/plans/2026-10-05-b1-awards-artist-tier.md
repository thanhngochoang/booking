# B1: Awards and the Nhiếp ảnh gia (NAG) tier (S25, S03.01 awards) Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle or performance steps; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, `storage.rules` and adds Functions. Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **Lanes:** Tasks 1–4 are lane 2 (domain, Functions, rules, CLI, `lib/data/**`, `lib/core/widgets/**`); Tasks 5–6 are lane 1 after lane 2 merges Task 4 (gate **GB1**). **Needs plan A1 Tasks 1–5 merged** (`providerType`, `recomputeArtistTier` hook, `ProviderTag`, `approvedAwardCount` read in the app).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** Photographers list their awards with proof, staff approve or return each one, and an individual with at least 3 approved awards automatically becomes a Nhiếp ảnh gia (gold mark) — and drops back below the threshold; approved awards show on the profile (S03.01) and the photographer follows progress on S25.01.

**Architecture:** `awards/{id}` (public when approved, owner otherwise) and `awardProofs/{awardId}` (owner only) are written by callables only; proof images upload to a private Storage folder. Staff decide through `reviewAward`, gated by the `staffRole == 'admin'` custom claim; until the internal tools of S23 exist, admins use a small CLI that lists the queue and calls the same use case. A trigger on `awards/{id}` recomputes `approvedAwardCount` and the tier on `photographers/{uid}` (the rule from spec §2.3 lives in `packages/domain`; plan A1's `recomputeArtistTier` hook now calls it). A daily job purges proofs 30 days after a final decision.

**Tech Stack:** TypeScript (domain, Functions v2: callables, `onDocumentWritten`, `onSchedule`), Firestore and Storage rules; Flutter, Riverpod 3, existing `MediaUploader`, `imagePickerProvider`, `showAppSheet`, `AsyncView`, `StatusBadge`, `CapacityBar`, `GlassCard`.

**Spec:** `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §2 (all), §1.3 (S03.01 NAG variant), §6, §10; `docs/superpowers/specs/screens/portfolio-awards.md` (S03.01 biến thể NAG, S09.01 nudge, S25.01, S25.02); `docs/superpowers/specs/components/shared-components.md` → `AwardChip`, `AwardRow`; `docs/superpowers/specs/data-model/domain-model.md` §2.8 (`Award`, `AwardProof`), §4 (`AwardResult`, `AwardStatus`), §5 (award machine), §6 invariant 16; mock `docs/design/ui-mock.html` `#S03.01-nag`, `#S25.01`, `#S25.02`.

**Prerequisite:** plan A1 Tasks 1–5 merged; develop at or after PR #25.

## Contract with existing code

First step of Tasks 1 and 5 checks; adapt and ledger differences:

- From A1: domain `ProviderType`, `providerTypeOf`, `ProviderDeps.recomputeArtistTier`; Functions `live_provider.ts` (where the no-op hook is wired), the server-only fields helper in `firestore.rules` (`approvedAwardCount`, `artistSince` already listed); app `PhotographerSummary.providerType/approvedAwardCount`, `ProviderTag`, `ProviderMark`.
- Domain/Functions: `DomainError`, `Clock`, `IdGenerator`, `isId`, `graphemeCount`, `CALLABLE_OPTIONS`, `TRIGGER_OPTIONS`, `SCHEDULE_OPTIONS`, `toHttpsError`, `CallableInput`, `db()`, the Storage bucket accessor used by the review callable (plan 4e, `storageUrlPrefixes`), `scheduled/booking_clock.ts` pattern.
- Rules: `storage.rules` `posts/{uid}/{postId}/{file}` as the pattern for a new private folder.
- App: `MediaUploader.upload(PickedImage, storagePath:)` / `delete`, `imagePickerProvider`, `photographerProfileProvider`, S09.01 and S09.02 screens, `ProfileHeader`, `StatTileRow`, the badges row on S03.01, `lib/app/router.dart`, `ScreenCodes.myAwards` (S25.01), `ScreenCodes.editAward` (S25.02).

## Global Constraints

- "Giải không gắn vào từng bài (đã chốt)." Fields: "cuộc thi / triển lãm, năm, hạng mục (tuỳ chọn), kết quả, tác phẩm (tuỳ chọn, liên kết tới một bài của mình), minh chứng (ít nhất một: ảnh giấy chứng nhận hoặc link trang công bố kết quả)."
- `AwardResult`: "`gold` (Vàng / Nhất), `silver` (Bạc / Nhì), `bronze` (Đồng / Ba), `honorable` (Khuyến khích), `finalist` (Top / Chung kết), `exhibited` (Được chọn triển lãm)."
- Machine (verbatim): `pending ──(staff duyệt)──▶ approved`, `──(cần bổ sung, có lý do)──▶ needs_info ──(chủ hồ sơ sửa)──▶ pending`, `└ ──(từ chối, có lý do)──▶ rejected`, `approved ──(chủ hồ sơ sửa nội dung)──▶ pending`, `approved ──(staff thu hồi, có lý do)──▶ revoked`.
- "lý do bắt buộc trừ khi duyệt"; "Mọi quyết định ghi nhật ký kiểm toán (spec chính 3i.6)."
- "Minh chứng lưu riêng tư (chỉ chủ hồ sơ và staff đọc), xoá 30 ngày sau khi giải ra trạng thái cuối (`approved`, `rejected`, `revoked`). Chỉ giải `approved` hiện công khai."
- "Studio vẫn khai giải được (hiện trên hồ sơ studio) nhưng không tính hạng."
- Tier: "`providerType = individual` và **≥ 3 giải `approved`**. Server tự đặt `providerType = artist` và `artistSince`, gửi thông báo `artist_granted`. Không có đơn xin riêng." "Số giải đã duyệt tụt dưới ngưỡng … → server đặt lại `individual`, gửi `artist_revoked`."
- S25.02 validation: "Năm" 4 digits 1950–current year; up to 3 images + 2 https links; "link không phải https → "Link phải bắt đầu bằng https://""; images > 10 MB are compressed before upload.
- Copy and keys: the `s2501_…`, `s2502_…` and award status strings of `screens/portfolio-awards.md` (camelCase app keys, Vietnamese text verbatim).
- Layering, strings, tokens, imports, Firebase only in adapters, `AsyncView` for every `AsyncValue`, one primary action per screen, commit trailer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions (where the spec is silent)

1. **Docs.** `awards/{id}`: `photographerId`, `competition` (2–120), `year`, `category` (≤ 60, optional), `result`, `workPostId?` (a `work` post of the owner), `status`, `reviewNote?`, `reviewedBy?`, `reviewedAt?`, `createdAt`, `updatedAt`. `awardProofs/{awardId}`: `photographerId`, `files: [{storagePath}]` (≤ 3, under `awardProofs/{uid}/{awardId}/`), `links` (≤ 2, https, ≤ 300 chars), `purgeAfter?`. `awardAudit/{id}`: `awardId`, `actorId`, `action` (`approve | needs_info | reject | revoke`), `note`, `at` (append-only, no client access).
2. **Callables.** `createAward(input)` → `{awardId}` (status `pending`; ≤ 50 awards per photographer, else `limit_exceeded`); `updateAward({awardId, …})` (owner; any status except `revoked`; content change → `pending`, clears `reviewNote`); `deleteAward({awardId})` (owner; deletes award, proof doc and files); `reviewAward({awardId, action, note?})` (staff; `approve` only from `pending`, `needs_info`/`reject` from `pending`, `revoke` from `approved`; `note` 5–500 required except approve; writes the audit row; sets `purgeAfter = now + 30 d` on final states). Callers without the photographer role (create) or the admin claim (review) → `permission_denied`.
3. **Proof upload.** The app picks an award id (ULID) before uploading (`createAward` accepts the id like `submitReview` accepts `postId`), uploads to `awardProofs/{uid}/{awardId}/{fileId}.jpg` (a fresh ULID per file; the storage rule is create-only, so files cannot be swapped after review — ruling 2026-10-06 in unit 9c/1-L2), then calls the callable with the storage paths. Storage rule: owner create/read/delete, image ≤ 10 MB; nobody else (staff read through the Admin SDK).
4. **Recompute** (`recomputeTier(uid)` use case, called by the trigger on every award write and by A1's hook): count `approved` awards → `approvedAwardCount`; `studio` keeps its type; else `artist` when count ≥ 3 (set `artistSince` when it was not artist), `individual` when < 3 (clear `artistSince`). Writes only when something changes (no trigger loops). Emits `artist_granted` / `artist_revoked` through a `notify` port whose live adapter is a logged no-op until plan S17 (named `notifyTierChange`).
5. **Award review notifications** (`award_reviewed`) go through the same no-op port (`notifyAwardReviewed`).
6. **Public reads.** S03.01: `awards where photographerId == uid and status == 'approved' orderBy year desc, createdAt desc` (rules allow the query because of the status filter). S25.01: owner query without the status filter. Indexes: `awards (photographerId, status, year desc, createdAt desc)`, `awards (photographerId, createdAt desc)`, `awards (status, createdAt)` (CLI queue).
7. **Staff CLI** `app_flutter/firebase/functions/tools/awards.ts` (`npm run awards -- list | show <id> | approve <id> | needs-info <id> "<note>" | reject <id> "<note>" | revoke <id> "<note>"`), Admin SDK with `GOOGLE_APPLICATION_CREDENTIALS` or the emulator; `show` prints signed URLs (15 min) for proof files; the actor id is a required `--actor <uid>` of a user with the admin claim. It calls the same `reviewAward` use case.
8. **Purge** `purgeAwardProofs` daily (`SCHEDULE_OPTIONS`, 03:00 Asia/Ho_Chi_Minh): proof docs with `purgeAfter <= now` → delete their files and the doc.
9. **S03.01 NAG variant** applies when `providerType == artist`: stat tiles become rating · "giải thưởng" (= `approvedAwardCount`) · buổi chụp · kinh nghiệm (replacing "phản hồi"); the awards strip (≤ 2 visible, horizontal scroll, newest first) sits where the badges row was; badges move below the bio; tapping the strip opens a read-only sheet with all approved awards (`AwardRow` without status). A studio or individual with approved awards shows the strip below the bio, stats unchanged.

## Review Focus

1. The third award is approved → the profile turns gold without the photographer reopening the app; a later revocation turns it back. Pinned by Task 1 ("the third approval makes an artist", "a revocation below 3 makes an individual again") and Task 5 ("S25.01 switches to Bạn là Nhiếp ảnh gia when the third award is approved").
2. A studio with 5 approved awards → stays `studio`, no gold mark. Pinned by Task 1 ("a studio never becomes an artist").
3. Editing an approved award (e.g. changing the year) → it goes back to pending and, if it was the third, the tier drops until re-approval. Pinned by Task 1 ("editing an approved award re-queues it and recounts").
4. Someone else's (or no) proof path, more than 3 files, an http link → refused, nothing written. Pinned by Task 1 ("proof paths must be the caller's own folder", "http links are invalid", "more than 3 files is invalid").
5. The trigger runs twice, or recompute runs from both the trigger and A1's hook → one change, no write when nothing changed. Pinned by Task 2 ("recompute without a change writes nothing").

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/src/award.ts`, `award_ports.ts`, `memory_award_store.ts`, `award_use_cases.ts`, `artist_tier.ts` (create) | rules, ports, reference adapter, use cases, tier rule |
| `packages/domain/test/award*.test.ts`, `artist_tier.test.ts` | tests |
| `app_flutter/firebase/functions/src/infra/award_firestore.ts`, `live_award.ts`, `src/callables/award.ts`, `src/triggers/award_write.ts`, `src/scheduled/award_purge.ts` (create); `src/infra/live_provider.ts`, `src/index.ts`, `package.json` (script `awards`) (modify) | adapters, callables, trigger, schedule, hook wiring |
| `app_flutter/firebase/functions/tools/awards.ts` (create) | staff CLI |
| `app_flutter/firebase/functions/test/unit/award_*.test.ts`, `test/integration/award.test.ts` | tests |
| `app_flutter/firebase/firestore.rules`, `storage.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` (modify) | read rules, private proofs, indexes |
| `app_flutter/lib/data/award/award.dart`, `award_repository.dart` (interface + fake), `firestore_award_repository.dart`, `award_providers.dart` (create) | app data |
| `app_flutter/lib/core/widgets/award_chip.dart`, `award_row.dart` (create); `core.dart` (modify); gallery | widgets |
| `app_flutter/lib/features/awards/my_awards_screen.dart`, `my_awards_controller.dart`, `edit_award_sheet.dart`, `edit_award_controller.dart` (create); S09.01, S09.02 (modify) | S25.01, S25.02, entries |
| `app_flutter/lib/features/photographer_profile/widgets/profile_header.dart`, `profile_sections.dart` (modify) | NAG variant, awards strip |
| `app_flutter/lib/app/router.dart`, `lib/l10n/app_vi.arb` (modify, append-only) | route `/me/awards`, strings |

---

### Task 1: Domain — awards, review, tier

**Files:**
- Create: `packages/domain/src/award.ts`, `award_ports.ts`, `memory_award_store.ts`, `award_use_cases.ts`, `artist_tier.ts`; modify `src/index.ts`
- Test: `packages/domain/test/award.test.ts`, `award_use_cases.test.ts`, `artist_tier.test.ts`

**Interfaces:**
- Produces:

```ts
export const AWARD_RESULTS = ['gold', 'silver', 'bronze', 'honorable', 'finalist', 'exhibited'] as const;
export const AWARD_STATUSES = ['pending', 'needs_info', 'approved', 'rejected', 'revoked'] as const;
export const ARTIST_THRESHOLD = 3, AWARDS_PER_PHOTOGRAPHER = 50, PROOF_FILES_MAX = 3, PROOF_LINKS_MAX = 2, PROOF_PURGE_DAYS = 30;
export type AwardResult = (typeof AWARD_RESULTS)[number];
export type AwardStatus = (typeof AWARD_STATUSES)[number];
export type ReviewAction = 'approve' | 'needs_info' | 'reject' | 'revoke';
export interface AwardInput {
  readonly awardId: string; readonly competition: string; readonly year: number; readonly category: string | null;
  readonly result: AwardResult; readonly workPostId: string | null;
  readonly proofFiles: readonly string[];           // storage paths
  readonly proofLinks: readonly string[];
}
export interface Award { readonly id: string; readonly photographerId: string; readonly competition: string; readonly year: number;
  readonly category: string | null; readonly result: AwardResult; readonly workPostId: string | null; readonly status: AwardStatus;
  readonly reviewNote: string | null; readonly reviewedBy: string | null; readonly reviewedAt: Date | null;
  readonly createdAt: Date; readonly updatedAt: Date; }
export interface AwardProof { readonly awardId: string; readonly photographerId: string; readonly files: readonly string[];
  readonly links: readonly string[]; readonly purgeAfter: Date | null; }

/** invalid_argument unless Decision 1/3 and Global Constraints hold; `now` gives the current year. */
export function validateAwardInput(raw: unknown, callerId: string, now: Date): AwardInput;
export function nextStatus(current: AwardStatus, action: ReviewAction): AwardStatus;   // throws conflict on an illegal move
/** Pure tier rule (spec §2.3). */
export function tierFor(current: ProviderType, approvedCount: number): ProviderType;

export interface AwardTx {
  getAward(id: string): Promise<Award | null>;
  getProof(awardId: string): Promise<AwardProof | null>;
  countAwards(photographerId: string): Promise<number>;
  isOwnWorkPost(postId: string, photographerId: string): Promise<boolean>;
  putAward(a: Award): void; putProof(p: AwardProof): void; deleteAward(id: string): void; deleteProof(awardId: string): void;
  addAudit(row: { awardId: string; actorId: string; action: ReviewAction; note: string | null; at: Date }): void;
}
export interface TierTx {
  getTierState(uid: string): Promise<{ providerType: ProviderType; artistSince: Date | null; approvedAwardCount: number } | null>;
  countApproved(uid: string): Promise<number>;
  setTierState(uid: string, s: { providerType: ProviderType; artistSince: Date | null; approvedAwardCount: number }): void;
}
export interface AwardDeps {
  readonly awards: { runTransaction<T>(fn: (tx: AwardTx) => Promise<T>): Promise<T> };
  readonly tiers: { runTransaction<T>(fn: (tx: TierTx) => Promise<T>): Promise<T> };
  readonly files: { delete(paths: readonly string[]): Promise<void> };
  readonly notify: { tierChanged(uid: string, to: 'artist' | 'individual'): Promise<void>; awardReviewed(uid: string, awardId: string, status: AwardStatus): Promise<void> };
  readonly clock: Clock;
}
export function createAward(deps: AwardDeps, callerId: string, raw: unknown): Promise<{ awardId: string }>;
export function updateAward(deps: AwardDeps, callerId: string, raw: unknown): Promise<void>;
export function deleteAward(deps: AwardDeps, callerId: string, raw: unknown): Promise<void>;
export function reviewAward(deps: AwardDeps, actorId: string, isAdmin: boolean, raw: unknown): Promise<{ status: AwardStatus }>;
export function recomputeTier(deps: AwardDeps, uid: string): Promise<'unchanged' | 'artist' | 'individual' | 'count'>;
export function purgeDueProofs(deps: AwardDeps & { proofsDue: (now: Date) => Promise<AwardProof[]> }): Promise<number>;
```

`tierFor` (sample — the one rule everything else relies on):

```ts
export function tierFor(current: ProviderType, approvedCount: number): ProviderType {
  if (current === 'studio') return 'studio';
  return approvedCount >= ARTIST_THRESHOLD ? 'artist' : 'individual';
}
```

- [ ] **Step 1: Contract check** (A1 and domain parts).
- [ ] **Step 2: Write the failing tests:**
  - `award.test.ts`: "competition is trimmed and 2–120 characters"; "year before 1950 or after this year is invalid"; "an unknown result is invalid"; "at least one proof is required"; "proof paths must be the caller's own folder"; "more than 3 files is invalid"; "http links are invalid"; "illegal review moves are conflicts" (approve from approved, revoke from pending, …).
  - `award_use_cases.test.ts`: "create stores a pending award and its proof"; "the 51st award is limit_exceeded"; "a work post of someone else is invalid"; "editing an approved award re-queues it and recounts"; "a revoked award cannot be edited"; "delete removes the award, proof doc and files"; "only admins review"; "needs_info without a note is invalid"; "approve writes an audit row and a purge date"; "review notifies the owner".
  - `artist_tier.test.ts`: "the third approval makes an artist" (sets `artistSince`, notifies `artist`); "a revocation below 3 makes an individual again" (clears `artistSince`, notifies); "a studio never becomes an artist" (count still updated); "recompute without a change writes nothing"; "purge deletes due proofs and their files only".
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → fail. **Step 4: Implement.** **Step 5: Run** `npm test && npm run lint` → pass.
- [ ] **Step 6: Commit** `feat(domain): awards, staff review and the artist tier [b1]`.

### Task 2: Functions, rules, storage, staff CLI

**Files:**
- Create: `src/infra/award_firestore.ts`, `src/infra/live_award.ts`, `src/callables/award.ts`, `src/triggers/award_write.ts`, `src/scheduled/award_purge.ts`, `tools/awards.ts`; modify `src/infra/live_provider.ts` (the A1 hook now runs `recomputeTier`), `src/index.ts`, `package.json` (`"awards": "tsx tools/awards.ts"`), `seed/fixtures.ts` (an artist with 3 approved awards, a pending award, an admin user with the claim)
- Modify: `app_flutter/firebase/firestore.rules`, `storage.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`
- Test: `test/unit/award_callables.test.ts`, `test/unit/award_cli.test.ts` (argument parsing, dry-run against the memory store), `test/integration/award.test.ts`

**Interfaces:**
- Produces: callables `createAward`, `updateAward`, `deleteAward`, `reviewAward`; trigger `onAwardWrite` (`awards/{awardId}` → `recomputeTier(photographerId)`, for both the before and after owner when they differ); schedule `purgeAwardProofs`. `isAdmin = request.auth?.token?.staffRole === 'admin'`.

Rules (sample):

```
match /awards/{awardId} {
  allow read: if signedIn() && (resource.data.status == 'approved' || resource.data.photographerId == request.auth.uid);
  allow write: if false;
}
match /awardProofs/{awardId} {
  allow read: if signedIn() && resource.data.photographerId == request.auth.uid;
  allow write: if false;
}
match /awardAudit/{id} { allow read, write: if false; }
```

Storage:

```
match /awardProofs/{uid}/{awardId}/{file} {
  allow read, delete: if request.auth != null && request.auth.uid == uid;
  allow create: if request.auth != null && request.auth.uid == uid
    && request.resource.contentType.matches('image/(jpeg|png|webp|heic|heif)') && request.resource.size <= 10 * 1024 * 1024;
}
```

- [ ] **Step 1: Write the failing tests.** Unit: "unauthenticated is refused"; "a non-admin reviewAward is permission-denied"; "the admin claim reaches the use case as isAdmin"; CLI "approve needs --actor"; "list prints pending awards oldest first". Integration (do not run): "a third approval turns the photographer gold"; "recompute without a change writes nothing"; "deleting an approved award recounts"; "the A1 hook recomputes after studio → individual". Rules (do not run): "anyone signed in reads approved awards"; "a pending award is readable by its owner only"; "proof docs are owner-only"; "nobody reads the audit log"; storage "others cannot read a proof image"; "a proof image over 10 MB is refused".
- [ ] **Step 2: Run** `(cd app_flutter/firebase/functions && npm test)` → fail. **Step 3: Implement.** **Step 4: Run** `npm test && npm run build` → pass; ledger the emulator suites.
- [ ] **Step 5: Commit** `feat(functions): award callables, tier trigger, proof purge, staff CLI [b1]`.

### Task 3: App data — awards repository

**Files:**
- Create: `app_flutter/lib/data/award/award.dart`, `award_repository.dart` (interface + `FakeAwardRepository`), `firestore_award_repository.dart`, `award_providers.dart`; `test/support/content_fixtures.dart` (`fixtureAward`)
- Test: `test/data/award/firestore_award_repository_test.dart`

**Interfaces:**
- Produces:

```dart
enum AwardResult { gold, silver, bronze, honorable, finalist, exhibited; String get code; static AwardResult fromCode(Object? raw); }
enum AwardStatus { pending, needsInfo, approved, rejected, revoked; String get code; static AwardStatus fromCode(Object? raw); }
@immutable class Award { const Award({required this.id, required this.photographerId, required this.competition, required this.year,
  this.category, required this.result, this.workPostId, required this.status, this.reviewNote, required this.createdAt}); … }
@immutable class AwardDraft { const AwardDraft({required this.awardId, required this.competition, required this.year, this.category,
  required this.result, this.workPostId, this.proofPaths = const [], this.proofLinks = const []}); … }
abstract class AwardRepository {
  Stream<List<Award>> watchMine(String uid);                 // newest first, every status
  Stream<List<Award>> watchApproved(String photographerId);  // Decision 6 order
  Future<AwardDraft?> loadDraft(String awardId);             // for editing: award + its proof doc (owner)
  Future<void> create(AwardDraft d);
  Future<void> update(AwardDraft d);
  Future<void> delete(String awardId);
  String proofPath(String uid, String awardId, String fileId); // 'awardProofs/$uid/$awardId/$fileId.jpg', fileId = fresh ULID per upload (create-only storage rule)
}
class AwardError implements Exception { const AwardError(this.code); final String code; }
final awardRepositoryProvider = Provider<AwardRepository>(...);
final myAwardsProvider = StreamProvider.autoDispose<List<Award>>(...);
final approvedAwardsProvider = StreamProvider.autoDispose.family<List<Award>, String>(...);
```

- [ ] **Step 1: Write the failing tests:** "an award doc parses its status and result"; "an unknown status reads as pending"; "an unknown result skips the doc"; "watchApproved asks only approved awards newest year first"; "create sends paths and links"; "limit_exceeded becomes AwardError".
- [ ] **Step 2–4:** run → fail; implement; `flutter analyze && flutter test test/data` → pass.
- [ ] **Step 5: Commit** `feat(data): award repository [b1]`.

### Task 4: Core widgets — `AwardChip`, `AwardRow`

**Files:**
- Create: `app_flutter/lib/core/widgets/award_chip.dart`, `award_row.dart`; modify `core.dart`; gallery entries
- Test: `test/core/widgets/award_chip_test.dart`, `award_row_test.dart`

**Interfaces:**
- Produces:

```dart
class AwardChip extends StatelessWidget {     // 178dp, gold soft background and line, gold disc with the award icon
  const AwardChip({super.key, required this.resultLabel, required this.subtitle, this.onTap});   // "Huy chương Vàng", "VIPA 2024 · Phong cảnh"
  const AwardChip.skeleton({super.key});
}
class AwardRow extends StatelessWidget {      // S25.01 and the read-only list
  const AwardRow({super.key, required this.title, required this.subtitle, this.status, this.statusLabel, this.onTap, this.onLongPress});
  final AwardStatus? status;                  // null = read-only list (no badge); approved → gold disc, others grey
}
/// "Huy chương Vàng" style labels for chips; short labels for rows ("Vàng / Nhất" in the picker).
String awardResultTitle(AppLocalizations l, AwardResult r);
```

- [ ] **Step 1: Write the failing tests:** "chip shows the result and the competition line"; "row shows the status badge with text"; "an approved row has the gold disc"; "a read-only row has no badge"; "chip skeleton matches its size".
- [ ] **Step 2–4:** run → fail; implement (`AppColors.gold*` from A1); `flutter analyze && flutter test test/core` → pass.
- [ ] **Step 5: Commit** `feat(core): award chip and award row [b1]`. **Gate GB1.**

### Task 5: Lane 1 — S25.01, S25.02, entries in S09.01 and S09.02

**Files:**
- Create: `features/awards/my_awards_screen.dart` (`ScreenCode(ScreenCodes.myAwards, …)`), `my_awards_controller.dart`, `edit_award_sheet.dart` (`ScreenCode(ScreenCodes.editAward, …)`), `edit_award_controller.dart`; route `/me/awards`
- Modify: S09.02 settings (photographers: row "Giải thưởng"), S09.01 profile (individual, not artist: nudge row "Có giải thưởng? Lên hạng Nhiếp ảnh gia" with "Để sau" stored as `awardNudgeDismissed:<uid>`), `lib/l10n/app_vi.arb` (block), `test/support/` world for awards
- Test: `test/features/awards/my_awards_screen_test.dart`, `edit_award_sheet_test.dart`, settings and profile tests (extend)

**Interfaces:**
- Consumes: Task 3 repository/providers, Task 4 widgets, `photographerProfileProvider` / own summary (`providerType`, `approvedAwardCount`), `MediaUploader`, `imagePickerProvider`, `newUlid`, `showConfirmSheet`, `CapacityBar`, `GlassCard`.

Behaviour (mock `#S25.01`, `#S25.02`; strings and states in `screens/portfolio-awards.md`):
- S25.01: tier card "Hạng Nhiếp ảnh gia (NAG)" with "{approved} / 3" and `CapacityBar`; artist → "Bạn là Nhiếp ảnh gia · từ {date}"; studio → no tier card. List "Đã khai · {n} giải" of `AwardRow`s (title "{result} · {competition} {year}", subtitle = category or the staff note for `needsInfo`/`rejected`/`revoked`). Tap → S25.02 (editing an approved award asks first: "Giải sẽ được duyệt lại"); long press → delete with `showConfirmSheet` (red). Primary "Thêm giải thưởng". (i) opens a read-only sheet explaining the tier rule.
- S25.02: fields per spec; result chips single choice; "Tác phẩm" opens a picker of own `work` posts (reuse `PostPickerGrid` from plan C if merged, else a simple 3-column grid with single choice — ledger which); "Minh chứng" sub-sheet: up to 3 images (upload as picked, per-tile progress and retry, using `proofPath`) and up to 2 links; "Gửi duyệt" disabled until competition, year, result and ≥ 1 proof are valid; closing without saving deletes uploaded files (best effort) and asks "Bỏ thay đổi?" when something was entered.

- [ ] **Step 1: Contract check** (lane 1 part). **Step 2: Write the failing tests:** S25.01 "progress shows approved out of 3"; "an artist sees Bạn là Nhiếp ảnh gia"; "a studio has no tier card"; "a needs_info award shows the staff note"; "S25.01 switches to Bạn là Nhiếp ảnh gia when the third award is approved" (fake stream emits a new summary); "deleting asks first"; S25.02 "submit stays disabled without a proof"; "an http link shows the https error"; "a failed upload tile can be retried"; "closing without saving deletes uploaded files"; "editing an approved award warns it will be reviewed again"; S09.02 "photographers see Giải thưởng"; S09.01 "the nudge shows for individuals and hides after Để sau".
- [ ] **Step 3: Run** → fail. **Step 4: Implement.** **Step 5: Run** `flutter analyze && flutter test` → pass.
- [ ] **Step 6: Commit** `feat(awards): Giải thưởng của tôi and award sheet S25.01–S25.02 [b1]`.

### Task 6: Lane 1 — S03.01 NAG variant and awards strip

**Files:**
- Modify: `features/photographer_profile/widgets/profile_header.dart`, `profile_sections.dart` (or a new `widgets/awards_strip.dart` in the feature), `photographer_profile_screen.dart`
- Test: `test/features/photographer_profile/photographer_profile_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `approvedAwardsProvider(uid)`, `AwardChip`, `AwardRow`, `PhotographerSummary.providerType/approvedAwardCount`, `ProviderTag`.

Behaviour: Decision 9.

- [ ] **Step 1: Write the failing tests:** "an artist shows the giải thưởng stat instead of phản hồi"; "an artist shows the awards strip above the badges"; "the strip opens the full list read-only"; "an individual with approved awards shows the strip below the bio"; "no approved awards → no strip"; "the strip loads with chip skeletons".
- [ ] **Step 2: Run** → fail. **Step 3: Implement.** **Step 4: Run** `flutter analyze && flutter test test/features/photographer_profile` → pass.
- [ ] **Step 5: Update** the S25.01, S25.02 and S03.01 status cells in `remaining-screens.md` §2 ("✅ đã làm (b1)"; S23.07 stays "chưa có mock", CLI noted).
- [ ] **Step 6: Commit** `feat(profile): Nhiếp ảnh gia profile variant and awards strip [b1]`.
