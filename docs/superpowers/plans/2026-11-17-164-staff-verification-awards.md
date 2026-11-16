# S23 · Staff verification and award review (#164) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Code goes to **booking-be**. Part A's app change (A4) and each part's last task go to this repository. Each part is one unit: branch `plan/<issue>-<slug>` in both repos; the booking-be PR lands first (`land.py <issue> --pr <n> --repo thanhngochoang/booking-be`), then the PR here.

**Goal:** Admin and support staff review awards in the dashboard (S23.07), and verifications (S23.04): identity and business submissions, revoking a verification, and reinstating it with a second person's approval. Every view of identity data is audited. The NAG tier now waits for identity verification (V1).

**Architecture:** As in #162 and #163. Rules are pure functions in `packages/domain`. Callables are thin (`gate()` → domain use case). The dashboard reads Firestore with the Admin SDK through per-screen readers and writes only through callables. The one exception to "reads go through readers" is the identity detail. It is read through the `getVerificationForReview` callable, so each view writes an `audit_log` row (spec V3). Reinstating a verification is a `staff_approvals` kind that runs through `execute` (#163 D2), because the verification store has its own transaction.

**Tech Stack:** TypeScript (ESM, Node 24), `node:test` (domain, Functions unit), Cloud Functions v2 `onCall` (`asia-southeast1`), Firestore + Storage, Next.js 16 BFF (React 19, Vitest + RTL), Playwright on the emulators; Flutter for A4.

**Spec:** `docs/superpowers/specs/screens/staff-verification-awards.md` (V1–V4, §1–§8). Also:
- `docs/superpowers/specs/2026-10-08-dashboard-web-design.md` (§2.3 readers, §2.4 writes, §4.2 roles, §5.4 approvals);
- `docs/superpowers/specs/2026-10-06-identity-verification-design.md` §4;
- `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §2.

Mock: `docs/design/dashboard-mock.html#S23.04`, `#S23.07`, and the S23.04 reject dialog pattern ("Mẫu · QueueLayout + DecisionDialog").

Handovers whose rulings stand:
- `ledger-162-dashboard-foundation.md`: rulings 1–16, and the "Các ticket sau thêm gì" row for #164;
- `ledger-163-money-a.md`, `-b.md`, `-c.md`: the `execute` approval path, `Tabs`, cursors and `QueueCardSpec`.

## Units

| Part | Issue | Tasks | Blocked by |
|---|---|---|---|
| A · Staff actions, NAG waits for verification (V1), S23.07 Giải thưởng, S25.01 nudge | #164 | A1–A5 | — (#162, #135, #145 merged) |
| B · S23.04 Xác minh: review, revoke, reinstate, audited detail | new issue `S23 · Duyệt xác minh danh tính & doanh nghiệp` | B1–B4 | Part A |

## Global Constraints

- Everything in #162's Global Constraints still holds:
  - the browser never touches Firestore or Storage; writes go only through callables;
  - TOTP on every staff route and callable;
  - reasons are 5–500 characters;
  - no realtime listeners; queues refresh every 30 s;
  - strings live in `src/messages/vi.ts`;
  - one primary action per screen;
  - DTOs are plain objects;
  - the Blaze switch applies;
  - every error code is registered in four places.
- **Roles (spec §0):** both screens and all their callables are for `admin` and `support`. Finance and sales get no menu item, a 403 page, and `staff_forbidden` from the callables. Only admin proposes a reinstatement; admin or support approves it (V2).
- **Never auto-approve (V4).** No job or trigger approves a verification or an award.
- **At most 4 digits of an ID number (V3):** applies to DTOs, logs, audit `diff`, approval `params` and error messages. The full number and `idHash` never leave Functions. `getVerificationForReview` returns `idLast4` only.
- **Late thresholds:** identity and business reviews are late after 24 h (`REVIEW_SLA_HOURS`). Awards are late after 3 business days: Monday–Friday, Vietnam time (UTC+7), holidays not counted (spec Q1).
- **Notes and reasons:**
  - Award notes are 5–500 characters, required for every action except approve (`validateReviewNote`).
  - Verification approve and reject notes are 5–500 characters. The dashboard always asks for one; the domain keeps it optional on approve for the CLI.
  - A revoke note is **at least 20** characters (spec §2.3), in the domain as well.
  - A reinstate reason is 5–500 characters.
- **Verification timestamps are ISO strings** in Firestore (`submittedAt`, `decidedAt`, `business.submittedAt`, `verificationAudit.at`). Readers order and compare them as strings, which are lexicographically ordered. Award timestamps are Firestore `Timestamp`s.
- **Commits:** Conventional Commits, subject ending with `[#<issue of the part>]`, trailer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`. The booking-be PR body says `thanhngochoang/booking#<issue>`.
- **Tests:**
  - Domain: `cd packages/domain && npm run typecheck && npm run lint && npm test`.
  - Functions: `cd firebase/functions && npm run lint && npm run typecheck && npm test`. Integration and rules tests are written here and run by CI, not in the Claude sandbox.
  - Dashboard: `cd apps/dashboard && npm run lint && npm run typecheck && npm test && npm run build`. Playwright runs locally with the sandbox off (`MFA_DEV_BYPASS=1`) and in CI.
  - App (A4): from `app_flutter/`, `flutter analyze && flutter test test/features/awards`.

## Decisions this plan makes

Each goes into the part's handover ledger as a ruling.

- **D1 · Built on Firebase, like #163.** Memory note 2026-11-15 says the remaining dashboard screens should be built on the Phase 2 Node.js + PostgreSQL API. #163 (A, B, C) was nevertheless planned, approved and merged on Firebase callables after that note. No Phase 2 spec (#170) exists yet. This plan follows #163. Cost if wrong: the readers and callables of two screens move to the API with the rest of the money and content clusters (#183).
- **D2 · Two units.** Part A carries every shared change (all new `StaffAction`s, V1, the award review hardening) plus S23.07. Part B carries what only S23.04 needs. Spec §7 suggested this order before #135 merged; it still keeps each PR reviewable.
- **D3 · V1 in one rule, applied by recompute.**
  - `tierFor(current, approvedCount, verified)` gives `artist` only when `verified` is true.
  - `recomputeTier` reads `verified` through `TierState`.
  - The tier is recomputed:
    - after an award review (as today);
    - after every verification change that flips `photographers/{uid}.verified` (approve, revoke, reinstate), post-commit and quietly, like `reviewAward`;
    - by `onPhotographerWrite` when `verified` changed, as a backstop.

  The spec asks for the same transaction. Recompute is idempotent and already the award path's model, so the verification store does not gain the award ports. Cost if wrong: a few seconds in which a newly verified photographer with 3 awards still shows `individual`.
- **D4 · Existing unverified artists lose the tier on their next recompute.** That is the V1 rule. No production data exists yet (Phase 1 is not launched). Seeds are adjusted: Dũng is verified.
- **D5 · Audit next to the legacy audit collections.**
  - `reviewAward` and `reviewVerification` keep writing `awardAudit` and `verificationAudit`, which the CLI and app history read.
  - They also write `audit_log` in the same transaction, through an `AuditWriter` on their tx ports.
  - `getVerificationForReview` writes `verification.view` through `AuditLog` **before** it returns. If that write fails, the call fails and returns no identity data, as the tax export does.
- **D6 · Callers.** `reviewAward(deps, caller: StaffCaller, raw)` and `reviewVerification(deps, caller: StaffCaller, raw)` replace the `actorId`/`isAdmin` and `{uid, isAdmin}` parameters. They check with `assertStaffCaller`:
  - verification revoke: `verification.revoke`;
  - other verification actions: `verification.review`;
  - every award action: `award.review`.

  The CLIs build `{uid, role: 'admin', mfa: true}`: `--actor <uid>` for `awards`, `cli:<user>` for `verifications`, as `npm run staff` does.
- **D7 · Reinstating is a `staff_approvals` kind with `execute`.** `requestVerificationReinstate` always opens a request; there is no threshold.
  - The kind's `execute` runs `revoked → approved` in the verification store's own transaction. That transition is new in the state machine. It runs with the approver as actor and merges `approvalDiffOf` into the audit `diff`.
  - The guard is state: a record that is not `revoked` throws `conflict`, which closes the request stale.
  - `freeResubmitsLeft` is unchanged (spec Q3).
  - The photographer gets `verification_approved` again through `notifyVerificationChange`.
- **D8 · Duplicates come from the audit trail.** A submitted identity has passed its check, so its own hash belongs to it. Duplicate warnings are therefore the `verificationAudit` rows with `action: 'duplicate'` where this uid is `uid` or `otherUid`. Each other account is shown with its current status.
- **D9 · Approved-tab search** takes a uid (exact document) or a name prefix. The prefix is folded with `foldNameKey` and run as a range on `photographers.nameKey` (limit 20), then kept to `approved` verifications. There is no full-text search.
- **D10 · "Số booking đang chạy"** is computed in the detail only, not per row. It is `bookings` where `photographerId == uid` and `status not-in CLOSED_BOOKING_STATUSES`, as a `count()` served by the existing `(photographerId, status)` index.
- **D11 · Award queue order.**
  - Chờ duyệt: `updatedAt` ascending. This is when the award entered `pending`, so an edit after "Cần bổ sung" counts from the edit.
  - Cần bổ sung: `reviewedAt` ascending.
  - Đã duyệt and Đã từ chối: `reviewedAt` descending.

  A late award has `updatedAt <= businessCutoff(now, 72)`, so the late count is a plain range `count()`.
- **D12 · Navigation and cards.**
  - The "Hàng đợi" group gets Xác minh (`verified_user`) and Giải thưởng (`emoji_events`) before Chờ duyệt, as in the mock.
  - S23.09 gets three cards: `verifications_identity`, `verifications_business` and `awards_pending`.
  - `navBadges` sums cards that map to the same nav id.
  - A `verification_reinstate` request appears in the existing Chờ duyệt entry. Adding the kind gives support that menu item (`canApproveAny`).
- **D13 · Id search.** A shell-level resolver module, imported once by `ShellFrame`, registers the verification resolver. It sends a code to `/staff/verifications?uid=<code>` when the code is a Firebase uid (`/^[A-Za-z0-9]{28}$/`) or an emulator seed uid (`/^seed-[a-z0-9-]+$/`). No other resolver exists yet. Later tickets add theirs to the same module.
- **D14 · `DecisionDialog` gets `reasonMode: 'optional'`.** The award approve dialog uses it (spec §3: approving needs no note, but has an optional reason field). An empty optional reason is sent as no `note`.
- **D15 · Business docs are JPEG** (Storage rules: `jpegUpTo(3 MiB)`), so `SecureFileViewer` (image only) is enough. `requestSensitiveFileUrl` is the first dashboard server action for `getSensitiveFileUrl`. It checks the kind's own action:
  - `award_proof`: `award.view`;
  - `business_doc`: `verification.view`.

  The callable's `KIND_ACTION` moves to the same `.view` actions.

## Review Focus

1. **An ID number leaking.** The verification detail DTO, `verification.view` audit rows, approval `params` and every error must hold `idLast4` at most, and never `idHash` or `idNumberEnc`. Pinned in B1 (`review DTO has no idNumberEnc, idHash or 9+ digit run`) and B3 (screen shows `•••• 4821`).
2. **Two staff on one submission.** Support approves Giang while admin rejects the same record from a stale page: the second decision is `conflict`. The page reloads the detail and shows "Hồ sơ này vừa được {name} xử lý" instead of a generic error. Pinned in B1 (`approve after approve → conflict`) and B3 (`conflict reloads and shows the stale banner`).
3. **The NAG tier on every path.** These cases must each land on the right `providerType`:
   - the third award approved for a verified photographer;
   - the third approved for an unverified one;
   - the verification approved later;
   - verification revoked;
   - verification reinstated;
   - an award revoked below 3;
   - a studio.

   Pinned in A1 (the `tierFor` table and `recomputeTier` with `verified`), A2 (the trigger recomputes when `verified` flips) and B1 (reinstate gives back `artist`).
4. **Reinstate abuse.** These must all fail:
   - support proposing;
   - the proposer approving their own request (`same_person`);
   - a finance user approving;
   - approving after someone else already reinstated (stale, no second write).

   Pinned in B1.
5. **Business-day lateness around weekends.** An award submitted Friday 17:00 (Vietnam time) is not late on Tuesday 16:59 and is late on Wednesday 17:01. A Saturday submission counts from Monday 00:00. Pinned in A1 (`businessHoursBetween` table, `businessCutoff`).

## File structure (booking-be)

```
packages/domain/src/
  staff_permissions.ts      + view/revoke/reinstate/award.view actions             (A1)
  staff_approvals.ts        + verification_reinstate metadata row                  (A1)
  artist_tier.ts            tierFor(current, approvedCount, verified)              (A1)
  award_ports.ts            TierState.verified, AwardTx.audit                      (A1)
  award_use_cases.ts        reviewAward(deps, caller, raw), audit_log              (A1)
  review_sla.ts             businessHoursBetween, businessCutoff, awardWait        (A1)
  verification_ports.ts     VerificationTx.audit, VerificationReviewReader         (B1)
  verification_use_cases.ts reviewVerification(deps, caller, raw), revoke ≥ 20     (B1)
  verification_review.ts    verificationForReview, VerificationReviewDto           (B1)
  verification_reinstate.ts requestVerificationReinstate, verificationApprovalKinds (B1)
firebase/functions/src/
  callables/award.ts, callables/verification.ts, callables/sensitive_file.ts
  infra/award_firestore.ts, infra/verification_firestore.ts, infra/live_staff.ts
  triggers/photographer_write.ts, tools/awards.ts, tools/verifications.ts, seed/fixtures.ts
apps/dashboard/src/
  app/(staff)/staff/{awards,verifications}/, server/read/{awards,verifications}.ts + firestore/*,
  server/write/sensitive-file.ts, lib/{award-tabs,verification-tabs,id-resolvers.staff}.ts
```

---

# Part A · Staff actions, V1 and S23.07 (#164)

### Task A1: Actions, the V1 tier rule, award review with a staff caller, business-day lateness (domain)

**Files:**
- Modify: `packages/domain/src/staff_permissions.ts`, `staff_approvals.ts`, `artist_tier.ts`, `award_ports.ts`, `award_use_cases.ts`, `memory_award_store.ts`, `index.ts`
- Create: `packages/domain/src/review_sla.ts`
- Test: `packages/domain/test/staff_permissions.test.ts`, `artist_tier.test.ts`, `award_use_cases.test.ts`, `staff_approvals.test.ts`, `review_sla.test.ts`

**Interfaces:**
- Produces:
  - `STAFF_ACTIONS` adds:
    - `verification.view`, `verification.revoke`, `verification.reinstate.decide`, `award.view`: admin and support;
    - `verification.reinstate.request`: admin.

    `verification.review` and `award.review` stay admin and support.
  - `APPROVAL_KINDS.verification_reinstate = { requestAction: 'verification.reinstate.request', approveAction: 'verification.reinstate.decide' }`. It is metadata only; B1 supplies `execute`. Replace the test-only `verification_reinstate` rows in `packages/domain/test/staff_approvals.test.ts` (and the dashboard's `test/read/approvals.test.ts` in A3) with the real row.
  - `tierFor(current: ProviderType, approvedCount: number, verified: boolean): ProviderType`.
  - `TierState` gains `readonly verified: boolean`. `recomputeTier` passes it to `tierFor`. Studios are unchanged.
  - `AwardTx` gains `readonly audit: AuditWriter`. `reviewAward(deps: AwardDeps, caller: StaffCaller, raw: unknown): Promise<{ status: AwardStatus }>`:
    - order: `assertStaffCaller(caller, 'award.review')` first, then the existing self-review guard (`permission_denied`), then `nextStatus`;
    - besides `awardAudit` it writes `audit_log` `{actorId: caller.uid, actorRole: caller.role, action: 'award.<action>', entityType: 'award', entityId: awardId, reason: note, diff: {status: [before, after]}}`.
  - `review_sla.ts`:
    - `VN_OFFSET_MINUTES = 420`; `AWARD_REVIEW_BUSINESS_DAYS = 3`;
    - `businessHoursBetween(from: Date, to: Date): number`: hours, fractional, that fall on Monday–Friday in Vietnam time; 0 when `to <= from`;
    - `businessCutoff(now: Date, businessHours: number): Date`: the latest instant `t` with `businessHoursBetween(t, now) >= businessHours`;
    - `awardWait(submittedAt: Date, now: Date): { unit: 'hours' | 'days'; value: number; late: boolean }`:
      - `hours` (floored) under 24 business hours, else `days` (floored business hours / 24);
      - `late` when business hours > 72.

- [ ] **Step 1: Write the failing tests**

```ts
// staff_permissions.test.ts — add rows to the table
['verification.view', ['admin','support']], ['verification.revoke', ['admin','support']],
['verification.reinstate.request', ['admin']], ['verification.reinstate.decide', ['admin','support']],
['award.view', ['admin','support']],
// artist_tier.test.ts
test('tierFor table', () => {
  assert.equal(tierFor('studio', 5, true), 'studio');
  assert.equal(tierFor('individual', 3, false), 'individual');
  assert.equal(tierFor('individual', 2, true), 'individual');
  assert.equal(tierFor('individual', 3, true), 'artist');
  assert.equal(tierFor('artist', 3, false), 'individual'); // V1: revoked verification drops the tier
});
// award_use_cases.test.ts
test('support may review; finance gets staff_forbidden; no TOTP gets mfa_required', …);
test('approving the 3rd award of an unverified photographer keeps individual, of a verified one gives artist', …);
test('each action writes one audit_log row award.<action> with the note as reason and the status diff', …);
test('self-review is still permission_denied for a staff photographer', …);
// review_sla.test.ts  (Vietnam times written as +07:00)
test('Fri 17:00 → Tue 16:59 is < 72 business hours, → Wed 17:01 is > 72', …);
test('a Saturday submission counts from Monday 00:00', …);
test('businessCutoff(now, 72) is the instant awardWait turns late', …);
test('awardWait: 5 business hours → {hours, 5}; 50 → {days, 2}', …);
```

- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Update every `tierFor` and `reviewAward` caller in the domain and its tests, and the memory award store (`verified` in the tier state, a buffered `audit`).
- [ ] **Step 4: Run the domain checks; expect PASS.**
- [ ] **Step 5: Commit** `feat(domain): staff review actions, NAG waits for verification, business-day SLA [#164]`.

### Task A2: Award callable through `gate()`, tier backstop, CLI, seed and indexes (Functions)

**Files:**
- Modify:
  - `firebase/functions/src/callables/award.ts`, `callables/sensitive_file.ts`, `callables/verification.ts` (post-commit recompute only);
  - `src/infra/award_firestore.ts` (`TierState.verified` from `photographers/{uid}.verified`; `AwardTx.audit` through `bufferedAuditWriter`), `src/infra/live_award.ts`;
  - `src/triggers/photographer_write.ts` and its wiring in `src/index.ts`;
  - `tools/awards.ts`, `tools/verifications.ts` (post-commit recompute after approve/revoke);
  - `seed/fixtures.ts`, `seed/README.md`;
  - `firebase/firestore.indexes.json`.
- Test:
  - Functions unit: `test/unit/award_callables.test.ts`, `award_cli.test.ts`, `sensitive_file.test.ts`, `photographer_write.test.ts` (create if absent), `seed_fixtures.test.ts`;
  - integration: `test/integration/award.test.ts`.

**Interfaces:**
- Consumes: A1.
- Produces:
  - `handleReviewAward(request, deps: AwardDeps & StaffGate)`: `run('reviewAward', async () => reviewAward(deps, await gate(request, deps, 'award.review'), request.data))` (the `callables/money.ts` pattern). Same response `{status}`. Errors `staff_forbidden`, `mfa_required`, `unauthenticated` come from `gate`.
  - `KIND_ACTION`: `award_proof → 'award.view'`, `business_doc → 'verification.view'`.
  - `handlePhotographerWrite`: when `before?.verified !== after?.verified` and `after` exists, `await recomputeTier(awardDeps, uid)`. A failure is logged and not rethrown.
  - After `reviewVerification` commits a change that flips `verified`, the callable and the CLI call `recomputeTier` quietly (D3). Part B keeps this when it rewrites the callable.
  - `awards --actor <uid>` runs as `{uid, role: 'admin', mfa: true}`.
  - Indexes on `awards`: `(status ↑, updatedAt ↑)`, `(status ↑, reviewedAt ↑)` and `(status ↑, reviewedAt ↓)`.
  - Seed:
    - Giang (`seed-photographer-giang`, identity `submitted`, `verified: false`) gets `seed-award-giang-1`, `-2` (approved) and `-3` (pending, finalist, "Sony World Photography Awards", 2025, category "Kiến trúc", one link `https://worldphoto.org/…`). `approvedAwardCount: 2`.
    - Bình gets `seed-award-binh-2` (`needs_info`, with a review note) and `seed-award-binh-3` (`rejected`).
    - Dũng stays `artist` and `verified: true`.

- [ ] **Step 1: Write the failing tests**

```ts
// award_callables.test.ts
test('support reviews an award; finance gets staff_forbidden; no TOTP gets mfa_required', …);
test('reviewAward writes awardAudit and audit_log in one transaction', …);   // integration
// sensitive_file.test.ts
test('award_proof is allowed with award.view, business_doc with verification.view; sales is staff_forbidden', …);
// photographer_write.test.ts
test('verified false → true with 3 approved awards makes the photographer artist', …);
test('a write that leaves verified unchanged does not recompute', …);
// seed_fixtures.test.ts
test('Giang has 2 approved and 1 pending award and is not verified; Bình has needs_info and rejected awards', …);
```

- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Error codes need no change.
- [ ] **Step 4: Run the Functions checks; expect PASS.** Integration runs in CI.
- [ ] **Step 5: Commit** `feat(functions): staff-gated award review, tier recompute on verification [#164]`.

### Task A3: S23.07 Giải thưởng, the shared review pieces and the queue entries (dashboard)

**Files:**
- Create:
  - `apps/dashboard/src/app/(staff)/staff/awards/{page.tsx, AwardsScreen.client.tsx, Awards.module.css, actions.ts}`;
  - `src/server/read/awards.ts`, `src/server/read/firestore/awards.ts`;
  - `src/server/write/sensitive-file.ts`;
  - `src/lib/award-tabs.ts`, `src/lib/nag.ts`.
- Modify:
  - `src/components/DecisionDialog.client.tsx` (`reasonMode: 'optional'`);
  - `src/components/nav.ts`, `src/app/(staff)/staff/layout.tsx` (sum badges);
  - `src/server/read/firestore/overview.ts`, `src/server/read/firestore/db.ts` (`AWARDS`, `AWARD_PROOFS`, `AWARD_AUDIT`, `POSTS`);
  - `src/lib/{dto.ts, labels.ts, screen-codes.ts}`, `src/messages/vi.ts`;
  - `e2e/roles.spec.ts`.
- Test: `test/read/awards.test.ts`, `test/staff/AwardsScreen.test.tsx`, `test/lib/nag.test.ts`, `test/components/DecisionDialog.test.tsx`, `test/read/overview-review.test.ts`, `test/staff/StaffShell-review.test.tsx`

**Interfaces:**
- Consumes: A1 (`awardWait`, `businessCutoff`, actions), A2 (callables, indexes).
- Produces:
  - `type AwardTab = 'pending' | 'needs_info' | 'approved' | 'rejected'`; `award-tabs.ts` exports `AWARD_TABS`, `isAwardTab`, `parseAwardTab`, `tabOfAwardStatus`.
  - `AwardsReader`:
    - `page(tab, now, cursor?): Promise<PageDto<AwardRowDto>>`;
    - `counts(now): Promise<{pending: number; needs_info: number}>`;
    - `detail(awardId, now): Promise<AwardDetailDto | null>`.
    - Queries, 50 per page, follow D11.
  - DTOs:
    - `AwardRowDto { id; photographerId; photographerName: string|null; providerType: 'individual'|'artist'|'studio'; approvedCount: number; competition; year; category: string|null; result: AwardResult; status: AwardStatus; submittedAt: string; wait: {unit: 'hours'|'days'; value: number; late: boolean} }`. `submittedAt` is `updatedAt`; `approvedCount` and `providerType` come from `photographers/{uid}`, one read per distinct uid on the page.
    - `AwardDetailDto extends AwardRowDto { verified: boolean; workPost: {id; title: string|null; imageUrl: string|null} | null; files: string[]; links: {url: string; host: string}[]; reviewNote: string|null; reviewedBy: string|null; reviewedByName: string|null; reviewedAt: string|null; history: {action: string; note: string|null; actorName: string|null; at: string}[] }`.
      - `files` holds basenames of `awardProofs/{id}.files`.
      - `history` comes from `awardAudit` rows for this award, newest first.
  - `nag.ts`: `nagBanner(d: {providerType; approvedCount; verified; status: AwardStatus}): 'grants' | 'waits_verification' | null`. It returns non-null only for a `pending` award of a non-studio, non-artist photographer with `approvedCount + 1 >= 3`.
  - `sensitive-file.ts`: `requestSensitiveFileUrl(input: {kind: 'award_proof'|'business_doc'; entityId: string; file: string}): Promise<ActionResult<{url: string; expiresAt: string}>>`. It calls `requireStaff('award.view' | 'verification.view')`, then `runCallable('getSensitiveFileUrl', …)`.
  - `actions.ts`: `reviewAwardAction({awardId, action, note?})` with `requireStaff('award.review', '/staff/awards')`; `loadAwardsPage(tab, cursor)`, `loadAwardDetail(id)`.
  - Nav: in the `queues` group before `approvals`:
    - `verifications` (`nav.verifications` 'Xác minh', `verified_user`, `/staff/verifications`, action `verification.view`). It shows from Part A on, and the page 404s until B3. Hide it behind `NAV_HIDDEN = ['verifications']` until B3 removes the entry.
    - `awards` (`nav.awards` 'Giải thưởng', `emoji_events`, `/staff/awards`, action `award.view`).
  - Cards (`QueueCardSpec`, action as named):
    - `awards_pending` (`queue.awards_pending` 'Giải thưởng chờ duyệt', `award.view`): late = `updatedAt <= businessCutoff(now, 72)`.
    - `verifications_identity` ('Xác minh danh tính chờ duyệt') and `verifications_business` ('Doanh nghiệp chờ duyệt'), both `verification.view`, late after 24 h on the submitted field. They are added here with the B3 hrefs, behind the same hidden flag as the nav item.
    - `NAV_ID_OF_CARD` maps `awards_pending → awards` and both verification cards → `verifications`; `navBadges` sums `open` and ORs `late` for cards sharing a nav id.
  - `SCREEN_CODES.awards = 'S23.07'`, `SCREEN_CODES.verifications = 'S23.04'`. `entityHref('award', id)` → `/staff/awards?id=<id>`. `audit.action.award.{approve,needs_info,reject,revoke}` = 'Duyệt giải thưởng' · 'Yêu cầu bổ sung giải thưởng' · 'Từ chối giải thưởng' · 'Thu hồi giải thưởng'.
  - Screen copy (mock wins):
    - Title 'Giải thưởng'; subtitle 'Mục tiêu duyệt trong 3 ngày làm việc'.
    - Tabs Chờ duyệt · Cần bổ sung · Đã duyệt · Đã từ chối.
    - Columns Thợ · Cuộc thi · Kết quả · Chờ.
      - The Thợ sub-line is '{n} giải đã duyệt', or 'NAG · {n} giải' for an artist.
      - Chờ shows '{n} giờ' / '{n} ngày', red when `late`.
    - Results: Vàng · Bạc · Đồng · Khuyến khích · Chung khảo · Triển lãm.
    - Detail:
      - Title '{competition} {year}'; subtitle 'Hạng mục {category} · {result} · gửi {dd/MM}'.
      - Each file is a `SecureFileViewer` (`kind: 'award_proof'`, `entityId: '<photographerId>/<awardId>'`).
      - Each link reads 'Link {host} · mở tab mới', with `target="_blank" rel="noopener noreferrer"`.
      - The work post reads 'Bài dự thi "{title}" · ảnh công khai'.
      - NAG line: '{n}/3 giải đã duyệt' plus the verification state.
      - Banner `grants`: 'Duyệt giải này sẽ cấp hạng NAG'.
      - Banner `waits_verification`: 'Đủ điều kiện NAG, chờ xác minh danh tính' with 'Duyệt giải này là giải thứ 3. {name} chưa được duyệt xác minh (S21), hạng NAG sẽ tự cấp khi xác minh xong.'
      - Studios show no NAG line.
    - Footer by the award's own status:
      - `pending`: primary 'Duyệt', secondary 'Cần bổ sung…' and 'Từ chối…';
      - `approved`: 'Thu hồi…';
      - `needs_info` and `rejected`: none.
    - Dialogs:
      - Approve: `reasonMode: 'optional'`, title 'Duyệt giải {competition} {year} của {name}?', confirm 'Duyệt'.
      - Needs info: 'Gửi yêu cầu bổ sung cho {name}?', confirm 'Gửi yêu cầu'; the note goes to the photographer.
      - Reject: danger, 'Từ chối giải này?', confirm 'Từ chối'.
      - Revoke: danger, 'Thu hồi giải này?', confirm 'Thu hồi'. When the photographer is an artist with exactly 3 approved awards, the summary adds '{name} sẽ mất hạng NAG.'
    - Toasts: 'Đã duyệt giải' · 'Đã gửi yêu cầu bổ sung' · 'Đã từ chối giải' · 'Đã thu hồi giải'.
    - Empty: 'Không có giải nào chờ duyệt'.
  - The page passes `session.email` to `SecureFileViewer` as `viewerEmail`.

- [ ] **Step 1: Write the failing tests**

```ts
// awards.test.ts
test('each tab sends D11 where/orderBy and every query has a declared index', …);
test('row wait comes from updatedAt in business hours; late after 72', …);
test('detail lists file basenames and link hosts, history newest first, and is plain', …);
// nag.test.ts
test('nagBanner: verified + 2 approved → grants; unverified + 2 → waits_verification; 1 approved → null; studio → null; artist → null; needs_info → null', …);
// AwardsScreen.test.tsx
test('pending footer has one primary Duyệt; approved has Thu hồi…; rejected has none', …);
test('approve sends no note when the optional reason is empty', …);
test('needs_info and reject keep Confirm disabled under 5 characters', …);
test('proof link has target _blank and rel noopener noreferrer and shows the host', …);
test('waits_verification banner text names the photographer', …);
// DecisionDialog.test.tsx
test('reasonMode optional enables Confirm with an empty reason and still caps at 500', …);
// overview-review.test.ts
test('support sees awards_pending; finance and sales do not; late uses businessCutoff', …);
// StaffShell-review.test.tsx
test('support menu: Tổng quan, Giải thưởng, Chờ duyệt (Xác minh hidden until Part B)', …);
test('two cards on one nav id sum into one badge', …);
```

- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** `e2e/roles.spec.ts`:
  - support menu: `[overview, awards, approvals]`;
  - admin menu: adds `awards`.

  New copy goes in the ledger's "chữ mới" table.
- [ ] **Step 4: Run the dashboard checks; expect PASS.**
- [ ] **Step 5: Commit** `feat(dashboard): S23.07 award review queue [#164]`.

### Task A4: S25.01 "eligible, verify to become NAG" (app, this repository)

**Files:**
- Modify:
  - `app_flutter/lib/data/award/award.dart` (`AwardTier.verified`);
  - `app_flutter/lib/data/award/firestore_award_repository.dart` (read `verified` from `photographers/{uid}`);
  - `app_flutter/lib/data/award/award_repository.dart` (fake);
  - `app_flutter/lib/features/awards/my_awards_screen.dart` (`_TierCard`);
  - `app_flutter/lib/l10n/app_vi.arb` (+ `flutter gen-l10n`);
  - `docs/design/ui-mock.html#S25.01` (one extra card state).
- Test: `app_flutter/test/features/awards/my_awards_screen_test.dart`

**Interfaces:**
- Produces:
  - `AwardTier({providerType, approvedCount, artistSince, verified = false})`, with `verified` in `==` and `hashCode`.
  - When the photographer is not a studio, not an artist, has `approvedCount >= kAwardTierThreshold` and `!verified`, the card sub-line is `s2501EligibleVerify` 'Đủ 3 giải · xác minh danh tính để lên Nhiếp ảnh gia'. Below the bar is a secondary button `s2501VerifyNow` 'Xác minh ngay' → `context.push(verifyStartPath)`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('3 approved, not verified: eligible line and Xác minh ngay opens verifyStartPath', …);
testWidgets('3 approved and verified but tier not yet artist: no button, remaining 0 line', …);
testWidgets('studio still shows no tier card', …);
```

- [ ] **Step 2: Run them and see them fail** (`flutter test test/features/awards`).
- [ ] **Step 3: Implement.** Imports `package:photobooking/...` and `core/core.dart`; tokens through `AppSpace`; strings only in `app_vi.arb`.
- [ ] **Step 4: Run `flutter analyze && flutter test test/features/awards`; expect PASS.**
- [ ] **Step 5: Commit** here `feat(awards): S25.01 asks an eligible photographer to verify [#164]`.

### Task A5: Playwright and docs (Part A)

**Files:**
- Create: `apps/dashboard/e2e/awards.spec.ts`
- In this repository:
  - `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §2.3: replace the line "S23.07 yêu cầu staff xác minh danh tính cùng lúc" with V1;
  - `docs/superpowers/specs/data-model/domain-model.md`: `TierState.verified`, the `tierFor` rule;
  - `docs/superpowers/specs/screens/staff-verification-awards.md` §3: "✅ đã làm (#164)", with a "Đã làm" note;
  - `docs/superpowers/specs/2026-10-01-remaining-screens.md`: S23.07 Trạng thái;
  - new `docs/superpowers/handover/ledger-164-verification-awards-a.md`.

- [ ] **Step 1: Write `awards.spec.ts`** (serial, retries 0):

```ts
test('support approves Giang\'s third award: banner says chờ xác minh, photographer stays individual', …);
test('support asks Bình for more information on seed-award-binh-1 with a note', …);
test('admin revokes seed-award-dung-3: Dũng drops to individual', …);
test('finance typing /staff/awards gets the 403 page', …);
```

- [ ] **Step 2: Run it on the emulators** (scratchpad `e2e-*.sh` pattern from #343, sandbox off); expect PASS together with the existing specs.
- [ ] **Step 3: Update the docs.** The ledger lists D1–D6, D11, D12, D14 and D15 as rulings, the new copy, and the deferred items.
- [ ] **Step 4: Commit** in booking-be `test(dashboard): award review end-to-end [#164]` and here `docs(awards): NAG waits for verification, S23.07 ledger [#164]`.

---

# Part B · S23.04 Xác minh

### Task B1: Verification review with a staff caller, the audited detail and reinstatement (domain)

**Files:**
- Modify: `packages/domain/src/verification_ports.ts`, `verification_use_cases.ts`, `verification.ts`, `memory_verification_store.ts`, `index.ts`
- Create: `packages/domain/src/verification_review.ts`, `packages/domain/src/verification_reinstate.ts`
- Test: `packages/domain/test/verification_review.test.ts`, `verification_reinstate.test.ts`, `verification_staff.test.ts`

**Interfaces:**
- Consumes: A1 (actions, `APPROVAL_KINDS.verification_reinstate`, `tierFor`), #163 (`requestApproval`, `ApprovalKindSpec.execute`, `approvalDiffOf`, `STALE_CODES`).
- Produces:
  - `REVOKE_NOTE_MIN = 20` in `verification.ts`.
  - `VerificationTx` gains `readonly audit: AuditWriter`.
  - `reviewVerification(deps: VerificationDeps, caller: StaffCaller, raw: unknown): Promise<VerificationChange>`:
    - the action check is D6;
    - a revoke note shorter than 20 is `invalid_argument`;
    - besides `verificationAudit`, it writes `audit_log` with `entityType: 'verification'`, `entityId: uid`, `reason: note`, and `diff: {status: [before, after]}` (business: `{'business.status': [...]}`).
    - The `audit_log` actions are:
      - `verification.approve`, `verification.reject`, `verification.revoke` for identity;
      - `verification.business_approve`, `verification.business_reject` for business.
  - `VerificationReviewReader`, read-only:

    ```ts
    verification(uid): Promise<VerificationRecord | null>;
    identity(uid): Promise<IdentityRecord | null>;
    auditOf(uid, limit): Promise<VerificationAuditEntry[]>; // rows with uid or otherUid == uid, newest first
    statuses(uids): Promise<Record<string, VerificationStatus>>;
    ```
  - `verificationForReview(deps: {reader: VerificationReviewReader; audit: AuditLog; clock: Clock}, caller: StaffCaller, raw: unknown): Promise<VerificationReviewDto>`:
    - `assertStaffCaller(caller, 'verification.view')`, input `{uid}`;
    - `not_found` when there is no record;
    - writes `audit_log` `{action: 'verification.view', entityType: 'verification', entityId: uid, reason: null, diff: null}` **before** returning (D5).
  - The DTO, plain:

    ```ts
    VerificationReviewDto {
      uid; kind; status; submittedAt: string|null; decidedAt: string|null; decidedBy: string|null;
      attempt: number;                       // 1 + earlier identity 'reject' rows
      freeResubmitsLeft: number;
      identity: { legalName; dob; ageYears: number; gender; idLast4: string|null; method; passed: boolean } | null;
      steps: { phone: boolean; feePaymentId: string|null; feeAmount: number|null; rulesVersion: string|null };
      duplicates: { uid: string; status: VerificationStatus }[];                  // D8
      business: { subject; kind; status; taxCode; name; address; registryStatus; docFile: string|null;
                  representativeMatched: boolean; submittedAt: string } | null;   // docFile = basename of docPath
      history: { action: string; reason: string|null; note: string|null; actorId: string|null; at: string }[];
    }
    ```

    `passed` is `steps.identity?.result === 'passed'`.
  - `requestVerificationReinstate(deps: {approvals: ApprovalDeps; verification: VerificationDeps}, caller: StaffCaller, raw: unknown): Promise<{status: 'awaiting_second_approval'; approvalId: string}>`:
    - input `{uid, reason}`;
    - `assertStaffCaller(caller, 'verification.reinstate.request')`;
    - the record must be `revoked`, else `conflict`;
    - then `requestApproval({kind: 'verification_reinstate', entityType: 'verification', entityId: uid, params: {uid}, reason})`.
  - `verificationApprovalKinds(deps: VerificationDeps, notify: NotifyDeps): Pick<ApprovalKinds, 'verification_reinstate'>`. It spreads the metadata row and adds `execute(approver, {uid}, ref)`, which in one verification transaction:
    - requires `revoked`, else `conflict`;
    - sets `approved`, `decidedAt`, `decidedBy: approver.uid`;
    - `setProviderFlags({verified: true, verifiedAt: now, acceptingOrders: acceptsOrders(…)})`;
    - writes a `verificationAudit` row with `action: 'reinstate'`, `note: ref.reason`;
    - writes `audit_log` `verification.reinstate` with `diff: {status: ['revoked','approved'], ...approvalDiffOf(ref, approver.uid)}`.

    After commit, `notifyVerificationChange`. Tier recompute is the Functions side (D3).
  - `VerificationAuditEntry.action` gains `'reinstate'`.

- [ ] **Step 1: Write the failing tests**

```ts
// verification_staff.test.ts
test('support approves; finance gets staff_forbidden; revoke needs verification.revoke', …);
test('revoke with a 19-character note is invalid_argument, 20 passes', …);
test('approve after approve → conflict', …);
test('each decision writes verificationAudit and one audit_log row with the status diff', …);
// verification_review.test.ts
test('review DTO has no idNumberEnc, idHash or 9+ digit run', () => {
  const s = JSON.stringify(dto); assert.ok(!/idNumberEnc|idHash|\d{9,}/.test(s)); assert.equal(dto.identity?.idLast4, '4821');
});
test('writes verification.view before returning; audit failure → throws and returns nothing', …);
test('duplicates come from duplicate audit rows in either direction, with each account status', …);
test('attempt counts earlier rejects; ageYears from dob in Vietnam time', …);
// verification_reinstate.test.ts
test('support cannot propose; admin proposes only from revoked', …);
test('the proposer approving is same_person; finance approving is staff_forbidden; support approves', …);
test('execute sets approved, verified, acceptingOrders, audit diff has requestedBy and approvedBy', …);
test('approving after another reinstatement closes the request stale with no second write', …);
```

- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** The memory verification store gains the reader and a buffered `audit`.
- [ ] **Step 4: Run the domain checks; expect PASS.**
- [ ] **Step 5: Commit** `feat(domain): staff verification review, audited detail and reinstatement [Part B issue]`.

### Task B2: Verification callables, adapters, CLI, seed and indexes (Functions)

**Files:**
- Modify:
  - `firebase/functions/src/callables/verification.ts`;
  - `src/infra/verification_firestore.ts` (`audit`, `FirestoreVerificationReviewReader`), `src/infra/live_verification.ts`, `src/infra/live_staff.ts` (approval kinds), `src/index.ts`;
  - `tools/verifications.ts`;
  - `seed/fixtures.ts`, `seed/README.md`;
  - `firebase/firestore.indexes.json`.
- Test:
  - Functions unit: `test/unit/verification_callables.test.ts`, `verifications_cli.test.ts`, `verification_firestore.test.ts`, `staff_callables.test.ts`, `seed_fixtures.test.ts`;
  - integration: `test/integration/verification.test.ts`.

**Interfaces:**
- Consumes: B1, A2 (post-commit recompute).
- Produces:
  - `handleReviewVerification(request, deps)`: `reviewVerification(deps, await gate(request, deps, null), request.data)` inside `run`. The use case checks the specific action. Notify and recompute run after commit; the response is `{status}` as today.
  - `getVerificationForReview` callable: `verificationForReview(deps, await gate(request, deps, 'verification.view'), request.data)`.
  - `requestVerificationReinstate` callable: `await gate(request, deps, 'verification.reinstate.request')` then `requestVerificationReinstate`. Use `PAYMENT_CALLABLE_OPTIONS` only if the approvals callables do; otherwise `CALLABLE_OPTIONS`.
  - `liveApprovalDeps().kinds` spreads `verificationApprovalKinds(liveVerificationDeps(env), notify)`. The tier recompute after `execute` is wrapped in the Functions factory (`execute` then `recomputeTier` quietly).
  - `FirestoreVerificationReviewReader.auditOf` runs two queries on `verificationAudit`, `(uid ==, at ↓)` and `(otherUid ==, at ↓)`, merged and de-duplicated.
  - Indexes:
    - `verificationAudit`: `(uid ↑, at ↓)`, `(otherUid ↑, at ↓)`;
    - `verifications`: `(status ↑, decidedAt ↓)`.
  - CLI `verifications` runs as `cli:<user>` admin (D6) and gains `reinstate <uid> "lý do"`, which only opens the request.
  - Seed:
    - Cúc (`CUC`, studio) gets `business` `submitted`: company, tax code `0312345678`, 'CÔNG TY TNHH STUDIO CÚC', an address, `registryStatus: 'active'`, `docPath: 'businessDocs/<CUC>/seed-business.jpg'`, `representativeMatched: true`. A small JPEG is uploaded to the Storage emulator at that path, if the seed writes Storage; otherwise the viewer shows its error state and the README says so.
    - New `seed-photographer-khanh` ('Khánh', TP.HCM, individual) is `revoked` by `seed-staff-admin`, with a `verificationAudit` revoke row (note ≥ 20 characters) and `verified: false`.
    - Giang's identity doc has `idLast4: '4821'`.
    - A `duplicate` audit row links Giang to Khánh.

- [ ] **Step 1: Write the failing tests**

```ts
// verification_callables.test.ts
test('support approves Giang; sales gets staff_forbidden; no TOTP gets mfa_required', …);
test('getVerificationForReview returns idLast4 and writes one verification.view row', …);
test('requestVerificationReinstate by support is staff_forbidden; by admin opens a staff_approvals row', …);
test('decideStaffApproval on verification_reinstate by support reinstates Khánh and recomputes the tier', …);
// verifications_cli.test.ts
test('revoke with a short note prints the 20-character rule; reinstate opens a request', …);
```

- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the Functions checks; expect PASS.** Integration runs in CI.
- [ ] **Step 5: Commit** `feat(functions): staff verification callables and reinstatement [Part B issue]`.

### Task B3: S23.04 Xác minh (dashboard)

**Files:**
- Create:
  - `apps/dashboard/src/app/(staff)/staff/verifications/{page.tsx, VerificationsScreen.client.tsx, Verifications.module.css, actions.ts}`;
  - `src/server/read/verifications.ts`, `src/server/read/firestore/verifications.ts`;
  - `src/lib/verification-tabs.ts`, `src/lib/id-resolvers.staff.ts`.
- Modify:
  - `src/components/nav.ts` (drop `NAV_HIDDEN`), `src/server/read/firestore/overview.ts` (unhide the cards);
  - `src/components/ShellFrame.client.tsx` (import the resolver module);
  - `src/server/read/firestore/approval-details.ts`, `src/app/(staff)/staff/approvals/ApprovalsQueue.client.tsx` (the `verification_reinstate` detail);
  - `src/lib/{dto.ts, labels.ts}`, `src/messages/vi.ts`;
  - `e2e/roles.spec.ts`.
- Test: `test/read/verifications.test.ts`, `test/staff/VerificationsScreen.test.tsx`, `test/lib/id-resolvers.test.ts`, `test/read/approvals.test.ts`

**Interfaces:**
- Consumes: B2 callables; A3 pieces (`requestSensitiveFileUrl`, `Tabs`, cards).
- Produces:
  - `type VerificationTab = 'identity' | 'business' | 'approved' | 'revoked' | 'history'`. `verification-tabs.ts` exports `VERIFICATION_TABS`, `parseVerificationTab`, `tabOfVerification(dto)`:
    - identity `submitted` → `identity`;
    - business `submitted` → `business`;
    - `approved` → `approved`;
    - `revoked` → `revoked`;
    - else `history`.
  - `VerificationsReader`:
    - `page(tab, now, cursor?, q?)`, with `q` used by `approved` only (D9);
    - `counts(now): {identity; business; revoked}`;
    - `profile(uid): Promise<VerificationProfileDto | null>` (public data only);
    - `activeBookings(uid): Promise<number>` (D10).
    - Queries, 50 per page:
      - `identity`: `status == 'submitted'` by `submittedAt` ↑;
      - `business`: `business.status == 'submitted'` by `business.submittedAt` ↑;
      - `approved` and `revoked`: `status ==`, by `decidedAt` ↓;
      - `history`: `verificationAudit` `at >= now − 30 d`, by `at` ↓, keeping `approve|reject|revoke|reinstate`.
      - Revoked rows take their reason from the uid's latest `revoke` audit row. A pending `verification_reinstate` request (one `staff_approvals` query) sets `awaitingApproval`.
  - DTOs:
    - `VerificationRowDto { uid; displayName: string|null; providerType; city: string|null; submittedAt: string|null; decidedAt: string|null; decidedByName: string|null; attempt: number; flags: ('duplicate'|'late')[]; lateHours: number; business: {taxCode; name} | null; revokeNote: string|null; awaitingApproval: boolean }`;
    - `VerificationProfileDto { avatarUrl: string|null; displayName; city; bio: string|null; createdAt: string; posts: {id; imageUrl}[] }`, with the 6 newest public posts;
    - `VerificationHistoryRowDto { uid; displayName; action; reason; note; actorName; at }`.
  - `actions.ts`, each `requireStaff(...)` then `runCallable`:
    - `loadVerificationDetail(uid)` → `getVerificationForReview` (`verification.view`);
    - `reviewVerificationAction({uid, target, action, reason?, note})` (`verification.review`, or `verification.revoke` for revoke);
    - `requestReinstateAction({uid, reason})` (`verification.reinstate.request`);
    - `loadVerificationsPage(tab, cursor, q?)`, `loadVerificationProfile(uid)`, `loadActiveBookings(uid)`.
  - The page reads `?tab=` and `?uid=`. `?uid=` opens that detail and, without `?tab=`, picks the tab with `tabOfVerification`. `id-resolvers.staff.ts` registers the D13 resolver.
  - `approval.kind.verification_reinstate` 'Khôi phục xác minh'. `entityHref('verification', uid)` → `/staff/verifications?uid=<uid>`. The approval detail shows the photographer's name and the revoke note.
  - `audit.action.verification.{view,approve,reject,revoke,reinstate,business_approve,business_reject}`: 'Xem hồ sơ xác minh' · 'Duyệt xác minh' · 'Từ chối xác minh' · 'Thu hồi xác minh' · 'Khôi phục xác minh' · 'Duyệt doanh nghiệp' · 'Từ chối doanh nghiệp'.
  - Screen copy (mock wins):
    - Title 'Xác minh'; subtitle 'Duyệt trong 24 giờ · không bao giờ tự duyệt'.
    - Tabs Danh tính · Doanh nghiệp · Đã duyệt · Đã thu hồi · Lịch sử.
    - Identity columns Thợ · Gửi lúc · Lần · Cờ. The Thợ sub-line is '{loại} · {khu vực}'. Chips: 'Trùng tài khoản' (red) and 'Quá {n} giờ'.
    - Identity detail:
      - Subtitle 'Gửi {dd/MM/yyyy HH:mm} · lần {n} · mở chi tiết được ghi vào nhật ký'.
      - Fields:
        - 'Họ tên trên giấy tờ';
        - 'Ngày sinh' ('{dd/MM/yyyy} · {n} tuổi');
        - 'Giới tính';
        - 'Số định danh' ('•••• {last4}');
        - 'Cách xác minh' ('VNeID · Đạt' / 'Chip CCCD · Không đạt');
        - 'Trùng tài khoản': 'Không có', or links to each account with its status;
        - 'Các bước': 'Điện thoại ✓ · Phí {amount} ✓ · Quy định {version} ✓'.
      - Public profile: avatar, 6 posts, bio, 'tài khoản tạo {date}'.
      - Earlier rejections with reason, note and decider; '{n} lần gửi lại miễn phí còn lại'.
      - When the display name and the legal name differ, both are shown side by side, with no automatic comparison (spec Q2).
    - Footer by status:
      - `submitted`: primary 'Duyệt', secondary 'Từ chối…';
      - approved: 'Thu hồi xác minh…';
      - revoked: admin 'Khôi phục…', support no button;
      - history: none.
    - Dialogs:
      - Approve: 'Cho {name} nhận đơn?', confirm 'Duyệt'. Adds 'Hạng NAG sẽ được cấp cùng lúc' when the photographer has ≥ 3 approved awards and is not a studio.
      - Reject: 'Từ chối xác minh?', danger, confirm 'Từ chối'.
        - Summary: '{name} sẽ nhận thông báo kèm lý do và còn {n} lần gửi lại miễn phí.'
        - The reason radio group is in mock order: Ảnh đại diện giả · Portfolio của người khác · Không khớp danh tính · Trùng tài khoản · Chưa đủ 18 tuổi · Khác.
        - Hint: 'Trùng tài khoản và Chưa đủ 18 tuổi là từ chối hẳn, không gửi lại được.'
        - With `duplicate_account` or `underage` selected, the summary instead says '{name} sẽ bị từ chối hẳn, không gửi lại được.'
        - Reason label: 'Ghi chú (5–500 ký tự, ghi vào nhật ký)'.
        - Confirm stays disabled until a reason is chosen.
      - Business reject reasons: Ngừng hoạt động · Người đại diện không khớp · Ảnh không đọc được · Khác.
      - Revoke: 'Thu hồi xác minh của {name}?', danger, `minLength={20}`, confirm 'Thu hồi'. Summary: '{n} booking đang chạy không bị huỷ; xử lý qua khiếu nại nếu cần.'
      - Reinstate: 'Khôi phục xác minh cho {name}?', confirm 'Gửi duyệt lần hai'. Summary: 'Một staff khác (admin hoặc support) phải duyệt trong 24 giờ.' The row then shows the chip 'Chờ duyệt lần hai'.
    - Business detail:
      - fields Mã số thuế, Tên doanh nghiệp, Địa chỉ, Tình trạng ('Đang hoạt động' / 'Ngừng hoạt động'), Loại ('Công ty');
      - 'Họ tên chủ studio đã xác minh' (from the DTO identity);
      - `SecureFileViewer` (`kind: 'business_doc'`, `entityId: uid`, `file: docFile`).
    - Stale (Review Focus 2): a decision that answers `conflict` reloads the detail. If its status changed, a banner reads 'Hồ sơ này vừa được {name} xử lý' and the footer follows the new status.
    - Empty: 'Không có hồ sơ nào chờ duyệt'.
    - Toasts: 'Đã duyệt xác minh' · 'Đã từ chối' · 'Đã thu hồi xác minh' · 'Đã gửi duyệt lần hai'.

- [ ] **Step 1: Write the failing tests**

```ts
// verifications.test.ts
test('each tab sends its where/orderBy and every query has a declared index', …);
test('approved search: a uid reads one document; a name prefix ranges nameKey and keeps approved only', …);
test('revoked rows carry the latest revoke note and awaitingApproval from one staff_approvals query', …);
test('history keeps approve/reject/revoke/reinstate rows of the last 30 days', …);
test('activeBookings counts photographerId with status not-in CLOSED_BOOKING_STATUSES', …);
// VerificationsScreen.test.tsx
test('identity detail shows •••• 4821 and never more digits', …);
test('reject: Confirm disabled until a reason is chosen; duplicate_account says từ chối hẳn', …);
test('revoke keeps Confirm disabled at 19 characters and names the active booking count', …);
test('support sees no Khôi phục… on a revoked row; admin does', …);
test('conflict reloads the detail and shows the stale banner with the decider name', …);
// id-resolvers.test.ts
test('a 28-char uid and seed-photographer-giang resolve to /staff/verifications?uid=…; PB-7K2MQ8 does not', …);
// approvals.test.ts
test('verification_reinstate detail shows the name and revoke note; entityHref links to S23.04', …);
```

- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** `e2e/roles.spec.ts`:
  - support menu: `[overview, verifications, awards, approvals]`;
  - admin menu: adds `verifications`.
- [ ] **Step 4: Run the dashboard checks; expect PASS.**
- [ ] **Step 5: Commit** `feat(dashboard): S23.04 verification review queue [Part B issue]`.

### Task B4: Playwright and docs (Part B)

**Files:**
- Create: `apps/dashboard/e2e/verifications.spec.ts`
- In this repository:
  - `docs/superpowers/specs/2026-10-06-identity-verification-design.md` §4 and question 7: reinstatement (V2) replaces "thu hồi là cuối";
  - `docs/superpowers/specs/data-model/domain-model.md`: `revoked → approved` through `verification_reinstate`, and the `reinstate` audit action;
  - `docs/superpowers/specs/data-model/relational-schema.md`: the new indexes as needed;
  - `docs/superpowers/specs/screens/staff-verification-awards.md` §2: "✅ đã làm", with a "Đã làm" note;
  - `docs/superpowers/specs/2026-10-01-remaining-screens.md`: S23.04 Trạng thái;
  - new `docs/superpowers/handover/ledger-164-verification-awards-b.md`.

- [ ] **Step 1: Write `verifications.spec.ts`** (serial, retries 0):

```ts
test('support opens Giang: •••• 4821, the duplicate link to Khánh, and one verification.view row on S23.11', …);
test('support approves Giang; with her third award approved in awards.spec she becomes artist', …);
test('admin proposes reinstating Khánh; support approves on /staff/approvals; Khánh is approved', …);
test('support rejects Cúc\'s business with Ảnh không đọc được', …);
test('finance typing /staff/verifications gets the 403 page', …);
```

  The second case depends on `awards.spec.ts` running first; Playwright runs spec files alphabetically. If the run order differs, approve the award in this spec instead.
- [ ] **Step 2: Run it on the emulators; expect PASS** with the whole suite.
- [ ] **Step 3: Update the docs.** The ledger lists D5–D10 and D13 as rulings, the new copy, and the deferred items.
- [ ] **Step 4: Commit** in booking-be `test(dashboard): verification review end-to-end [Part B issue]` and here `docs(verification): reinstatement and S23.04 ledger [Part B issue]`.
