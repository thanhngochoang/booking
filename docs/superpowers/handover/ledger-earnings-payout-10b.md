# Handover ledger — unit 10b (S06.05 Thu nhập, S06.06 Tài khoản nhận tiền)

Plan: `docs/superpowers/plans/2026-10-06-10b-earnings-payout.md`. Built on the stack branch `plan/stack-2026-10` (not yet in develop).

## Before this reaches develop (owner)
- Create secret `PAYOUT_ACCOUNT_KEY` (32 bytes, base64) in Secret Manager for `booking-c1922` and grant the CI deploy service account access (FIREBASE-SETUP.md §12). Without it the functions deploy on develop fails. Same for prod later.
- Real payouts need a real payout provider and legal review (open question 19); only `FakePayoutGateway` exists.

## Built
- Domain: payout account (bank list, number/holder normalisation, `reauth_required`), earnings read model (held / disputed → Đang giữ, released → Sắp nhận, paid_out → Đã nhận; refunds net), payouts (released money only, idempotent, failure returns money to payable), fake gateway.
- Functions: AES-256-GCM account cipher (fresh IV, 16-byte tag), `savePayoutAccount` callable (recent sign-in for changes), earnings projection triggers on payment and payout writes, staff CLI `npm run payouts` (fake mode only on the emulator or the dev project), rules (earnings owner-read; payoutAccounts masked owner-read; payouts and account history server-only), indexes, seed.
- App: earnings repository, bank list, input rules (exact parity with the domain via a generated table, 63k-code-point sweep), re-authentication port; S06.05 (totals truncated "3,95M" with full-amount semantics, month-grouped rows, fixed hold labels), S06.06 (masked view, confirm, re-auth then one retry).

## Rulings
- R3 realised as fixed hold-reason codes (`dispute`, `payout_on_hold`) → fixed labels; customer text and staff notes never reach the photographer (payouts are not client-readable).
- R4 holder name is a hint until S21.
- Money on screen never rounds up: totals and rows ≥ 1M truncate to 2 decimals; below 1M the K form may round by ≤ 50₫ (amounts are whole thousands in practice).
- `Booking.escrowStatus` is not mirrored to `paid_out` (the app only reads `held`).
- `functions/.secret.local` holds an emulator-only test key, committed like seed values.
- Payouts batch booking payments only until event-ticket earnings rows exist (TODO 10c Task 9).
- executePayout decrypts in a read-only transaction first; a changed account makes the write transaction return `conflict` (payout stays pending).

## Deferred
- A payout whose gateway keeps throwing stays `processing` (staff "mark failed" tool for S23).
- Earnings refresh reads all items per write (battery/performance plan).
- No rate limit on `savePayoutAccount` (re-auth limits it). Re-auth falls back to password for phone/anonymous users (revisit with S21 OTP).
- Magic numbers in `EarningRow`/`StatTile`. K-form rounding under 1M (≤ 50₫).
- Task 5's app files landed inside commit 70750ea (a 10c domain commit) through a shared-index race.
