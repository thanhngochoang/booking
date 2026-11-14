# Phase 1.5 · Dashboard foundation (#162) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Code goes to **booking-be**; Task 13 (docs) goes to this repository. Both use the branch `plan/162-dashboard-foundation`; the booking-be PR lands first (`land.py 162 --pr <n> --repo thanhngochoang/booking-be`), then the docs PR here.

**Goal:** Staff and studio owners can sign in to a Next.js dashboard in booking-be `apps/dashboard/`. Staff pass a TOTP second factor. Admins grant, change and revoke staff roles and reset a lost second factor. Every staff decision lands in one `audit_log`. Two-person approvals and private-file viewing exist as shared mechanisms for the later tickets. The S23.08–S23.11 and S23.15 screens work against the emulators.

**Architecture:** As in the spec. The browser talks only to the Next.js server (BFF). The BFF **reads** Firestore through per-screen reader interfaces backed by the Admin SDK, and **writes** only by calling Cloud Functions callables with the signed-in user's own ID token. Every rule (roles × actions, reason length, approval lifecycle, last-admin guard) is a pure function in `packages/domain`. Functions and the BFF both import it through the `tsconfig` `paths` alias. Callables re-check permissions themselves and never trust the BFF.

**Tech Stack:** Next.js 16 (App Router, TypeScript strict, React 19), Firebase JS SDK (`firebase/app`, `firebase/auth` only), `firebase-admin` (server only), Vitest + React Testing Library, Playwright; Cloud Functions v2 `onCall` (region `asia-southeast1`), `node:test` for domain and Functions; Firestore/Storage rules with `@firebase/rules-unit-testing`.

**Spec:** `docs/superpowers/specs/2026-10-08-dashboard-web-design.md` (D1–D11, §2–§10, §13). Mock: `docs/design/dashboard-mock.html` (`#S23.08`–`#S23.11`, studio shell). **Issue:** #162 (epic #83). Booking-be layout and conventions: its `AGENTS.md`.

## Global Constraints

- **Browser never touches Firestore or Storage** (D2). Client code may import only `firebase/app` and `firebase/auth`. `firebase-admin`, `server-only` and `src/server/**` are importable only from `src/server/**`, server components, server actions and route handlers (spec §2.6). This is enforced by ESLint `no-restricted-imports` and by a purity test.
- **Writes only through callables** with the user's ID token from the `__session` cookie. The BFF never writes Firestore.
- **Roles:** `staffRole ∈ {admin, finance, support, sales}`, one value per account. The source of truth is `staff_members/{uid}` `{role, grantedBy, grantedAt, updatedAt}`; the custom claim is a copy, written in the same callable. At least one `admin` always remains (`last_admin`).
- **TOTP:** every staff route and every staff callable requires `firebase.sign_in_second_factor === 'totp'` in the token. `MFA_DEV_BYPASS=1` only has effect when the BFF runs with `USE_EMULATORS=1` and Functions run in the emulator (`FUNCTIONS_EMULATOR=true`). Everywhere else it is ignored, and a warning is logged once.
- **Sessions:** cookie `__session` (httpOnly, Secure except on `http://localhost`, SameSite=Strict, `Max-Age` = remaining token life); `verifyIdToken(token, true)` on every request. Staff: re-login when `auth_time` is older than 12 h; client logs out after 30 min idle with a 60 s warning. Studio owner: plain Firebase session.
- **Audit:** every staff decision writes **exactly one** `audit_log/{ulid}` row `{actorId, actorRole, action, entityType, entityId, reason, diff, at}` in the same transaction as the decision. The row never contains an account number, an ID-document number or a phone number. Rows are never deleted. Clients can neither read nor write it.
- **Reasons:** 5–500 characters after trim, wherever a reason is required.
- **No realtime listeners.** Queues refresh every 30 s while the tab is visible, S23.09 every 60 s, and immediately after each write (`router.refresh()`).
- **Text:** all visible strings in `src/messages/vi.ts`, keyed `s23_09.title` / `common.retry`. ESLint `react/jsx-no-literals` is on for `src/app` and `src/components`.
- **Theme:** dark aurora by default, plus light; 60-30-10 (violet only for primary button, selected item, link, focus); icons Material Symbols Rounded; fonts Be Vietnam Pro and Fraunces. `styles/tokens.css` is generated from the pinned snapshot `design-tokens/tokens.json` and never edited by hand.
- **One primary action per screen.** Reject, cancel, revoke and reset are red buttons inside a `DecisionDialog`, never the gradient button.
- **Data on the wire to the browser** follows `data-model/README.md`: string ids, integer VND, ISO UTC strings, string enum codes. No `Timestamp` or `DocumentReference` reaches the browser.
- **Blaze switch:** nothing in this plan deploys unless `vars.FIREBASE_PROJECT_ID != ''` and `vars.BLAZE_ENABLED == 'true'`.
- **New domain error codes:** `staff_forbidden`, `mfa_required`, `last_admin`, `approval_pending`, `same_person`. Each one needs a row in `packages/domain/src/errors.ts` `ERROR_CODES`, in `firebase/functions/src/callables/errors.ts` `TRANSPORT_CODE`, in the root `src/errors.ts` `HTTP_STATUS`, and in the `expected` map of `firebase/functions/test/unit/errors.test.ts`.
- **Commits:** Conventional Commits, subject ends with `[#162]`. The booking-be PR body says `thanhngochoang/booking#162`.
- **Tests:**
  - Domain: `cd packages/domain && npm run typecheck && npm run lint && npm test`.
  - Functions: `cd firebase/functions && npm run lint && npm run typecheck && npm test`. Integration (`npm run test:integration`) and rules (`firebase/rules-test`) are written and run by CI; run them locally only outside the Claude sandbox.
  - Dashboard: `cd apps/dashboard && npm run lint && npm run typecheck && npm test && npm run build`; Playwright runs in CI.

## Review Focus

1. **A staff token without the second factor.** A stolen first-factor session (or one from before TOTP enrolment) is refused by the BFF *and* by every staff callable called directly. It is not merely hidden in the menu. Pinned in Task 4 (`assertStaff refuses a token without totp`), Task 9 (`getSession: staff without second factor goes to the TOTP step`) and Task 12 (Playwright `direct callable call without totp is refused`).
2. **Revocation takes effect on the next request.** After `setStaffRole(uid, null)` or a role change, the same browser session gets 403 on its next page load and on its next callable, without waiting for token expiry. Pinned in Task 2 (`setStaffRole` revokes sessions after the claim), Task 4 (integration: the old token is refused), Task 9 (`getSession`: revoked token is 401) and Task 12 (Playwright `revoked staff loses access at once`).
3. **The last admin cannot lock everyone out.** The last admin cannot demote or remove themselves or be demoted, two admins demoting each other at the same moment still leave one, and resetting the last admin's MFA does not remove the role. Pinned in Task 2 (`last_admin`, both orders; `countAdmins` is read inside the transaction) and Task 4 (integration).
4. **A route or callable guessed by URL.** A finance user typing `/staff/team` or `/staff/audit`, a sales user calling `getSensitiveFileUrl`, or a studio owner typing `/staff` gets a 403 page or `permission-denied`, with no data in the response. Pinned in Task 9 (guard table test), Task 5 (`getSensitiveFileUrl` kind × role table) and Task 12.
5. **A double click or a retried request.** Submitting "Cấp quyền" twice, or approving an approval twice, writes one `staff_members` change, one approval decision and one audit row. Pinned in Task 2 (`decideApproval` twice → the second is `conflict`; `setStaffRole` with an unchanged role is a no-op without an audit row) and Task 8 (`DecisionDialog` calls `onConfirm` once on a double click).

## File structure (booking-be)

```
packages/domain/src/
  staff_permissions.ts   STAFF_ROLES, StaffRole, StaffAction, staffMay, isStaffRole
  audit.ts               AuditEntry, AuditWriter, validateReason, AUDIT_REASON_MIN/MAX
  staff_members.ts       StaffMember, ports, setStaffRole, resetStaffMfa, findUserForStaff use cases
  staff_approvals.ts     StaffApproval, ApprovalKind registry (empty), request/decide/cancel/expire use cases
  memory_staff_store.ts  in-memory adapters for tests
  payout_use_cases.ts    StaffActor {uid, role}; payout checks through staffMay
firebase/functions/
  src/callables/staff.ts               assertStaff, mfaBypassActive, the five staff callables
  src/callables/sensitive_file.ts      getSensitiveFileUrl
  src/infra/audit_firestore.ts         AuditWriter adapter
  src/infra/staff_firestore.ts         staff_members + Auth (claims, revoke, MFA) adapter
  src/infra/approvals_firestore.ts     staff_approvals adapter
  src/infra/signed_url.ts              FileSigner port + Storage / emulator adapters
  src/infra/live_staff.ts              wiring
  tools/staff.ts                       npm run staff -- list | set-role | reset-mfa
apps/dashboard/                        (layout of spec §2.1)
.github/workflows/dashboard.yml
```

---

### Task 0: Two checks on the emulators (no product code)

The answers decide the code paths of Tasks 4, 9 and 12 (spec Q3, Q4). Run them outside the Claude sandbox with `scripts/backend-local.sh --fresh` running.

- [ ] **Step 1: TOTP on the Auth emulator.** In a throwaway Node script, using the Firebase JS SDK against `http://127.0.0.1:9099`:
  1. sign in `admin.staff@seed.test`;
  2. call `multiFactor(user).getSession()` and `TotpMultiFactorGenerator.generateSecret(session)`;
  3. compute a code from the secret with RFC 6238 (`otpauth` npm package in the script only);
  4. call `multiFactor(user).enroll(...)`;
  5. sign out, sign in again and expect `auth/multi-factor-auth-required`;
  6. resolve with a fresh code;
  7. decode the new ID token and check that `firebase.sign_in_second_factor === 'totp'`.
- [ ] **Step 2: Record the result** in the booking-be handover log (`handoff.py note`) and in the PR body:
  - **"TOTP works on the emulator":** Task 9 implements enrolment and verification for real on the emulator, and Playwright (Task 12) enrols with a generated secret. `MFA_DEV_BYPASS` stays as the guarded fallback but is off in CI.
  - **"Does not work":** Task 9 still ships the TOTP screens (they need Identity Platform, i.e. Blaze, to run for real), and local runs and Playwright use `MFA_DEV_BYPASS=1`.
- [ ] **Step 3: Callable URL.** Check that `http://127.0.0.1:5001/<project>/asia-southeast1/<name>` serves an existing 2nd-gen callable (it does, via `seed/emulator_client.ts`). Record that the production form `https://asia-southeast1-<project>.cloudfunctions.net/<name>` stays unverified until Blaze; `callables.ts` reads the base from `CALLABLE_BASE_URL`, so a different form changes only the env value.

---

### Task 1: Roles, actions and new error codes (domain)

**Files:**
- Create: `packages/domain/src/staff_permissions.ts`, `packages/domain/test/staff_permissions.test.ts`
- Modify: `packages/domain/src/errors.ts`, `packages/domain/src/index.ts`, `firebase/functions/src/callables/errors.ts`, `firebase/functions/test/unit/errors.test.ts`, root `src/errors.ts`

**Interfaces:**
- Produces:

```ts
export const STAFF_ROLES = ['admin', 'finance', 'support', 'sales'] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];
export function isStaffRole(v: unknown): v is StaffRole;
/** #162's actions; later tickets append theirs (spec §4.2). */
export const STAFF_ACTIONS = ['overview.view', 'staff.set_role', 'staff.reset_mfa', 'audit.view', 'payout.manage'] as const;
export type StaffAction = (typeof STAFF_ACTIONS)[number];
export function staffMay(role: StaffRole | null | undefined, action: StaffAction): boolean;
```

- [ ] **Step 1: Write the failing table test.** It loops over every role × every action and compares with this table, and checks that `null`/`undefined`/`'owner'` may do nothing:

| Action | admin | finance | support | sales |
|---|---|---|---|---|
| `overview.view` | ✓ | ✓ | ✓ | ✓ |
| `staff.set_role` | ✓ | | | |
| `staff.reset_mfa` | ✓ | | | |
| `audit.view` | ✓ | | | |
| `payout.manage` | ✓ | ✓ | | |

  Also test `isStaffRole('admin') === true` and `isStaffRole('owner') === false`.

- [ ] **Step 2: Add the five error codes** (see Global Constraints). Transport codes: `staff_forbidden` and `mfa_required` → `permission-denied`; `last_admin`, `approval_pending` and `same_person` → `failed-precondition`. API `HTTP_STATUS`: 403, 403, 409, 409, 409.
- [ ] **Step 3: Implement** with a `Record<StaffAction, readonly StaffRole[]>`, so a new action fails `typecheck` until it has a row.
- [ ] **Step 4: Run** the domain, Functions unit and root `npm run typecheck`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(domain): staff roles, actions and permission table [#162]`.

---

### Task 2: Audit, staff members and two-person approvals (domain)

**Files:**
- Create: `packages/domain/src/audit.ts`, `staff_members.ts`, `staff_approvals.ts`, `memory_staff_store.ts`
- Test: `packages/domain/test/audit.test.ts`, `staff_members.test.ts`, `staff_approvals.test.ts`
- Modify: `packages/domain/src/index.ts`

**Interfaces:**
- Consumes: Task 1.
- Produces (ports follow the existing `*_ports.ts` style: a `run(fn)` transaction with reads before writes):

```ts
// audit.ts
export const AUDIT_REASON_MIN = 5, AUDIT_REASON_MAX = 500;
export type AuditActorRole = StaffRole | 'studio' | 'system';
export interface AuditEntry {
  readonly actorId: string; readonly actorRole: AuditActorRole; readonly action: string;
  readonly entityType: string; readonly entityId: string; readonly reason: string | null;
  readonly diff: Readonly<Record<string, readonly [unknown, unknown]>> | null;
}
export interface AuditWriter { add(entry: AuditEntry): void }   // inside a transaction; the adapter stamps id (ULID) and at
export function validateReason(raw: unknown): string;          // trimmed; DomainError invalid_argument field 'reason'
// staff_members.ts
export interface StaffMember { readonly uid: string; readonly role: StaffRole; readonly grantedBy: string; readonly grantedAt: Date; readonly updatedAt: Date }
export interface StaffCaller { readonly uid: string; readonly role: StaffRole | null; readonly mfa: boolean }
export interface StaffTx extends AuditWriter {
  getMember(uid: string): Promise<StaffMember | null>;
  countAdmins(): Promise<number>;
  putMember(m: StaffMember): void; deleteMember(uid: string): void;
}
export interface StaffAuth {                           // effects after the transaction commits
  userExists(uid: string): Promise<boolean>;
  setRoleClaim(uid: string, role: StaffRole | null): Promise<void>;
  revokeSessions(uid: string): Promise<void>;
  clearSecondFactors(uid: string): Promise<void>;
  findByEmail(email: string): Promise<{ uid: string; displayName: string; email: string; staffRole: StaffRole | null } | null>;
}
export interface StaffDeps { readonly store: { run<T>(fn: (tx: StaffTx) => Promise<T>): Promise<T> }; readonly auth: StaffAuth; readonly clock: { now(): Date } }
export function assertStaffCaller(caller: StaffCaller, action: StaffAction): void;   // mfa_required, then staff_forbidden
export async function setStaffRole(deps: StaffDeps, caller: StaffCaller, raw: unknown): Promise<{ changed: boolean }>;
export async function resetStaffMfa(deps: StaffDeps, caller: StaffCaller, raw: unknown): Promise<void>;
export async function findUserForStaff(deps: StaffDeps, caller: StaffCaller, raw: unknown): Promise<{ uid: string; displayName: string; email: string; staffRole: StaffRole | null }>;
// staff_approvals.ts
export const APPROVAL_TTL_HOURS = 24;
export type ApprovalStatus = 'pending' | 'approved' | 'rejected' | 'cancelled' | 'expired';
export interface ApprovalKindSpec<P> {
  readonly requestAction: StaffAction; readonly approveAction: StaffAction;
  /** Re-validates the stored params against the entity now; false → the request closes as stale. */
  stillValid(tx: unknown, params: P): Promise<boolean>;
  /** Runs the original operation inside the decide transaction, with the approver as actor. */
  run(tx: unknown, approver: StaffCaller, params: P): Promise<void>;
}
export const APPROVAL_KINDS: Readonly<Record<string, ApprovalKindSpec<unknown>>>;   // empty in #162; #163/#164 add rows
export interface StaffApproval { /* fields of spec §5.4 */ }
export async function requestApproval(deps, caller, input: { kind; entityType; entityId; amount?; params; reason }): Promise<{ status: 'awaiting_second_approval'; approvalId: string }>;
export async function decideApproval(deps, caller, raw: unknown): Promise<{ status: 'approved' | 'rejected' | 'expired' }>;
export async function cancelApproval(deps, caller, raw: unknown): Promise<void>;
```

- [ ] **Step 1: Write the failing tests** (memory store and a fake `StaffAuth` that records calls):
  - `validateReason`: `'  abcd '` → invalid; `'abcde'` → `'abcde'`; 501 characters → invalid; a number → invalid.
  - `setStaffRole` grant:
    - Caller admin with MFA grants `support` to user `u2` with a reason. The member is written, then the claim is set, then sessions are revoked.
    - The single audit row is `{action: 'staff.set_role', entityType: 'user', entityId: 'u2', reason, diff: {role: [null, 'support']}, actorRole: 'admin'}`.
    - The result is `{changed: true}`.
  - `setStaffRole` change: `support` → `finance` gives diff `{role: ['support','finance']}`.
  - `setStaffRole` revoke: `role: null` deletes the member; the claim becomes `null`; sessions are revoked.
  - Idempotent: the same role again → `{changed: false}`, no audit row, no claim call.
  - `last_admin`: with one admin, demoting or removing that admin (including self) → `last_admin` and nothing written. With two admins, the first demotion succeeds and the second fails.
  - Unknown uid (`userExists` false) → `not_found`.
  - Callers that are refused, before any write:
    - not admin → `staff_forbidden`;
    - no MFA → `mfa_required`, which is checked before role;
    - role `owner` in input → `invalid_argument`.
  - `resetStaffMfa`: clears factors, revokes sessions, one audit row `staff.reset_mfa`. Works on the last admin and does not touch the role.
  - `findUserForStaff`:
    - exact email lower-cased → the user;
    - an unknown email → `not_found`;
    - an input that is not an email → `invalid_argument`.

    It writes no audit row, because it is a lookup, not a decision.
  - Approvals: register a test-only kind `test_kind` through a helper that wraps `APPROVAL_KINDS` (the test passes a registry; production uses `APPROVAL_KINDS`). Expectations:
    - `requestApproval` creates a `pending` row with `expiresAt = requestedAt + 24 h` and writes the audit row `approval.request`.
    - A second request on the same entity while one is pending → `approval_pending`.
    - Decide by the requester → `same_person`.
    - Decide by a user without `approveAction` → `staff_forbidden`.
    - Decide `approve`:
      - runs `run` once;
      - the status becomes `approved`;
      - it writes two audit rows, `approval.decide` and the kind's own action written by `run`.
    - Decide again → `conflict`.
    - Decide after `expiresAt` → `{status: 'expired'}`, the row becomes `expired`, and `run` is not called.
    - `stillValid` false → `{status: 'rejected'}` with `decisionNote: 'stale'`.
    - `cancelApproval` works only for the requester and only while pending; others get `staff_forbidden`, a non-pending row gets `conflict`.
- [ ] **Step 2: Run** `npm test` in `packages/domain`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Order inside every use case:
    1. validate input;
    2. check the caller (`assertStaffCaller`);
    3. run the transaction (reads, then the guard, then writes, then the audit row);
    4. after commit, the auth effects in the order claim → revoke.
  - If an auth effect fails after commit, the use case rethrows `internal`. The member row and the audit row stand, and the CLI `staff set-role` re-applies the claim idempotently. Write this down in the doc comment.
  - `countAdmins` is read inside the transaction, so two concurrent demotions cannot both pass (Firestore retries the loser).
- [ ] **Step 4: Run** `npm run typecheck && npm run lint && npm test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(domain): audit log, staff members and two-person approvals [#162]`.

---

### Task 3: `StaffActor {uid, role}` for payouts

**Files:**
- Modify: `packages/domain/src/payout_use_cases.ts` (`StaffActor`, `requireAdmin` → `requirePayoutStaff`, `SYSTEM_PAYOUT_ACTOR`), every caller and test that builds `{uid, isAdmin}` for payouts (grep `isAdmin` under `packages/domain` and `firebase/functions` and change only the payout ones), `firebase/functions/tools/payouts.ts` (`io.isAdmin` → `io.staffRole(uid)`)

**Interfaces:**
- Produces: `export interface StaffActor { readonly uid: string; readonly role: StaffRole | 'system' }`; `SYSTEM_PAYOUT_ACTOR = { uid: 'system:createPayouts', role: 'system' }`; payout use cases allow `role === 'system'` or `staffMay(role, 'payout.manage')`.

- [ ] **Step 1: Update the payout tests first.** Every `{uid, isAdmin: true}` becomes `{uid, role: 'admin'}`. Add three cases: `finance` approves a payout → allowed; `support` → `permission_denied` (the existing code, unchanged); `system` runs the daily job → allowed.
- [ ] **Step 2: Run** domain and Functions unit tests. Expected: FAIL (type errors).
- [ ] **Step 3: Implement.** Award, verification and dispute keep their `isAdmin` checks: those change in #164 and #165 (spec §4.4).
- [ ] **Step 4: Run** domain + Functions unit + root typecheck. Expected: PASS.
- [ ] **Step 5: Commit** `refactor(payouts): staff actor carries a role, payouts open to finance [#162]`.

---

### Task 4: `assertStaff` and the staff callables (Functions)

**Files:**
- Create: `firebase/functions/src/callables/staff.ts`, `src/infra/audit_firestore.ts`, `src/infra/staff_firestore.ts`, `src/infra/approvals_firestore.ts`, `src/infra/live_staff.ts`
- Modify: `src/index.ts` (exports `setStaffRole`, `resetStaffMfa`, `findUserForStaff`, `decideStaffApproval`, `cancelStaffApproval` with `CALLABLE_OPTIONS`)
- Test: `test/unit/staff_callables.test.ts`, `test/integration/staff.test.ts` (written; CI runs it)

**Interfaces:**
- Consumes: Task 2 use cases.
- Produces:

```ts
export const AUDIT_LOG_COLLECTION = 'audit_log';
export const STAFF_MEMBERS_COLLECTION = 'staff_members';
export const STAFF_APPROVALS_COLLECTION = 'staff_approvals';
export function mfaBypassActive(env: NodeJS.ProcessEnv): boolean;   // MFA_DEV_BYPASS==='1' && FUNCTIONS_EMULATOR==='true'
export function staffCallerOf(request: { auth?: { uid: string; token?: Record<string, unknown> } }, env?: NodeJS.ProcessEnv): StaffCaller;
export function assertStaff(request, action: StaffAction, env?: NodeJS.ProcessEnv): StaffCaller;   // throws HttpsError via toHttpsError
export function handleSetStaffRole(request, deps: StaffDeps): Promise<{ changed: boolean }>;   // and the other four handlers
```

- [ ] **Step 1: Write the failing unit tests** (inline request objects as in `award_callables.test.ts`; in-memory store from Task 2):
  - `staffCallerOf` reads `token.staffRole` and `token.firebase.sign_in_second_factor === 'totp'`.
  - `assertStaff refuses a token without totp`: `permission-denied`, `details.code === 'mfa_required'`.
  - `MFA_DEV_BYPASS=1` with `FUNCTIONS_EMULATOR=true` → passes; with `FUNCTIONS_EMULATOR` unset → still `mfa_required`, and `logger.warn` is called once per process.
  - Unauthenticated → `unauthenticated`.
  - Each handler maps `last_admin`, `same_person`, `approval_pending`, `staff_forbidden` to the right `HttpsError` (`details.code`).
- [ ] **Step 2: Implement the adapters.**
  - `audit_firestore.add` buffers `{...entry, at: serverTimestamp()}` under `newUlid()` ids into the transaction's write list.
  - `staff_firestore`:
    - `StaffAuth` through `adminAuth()`: `setCustomUserClaims` merges with the existing claims, never replaces other claims;
    - `revokeRefreshTokens`;
    - `updateUser(uid, { multiFactor: { enrolledFactors: null } })`;
    - `getUserByEmail`;
    - `countAdmins` = `count()` of `staff_members` where `role == 'admin'`, inside the transaction.
  - `approvals_firestore` follows `payout_firestore.ts`: reads go through `tx.get`, writes are buffered.
- [ ] **Step 3: Integration test** `test/integration/staff.test.ts`, using the seed accounts from Task 6 and `MFA_DEV_BYPASS=1` set for the emulator run in `package.json`'s `test:integration` only if Task 0 found no TOTP support. Steps:
  1. admin grants `support` to `lan.customer@seed.test`;
  2. Lan's old ID token is refused on the next `findUserForStaff` call (revoked);
  3. a fresh token carries `staffRole: 'support'`;
  4. one `audit_log` row exists;
  5. demoting the only admin → `last_admin`.
- [ ] **Step 4: Run** Functions lint, typecheck, unit. Expected: PASS.
- [ ] **Step 5: Commit** `feat(functions): staff callables with second-factor check and audit log [#162]`.

---

### Task 5: Private files (`getSensitiveFileUrl`)

**Files:**
- Create: `firebase/functions/src/callables/sensitive_file.ts`, `src/infra/signed_url.ts`, `test/unit/sensitive_file.test.ts`
- Modify: `packages/domain/src/staff_permissions.ts` (actions `award.review`, `verification.review`, `dispute.view`, each admin + support only: finance never sees documents or evidence, spec §4.2) and its table test, `src/index.ts`

**Interfaces:**
- Produces:

```ts
export type SensitiveFileKind = 'award_proof' | 'business_doc' | 'dispute_evidence';
export interface FileSigner { sign(path: string, ttlSeconds: number): Promise<string> }
export function sensitivePath(kind: SensitiveFileKind, entityId: string, file: string, ctx: …): Promise<string>;   // validated path or not_found
export function handleGetSensitiveFileUrl(request, deps: { signer: FileSigner; disputes: …; awards: …; audit: …; clock }): Promise<{ url: string; expiresAt: string }>;
```

- [ ] **Step 1: Write the failing tests:**
  - **Kind × role table:**
    - `award_proof` and `business_doc`: admin and support allowed; finance and sales `staff_forbidden`.
    - `dispute_evidence`: admin and support allowed; finance `staff_forbidden` (spec §4.2: finance never sees evidence).
  - **Path building:**
    - `award_proof`: `entityId = '<uid>/<awardId>'` → `awardProofs/<uid>/<awardId>/<file>`.
    - `business_doc`: `entityId = '<uid>'`.
    - `dispute_evidence`: signs only when `disputeEvidence/<uid>/<disputeId>/<file>` is listed in `disputes/{id}.evidencePaths`; otherwise `not_found`.
  - **Bad input:** a `file` containing `/`, `..` or a character outside `[A-Za-z0-9_.-]` → `invalid_argument`. An unknown kind → `invalid_argument`.
  - **Audit:** one row per call: `action 'file.view'`, `entityType` = kind, `entityId` = the full path, `reason null`.
  - **Expiry:** `expiresAt = now + 300 s`.
- [ ] **Step 2: Implement `signed_url.ts`.** Production uses `bucket().file(path).getSignedUrl({ version: 'v4', action: 'read', expires })`. This needs `iam.serviceAccounts.signBlob` on the Functions service account; note it in the deploy docs (Task 12). On the emulator (`FUNCTIONS_EMULATOR === 'true'`), download the object and return `data:<contentType>;base64,…`, because the emulator cannot sign. Callers treat the URL as opaque either way.
- [ ] **Step 3: Run** Functions unit. Expected: PASS.
- [ ] **Step 4: Commit** `feat(functions): private file viewing through short-lived signed URLs [#162]`.

---

### Task 6: Rules, indexes, seed and the `staff` CLI

**Files:**
- Modify: `firebase/firestore.rules` (explicit deny blocks for `audit_log`, `staff_members`, `staff_approvals` next to `awardAudit`), `firebase/firestore.indexes.json`, `firebase/rules-test/rules.test.mjs`, `firebase/functions/seed/fixtures.ts`, `seed/apply.ts`, `seed/README.md`, `test/unit/seed_fixtures.test.ts`, `firebase/functions/package.json` (`"staff": "tsx tools/staff.ts"`)
- Create: `firebase/functions/tools/staff.ts`, `test/unit/staff_cli.test.ts`

- [ ] **Step 1: Indexes** (the expanded one-field-per-object style of the file):
  - `audit_log`: (`entityType` ASC, `entityId` ASC, `at` DESC), (`actorId` ASC, `at` DESC), (`action` ASC, `at` DESC).
  - `staff_approvals`: (`status` ASC, `requestedAt` ASC), (`entityType` ASC, `entityId` ASC, `status` ASC).
- [ ] **Step 2: Rules tests** (written, run by CI): an admin token, a staff token and an owner token can neither read nor write a document in any of the three collections; `withSecurityRulesDisabled` seeding works.
- [ ] **Step 3: Seed.**
  - `SeedUser.staffRole` widens to `StaffRole`.
  - Add three accounts with `SEED_PASSWORD`: `finance.staff@seed.test` (uid `seed-staff-finance`), `support.staff@seed.test` (`seed-staff-support`), `sales.staff@seed.test` (`seed-staff-sales`).
  - Write a `staff_members/{uid}` doc for every seed staff account, admin included (`grantedBy: 'seed'`).
  - The studio owner is the existing `cuc.studio@seed.test`; document it in the README account table.
  - Update the seed fixture test counts.
- [ ] **Step 4: CLI** `tools/staff.ts`, in the `parseArgs` / `CliIo` / `runCli` / `main()` pattern of `tools/awards.ts` with `guardEnv` + `assertLocalEmulators({ allowAnyProject: true })`. It runs the Task 2 use cases with a system caller `{uid: 'cli:<os user>', role: 'admin', mfa: true}`:

  ```
  staff list
  staff set-role <uid> <admin|finance|support|sales|none> --reason "…"
  staff reset-mfa <uid> --reason "…"
  ```

  It is not guarded by an actor's role: it runs with Admin credentials and exists to create the first admin. It still writes the audit row, with `actorId 'cli:<os user>'` and `actorRole 'admin'`. Unit tests use a fake `CliIo`: list prints uid, email, role and MFA on/off; set-role prints `changed`/`unchanged`; missing `--reason` → usage error, exit 2.
- [ ] **Step 5: Run** Functions lint, typecheck, unit. Expected: PASS.
- [ ] **Step 6: Commit** `feat(functions): staff rules, indexes, seed accounts and the staff CLI [#162]`.

---

### Task 7: Dashboard project, lint wall and tokens

**Files (all under `apps/dashboard/`):** `package.json`, `package-lock.json`, `tsconfig.json`, `next.config.ts`, `eslint.config.js`, `vitest.config.ts`, `.env.example`, `src/app/layout.tsx`, `src/app/globals.css`, `src/messages/vi.ts`, `src/lib/screen-codes.ts`, `src/lib/format.ts`, `design-tokens/tokens.json`, `design-tokens/tokens.lock`, `tool/sync_tokens.mjs`, `tool/gen_tokens_css.mjs`, `src/styles/tokens.css`, `test/purity.test.ts`, `test/format.test.ts`, `test/tokens.test.ts`; root `.github/dependabot.yml` (an `npm` entry for `/apps/dashboard`).

**Interfaces:**
- Produces:
  - `formatMoney(vnd: number): string`, which gives `1.500.000₫`;
  - `formatDateTime(iso: string): string`, which gives `T7 12/10 15:30` in Asia/Ho_Chi_Minh;
  - `formatAge(fromIso: string, nowIso: string): string`, which gives `26 giờ`, `3 ngày`;
  - `SCREEN_CODES` (`login: 'S23.08'`, `overview: 'S23.09'`, `team: 'S23.10'`, `audit: 'S23.11'`, `approvals: 'S23.15'`);
  - `t(key: MessageKey, vars?: Record<string, string | number>): string`.

- [ ] **Step 1: Create the project** with `npm init` and pinned versions:
  - **Dependencies:** `next@^16`, `react@^19`, `react-dom@^19`, `firebase@^12`, `firebase-admin@^13` (as in the functions package), `server-only`, `ulidx`.
  - **Dev dependencies:** `typescript`, `@types/react`, `@types/node`, `eslint` with `eslint-config-next`, `eslint-plugin-react`, `vitest`, `@testing-library/react`, `@testing-library/user-event`, `jsdom`, `@playwright/test`.
  - **Engine:** Node `>=24.22.1`.
  - **Scripts:** `dev`, `build`, `start`, `lint`, `typecheck`, `test` (vitest run), `e2e` (playwright test), `tokens:sync`, `tokens:css`, `tokens:check`.
  - **tsconfig:** `paths` `{"@photobooking/domain": ["../../packages/domain/src/index"]}` and `@/*` → `src/*`. `next.config.ts` sets `transpilePackages` / `experimental.externalDir` so that the domain sources outside the app compile.
- [ ] **Step 2: ESLint** (spec §2.6):
  - For files outside `src/server/**`, `no-restricted-imports` forbids `firebase-admin`, `firebase-admin/*`, `server-only`, `@/server/*`, `firebase/firestore`, `firebase/storage` and `firebase/database`.
  - For `src/server/**`, it forbids `firebase/auth` and `firebase/app`; the client SDK stays out of the server.
  - Convention that makes the wall checkable: every client component (a file starting with `'use client'`) is named `*.client.tsx`. The client rule above applies to `src/**/*.client.tsx`; server components, server actions and route handlers may import `@/server/*`.
  - `react/jsx-no-literals` is on for `src/app/**` and `src/components/**`.
- [ ] **Step 3: Purity test** `test/purity.test.ts`. It fails when a file starting with `'use client'` is not named `*.client.tsx`, and when a `*.client.tsx` file imports any of `firebase-admin`, `server-only`, `@/server/`, `firebase/firestore`, `firebase/storage` or `firebase/database`. Seed it with one temporary bad fixture string to prove the regex bites, then remove the fixture.
- [ ] **Step 4: Tokens.**
  - `tool/sync_tokens.mjs` reads `design-tokens/tokens.lock` (`ref=<sha>`) and downloads `design-system/tokens.json` at that commit from `https://raw.githubusercontent.com/thanhngochoang/booking/<sha>/design-system/tokens.json` into `design-tokens/tokens.json`. Initial `ref` = `origin/develop` of the app repo at implementation time.
  - `tool/gen_tokens_css.mjs` mirrors `app_flutter/tool/gen_tokens.dart`:
    - `resolve()` follows `{a.b.c}` references to `$value`;
    - emits `:root { … }` from `semantic` (light) and `:root[data-theme="dark"] { … }` from `dark.semantic.color` overrides;
    - names are `--color-<name>`, `--space-<name>`, `--radius-<name>`, `--font-<name>`, `--text-<name>-size`/`-line`/`-weight`;
    - colours as `#RRGGBB`, or `rgb(r g b / a)` when an alpha is present (the source sometimes holds `#AARRGGBB`; convert it, never emit 8-digit ARGB);
    - `dp` values become `px`;
    - header `/* generated from design-tokens/tokens.json (<ref>); do not edit */`.
  - `tokens:check` regenerates to a temp file and fails if it differs from `src/styles/tokens.css`.
  - `<html data-theme="dark">` is the default in `layout.tsx`; the theme toggle (account menu) stores the choice in `localStorage` and flips the attribute.
  - Tests: one colour, one reference chain, one alpha colour, one `dp` value, and `tokens:check` passes.
- [ ] **Step 5: Format tests:**
  - `formatMoney(1500000) === '1.500.000₫'` and `formatMoney(0) === '0₫'`;
  - `formatDateTime('2026-10-12T08:30:00Z') === 'T2 12/10 15:30'` (a Monday, 15:30 in Asia/Ho_Chi_Minh) and `formatDateTime('2026-10-11T17:30:00Z') === 'T2 12/10 00:30'` (the day follows Vietnam time, not UTC);
  - `formatAge` gives `26 giờ` under 48 h, then `n ngày`.
- [ ] **Step 6: Run** `npm run lint && npm run typecheck && npm test && npm run build`. Expected: PASS (empty home page).
- [ ] **Step 7: Commit** `feat(dashboard): Next.js project, import wall, tokens and formatting [#162]`.

---

### Task 8: Shared web components

**Files:** `apps/dashboard/src/components/` — `ScreenCode`, `StaffShell`, `StudioShell`, `QueueLayout`, `DataTable`, `DetailPane`, `DecisionDialog`, `StatusChip`, `MoneyText`, `DateTimeText`, `SecureFileViewer`, `EmptyState`, `ErrorState`, `Skeleton`, `AsyncView`, `DotRingLoader`, `Toast`, `Icon` (Material Symbols Rounded via Google Fonts `<link>`); tests in `apps/dashboard/test/components/`.

Layout and visuals follow the mock (`#S23.09` and the studio shell) and spec §8:
- **`StaffShell`:**
  - side bar 248 px with groups Hàng đợi · Tiền · Nội dung · Hệ thống, showing only items `staffMay` allows;
  - top bar with "Tìm theo mã" (a placeholder in #162 that reports "Chưa hỗ trợ mã này" until tickets register their id resolvers), role chip and account menu;
  - below 1024 px, the bar "Dashboard staff cần màn hình rộng hơn".
- **`StudioShell`:** same structure, with the menu items of spec §7 "Khung studio" all pointing to `/studio` placeholders.
- **`QueueLayout`:** `j`/`k` move the selection and `Enter` opens it. It refreshes with `router.refresh()` every `intervalMs` while `document.visibilityState === 'visible'`.
- **`DecisionDialog`:**
  - shows a summary, a reason textarea (5–500 characters after trim) and a confirm button;
  - `danger` makes the confirm button red;
  - the confirm button is disabled while the reason is invalid or while the action is pending;
  - it generates an `idempotencyKey` (ULID) when it opens.
- **`SecureFileViewer`:**
  - calls a server action that returns `{url}`;
  - renders the image with a CSS overlay "Nội bộ · <email> · <time>";
  - never puts the URL in an `href`.
- **`ScreenCode`:** shows the code label only with `?debug=1` and `NODE_ENV !== 'production'`.

- [ ] **Step 1: Write the RTL tests:**
  - `DecisionDialog`:
    - a 4-character reason keeps the confirm button disabled;
    - 5 characters enable it;
    - clicking confirm twice calls `onConfirm` once;
    - `danger` renders the class/variant used for red and never the gradient class.
  - `QueueLayout`: `j`/`k` change `aria-selected`; with fake timers, refresh is called every 30 s only while visible.
  - `StaffShell`: for `sales`, only "Tổng quan" is visible; for `admin`, "Staff" and "Nhật ký" are visible.
  - `MoneyText` and `DateTimeText` render through `format.ts`.
  - `ScreenCode` is hidden without `?debug=1`.
- [ ] **Step 2: Implement** with CSS modules over `tokens.css` variables. No component library.
- [ ] **Step 3: Run** lint, typecheck, test. Expected: PASS.
- [ ] **Step 4: Commit** `feat(dashboard): shells, queue layout, decision dialog and shared components [#162]`.

---

### Task 9: Sessions, guards and S23.08 login

**Files:**
- `apps/dashboard/src/server/auth/admin.ts` (Admin SDK init; with `USE_EMULATORS=1` it relies on `FIREBASE_AUTH_EMULATOR_HOST` and `FIRESTORE_EMULATOR_HOST`)
- `src/server/auth/session.ts`, `src/server/auth/guards.ts`
- `src/app/api/session/route.ts`
- `src/lib/firebase.client.ts` (`connectAuthEmulator` when `NEXT_PUBLIC_USE_EMULATORS=1`)
- `src/app/login/page.tsx` + `LoginCard.client.tsx` (steps: sign-in, TOTP enrol, TOTP verify, not allowed, choose staff/studio)
- `src/components/IdleTimeout.client.tsx`
- `src/app/403/page.tsx`
- tests

**Interfaces:**
- Produces:

```ts
export interface Session { uid: string; email: string | null; staffRole: StaffRole | null; mfa: boolean; authTime: Date; studioOwner: boolean }
export async function getSession(): Promise<Session | null>;                 // reads the __session cookie
export async function requireStaff(action: StaffAction): Promise<Session>;   // redirect('/login?next=…'), redirect('/login?step=totp'), or notFound-style 403
export async function requireStudioOwner(): Promise<Session>;
export function landingFor(s: Session): '/staff' | '/studio' | '/login?step=choose' | '/login?step=not-allowed';
```

- [ ] **Step 1: Write the failing tests** (Vitest; a fake verifier and a fake `photographers` reader injected through a small `deps` object):
  - No cookie → `null`.
  - Expired or revoked token → `null`, and the route handler answers 401.
  - `getSession` for a staff token without a second factor returns `mfa: false`, and `requireStaff` redirects to `/login?step=totp`.
  - With `MFA_DEV_BYPASS=1` and `USE_EMULATORS=1`, `mfa` is true. With only `MFA_DEV_BYPASS=1`, it stays false and a warning is logged.
  - `authTime` older than 12 h for a staff member → redirect `/login?reason=expired`.
  - Guard table: for each role × each of `/staff` (`overview.view`), `/staff/team` (`staff.set_role`) and `/staff/audit` (`audit.view`), allowed or 403. A studio owner without `staffRole` gets 403 on every `/staff/*`.
  - `landingFor`:
    - staff only → `/staff`;
    - studio owner only (`photographers/{uid}.providerType === 'studio'`) → `/studio`;
    - both → `choose`;
    - neither → `not-allowed`.
  - `POST /api/session`:
    - refuses a request whose `Origin` is not the app origin (403);
    - with a valid token, sets the cookie flags of the Global Constraints;
    - `DELETE` clears the cookie.
- [ ] **Step 2: Implement the server side.** `getSession` uses `verifyIdToken(token, true)`, reads `staffRole` from claims, reads `mfa` from `firebase.sign_in_second_factor === 'totp'` (or the bypass), and reads the studio-owner flag from `photographers/{uid}` (one `get`, cached per request with React `cache`).
- [ ] **Step 3: Implement the client.**
  - `onIdTokenChanged` posts the new token to `/api/session`.
  - A 401 from a server action triggers one `getIdToken(true)` and a retry.
  - Sign-in options: Google, Facebook and email/password.
  - `auth/multi-factor-auth-required` → the TOTP verify step: 6 boxes, paste works, it auto-submits at 6 digits.
  - A staff member without enrolled factors → the enrol step: QR from `secret.generateQrCodeUrl(email, 'Dashboard')` as an `<img>` rendered by a small QR SVG generator (add `qrcode` as a dependency), plus the secret with a copy button and the 6-digit confirm.
  - Error texts of spec §7 S23.08 come from `messages/vi.ts`.
  - `IdleTimeout` (staff only): 30 min without input → a dialog with a 60 s countdown → sign out.
- [ ] **Step 4: Run** lint, typecheck, test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dashboard): sessions, role guards and the S23.08 login with TOTP [#162]`.

---

### Task 10: Read layer, `callCallable` and the S23.09–S23.11, S23.15 screens

**Files:**
- `apps/dashboard/src/server/write/callables.ts`, `src/server/write/errors.ts`
- `src/server/read/{overview,team,audit,approvals}.ts` + `src/server/read/firestore/{overview,team,audit,approvals}.ts`
- `src/app/(staff)/staff/layout.tsx` (StaffShell)
- pages `page.tsx` for `/staff`, `/staff/team`, `/staff/audit`, `/staff/approvals`, with server actions in `actions.ts` next to each page
- `src/app/(studio)/studio/layout.tsx` + `page.tsx` (shell and a "Sắp có" placeholder)
- tests

**Interfaces:**

```ts
export async function callCallable<TIn, TOut>(name: string, data: TIn, idToken: string, fetchFn?: typeof fetch): Promise<TOut>;
export class CallableError extends Error { constructor(readonly code: string, readonly status: number) }
export function messageForCode(code: string): string;   // vi text; unknown → common.unknown_error with the code
// readers return DTOs only (strings, numbers, ISO strings)
export interface OverviewReader { recentActions(uid: string, limit: 5): Promise<AuditRowDto[]>; queues(role: StaffRole): Promise<QueueCardDto[]> }   // queues: [] in #162
export interface TeamReader { list(): Promise<TeamRowDto[]> }        // staff_members + Auth getUsers (name, email, MFA enrolled)
export interface AuditReader { page(filter: AuditFilter, cursor?: string): Promise<{ rows: AuditRowDto[]; next?: string }> }
export interface ApprovalsReader { page(viewer: Session, cursor?: string): Promise<{ rows: ApprovalRowDto[]; next?: string }> }
```

- [ ] **Step 1: Write the failing tests:**
  - **`callCallable`:**
    - posts `{data}` with `Authorization: Bearer` to `${CALLABLE_BASE_URL}/${name}` and returns `result`;
    - an `{error:{details:{code:'last_admin'}}}` answer → `CallableError('last_admin')`, and `messageForCode` gives the Vietnamese text;
    - a network failure → `CallableError('unavailable')`.
  - **Mappers:** every DTO field is a primitive or an ISO string; a test walks the object and fails on any non-plain value (a `Timestamp` look-alike with `toDate`).
  - **`AuditReader`:** each filter uses exactly one of the three indexes (assert the query shape on a fake Firestore); pages have 50 rows; the cursor continues after the last `at`/id.
  - **`ApprovalsReader`:** in #162 `APPROVAL_KINDS` is empty, so only the viewer's own requests show; S23.15 shows the empty state "Không có thao tác nào chờ duyệt".
- [ ] **Step 2: Implement the screens** per spec §7 and the mock:
  - **S23.09:** title "Tổng quan" with the date; a queue grid (no cards in #162, so `EmptyState` "Không còn việc nào đang chờ"); "Thao tác gần đây của bạn" (5 rows); refresh every 60 s.
  - **S23.10:**
    - a table (name, email, role chip, MFA on/off, granted by, date) with a "…" menu;
    - "Thêm staff" opens a `DecisionDialog` that runs `findUserForStaff`, then a role select, then a reason, then `setStaffRole`;
    - "Bỏ quyền staff" and "Đặt lại xác thực hai lớp" are red, in the dialog, with a reason;
    - states: not found, already staff (switch to change role), `last_admin`.
  - **S23.11:** filters (actor, entity type + id, action, date range), table, a detail drawer with `diff`, 50 per page.
  - **S23.15:** `QueueLayout` with approve/reject/cancel wired to `decideStaffApproval` / `cancelStaffApproval`.
  - Every page is wrapped in `<ScreenCode>` and guarded with `requireStaff(...)`. Server actions call `revalidatePath` after a write.
- [ ] **Step 3: RTL test of the S23.10 add-staff flow** with the server actions mocked: email → found user shown → role → reason → submit → the table re-renders.
- [ ] **Step 4: Run** lint, typecheck, test, build. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dashboard): read layer, callables and the staff overview, team, audit and approvals screens [#162]`.

---

### Task 11: Run locally against the emulators

**Files:** `apps/dashboard/.env.example`, `apps/dashboard/README.md`, booking-be `AGENTS.md` (Commands + a "Dashboard" paragraph), `scripts/dashboard-local.sh` (new).

- [ ] **Step 1: Write the env and the script.** `.env.example` (test values only):
  - `USE_EMULATORS=1`, `NEXT_PUBLIC_USE_EMULATORS=1`;
  - `NEXT_PUBLIC_FIREBASE_API_KEY=fake-api-key`, `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=localhost`;
  - `NEXT_PUBLIC_FIREBASE_PROJECT_ID` and `FIREBASE_PROJECT_ID`, both set to the project `backend-local.sh` prints;
  - `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`, `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099`;
  - `CALLABLE_BASE_URL=http://127.0.0.1:5001/<project>/asia-southeast1`;
  - `MFA_DEV_BYPASS=` (set to `1` only if Task 0 found no TOTP).

  `scripts/dashboard-local.sh` reads the project id the same way as `backend-local.sh` and starts `npm --prefix apps/dashboard run dev` with these values.
- [ ] **Step 2: Manual walkthrough**, recorded in the PR with screenshots:
  1. `admin.staff@seed.test` signs in, passes TOTP and lands on `/staff`;
  2. on S23.10, grant `support` to `lan.customer@seed.test` with a reason;
  3. S23.11 shows the row;
  4. Lan signs in (TOTP enrolment) and sees "Tổng quan" only, plus no "Staff";
  5. `cuc.studio@seed.test` lands on `/studio`;
  6. `minh.nophone@seed.test` sees "Tài khoản này không dùng được dashboard".
- [ ] **Step 3: Commit** `docs(dashboard): run the dashboard against the local emulators [#162]`.

---

### Task 12: CI, Playwright and the App Hosting job

**Files:** `.github/workflows/dashboard.yml`, `apps/dashboard/playwright.config.ts`, `apps/dashboard/e2e/*.spec.ts`, `apps/dashboard/apphosting.yaml`, `firebase/firebase.json` (`apphosting` block: backendId `dashboard`, rootDir `apps/dashboard`), `.github/workflows/firebase-deploy.yml` (job `deploy-dashboard`), booking-be `AGENTS.md` (CI section).

- [ ] **Step 1: `dashboard.yml`.**
  - **Triggers:** push to develop/main and PRs touching `apps/dashboard/**`, `packages/domain/**`, `firebase/**` or the workflow itself.
  - **Job `checks`:** Node 24; in `apps/dashboard`: `npm ci`, lint, typecheck, `tokens:check`, test, build.
  - **Job `e2e`:**
    - Java 21 + Node 24;
    - build Functions;
    - `firebase emulators:exec --config firebase/firebase.json --project demo-nag --only auth,firestore,functions,storage "<seed> && <next build && next start &> && npx playwright test"`;
    - env as in `.env.example` with project `demo-nag`, and `MFA_DEV_BYPASS=1` only if Task 0 said so.
- [ ] **Step 2: Playwright specs** (Review Focus 1, 2, 4):
  - each seed role signs in and sees its menu: admin all, finance Tổng quan + nothing of #162 beyond it, sales Tổng quan;
  - `/staff/team` by finance → 403 page;
  - admin grants `support` to Lan, and Lan's next page load has the new menu;
  - admin revokes Lan, and Lan's next navigation → `/login`;
  - S23.11 shows the grant and the revoke;
  - direct callable call without totp is refused: a `fetch` to `setStaffRole` with a first-factor-only emulator token → `permission-denied` / `mfa_required` (skipped when the bypass is on, with the reason printed);
  - studio owner → `/studio`;
  - a non-staff, non-studio account → "không dùng được".
- [ ] **Step 3: `apphosting.yaml`:** `runConfig: { minInstances: 0, maxInstances: 2, concurrency: 80 }`; env `CALLABLE_BASE_URL`, `FIREBASE_PROJECT_ID`, `NEXT_PUBLIC_FIREBASE_*` (values per environment are set in the App Hosting console, not committed). No secrets.
- [ ] **Step 4: `deploy-dashboard` job** in `firebase-deploy.yml`.
  - It mirrors `deploy-functions`: `needs: [deploy-functions]`, the same environment selection, `ON` gate and `::warning::` step when off; when on, `npx firebase deploy --config ../firebase.json --non-interactive --project "$PROJECT_ID" --only apphosting:dashboard`.
  - Add `apps/dashboard/**` to the workflow's `paths`.
  - Document the backend service account roles (`roles/datastore.viewer`, `roles/firebaseauth.viewer`) and the Functions service account's `iam.serviceAccounts.signBlob` for Task 5 in booking-be `AGENTS.md`.
- [ ] **Step 5: Run** `actionlint` if available, and push the branch so CI runs both workflows. Expected: green; the deploy job is skipped with a warning because Blaze is off.
- [ ] **Step 6: Commit** `ci(dashboard): checks, Playwright on the emulators and the App Hosting job behind the Blaze switch [#162]`.

---

### Task 13: Docs in the app repository (separate PR, same branch name)

**Files (this repository):**
- `docs/superpowers/specs/data-model/domain-model.md`: `AuditLog` gains `actorRole` and `reason`; new rows `StaffMember` and `StaffApproval`.
- `docs/superpowers/specs/data-model/relational-schema.md`: `audit_log` gains `actor_role` and `reason`; new tables `staff_members` and `staff_approvals`.
- `docs/superpowers/specs/components/shared-components.md`: new section "Web (dashboard)" listing the Task 8 components and the `.client.tsx` rule.
- `design-system/README.md`: CSS is generated by booking-be `apps/dashboard/tool/gen_tokens_css.mjs` from a pinned snapshot; changing tokens here needs a booking-be PR that bumps `tokens.lock`.
- `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2: status cells of S23.08–S23.11 and S23.15 → "✅ đã làm (#162)".
- `docs/superpowers/handover/ledger-162-dashboard-foundation.md`, containing:
  - the Task 0 results;
  - the rulings (the `.client.tsx` convention, the emulator `data:` URL for private files, `payout.manage` opening payouts to finance, the CLI running as `cli:<user>`);
  - what tickets #163–#169 add (their `StaffAction` rows, `APPROVAL_KINDS` rows, overview cards and id resolvers for "Tìm theo mã").

- [ ] **Step 1: Edit the docs.** Keep Vietnamese prose with English code names, and check that every name matches the booking-be code.
- [ ] **Step 2: Commit** `docs(dashboard): data model, web components and ledger for the dashboard foundation [#162]`.
