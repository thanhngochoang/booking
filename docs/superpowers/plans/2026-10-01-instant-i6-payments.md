# Instant booking I6: real payments (MoMo, VNPay) and escrow release for Chụp ngay Implementation Plan

> **iOS (2026-10-02, user):** the dependency on iOS enablement Task 1 (`ios/Flutter/Secrets.xcconfig.example`, `test/platform/ios_config_test.dart`) is deferred: skip the iOS parts of this plan and append them under "Deferred iOS steps" in the iOS enablement plan.

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** do not run the Firestore/Storage rules tests on the emulator (`app_flutter/firebase/rules-test`, `npm test`, `npm run test:*`) while executing this plan; the sandbox cannot run them. Still write or update the rules and their test files as the task says, but skip every step that runs them and every `Expected:` that depends on them; CI (`flutter.yml`, `firebase-deploy.yml`) runs them on push and blocks deploy on failure. Record the skip in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A customer pays a "Chụp ngay" request with MoMo or VNPay for real. The dispatch service builds the provider's signed payment page, verifies every IPN signature (MoMo HMAC-SHA256 POST answered with 204, VNPay HMAC-SHA512 GET answered with `RspCode`), checks the amount, ignores duplicates, and only then moves the request to `searching`. A reconciliation job asks the provider about payments with no IPN after 5 minutes. Refunds from the cancel and no-match rules go back through the provider, with retries and a manual queue. Completed (and fee-bearing cancelled) requests release the photographer's share after the 24-hour dispute window into payout lines; a customer dispute freezes it; ops export payouts to CSV for a manual bank run. The app opens the payment page outside the app, comes back through an App Link / Universal Link (`https://<host>/instant/<id>`) or `photobooking://instant/<id>`, and never trusts the redirect: S48 waits on the Firestore mirror. No polling, and no timer or listener runs while the customer is in the payment app.

**Architecture:** Plan I3's `PaymentGateway` port stays exactly as written; MoMo and VNPay are two new implementations registered in `buildGateways` and pass the shared `runGatewayContract` suite. The flow is unchanged: route → `verifyWebhook` (pure, signature + shape) → `handlePaymentEvent` (idempotent by `payments.status`) → `acknowledge`. One optional second port, `PaymentStatusSource` (`queryPayment`, `queryRefund`), is used only by the reconciliation job. Signatures live in pure modules (`momo-sign.ts`, `vnpay-sign.ts`, `vn-time.ts`) with self-generated test vectors. Two self-rescheduling BullMQ ticks (`payments-reconcile` every minute, `escrow-release` every 5 minutes) join I3's queue. Money stays in the shared tables of `relational-schema.md` §2.4, plus a few columns and two tables (`payment_notifications`, `disputes`). The app gets a real `PaymentLauncher` (`GatewayPaymentLauncher` over plan 2b's `ExternalLauncher`), a `ReturnLinkSource` port over `app_links`, and a foreground-gated mirror provider for `/instant/:id`.

**Tech Stack:** as plan I3 (Node 22, TypeScript 5.7, Fastify 5, Kysely 0.27, BullMQ 5, Vitest 2 + Testcontainers), `node:crypto` HMAC only (no provider SDK). Flutter as plan I5, plus `app_links` ^6.4.0 (new) and plan 2b's `url_launcher` through `ExternalLauncher`.

**Spec:** `docs/superpowers/specs/2026-10-01-instant-booking-design.md` §4 (money, cancel table, "không tin redirect"), §10 (errors: payment failure and timeout, late payment); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3g (escrow `held → released → paid_out`, release rule, dispute window 24 h, refunds only from held money, manual refunds, payouts by admin with an export, ledger, §3g.7 legal note); `docs/superpowers/specs/data-model/README.md` (§2 conventions, §3 `PaymentGateway`, §4 matrix: `payments`, `refunds`, `ledger_entries`, `payouts` Svc-only, §5 use cases `handle_payment_notification`, `refund_payment`, `release_escrow`, `create_payout`, `open_dispute`, `resolve_dispute`); `domain-model.md` (§4 enums, §5 escrow, §6 invariants 11, 12, 15); `relational-schema.md` §2.4; `services/dispatch/api/openapi.yaml` (`paymentWebhook` POST, `paymentWebhookQuery` GET from I3 Task 1, `InstantRequestMirror`); provider documentation: developers.momo.vn (AIO v2: create, IPN, refund, query, result codes) and sandbox.vnpayment.vn/apis (2.1.0: payment URL, IPN, merchant_webapi refund and querydr, response codes).

**Prerequisite (all must be done first):**

- `docs/superpowers/plans/2026-10-01-instant-i3-dispatch-service.md` (all tasks): the `PaymentGateway` family and `buildGateways` (Task 3), `MirrorWriter` (Task 4), `Scheduler`/`JOB_NAMES`/`ManualScheduler` (Task 5), `Deps`, `buildApp`, `wire`, `createLogger`, test helpers (Task 6), the money migration and `Database` types (Task 7), `createRequest`, `handlePaymentEvent`, `expirePayment`, `executeRefund`, `applySplit`, `paymentForRequest`, `heldVnd`, the webhook routes (Task 10), completion settlement (Task 13), cancellation (Task 14), `reconcile()` (Task 15).
- `docs/superpowers/plans/2026-10-01-instant-i4-photographer-app.md`: `instant_models.dart` / `instant_wire.dart` (`InstantRequestView`, `requestViewFromMap`, `PaymentProvider`, `CreatedRequest`, `DispatchException`), `FakeInstantMirror.listenersOf`, `TickingBuilder.debugActiveCount`, `AppButton.danger`, `wireInstantNavigation` and its `routerProvider` edit.
- `docs/superpowers/plans/2026-10-01-instant-i5-customer-app.md`: `PaymentLauncher`/`PaymentStart`/`DevFakePaymentLauncher`/`UnavailablePaymentLauncher`/`FakePaymentLauncher` and `paymentLauncherProvider` (Task 2), `InstantDraft` (Task 5), `InstantBookController.submit` (Task 5), S47 screen (Task 6), `InstantRequestScreen`, `InstantPaymentPendingView`, `InstantPaymentFailedView`, `InstantCustomerActions` (Task 7), `InstantCustomerWorld`, `instantCustomerApp` (test support).
- `docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md`: `ExternalLauncher`, `FakeExternalLauncher`, `externalLauncherProvider` (`lib/data/contact/contact_providers.dart`).
- `docs/superpowers/plans/2026-10-01-ios-enablement.md` Task 1 (`ios/Flutter/Secrets.xcconfig.example`, `test/platform/ios_config_test.dart`) and plan I4's `ios/Runner/Runner.entitlements`.
- **[người dùng]** before Task 13 only: MoMo Business test merchant (partner code, access key, secret key) and a VNPay sandbox terminal (TMN code, hash secret) registered with the staging IPN URLs; a public https staging host for the dispatch service.

## Key decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Port | I3's `PaymentGateway` unchanged; MoMo/VNPay implement it and join `buildGateways`'s `live` list; status queries go through an extra optional port `PaymentStatusSource` (`isStatusSource(g)`) | The task says "implement EXACTLY that interface"; reconciliation needs a query the port does not have, so it is additive and the fake gateway is untouched. |
| 2 | `buildGateways` input | `Pick<ServiceConfig, 'payments' \| 'fakePaymentSecret'> & Partial<Pick<ServiceConfig, 'momo' \| 'vnpay'>>`, optional `GatewayWiring` (fetch, clock, log) | I3's call `buildGateways({ payments: 'live', fakePaymentSecret: '' })` and its test keep working (no provider → `[]`). |
| 3 | MoMo request type | `captureWallet` by default, `payWithMethod` by `MOMO_REQUEST_TYPE`; `autoCapture: true`; `orderId = requestId = payments.id`; refunds `orderId = requestId = refunds.id` | ULIDs fit MoMo's id rules; a retried call is the same order, so MoMo refuses a second charge (40/41). |
| 4 | Which URL the app opens | `paymentUrl` = MoMo `payUrl` (https) or the signed VNPay URL; the MoMo page itself offers "Mở ứng dụng MoMo" | `CreatePaymentResult` has one URL; no contract change and no `LSApplicationQueriesSchemes` for `momo`. |
| 5 | VNPay `vnp_CreateDate` | The ULID time of `payments.id`, in GMT+7; refund and querydr recompute it as `vnp_TransactionDate` | `RefundInput` carries no stored provider data; payments.id is created with the request clock. |
| 6 | VNPay `vnp_IpAddr` | `VNPAY_SERVER_IP` (the service's egress IP) | `CreatePaymentInput` has no client IP and must not change; flagged for VNPay to confirm (open question 3). |
| 7 | VNPay order info | ASCII only (diacritics stripped, letters/digits/spaces) | VNPay asks for "không dấu, không ký tự đặc biệt"; it also removes every URL-encoder difference from the hash. |
| 8 | Hash of empty VNPay values | Skipped (like VNPay's Java sample) | Cancelled-payment IPNs carry empty `vnp_BankTranNo`/`vnp_CardType`; cross-checked in Task 13. |
| 9 | Return URL | `returnUrlFor(id)` = `${APP_LINK_BASE_URL}/instant/<id>` (https, VNPay requires it) when configured, else I3's `photobooking://instant/<id>`; the service serves a small return page plus `assetlinks.json` / `apple-app-site-association` | Verified App Links / Universal Links open the app straight from the browser; the page is the fallback; neither reads the provider's query. |
| 10 | Gateway down at creation | `payment-timeout` scheduled before calling the provider; on failure payment `failed`, request `payment_failed`, `500 internal "payment provider unavailable"` | Otherwise the customer is blocked 15 minutes by "one active request per customer". |
| 11 | Money after "failed" | `handlePaymentEvent` accepts `paid` for a `failed` payment: capture, then full refund (same path as I3's late payment) | Reconciliation gives up after 2 h and a create error marks `failed`; a provider can still confirm money later. |
| 12 | Reconciliation | Every minute; `created` payments ≥ 5 min old; backoff 5·2^min(n,4) min; ≤ 24 per tick, 4 at once; give up (failed) after 2 h | Lost IPNs are rare; the budget keeps a tick < 48 s even if every call times out (8 s). |
| 13 | Refund follow-up | Provider answer kept on `refunds` (`provider_status`, `attempts`, `provider_ref`); `pending` answers polled; exhausted retries resubmitted after 2 h (≤ 20 attempts); unconfirmed after 24 h → `manual` | Spec main §3g.3 "đánh dấu manual và tạo việc cho admin". |
| 14 | IPN log | `payment_notifications`: provider, payment id, kind, outcome, amount, provider ref, source; no body, no signature | Evidence for idempotency and amount mismatches, the ops list, and the webhook timing. |
| 15 | Ledger for release and payout | `escrow_released +share` (owner = photographer), `payout_paid −amount` (owner), `adjustment −x` note `fee_reversal` when a dispute refund exceeds the share; a payout hold is a status (`on_hold`, `disputed`), not an entry | Append-only ledger records money movements only (spec main §3g.5); no new ledger type. |
| 16 | Dispute | `POST /v1/requests/{id}/dispute` (customer, ≤ 24 h after `completed`, state machine `open_dispute`); ops resolve with the CLI (`release` or `refund <vnd>`) | "Endpoint/flag only, ops UI later"; resolution rules beyond release/refund are product decisions. |
| 17 | Payout execution | Out of scope: `ops payouts-export` writes a CSV (no full account number) and moves payouts to `processing`; `payout-paid` / `payout-failed` record the bank result | Spec main §3g.4 manual phase; legal open question §3g.7. |
| 18 | App provider choice | `--dart-define=PAYMENT_PROVIDERS=momo,vnpay`; chips on S47 when two; the choice is session state (`paymentChoiceProvider`) | Mirrors S07's MoMo/VNPay choice in the mock. |
| 19 | App waiting | S48 `payment` state shows the gateway, a fixed deadline (no ticking), "Mở lại trang thanh toán" (same order) and "Huỷ yêu cầu"; the mirror listener is closed while the app is in the background and reopened on resume | No polling; nothing runs behind the payment app; Firestore delivers the current document on resume. |

## Global Constraints

- Server commands run from `services/dispatch/` (Node ≥ 22.11, Docker for the PostgreSQL/Redis suites), app commands from `app_flutter/`; before any command, once per shell from the repo root: `source scripts/env.sh >/dev/null && export HOME="$PWD/.home"` (and `export PATH="$PWD/.flutter/bin:$PATH"` for Flutter).
- **What was verified while writing this plan (Claude Code sandbox, no Docker daemon, no device):** plan I2 and I3's code blocks were extracted into a staged tree, every server file of this plan was added and the whole tree type-checks (`tsc --noEmit`, 0 errors) against the contract with I3 Task 1 and this plan's Task 1 applied; the container-free suites pass with Vitest 2.1.9: `signatures` 11, `momo-gateway` 12, `vnpay-gateway` 10, `config-payments` 7, `logging` 2, plus I3's `fake-gateway` 8 and `config` 5. All HMAC vectors were also checked with `openssl dgst -hmac`. The pure Dart parts (`PaymentConfig.parse`, `instantReturnTarget`) were run with the project's Dart SDK (12 checks). **Not run here:** the PostgreSQL/Redis suites (Tasks 6–12, 18), the Flutter widget and platform tests (Tasks 14–18; they depend on plan I4/I5 code that is not in the repo yet), the sandboxes (Task 13), devices.
- **Test vectors are self-generated:** computed with this plan's own signing code from the providers' documented field order and confirmed with `openssl`; they pin our encoding, not the providers' agreement. Task 13 cross-checks them with the real sandboxes; `PAYMENT_ENV=production` must not be set anywhere until Task 13's checklist is complete and recorded in the PR.
- **Secrets:** provider keys only from the environment (`MOMO_*`, `VNPAY_*`), checked for length at boot, never in `raw`, error messages, logs or responses; logs drop URL query strings (VNPay puts `vnp_SecureHash` there, `GET /v1/packages` puts coordinates there) and redact `secretKey`, `accessKey`, `hashSecret`, `signature`, `vnp_SecureHash`. `.env.example` holds self-made test values only.
- **Never trust the redirect:** only a verified IPN or a status query answer moves money state; the return page and the app's link handler ignore every provider query parameter.
- **Money:** integer VND (VNPay amounts ×100 only at the boundary), every settlement and resolution keeps `refunds + photographer + platform = collected`; ledger append-only; refunds only from what is held; a payment already released is never refunded here (spec main §3g.3, adjustment on a later payout).
- **App rules (CLAUDE.md):** `package:photobooking/...` imports, features import `core/core.dart`; strings in `app_vi.arb`; one primary action per screen (S48 has none); cancel is a red text button and the confirmation a red `AppButton.danger`; no Firebase import outside adapters; phone numbers untouched.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Signature reference (from the providers' documentation)

| Call | Algorithm | Signed string (exact order) |
|---|---|---|
| MoMo create `POST /v2/gateway/api/create` | HMAC-SHA256(secretKey), lower hex | `accessKey=…&amount=…&extraData=…&ipnUrl=…&orderId=…&orderInfo=…&partnerCode=…&redirectUrl=…&requestId=…&requestType=…` |
| MoMo IPN (POST JSON to `ipnUrl`, answer HTTP 204) | same | `accessKey&amount&extraData&message&orderId&orderInfo&orderType&partnerCode&payType&requestId&responseTime&resultCode&transId` (each `key=value`) |
| MoMo refund `POST /v2/gateway/api/refund` | same | `accessKey&amount&description&orderId&partnerCode&requestId&transId` |
| MoMo query `POST /v2/gateway/api/query` | same | `accessKey&orderId&partnerCode&requestId` |
| VNPay payment URL and IPN (GET) | HMAC-SHA512(hashSecret), hex | every `vnp_*` except `vnp_SecureHash`, `vnp_SecureHashType` and empty values, sorted by key, `key=value` URL-encoded (`encodeURIComponent`, space → `+`), joined by `&` |
| VNPay refund `POST merchant_webapi/api/transaction` | HMAC-SHA512, hex | `vnp_RequestId\|vnp_Version\|vnp_Command\|vnp_TmnCode\|vnp_TransactionType\|vnp_TxnRef\|vnp_Amount\|vnp_TransactionNo\|vnp_TransactionDate\|vnp_CreateBy\|vnp_CreateDate\|vnp_IpAddr\|vnp_OrderInfo` |
| VNPay refund answer | same | `vnp_ResponseId\|vnp_Command\|vnp_ResponseCode\|vnp_Message\|vnp_TmnCode\|vnp_TxnRef\|vnp_Amount\|vnp_BankCode\|vnp_PayDate\|vnp_TransactionNo\|vnp_TransactionType\|vnp_TransactionStatus\|vnp_OrderInfo` |
| VNPay querydr request | same | `vnp_RequestId\|vnp_Version\|vnp_Command\|vnp_TmnCode\|vnp_TxnRef\|vnp_TransactionDate\|vnp_CreateDate\|vnp_IpAddr\|vnp_OrderInfo` |
| VNPay querydr answer | same | refund-answer order + `\|vnp_PromotionCode\|vnp_PromotionAmount` |

Result codes used (to re-check in Task 13): MoMo `0` success; `1000`, `7000`, `7002`, `9000` not final; `40`, `41`, `43` duplicate/in progress; `42` order not found; `99` unknown (retry); anything else failed. VNPay IPN success = `vnp_ResponseCode 00` and `vnp_TransactionStatus 00` (`24` = customer cancelled); our IPN answers `00` confirmed, `02` already confirmed, `01` order not found, `04` invalid amount, `97` invalid signature, `99` other; refund `00` done, `94` duplicate (pending), `99` retry, others manual; querydr `91` not found, status `00` paid, `01` pending, `02` failed; refund status `05` processing, `06` sent to bank, `09` rejected.

Self-generated vectors (keys in `test/payments/fixtures.ts`: MoMo `NAGTEST` / `nagTestAccessKey` / `nag-test-momo-secret-0123456789`; VNPay `NAGTEST1` / `NAGTESTVNPAYHASHSECRET0123456789`; payment `01M3V7ME00PAYMENT000000001`, request `01M3V7ME00REQ0000000000001`, refund `01M3V7ME00REFVND0000000001`, ULID time 2026-10-01T08:00:00Z):

| Vector | Expected |
|---|---|
| MoMo create (600.000₫, captureWallet) | `542c94dc0a9253dc811321fae43eb774f060cf5a5334b3a476746b433631f3de` |
| MoMo IPN paid (transId 4088878653) | `c527bd66141558305e46256e2a3420a55eb95e061f38b4863e56da1d8cf64b49` |
| MoMo IPN declined (1006) | `3a0ed96e5859892a89c8c841eaa2411ecf5b1ddf2ce6e4a253800e30068a078b` |
| MoMo refund 480.000₫ | `cc12ac103d7999a9c6a524f5bd77e740275a24f8ffeca8140d6b002f2d6a8b93` |
| MoMo query | `d560af58b857037a1eff0df13eeac544d33368ac8e0158769367dda5bba254fb` |
| VNPay payment URL | `b1e2d047…63f87fee` (full value in Task 2) |
| VNPay IPN paid / cancelled (24) | `45856385…21db5043` / `7103710c…d228deb6` |
| VNPay refund request / answer | `1658ef34…59cb9ed6` / `3de477b4…e88af9d1` |
| VNPay querydr request / answer | `afbadd94…763499e6` / `9f400227…e6286c7501` |

## File Structure

| File | Responsibility |
|---|---|
| `services/dispatch/api/openapi.yaml`, `docs/superpowers/specs/data-model/relational-schema.md`, `domain-model.md`, `README.md` (modify) | `openDispute`, mirror payment fields; §2.4 columns and tables (Task 1) |
| `services/dispatch/src/payments/vn-time.ts`, `momo-sign.ts`, `vnpay-sign.ts` (create) | Pure signatures, Vietnam time, ULID time |
| `services/dispatch/src/payments/status.ts`, `momo.ts`, `vnpay.ts` (create) | `PaymentStatusSource`, `PaymentProviderError`, `postJson`; the two gateways |
| `services/dispatch/src/payments/registry.ts`, `src/config.ts`, `src/wiring.ts`, `.env.example`, `package.json`, `tsconfig.json`, `vitest.unit.config.ts` (modify / create) | Provider config, registry, log redaction, scripts |
| `services/api/migrations/1790899300001_payments_live.sql`, `services/api/test/migrations.test.ts`, `services/dispatch/src/db/database.ts`, `test/helpers.ts` (create / modify) | Schema additions and types |
| `services/dispatch/src/payments/window.ts`, `notifications.ts` (create); `src/requests/create.ts`, `publish.ts`, `src/payments/events.ts`, `ledger.ts`, `src/routes/payments.ts` (modify) | Gateway failure at creation, late capture, IPN log and timing, refund tracking, mirror payment fields |
| `services/dispatch/src/payments/reconcile.ts`, `escrow.ts`, `disputes.ts`, `payouts.ts` (create); `src/jobs/scheduler.ts`, `handlers.ts` (modify) | Ticks: reconciliation, refund poller, release, payout lines; disputes; payouts |
| `services/dispatch/src/routes/disputes.ts`, `app-links.ts` (create); `src/app.ts`, `src/server.ts` (modify) | Dispute route, return page and App Link files |
| `services/dispatch/src/tools/ops.ts`, `sandbox-check.ts` (create) | Ops CLI, sandbox cross-check |
| `services/dispatch/test/payments/*`, `test/config-payments.test.ts`, `test/logging.test.ts`, `test/app-links.test.ts` (create) | Tests |
| `app_flutter/pubspec.yaml`, `lib/data/instant/payment_config.dart`, `gateway_payment_launcher.dart`, `return_links.dart` (create / modify) | Real launcher, provider choice, return links |
| `app_flutter/lib/data/instant/instant_models.dart`, `instant_wire.dart`, `instant_providers.dart` (modify) | Mirror fields, providers |
| `app_flutter/lib/features/instant/instant_return_links.dart`, `instant_foreground.dart`, `payment_method_picker.dart` (create); `instant_request_screen.dart`, `views/instant_searching_view.dart`, `instant_draft.dart`, `instant_book_controller.dart`, `instant_book_screen.dart`, `lib/app/router.dart`, `lib/l10n/app_vi.arb` (modify) | Link wiring, foreground gate, S47 picker, S48 payment wait |
| `app_flutter/android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `ios/Flutter/Debug.xcconfig`, `Release.xcconfig`, `Secrets.xcconfig.example` (modify) | App Link / Universal Link / URL scheme |
| `app_flutter/test/...` (create) | Data, widget, platform and battery tests |
| `docs/design/ui-mock.html`, `docs/superpowers/specs/2026-10-01-instant-booking-design.md`, `2026-10-01-remaining-screens.md`, `docs/testing/battery-and-performance.md`, `services/dispatch/README.md` (modify) | Docs alignment |

---

### Task 1: Contract and schema for live payments (documentation only)

**Files:**
- Modify: `services/dispatch/api/openapi.yaml`, `services/dispatch/test/contract.test.ts`, `docs/superpowers/specs/data-model/relational-schema.md`, `docs/superpowers/specs/data-model/domain-model.md`, `docs/superpowers/specs/data-model/README.md`

**Interfaces:**
- Produces: operation `openDispute` (`POST /v1/requests/{requestId}/dispute`, body `DisputeBody {reason 1..500}`, 204 / 403 / 404 / 409); `InstantRequestMirror.paymentProvider` (nullable `PaymentProvider`) and `paymentExpiresAt` (nullable `Instant`, only while `pending_payment`); §2.4 columns `payments.checked_at`, `check_count`, `refunds.provider_ref`, `provider_status`, `attempts`, `updated_at`, `resolved_by`, `resolved_reference`, tables `payment_notifications`, `disputes`, indexes `ix_payments_unconfirmed`, `ix_payments_release_due`, `ix_refunds_open`, `ix_payment_notifications_payment`, `ix_payment_notifications_attention`, `ux_disputes_open`, `ix_disputes_payment`. No new `ErrorCode` (the app's enum test in plan I4 stays green).

- [ ] **Step 1: Edit `services/dispatch/api/openapi.yaml`**

Directly above the line `  /v1/requests/{requestId}/location:` insert:

```yaml
  /v1/requests/{requestId}/dispute:
    post:
      operationId: openDispute
      summary: Khách khiếu nại trong 24 giờ sau khi hoàn thành (kế hoạch I6); giữ tiền của nhiếp ảnh gia tới khi admin xử lý
      parameters: [ { $ref: '#/components/parameters/RequestId' } ]
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/DisputeBody' }
      responses:
        '204': { description: Đã mở khiếu nại; yêu cầu chuyển sang disputed }
        '403': { $ref: '#/components/responses/Error' }
        '404': { $ref: '#/components/responses/Error' }
        '409':
          description: 'conflict với details {"reason": "..."}: chưa hoàn thành, quá 24 giờ, hoặc đã khiếu nại'
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
```

Directly above the line `    CancelRule:` insert:

```yaml
    DisputeBody:
      type: object
      required: [reason]
      additionalProperties: false
      properties:
        reason: { type: string, minLength: 1, maxLength: 500 }
```

In `InstantRequestMirror`, directly below `        refundVnd: { allOf: [ { $ref: '#/components/schemas/Vnd' } ], nullable: true }` insert:

```yaml
        paymentProvider:
          allOf: [ { $ref: '#/components/schemas/PaymentProvider' } ]
          nullable: true
          description: Cổng khách đã chọn (S48 "Cổng MoMo chưa báo về"); kế hoạch I6
        paymentExpiresAt:
          allOf: [ { $ref: '#/components/schemas/Instant' } ]
          nullable: true
          description: Hạn thanh toán, chỉ khi pending_payment (S48); kế hoạch I6
```

In `services/dispatch/test/contract.test.ts` (I3), add `'openDispute'` to the `PENDING` set (its route arrives in Task 10, which removes it again), so the contract suite stays green in between.

- [ ] **Step 2: Edit `relational-schema.md` §2.4**

In `create table payments`, replace

```sql
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index ix_payments_subject on payments (subject_type, subject_id);
create index ix_payments_release on payments (escrow_status, release_after) where escrow_status = 'held';
```

with

```sql
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  checked_at      timestamptz,                    -- lần hỏi trạng thái cổng gần nhất (đối soát, kế hoạch I6)
  check_count     int not null default 0
);
create index ix_payments_subject on payments (subject_type, subject_id);
create index ix_payments_release on payments (escrow_status, release_after) where escrow_status = 'held';
create index ix_payments_unconfirmed on payments (created_at) where status = 'created';
create index ix_payments_release_due on payments (release_after) where released_at is null and payee_id is not null;
```

In `create table refunds`, replace

```sql
  manual     boolean not null default false,
  created_at timestamptz not null default now()
);
```

with

```sql
  manual     boolean not null default false,
  created_at timestamptz not null default now(),
  provider_ref       text,                         -- mã hoàn của cổng
  provider_status    text,                         -- câu trả lời gần nhất: done | pending | failed:<lý do> | manual:<lý do>
  attempts           int not null default 0,
  updated_at         timestamptz not null default now(),
  resolved_by        text references users(id),    -- admin xử lý tay (hàng đợi manual)
  resolved_reference text                          -- mã chuyển khoản khi hoàn tay
);
create index ix_refunds_open on refunds (created_at) where status = 'pending';
```

Directly after `create index ix_ledger_owner on ledger_entries (account_owner_id, at);` insert:

```sql

create table payment_notifications (              -- mỗi IPN hoặc câu trả lời truy vấn; không lưu thân, không lưu chữ ký
  id           text primary key,
  provider     text not null check (provider in ('momo','vnpay','fake')),
  payment_id   text,                               -- không FK: unknown_payment giữ id cổng gửi
  kind         text check (kind in ('paid','failed')),
  outcome      text not null check (outcome in ('processed','duplicate','unknown_payment','amount_mismatch','invalid_signature','malformed','error')),
  amount       bigint,
  provider_ref text,
  source       text not null check (source in ('webhook','query')),
  received_at  timestamptz not null default now()
);
create index ix_payment_notifications_payment on payment_notifications (payment_id, received_at);
create index ix_payment_notifications_attention on payment_notifications (received_at) where outcome in ('amount_mismatch','unknown_payment','error');

create table disputes (                           -- khiếu nại trong cửa sổ 24 giờ (spec chính 3g.2)
  id           text primary key,
  subject_type text not null check (subject_type in ('booking','event_registration','instant_request')),
  subject_id   text not null,
  payment_id   text not null references payments(id),
  opened_by    text not null references users(id),
  reason       text not null check (length(reason) between 1 and 500),
  status       text not null default 'open' check (status in ('open','resolved')),
  resolution   text check (resolution in ('released','refunded','partially_refunded')),
  refund_vnd   bigint check (refund_vnd >= 0),
  resolved_by  text references users(id),
  note         text,
  opened_at    timestamptz not null default now(),
  resolved_at  timestamptz,
  check ((status = 'open') = (resolved_at is null))
);
create unique index ux_disputes_open on disputes (subject_type, subject_id) where status = 'open';
create index ix_disputes_payment on disputes (payment_id) where status = 'open';
```

In §5 (export order) replace `` `ledger_entries` → `reviews` `` with `` `ledger_entries`, `payment_notifications`, `disputes` → `reviews` ``.

- [ ] **Step 3: Edit `domain-model.md`**

In §2.4, replace the `Refund` row with:

```
| `Refund` | `id` PK, `paymentId` FK, `amount: Money`, `percent`, `status`, `manual`, `providerRef?`, `providerStatus?`, `attempts`, `createdAt`, `updatedAt`, `resolvedBy?`, `resolvedReference?` | `manual`: hàng đợi hoàn tay của admin |
| `PaymentNotification` | `id` PK, `provider`, `paymentId?`, `kind?` (`paid`/`failed`), `outcome: PaymentNotificationOutcome`, `amount?: Money`, `providerRef?`, `source` (`webhook`/`query`), `receivedAt` | Nhật ký IPN và truy vấn trạng thái; không lưu thân, không chữ ký |
| `Dispute` | `id` PK, `subjectType: PaymentSubject`, `subjectId`, `paymentId` FK, `openedBy`, `reason`, `status: DisputeStatus`, `resolution?: DisputeResolution`, `refundVnd?: Money`, `resolvedBy?`, `note?`, `openedAt`, `resolvedAt?` | Một khiếu nại mở mỗi đối tượng |
```

and in the `Payment` row replace `` `idempotencyKey`, `createdAt`, `updatedAt` `` with `` `idempotencyKey`, `createdAt`, `updatedAt`, `checkedAt?`, `checkCount` ``.

In §4, directly below the `RefundStatus` row insert:

```
| `PaymentNotificationOutcome` | `processed`, `duplicate`, `unknown_payment`, `amount_mismatch`, `invalid_signature`, `malformed`, `error` | Kết quả xử lý một IPN (cổng nhận câu trả lời tương ứng) |
| `DisputeStatus` | `open`, `resolved` | |
| `DisputeResolution` | `released`, `refunded`, `partially_refunded` | |
```

In §5 "Tiền treo (escrow)", directly below `Mỗi chuyển ghi `LedgerEntry` bất biến. `released` còn gọi là "sắp nhận" ở S43.` add:

```
Bút toán (kế hoạch I6): thả tiền `escrow_released +phần nhiếp ảnh gia` (`accountOwnerId` = nhiếp ảnh gia); chi trả `payout_paid −số tiền lô` (`accountOwnerId`, `payoutId`); hoàn khi khiếu nại vượt phần nhiếp ảnh gia thì phần còn lại lấy từ phí nền tảng: `adjustment −x` ghi chú `fee_reversal`. "Giữ chi trả" không phải bút toán (không có tiền chuyển): `escrowStatus = disputed` hoặc `Payout.status = on_hold`.
```

In §6 append:

```
16. Sau mọi lần thả tiền hoặc xử lý khiếu nại: Σ hoàn + phần nhiếp ảnh gia đã thả + phí nền tảng (sau `fee_reversal`) = số đã thu của khoản đó.
```

- [ ] **Step 4: Edit `README.md` §4 (matrix)**

Directly below the row `` | `payouts`, `payout_items` | người nhận, A | Svc / A (duyệt) | `` insert:

```
| `payment_notifications` | A | Svc (chỉ thêm) |
| `disputes` | P (người mở và người nhận tiền), A | Svc (`open_dispute` cho khách; `resolve_dispute` chỉ A) |
```

- [ ] **Step 5: Check the edits**

Run (repo root):

```bash
grep -c "operationId:" services/dispatch/api/openapi.yaml
grep -n "paymentExpiresAt\|DisputeBody:" services/dispatch/api/openapi.yaml
grep -c "create table payment_notifications\|create table disputes" docs/superpowers/specs/data-model/relational-schema.md
```

Expected: `18` (I3's 17 + `openDispute`); two lines (`    DisputeBody:` and `        paymentExpiresAt:`); `2`.

- [ ] **Step 6: Commit**

```bash
git add services/dispatch/api/openapi.yaml services/dispatch/test/contract.test.ts docs/superpowers/specs/data-model
git commit -m "docs(payments): dispute operation, mirror payment fields, reconciliation and dispute tables for live gateways

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Signature primitives, Vietnam time and the test vectors

**Files:**
- Create: `services/dispatch/src/payments/vn-time.ts`, `services/dispatch/src/payments/momo-sign.ts`, `services/dispatch/src/payments/vnpay-sign.ts`, `services/dispatch/test/payments/fixtures.ts`, `services/dispatch/test/payments/signatures.test.ts`, `services/dispatch/vitest.unit.config.ts`
- Modify: `services/dispatch/package.json` (script `test:unit`), `services/dispatch/tsconfig.json` (include the new config)

**Interfaces:**
- Produces: `vnTimestamp(at): string`, `parseVnTimestamp(s): Date | null`, `ulidTime(id): Date | null`; `MOMO_CREATE_FIELDS`, `MOMO_IPN_FIELDS`, `MOMO_REFUND_FIELDS`, `MOMO_QUERY_FIELDS`, `momoRawSignature(fields, values)`, `hmacSha256Hex`, `momoSign(secret, fields, values)`, `sameHex(a, b)`; `VNP_REFUND_FIELDS`, `VNP_REFUND_RESPONSE_FIELDS`, `VNP_QUERY_FIELDS`, `VNP_QUERY_RESPONSE_FIELDS`, `vnpEncode`, `vnpSignData(params)`, `hmacSha512Hex`, `vnpSecureHash(secret, params)`, `vnpPipeData`, `vnpPipeHash`, `asciiOrderInfo(text)`; test fixtures `PAY`, `REQ`, `REF`, `T0`, `MOMO_TEST`, `VNPAY_TEST`; `npm run test:unit` (suites without Docker).

The expected values below were produced by these functions in a scratch directory while writing the plan and confirmed with `openssl dgst -sha256|-sha512 -hmac <key>` over the printed raw strings. They are **self-generated**: they fix field order, encoding and hex output; agreement with MoMo and VNPay is proven in Task 13.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/fixtures.ts
// Self-made test credentials (never real keys). PAY/REQ/REF are ULIDs whose time part is
// 2026-10-01T08:00:00.000Z (= test/helpers.ts T0), so VNPay's vnp_CreateDate is 20261001150000.
export const PAY = '01M3V7ME00PAYMENT000000001';
export const REQ = '01M3V7ME00REQ0000000000001';
export const REF = '01M3V7ME00REFVND0000000001';
export const T0 = new Date('2026-10-01T08:00:00.000Z');

export const MOMO_TEST = { partnerCode: 'NAGTEST', accessKey: 'nagTestAccessKey', secretKey: 'nag-test-momo-secret-0123456789' } as const;
export const VNPAY_TEST = { tmnCode: 'NAGTEST1', hashSecret: 'NAGTESTVNPAYHASHSECRET0123456789' } as const;
```

```ts
// services/dispatch/test/payments/signatures.test.ts
// Test vectors are SELF-GENERATED (plan I6): computed with this module and cross-checked with
// `openssl dgst -hmac` while writing the plan. They prove field order, encoding and hex output are
// stable; they do not prove MoMo/VNPay agree — Task 12 checks that against the sandboxes.
import { describe, expect, it } from 'vitest';

import {
  MOMO_CREATE_FIELDS, MOMO_IPN_FIELDS, MOMO_QUERY_FIELDS, MOMO_REFUND_FIELDS, momoRawSignature, momoSign, sameHex,
} from '../../src/payments/momo-sign.js';
import { parseVnTimestamp, ulidTime, vnTimestamp } from '../../src/payments/vn-time.js';
import {
  VNP_QUERY_FIELDS, VNP_QUERY_RESPONSE_FIELDS, VNP_REFUND_FIELDS, VNP_REFUND_RESPONSE_FIELDS, asciiOrderInfo, vnpPipeData,
  vnpPipeHash, vnpSecureHash, vnpSignData,
} from '../../src/payments/vnpay-sign.js';
import { MOMO_TEST, PAY, REF, REQ, VNPAY_TEST } from './fixtures.js';

describe('MoMo raw signature strings and HMAC-SHA256 (self-generated vectors)', () => {
  const create = {
    accessKey: MOMO_TEST.accessKey, amount: 600000, extraData: '', ipnUrl: 'https://dispatch.example.test/v1/payments/webhook/momo',
    orderId: PAY, orderInfo: `Chụp ngay p60 - ${REQ}`, partnerCode: MOMO_TEST.partnerCode,
    redirectUrl: `https://links.example.test/instant/${REQ}`, requestId: PAY, requestType: 'captureWallet',
  };

  it('create', () => {
    expect(momoRawSignature(MOMO_CREATE_FIELDS, create)).toBe(
      `accessKey=nagTestAccessKey&amount=600000&extraData=&ipnUrl=https://dispatch.example.test/v1/payments/webhook/momo&orderId=${PAY}&orderInfo=Chụp ngay p60 - ${REQ}&partnerCode=NAGTEST&redirectUrl=https://links.example.test/instant/${REQ}&requestId=${PAY}&requestType=captureWallet`,
    );
    expect(momoSign(MOMO_TEST.secretKey, MOMO_CREATE_FIELDS, create)).toBe('542c94dc0a9253dc811321fae43eb774f060cf5a5334b3a476746b433631f3de');
  });

  it('IPN (paid and declined)', () => {
    const ipn = {
      accessKey: MOMO_TEST.accessKey, amount: 600000, extraData: '', message: 'Thành công.', orderId: PAY, orderInfo: `Chụp ngay p60 - ${REQ}`,
      orderType: 'momo_wallet', partnerCode: MOMO_TEST.partnerCode, payType: 'qr', requestId: PAY, responseTime: 1790841722000, resultCode: 0,
      transId: 4088878653,
    };
    expect(momoSign(MOMO_TEST.secretKey, MOMO_IPN_FIELDS, ipn)).toBe('c527bd66141558305e46256e2a3420a55eb95e061f38b4863e56da1d8cf64b49');
    const declined = { ...ipn, message: 'Giao dịch bị từ chối bởi người dùng.', resultCode: 1006, transId: 4088878654 };
    expect(momoSign(MOMO_TEST.secretKey, MOMO_IPN_FIELDS, declined)).toBe('3a0ed96e5859892a89c8c841eaa2411ecf5b1ddf2ce6e4a253800e30068a078b');
  });

  it('refund and query', () => {
    const refund = { accessKey: MOMO_TEST.accessKey, amount: 480000, description: 'instant refund', orderId: REF, partnerCode: MOMO_TEST.partnerCode, requestId: REF, transId: 4088878653 };
    expect(momoRawSignature(MOMO_REFUND_FIELDS, refund)).toBe(
      `accessKey=nagTestAccessKey&amount=480000&description=instant refund&orderId=${REF}&partnerCode=NAGTEST&requestId=${REF}&transId=4088878653`,
    );
    expect(momoSign(MOMO_TEST.secretKey, MOMO_REFUND_FIELDS, refund)).toBe('cc12ac103d7999a9c6a524f5bd77e740275a24f8ffeca8140d6b002f2d6a8b93');
    const query = { accessKey: MOMO_TEST.accessKey, orderId: PAY, partnerCode: MOMO_TEST.partnerCode, requestId: `${PAY}Q1790842200000` };
    expect(momoSign(MOMO_TEST.secretKey, MOMO_QUERY_FIELDS, query)).toBe('d560af58b857037a1eff0df13eeac544d33368ac8e0158769367dda5bba254fb');
  });

  it('sameHex ignores case and refuses different lengths', () => {
    expect(sameHex('ABCD', 'abcd')).toBe(true);
    expect(sameHex('abcd', 'abc')).toBe(false);
  });
});

describe('VNPay 2.1.0 hash data and HMAC-SHA512 (self-generated vectors)', () => {
  it('payment URL: sorted, encoded with + for spaces', () => {
    const pay = {
      vnp_Version: '2.1.0', vnp_Command: 'pay', vnp_TmnCode: VNPAY_TEST.tmnCode, vnp_Amount: '60000000', vnp_CreateDate: '20261001150000',
      vnp_CurrCode: 'VND', vnp_IpAddr: '203.0.113.10', vnp_Locale: 'vn', vnp_OrderInfo: `Chup ngay p60 ${REQ}`, vnp_OrderType: 'other',
      vnp_ReturnUrl: `https://links.example.test/instant/${REQ}`, vnp_ExpireDate: '20261001151500', vnp_TxnRef: PAY,
    };
    expect(vnpSignData(pay)).toBe(
      `vnp_Amount=60000000&vnp_Command=pay&vnp_CreateDate=20261001150000&vnp_CurrCode=VND&vnp_ExpireDate=20261001151500&vnp_IpAddr=203.0.113.10&vnp_Locale=vn&vnp_OrderInfo=Chup+ngay+p60+${REQ}&vnp_OrderType=other&vnp_ReturnUrl=https%3A%2F%2Flinks.example.test%2Finstant%2F${REQ}&vnp_TmnCode=NAGTEST1&vnp_TxnRef=${PAY}&vnp_Version=2.1.0`,
    );
    expect(vnpSecureHash(VNPAY_TEST.hashSecret, pay)).toBe(
      'b1e2d047b6f8710229cf9311c8fe45d7c57e91ecb00b5a6013675847239432e9acb1f93da141668cf7e81484838ff4eeeb4eea2a3f937dbad05ee35a63f87fee',
    );
  });

  it('IPN: vnp_SecureHash and vnp_SecureHashType are excluded, empty values are skipped', () => {
    const ipn = {
      vnp_Amount: '60000000', vnp_BankCode: 'NCB', vnp_BankTranNo: 'VNP14600001', vnp_CardType: 'ATM', vnp_OrderInfo: `Chup ngay p60 ${REQ}`,
      vnp_PayDate: '20261001150230', vnp_ResponseCode: '00', vnp_TmnCode: VNPAY_TEST.tmnCode, vnp_TransactionNo: '14600001',
      vnp_TransactionStatus: '00', vnp_TxnRef: PAY,
    };
    const hash = '458563856fd31ce7bfca8aeefa696a8428b0ef6d5b4eb3a7d1ae1c028b6645db4d83c35a794b67b28100f6c707de38f94e2295959b3961edeb5b13bf21db5043';
    expect(vnpSecureHash(VNPAY_TEST.hashSecret, ipn)).toBe(hash);
    expect(vnpSecureHash(VNPAY_TEST.hashSecret, { ...ipn, vnp_SecureHash: hash, vnp_SecureHashType: 'HmacSHA512' })).toBe(hash);
    const cancelled = { ...ipn, vnp_BankTranNo: '', vnp_CardType: '', vnp_PayDate: '20261001150410', vnp_ResponseCode: '24', vnp_TransactionNo: '0', vnp_TransactionStatus: '02' };
    expect(vnpSecureHash(VNPAY_TEST.hashSecret, cancelled)).toBe(
      '7103710c2fe40d49326293774f05a116f5ee0e39619667b5671550d54c1ea361aa4fb952c6358e3db49f7661314bf0e7a84b3fdf94e3919b058a9e9ed228deb6',
    );
  });

  it('refund request and response checksums (pipe-joined, documented order)', () => {
    const rf = {
      vnp_RequestId: REF, vnp_Version: '2.1.0', vnp_Command: 'refund', vnp_TmnCode: VNPAY_TEST.tmnCode, vnp_TransactionType: '03', vnp_TxnRef: PAY,
      vnp_Amount: '48000000', vnp_TransactionNo: '14600001', vnp_TransactionDate: '20261001150000', vnp_CreateBy: 'dispatch',
      vnp_CreateDate: '20261001153000', vnp_IpAddr: '203.0.113.10', vnp_OrderInfo: `Hoan tien ${REF}`,
    };
    expect(vnpPipeData(VNP_REFUND_FIELDS, rf)).toBe(
      `${REF}|2.1.0|refund|NAGTEST1|03|${PAY}|48000000|14600001|20261001150000|dispatch|20261001153000|203.0.113.10|Hoan tien ${REF}`,
    );
    expect(vnpPipeHash(VNPAY_TEST.hashSecret, VNP_REFUND_FIELDS, rf)).toBe(
      '1658ef34b27a052ae50781113802dbc2af708b0267776048122bd81815c6086382aad5f6996092bcd36cddab6ac70a19950e1a09011f72099e110ae859cb9ed6',
    );
    const resp = {
      vnp_ResponseId: 'RESP0001', vnp_Command: 'refund', vnp_ResponseCode: '00', vnp_Message: 'Refund success', vnp_TmnCode: VNPAY_TEST.tmnCode,
      vnp_TxnRef: PAY, vnp_Amount: '48000000', vnp_BankCode: 'NCB', vnp_PayDate: '20261001153001', vnp_TransactionNo: '14600002',
      vnp_TransactionType: '03', vnp_TransactionStatus: '05', vnp_OrderInfo: `Hoan tien ${REF}`,
    };
    expect(vnpPipeHash(VNPAY_TEST.hashSecret, VNP_REFUND_RESPONSE_FIELDS, resp)).toBe(
      '3de477b475fbcb86137a20a414b3665b292079216abfa455fb8c59e15afcc72f783622434bbe342f99b52539011f5e7eea605b6781ff425f523e2321e88af9d1',
    );
  });

  it('querydr request and response checksums (empty promotion fields stay as empty segments)', () => {
    const q = {
      vnp_RequestId: `Q${PAY}`, vnp_Version: '2.1.0', vnp_Command: 'querydr', vnp_TmnCode: VNPAY_TEST.tmnCode, vnp_TxnRef: PAY,
      vnp_TransactionDate: '20261001150000', vnp_CreateDate: '20261001151000', vnp_IpAddr: '203.0.113.10', vnp_OrderInfo: `Truy van ${PAY}`,
    };
    expect(vnpPipeHash(VNPAY_TEST.hashSecret, VNP_QUERY_FIELDS, q)).toBe(
      'afbadd9447b99ecbfd7e95192bbc72245f178d5ac3f98b02b418a5559c45f7a9377905cd07ddcba7a2b895e65e735488ff285ebf421cc052d8d745c5763499e6',
    );
    const resp = {
      vnp_ResponseId: 'RESP0002', vnp_Command: 'querydr', vnp_ResponseCode: '00', vnp_Message: 'QueryDR Success', vnp_TmnCode: VNPAY_TEST.tmnCode,
      vnp_TxnRef: PAY, vnp_Amount: '60000000', vnp_BankCode: 'NCB', vnp_PayDate: '20261001150230', vnp_TransactionNo: '14600001',
      vnp_TransactionType: '01', vnp_TransactionStatus: '00', vnp_OrderInfo: `Chup ngay p60 ${REQ}`, vnp_PromotionCode: '', vnp_PromotionAmount: '',
    };
    expect(vnpPipeData(VNP_QUERY_RESPONSE_FIELDS, resp).endsWith(`|Chup ngay p60 ${REQ}||`)).toBe(true);
    expect(vnpPipeHash(VNPAY_TEST.hashSecret, VNP_QUERY_RESPONSE_FIELDS, resp)).toBe(
      '9f4002277ae83e43745380335b7fa13b92b7e2749a2f79df7c297bc477c9ad182416b4b387e1dd74267d6c29bace1ead913b6c12c3856c37c7fd06e6286c7501',
    );
  });

  it('order info without diacritics or symbols', () => {
    expect(asciiOrderInfo(`Chụp ngay p60 - ${REQ}`)).toBe(`Chup ngay p60 ${REQ}`);
    expect(asciiOrderInfo('Đặt  chụp: Đà Lạt!')).toBe('Dat chup Da Lat');
  });
});

describe('Vietnam time and ULID time', () => {
  it('yyyyMMddHHmmss in GMT+7 and back', () => {
    expect(vnTimestamp(new Date('2026-10-01T08:00:00.000Z'))).toBe('20261001150000');
    expect(vnTimestamp(new Date('2026-10-01T17:30:05.000Z'))).toBe('20261002003005');
    expect(parseVnTimestamp('20261001150000')?.toISOString()).toBe('2026-10-01T08:00:00.000Z');
    expect(parseVnTimestamp('20261301150000')).toBe(null);
  });

  it('decodes the creation time of a ULID', () => {
    expect(ulidTime(PAY)?.toISOString()).toBe('2026-10-01T08:00:00.000Z');
    expect(ulidTime('not-a-ulid')).toBe(null);
  });
});
```

```ts
// services/dispatch/vitest.unit.config.ts
import { defineConfig } from 'vitest/config';

/** Suites that need no PostgreSQL, Redis or Docker (plan I6): signatures, gateways, config, logs. */
export default defineConfig({
  test: {
    include: [
      'test/payments/signatures.test.ts',
      'test/payments/*-gateway.test.ts',
      'test/config.test.ts',
      'test/config-payments.test.ts',
      'test/logging.test.ts',
    ],
  },
});
```

In `services/dispatch/package.json` add to `scripts`:

```json
    "test:unit": "vitest run -c vitest.unit.config.ts",
```

and in `services/dispatch/tsconfig.json` add `"vitest.unit.config.ts"` to `include` (next to `"vitest.mirror.config.ts"`).

- [ ] **Step 2: Run and see it fail**

Run: `npm run test:unit`
Expected: FAIL, `Failed to load url ../../src/payments/momo-sign.js` (and `vn-time.js`, `vnpay-sign.js`).

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/payments/vn-time.ts
/**
 * VNPay timestamps are `yyyyMMddHHmmss` in Vietnam time (GMT+7, no daylight saving).
 * Every other instant in the service is UTC; convert only at the provider boundary.
 */
const VN_OFFSET_MS = 7 * 60 * 60_000;

const two = (n: number): string => String(n).padStart(2, '0');

export function vnTimestamp(at: Date): string {
  const d = new Date(at.getTime() + VN_OFFSET_MS);
  return `${d.getUTCFullYear()}${two(d.getUTCMonth() + 1)}${two(d.getUTCDate())}${two(d.getUTCHours())}${two(d.getUTCMinutes())}${two(d.getUTCSeconds())}`;
}

/** Inverse of vnTimestamp; null when the text is not 14 digits of a real date. */
export function parseVnTimestamp(s: string): Date | null {
  const m = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/.exec(s);
  if (!m) return null;
  const [y, mo, d, h, mi, se] = m.slice(1).map(Number) as [number, number, number, number, number, number];
  const utc = Date.UTC(y, mo - 1, d, h, mi, se) - VN_OFFSET_MS;
  const back = new Date(utc);
  return vnTimestamp(back) === s ? back : null;
}

const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/**
 * Creation instant encoded in a ULID (first 10 characters, milliseconds). payments.id is created
 * with the request's clock, so VNPay's vnp_CreateDate can be recomputed later for refund/querydr
 * (their `vnp_TransactionDate`) without storing it anywhere else.
 */
export function ulidTime(id: string): Date | null {
  if (!/^[0-9A-HJKMNP-TV-Z]{26}$/.test(id)) return null;
  let ms = 0;
  for (const ch of id.slice(0, 10)) ms = ms * 32 + CROCKFORD.indexOf(ch);
  return new Date(ms);
}
```

```ts
// services/dispatch/src/payments/momo-sign.ts
/**
 * MoMo AIO v2 signatures (developers.momo.vn, "Thanh toán một lần" / "Hoàn tiền" / "Truy vấn"):
 * HMAC-SHA256(secretKey, rawSignature), lower-case hex, where rawSignature is `key=value` pairs
 * joined by `&` in the exact (alphabetical) order MoMo documents for each call, values as sent
 * (no URL encoding, numbers in decimal, empty string for an empty extraData).
 */
import { createHmac, timingSafeEqual } from 'node:crypto';

export const MOMO_CREATE_FIELDS = [
  'accessKey', 'amount', 'extraData', 'ipnUrl', 'orderId', 'orderInfo', 'partnerCode', 'redirectUrl', 'requestId', 'requestType',
] as const;
export const MOMO_IPN_FIELDS = [
  'accessKey', 'amount', 'extraData', 'message', 'orderId', 'orderInfo', 'orderType', 'partnerCode', 'payType', 'requestId',
  'responseTime', 'resultCode', 'transId',
] as const;
export const MOMO_REFUND_FIELDS = ['accessKey', 'amount', 'description', 'orderId', 'partnerCode', 'requestId', 'transId'] as const;
export const MOMO_QUERY_FIELDS = ['accessKey', 'orderId', 'partnerCode', 'requestId'] as const;

export type MomoValues = Readonly<Record<string, string | number | undefined | null>>;

/** `accessKey=…&amount=…&…` over `fields`; a missing value is an empty string. */
export function momoRawSignature(fields: readonly string[], values: MomoValues): string {
  return fields.map((k) => `${k}=${values[k] ?? ''}`).join('&');
}

export function hmacSha256Hex(secret: string, data: string): string {
  return createHmac('sha256', secret).update(data, 'utf8').digest('hex');
}

export function momoSign(secret: string, fields: readonly string[], values: MomoValues): string {
  return hmacSha256Hex(secret, momoRawSignature(fields, values));
}

/** Constant-time comparison of two hex signatures (case-insensitive). */
export function sameHex(a: string, b: string): boolean {
  const x = Buffer.from(a.toLowerCase(), 'utf8');
  const y = Buffer.from(b.toLowerCase(), 'utf8');
  return x.length === y.length && timingSafeEqual(x, y);
}
```

```ts
// services/dispatch/src/payments/vnpay-sign.ts
/**
 * VNPay 2.1.0 signatures (sandbox.vnpayment.vn/apis, "Tạo URL thanh toán", "IPN", "Hoàn tiền", "Truy vấn"):
 *  - payment URL and IPN: every `vnp_*` parameter except vnp_SecureHash / vnp_SecureHashType, sorted by
 *    key, each `key=value` URL-encoded the way VNPay's samples do (encodeURIComponent, spaces as '+'),
 *    joined by '&'; vnp_SecureHash = HMAC-SHA512(hashSecret, that string), hex.
 *  - merchant_webapi (refund, querydr) requests and responses: the documented fields joined by '|'
 *    in the documented order, raw values; HMAC-SHA512, hex.
 */
import { createHmac } from 'node:crypto';

export const VNP_REFUND_FIELDS = [
  'vnp_RequestId', 'vnp_Version', 'vnp_Command', 'vnp_TmnCode', 'vnp_TransactionType', 'vnp_TxnRef', 'vnp_Amount',
  'vnp_TransactionNo', 'vnp_TransactionDate', 'vnp_CreateBy', 'vnp_CreateDate', 'vnp_IpAddr', 'vnp_OrderInfo',
] as const;
export const VNP_REFUND_RESPONSE_FIELDS = [
  'vnp_ResponseId', 'vnp_Command', 'vnp_ResponseCode', 'vnp_Message', 'vnp_TmnCode', 'vnp_TxnRef', 'vnp_Amount',
  'vnp_BankCode', 'vnp_PayDate', 'vnp_TransactionNo', 'vnp_TransactionType', 'vnp_TransactionStatus', 'vnp_OrderInfo',
] as const;
export const VNP_QUERY_FIELDS = [
  'vnp_RequestId', 'vnp_Version', 'vnp_Command', 'vnp_TmnCode', 'vnp_TxnRef', 'vnp_TransactionDate', 'vnp_CreateDate',
  'vnp_IpAddr', 'vnp_OrderInfo',
] as const;
export const VNP_QUERY_RESPONSE_FIELDS = [
  'vnp_ResponseId', 'vnp_Command', 'vnp_ResponseCode', 'vnp_Message', 'vnp_TmnCode', 'vnp_TxnRef', 'vnp_Amount',
  'vnp_BankCode', 'vnp_PayDate', 'vnp_TransactionNo', 'vnp_TransactionType', 'vnp_TransactionStatus', 'vnp_OrderInfo',
  'vnp_PromotionCode', 'vnp_PromotionAmount',
] as const;

/** VNPay's sample encoding: encodeURIComponent with %20 → '+'. */
export const vnpEncode = (v: string): string => encodeURIComponent(v).replace(/%20/g, '+');

/** The string VNPay hashes for a payment URL or an IPN. */
export function vnpSignData(params: Readonly<Record<string, string>>): string {
  return Object.keys(params)
    .filter((k) => k.startsWith('vnp_') && k !== 'vnp_SecureHash' && k !== 'vnp_SecureHashType' && params[k] !== '')
    .sort()
    .map((k) => `${vnpEncode(k)}=${vnpEncode(params[k] as string)}`)
    .join('&');
}

export function hmacSha512Hex(secret: string, data: string): string {
  return createHmac('sha512', secret).update(data, 'utf8').digest('hex');
}

export function vnpSecureHash(secret: string, params: Readonly<Record<string, string>>): string {
  return hmacSha512Hex(secret, vnpSignData(params));
}

/** merchant_webapi checksum: documented fields, raw values, joined by '|'. */
export function vnpPipeData(fields: readonly string[], values: Readonly<Record<string, string | undefined>>): string {
  return fields.map((k) => values[k] ?? '').join('|');
}

export function vnpPipeHash(secret: string, fields: readonly string[], values: Readonly<Record<string, string | undefined>>): string {
  return hmacSha512Hex(secret, vnpPipeData(fields, values));
}

/**
 * VNPay asks for vnp_OrderInfo "Tiếng Việt không dấu, không ký tự đặc biệt": strip diacritics
 * (đ → d), keep letters, digits and single spaces, at most 255 characters. Keeping the text this
 * plain also removes every difference between URL encoders (PHP, Java, JavaScript) from the hash.
 */
export function asciiOrderInfo(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .replace(/[^A-Za-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 255);
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run test:unit`
Expected: clean; `Test Files  3 passed (3)`, `Tests  24 passed (24)` (signatures 11, plus I3's fake gateway 8 and config 5).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): MoMo and VNPay signature primitives, Vietnam time and self-generated test vectors

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `PaymentStatusSource` port and the MoMo gateway

**Files:**
- Create: `services/dispatch/src/payments/status.ts`, `services/dispatch/src/payments/momo.ts`, `services/dispatch/test/payments/provider-fetch.ts`, `services/dispatch/test/payments/provider-messages.ts`, `services/dispatch/test/payments/momo-gateway.test.ts`

**Interfaces:**
- Consumes: the `PaymentGateway` family (I3 Task 3, unchanged), `runGatewayContract` / `GatewayFixture` (I3 Task 3), Task 2.
- Produces:
  - `status.ts`: `PaymentQueryInput {paymentId; providerRef; amountVnd}`, `PaymentQueryResult = {state: 'paid'|'failed'; event} | {state: 'pending'} | {state: 'not_found'} | {state: 'unknown'; reason}`, `RefundQueryInput {refundId; paymentId; providerRef; amountVnd}`, `interface PaymentStatusSource { queryPayment; queryRefund(): Promise<RefundResult> }`, `isStatusSource(g)`, `class PaymentProviderError(provider, code)`, `type Fetch`, `postJson(fetch, url, body, timeoutMs, log?)` (null on timeout, network error, non-2xx, non-JSON; never logs the body).
  - `momo.ts`: `MOMO_SANDBOX_URL`, `MOMO_PRODUCTION_URL`, `interface MomoConfig {partnerCode; accessKey; secretKey; baseUrl; ipnUrl; requestType: 'captureWallet'|'payWithMethod'; timeoutMs}`, `interface GatewayOptions {fetch?; now?; log?}`, `MOMO_PENDING_CODES`, `MOMO_MIN_VND` 1,000, `MOMO_MAX_VND` 50,000,000, `class MomoGateway implements PaymentGateway, PaymentStatusSource` (`provider = 'momo'`).
  - Test support: `providerFetch(answer)` → `{fetch, calls}` (answer: object = 200 JSON, number = HTTP status, `'timeout'`); `MOMO_CONFIG`, `momoIpn(paymentId, amountVnd, over?)`.

Behaviour (developers.momo.vn): create signs the documented string with the access key inside but never sends the access key; `orderExpireTime` = minutes until `expiresAt` (≥ 1; Task 13 checks the sandbox accepts it); a refusal, a timeout or an amount outside 1,000–50,000,000 throws `PaymentProviderError` (Task 7 closes the request). IPN: partner code and signature checked, `resultCode 0` → `paid` with `providerRef = transId`, not-final codes → `malformed` (answer 400, MoMo retries; reconciliation covers it), other codes → `failed` (`momo_<code>`). Acknowledgement: 204 for everything we recorded (including `amount_mismatch` and `unknown_payment`, kept for ops), 401 bad signature, 400 malformed, 500 error (MoMo retries). Refund: `transId` from `providerRef` (none → `manual`), `0` done, not-final or duplicate (`40/41/43`) pending, `99` or no answer retryable, other codes non-retryable. Query: `0` paid, not-final pending, `42` not found, `99`/no answer unknown, others failed; refunds are found in `refundTrans` by our refund id.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/provider-fetch.ts
import type { Fetch } from '../../src/payments/status.js';

export interface RecordedCall {
  url: string;
  body: Record<string, unknown>;
}

/**
 * A provider stand-in: answers each POST with `answer(url, body)` (an object = 200 JSON, a number =
 * that HTTP status, 'timeout' = the request is aborted) and records every call.
 */
export function providerFetch(answer: (url: string, body: Record<string, unknown>) => Record<string, unknown> | number | 'timeout'): {
  fetch: Fetch;
  calls: RecordedCall[];
} {
  const calls: RecordedCall[] = [];
  const fetch: Fetch = async (url, init) => {
    const body = JSON.parse(init.body) as Record<string, unknown>;
    calls.push({ url, body });
    const a = answer(url, body);
    if (a === 'timeout') throw Object.assign(new Error('The operation was aborted due to timeout'), { name: 'TimeoutError' });
    if (typeof a === 'number') return { ok: a >= 200 && a < 300, status: a, text: async () => '' };
    return { ok: true, status: 200, text: async () => JSON.stringify(a) };
  };
  return { fetch, calls };
}
```

```ts
// services/dispatch/test/payments/provider-messages.ts
// What MoMo (and, from Task 4, VNPay) send and answer, signed with the self-made test keys of fixtures.ts.
import { MOMO_SANDBOX_URL, type MomoConfig } from '../../src/payments/momo.js';
import { MOMO_IPN_FIELDS, momoSign } from '../../src/payments/momo-sign.js';
import { MOMO_TEST, REQ } from './fixtures.js';

export const MOMO_CONFIG: MomoConfig = {
  ...MOMO_TEST, baseUrl: MOMO_SANDBOX_URL, ipnUrl: 'https://dispatch.example.test/v1/payments/webhook/momo',
  requestType: 'captureWallet', timeoutMs: 4_000,
};

/** A MoMo IPN body as MoMo signs it. */
export function momoIpn(paymentId: string, amountVnd: number, over: Record<string, string | number> = {}): Record<string, string | number> {
  const b: Record<string, string | number> = {
    partnerCode: MOMO_TEST.partnerCode, orderId: paymentId, requestId: paymentId, amount: amountVnd, orderInfo: `Chụp ngay p60 - ${REQ}`,
    orderType: 'momo_wallet', transId: 4088878653, resultCode: 0, message: 'Thành công.', payType: 'qr', responseTime: 1790841722000,
    extraData: '', ...over,
  };
  b.signature = momoSign(MOMO_TEST.secretKey, MOMO_IPN_FIELDS, { ...b, accessKey: MOMO_TEST.accessKey });
  return b;
}
```

```ts
// services/dispatch/test/payments/momo-gateway.test.ts
import { describe, expect, it } from 'vitest';

import type { WebhookRequest } from '../../src/payments/gateway.js';
import { MomoGateway } from '../../src/payments/momo.js';
import { PaymentProviderError } from '../../src/payments/status.js';
import { MOMO_TEST, PAY, REF, REQ, T0 } from './fixtures.js';
import { runGatewayContract } from './gateway-contract.js';
import { providerFetch } from './provider-fetch.js';
import { MOMO_CONFIG, momoIpn } from './provider-messages.js';

const config = MOMO_CONFIG;

const post = (body: object): WebhookRequest => ({ provider: 'momo', method: 'POST', headers: { 'content-type': 'application/json' }, query: {}, rawBody: JSON.stringify(body) });

const created = () =>
  providerFetch((url) =>
    url.endsWith('/create')
      ? { partnerCode: 'NAGTEST', orderId: PAY, requestId: PAY, amount: 600000, responseTime: 1790841600100, message: 'Thành công.', resultCode: 0, payUrl: 'https://test-payment.momo.vn/v2/gateway/pay?t=abc', deeplink: 'momo://app?action=payWithApp' }
      : url.endsWith('/refund')
        ? { partnerCode: 'NAGTEST', orderId: REF, requestId: REF, amount: 480000, transId: 4088878999, resultCode: 0, message: 'Thành công.', responseTime: 1 }
        : 500,
  );

runGatewayContract('momo', {
  make: () => new MomoGateway(config, { fetch: created().fetch, now: () => T0 }),
  paidWebhook: (paymentId, amountVnd) => post(momoIpn(paymentId, amountVnd)),
  tamperedWebhook: (paymentId, amountVnd) => post({ ...momoIpn(paymentId, amountVnd), amount: amountVnd + 1 }),
});

describe('MomoGateway', () => {
  const input = {
    paymentId: PAY, idempotencyKey: `instant:${REQ}`, subject: { type: 'instant_request' as const, id: REQ }, amountVnd: 600_000,
    description: `Chụp ngay p60 - ${REQ}`, returnUrl: `https://links.example.test/instant/${REQ}`, expiresAt: new Date(T0.getTime() + 15 * 60_000),
  };

  it('create: signed body without the access key, payUrl returned, 15-minute expiry', async () => {
    const p = created();
    const r = await new MomoGateway(config, { fetch: p.fetch, now: () => T0 }).createPayment(input);
    expect(r).toEqual({ paymentUrl: 'https://test-payment.momo.vn/v2/gateway/pay?t=abc', providerRef: null, raw: { provider: 'momo', resultCode: 0, requestType: 'captureWallet', orderExpireMinutes: 15 } });
    expect(p.calls[0]?.url).toBe('https://test-payment.momo.vn/v2/gateway/api/create');
    expect(p.calls[0]?.body).toEqual({
      partnerCode: 'NAGTEST', requestId: PAY, orderId: PAY, amount: 600000, orderInfo: `Chụp ngay p60 - ${REQ}`,
      redirectUrl: `https://links.example.test/instant/${REQ}`, ipnUrl: 'https://dispatch.example.test/v1/payments/webhook/momo', extraData: '',
      requestType: 'captureWallet', lang: 'vi', autoCapture: true, orderExpireTime: 15,
      signature: '542c94dc0a9253dc811321fae43eb774f060cf5a5334b3a476746b433631f3de',
    });
    expect(JSON.stringify(p.calls[0]?.body)).not.toContain(MOMO_TEST.accessKey);
  });

  it('create: a refusal, a timeout or an amount outside 1,000–50,000,000 is a PaymentProviderError', async () => {
    const refused = providerFetch(() => ({ resultCode: 22, message: 'amount' }));
    await expect(new MomoGateway(config, { fetch: refused.fetch, now: () => T0 }).createPayment(input)).rejects.toThrow(PaymentProviderError);
    const slow = providerFetch(() => 'timeout');
    await expect(new MomoGateway(config, { fetch: slow.fetch, now: () => T0 }).createPayment(input)).rejects.toThrow(/unreachable/);
    await expect(new MomoGateway(config, { fetch: created().fetch }).createPayment({ ...input, amountVnd: 999 })).rejects.toThrow(/amount_out_of_range/);
  });

  it('IPN: paid carries transId; declined is failed; pending codes are not final; wrong partner is refused', async () => {
    const g = new MomoGateway(config, { fetch: created().fetch });
    expect(await g.verifyWebhook(post(momoIpn(PAY, 600_000)))).toMatchObject({ ok: true, event: { kind: 'paid', paymentId: PAY, providerRef: '4088878653', amountVnd: 600_000 } });
    expect(await g.verifyWebhook(post(momoIpn(PAY, 600_000, { resultCode: 1006, transId: 4088878654, message: 'Giao dịch bị từ chối bởi người dùng.' })))).toMatchObject({
      ok: true, event: { kind: 'failed', reason: 'momo_1006', providerRef: '4088878654' },
    });
    expect(await g.verifyWebhook(post(momoIpn(PAY, 600_000, { resultCode: 7000 })))).toEqual({ ok: false, reason: 'malformed' });
    expect(await g.verifyWebhook(post(momoIpn(PAY, 600_000, { partnerCode: 'OTHER' })))).toEqual({ ok: false, reason: 'invalid_signature' });
    expect(await g.verifyWebhook({ ...post({}), rawBody: 'not json' })).toEqual({ ok: false, reason: 'malformed' });
  });

  it('IPN acknowledgements: 204 for everything recorded, 401 bad signature, 500 to make MoMo retry', () => {
    const g = new MomoGateway(config, {});
    expect(g.acknowledge('processed')).toEqual({ status: 204, body: null });
    expect(g.acknowledge('amount_mismatch')).toEqual({ status: 204, body: null });
    expect(g.acknowledge('invalid_signature').status).toBe(401);
    expect(g.acknowledge('error').status).toBe(500);
  });

  it('refund: signed with transId; codes map to done / pending / retry / manual', async () => {
    const p = created();
    const g = new MomoGateway(config, { fetch: p.fetch, now: () => T0 });
    const base = { refundId: REF, idempotencyKey: `instant:${REQ}:refund`, paymentId: PAY, providerRef: '4088878653', amountVnd: 480_000, paymentAmountVnd: 600_000, reason: 'instant refund' };
    expect(await g.refund(base)).toMatchObject({ status: 'done', providerRef: '4088878999' });
    expect(p.calls[0]?.body).toMatchObject({ orderId: REF, requestId: REF, amount: 480000, transId: 4088878653, signature: 'cc12ac103d7999a9c6a524f5bd77e740275a24f8ffeca8140d6b002f2d6a8b93' });
    const answer = (code: number | 'timeout') => new MomoGateway(config, { fetch: providerFetch(() => (code === 'timeout' ? 'timeout' : { resultCode: code })).fetch });
    expect((await answer(7000).refund(base)).status).toBe('pending');
    expect((await answer(41).refund(base)).status).toBe('pending');
    expect(await answer(99).refund(base)).toMatchObject({ status: 'failed', retryable: true });
    expect(await answer('timeout').refund(base)).toMatchObject({ status: 'failed', retryable: true });
    expect(await answer(1080).refund(base)).toMatchObject({ status: 'failed', retryable: false });
    expect((await g.refund({ ...base, providerRef: null })).status).toBe('manual');
  });

  it('query: paid / pending / not found / failed / unknown; refunds found by our refund id', async () => {
    const ask = (a: Record<string, unknown> | 'timeout') => new MomoGateway(config, { fetch: providerFetch(() => a).fetch, now: () => T0 });
    const q = { paymentId: PAY, providerRef: null, amountVnd: 600_000 };
    expect(await ask({ resultCode: 0, transId: 4088878653, amount: 600000 }).queryPayment(q)).toMatchObject({ state: 'paid', event: { kind: 'paid', providerRef: '4088878653', amountVnd: 600_000 } });
    expect(await ask({ resultCode: 1000 }).queryPayment(q)).toEqual({ state: 'pending' });
    expect(await ask({ resultCode: 42 }).queryPayment(q)).toEqual({ state: 'not_found' });
    expect(await ask({ resultCode: 1005 }).queryPayment(q)).toMatchObject({ state: 'failed', event: { reason: 'momo_1005' } });
    expect(await ask('timeout').queryPayment(q)).toEqual({ state: 'unknown', reason: 'unreachable' });
    const p = providerFetch(() => ({ resultCode: 0, transId: 4088878653, amount: 600000, refundTrans: [{ orderId: REF, amount: 480000, resultCode: 0, transId: 4088878999 }] }));
    const g = new MomoGateway(config, { fetch: p.fetch, now: () => new Date(T0.getTime() + 10 * 60_000) });
    expect(await g.queryRefund({ refundId: REF, paymentId: PAY, providerRef: '4088878653', amountVnd: 480_000 })).toMatchObject({ status: 'done', providerRef: '4088878999' });
    expect(p.calls[0]?.body).toMatchObject({ orderId: PAY, requestId: `${PAY}Q1790842200000`, signature: 'd560af58b857037a1eff0df13eeac544d33368ac8e0158769367dda5bba254fb' });
    expect((await ask({ resultCode: 0, refundTrans: [] }).queryRefund({ refundId: REF, paymentId: PAY, providerRef: '1', amountVnd: 1 })).status).toBe('pending');
  });

  it('refuses a short secret and a non-https IPN URL', () => {
    expect(() => new MomoGateway({ ...config, secretKey: 'short' })).toThrow(/16/);
    expect(() => new MomoGateway({ ...config, ipnUrl: 'http://x' })).toThrow(/https/);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm run test:unit`
Expected: FAIL, `Failed to load url ../../src/payments/momo.js`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/payments/status.ts
/**
 * Optional second port next to PaymentGateway (plan I3 Task 3 stays unchanged): real providers can be
 * asked for the status of a payment or a refund. Used only by the reconciliation job (Task 6), never
 * on a request path. The fake gateway does not implement it.
 */
import type { PaymentEvent, PaymentGateway, RefundResult } from './gateway.js';

export interface PaymentQueryInput {
  /** payments.id = the provider's order id. */
  paymentId: string;
  providerRef: string | null;
  amountVnd: number;
}

export type PaymentQueryResult =
  /** Final answer, fed to handlePaymentEvent exactly like a webhook. */
  | { state: 'paid' | 'failed'; event: PaymentEvent }
  /** The customer has not finished (or the provider is still processing). */
  | { state: 'pending' }
  /** The provider has never seen this order (the customer never opened the payment page). */
  | { state: 'not_found' }
  /** Network error, timeout, bad signature on the answer, unknown code: ask again later. */
  | { state: 'unknown'; reason: string };

export interface RefundQueryInput {
  /** refunds.id = the provider's refund request / order id. */
  refundId: string;
  paymentId: string;
  providerRef: string | null;
  amountVnd: number;
}

export interface PaymentStatusSource {
  queryPayment(input: PaymentQueryInput): Promise<PaymentQueryResult>;
  queryRefund(input: RefundQueryInput): Promise<RefundResult>;
}

export function isStatusSource(g: PaymentGateway | undefined): g is PaymentGateway & PaymentStatusSource {
  return g !== undefined && typeof (g as Partial<PaymentStatusSource>).queryPayment === 'function' && typeof (g as Partial<PaymentStatusSource>).queryRefund === 'function';
}

/** createPayment could not get a payment URL (provider down, refused, amount out of range). */
export class PaymentProviderError extends Error {
  constructor(
    readonly provider: string,
    readonly code: string,
  ) {
    super(`${provider} refused to create the payment (${code})`);
    this.name = 'PaymentProviderError';
  }
}

export type Fetch = (url: string, init: { method: string; headers: Record<string, string>; body: string; signal: AbortSignal }) => Promise<{ ok: boolean; status: number; text(): Promise<string> }>;

/**
 * POSTs JSON and returns the parsed answer, or null on timeout, network error, non-2xx or non-JSON.
 * Never logs the body (it carries signatures) nor the URL's query.
 */
export async function postJson(
  fetchImpl: Fetch,
  url: string,
  body: Record<string, unknown>,
  timeoutMs: number,
  log?: (msg: string, extra?: Record<string, unknown>) => void,
): Promise<Record<string, unknown> | null> {
  try {
    const res = await fetchImpl(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
    const text = await res.text();
    if (!res.ok) {
      log?.('payment_provider_http_error', { status: res.status });
      return null;
    }
    const parsed = JSON.parse(text) as unknown;
    return parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed) ? (parsed as Record<string, unknown>) : null;
  } catch (err) {
    log?.('payment_provider_unreachable', { error: (err as Error).name });
    return null;
  }
}
```

```ts
// services/dispatch/src/payments/momo.ts
/**
 * MoMo AIO v2 (developers.momo.vn): create (`/v2/gateway/api/create`, requestType captureWallet or
 * payWithMethod), IPN (POST JSON to our ipnUrl, answered with HTTP 204), refund
 * (`/v2/gateway/api/refund`) and query (`/v2/gateway/api/query`, also lists the order's refunds).
 * orderId = requestId = payments.id for the payment; orderId = requestId = refunds.id for a refund.
 * The accessKey is only part of the signed string; it is never sent in a body. Secrets never leave
 * this file: not in `raw`, not in logs, not in errors.
 */
import type {
  CreatePaymentInput, CreatePaymentResult, PaymentGateway, RefundInput, RefundResult, WebhookAck, WebhookOutcome,
  WebhookRequest, WebhookVerification,
} from './gateway.js';
import { MOMO_CREATE_FIELDS, MOMO_IPN_FIELDS, MOMO_QUERY_FIELDS, MOMO_REFUND_FIELDS, momoSign, sameHex } from './momo-sign.js';
import {
  PaymentProviderError, postJson, type Fetch, type PaymentQueryInput, type PaymentQueryResult, type PaymentStatusSource,
  type RefundQueryInput,
} from './status.js';

export const MOMO_SANDBOX_URL = 'https://test-payment.momo.vn';
export const MOMO_PRODUCTION_URL = 'https://payment.momo.vn';

export interface MomoConfig {
  partnerCode: string;
  accessKey: string;
  secretKey: string;
  /** MOMO_SANDBOX_URL or MOMO_PRODUCTION_URL. */
  baseUrl: string;
  /** https://<public host>/v1/payments/webhook/momo */
  ipnUrl: string;
  requestType: 'captureWallet' | 'payWithMethod';
  timeoutMs: number;
}

export interface GatewayOptions {
  fetch?: Fetch;
  now?: () => Date;
  log?: (msg: string, extra?: Record<string, unknown>) => void;
}

/** resultCode 0 = success; these mean "not final yet" (developers.momo.vn, "Mã lỗi"). */
export const MOMO_PENDING_CODES: ReadonlySet<number> = new Set([1000, 7000, 7002, 9000]);
/** Duplicate request/order id or a similar request in progress: our earlier attempt may have gone through. */
const MOMO_DUPLICATE_CODES: ReadonlySet<number> = new Set([40, 41, 43]);
const MOMO_RETRY_CODES: ReadonlySet<number> = new Set([99]);
const MOMO_NOT_FOUND = 42;
/** captureWallet limits (VND). */
export const MOMO_MIN_VND = 1_000;
export const MOMO_MAX_VND = 50_000_000;

const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
const int = (v: unknown): number | null => (typeof v === 'number' && Number.isSafeInteger(v) ? v : typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : null);

export class MomoGateway implements PaymentGateway, PaymentStatusSource {
  readonly provider = 'momo' as const;
  private readonly fetch: Fetch;
  private readonly now: () => Date;

  constructor(
    private readonly c: MomoConfig,
    private readonly o: GatewayOptions = {},
  ) {
    if (c.secretKey.length < 16) throw new Error('MOMO_SECRET_KEY must be at least 16 characters');
    if (!c.ipnUrl.startsWith('https://')) throw new Error('the MoMo IPN URL must be https');
    this.fetch = o.fetch ?? (globalThis.fetch as unknown as Fetch);
    this.now = o.now ?? (() => new Date());
  }

  private sign(fields: readonly string[], values: Record<string, string | number>): string {
    return momoSign(this.c.secretKey, fields, { ...values, accessKey: this.c.accessKey });
  }

  private call(path: string, body: Record<string, unknown>) {
    return postJson(this.fetch, `${this.c.baseUrl}${path}`, body, this.c.timeoutMs, this.o.log);
  }

  async createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult> {
    if (!Number.isSafeInteger(input.amountVnd) || input.amountVnd < MOMO_MIN_VND || input.amountVnd > MOMO_MAX_VND) {
      throw new PaymentProviderError('momo', 'amount_out_of_range');
    }
    const fields = {
      partnerCode: this.c.partnerCode,
      requestId: input.paymentId,
      orderId: input.paymentId,
      amount: input.amountVnd,
      orderInfo: input.description.slice(0, 200),
      redirectUrl: input.returnUrl,
      ipnUrl: this.c.ipnUrl,
      extraData: '',
      requestType: this.c.requestType,
    };
    const minutes = Math.max(1, Math.floor((input.expiresAt.getTime() - this.now().getTime()) / 60_000));
    const res = await this.call('/v2/gateway/api/create', {
      ...fields,
      lang: 'vi',
      autoCapture: true,
      orderExpireTime: minutes,
      signature: this.sign(MOMO_CREATE_FIELDS, fields),
    });
    if (!res) throw new PaymentProviderError('momo', 'unreachable');
    const code = int(res.resultCode);
    const payUrl = str(res.payUrl);
    if (code !== 0 || !payUrl || !payUrl.startsWith('https://')) throw new PaymentProviderError('momo', `result_${code ?? 'missing'}`);
    return { paymentUrl: payUrl, providerRef: null, raw: { provider: 'momo', resultCode: code, requestType: this.c.requestType, orderExpireMinutes: minutes } };
  }

  async verifyWebhook(req: WebhookRequest): Promise<WebhookVerification> {
    if (req.method !== 'POST') return { ok: false, reason: 'malformed' };
    let b: Record<string, unknown>;
    try {
      const parsed = JSON.parse(req.rawBody) as unknown;
      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) return { ok: false, reason: 'malformed' };
      b = parsed as Record<string, unknown>;
    } catch {
      return { ok: false, reason: 'malformed' };
    }
    const orderId = str(b.orderId);
    const requestId = str(b.requestId);
    const partnerCode = str(b.partnerCode);
    const signature = str(b.signature);
    const amount = int(b.amount);
    const resultCode = int(b.resultCode);
    const transId = int(b.transId);
    const responseTime = int(b.responseTime);
    if (!orderId || !requestId || !partnerCode || !signature || amount === null || resultCode === null || transId === null || responseTime === null) {
      return { ok: false, reason: 'malformed' };
    }
    const values = {
      amount, extraData: str(b.extraData) ?? '', message: str(b.message) ?? '', orderId, orderInfo: str(b.orderInfo) ?? '',
      orderType: str(b.orderType) ?? '', partnerCode, payType: str(b.payType) ?? '', requestId, responseTime, resultCode, transId,
    };
    if (partnerCode !== this.c.partnerCode || !sameHex(signature, this.sign(MOMO_IPN_FIELDS, values))) {
      return { ok: false, reason: 'invalid_signature' };
    }
    const raw = { provider: 'momo', resultCode, payType: values.payType, transId: String(transId) };
    if (resultCode === 0) {
      return { ok: true, event: { kind: 'paid', paymentId: orderId, providerRef: String(transId), amountVnd: amount, raw } };
    }
    // Not final: MoMo sends the final IPN later; the reconciliation job asks if it never comes.
    if (MOMO_PENDING_CODES.has(resultCode)) return { ok: false, reason: 'malformed' };
    return { ok: true, event: { kind: 'failed', paymentId: orderId, providerRef: transId > 0 ? String(transId) : null, reason: `momo_${resultCode}`, raw } };
  }

  acknowledge(outcome: WebhookOutcome): WebhookAck {
    switch (outcome) {
      case 'processed':
      case 'duplicate':
      case 'unknown_payment':
      case 'amount_mismatch':
        // MoMo expects 204 No Content; anything else makes it retry. Mismatches are kept for ops (Task 5).
        return { status: 204, body: null };
      case 'invalid_signature':
        return { status: 401, body: { code: 'unauthenticated', message: 'invalid signature' } };
      case 'malformed':
        return { status: 400, body: { code: 'invalid_argument', message: 'malformed or not final' } };
      case 'error':
        return { status: 500, body: { code: 'internal', message: 'internal error' } };
    }
  }

  async refund(input: RefundInput): Promise<RefundResult> {
    const transId = input.providerRef !== null && /^\d+$/.test(input.providerRef) ? Number(input.providerRef) : null;
    if (transId === null) return { status: 'manual', reason: 'no MoMo transId on the payment', raw: { provider: 'momo' } };
    if (input.amountVnd <= 0 || input.amountVnd > input.paymentAmountVnd) {
      return { status: 'failed', reason: 'refund amount out of range', retryable: false, raw: { provider: 'momo' } };
    }
    const fields = {
      partnerCode: this.c.partnerCode,
      orderId: input.refundId,
      requestId: input.refundId,
      amount: input.amountVnd,
      transId,
      description: input.reason.slice(0, 100),
    };
    const res = await this.call('/v2/gateway/api/refund', { ...fields, lang: 'vi', signature: this.sign(MOMO_REFUND_FIELDS, fields) });
    if (!res) return { status: 'failed', reason: 'unreachable', retryable: true, raw: { provider: 'momo' } };
    const code = int(res.resultCode);
    const raw = { provider: 'momo', resultCode: code };
    if (code === 0) return { status: 'done', providerRef: int(res.transId) === null ? null : String(int(res.transId)), raw };
    if (code !== null && (MOMO_PENDING_CODES.has(code) || MOMO_DUPLICATE_CODES.has(code))) return { status: 'pending', providerRef: null, raw };
    if (code === null || MOMO_RETRY_CODES.has(code)) return { status: 'failed', reason: `momo_${code ?? 'missing'}`, retryable: true, raw };
    return { status: 'failed', reason: `momo_${code}`, retryable: false, raw };
  }

  private async query(paymentId: string): Promise<Record<string, unknown> | null> {
    const fields = { partnerCode: this.c.partnerCode, orderId: paymentId, requestId: `${paymentId}Q${this.now().getTime()}` };
    return this.call('/v2/gateway/api/query', { ...fields, lang: 'vi', signature: this.sign(MOMO_QUERY_FIELDS, fields) });
  }

  async queryPayment(input: PaymentQueryInput): Promise<PaymentQueryResult> {
    const res = await this.query(input.paymentId);
    if (!res) return { state: 'unknown', reason: 'unreachable' };
    const code = int(res.resultCode);
    const transId = int(res.transId);
    const amount = int(res.amount);
    const raw = { provider: 'momo', resultCode: code, query: true };
    if (code === 0 && transId !== null && amount !== null) {
      return { state: 'paid', event: { kind: 'paid', paymentId: input.paymentId, providerRef: String(transId), amountVnd: amount, raw } };
    }
    if (code === null || MOMO_RETRY_CODES.has(code)) return { state: 'unknown', reason: `momo_${code ?? 'missing'}` };
    if (MOMO_PENDING_CODES.has(code)) return { state: 'pending' };
    if (code === MOMO_NOT_FOUND) return { state: 'not_found' };
    return { state: 'failed', event: { kind: 'failed', paymentId: input.paymentId, providerRef: transId ? String(transId) : null, reason: `momo_${code}`, raw } };
  }

  async queryRefund(input: RefundQueryInput): Promise<RefundResult> {
    const res = await this.query(input.paymentId);
    if (!res) return { status: 'failed', reason: 'unreachable', retryable: true, raw: { provider: 'momo' } };
    const list = Array.isArray(res.refundTrans) ? (res.refundTrans as Array<Record<string, unknown>>) : [];
    const mine = list.find((t) => t.orderId === input.refundId);
    if (!mine) return { status: 'pending', providerRef: null, raw: { provider: 'momo', refundSeen: false } };
    const code = int(mine.resultCode);
    const raw = { provider: 'momo', resultCode: code, refundSeen: true };
    if (code === 0) return { status: 'done', providerRef: int(mine.transId) === null ? null : String(int(mine.transId)), raw };
    if (code !== null && MOMO_PENDING_CODES.has(code)) return { status: 'pending', providerRef: null, raw };
    return { status: 'failed', reason: `momo_${code ?? 'missing'}`, retryable: false, raw };
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run test:unit`
Expected: clean; `Test Files  4 passed (4)`, `Tests  36 passed (36)` (MoMo: the 5 shared contract tests + 7).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): MoMo AIO v2 gateway (create, IPN, refund, query) on the I3 PaymentGateway port

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The VNPay gateway

**Files:**
- Create: `services/dispatch/src/payments/vnpay.ts`, `services/dispatch/test/payments/vnpay-gateway.test.ts`
- Modify: `services/dispatch/test/payments/provider-messages.ts` (replace)

**Interfaces:**
- Consumes: Tasks 2–3.
- Produces: `VNPAY_SANDBOX`, `VNPAY_PRODUCTION` (`payUrl`, `apiUrl`), `interface VnpayConfig {tmnCode; hashSecret; payUrl; apiUrl; serverIp; timeoutMs}`, `VNPAY_MIN_VND` 5,000, `VNPAY_MAX_VND` 999,999,999, `VNPAY_RSP` (IPN answers per outcome), `class VnpayGateway implements PaymentGateway, PaymentStatusSource` (`provider = 'vnpay'`); test support `VNPAY_CONFIG`, `vnpayIpn(paymentId, amountVnd, over?)`, `vnpaySigned(fields, values)`, `vnpayRefundAnswer(code, over?)`, `vnpayQueryAnswer(code, status, over?)`.

Behaviour (sandbox.vnpayment.vn/apis, 2.1.0): the payment URL is built locally (`vnp_Amount` = VND × 100, `vnp_CreateDate` = ULID time of `payments.id` in GMT+7, `vnp_ExpireDate` = `expiresAt` in GMT+7, `vnp_OrderInfo` ASCII, `vnp_IpAddr` = `serverIp`, `vnp_Locale vn`, `vnp_OrderType other`); IPN is GET only, required fields present, hash and terminal checked, amount must be whole VND; paid when `ResponseCode 00` and `TransactionStatus 00` (`providerRef = vnp_TransactionNo`), else failed `vnpay_<code>`; answers are always HTTP 200 with `VNPAY_RSP`. Refund: type `02` full or `03` partial, `vnp_RequestId = refunds.id`, `vnp_TransactionDate` from the payment ULID, the answer's checksum verified (an unsigned `00` is not trusted); `00` done, `94` pending, `99`/no answer/bad signature retryable, others non-retryable. Querydr: `91` not found, status `00` paid, `01` pending, `02` failed; refund status `06` (or `00` with type `02`/`03`) done, `05` pending, `09` rejected.

- [ ] **Step 1: Write the failing test**

Replace `services/dispatch/test/payments/provider-messages.ts` with:

```ts
// services/dispatch/test/payments/provider-messages.ts
// What MoMo and VNPay send and answer, signed with the self-made test keys of fixtures.ts.
import { MOMO_SANDBOX_URL, type MomoConfig } from '../../src/payments/momo.js';
import { MOMO_IPN_FIELDS, momoSign } from '../../src/payments/momo-sign.js';
import { VNPAY_SANDBOX, type VnpayConfig } from '../../src/payments/vnpay.js';
import { VNP_QUERY_RESPONSE_FIELDS, VNP_REFUND_RESPONSE_FIELDS, vnpPipeHash, vnpSecureHash } from '../../src/payments/vnpay-sign.js';
import { MOMO_TEST, PAY, REF, REQ, VNPAY_TEST } from './fixtures.js';

export const MOMO_CONFIG: MomoConfig = {
  ...MOMO_TEST, baseUrl: MOMO_SANDBOX_URL, ipnUrl: 'https://dispatch.example.test/v1/payments/webhook/momo',
  requestType: 'captureWallet', timeoutMs: 4_000,
};
export const VNPAY_CONFIG: VnpayConfig = { ...VNPAY_TEST, ...VNPAY_SANDBOX, serverIp: '203.0.113.10', timeoutMs: 4_000 };

/** A MoMo IPN body as MoMo signs it. */
export function momoIpn(paymentId: string, amountVnd: number, over: Record<string, string | number> = {}): Record<string, string | number> {
  const b: Record<string, string | number> = {
    partnerCode: MOMO_TEST.partnerCode, orderId: paymentId, requestId: paymentId, amount: amountVnd, orderInfo: `Chụp ngay p60 - ${REQ}`,
    orderType: 'momo_wallet', transId: 4088878653, resultCode: 0, message: 'Thành công.', payType: 'qr', responseTime: 1790841722000,
    extraData: '', ...over,
  };
  b.signature = momoSign(MOMO_TEST.secretKey, MOMO_IPN_FIELDS, { ...b, accessKey: MOMO_TEST.accessKey });
  return b;
}

/** The query string VNPay sends to the IPN URL, signed like VNPay does. */
export function vnpayIpn(paymentId: string, amountVnd: number, over: Record<string, string> = {}): Record<string, string> {
  const q: Record<string, string> = {
    vnp_Amount: String(amountVnd * 100), vnp_BankCode: 'NCB', vnp_BankTranNo: 'VNP14600001', vnp_CardType: 'ATM',
    vnp_OrderInfo: `Chup ngay p60 ${REQ}`, vnp_PayDate: '20261001150230', vnp_ResponseCode: '00', vnp_TmnCode: VNPAY_TEST.tmnCode,
    vnp_TransactionNo: '14600001', vnp_TransactionStatus: '00', vnp_TxnRef: paymentId, ...over,
  };
  return { ...q, vnp_SecureHashType: 'HmacSHA512', vnp_SecureHash: vnpSecureHash(VNPAY_TEST.hashSecret, q) };
}

/** A signed merchant_webapi answer. */
export function vnpaySigned(fields: readonly string[], values: Record<string, string>): Record<string, string> {
  return { ...values, vnp_SecureHash: vnpPipeHash(VNPAY_TEST.hashSecret, fields, values) };
}

export const vnpayRefundAnswer = (code: string, over: Record<string, string> = {}) =>
  vnpaySigned(VNP_REFUND_RESPONSE_FIELDS, {
    vnp_ResponseId: 'RESP0001', vnp_Command: 'refund', vnp_ResponseCode: code, vnp_Message: 'x', vnp_TmnCode: VNPAY_TEST.tmnCode, vnp_TxnRef: PAY,
    vnp_Amount: '48000000', vnp_BankCode: 'NCB', vnp_PayDate: '20261001153001', vnp_TransactionNo: '14600002', vnp_TransactionType: '03',
    vnp_TransactionStatus: '05', vnp_OrderInfo: `Hoan tien ${REF}`, ...over,
  });

export const vnpayQueryAnswer = (code: string, status: string, over: Record<string, string> = {}) =>
  vnpaySigned(VNP_QUERY_RESPONSE_FIELDS, {
    vnp_ResponseId: 'RESP0002', vnp_Command: 'querydr', vnp_ResponseCode: code, vnp_Message: 'x', vnp_TmnCode: VNPAY_TEST.tmnCode, vnp_TxnRef: PAY,
    vnp_Amount: '60000000', vnp_BankCode: 'NCB', vnp_PayDate: '20261001150230', vnp_TransactionNo: '14600001', vnp_TransactionType: '01',
    vnp_TransactionStatus: status, vnp_OrderInfo: `Chup ngay p60 ${REQ}`, vnp_PromotionCode: '', vnp_PromotionAmount: '', ...over,
  });
```

```ts
// services/dispatch/test/payments/vnpay-gateway.test.ts
import { describe, expect, it } from 'vitest';

import type { WebhookRequest } from '../../src/payments/gateway.js';
import { VnpayGateway } from '../../src/payments/vnpay.js';
import { VNP_REFUND_FIELDS } from '../../src/payments/vnpay-sign.js';
import { PAY, REF, REQ, T0, VNPAY_TEST } from './fixtures.js';
import { runGatewayContract } from './gateway-contract.js';
import { providerFetch } from './provider-fetch.js';
import { VNPAY_CONFIG, vnpayIpn, vnpayQueryAnswer, vnpayRefundAnswer } from './provider-messages.js';

const config = VNPAY_CONFIG;
const get = (query: Record<string, string>): WebhookRequest => ({ provider: 'vnpay', method: 'GET', headers: {}, query, rawBody: '' });
const refundAnswer = vnpayRefundAnswer;
const queryAnswer = vnpayQueryAnswer;

runGatewayContract('vnpay', {
  make: () => new VnpayGateway(config, { fetch: providerFetch(() => refundAnswer('00')).fetch, now: () => T0 }),
  paidWebhook: (paymentId, amountVnd) => get(vnpayIpn(paymentId, amountVnd)),
  tamperedWebhook: (paymentId, amountVnd) => get({ ...vnpayIpn(paymentId, amountVnd), vnp_Amount: String(amountVnd * 100 + 100) }),
});

describe('VnpayGateway', () => {
  const input = {
    paymentId: PAY, idempotencyKey: `instant:${REQ}`, subject: { type: 'instant_request' as const, id: REQ }, amountVnd: 600_000,
    description: `Chụp ngay p60 - ${REQ}`, returnUrl: `https://links.example.test/instant/${REQ}`, expiresAt: new Date(T0.getTime() + 15 * 60_000),
  };

  it('payment URL: the sandbox page, signed, create date from the payment ULID, expiry in Vietnam time', async () => {
    const r = await new VnpayGateway(config, { now: () => T0 }).createPayment(input);
    const url = new URL(r.paymentUrl);
    expect(`${url.origin}${url.pathname}`).toBe('https://sandbox.vnpayment.vn/paymentv2/vpcpay.html');
    expect(url.searchParams.get('vnp_CreateDate')).toBe('20261001150000');
    expect(url.searchParams.get('vnp_ExpireDate')).toBe('20261001151500');
    expect(url.searchParams.get('vnp_OrderInfo')).toBe(`Chup ngay p60 ${REQ}`);
    expect(url.searchParams.get('vnp_Amount')).toBe('60000000');
    expect(url.searchParams.get('vnp_SecureHash')).toBe(
      'b1e2d047b6f8710229cf9311c8fe45d7c57e91ecb00b5a6013675847239432e9acb1f93da141668cf7e81484838ff4eeeb4eea2a3f937dbad05ee35a63f87fee',
    );
    expect(r.raw).toEqual({ provider: 'vnpay', vnp_TxnRef: PAY, vnp_CreateDate: '20261001150000', vnp_ExpireDate: '20261001151500' });
    expect(r.paymentUrl).not.toContain(VNPAY_TEST.hashSecret);
    await expect(new VnpayGateway(config).createPayment({ ...input, amountVnd: 4_000 })).rejects.toThrow(/amount_out_of_range/);
  });

  it('IPN: paid / customer cancelled (24) / wrong terminal / bad amount / POST', async () => {
    const g = new VnpayGateway(config);
    expect(await g.verifyWebhook(get(vnpayIpn(PAY, 600_000)))).toMatchObject({ ok: true, event: { kind: 'paid', paymentId: PAY, providerRef: '14600001', amountVnd: 600_000 } });
    const cancelled = vnpayIpn(PAY, 600_000, { vnp_ResponseCode: '24', vnp_TransactionStatus: '02', vnp_TransactionNo: '0', vnp_BankTranNo: '', vnp_CardType: '', vnp_PayDate: '20261001150410' });
    expect(cancelled.vnp_SecureHash).toBe('7103710c2fe40d49326293774f05a116f5ee0e39619667b5671550d54c1ea361aa4fb952c6358e3db49f7661314bf0e7a84b3fdf94e3919b058a9e9ed228deb6');
    expect(await g.verifyWebhook(get(cancelled))).toMatchObject({ ok: true, event: { kind: 'failed', reason: 'vnpay_24', providerRef: null } });
    expect(await g.verifyWebhook(get(vnpayIpn(PAY, 600_000, { vnp_TmnCode: 'OTHER' })))).toEqual({ ok: false, reason: 'invalid_signature' });
    expect(await g.verifyWebhook(get({ ...vnpayIpn(PAY, 600_000), vnp_SecureHash: '' }))).toEqual({ ok: false, reason: 'malformed' });
    expect(await g.verifyWebhook({ ...get(vnpayIpn(PAY, 600_000)), method: 'POST' })).toEqual({ ok: false, reason: 'malformed' });
  });

  it('IPN answers are HTTP 200 with VNPay RspCodes', () => {
    const g = new VnpayGateway(config);
    expect(g.acknowledge('processed')).toEqual({ status: 200, body: { RspCode: '00', Message: 'Confirm Success' } });
    expect(g.acknowledge('duplicate').body).toEqual({ RspCode: '02', Message: 'Order already confirmed' });
    expect(g.acknowledge('unknown_payment').body).toMatchObject({ RspCode: '01' });
    expect(g.acknowledge('amount_mismatch').body).toMatchObject({ RspCode: '04' });
    expect(g.acknowledge('invalid_signature').body).toMatchObject({ RspCode: '97' });
    expect(g.acknowledge('error')).toMatchObject({ status: 200, body: { RspCode: '99' } });
  });

  it('refund: partial 03 / full 02, signed request, signed answer checked, codes mapped', async () => {
    const p = providerFetch(() => refundAnswer('00'));
    const g = new VnpayGateway(config, { fetch: p.fetch, now: () => new Date(T0.getTime() + 30 * 60_000) });
    const base = { refundId: REF, idempotencyKey: `instant:${REQ}:refund`, paymentId: PAY, providerRef: '14600001', amountVnd: 480_000, paymentAmountVnd: 600_000, reason: 'instant refund' };
    expect(await g.refund(base)).toMatchObject({ status: 'done', providerRef: '14600002' });
    expect(p.calls[0]?.url).toBe('https://sandbox.vnpayment.vn/merchant_webapi/api/transaction');
    expect(p.calls[0]?.body).toMatchObject({
      vnp_RequestId: REF, vnp_Command: 'refund', vnp_TransactionType: '03', vnp_Amount: '48000000', vnp_TransactionDate: '20261001150000',
      vnp_CreateDate: '20261001153000', vnp_CreateBy: 'dispatch',
      vnp_SecureHash: '1658ef34b27a052ae50781113802dbc2af708b0267776048122bd81815c6086382aad5f6996092bcd36cddab6ac70a19950e1a09011f72099e110ae859cb9ed6',
    });
    expect(Object.keys(p.calls[0]?.body ?? {}).filter((k) => k !== 'vnp_SecureHash')).toEqual([...VNP_REFUND_FIELDS]);
    await g.refund({ ...base, amountVnd: 600_000 });
    expect(p.calls[1]?.body.vnp_TransactionType).toBe('02');
    const answer = (a: Record<string, string> | 'timeout') => new VnpayGateway(config, { fetch: providerFetch(() => a).fetch, now: () => T0 });
    expect((await answer(refundAnswer('94')).refund(base)).status).toBe('pending');
    expect(await answer(refundAnswer('99')).refund(base)).toMatchObject({ status: 'failed', retryable: true });
    expect(await answer(refundAnswer('95')).refund(base)).toMatchObject({ status: 'failed', retryable: false, reason: 'vnpay_95' });
    expect(await answer({ ...refundAnswer('00'), vnp_Amount: '1' }).refund(base)).toMatchObject({ status: 'failed', retryable: true, reason: 'bad_signature' });
    expect(await answer('timeout').refund(base)).toMatchObject({ status: 'failed', retryable: true });
  });

  it('querydr: paid / pending / not found / failed; refund status from the transaction status', async () => {
    const ask = (a: Record<string, string>) => new VnpayGateway(config, { fetch: providerFetch(() => a).fetch, now: () => T0 });
    const q = { paymentId: PAY, providerRef: null, amountVnd: 600_000 };
    expect(await ask(queryAnswer('00', '00')).queryPayment(q)).toMatchObject({ state: 'paid', event: { providerRef: '14600001', amountVnd: 600_000 } });
    expect(await ask(queryAnswer('00', '01')).queryPayment(q)).toEqual({ state: 'pending' });
    expect(await ask(queryAnswer('91', '')).queryPayment(q)).toEqual({ state: 'not_found' });
    expect(await ask(queryAnswer('00', '02')).queryPayment(q)).toMatchObject({ state: 'failed' });
    const r = { refundId: REF, paymentId: PAY, providerRef: '14600001', amountVnd: 480_000 };
    expect((await ask(queryAnswer('00', '05')).queryRefund(r)).status).toBe('pending');
    expect((await ask(queryAnswer('00', '06')).queryRefund(r)).status).toBe('done');
    expect((await ask(queryAnswer('00', '00', { vnp_TransactionType: '03' })).queryRefund(r)).status).toBe('done');
    expect(await ask(queryAnswer('00', '09')).queryRefund(r)).toMatchObject({ status: 'failed', retryable: false });
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm run test:unit`
Expected: FAIL, `Failed to load url ../../src/payments/vnpay.js`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/payments/vnpay.ts
/**
 * VNPay 2.1.0 (sandbox.vnpayment.vn/apis): the payment page is a signed URL built locally
 * (no call at creation); the IPN is a GET with vnp_* parameters answered with HTTP 200 and
 * {"RspCode","Message"}; refund and querydr go to merchant_webapi as JSON with a '|' checksum.
 * vnp_TxnRef = payments.id; vnp_RequestId = refunds.id (refund) or a per-call id (querydr).
 * vnp_CreateDate is the ULID time of payments.id, so refund/querydr can send it back as
 * vnp_TransactionDate without storing it. The hash secret never leaves this file.
 */
import type {
  CreatePaymentInput, CreatePaymentResult, PaymentGateway, RefundInput, RefundResult, WebhookAck, WebhookOutcome,
  WebhookRequest, WebhookVerification,
} from './gateway.js';
import { sameHex } from './momo-sign.js';
import {
  PaymentProviderError, postJson, type Fetch, type PaymentQueryInput, type PaymentQueryResult, type PaymentStatusSource,
  type RefundQueryInput,
} from './status.js';
import { ulidTime, vnTimestamp } from './vn-time.js';
import {
  VNP_QUERY_FIELDS, VNP_QUERY_RESPONSE_FIELDS, VNP_REFUND_FIELDS, VNP_REFUND_RESPONSE_FIELDS, asciiOrderInfo, vnpPipeHash,
  vnpSecureHash, vnpSignData,
} from './vnpay-sign.js';

export const VNPAY_SANDBOX = {
  payUrl: 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
  apiUrl: 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction',
} as const;
export const VNPAY_PRODUCTION = {
  payUrl: 'https://pay.vnpay.vn/vpcpay.html',
  apiUrl: 'https://merchant.vnpay.vn/merchant_webapi/api/transaction',
} as const;

export interface VnpayConfig {
  tmnCode: string;
  hashSecret: string;
  payUrl: string;
  apiUrl: string;
  /** vnp_IpAddr: the service's public egress IP (the port has no client IP; see plan I6 deviation 2). */
  serverIp: string;
  timeoutMs: number;
}

export interface VnpayOptions {
  fetch?: Fetch;
  now?: () => Date;
  log?: (msg: string, extra?: Record<string, unknown>) => void;
}

export const VNPAY_MIN_VND = 5_000;
export const VNPAY_MAX_VND = 999_999_999;
const VERSION = '2.1.0';

/** IPN answers (VNPay "Bảng mã lỗi" for the merchant's response to an IPN). */
export const VNPAY_RSP: Readonly<Record<WebhookOutcome, { RspCode: string; Message: string }>> = {
  processed: { RspCode: '00', Message: 'Confirm Success' },
  duplicate: { RspCode: '02', Message: 'Order already confirmed' },
  unknown_payment: { RspCode: '01', Message: 'Order not found' },
  amount_mismatch: { RspCode: '04', Message: 'Invalid amount' },
  invalid_signature: { RspCode: '97', Message: 'Invalid signature' },
  malformed: { RspCode: '99', Message: 'Invalid request' },
  error: { RspCode: '99', Message: 'Unknown error' },
};

const s = (v: unknown): string => (typeof v === 'string' ? v : typeof v === 'number' ? String(v) : '');

export class VnpayGateway implements PaymentGateway, PaymentStatusSource {
  readonly provider = 'vnpay' as const;
  private readonly fetch: Fetch;
  private readonly now: () => Date;

  constructor(
    private readonly c: VnpayConfig,
    private readonly o: VnpayOptions = {},
  ) {
    if (c.hashSecret.length < 16) throw new Error('VNPAY_HASH_SECRET must be at least 16 characters');
    this.fetch = o.fetch ?? (globalThis.fetch as unknown as Fetch);
    this.now = o.now ?? (() => new Date());
  }

  /** vnp_CreateDate of the payment = its ULID time (Vietnam time). */
  private transactionDate(paymentId: string): string {
    const t = ulidTime(paymentId);
    if (!t) throw new Error('payments.id is not a ULID');
    return vnTimestamp(t);
  }

  async createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult> {
    if (!Number.isSafeInteger(input.amountVnd) || input.amountVnd < VNPAY_MIN_VND || input.amountVnd > VNPAY_MAX_VND) {
      throw new PaymentProviderError('vnpay', 'amount_out_of_range');
    }
    const params: Record<string, string> = {
      vnp_Version: VERSION,
      vnp_Command: 'pay',
      vnp_TmnCode: this.c.tmnCode,
      vnp_Amount: String(input.amountVnd * 100),
      vnp_CreateDate: this.transactionDate(input.paymentId),
      vnp_CurrCode: 'VND',
      vnp_IpAddr: this.c.serverIp,
      vnp_Locale: 'vn',
      vnp_OrderInfo: asciiOrderInfo(input.description),
      vnp_OrderType: 'other',
      vnp_ReturnUrl: input.returnUrl,
      vnp_ExpireDate: vnTimestamp(input.expiresAt),
      vnp_TxnRef: input.paymentId,
    };
    const query = vnpSignData(params);
    const hash = vnpSecureHash(this.c.hashSecret, params);
    return {
      paymentUrl: `${this.c.payUrl}?${query}&vnp_SecureHash=${hash}`,
      providerRef: null,
      raw: { provider: 'vnpay', vnp_TxnRef: params.vnp_TxnRef, vnp_CreateDate: params.vnp_CreateDate, vnp_ExpireDate: params.vnp_ExpireDate },
    };
  }

  async verifyWebhook(req: WebhookRequest): Promise<WebhookVerification> {
    if (req.method !== 'GET') return { ok: false, reason: 'malformed' };
    const q = req.query;
    const need = ['vnp_TxnRef', 'vnp_Amount', 'vnp_ResponseCode', 'vnp_TransactionStatus', 'vnp_TmnCode', 'vnp_SecureHash'] as const;
    if (need.some((k) => typeof q[k] !== 'string' || q[k] === '')) return { ok: false, reason: 'malformed' };
    if (!sameHex(q.vnp_SecureHash as string, vnpSecureHash(this.c.hashSecret, q)) || q.vnp_TmnCode !== this.c.tmnCode) {
      return { ok: false, reason: 'invalid_signature' };
    }
    const cents = /^\d+$/.test(q.vnp_Amount as string) ? Number(q.vnp_Amount) : Number.NaN;
    if (!Number.isSafeInteger(cents) || cents % 100 !== 0) return { ok: false, reason: 'malformed' };
    const paymentId = q.vnp_TxnRef as string;
    const txn = q.vnp_TransactionNo ?? '';
    const raw = {
      provider: 'vnpay', responseCode: q.vnp_ResponseCode, transactionStatus: q.vnp_TransactionStatus,
      bankCode: q.vnp_BankCode ?? null, cardType: q.vnp_CardType ?? null, payDate: q.vnp_PayDate ?? null,
    };
    if (q.vnp_ResponseCode === '00' && q.vnp_TransactionStatus === '00') {
      if (txn === '' || txn === '0') return { ok: false, reason: 'malformed' };
      return { ok: true, event: { kind: 'paid', paymentId, providerRef: txn, amountVnd: cents / 100, raw } };
    }
    return {
      ok: true,
      event: { kind: 'failed', paymentId, providerRef: txn === '' || txn === '0' ? null : txn, reason: `vnpay_${q.vnp_ResponseCode}`, raw },
    };
  }

  acknowledge(outcome: WebhookOutcome): WebhookAck {
    // VNPay reads the answer from the body; the HTTP status is always 200.
    return { status: 200, body: VNPAY_RSP[outcome] };
  }

  private requestId(prefix: string): string {
    // Unique per call, ≤ 32 characters: prefix + Vietnam time to the second + 4 random hex.
    return `${prefix}${vnTimestamp(this.now())}${Math.floor(Math.random() * 0x10000).toString(16).padStart(4, '0')}`.slice(0, 32);
  }

  private async api(fields: readonly string[], values: Record<string, string>, responseFields: readonly string[]): Promise<Record<string, string> | 'unreachable' | 'bad_signature'> {
    const body = { ...values, vnp_SecureHash: vnpPipeHash(this.c.hashSecret, fields, values) };
    const res = await postJson(this.fetch, this.c.apiUrl, body, this.c.timeoutMs, this.o.log);
    if (!res) return 'unreachable';
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(res)) out[k] = s(v);
    // Error answers (e.g. 97, 99) may come unsigned; only a signed answer can be trusted as success.
    if (out.vnp_SecureHash && !sameHex(out.vnp_SecureHash, vnpPipeHash(this.c.hashSecret, responseFields, out))) return 'bad_signature';
    if (!out.vnp_SecureHash && out.vnp_ResponseCode === '00') return 'bad_signature';
    return out;
  }

  async refund(input: RefundInput): Promise<RefundResult> {
    if (input.amountVnd <= 0 || input.amountVnd > input.paymentAmountVnd) {
      return { status: 'failed', reason: 'refund amount out of range', retryable: false, raw: { provider: 'vnpay' } };
    }
    const values: Record<string, string> = {
      vnp_RequestId: input.refundId,
      vnp_Version: VERSION,
      vnp_Command: 'refund',
      vnp_TmnCode: this.c.tmnCode,
      vnp_TransactionType: input.amountVnd === input.paymentAmountVnd ? '02' : '03',
      vnp_TxnRef: input.paymentId,
      vnp_Amount: String(input.amountVnd * 100),
      vnp_TransactionNo: input.providerRef ?? '',
      vnp_TransactionDate: this.transactionDate(input.paymentId),
      vnp_CreateBy: 'dispatch',
      vnp_CreateDate: vnTimestamp(this.now()),
      vnp_IpAddr: this.c.serverIp,
      vnp_OrderInfo: `Hoan tien ${input.refundId}`,
    };
    const r = await this.api(VNP_REFUND_FIELDS, values, VNP_REFUND_RESPONSE_FIELDS);
    if (r === 'unreachable' || r === 'bad_signature') return { status: 'failed', reason: r, retryable: true, raw: { provider: 'vnpay' } };
    const raw = { provider: 'vnpay', responseCode: r.vnp_ResponseCode, transactionStatus: r.vnp_TransactionStatus ?? null };
    switch (r.vnp_ResponseCode) {
      case '00':
        return { status: 'done', providerRef: r.vnp_TransactionNo || null, raw };
      case '94': // duplicate request within VNPay's window: our earlier attempt is in progress
        return { status: 'pending', providerRef: null, raw };
      case '99':
        return { status: 'failed', reason: 'vnpay_99', retryable: true, raw };
      default:
        return { status: 'failed', reason: `vnpay_${r.vnp_ResponseCode || 'missing'}`, retryable: false, raw };
    }
  }

  private querydr(paymentId: string) {
    const values: Record<string, string> = {
      vnp_RequestId: this.requestId('Q'),
      vnp_Version: VERSION,
      vnp_Command: 'querydr',
      vnp_TmnCode: this.c.tmnCode,
      vnp_TxnRef: paymentId,
      vnp_TransactionDate: this.transactionDate(paymentId),
      vnp_CreateDate: vnTimestamp(this.now()),
      vnp_IpAddr: this.c.serverIp,
      vnp_OrderInfo: `Truy van ${paymentId}`,
    };
    return this.api(VNP_QUERY_FIELDS, values, VNP_QUERY_RESPONSE_FIELDS);
  }

  async queryPayment(input: PaymentQueryInput): Promise<PaymentQueryResult> {
    const r = await this.querydr(input.paymentId);
    if (r === 'unreachable' || r === 'bad_signature') return { state: 'unknown', reason: r };
    if (r.vnp_ResponseCode === '91') return { state: 'not_found' };
    if (r.vnp_ResponseCode !== '00') return { state: 'unknown', reason: `vnpay_${r.vnp_ResponseCode || 'missing'}` };
    const raw = { provider: 'vnpay', responseCode: '00', transactionStatus: r.vnp_TransactionStatus, query: true };
    const cents = /^\d+$/.test(r.vnp_Amount ?? '') ? Number(r.vnp_Amount) : Number.NaN;
    switch (r.vnp_TransactionStatus) {
      case '00':
        if (!Number.isSafeInteger(cents) || cents % 100 !== 0 || !r.vnp_TransactionNo) return { state: 'unknown', reason: 'vnpay_bad_amount' };
        return { state: 'paid', event: { kind: 'paid', paymentId: input.paymentId, providerRef: r.vnp_TransactionNo, amountVnd: cents / 100, raw } };
      case '01':
        return { state: 'pending' };
      case '02':
        return { state: 'failed', event: { kind: 'failed', paymentId: input.paymentId, providerRef: r.vnp_TransactionNo || null, reason: 'vnpay_status_02', raw } };
      default:
        return { state: 'unknown', reason: `vnpay_status_${r.vnp_TransactionStatus || 'missing'}` };
    }
  }

  async queryRefund(input: RefundQueryInput): Promise<RefundResult> {
    const r = await this.querydr(input.paymentId);
    if (r === 'unreachable' || r === 'bad_signature') return { status: 'failed', reason: r, retryable: true, raw: { provider: 'vnpay' } };
    const raw = { provider: 'vnpay', responseCode: r.vnp_ResponseCode, transactionStatus: r.vnp_TransactionStatus ?? null, transactionType: r.vnp_TransactionType ?? null };
    if (r.vnp_ResponseCode !== '00') return { status: 'pending', providerRef: null, raw };
    const refundType = r.vnp_TransactionType === '02' || r.vnp_TransactionType === '03';
    if (r.vnp_TransactionStatus === '06' || (refundType && r.vnp_TransactionStatus === '00')) return { status: 'done', providerRef: r.vnp_TransactionNo || null, raw };
    if (r.vnp_TransactionStatus === '09') return { status: 'failed', reason: 'vnpay_refund_rejected', retryable: false, raw };
    return { status: 'pending', providerRef: null, raw };
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run test:unit`
Expected: clean; `Test Files  5 passed (5)`, `Tests  46 passed (46)` (VNPay: the 5 shared contract tests + 5).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): VNPay 2.1.0 gateway (signed URL, GET IPN with RspCode, refund, querydr)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Provider configuration, `buildGateways`, log redaction

**Files:**
- Modify: `services/dispatch/src/config.ts` (replace), `services/dispatch/src/payments/registry.ts` (replace), `services/dispatch/src/wiring.ts`, `services/dispatch/.env.example`
- Create: `services/dispatch/test/config-payments.test.ts`, `services/dispatch/test/logging.test.ts`

**Interfaces:**
- Consumes: `MomoConfig`, `VnpayConfig`, endpoints (Tasks 3–4); I3's `loadConfig`, `buildGateways`, `createLogger`, `wire`.
- Produces:
  - `ServiceConfig` + `paymentEnv: 'sandbox'|'production'`, `publicBaseUrl: string|null`, `appLinkBaseUrl: string|null`, `appLinks: AppLinksConfig|null`, `momo: MomoConfig|null`, `vnpay: VnpayConfig|null`; `interface AppLinksConfig {androidPackage; androidCertSha256: string[]; appleAppId: string|null}`; `type PaymentEnv`.
  - Env: `PAYMENT_ENV` (`sandbox` default; `production` refused unless `NODE_ENV=production`), `PUBLIC_BASE_URL`, `APP_LINK_BASE_URL` (https origins; the latter defaults to the former), `PAYMENT_HTTP_TIMEOUT_MS` (8,000), `MOMO_PARTNER_CODE` / `MOMO_ACCESS_KEY` / `MOMO_SECRET_KEY` (≥ 16) / `MOMO_REQUEST_TYPE`, `VNPAY_TMN_CODE` / `VNPAY_HASH_SECRET` (≥ 16) / `VNPAY_SERVER_IP` (IPv4), `ANDROID_PACKAGE`, `ANDROID_CERT_SHA256` (comma list), `APPLE_APP_ID`. Providers load only with `PAYMENTS=live`; a live process with none keeps I3's behaviour (no gateway; `server.ts` warns in Task 12).
  - `buildGateways(config, wiring?: GatewayWiring {fetch?; now?; log?})`; `LOG_REDACT`; `createLogger(level, destination?)` (request URLs logged without query).
  - `returnUrlFor(id)` = `${appLinkBaseUrl}/instant/${id}` when set, else `photobooking://instant/${id}` (I3).

- [ ] **Step 1: Write the failing tests**

```ts
// services/dispatch/test/config-payments.test.ts
import { describe, expect, it } from 'vitest';

import { loadConfig } from '../src/config.js';
import { buildGateways } from '../src/payments/registry.js';

const base = { DATABASE_URL: 'postgres://x@localhost/x', REDIS_URL: 'redis://localhost:6379', FIREBASE_PROJECT_ID: 'demo-nag' };
const momo = { MOMO_PARTNER_CODE: 'NAGTEST', MOMO_ACCESS_KEY: 'nagTestAccessKey', MOMO_SECRET_KEY: 'nag-test-momo-secret-0123456789' };
const vnpay = { VNPAY_TMN_CODE: 'NAGTEST1', VNPAY_HASH_SECRET: 'NAGTESTVNPAYHASHSECRET0123456789', VNPAY_SERVER_IP: '203.0.113.10' };
const urls = { PUBLIC_BASE_URL: 'https://dispatch.example.test', APP_LINK_BASE_URL: 'https://links.example.test' };

describe('live payment configuration (plan I6)', () => {
  it('nothing configured: live has no gateway (instant stays hidden), exactly as in plan I3', () => {
    const c = loadConfig({ ...base });
    expect(c).toMatchObject({ paymentEnv: 'sandbox', momo: null, vnpay: null, publicBaseUrl: null, appLinks: null });
    expect(buildGateways(c).enabled()).toEqual([]);
  });

  it('MoMo and VNPay from the environment: sandbox endpoints, IPN and return URLs on https', () => {
    const c = loadConfig({ ...base, ...urls, ...momo, ...vnpay });
    expect(c.momo).toMatchObject({ baseUrl: 'https://test-payment.momo.vn', ipnUrl: 'https://dispatch.example.test/v1/payments/webhook/momo', requestType: 'captureWallet', timeoutMs: 8_000 });
    expect(c.vnpay).toMatchObject({ payUrl: 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html', apiUrl: 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction', serverIp: '203.0.113.10' });
    expect(c.appLinkBaseUrl).toBe('https://links.example.test');
    expect(buildGateways(c).enabled()).toEqual(['momo', 'vnpay']);
  });

  it('production endpoints only with NODE_ENV=production', () => {
    expect(() => loadConfig({ ...base, ...urls, ...momo, NODE_ENV: 'development', PAYMENT_ENV: 'production' })).toThrow(/refused/);
    const c = loadConfig({ ...base, ...urls, ...momo, ...vnpay, PAYMENT_ENV: 'production' });
    expect(c.momo?.baseUrl).toBe('https://payment.momo.vn');
    expect(c.vnpay?.payUrl).toBe('https://pay.vnpay.vn/vpcpay.html');
  });

  it('refuses missing or weak secrets, http URLs and a bad server IP', () => {
    expect(() => loadConfig({ ...base, ...urls, ...momo, MOMO_SECRET_KEY: 'short' })).toThrow(/MOMO_SECRET_KEY/);
    expect(() => loadConfig({ ...base, ...urls, ...momo, MOMO_ACCESS_KEY: '' })).toThrow(/MOMO_ACCESS_KEY/);
    expect(() => loadConfig({ ...base, ...momo })).toThrow(/PUBLIC_BASE_URL/);
    expect(() => loadConfig({ ...base, ...momo, PUBLIC_BASE_URL: 'http://dispatch.example.test' })).toThrow(/https/);
    expect(() => loadConfig({ ...base, ...urls, ...vnpay, VNPAY_SERVER_IP: 'dispatch' })).toThrow(/IPv4/);
  });

  it('PAYMENTS=fake ignores provider settings', () => {
    const c = loadConfig({ ...base, ...urls, ...momo, NODE_ENV: 'development', PAYMENTS: 'fake', FAKE_PAYMENT_SECRET: 's'.repeat(16) });
    expect(c.momo).toBe(null);
    expect(buildGateways(c).enabled()).toEqual(['fake']);
  });

  it('App Link files: fingerprints and Apple app id are validated', () => {
    const fp = Array.from({ length: 32 }, () => 'AB').join(':');
    expect(loadConfig({ ...base, ANDROID_CERT_SHA256: fp.toLowerCase(), APPLE_APP_ID: 'ABCDE12345.com.thanhbk.photobooking' }).appLinks).toEqual({
      androidPackage: 'com.thanhbk.photobooking', androidCertSha256: [fp], appleAppId: 'ABCDE12345.com.thanhbk.photobooking',
    });
    expect(() => loadConfig({ ...base, ANDROID_CERT_SHA256: 'AB:CD' })).toThrow(/fingerprints/);
  });

  it('no secret appears in the config error messages', () => {
    try {
      loadConfig({ ...base, ...urls, ...momo, MOMO_SECRET_KEY: 'tooshort' });
    } catch (e) {
      expect(String(e)).not.toContain('tooshort');
    }
  });
});
```

```ts
// services/dispatch/test/logging.test.ts
import { Writable } from 'node:stream';

import { describe, expect, it } from 'vitest';

import { createLogger } from '../src/wiring.js';

function capture() {
  const lines: string[] = [];
  const stream = new Writable({
    write(chunk, _enc, done) {
      lines.push(String(chunk));
      done();
    },
  });
  return { log: createLogger('info', stream), text: () => lines.join('') };
}

describe('logs carry no provider secret, signature or query string (plan I6)', () => {
  it('drops the query of logged request URLs', () => {
    const c = capture();
    c.log.info({ req: { id: 'r1', method: 'GET', url: '/v1/payments/webhook/vnpay?vnp_Amount=1&vnp_SecureHash=deadbeef' } }, 'incoming request');
    expect(c.text()).toContain('/v1/payments/webhook/vnpay');
    expect(c.text()).not.toContain('deadbeef');
    expect(c.text()).not.toContain('vnp_Amount');
  });

  it('redacts secrets and signatures one level deep', () => {
    const c = capture();
    c.log.warn({ momo: { secretKey: 'S3CRET-momo', accessKey: 'AK', partnerCode: 'NAGTEST' }, ipn: { signature: 'abc123' }, q: { vnp_SecureHash: 'ffee' } }, 'x');
    for (const s of ['S3CRET-momo', '"AK"', 'abc123', 'ffee']) expect(c.text()).not.toContain(s);
    expect(c.text()).toContain('NAGTEST');
  });
});
```

- [ ] **Step 2: Run and see them fail**

Run: `npm run test:unit`
Expected: FAIL: `config-payments` reports `expected undefined to deeply equal null` (no `momo` in I3's config) and `logging` reports `expected '' to contain '/v1/payments/webhook/vnpay'` (I3's `createLogger` ignores the destination).

- [ ] **Step 3: Implement**

Replace `services/dispatch/src/config.ts` with:

```ts
// services/dispatch/src/config.ts
import { readFileSync } from 'node:fs';

import { configForCity, defaultBook, type ConfigBook, type DeepPartial, type DispatchConfig } from './domain/core.js';
import { MOMO_PRODUCTION_URL, MOMO_SANDBOX_URL, type MomoConfig } from './payments/momo.js';
import { VNPAY_PRODUCTION, VNPAY_SANDBOX, type VnpayConfig } from './payments/vnpay.js';

export type AuthMode = 'firebase' | 'firebase-emulator';
export type PaymentsMode = 'fake' | 'live';
export type MirrorMode = 'firestore' | 'memory';
export type PushMode = 'fcm' | 'log';
export type Role = 'all' | 'api' | 'worker';
export type PaymentEnv = 'sandbox' | 'production';

/** Files and page that make https://<app link host>/instant/<id> open the app (Task 12). */
export interface AppLinksConfig {
  androidPackage: string;
  /** SHA-256 fingerprints of the signing certificates (Play App Signing + upload key), `AB:CD:…`. */
  androidCertSha256: string[];
  /** `<TEAMID>.<bundle id>`; null = no apple-app-site-association. */
  appleAppId: string | null;
}

export interface ServiceConfig {
  port: number;
  host: string;
  databaseUrl: string;
  redisUrl: string;
  dbPoolMax: number;
  authMode: AuthMode;
  firebaseProjectId: string;
  logLevel: string;
  nodeEnv: string;
  role: Role;
  payments: PaymentsMode;
  /** HMAC key of the fake gateway's webhook (PAYMENTS=fake only). */
  fakePaymentSecret: string;
  mirror: MirrorMode;
  push: PushMode;
  /** Goong Distance Matrix / Geocode key; null → estimate only. Never logged. */
  goongApiKey: string | null;
  goongTimeoutMs: number;
  /** Exposes GET /internal/metrics (matcher timings) for the load test. */
  metricsEndpoint: boolean;
  /** Base values + per-city overrides of every dispatch tunable (plan I2 DispatchConfig). */
  book: ConfigBook;
  /** sandbox (default) or production endpoints of MoMo and VNPay; production only with NODE_ENV=production. */
  paymentEnv: PaymentEnv;
  /** https origin the providers call (IPN URLs). Required when a live provider is configured. */
  publicBaseUrl: string | null;
  /** https origin of the return page / App Link (`<origin>/instant/<id>`); defaults to publicBaseUrl. */
  appLinkBaseUrl: string | null;
  appLinks: AppLinksConfig | null;
  /** PAYMENTS=live and MOMO_PARTNER_CODE set; secrets live only here and in the gateway. */
  momo: MomoConfig | null;
  /** PAYMENTS=live and VNPAY_TMN_CODE set. */
  vnpay: VnpayConfig | null;
}

function required(env: NodeJS.ProcessEnv, key: string): string {
  const v = env[key];
  if (v === undefined || v.trim() === '') throw new Error(`${key} is required`);
  return v.trim();
}

function int(env: NodeJS.ProcessEnv, key: string, fallback: number, min: number, max: number): number {
  const raw = env[key];
  const n = raw === undefined || raw === '' ? fallback : Number(raw);
  if (!Number.isInteger(n) || n < min || n > max) throw new Error(`${key} must be an integer between ${min} and ${max}`);
  return n;
}

function oneOf<T extends string>(env: NodeJS.ProcessEnv, key: string, allowed: readonly T[], fallback: T): T {
  const v = (env[key] ?? fallback) as T;
  if (!allowed.includes(v)) throw new Error(`${key} must be one of ${allowed.join(', ')}`);
  return v;
}

function httpsOrigin(env: NodeJS.ProcessEnv, key: string): string | null {
  const v = env[key]?.trim();
  if (!v) return null;
  let u: URL;
  try {
    u = new URL(v);
  } catch {
    throw new Error(`${key} must be an https URL`);
  }
  if (u.protocol !== 'https:' || u.pathname !== '/' || u.search !== '') throw new Error(`${key} must be an https origin without a path`);
  return u.origin;
}

function secret(env: NodeJS.ProcessEnv, key: string, min: number): string {
  const v = required(env, key);
  if (v.length < min) throw new Error(`${key} must be at least ${min} characters`);
  return v;
}

const IPV4 = /^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$/;

function loadMomo(env: NodeJS.ProcessEnv, paymentEnv: PaymentEnv, publicBaseUrl: string | null, timeoutMs: number): MomoConfig | null {
  if (!env.MOMO_PARTNER_CODE?.trim()) return null;
  if (!publicBaseUrl) throw new Error('PUBLIC_BASE_URL is required for MoMo (IPN URL)');
  return {
    partnerCode: required(env, 'MOMO_PARTNER_CODE'),
    accessKey: required(env, 'MOMO_ACCESS_KEY'),
    secretKey: secret(env, 'MOMO_SECRET_KEY', 16),
    baseUrl: paymentEnv === 'production' ? MOMO_PRODUCTION_URL : MOMO_SANDBOX_URL,
    ipnUrl: `${publicBaseUrl}/v1/payments/webhook/momo`,
    requestType: oneOf(env, 'MOMO_REQUEST_TYPE', ['captureWallet', 'payWithMethod'] as const, 'captureWallet'),
    timeoutMs,
  };
}

function loadVnpay(env: NodeJS.ProcessEnv, paymentEnv: PaymentEnv, appLinkBaseUrl: string | null, timeoutMs: number): VnpayConfig | null {
  if (!env.VNPAY_TMN_CODE?.trim()) return null;
  if (!appLinkBaseUrl) throw new Error('APP_LINK_BASE_URL (or PUBLIC_BASE_URL) is required for VNPay (vnp_ReturnUrl must be https)');
  const serverIp = required(env, 'VNPAY_SERVER_IP');
  if (!IPV4.test(serverIp)) throw new Error('VNPAY_SERVER_IP must be an IPv4 address');
  const urls = paymentEnv === 'production' ? VNPAY_PRODUCTION : VNPAY_SANDBOX;
  return { tmnCode: required(env, 'VNPAY_TMN_CODE'), hashSecret: secret(env, 'VNPAY_HASH_SECRET', 16), ...urls, serverIp, timeoutMs };
}

function loadAppLinks(env: NodeJS.ProcessEnv): AppLinksConfig | null {
  const certs = (env.ANDROID_CERT_SHA256 ?? '').split(',').map((c) => c.trim().toUpperCase()).filter((c) => c !== '');
  const apple = env.APPLE_APP_ID?.trim() || null;
  if (certs.length === 0 && !apple) return null;
  for (const c of certs) if (!/^([0-9A-F]{2}:){31}[0-9A-F]{2}$/.test(c)) throw new Error('ANDROID_CERT_SHA256 must be colon-separated SHA-256 fingerprints');
  if (apple && !/^[A-Z0-9]{10}\.[A-Za-z0-9.-]+$/.test(apple)) throw new Error('APPLE_APP_ID must be <TEAMID>.<bundle id>');
  return { androidPackage: env.ANDROID_PACKAGE?.trim() || 'com.thanhbk.photobooking', androidCertSha256: certs, appleAppId: apple };
}

/** DISPATCH_CONFIG_PATH: JSON `{ "base": {…partial…}, "cities": { "<cityId>": {…partial…} } }`. */
export function loadBook(path: string | undefined): ConfigBook {
  if (!path) return defaultBook();
  const parsed = JSON.parse(readFileSync(path, 'utf8')) as {
    base?: DeepPartial<DispatchConfig>;
    cities?: Record<string, DeepPartial<DispatchConfig>>;
  };
  const withBase = defaultBook({ __base__: parsed.base ?? {} });
  const base = configForCity(withBase, '__base__');
  const book: ConfigBook = { base, cities: parsed.cities ?? {} };
  for (const city of Object.keys(book.cities)) configForCity(book, city); // validate every city now
  return book;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): ServiceConfig {
  const nodeEnv = env.NODE_ENV ?? 'production';
  const prod = nodeEnv === 'production';
  const authMode = oneOf<AuthMode>(env, 'AUTH_MODE', ['firebase', 'firebase-emulator'], 'firebase');
  if (authMode === 'firebase-emulator' && prod) {
    throw new Error('AUTH_MODE=firebase-emulator accepts unsigned tokens and is refused when NODE_ENV=production');
  }
  const payments = oneOf<PaymentsMode>(env, 'PAYMENTS', ['fake', 'live'], 'live');
  if (payments === 'fake' && prod) throw new Error('PAYMENTS=fake is refused when NODE_ENV=production');
  const mirror = oneOf<MirrorMode>(env, 'MIRROR', ['firestore', 'memory'], 'firestore');
  if (mirror === 'memory' && prod) throw new Error('MIRROR=memory is refused when NODE_ENV=production');
  const metricsEndpoint = env.METRICS_ENDPOINT === 'true';
  if (metricsEndpoint && prod) throw new Error('METRICS_ENDPOINT=true is refused when NODE_ENV=production');
  const goong = env.GOONG_API_KEY?.trim();
  const paymentEnv = oneOf<PaymentEnv>(env, 'PAYMENT_ENV', ['sandbox', 'production'], 'sandbox');
  if (paymentEnv === 'production' && !prod) throw new Error('PAYMENT_ENV=production (real money) is refused unless NODE_ENV=production');
  const publicBaseUrl = httpsOrigin(env, 'PUBLIC_BASE_URL');
  const appLinkBaseUrl = httpsOrigin(env, 'APP_LINK_BASE_URL') ?? publicBaseUrl;
  const paymentTimeoutMs = int(env, 'PAYMENT_HTTP_TIMEOUT_MS', 8_000, 1_000, 30_000);
  const live = payments === 'live';
  return {
    port: int(env, 'PORT', 8090, 1, 65_535),
    host: env.HOST ?? '0.0.0.0',
    databaseUrl: required(env, 'DATABASE_URL'),
    redisUrl: required(env, 'REDIS_URL'),
    dbPoolMax: int(env, 'DB_POOL_MAX', 10, 1, 50),
    authMode,
    firebaseProjectId: required(env, 'FIREBASE_PROJECT_ID'),
    logLevel: env.LOG_LEVEL ?? 'info',
    nodeEnv,
    role: oneOf<Role>(env, 'ROLE', ['all', 'api', 'worker'], 'all'),
    payments,
    fakePaymentSecret: payments === 'fake' ? required(env, 'FAKE_PAYMENT_SECRET') : '',
    mirror,
    push: oneOf<PushMode>(env, 'PUSH', ['fcm', 'log'], 'fcm'),
    goongApiKey: goong ? goong : null,
    goongTimeoutMs: int(env, 'GOONG_TIMEOUT_MS', 1_500, 100, 10_000),
    metricsEndpoint,
    book: loadBook(env.DISPATCH_CONFIG_PATH),
    paymentEnv,
    publicBaseUrl,
    appLinkBaseUrl,
    appLinks: loadAppLinks(env),
    momo: live ? loadMomo(env, paymentEnv, publicBaseUrl, paymentTimeoutMs) : null,
    vnpay: live ? loadVnpay(env, paymentEnv, appLinkBaseUrl, paymentTimeoutMs) : null,
  };
}
```

Replace `services/dispatch/src/payments/registry.ts` with:

```ts
// services/dispatch/src/payments/registry.ts
import type { ServiceConfig } from '../config.js';
import { FakePaymentGateway } from './fake.js';
import { gatewayRegistry, type PaymentGateway, type PaymentGateways } from './gateway.js';
import { MomoGateway } from './momo.js';
import type { Fetch } from './status.js';
import { VnpayGateway } from './vnpay.js';

export interface GatewayWiring {
  /** Tests inject a provider stand-in; production uses global fetch. */
  fetch?: Fetch;
  now?: () => Date;
  log?: (msg: string, extra?: Record<string, unknown>) => void;
}

/**
 * The gateways this process accepts. PAYMENTS=fake → only `fake`. PAYMENTS=live → MoMo when
 * MOMO_* is set, VNPay when VNPAY_* is set (plan I6). A live process with neither has no gateway
 * and POST /v1/requests answers invalid_argument "payment provider not enabled".
 */
export function buildGateways(
  config: Pick<ServiceConfig, 'payments' | 'fakePaymentSecret'> & Partial<Pick<ServiceConfig, 'momo' | 'vnpay'>>,
  wiring: GatewayWiring = {},
): PaymentGateways {
  if (config.payments === 'fake') return gatewayRegistry([new FakePaymentGateway(config.fakePaymentSecret)]);
  const live: PaymentGateway[] = [];
  if (config.momo) live.push(new MomoGateway(config.momo, wiring));
  if (config.vnpay) live.push(new VnpayGateway(config.vnpay, wiring));
  return gatewayRegistry(live);
}
```

In `services/dispatch/src/wiring.ts`: change the import `import pino, { type Logger } from 'pino';` to `import pino, { type DestinationStream, type Logger } from 'pino';`; replace the `createLogger` function and its comment with

```ts
/**
 * Logs never carry tokens, coordinates of a fix, the Goong key, provider secrets or signatures.
 * Request URLs are logged without their query string: VNPay's IPN puts vnp_SecureHash there and
 * GET /v1/packages puts coordinates there.
 */
export const LOG_REDACT = [
  'req.headers.authorization', 'req.headers["x-fake-signature"]', '*.apiKey', '*.api_key',
  '*.secretKey', '*.accessKey', '*.hashSecret', '*.signature', '*.vnp_SecureHash',
];

export function createLogger(level: string, destination?: DestinationStream): Logger {
  const options = {
    level,
    redact: LOG_REDACT,
    serializers: {
      req: (r: { method?: string; url?: string; id?: string }) => ({ id: r.id, method: r.method, url: (r.url ?? '').split('?')[0] }),
    },
  };
  return destination ? pino(options, destination) : pino(options);
}
```

replace `    gateways: buildGateways(config),` with

```ts
    gateways: buildGateways(config, { log: (msg, extra) => log.warn(extra ?? {}, msg) }),
```

and replace `` returnUrlFor: (requestId) => `photobooking://instant/${requestId}`, `` with

```ts
    // https App Link / Universal Link when configured (VNPay requires https); the custom scheme otherwise.
    returnUrlFor: (requestId) => (config.appLinkBaseUrl ? `${config.appLinkBaseUrl}/instant/${requestId}` : `photobooking://instant/${requestId}`),
```

Append to `services/dispatch/.env.example`:

```bash
# --- Live payments (plan I6). Needs PAYMENTS=live and at least one provider below. ---
# Self-made test values only; sandbox keys come from the MoMo / VNPay test portals, never from git.
# PAYMENT_ENV=sandbox                                  # production: real money, only with NODE_ENV=production
# PUBLIC_BASE_URL=https://dispatch.example.test        # IPN: <origin>/v1/payments/webhook/momo | vnpay
# APP_LINK_BASE_URL=https://links.example.test         # return page / App Link: <origin>/instant/<id>
# PAYMENT_HTTP_TIMEOUT_MS=8000
# MOMO_PARTNER_CODE=NAGTEST
# MOMO_ACCESS_KEY=nagTestAccessKey
# MOMO_SECRET_KEY=nag-test-momo-secret-0123456789
# MOMO_REQUEST_TYPE=captureWallet                      # or payWithMethod (wallet, ATM, cards)
# VNPAY_TMN_CODE=NAGTEST1
# VNPAY_HASH_SECRET=NAGTESTVNPAYHASHSECRET0123456789
# VNPAY_SERVER_IP=203.0.113.10                         # the service's public egress IP (vnp_IpAddr)
# App Link files served by the dispatch host (Task 12):
# ANDROID_CERT_SHA256=AB:CD:...                        # Play App Signing + upload key, comma-separated
# APPLE_APP_ID=ABCDE12345.com.thanhbk.photobooking
```

- [ ] **Step 4: Run and see them pass**

Run: `npm run typecheck && npm run test:unit`
Expected: clean; `Test Files  7 passed (7)`, `Tests  55 passed (55)`. I3's `config.test.ts` and `fake-gateway.test.ts` still pass unchanged (a live config with no provider has no gateway).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): MoMo/VNPay configuration from the environment, live gateway registry, logs without secrets or query strings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Migration for live payments, `Database` types, test reset

**Files:**
- Create: `services/api/migrations/1790899300001_payments_live.sql`, `services/dispatch/test/payments/migration.test.ts`
- Modify: `services/dispatch/src/db/database.ts`, `services/dispatch/test/helpers.ts`, `services/api/test/migrations.test.ts`

**Interfaces:**
- Consumes: Task 1 (§2.4 DDL), I3's `migrate`, `migrateAll`, `API_MIGRATIONS_DIR`.
- Produces: the columns, tables and indexes of Task 1 in the api migration history (`pgmigrations`, after I3's `1790899100001`); Kysely types `PayoutStatus`, `PayoutAccountsTable` (`account_number_enc` insert-only), `PayoutsTable`, `PayoutItemsTable`, `NotificationOutcome`, `PaymentNotificationsTable`, `DisputesTable`, and the new columns on `PaymentsTable`, `RefundsTable`, `UsersTable.staff_role` (phase 2 column, read by the ops tool).

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/migration.test.ts
import pg from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { API_MIGRATIONS_DIR, migrate, migrateAll } from '../../src/db/migrate.js';

async function withClient<T>(url: string, f: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: url });
  await c.connect();
  try {
    return await f(c);
  } finally {
    await c.end();
  }
}

const columns = (url: string, table: string) =>
  withClient(url, async (c) =>
    (await c.query<{ column_name: string }>(`select column_name from information_schema.columns where table_schema = 'public' and table_name = $1 order by ordinal_position`, [table])).rows.map((r) => r.column_name),
  );

describe('api migration 1790899300001_payments_live (plan I6)', () => {
  const name = `mig_payments_live_${Date.now()}_test`;
  const scratch = (() => {
    const u = new URL(process.env.TEST_DATABASE_URL ?? '');
    u.pathname = `/${name}`;
    return u.toString();
  })();
  beforeAll(async () => {
    await withClient(process.env.TEST_DATABASE_URL ?? '', (c) => c.query(`create database ${name}`));
    await migrateAll(scratch);
  });
  afterAll(() => withClient(process.env.TEST_DATABASE_URL ?? '', (c) => c.query(`drop database if exists ${name} with (force)`)));

  it('adds the columns and tables of relational-schema.md §2.4 (plan I6)', async () => {
    expect((await columns(scratch, 'payments')).slice(-2)).toEqual(['checked_at', 'check_count']);
    expect((await columns(scratch, 'refunds')).slice(-6)).toEqual(['provider_ref', 'provider_status', 'attempts', 'updated_at', 'resolved_by', 'resolved_reference']);
    expect(await columns(scratch, 'payment_notifications')).toEqual(['id', 'provider', 'payment_id', 'kind', 'outcome', 'amount', 'provider_ref', 'source', 'received_at']);
    expect(await columns(scratch, 'disputes')).toEqual([
      'id', 'subject_type', 'subject_id', 'payment_id', 'opened_by', 'reason', 'status', 'resolution', 'refund_vnd', 'resolved_by', 'note', 'opened_at', 'resolved_at',
    ]);
    const indexes = await withClient(scratch, async (c) => (await c.query<{ indexname: string }>(`select indexname from pg_indexes where schemaname = 'public'`)).rows.map((r) => r.indexname));
    expect(indexes).toEqual(expect.arrayContaining(['ix_payments_unconfirmed', 'ix_payments_release_due', 'ix_refunds_open', 'ix_payment_notifications_attention', 'ux_disputes_open', 'ix_disputes_payment']));
  });

  it('one open dispute per subject', async () => {
    await withClient(scratch, async (c) => {
      await c.query(`insert into users (id, display_name, role) values ('c1', 'C', 'customer')`);
      await c.query(`insert into payments (id, subject_type, subject_id, provider, amount, status, idempotency_key) values ('p1', 'instant_request', 'r1', 'momo', 1000, 'paid', 'k1')`);
      const add = (id: string) => c.query(`insert into disputes (id, subject_type, subject_id, payment_id, opened_by, reason) values ($1, 'instant_request', 'r1', 'p1', 'c1', 'x')`, [id]);
      await add('d1');
      await expect(add('d2')).rejects.toThrow(/ux_disputes_open/);
    });
  });

  it('rolls back cleanly', async () => {
    await migrate(scratch, 'down', { dir: API_MIGRATIONS_DIR, table: 'pgmigrations', count: 1 });
    expect(await columns(scratch, 'disputes')).toEqual([]);
    expect((await columns(scratch, 'payments')).includes('check_count')).toBe(false);
  });
});
```

In `services/api/test/migrations.test.ts` (phase 2, edited by I3 Task 7), in `EXPECTED` replace the `payments` and `refunds` entries and add two tables, in alphabetical position:

```ts
    disputes: [
      'id', 'subject_type', 'subject_id', 'payment_id', 'opened_by', 'reason', 'status', 'resolution', 'refund_vnd', 'resolved_by', 'note',
      'opened_at', 'resolved_at',
    ],
    payment_notifications: ['id', 'provider', 'payment_id', 'kind', 'outcome', 'amount', 'provider_ref', 'source', 'received_at'],
    payments: [
      'id', 'subject_type', 'subject_id', 'payee_id', 'provider', 'amount', 'currency', 'status', 'escrow_status', 'release_after',
      'released_at', 'provider_ref', 'raw', 'idempotency_key', 'created_at', 'updated_at', 'checked_at', 'check_count',
    ],
    refunds: [
      'id', 'payment_id', 'amount', 'percent', 'status', 'manual', 'created_at', 'provider_ref', 'provider_status', 'attempts', 'updated_at',
      'resolved_by', 'resolved_reference',
    ],
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/payments/migration.test.ts`
Expected: FAIL, `expected [ 'created_at', 'updated_at' ] to deeply equal [ 'checked_at', 'check_count' ]`.

- [ ] **Step 3: Implement**

```sql
-- services/api/migrations/1790899300001_payments_live.sql
-- relational-schema.md §2.4 after plan I6 (live MoMo/VNPay, reconciliation, refunds, disputes):
-- payments: last status query and count (reconciliation backoff); refunds: provider reference,
-- last provider answer, attempts, ops resolution; payment_notifications: one row per callback or
-- status answer (no body, no signature); disputes: customer disputes in the 24 h window.
-- Up Migration
alter table payments add column checked_at timestamptz;
alter table payments add column check_count int not null default 0;
create index ix_payments_unconfirmed on payments (created_at) where status = 'created';
create index ix_payments_release_due on payments (release_after) where released_at is null and payee_id is not null;

alter table refunds add column provider_ref text;
alter table refunds add column provider_status text;
alter table refunds add column attempts int not null default 0;
alter table refunds add column updated_at timestamptz not null default now();
alter table refunds add column resolved_by text references users(id);
alter table refunds add column resolved_reference text;
create index ix_refunds_open on refunds (created_at) where status = 'pending';

create table payment_notifications (
  id           text primary key,
  provider     text not null check (provider in ('momo','vnpay','fake')),
  payment_id   text,                               -- không FK: unknown_payment giữ id cổng gửi
  kind         text check (kind in ('paid','failed')),
  outcome      text not null check (outcome in ('processed','duplicate','unknown_payment','amount_mismatch','invalid_signature','malformed','error')),
  amount       bigint,
  provider_ref text,
  source       text not null check (source in ('webhook','query')),
  received_at  timestamptz not null default now()
);
create index ix_payment_notifications_payment on payment_notifications (payment_id, received_at);
create index ix_payment_notifications_attention on payment_notifications (received_at) where outcome in ('amount_mismatch','unknown_payment','error');

create table disputes (
  id           text primary key,
  subject_type text not null check (subject_type in ('booking','event_registration','instant_request')),
  subject_id   text not null,
  payment_id   text not null references payments(id),
  opened_by    text not null references users(id),
  reason       text not null check (length(reason) between 1 and 500),
  status       text not null default 'open' check (status in ('open','resolved')),
  resolution   text check (resolution in ('released','refunded','partially_refunded')),
  refund_vnd   bigint check (refund_vnd >= 0),
  resolved_by  text references users(id),
  note         text,
  opened_at    timestamptz not null default now(),
  resolved_at  timestamptz,
  check ((status = 'open') = (resolved_at is null))
);
create unique index ux_disputes_open on disputes (subject_type, subject_id) where status = 'open';
create index ix_disputes_payment on disputes (payment_id) where status = 'open';
-- Down Migration
drop table disputes;
drop table payment_notifications;
drop index ix_refunds_open;
alter table refunds drop column resolved_reference;
alter table refunds drop column resolved_by;
alter table refunds drop column updated_at;
alter table refunds drop column attempts;
alter table refunds drop column provider_status;
alter table refunds drop column provider_ref;
drop index ix_payments_release_due;
drop index ix_payments_unconfirmed;
alter table payments drop column check_count;
alter table payments drop column checked_at;
```

In `services/dispatch/src/db/database.ts`:

1. In `UsersTable`, below `  deleted_at: Opt<Date>;` add

```ts
  /** phase 2 users.staff_role; the ops tool (plan I6) acts only for 'admin'. */
  staff_role: Opt<'admin' | 'sales'>;
```

2. In `PaymentsTable`, below `  updated_at: UpdatedAt;` add

```ts
  /** plan I6: last provider status query (reconciliation) and how many were made. */
  checked_at: Opt<Date>;
  check_count: Def<number>;
```

3. In `RefundsTable`, below `  created_at: CreatedAt;` add

```ts
  /** plan I6: the provider's refund reference, its last answer, attempts, ops resolution. */
  provider_ref: Opt<string>;
  provider_status: Opt<string>;
  attempts: Def<number>;
  updated_at: UpdatedAt;
  resolved_by: Opt<string>;
  resolved_reference: Opt<string>;
```

4. Directly above the line `// ---- relational-schema.md §2.8 (schema dispatch) ----` add

```ts
export type PayoutStatus = 'pending' | 'on_hold' | 'processing' | 'paid' | 'failed';
/** Columns used here (relational-schema §2.4). */
export interface PayoutAccountsTable {
  id: string;
  user_id: string;
  bank_code: string;
  /** Encrypted by the S44 tooling; insert-only here (tests), never selected by this service. */
  account_number_enc: ColumnType<never, Buffer, never>;
  account_last4: string;
  holder_name: string;
  active: Def<boolean>;
  created_at: CreatedAt;
}
export interface PayoutsTable {
  id: string;
  payee_id: string;
  account_id: string;
  amount: number;
  currency: Def<string>;
  status: PayoutStatus;
  reference: Opt<string>;
  approved_by: Opt<string>;
  failure_reason: Opt<string>;
  created_at: CreatedAt;
  scheduled_at: Opt<Date>;
  paid_at: Opt<Date>;
}
export interface PayoutItemsTable {
  payout_id: string;
  payment_id: string;
  amount: number;
}
export type NotificationOutcome = 'processed' | 'duplicate' | 'unknown_payment' | 'amount_mismatch' | 'invalid_signature' | 'malformed' | 'error';
/** plan I6: one row per provider callback or status query answer (no raw body, no signature). */
export interface PaymentNotificationsTable {
  id: string;
  provider: PaymentProvider;
  payment_id: Opt<string>;
  kind: Opt<'paid' | 'failed'>;
  outcome: NotificationOutcome;
  amount: Opt<number>;
  provider_ref: Opt<string>;
  source: 'webhook' | 'query';
  received_at: ColumnType<Date, Date | string | undefined, never>;
}
export interface DisputesTable {
  id: string;
  subject_type: 'booking' | 'event_registration' | 'instant_request';
  subject_id: string;
  payment_id: string;
  opened_by: string;
  reason: string;
  status: Def<'open' | 'resolved'>;
  resolution: Opt<'released' | 'refunded' | 'partially_refunded'>;
  refund_vnd: Opt<number>;
  resolved_by: Opt<string>;
  note: Opt<string>;
  opened_at: CreatedAt;
  resolved_at: Opt<Date>;
}
```

5. In `interface Database`, below `  ledger_entries: LedgerEntriesTable;` add

```ts
  payout_accounts: PayoutAccountsTable;
  payouts: PayoutsTable;
  payout_items: PayoutItemsTable;
  payment_notifications: PaymentNotificationsTable;
  disputes: DisputesTable;
```

In `services/dispatch/test/helpers.ts`, in `resetAll`, replace `    ledger_entries, refunds, payout_items, payouts, payout_accounts, payments,` with

```ts
    payment_notifications, disputes, ledger_entries, refunds, payout_items, payouts, payout_accounts, payments,
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test -- test/payments/migration.test.ts test/migrations.test.ts`, then from `services/api`: `npm test -- test/migrations.test.ts`
Expected: clean; `Tests  3 passed` and I3's dispatch migration tests still pass; phase 2's api migration test passes with the new `EXPECTED`.

- [ ] **Step 5: Commit**

```bash
git add services/api/migrations services/api/test/migrations.test.ts services/dispatch
git commit -m "feat(payments): reconciliation and refund tracking columns, payment notifications and disputes tables

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Live payment flow: gateway failure at creation, late capture, IPN log, refund tracking, mirror payment fields

**Files:**
- Create: `services/dispatch/src/payments/window.ts`, `services/dispatch/src/payments/notifications.ts`, `services/dispatch/test/payments/live-world.ts`, `services/dispatch/test/payments/live-payments.test.ts`
- Modify: `services/dispatch/src/requests/create.ts`, `services/dispatch/src/requests/publish.ts`, `services/dispatch/src/payments/events.ts`, `services/dispatch/src/payments/ledger.ts`, `services/dispatch/src/routes/payments.ts`, `services/dispatch/src/generated/api.ts` (regenerated)

**Interfaces:**
- Consumes: Tasks 1–6; I3's `createRequest`, `handlePaymentEvent`, `executeRefund`, `applySplit`, `composeRequestMirror`, webhook routes.
- Produces:
  - `PAYMENT_WINDOW_MS` moves to `payments/window.ts` (still re-exported by `requests/create.ts`).
  - `createRequest`: `payment-timeout` scheduled before the provider call; payments row `created_at` = service clock; a provider error → payment `failed`, request `payment_failed`, mirror, `ApiError('internal', 'payment provider unavailable', {provider})` (HTTP 500).
  - `handlePaymentEvent`: a `paid` event for a `failed` payment is captured and refunded in full (`'processed'`); everything else unchanged.
  - `executeRefund`: every answer saved on the refund (`provider_status` `done|pending|failed:<reason>|manual:<reason>`, `provider_ref`, `attempts + 1`, `updated_at`); behaviour per answer unchanged from I3.
  - `applySplit`: refunds `created_at`/`updated_at` = service clock.
  - `recordNotification(deps, {provider, source, outcome, event})` (never throws; logs `payment_needs_attention` for `unknown_payment`/`amount_mismatch`); the webhook route records every callback and observes `webhook_ms` in `deps.metrics`.
  - Mirror `paymentProvider` and `paymentExpiresAt` (`requestedAt + 15 min` while `pending_payment`).
  - Test support `liveWorld(db, redis)` → I3's `TestWorld` + `app`, `momo`, `vnpay` (switchable stand-ins: `set(answer)`, `slowBy(ms)`, `calls`, `paths()`, `maxInFlight()`), `MOMO_OK`, `VNPAY_OK`, `createBody`, `createLive(w, customer, provider)`, `postMomo(w, body)`, `getVnpay(w, query)`.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/live-world.ts
import type { FastifyInstance } from 'fastify';
import type { Redis } from 'ioredis';

import type { Db } from '../../src/db/database.js';
import { gatewayRegistry } from '../../src/payments/gateway.js';
import type { Fetch } from '../../src/payments/status.js';
import { MomoGateway } from '../../src/payments/momo.js';
import { VnpayGateway } from '../../src/payments/vnpay.js';
import { HCM, PACKAGES, as, testApp, testWorld, type TestWorld } from '../helpers.js';
import { providerFetch, type RecordedCall } from './provider-fetch.js';
import { MOMO_CONFIG, VNPAY_CONFIG, vnpayQueryAnswer, vnpayRefundAnswer } from './provider-messages.js';

type Answer = (url: string, body: Record<string, unknown>) => Record<string, unknown> | number | 'timeout';

/** A provider stand-in whose answers (and speed) a test can change; counts calls in flight. */
export function switchableProvider(initial: Answer): {
  calls: RecordedCall[];
  set(a: Answer): void;
  slowBy(ms: number): void;
  fetch: Fetch;
  paths(): string[];
  maxInFlight(): number;
} {
  let answer = initial;
  let delayMs = 0;
  let inFlight = 0;
  let max = 0;
  const p = providerFetch((url, body) => answer(url, body));
  const fetch: Fetch = async (url, init) => {
    inFlight++;
    max = Math.max(max, inFlight);
    try {
      if (delayMs > 0) await new Promise((r) => setTimeout(r, delayMs));
      return await p.fetch(url, init);
    } finally {
      inFlight--;
    }
  };
  return {
    calls: p.calls, fetch, set: (a) => (answer = a), slowBy: (ms) => (delayMs = ms),
    paths: () => p.calls.map((c) => new URL(c.url).pathname), maxInFlight: () => max,
  };
}

export const MOMO_OK: Answer = (url, body) =>
  url.endsWith('/create')
    ? { resultCode: 0, message: 'Thành công.', payUrl: `https://test-payment.momo.vn/v2/gateway/pay?t=${String(body.orderId)}` }
    : url.endsWith('/refund')
      ? { resultCode: 0, transId: 5000000001, amount: body.amount }
      : { resultCode: 1000, message: 'Đang chờ người dùng xác nhận' };

export const VNPAY_OK: Answer = (_url, body) => (body.vnp_Command === 'refund' ? vnpayRefundAnswer('00') : vnpayQueryAnswer('00', '01'));

export interface LiveWorld extends TestWorld {
  app: FastifyInstance;
  momo: ReturnType<typeof switchableProvider>;
  vnpay: ReturnType<typeof switchableProvider>;
}

/** The plan I3 test world with MoMo and VNPay (stand-in HTTP, real signatures) next to the fake gateway. */
export async function liveWorld(db: Db, redis: Redis): Promise<LiveWorld> {
  const w = testWorld(db, redis);
  const momo = switchableProvider(MOMO_OK);
  const vnpay = switchableProvider(VNPAY_OK);
  const now = () => w.clock.now();
  w.deps.gateways = gatewayRegistry([new MomoGateway(MOMO_CONFIG, { fetch: momo.fetch, now }), new VnpayGateway(VNPAY_CONFIG, { fetch: vnpay.fetch, now }), w.gateway]);
  const app = await testApp(w);
  return { ...w, app, momo, vnpay };
}

export const createBody = (provider: 'momo' | 'vnpay' | 'fake', over: object = {}) => ({
  packageId: PACKAGES.p60, genre: 'portrait', meetPoint: { ...HCM, address: '12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh' },
  expand: false, expectedAmountVnd: 600_000, provider, ...over,
});

export async function createLive(w: LiveWorld, customer: string, provider: 'momo' | 'vnpay'): Promise<{ requestId: string; paymentId: string; paymentUrl: string }> {
  const res = await w.app.inject({ method: 'POST', url: '/v1/requests', headers: as(customer), payload: createBody(provider) });
  if (res.statusCode !== 201) throw new Error(`create: ${res.statusCode} ${res.body}`);
  const { requestId, paymentUrl } = res.json() as { requestId: string; paymentUrl: string };
  const pay = await w.deps.db.selectFrom('payments').select('id').where('subject_id', '=', requestId).executeTakeFirstOrThrow();
  return { requestId, paymentId: pay.id, paymentUrl };
}

/** POST a MoMo IPN through the real route. */
export const postMomo = (w: LiveWorld, body: object) =>
  w.app.inject({ method: 'POST', url: '/v1/payments/webhook/momo', headers: { 'content-type': 'application/json' }, payload: JSON.stringify(body) });

/** GET a VNPay IPN through the real route. */
export const getVnpay = (w: LiveWorld, query: Record<string, string>) => w.app.inject({ method: 'GET', url: '/v1/payments/webhook/vnpay', query });
```

```ts
// services/dispatch/test/payments/live-payments.test.ts
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { heldVnd } from '../../src/payments/events.js';
import { addCustomer, as, resetAll, seedCatalog, testDb, testRedis } from '../helpers.js';
import { createBody, createLive, getVnpay, liveWorld, postMomo, type LiveWorld } from './live-world.js';
import { momoIpn, vnpayIpn } from './provider-messages.js';

const db = testDb();
const redis = testRedis();
let w: LiveWorld;
beforeEach(async () => {
  await resetAll(db, redis);
  w = await liveWorld(db, redis);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const payment = (requestId: string) => db.selectFrom('payments').selectAll().where('subject_id', '=', requestId).executeTakeFirstOrThrow();
const notes = () => db.selectFrom('payment_notifications').select(['provider', 'outcome', 'kind', 'source']).orderBy('id').execute();

describe('MoMo end to end through the routes (plan I6)', () => {
  it('create → signed IPN → searching; the same IPN again is a duplicate; MoMo always gets 204', async () => {
    const { requestId, paymentId, paymentUrl } = await createLive(w, 'c1', 'momo');
    expect(paymentUrl).toBe(`https://test-payment.momo.vn/v2/gateway/pay?t=${paymentId}`);
    expect(w.mirror.requests.get(requestId)).toMatchObject({ status: 'pending_payment', paymentProvider: 'momo', paymentExpiresAt: '2026-10-01T08:15:00.000Z' });
    const ipn = momoIpn(paymentId, 600_000);
    const first = await postMomo(w, ipn);
    expect([first.statusCode, first.body]).toEqual([204, '']);
    expect(w.mirror.requests.get(requestId)).toMatchObject({ status: 'searching', paymentExpiresAt: null });
    expect(await payment(requestId)).toMatchObject({ status: 'paid', provider_ref: '4088878653' });
    expect((await postMomo(w, ipn)).statusCode).toBe(204);
    expect(await heldVnd(w.deps, paymentId)).toBe(600_000);
    expect(await notes()).toEqual([
      { provider: 'momo', outcome: 'processed', kind: 'paid', source: 'webhook' },
      { provider: 'momo', outcome: 'duplicate', kind: 'paid', source: 'webhook' },
    ]);
  });

  it('a wrong amount is recorded for ops and changes nothing; a bad signature is 401', async () => {
    const { requestId, paymentId } = await createLive(w, 'c1', 'momo');
    expect((await postMomo(w, momoIpn(paymentId, 1_000))).statusCode).toBe(204);
    expect((await payment(requestId)).status).toBe('created');
    expect((await postMomo(w, { ...momoIpn(paymentId, 600_000), signature: '0'.repeat(64) })).statusCode).toBe(401);
    expect((await notes()).map((n) => n.outcome)).toEqual(['amount_mismatch', 'invalid_signature']);
  });

  it('declined (1006) → payment_failed; a later paid IPN for the same order is captured and refunded in full', async () => {
    const { requestId, paymentId } = await createLive(w, 'c1', 'momo');
    await postMomo(w, momoIpn(paymentId, 600_000, { resultCode: 1006, transId: 4088878654, message: 'Giao dịch bị từ chối bởi người dùng.' }));
    expect(w.mirror.requests.get(requestId)?.status).toBe('payment_failed');
    expect((await payment(requestId)).status).toBe('failed');
    expect((await postMomo(w, momoIpn(paymentId, 600_000))).statusCode).toBe(204);
    await w.runDue();
    expect(await payment(requestId)).toMatchObject({ status: 'refunded', escrow_status: 'refunded' });
    expect(await db.selectFrom('refunds').select(['amount', 'status', 'provider_status', 'attempts', 'provider_ref']).execute()).toEqual([
      { amount: 600_000, status: 'done', provider_status: 'done', attempts: 1, provider_ref: '5000000001' },
    ]);
    expect(w.momo.paths()).toEqual(['/v2/gateway/api/create', '/v2/gateway/api/refund']);
    expect(w.mirror.requests.get(requestId)).toMatchObject({ status: 'payment_failed', refundVnd: 600_000 });
  });

  it('MoMo down at creation: 500, request closed at once, the customer can start again', async () => {
    w.momo.set(() => 'timeout');
    const res = await w.app.inject({ method: 'POST', url: '/v1/requests', headers: as('c1'), payload: createBody('momo') });
    expect([res.statusCode, res.json().code, res.json().message]).toEqual([500, 'internal', 'payment provider unavailable']);
    const req = await db.selectFrom('dispatch.instant_requests').select(['id', 'status']).executeTakeFirstOrThrow();
    expect(req.status).toBe('payment_failed');
    expect((await payment(req.id)).status).toBe('failed');
    expect(w.mirror.requests.get(req.id)?.status).toBe('payment_failed');
    const again = await w.app.inject({ method: 'POST', url: '/v1/requests', headers: as('c1'), payload: createBody('vnpay') });
    expect(again.statusCode).toBe(201);
  });
});

describe('VNPay end to end through the routes (plan I6)', () => {
  it('GET IPN → RspCode 00, again → 02; wrong amount → 04; unknown order → 01; bad hash → 97 (always HTTP 200)', async () => {
    const { requestId, paymentId, paymentUrl } = await createLive(w, 'c1', 'vnpay');
    expect(new URL(paymentUrl).searchParams.get('vnp_TxnRef')).toBe(paymentId);
    expect(new URL(paymentUrl).searchParams.get('vnp_CreateDate')).toBe('20261001150000');
    const wrong = await getVnpay(w, vnpayIpn(paymentId, 1_000));
    expect([wrong.statusCode, wrong.json()]).toEqual([200, { RspCode: '04', Message: 'Invalid amount' }]);
    const ok = await getVnpay(w, vnpayIpn(paymentId, 600_000));
    expect([ok.statusCode, ok.json()]).toEqual([200, { RspCode: '00', Message: 'Confirm Success' }]);
    expect(w.mirror.requests.get(requestId)?.status).toBe('searching');
    expect((await getVnpay(w, vnpayIpn(paymentId, 600_000))).json()).toMatchObject({ RspCode: '02' });
    expect((await getVnpay(w, vnpayIpn('01M3V7ME00ZZZZZZZZZZZZZZZZ', 600_000))).json()).toMatchObject({ RspCode: '01' });
    expect((await getVnpay(w, { ...vnpayIpn(paymentId, 600_000), vnp_SecureHash: 'ab'.repeat(64) })).json()).toMatchObject({ RspCode: '97' });
  });

  it('customer cancelled at VNPay (24) → payment_failed, nothing captured', async () => {
    const { requestId, paymentId } = await createLive(w, 'c1', 'vnpay');
    const r = await getVnpay(w, vnpayIpn(paymentId, 600_000, { vnp_ResponseCode: '24', vnp_TransactionStatus: '02', vnp_TransactionNo: '0', vnp_BankTranNo: '', vnp_CardType: '' }));
    expect(r.json()).toMatchObject({ RspCode: '00' });
    expect(w.mirror.requests.get(requestId)?.status).toBe('payment_failed');
    expect(await heldVnd(w.deps, paymentId)).toBe(0);
  });

  it('a refund after a cancel goes to VNPay with partial/full type and is tracked on the refund row', async () => {
    const { requestId, paymentId } = await createLive(w, 'c1', 'vnpay');
    await getVnpay(w, vnpayIpn(paymentId, 600_000));
    const cancel = await w.app.inject({ method: 'POST', url: `/v1/requests/${requestId}/cancel`, headers: as('c1'), payload: { dryRun: false } });
    expect(cancel.json()).toMatchObject({ rule: 'free_searching', refundVnd: 600_000 });
    await w.runDue();
    const call = w.vnpay.calls.find((c) => c.body.vnp_Command === 'refund');
    expect(call?.body).toMatchObject({ vnp_TxnRef: paymentId, vnp_TransactionType: '02', vnp_Amount: '60000000', vnp_TransactionNo: '14600001', vnp_TransactionDate: '20261001150000' });
    expect(await db.selectFrom('refunds').select(['status', 'provider_status']).executeTakeFirstOrThrow()).toEqual({ status: 'done', provider_status: 'done' });
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/payments/live-payments.test.ts`
Expected: FAIL: the mirror has no `paymentProvider`, `payment_notifications` stays empty, the late paid IPN is a `duplicate` (no refund), and MoMo being down answers 500 but leaves the request `pending_payment` (the second create gets 409).

- [ ] **Step 3: Implement**

Regenerate the contract types (Task 1 added the mirror fields and `DisputeBody`):

```bash
npm run gen:types
```

```ts
// services/dispatch/src/payments/window.ts
/** How long the customer has to pay before the request becomes payment_failed (plan I3 Task 10). */
export const PAYMENT_WINDOW_MS = 15 * 60_000;
```

```ts
// services/dispatch/src/payments/notifications.ts
import type { Deps } from '../deps.js';
import type { PaymentProvider } from '../domain/core.js';
import { newId } from '../ids.js';
import type { PaymentEvent, WebhookOutcome } from './gateway.js';

/**
 * One row per provider callback or status answer (plan I6): the evidence behind "idempotent",
 * the ops list of amount mismatches / unknown payments, and the IPN p95 sample. No raw body, no
 * signature, no card or wallet data. Never throws: the provider's acknowledgement must not fail
 * because of this log.
 */
export async function recordNotification(
  deps: Pick<Deps, 'db' | 'clock' | 'log'>,
  n: { provider: PaymentProvider; source: 'webhook' | 'query'; outcome: WebhookOutcome; event: PaymentEvent | null },
): Promise<void> {
  try {
    await deps.db
      .insertInto('payment_notifications')
      .values({
        id: newId(deps.clock.now().getTime()),
        provider: n.provider,
        // unknown_payment: the id is not ours; keep it for ops (no FK on purpose).
        payment_id: n.event?.paymentId.slice(0, 64) ?? null,
        kind: n.event?.kind ?? null,
        outcome: n.outcome,
        amount: n.event?.kind === 'paid' ? n.event.amountVnd : null,
        provider_ref: n.event?.providerRef ?? null,
        source: n.source,
        received_at: deps.clock.now(),
      })
      .execute();
  } catch (err) {
    deps.log.warn({ error: (err as Error).name, outcome: n.outcome }, 'payment_notification_not_recorded');
  }
  if (n.outcome === 'unknown_payment' || n.outcome === 'amount_mismatch') {
    deps.log.error({ provider: n.provider, outcome: n.outcome, paymentId: n.event?.paymentId ?? null }, 'payment_needs_attention');
  }
}
```

In `services/dispatch/src/requests/create.ts`:

1. Replace the imports block with

```ts
import { sql } from 'kysely';

import { cityAt, cityConfig, currentPriceListVersion } from '../catalog/catalog.js';
import { ewktPoint } from '../db/database.js';
import { ACTIVE_STATUSES, DispatchError, quotePrice, transition, type Genre, type PaymentProvider } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { areaFromAddress } from '../eta/eta.js';
import { ApiError } from '../errors.js';
import { newId } from '../ids.js';
import type { CreatePaymentResult } from '../payments/gateway.js';
import { PaymentProviderError } from '../payments/status.js';
import { PAYMENT_WINDOW_MS } from '../payments/window.js';
import { keys } from '../redis/keys.js';
import { publishRequest } from './publish.js';
import { bump, loadRequest, type Exec } from './rows.js';
```

2. Replace

```ts
/** How long the customer has to pay before the request becomes payment_failed. */
export const PAYMENT_WINDOW_MS = 15 * 60_000;
```

with

```ts
/** How long the customer has to pay before the request becomes payment_failed (moved to payments/window.ts by plan I6). */
export { PAYMENT_WINDOW_MS };
```

3. In the `insertInto('payments')` values, below `` amount: quote.amountVnd, status: 'created', idempotency_key: `instant:${requestId}`, `` add

```ts
        created_at: now, // service clock: reconciliation (plan I6) measures from here
```

4. Replace everything from `  const created = await gateway.createPayment({` down to (not including) `  await deps.db.updateTable('payments').set({ provider_ref: created.providerRef, raw: JSON.stringify(created.raw) })` with

```ts
  // The timer first (plan I6): whatever happens next, an unpaid request closes after the window.
  await deps.scheduler.schedule('payment-timeout', requestId, new Date(now.getTime() + PAYMENT_WINDOW_MS));
  let created: CreatePaymentResult;
  try {
    created = await gateway.createPayment({
      paymentId,
      idempotencyKey: `instant:${requestId}`,
      subject: { type: 'instant_request', id: requestId },
      amountVnd: quote.amountVnd,
      description: `Chụp ngay ${pkg.code} - ${requestId}`,
      returnUrl: deps.returnUrlFor(requestId),
      expiresAt: new Date(now.getTime() + PAYMENT_WINDOW_MS),
    });
  } catch (err) {
    // A real provider can be down or refuse: close this request at once so the customer can retry
    // (one active request per customer) instead of waiting 15 minutes.
    await failUnopenedPayment(deps, requestId, paymentId, err);
    throw new ApiError('internal', 'payment provider unavailable', { provider: input.provider });
  }
```

5. Remove the line `  await deps.scheduler.schedule('payment-timeout', requestId, new Date(now.getTime() + PAYMENT_WINDOW_MS));` that follows the `hset(keys.search(requestId), 'area', area)` call (it moved up), and append at the end of the file

```ts
/** createPayment failed: payment `failed`, request `payment_failed`, mirror updated (plan I6). */
async function failUnopenedPayment(deps: Deps, requestId: string, paymentId: string, err: unknown): Promise<void> {
  const code = err instanceof PaymentProviderError ? err.code : 'error';
  deps.log.warn({ requestId, provider: err instanceof PaymentProviderError ? err.provider : null, code }, 'payment_create_failed');
  const now = deps.clock.now();
  await deps.db.transaction().execute(async (trx) => {
    const req = await loadRequest(trx, requestId, true);
    if (!req) return;
    await trx.updateTable('payments').set({ status: 'failed', raw: JSON.stringify({ createFailed: code }) }).where('id', '=', paymentId).where('status', '=', 'created').execute();
    const t = transition(req, 'payment_failed', now, cityConfig(deps, req.cityId));
    if (t.ok) await trx.updateTable('dispatch.instant_requests').set({ status: t.to, version: bump() }).where('id', '=', requestId).execute();
  });
  await publishRequest(deps, requestId);
}
```

In `services/dispatch/src/requests/publish.ts`, add the import `import { PAYMENT_WINDOW_MS } from '../payments/window.js';`, replace the `refunded` query and the `refundTotal` line in `composeRequestMirror` with

```ts
  // One query for the payment's provider and what was refunded (failed refunds do not count).
  const money = await deps.db
    .selectFrom('payments as p')
    .leftJoin('refunds as f', (j) => j.onRef('f.payment_id', '=', 'p.id').on('f.status', '<>', 'failed'))
    .select((eb) => ['p.provider', eb.fn.sum<number>('f.amount').as('total')])
    .where('p.subject_type', '=', 'instant_request')
    .where('p.subject_id', '=', row.id)
    .groupBy('p.provider')
    .executeTakeFirst();
  const refundTotal = money?.total === null || money?.total === undefined ? null : Number(money.total);
  const pending = row.status === 'pending_payment';
```

and replace

```ts
    refundVnd: refundTotal,
    updatedAt: at.toISOString(),
```

with

```ts
    refundVnd: refundTotal,
    paymentProvider: money?.provider ?? null,
    paymentExpiresAt: pending ? new Date(row.requestedAt.getTime() + PAYMENT_WINDOW_MS).toISOString() : null,
    updatedAt: at.toISOString(),
```

In `services/dispatch/src/payments/events.ts`, replace the line `    if (pay.status !== 'created') return { outcome: 'duplicate' };` with

```ts
    // A provider can confirm money after the payment was marked failed (create error, the
    // reconciliation job giving up, a second attempt on the same order): capture it and refund it
    // in full below, because the request can no longer start a search (plan I6).
    const lateCapture = pay.status === 'failed' && event.kind === 'paid';
    if (pay.status !== 'created' && !lateCapture) return { outcome: 'duplicate' };
```

and replace the whole `executeRefund` function (and its comment) with

```ts
/**
 * Job `refund`: asks the provider to send a pending refund back. Every answer is kept on the refund
 * row (provider_status, attempts) for the poller and the ops queue (plan I6); a retryable failure
 * throws so BullMQ retries (8 attempts, exponential from 30 s).
 */
export async function executeRefund(deps: Deps, refundId: string): Promise<void> {
  const r = await deps.db
    .selectFrom('refunds as f')
    .innerJoin('payments as p', 'p.id', 'f.payment_id')
    .select(['f.id', 'f.amount', 'f.status', 'f.manual', 'p.id as payment_id', 'p.amount as payment_amount', 'p.provider', 'p.provider_ref', 'p.subject_id'])
    .where('f.id', '=', refundId)
    .executeTakeFirst();
  if (!r || r.status !== 'pending' || r.manual) return;
  const now = deps.clock.now();
  const save = (patch: { status?: 'done' | 'failed'; manual?: boolean; provider_ref?: string | null; provider_status: string }) =>
    deps.db
      .updateTable('refunds')
      .set({ ...patch, attempts: sql<number>`attempts + 1`, updated_at: now })
      .where('id', '=', refundId)
      .where('status', '=', 'pending')
      .execute();
  const gw = deps.gateways.get(r.provider);
  if (!gw) {
    await save({ manual: true, provider_status: 'manual:provider not enabled' });
    return;
  }
  const res = await gw.refund({
    refundId: r.id,
    idempotencyKey: `instant:${r.subject_id}:refund`,
    paymentId: r.payment_id,
    providerRef: r.provider_ref,
    amountVnd: r.amount,
    paymentAmountVnd: r.payment_amount,
    reason: 'instant refund',
  });
  switch (res.status) {
    case 'done':
      await save({ status: 'done', provider_ref: res.providerRef, provider_status: 'done' });
      return;
    case 'pending':
      // Final answer later: the refund poller asks the provider (Task 6).
      await save({ provider_ref: res.providerRef, provider_status: 'pending' });
      return;
    case 'manual':
      await save({ manual: true, provider_status: `manual:${res.reason}` });
      return;
    case 'failed':
      if (res.retryable) {
        await save({ provider_status: `failed:${res.reason}` });
        throw new Error(`refund ${refundId} failed, will retry`);
      }
      await save({ status: 'failed', manual: true, provider_status: `failed:${res.reason}` });
  }
}
```

In `services/dispatch/src/payments/ledger.ts`, in `applySplit` replace

```ts
    await trx.insertInto('refunds').values({ id: refundId, payment_id: input.paymentId, amount: split.refundVnd, percent, status: 'pending' }).execute();
```

with

```ts
    await trx
      .insertInto('refunds')
      .values({ id: refundId, payment_id: input.paymentId, amount: split.refundVnd, percent, status: 'pending', created_at: now, updated_at: now })
      .execute();
```

In `services/dispatch/src/routes/payments.ts`, add `import { recordNotification } from '../payments/notifications.js';` and replace, inside the webhook handler,

```ts
          const v = await gw.verifyWebhook(webhookRequest(req, provider));
```

with

```ts
          const started = performance.now();
          const v = await gw.verifyWebhook(webhookRequest(req, provider));
```

and

```ts
          const ack = gw.acknowledge(outcome);
```

with

```ts
          // Plan I6: every callback is logged (no body, no signature) and timed.
          await recordNotification(deps, { provider, source: 'webhook', outcome, event: v.ok ? v.event : null });
          deps.metrics.observe('webhook_ms', performance.now() - started);
          const ack = gw.acknowledge(outcome);
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test -- test/payments/live-payments.test.ts test/requests.test.ts test/cancel.test.ts test/contract.test.ts`
Expected: clean; `live-payments` 7 passed; I3's request, cancel and contract suites still pass (the mirror documents validate against the contract with the two new fields; `openDispute` is still in `PENDING`).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): close the request when the gateway is down, capture and refund money after failure, IPN log, refund tracking, mirror payment fields

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Reconciliation of unconfirmed payments and the refund poller (`payments-reconcile`)

**Files:**
- Create: `services/dispatch/src/payments/reconcile.ts`, `services/dispatch/test/payments/reconcile.test.ts`
- Modify: `services/dispatch/src/jobs/scheduler.ts`, `services/dispatch/src/jobs/handlers.ts`

**Interfaces:**
- Consumes: `PaymentStatusSource` (Task 3), `handlePaymentEvent`, `recordNotification`, refund columns (Tasks 6–7), `Scheduler`, `JOB_NAMES`, `reconcile()` (I3 Tasks 5, 15).
- Produces:
  - Constants `RECONCILE_EVERY_MS` 60 s, `FIRST_CHECK_AFTER_MS` 5 min, `MAX_BACKOFF_STEP` 4, `GIVE_UP_AFTER_MS` 2 h, `RECONCILE_BATCH` 24, `RECONCILE_CONCURRENCY` 4, `REFUND_FIRST_CHECK_MS` 5 min, `REFUND_RESUBMIT_AFTER_MS` 2 h, `REFUND_MAX_ATTEMPTS` 20, `REFUND_MANUAL_AFTER_MS` 24 h; `nextSlot(now, every)`.
  - `unconfirmedQuery(db, now, providers)`, `reconcilePayments(deps): Promise<ReconcileReport {checked; paid; failed; waiting; gaveUp}>`, `openRefundsQuery(db, now)`, `pollRefunds(deps): Promise<RefundPollReport {checked; done; resubmitted; manual}>`, `reconcileTick(deps)`.
  - Job names `payments-reconcile` and `escrow-release` (key `tick`) in `JOB_NAMES`; handlers; `reconcile()` (boot) seeds both ticks at their next slot.

The tick reschedules itself **before** working, at the next slot aligned to its period, so a failing tick never breaks the chain and two schedulers produce the same job id (`payments-reconcile-tick-<slotMs>`).

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/reconcile.test.ts
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { GIVE_UP_AFTER_MS, RECONCILE_BATCH, nextSlot, pollRefunds, reconcilePayments } from '../../src/payments/reconcile.js';
import { reconcile } from '../../src/jobs/handlers.js';
import { addCustomer, as, resetAll, seedCatalog, testDb, testRedis } from '../helpers.js';
import { MOMO_OK, createLive, liveWorld, postMomo, type LiveWorld } from './live-world.js';
import { momoIpn, vnpayQueryAnswer } from './provider-messages.js';

const db = testDb();
const redis = testRedis();
let w: LiveWorld;
beforeEach(async () => {
  await resetAll(db, redis);
  w = await liveWorld(db, redis);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const MIN = 60_000;
const queries = () => w.momo.paths().filter((p) => p.endsWith('/query')).length;
const momoAnswers = (query: Record<string, unknown>) =>
  w.momo.set((url, body) => (url.endsWith('/query') ? query : MOMO_OK(url, body)));

describe('payments-reconcile: lost or late IPNs (plan I6)', () => {
  it('asks nothing before 5 minutes; a paid answer starts the search like the webhook would', async () => {
    const { requestId, paymentId } = await createLive(w, 'c1', 'momo');
    momoAnswers({ resultCode: 0, transId: 4088878653, amount: 600000 });
    w.clock.advance(4 * MIN);
    expect((await reconcilePayments(w.deps)).checked).toBe(0);
    w.clock.advance(MIN);
    expect(await reconcilePayments(w.deps)).toMatchObject({ checked: 1, paid: 1 });
    expect(w.mirror.requests.get(requestId)?.status).toBe('searching');
    expect(await db.selectFrom('payment_notifications').select(['source', 'outcome', 'payment_id']).execute()).toEqual([{ source: 'query', outcome: 'processed', payment_id: paymentId }]);
    // the IPN arriving afterwards is a duplicate
    await postMomo(w, momoIpn(paymentId, 600_000));
    expect((await db.selectFrom('payment_notifications').select('outcome').orderBy('id').execute()).map((n) => n.outcome)).toEqual(['processed', 'duplicate']);
  });

  it('backs off 5 → 10 → 20 minutes while the provider says "not yet"', async () => {
    await createLive(w, 'c1', 'momo');
    momoAnswers({ resultCode: 1000 });
    const at = async (minutes: number) => {
      w.clock.set(new Date(Date.parse('2026-10-01T08:00:00.000Z') + minutes * MIN));
      await reconcilePayments(w.deps);
      return queries();
    };
    expect(await at(5)).toBe(1);
    expect(await at(14)).toBe(1);
    expect(await at(15)).toBe(2);
    expect(await at(34)).toBe(2);
    expect(await at(35)).toBe(3);
  });

  it('gives up after 2 hours (payment failed); money that still arrives is captured and refunded', async () => {
    const { requestId, paymentId } = await createLive(w, 'c1', 'momo');
    momoAnswers({ resultCode: 42 });
    await w.advance(15 * MIN); // payment-timeout → payment_failed
    expect(w.mirror.requests.get(requestId)?.status).toBe('payment_failed');
    w.clock.advance(GIVE_UP_AFTER_MS);
    expect(await reconcilePayments(w.deps)).toMatchObject({ gaveUp: 1 });
    expect((await db.selectFrom('payments').select('status').where('id', '=', paymentId).executeTakeFirstOrThrow()).status).toBe('failed');
    await postMomo(w, momoIpn(paymentId, 600_000));
    await w.runDue();
    expect(await db.selectFrom('refunds').select(['amount', 'status']).execute()).toEqual([{ amount: 600_000, status: 'done' }]);
  });

  it('VNPay querydr answers the same way', async () => {
    const { requestId } = await createLive(w, 'c1', 'vnpay');
    w.vnpay.set((_url, body) => (body.vnp_Command === 'querydr' ? vnpayQueryAnswer('00', '00') : 500));
    w.clock.advance(5 * MIN);
    expect(await reconcilePayments(w.deps)).toMatchObject({ checked: 1, paid: 1 });
    expect(w.mirror.requests.get(requestId)?.status).toBe('searching');
  });

  it(`at most ${RECONCILE_BATCH} provider calls per tick`, async () => {
    for (let i = 0; i < 60; i++) {
      await addCustomer(db, `cx${i}`);
      await createLive(w, `cx${i}`, 'momo');
    }
    momoAnswers({ resultCode: 1000 });
    w.clock.advance(5 * MIN);
    expect((await reconcilePayments(w.deps)).checked).toBe(RECONCILE_BATCH);
    expect(queries()).toBe(RECONCILE_BATCH);
  });

  it('the tick reschedules itself on the next minute and boot reconciliation seeds both ticks', async () => {
    await reconcile(w.deps);
    expect(w.scheduler.pending('payments-reconcile').map((j) => j.at.toISOString())).toEqual([nextSlot(w.clock.now(), MIN).toISOString()]);
    expect(w.scheduler.pending('escrow-release').map((j) => j.at.toISOString())).toEqual(['2026-10-01T08:05:00.000Z']);
    await w.advance(MIN);
    expect(w.scheduler.pending('payments-reconcile').map((j) => j.at.toISOString())).toEqual(['2026-10-01T08:02:00.000Z']);
  });
});

describe('refund poller and the manual queue (plan I6)', () => {
  async function cancelledMomo(): Promise<string> {
    const { requestId, paymentId } = await createLive(w, 'c1', 'momo');
    await postMomo(w, momoIpn(paymentId, 600_000));
    await w.app.inject({ method: 'POST', url: `/v1/requests/${requestId}/cancel`, headers: as('c1'), payload: { dryRun: false } });
    return paymentId;
  }
  const refund = () => db.selectFrom('refunds').select(['id', 'status', 'manual', 'provider_status', 'attempts']).executeTakeFirstOrThrow();

  it('accepted but not final (7000): the poller finds our refund id in refundTrans and marks it done', async () => {
    w.momo.set((url, body) => (url.endsWith('/refund') ? { resultCode: 7000 } : MOMO_OK(url, body)));
    await cancelledMomo();
    await w.runDue();
    const r = await refund();
    expect(r).toMatchObject({ status: 'pending', provider_status: 'pending', attempts: 1 });
    w.momo.set((url, body) => (url.endsWith('/query') ? { resultCode: 0, refundTrans: [{ orderId: r.id, amount: 600000, resultCode: 0, transId: 5000000009 }] } : MOMO_OK(url, body)));
    w.clock.advance(10 * MIN);
    expect(await pollRefunds(w.deps)).toMatchObject({ checked: 1, done: 1 });
    expect(await refund()).toMatchObject({ status: 'done', provider_status: 'done' });
  });

  it('retries ran out: submitted again after 2 hours; unconfirmed after 24 hours: manual queue', async () => {
    w.momo.set((url, body) => (url.endsWith('/refund') ? 'timeout' : MOMO_OK(url, body)));
    await cancelledMomo();
    await expect(w.runDue()).rejects.toThrow(/will retry/); // the manual scheduler surfaces what BullMQ would retry
    expect(await refund()).toMatchObject({ status: 'pending', provider_status: 'failed:unreachable' });
    w.clock.advance(2 * 60 * MIN);
    expect((await pollRefunds(w.deps)).resubmitted).toBe(1);
    expect(w.scheduler.pending('refund')).toHaveLength(1);
    w.clock.advance(24 * 60 * MIN);
    expect((await pollRefunds(w.deps)).manual).toBe(1);
    expect(await refund()).toMatchObject({ manual: true });
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/payments/reconcile.test.ts`
Expected: FAIL, `Failed to load url ../../src/payments/reconcile.js`.

- [ ] **Step 3: Implement**

In `services/dispatch/src/jobs/scheduler.ts`, replace

```ts
  'refund',
] as const;
```

with

```ts
  'refund',
  // plan I6: self-rescheduling ticks (key 'tick'), aligned to their period so duplicates collapse.
  'payments-reconcile',
  'escrow-release',
] as const;
```

```ts
// services/dispatch/src/payments/reconcile.ts
import { sql } from 'kysely';

import type { Db } from '../db/database.js';
import type { Deps } from '../deps.js';
import type { PaymentProvider } from '../domain/core.js';
import { handlePaymentEvent } from './events.js';
import { recordNotification } from './notifications.js';
import { isStatusSource, type PaymentQueryResult } from './status.js';

/** Tick of the `payments-reconcile` job. */
export const RECONCILE_EVERY_MS = 60_000;
/** A payment is asked about only after the provider had 5 minutes to send its IPN. */
export const FIRST_CHECK_AFTER_MS = 5 * 60_000;
/** Then after 10, 20, 40, 80, 80 … minutes (5 min × 2^min(checks, 4)). */
export const MAX_BACKOFF_STEP = 4;
/** No final answer 2 hours after creation: the payment is closed as failed locally. */
export const GIVE_UP_AFTER_MS = 2 * 60 * 60_000;
/**
 * At most this many provider calls per tick, this many at once (budget, Task 18): even if every call
 * waits the whole PAYMENT_HTTP_TIMEOUT_MS (8 s), a tick ends within 24 / 4 × 8 s = 48 s < 60 s.
 */
export const RECONCILE_BATCH = 24;
export const RECONCILE_CONCURRENCY = 4;
/** A refund still pending at the provider is asked about after 5 min, then with the same backoff. */
export const REFUND_FIRST_CHECK_MS = 5 * 60_000;
/** A refund whose job retries ran out is submitted again after 2 hours … */
export const REFUND_RESUBMIT_AFTER_MS = 2 * 60 * 60_000;
export const REFUND_MAX_ATTEMPTS = 20;
/** … and goes to the manual queue (refunds.manual) when nothing confirmed it within 24 hours. */
export const REFUND_MANUAL_AFTER_MS = 24 * 60 * 60_000;

/** The next tick strictly after `now`, aligned to `every` (same job id for every scheduler). */
export const nextSlot = (now: Date, every: number): Date => new Date(Math.floor(now.getTime() / every) * every + every);

async function pool<T>(items: readonly T[], size: number, f: (t: T) => Promise<void>): Promise<void> {
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(size, items.length) }, async () => {
      while (next < items.length) await f(items[next++] as T);
    }),
  );
}

const backoffDue = (now: Date) =>
  sql<boolean>`coalesce(checked_at, created_at) + make_interval(secs => 300 * power(2, least(check_count, ${MAX_BACKOFF_STEP}))) <= ${now}`;

/** Instant payments still `created`, old enough and due for a status query (index ix_payments_unconfirmed). */
export const unconfirmedQuery = (db: Db, now: Date, providers: readonly PaymentProvider[]) =>
  db
    .selectFrom('payments')
    .select(['id', 'provider', 'provider_ref', 'amount', 'created_at'])
    .where('status', '=', 'created')
    .where('subject_type', '=', 'instant_request')
    .where('provider', 'in', providers)
    .where('created_at', '<=', new Date(now.getTime() - FIRST_CHECK_AFTER_MS))
    .where(backoffDue(now))
    .orderBy('created_at')
    .limit(RECONCILE_BATCH);

export interface ReconcileReport {
  checked: number;
  paid: number;
  failed: number;
  waiting: number;
  gaveUp: number;
}

/**
 * Asks MoMo/VNPay about instant payments still `created` 5 minutes after creation (lost or late
 * IPN), with backoff, at most RECONCILE_BATCH per tick. A final answer goes through
 * handlePaymentEvent exactly like a webhook (idempotent); after 2 hours without one the payment is
 * closed as failed (a later "paid" is still captured and refunded in full by handlePaymentEvent).
 */
export async function reconcilePayments(deps: Deps): Promise<ReconcileReport> {
  const now = deps.clock.now();
  const report: ReconcileReport = { checked: 0, paid: 0, failed: 0, waiting: 0, gaveUp: 0 };
  const providers = deps.gateways.enabled().filter((p) => isStatusSource(deps.gateways.get(p)));
  if (providers.length === 0) return report;
  const due = await unconfirmedQuery(deps.db, now, providers).execute();
  await pool(due, RECONCILE_CONCURRENCY, async (p) => {
    const gw = deps.gateways.get(p.provider as PaymentProvider);
    if (!isStatusSource(gw)) return;
    report.checked++;
    let r: PaymentQueryResult;
    try {
      r = await gw.queryPayment({ paymentId: p.id, providerRef: p.provider_ref, amountVnd: p.amount });
    } catch (err) {
      r = { state: 'unknown', reason: (err as Error).name };
    }
    if (r.state === 'paid' || r.state === 'failed') {
      const outcome = await handlePaymentEvent(deps, r.event);
      await recordNotification(deps, { provider: p.provider as PaymentProvider, source: 'query', outcome, event: r.event });
      if (r.state === 'paid') report.paid++;
      else report.failed++;
      return;
    }
    if (now.getTime() - p.created_at.getTime() >= GIVE_UP_AFTER_MS) {
      const event = { kind: 'failed' as const, paymentId: p.id, providerRef: p.provider_ref, reason: `unconfirmed_${r.state}`, raw: { reconcile: r.state } };
      const outcome = await handlePaymentEvent(deps, event);
      await recordNotification(deps, { provider: p.provider as PaymentProvider, source: 'query', outcome, event });
      report.gaveUp++;
      return;
    }
    await deps.db
      .updateTable('payments')
      .set({ checked_at: now, check_count: sql<number>`check_count + 1` })
      .where('id', '=', p.id)
      .execute();
    report.waiting++;
  });
  if (report.checked > 0) deps.log.info(report, 'payments_reconciled');
  return report;
}

export interface RefundPollReport {
  checked: number;
  done: number;
  resubmitted: number;
  manual: number;
}

/** Pending instant refunds due for a look (index ix_refunds_open). */
export const openRefundsQuery = (db: Db, now: Date) =>
  db
    .selectFrom('refunds as f')
    .innerJoin('payments as p', 'p.id', 'f.payment_id')
    .select(['f.id', 'f.amount', 'f.provider_status', 'f.attempts', 'f.updated_at', 'p.id as payment_id', 'p.provider', 'p.provider_ref'])
    .where('p.subject_type', '=', 'instant_request')
    .where('f.status', '=', 'pending')
    .where('f.manual', '=', false)
    .where('f.created_at', '<=', new Date(now.getTime() - REFUND_FIRST_CHECK_MS))
    .where(sql<boolean>`f.updated_at + make_interval(secs => 300 * power(2, least(f.attempts, ${MAX_BACKOFF_STEP}))) <= ${now}`)
    .orderBy('f.created_at')
    .limit(RECONCILE_BATCH);

/**
 * Refunds the provider accepted but has not confirmed (provider_status 'pending') are asked about;
 * refunds whose job retries ran out (provider_status 'failed:…') are submitted again after 2 hours
 * (up to 20 attempts); anything unconfirmed after 24 hours joins the manual queue.
 */
export async function pollRefunds(deps: Deps): Promise<RefundPollReport> {
  const now = deps.clock.now();
  const report: RefundPollReport = { checked: 0, done: 0, resubmitted: 0, manual: 0 };
  const stale = await deps.db
    .updateTable('refunds')
    .set({ manual: true, provider_status: sql<string>`coalesce(provider_status, 'none') || ' (unconfirmed 24 h)'`, updated_at: now })
    .where('status', '=', 'pending')
    .where('manual', '=', false)
    .where('created_at', '<=', new Date(now.getTime() - REFUND_MANUAL_AFTER_MS))
    .returning('id')
    .execute();
  report.manual += stale.length;
  if (stale.length > 0) deps.log.error({ refunds: stale.length }, 'refunds_to_manual_queue');

  const open = await openRefundsQuery(deps.db, now).execute();
  await pool(open, RECONCILE_CONCURRENCY, async (f) => {
    if (f.provider_status?.startsWith('failed:')) {
      if (now.getTime() - f.updated_at.getTime() < REFUND_RESUBMIT_AFTER_MS || f.attempts >= REFUND_MAX_ATTEMPTS) return;
      await deps.scheduler.schedule('refund', f.id, now);
      report.resubmitted++;
      return;
    }
    if (f.provider_status !== 'pending') return;
    const gw = deps.gateways.get(f.provider as PaymentProvider);
    if (!isStatusSource(gw)) return;
    report.checked++;
    const r = await gw.queryRefund({ refundId: f.id, paymentId: f.payment_id, providerRef: f.provider_ref, amountVnd: f.amount });
    const touch = { attempts: sql<number>`attempts + 1`, updated_at: now };
    if (r.status === 'done') {
      await deps.db.updateTable('refunds').set({ ...touch, status: 'done', provider_ref: r.providerRef, provider_status: 'done' }).where('id', '=', f.id).execute();
      report.done++;
    } else if (r.status === 'failed' && !r.retryable) {
      await deps.db.updateTable('refunds').set({ ...touch, status: 'failed', manual: true, provider_status: `failed:${r.reason}` }).where('id', '=', f.id).execute();
      report.manual++;
    } else {
      await deps.db.updateTable('refunds').set(touch).where('id', '=', f.id).execute();
    }
  });
  return report;
}

/** Job `payments-reconcile` (key 'tick'): reschedules itself first, so a failing tick never breaks the chain. */
export async function reconcileTick(deps: Deps): Promise<void> {
  await deps.scheduler.schedule('payments-reconcile', 'tick', nextSlot(deps.clock.now(), RECONCILE_EVERY_MS));
  await reconcilePayments(deps);
  await pollRefunds(deps);
}
```

`escrowTick` and `ESCROW_EVERY_MS` come in Task 9; to keep this task building, create `services/dispatch/src/payments/escrow.ts` now with only

```ts
// services/dispatch/src/payments/escrow.ts
import type { Deps } from '../deps.js';
import { nextSlot } from './reconcile.js';

/** Tick of the `escrow-release` job. */
export const ESCROW_EVERY_MS = 5 * 60_000;

/** Job `escrow-release` (key 'tick'): reschedules itself first; the release itself arrives in Task 9. */
export async function escrowTick(deps: Deps): Promise<void> {
  await deps.scheduler.schedule('escrow-release', 'tick', nextSlot(deps.clock.now(), ESCROW_EVERY_MS));
}
```

In `services/dispatch/src/jobs/handlers.ts`, replace the import `import { executeRefund, expirePayment } from '../payments/events.js';` with

```ts
import { ESCROW_EVERY_MS, escrowTick } from '../payments/escrow.js';
import { executeRefund, expirePayment } from '../payments/events.js';
import { RECONCILE_EVERY_MS, nextSlot, reconcileTick } from '../payments/reconcile.js';
```

add to the object returned by `jobHandlers`

```ts
    'payments-reconcile': () => reconcileTick(deps),
    'escrow-release': () => escrowTick(deps),
```

and in `reconcile()`, directly above its `return { searching: …, refunds: refunds.length };` line, add

```ts
  // Plan I6: (re)start the two money ticks; the slot-aligned job id makes this a no-op when they exist.
  await deps.scheduler.schedule('payments-reconcile', 'tick', nextSlot(now, RECONCILE_EVERY_MS));
  await deps.scheduler.schedule('escrow-release', 'tick', nextSlot(now, ESCROW_EVERY_MS));
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test -- test/payments/reconcile.test.ts test/bullmq.test.ts`
Expected: clean; `reconcile` 8 passed; I3's BullMQ suite still passes (its workers now also see the two ticks, which do nothing with the fake gateway).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): reconciliation of unconfirmed payments and refund poller with backoff, resubmission and manual queue

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Escrow release after the dispute window and payout lines (`escrow-release`)

**Files:**
- Create: `services/dispatch/test/payments/escrow-world.ts`, `services/dispatch/test/payments/escrow.test.ts`
- Modify: `services/dispatch/src/payments/escrow.ts` (replace)

**Interfaces:**
- Consumes: completion and cancellation settlement of I3 (`payee_id`, `release_after` = +24 h, `fee_charged`), the ledger, `disputes` (Task 6), `nextSlot` (Task 8).
- Produces:
  - `ESCROW_EVERY_MS` 5 min, `RELEASE_BATCH` 200; `photographerShareVnd(db, paymentId)` (= Σ deposit_received + Σ refund_issued − Σ fee_charged − Σ fee_reversal − Σ escrow_released); `attachToPayout(trx, payeeId, paymentId, amount): Promise<boolean>`; `releaseDueQuery(db, now)`; `releaseDueEscrow(deps): Promise<ReleaseReport {released; vnd; batched}>`; `batchReleased(deps): Promise<number>`; `escrowTick(deps)`.
  - Ledger `escrow_released +share` with `account_owner_id` = photographer; payment `escrow_status 'released'`, `released_at`; a payout line (`payout_items`) in the payee's open `pending` payout when they have an active payout account, else later.
  - Test support `arrivedRequest`, `completedRequest(app, w, db, customer, photographer)`, `addPayoutAccount(db, uid)`, `paymentOf`, `ledgerOf`.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/escrow-world.ts
import type { FastifyInstance } from 'fastify';

import type { Db } from '../../src/db/database.js';
import { HCM, addPhotographer, as, fixAt, north, online, paidRequest, type TestWorld } from '../helpers.js';

const ok = async (p: Promise<{ statusCode: number; body: string }>, what: string) => {
  const r = await p;
  if (r.statusCode >= 300) throw new Error(`${what}: ${r.statusCode} ${r.body}`);
};

/** A request taken by `photographer`, up to `arrived` (fake gateway, plan I3 flow). */
export async function arrivedRequest(app: FastifyInstance, w: TestWorld, db: Db, customer: string, photographer: string): Promise<string> {
  const known = await db.selectFrom('users').select('id').where('id', '=', photographer).executeTakeFirst();
  if (!known) await addPhotographer(db, photographer);
  await online(app, photographer, north(HCM, 1), w.clock.now());
  const id = await paidRequest(app, customer);
  await w.runDue();
  const offer = await db.selectFrom('dispatch.instant_offers').select('id').where('request_id', '=', id).where('photographer_id', '=', photographer).executeTakeFirstOrThrow();
  await ok(app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as(photographer) }), 'accept');
  await ok(app.inject({ method: 'POST', url: `/v1/requests/${id}/arrive`, headers: as(photographer), payload: { fix: fixAt(HCM, w.clock.now()) } }), 'arrive');
  return id;
}

/** The same request shot and confirmed by the customer: `completed`, photographer share held for 24 h. */
export async function completedRequest(app: FastifyInstance, w: TestWorld, db: Db, customer: string, photographer: string): Promise<string> {
  const id = await arrivedRequest(app, w, db, customer, photographer);
  await ok(app.inject({ method: 'POST', url: `/v1/requests/${id}/start`, headers: as(photographer) }), 'start');
  await ok(app.inject({ method: 'POST', url: `/v1/requests/${id}/finish`, headers: as(photographer) }), 'finish');
  await ok(app.inject({ method: 'POST', url: `/v1/requests/${id}/confirm-complete`, headers: as(customer) }), 'confirm');
  return id;
}

export async function addPayoutAccount(db: Db, uid: string): Promise<string> {
  const id = `acct_${uid}`;
  await db.insertInto('payout_accounts').values({ id, user_id: uid, bank_code: 'VCB', account_number_enc: Buffer.from('test-only'), account_last4: '6789', holder_name: `NGUYEN VAN ${uid.toUpperCase()}` }).execute();
  return id;
}

export const paymentOf = (db: Db, requestId: string) => db.selectFrom('payments').selectAll().where('subject_id', '=', requestId).executeTakeFirstOrThrow();

export const ledgerOf = (db: Db, paymentId: string) =>
  db.selectFrom('ledger_entries').select(['type', 'amount', 'account_owner_id', 'note']).where('payment_id', '=', paymentId).orderBy('id').execute();
```

```ts
// services/dispatch/test/payments/escrow.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { escrowTick, photographerShareVnd, releaseDueEscrow } from '../../src/payments/escrow.js';
import { heldVnd } from '../../src/payments/events.js';
import { HCM, addCustomer, addPhotographer, as, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld } from '../helpers.js';
import { addPayoutAccount, completedRequest, ledgerOf, paymentOf } from './escrow-world.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeEach(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addCustomer(db, 'c2');
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const DAY = 24 * 60 * 60_000;

describe('escrow release for Chụp ngay: completed + 24 h (spec main §3g.2, plan I6)', () => {
  it('nothing moves inside the dispute window; then the share is released, booked and owed to the photographer', async () => {
    const id = await completedRequest(app, w, db, 'c1', 'p1');
    const pay = await paymentOf(db, id);
    expect(pay.release_after?.toISOString()).toBe('2026-10-02T08:00:00.000Z');
    expect(await photographerShareVnd(db, pay.id)).toBe(480_000);
    w.clock.advance(DAY - 1);
    expect((await releaseDueEscrow(w.deps)).released).toBe(0);
    w.clock.advance(1);
    expect(await releaseDueEscrow(w.deps)).toEqual({ released: 1, vnd: 480_000, batched: 0 });
    expect(await paymentOf(db, id)).toMatchObject({ escrow_status: 'released', released_at: new Date('2026-10-02T08:00:00.000Z') });
    expect(await ledgerOf(db, pay.id)).toEqual([
      { type: 'deposit_received', amount: 600_000, account_owner_id: null, note: 'instant_request' },
      { type: 'fee_charged', amount: 120_000, account_owner_id: null, note: 'instant completed' },
      { type: 'escrow_released', amount: 480_000, account_owner_id: 'p1', note: 'instant escrow release' },
    ]);
    expect(await photographerShareVnd(db, pay.id)).toBe(0);
    expect(await heldVnd(w.deps, pay.id)).toBe(600_000); // the platform still holds the money until the payout
    const owed = await db.selectFrom('ledger_entries').select((eb) => eb.fn.sum<number>('amount').as('vnd')).where('account_owner_id', '=', 'p1').executeTakeFirstOrThrow();
    expect(Number(owed.vnd)).toBe(480_000);
    expect((await releaseDueEscrow(w.deps)).released).toBe(0); // idempotent
  });

  it('payout lines: none without a payout account; batched into one pending payout once S44 is filled in', async () => {
    const a = await completedRequest(app, w, db, 'c1', 'p1');
    w.clock.advance(DAY);
    await releaseDueEscrow(w.deps);
    expect(await db.selectFrom('payouts').selectAll().execute()).toEqual([]);
    const account = await addPayoutAccount(db, 'p1');
    const b = await completedRequest(app, w, db, 'c2', 'p1');
    w.clock.advance(DAY);
    expect(await releaseDueEscrow(w.deps)).toMatchObject({ released: 1, batched: 1 });
    const payouts = await db.selectFrom('payouts').select(['payee_id', 'account_id', 'amount', 'status']).execute();
    expect(payouts).toEqual([{ payee_id: 'p1', account_id: account, amount: 960_000, status: 'pending' }]);
    const items = await db.selectFrom('payout_items').select(['payment_id', 'amount']).orderBy('payment_id').execute();
    expect(items.map((i) => i.amount)).toEqual([480_000, 480_000]);
    expect(new Set(items.map((i) => i.payment_id))).toEqual(new Set([(await paymentOf(db, a)).id, (await paymentOf(db, b)).id]));
  });

  it('a cancellation fee (en_route_fee, 20 %) is released the same way, 24 h after the cancellation', async () => {
    await addPhotographer(db, 'p1');
    await online(app, 'p1', north(HCM, 1), w.clock.now());
    const id = await paidRequest(app, 'c1');
    await w.runDue();
    const offer = await db.selectFrom('dispatch.instant_offers').select('id').where('photographer_id', '=', 'p1').executeTakeFirstOrThrow();
    await app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as('p1') });
    w.clock.advance(3 * 60_000);
    expect((await app.inject({ method: 'POST', url: `/v1/requests/${id}/cancel`, headers: as('c1'), payload: { dryRun: false } })).json()).toMatchObject({ rule: 'en_route_fee', photographerVnd: 120_000 });
    await w.runDue();
    w.clock.advance(DAY);
    expect(await releaseDueEscrow(w.deps)).toMatchObject({ released: 1, vnd: 120_000 });
    expect(await paymentOf(db, id)).toMatchObject({ status: 'partially_refunded', escrow_status: 'released' });
  });

  it('every request adds up: refunds + photographer + platform = collected, after release', async () => {
    const id = await completedRequest(app, w, db, 'c1', 'p1');
    w.clock.advance(DAY);
    await releaseDueEscrow(w.deps);
    const l = await ledgerOf(db, (await paymentOf(db, id)).id);
    const sum = (t: string) => l.filter((e) => e.type === t).reduce((s, e) => s + e.amount, 0);
    expect(-sum('refund_issued') + sum('escrow_released') + sum('fee_charged')).toBe(sum('deposit_received'));
  });

  it('escrow-release tick runs every 5 minutes and reschedules itself first', async () => {
    await escrowTick(w.deps);
    expect(w.scheduler.pending('escrow-release').map((j) => j.at.toISOString())).toEqual(['2026-10-01T08:05:00.000Z']);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/payments/escrow.test.ts`
Expected: FAIL, `The requested module '../../src/payments/escrow.js' does not provide an export named 'photographerShareVnd'`.

- [ ] **Step 3: Implement**

Replace `services/dispatch/src/payments/escrow.ts` with:

```ts
// services/dispatch/src/payments/escrow.ts
import { sql, type Transaction } from 'kysely';

import type { Database, Exec } from '../db/database.js';
import type { Deps } from '../deps.js';
import { newId } from '../ids.js';
import { nextSlot } from './reconcile.js';

type Trx = Transaction<Database>;

/** Tick of the `escrow-release` job. */
export const ESCROW_EVERY_MS = 5 * 60_000;
export const RELEASE_BATCH = 200;

/**
 * Ledger conventions added by plan I6 (spec main §3g.5, relational-schema §2.4):
 *  - release:        escrow_released  +share   (account_owner_id = photographer: their balance "sắp nhận")
 *  - payout:         payout_paid      −amount  (account_owner_id = photographer, payout_id set)
 *  - fee reversal:   adjustment       −x       (note 'fee_reversal': a dispute refund larger than the
 *                                               photographer's share takes the rest from the platform fee)
 * The photographer's share still held on a payment is
 *   Σ deposit_received + Σ refund_issued − Σ fee_charged − Σ fee_reversal − Σ escrow_released.
 * A payout "hold" is not a ledger entry (no money moves): it is payouts.status = 'on_hold'
 * or payments.escrow_status = 'disputed'.
 */
export async function photographerShareVnd(db: Exec, paymentId: string): Promise<number> {
  const r = await db
    .selectFrom('ledger_entries')
    .select(
      sql<string>`coalesce(sum(case
        when type in ('deposit_received', 'refund_issued') then amount
        when type = 'fee_charged' then -amount
        when type = 'adjustment' and note = 'fee_reversal' then -amount
        when type = 'escrow_released' then -amount
        else 0 end), 0)`.as('share'),
    )
    .where('payment_id', '=', paymentId)
    .executeTakeFirstOrThrow();
  return Number(r.share);
}

/**
 * Adds a released payment to the payee's open payout (status pending), creating one if needed.
 * No active payout account (S44 not filled in): the money stays `released` and is batched later
 * (spec main §3g.4). Returns whether it was batched.
 */
export async function attachToPayout(trx: Trx, payeeId: string, paymentId: string, amount: number): Promise<boolean> {
  if (amount <= 0) return false;
  const account = await trx.selectFrom('payout_accounts').select('id').where('user_id', '=', payeeId).where('active', '=', true).executeTakeFirst();
  if (!account) return false;
  const open = await trx
    .selectFrom('payouts')
    .select(['id'])
    .where('payee_id', '=', payeeId)
    .where('account_id', '=', account.id)
    .where('status', '=', 'pending')
    .orderBy('created_at', 'desc')
    .forUpdate()
    .executeTakeFirst();
  let payoutId: string;
  if (open) {
    payoutId = open.id;
    await trx.updateTable('payouts').set({ amount: sql<number>`amount + ${amount}` }).where('id', '=', payoutId).execute();
  } else {
    payoutId = newId();
    await trx.insertInto('payouts').values({ id: payoutId, payee_id: payeeId, account_id: account.id, amount, status: 'pending' }).execute();
  }
  await trx.insertInto('payout_items').values({ payout_id: payoutId, payment_id: paymentId, amount }).execute();
  return true;
}

/** One payment: held → released after its dispute window, ledger escrow_released, payout line. */
async function releaseOne(deps: Deps, paymentId: string, now: Date): Promise<number | null> {
  return deps.db.transaction().execute(async (trx) => {
    const pay = await trx
      .selectFrom('payments')
      .select(['id', 'payee_id', 'escrow_status', 'release_after', 'released_at'])
      .where('id', '=', paymentId)
      .forUpdate()
      .executeTakeFirst();
    if (!pay || !pay.payee_id || pay.released_at || !pay.release_after || pay.release_after > now) return null;
    if (pay.escrow_status !== 'held' && pay.escrow_status !== 'partially_refunded') return null;
    const dispute = await trx.selectFrom('disputes').select('id').where('payment_id', '=', paymentId).where('status', '=', 'open').executeTakeFirst();
    if (dispute) return null;
    const share = await photographerShareVnd(trx, paymentId);
    if (share > 0) {
      await trx
        .insertInto('ledger_entries')
        .values({ id: newId(now.getTime()), type: 'escrow_released', payment_id: paymentId, account_owner_id: pay.payee_id, amount: share, note: 'instant escrow release', at: now })
        .execute();
    }
    await trx.updateTable('payments').set({ escrow_status: 'released', released_at: now }).where('id', '=', paymentId).execute();
    await attachToPayout(trx, pay.payee_id, paymentId, share);
    return share;
  });
}

/** Shares whose dispute window has passed (index ix_payments_release_due). */
export const releaseDueQuery = (db: Exec, now: Date) =>
  db
    .selectFrom('payments')
    .select('id')
    .where('subject_type', '=', 'instant_request')
    .where('released_at', 'is', null)
    .where('payee_id', 'is not', null)
    .where('release_after', '<=', now)
    .where('escrow_status', 'in', ['held', 'partially_refunded'])
    .orderBy('release_after')
    .limit(RELEASE_BATCH);

export interface ReleaseReport {
  released: number;
  vnd: number;
  batched: number;
}

/**
 * Spec main §3g.2 for Chụp ngay: the photographer's share (completed: payout; en_route_fee and
 * no_show: their part) is released once `release_after` (= completed/cancelled + 24 h dispute
 * window, plan I3) has passed and no dispute is open; then it joins the payee's open payout.
 */
export async function releaseDueEscrow(deps: Deps): Promise<ReleaseReport> {
  const now = deps.clock.now();
  const due = await releaseDueQuery(deps.db, now).execute();
  const report: ReleaseReport = { released: 0, vnd: 0, batched: 0 };
  for (const p of due) {
    const share = await releaseOne(deps, p.id, now);
    if (share === null) continue;
    report.released++;
    report.vnd += share;
  }
  report.batched = await batchReleased(deps);
  if (report.released > 0) deps.log.info(report, 'escrow_released');
  return report;
}

/**
 * Released instant payments not in any live payout (none yet, or only in failed ones) whose payee
 * now has an active payout account: add them to the payee's open payout.
 */
export async function batchReleased(deps: Pick<Deps, 'db'>): Promise<number> {
  const rows = await deps.db
    .selectFrom('payments as p')
    .innerJoin('payout_accounts as a', (j) => j.onRef('a.user_id', '=', 'p.payee_id').on('a.active', '=', true))
    .select(['p.id', 'p.payee_id'])
    .where('p.subject_type', '=', 'instant_request')
    .where('p.escrow_status', '=', 'released')
    .where((eb) =>
      eb.not(
        eb.exists(
          eb
            .selectFrom('payout_items as i')
            .innerJoin('payouts as o', 'o.id', 'i.payout_id')
            .select('i.payment_id')
            .whereRef('i.payment_id', '=', 'p.id')
            .where('o.status', '<>', 'failed'),
        ),
      ),
    )
    .limit(RELEASE_BATCH)
    .execute();
  let batched = 0;
  for (const r of rows) {
    if (!r.payee_id) continue;
    const payeeId = r.payee_id;
    const ok = await deps.db.transaction().execute(async (trx) => {
      await trx.selectFrom('payments').select('id').where('id', '=', r.id).forUpdate().executeTakeFirst();
      const live = await trx
        .selectFrom('payout_items as i')
        .innerJoin('payouts as o', 'o.id', 'i.payout_id')
        .select('i.payout_id')
        .where('i.payment_id', '=', r.id)
        .where('o.status', '<>', 'failed')
        .executeTakeFirst();
      if (live) return false;
      const released = await trx
        .selectFrom('ledger_entries')
        .select(sql<string>`coalesce(sum(amount), 0)`.as('vnd'))
        .where('payment_id', '=', r.id)
        .where('type', '=', 'escrow_released')
        .executeTakeFirstOrThrow();
      return attachToPayout(trx, payeeId, r.id, Number(released.vnd));
    });
    if (ok) batched++;
  }
  return batched;
}

/** Job `escrow-release` (key 'tick'): reschedules itself first. */
export async function escrowTick(deps: Deps): Promise<void> {
  await deps.scheduler.schedule('escrow-release', 'tick', nextSlot(deps.clock.now(), ESCROW_EVERY_MS));
  await releaseDueEscrow(deps);
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test -- test/payments/escrow.test.ts test/trip.test.ts test/cancel.test.ts`
Expected: clean; `escrow` 5 passed; I3's trip and cancel suites unchanged.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): release the photographer's share 24 h after completion and batch it into payout lines

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Disputes: customer endpoint, frozen release, ops resolution

**Files:**
- Create: `services/dispatch/src/payments/disputes.ts`, `services/dispatch/src/routes/disputes.ts`, `services/dispatch/test/payments/disputes.test.ts`
- Modify: `services/dispatch/src/app.ts`, `services/dispatch/test/contract.test.ts` (remove `'openDispute'` from `PENDING`)

**Interfaces:**
- Consumes: `transition(…, 'open_dispute')` (plan I2: `completed → disputed` within `completion.disputeWindowMs`), `loadRequest`, `publishRequest`, `PushSender`, `photographerShareVnd` (Task 9), `Scheduler` (`refund`).
- Produces:
  - `openDispute(deps, uid, requestId, reason)`: `not_found`, `permission_denied` (not the customer), `conflict {reason}` (state machine refuses: not completed, window closed, already disputed); request `disputed`, payment `escrow_status 'disputed'` (or, when already released, its pending payout `on_hold`), a `disputes` row, mirror, push `{type: 'status', status: 'disputed'}` to the photographer.
  - `type DisputeDecision = {outcome: 'release'} | {outcome: 'refund'; refundVnd}`; `resolveDispute(deps, requestId, decision, by, note): Promise<{refundId}>`: `release` → `held` with `release_after = now` (or payout back to `pending`); `refund x` (1 ≤ x ≤ held) → refund row + `refund_issued −x`, `adjustment −(x − share)` `fee_reversal` when x exceeds the share, payment `refunded`/`partially_refunded`, remaining share released on the next tick; refused for a payment already released.
  - Route `openDispute` (`POST /v1/requests/{requestId}/dispute` → 204).

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/disputes.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { resolveDispute } from '../../src/payments/disputes.js';
import { photographerShareVnd, releaseDueEscrow } from '../../src/payments/escrow.js';
import { heldVnd } from '../../src/payments/events.js';
import { addCustomer, as, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld } from '../helpers.js';
import { expectMirror } from '../mirror-schema.js';
import { addPayoutAccount, completedRequest, ledgerOf, paymentOf } from './escrow-world.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
let id: string;
beforeEach(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addCustomer(db, 'c9');
  id = await completedRequest(app, w, db, 'c1', 'p1');
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const HOUR = 60 * 60_000;
const dispute = (uid: string, reason = 'Ảnh không đúng như đã thoả thuận') =>
  app.inject({ method: 'POST', url: `/v1/requests/${id}/dispute`, headers: as(uid), payload: { reason } });

describe('POST /v1/requests/{id}/dispute (plan I6)', () => {
  it('within 24 h: disputed, money frozen, photographer told; never released while open', async () => {
    w.clock.advance(HOUR);
    expect((await dispute('c1')).statusCode).toBe(204);
    const mirror = w.mirror.requests.get(id);
    expectMirror('InstantRequestMirror', mirror);
    expect(mirror?.status).toBe('disputed');
    expect(await paymentOf(db, id)).toMatchObject({ escrow_status: 'disputed' });
    expect(await db.selectFrom('disputes').select(['status', 'opened_by', 'reason']).executeTakeFirstOrThrow()).toEqual({ status: 'open', opened_by: 'c1', reason: 'Ảnh không đúng như đã thoả thuận' });
    expect(w.push.to('p1')).toContainEqual({ type: 'status', requestId: id, status: 'disputed' });
    w.clock.advance(3 * 24 * HOUR);
    expect((await releaseDueEscrow(w.deps)).released).toBe(0);
  });

  it('after 24 h, twice, by the photographer or a stranger, for an unknown request, or with an empty reason: refused', async () => {
    w.clock.advance(24 * HOUR + 1);
    expect([(await dispute('c1')).statusCode, (await dispute('c1')).json().code]).toEqual([409, 'conflict']);
    w.clock.advance(-2 * HOUR);
    expect((await dispute('p1')).statusCode).toBe(403);
    expect((await dispute('c9')).statusCode).toBe(403);
    expect((await dispute('c1', '')).statusCode).toBe(400);
    expect((await dispute('c1')).statusCode).toBe(204);
    expect((await dispute('c1')).statusCode).toBe(409);
    expect((await app.inject({ method: 'POST', url: '/v1/requests/01M3V7ME00ZZZZZZZZZZZZZZZZ/dispute', headers: as('c1'), payload: { reason: 'x' } })).statusCode).toBe(404);
  });
});

describe('resolveDispute (ops, plan I6)', () => {
  beforeEach(async () => {
    w.clock.advance(HOUR);
    await dispute('c1');
  });

  it('release: back to the normal path, released on the next tick', async () => {
    await resolveDispute(w.deps, id, { outcome: 'release' }, 'admin1', 'không có lỗi');
    expect((await releaseDueEscrow(w.deps)).vnd).toBe(480_000);
    expect(await db.selectFrom('disputes').select(['status', 'resolution', 'resolved_by']).executeTakeFirstOrThrow()).toEqual({ status: 'resolved', resolution: 'released', resolved_by: 'admin1' });
  });

  it('partial refund from the photographer share: 200k back, 280k released, platform keeps its 120k', async () => {
    const { refundId } = await resolveDispute(w.deps, id, { outcome: 'refund', refundVnd: 200_000 }, 'admin1', null);
    await w.runDue();
    expect(await db.selectFrom('refunds').select(['amount', 'status']).where('id', '=', refundId).executeTakeFirstOrThrow()).toEqual({ amount: 200_000, status: 'done' });
    expect((await releaseDueEscrow(w.deps)).vnd).toBe(280_000);
    const pay = await paymentOf(db, id);
    expect(pay).toMatchObject({ status: 'partially_refunded', escrow_status: 'released' });
    expect(await heldVnd(w.deps, pay.id)).toBe(400_000);
    expect(w.mirror.requests.get(id)?.refundVnd).toBe(200_000);
  });

  it('a refund larger than the share takes the rest from the fee (adjustment fee_reversal); nothing is released', async () => {
    await resolveDispute(w.deps, id, { outcome: 'refund', refundVnd: 550_000 }, 'admin1', null);
    const pay = await paymentOf(db, id);
    expect(await photographerShareVnd(db, pay.id)).toBe(0);
    expect((await ledgerOf(db, pay.id)).filter((e) => e.type === 'adjustment')).toEqual([{ type: 'adjustment', amount: -70_000, account_owner_id: null, note: 'fee_reversal' }]);
    expect(pay).toMatchObject({ escrow_status: 'partially_refunded', release_after: null });
    expect((await releaseDueEscrow(w.deps)).released).toBe(0);
  });

  it('full refund: payment refunded; more than what is held is refused', async () => {
    await expect(resolveDispute(w.deps, id, { outcome: 'refund', refundVnd: 600_001 }, 'admin1', null)).rejects.toThrow();
    await resolveDispute(w.deps, id, { outcome: 'refund', refundVnd: 600_000 }, 'admin1', null);
    expect(await paymentOf(db, id)).toMatchObject({ status: 'refunded', escrow_status: 'refunded' });
  });

  it('a payout line waiting for the bank goes on_hold when the money was already released', async () => {
    await resolveDispute(w.deps, id, { outcome: 'release' }, 'admin1', null);
    await addPayoutAccount(db, 'p1');
    await releaseDueEscrow(w.deps);
    // a second request of the same photographer, disputed after its release
    await addCustomer(db, 'c2');
    const second = await completedRequest(app, w, db, 'c2', 'p1');
    w.clock.advance(24 * HOUR);
    await releaseDueEscrow(w.deps);
    w.clock.set(new Date((await paymentOf(db, second)).release_after?.getTime() ?? 0));
    expect((await app.inject({ method: 'POST', url: `/v1/requests/${second}/dispute`, headers: as('c2'), payload: { reason: 'Thiếu ảnh' } })).statusCode).toBe(204);
    expect((await db.selectFrom('payouts').select('status').executeTakeFirstOrThrow()).status).toBe('on_hold');
  });
});
```

In `services/dispatch/test/contract.test.ts` remove `'openDispute'` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/payments/disputes.test.ts test/contract.test.ts`
Expected: FAIL: the dispute endpoint answers 404 and `openDispute` is not routed.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/payments/disputes.ts
import { sql } from 'kysely';

import { cityConfig } from '../catalog/catalog.js';
import { DispatchError, transition } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { newId } from '../ids.js';
import { publishRequest } from '../requests/publish.js';
import { bump, loadRequest } from '../requests/rows.js';
import { photographerShareVnd } from './escrow.js';

/**
 * POST /v1/requests/{id}/dispute (spec §3.1 `completed → disputed` within 24 h; spec main §3g.2):
 * the customer opens a dispute; the photographer's share stops at `disputed` (never released while
 * the dispute is open) and a payout line already waiting for the bank goes `on_hold`.
 * Resolution is an ops action (`resolveDispute`, ops CLI); the ops screen comes later.
 */
export async function openDispute(deps: Deps, uid: string, requestId: string, reason: string): Promise<void> {
  const now = deps.clock.now();
  const photographerId = await deps.db.transaction().execute(async (trx) => {
    const req = await loadRequest(trx, requestId, true);
    if (!req) throw new DispatchError('not_found');
    if (req.customerId !== uid) throw new DispatchError('permission_denied');
    const t = transition(req, 'open_dispute', now, cityConfig(deps, req.cityId));
    if (!t.ok) throw new DispatchError('conflict', { reason: t.reason });
    const pay = await trx
      .selectFrom('payments')
      .select(['id', 'released_at'])
      .where('subject_type', '=', 'instant_request')
      .where('subject_id', '=', requestId)
      .forUpdate()
      .executeTakeFirst();
    if (!pay) throw new DispatchError('conflict', { reason: 'no payment' });
    await trx.updateTable('dispatch.instant_requests').set({ status: 'disputed', version: bump() }).where('id', '=', requestId).execute();
    if (pay.released_at === null) {
      await trx.updateTable('payments').set({ escrow_status: 'disputed' }).where('id', '=', pay.id).execute();
    } else {
      await trx
        .updateTable('payouts')
        .set({ status: 'on_hold' })
        .where('status', '=', 'pending')
        .where('id', 'in', (eb) => eb.selectFrom('payout_items').select('payout_id').where('payment_id', '=', pay.id))
        .execute();
    }
    await trx
      .insertInto('disputes')
      .values({ id: newId(now.getTime()), subject_type: 'instant_request', subject_id: requestId, payment_id: pay.id, opened_by: uid, reason, opened_at: now })
      .execute();
    return req.photographerId;
  });
  await publishRequest(deps, requestId);
  if (photographerId) await deps.push.send(photographerId, { type: 'status', requestId, status: 'disputed' });
}

export type DisputeDecision = { outcome: 'release' } | { outcome: 'refund'; refundVnd: number };

/**
 * Ops resolution (admin). `release`: the share goes back to the normal release path (released on the
 * next escrow tick, or the held payout line resumes). `refund`: refund row + refund_issued from what
 * is still held; beyond the photographer's share the rest comes from the platform fee
 * (adjustment 'fee_reversal'); the remaining share, if any, is released on the next tick.
 * A payment already released cannot be refunded here (spec main §3g.3: adjustment on a later payout).
 */
export async function resolveDispute(deps: Deps, requestId: string, decision: DisputeDecision, by: string, note: string | null): Promise<{ refundId: string | null }> {
  const now = deps.clock.now();
  const out = await deps.db.transaction().execute(async (trx) => {
    const dispute = await trx
      .selectFrom('disputes')
      .select(['id', 'payment_id'])
      .where('subject_type', '=', 'instant_request')
      .where('subject_id', '=', requestId)
      .where('status', '=', 'open')
      .forUpdate()
      .executeTakeFirst();
    if (!dispute) throw new DispatchError('not_found', { reason: 'no open dispute' });
    const pay = await trx
      .selectFrom('payments')
      .select(['id', 'amount', 'released_at', 'payee_id'])
      .where('id', '=', dispute.payment_id)
      .forUpdate()
      .executeTakeFirstOrThrow();
    const close = (resolution: 'released' | 'refunded' | 'partially_refunded', refundVnd: number | null) =>
      trx
        .updateTable('disputes')
        .set({ status: 'resolved', resolution, refund_vnd: refundVnd, resolved_by: by, note, resolved_at: now })
        .where('id', '=', dispute.id)
        .execute();

    if (decision.outcome === 'release') {
      if (pay.released_at === null) {
        await trx.updateTable('payments').set({ escrow_status: 'held', release_after: now }).where('id', '=', pay.id).execute();
      } else {
        await trx
          .updateTable('payouts')
          .set({ status: 'pending' })
          .where('status', '=', 'on_hold')
          .where('id', 'in', (eb) => eb.selectFrom('payout_items').select('payout_id').where('payment_id', '=', pay.id))
          .execute();
      }
      await close('released', null);
      return { refundId: null };
    }

    if (pay.released_at !== null) throw new DispatchError('conflict', { reason: 'already released: adjust on a later payout' });
    const held = Number(
      (
        await trx
          .selectFrom('ledger_entries')
          .select(sql<string>`coalesce(sum(amount) filter (where type in ('deposit_received', 'refund_issued')), 0)`.as('held'))
          .where('payment_id', '=', pay.id)
          .executeTakeFirstOrThrow()
      ).held,
    );
    const x = decision.refundVnd;
    if (!Number.isSafeInteger(x) || x <= 0 || x > held) throw new DispatchError('invalid_argument', { reason: `refund must be 1..${held}` });
    const share = await photographerShareVnd(trx, pay.id);
    const refundId = newId(now.getTime());
    await trx
      .insertInto('refunds')
      .values({ id: refundId, payment_id: pay.id, amount: x, percent: Math.floor((x * 100) / pay.amount), status: 'pending', created_at: now, updated_at: now })
      .execute();
    await trx
      .insertInto('ledger_entries')
      .values({ id: newId(now.getTime()), type: 'refund_issued', payment_id: pay.id, refund_id: refundId, amount: -x, note: 'instant dispute', at: now })
      .execute();
    if (x > share) {
      await trx
        .insertInto('ledger_entries')
        .values({ id: newId(now.getTime()), type: 'adjustment', payment_id: pay.id, amount: -(x - share), note: 'fee_reversal', at: now })
        .execute();
    }
    const full = x === held;
    const remaining = Math.max(0, share - x);
    await trx
      .updateTable('payments')
      .set({
        status: full ? 'refunded' : 'partially_refunded',
        escrow_status: full ? 'refunded' : 'partially_refunded',
        release_after: remaining > 0 ? now : null,
      })
      .where('id', '=', pay.id)
      .execute();
    await close(full ? 'refunded' : 'partially_refunded', x);
    return { refundId };
  });
  if (out.refundId) await deps.scheduler.schedule('refund', out.refundId, now);
  await publishRequest(deps, requestId);
  return out;
}
```

```ts
// services/dispatch/src/routes/disputes.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { openDispute } from '../payments/disputes.js';

type S = components['schemas'];

export function registerDisputeRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Params: { requestId: string }; Body: S['DisputeBody'] }>({
    ...route(deps.contract, 'openDispute'),
    handler: async (req, reply) => {
      await openDispute(deps, principalOf(req).uid, req.params.requestId, req.body.reason);
      return reply.status(204).send();
    },
  });
}
```

In `services/dispatch/src/app.ts` add `import { registerDisputeRoutes } from './routes/disputes.js';` and, below `  registerHealthRoutes(app, deps);`,

```ts
  registerDisputeRoutes(app, deps);
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test -- test/payments/disputes.test.ts test/contract.test.ts`
Expected: clean; `disputes` 7 passed; the contract suite passes with an empty `PENDING`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): customer disputes within 24 h freeze the release; ops release or refund with fee reversal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Ops CLI: manual refund queue, attention list, disputes, payout export

**Files:**
- Create: `services/dispatch/src/payments/payouts.ts`, `services/dispatch/src/tools/ops.ts`, `services/dispatch/test/payments/payouts.test.ts`
- Modify: `services/dispatch/package.json` (script `ops`, build entry), `services/dispatch/README.md`

**Interfaces:**
- Consumes: `wire`, `loadConfig` (I3), `resolveDispute` (Task 10), payout tables (Task 6), `batchReleased` (Task 9).
- Produces:
  - `requireAdmin(db, uid)` (`users.staff_role = 'admin'`, else `permission_denied`); `PAYOUT_CSV_HEADER`; `exportPendingPayouts(db, by, now): Promise<{csv; payouts; totalVnd}>` (pending → processing, `approved_by`, `scheduled_at`; CSV `payout_id, payee_id, holder_name, bank_code, account_last4, amount_vnd, items, created_at`); `markPayoutPaid(db, payoutId, reference, by, now)` (ledger `payout_paid −amount`, payments `paid_out`); `markPayoutFailed(db, payoutId, reason, by)` (re-batched by the next escrow tick); `payableVnd(db, payeeId)`.
  - CLI `npm run ops -- refunds | refund-done <refundId> <bankRef> --by <uid> | attention [days] | disputes | resolve-dispute <requestId> release|refund <vnd> --by <uid> [--note …] | payouts-export <file.csv> --by <uid> | payout-paid <payoutId> <bankRef> --by <uid> | payout-failed <payoutId> <reason> --by <uid>`.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/payments/payouts.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { releaseDueEscrow } from '../../src/payments/escrow.js';
import { PAYOUT_CSV_HEADER, exportPendingPayouts, markPayoutFailed, markPayoutPaid, payableVnd } from '../../src/payments/payouts.js';
import { addCustomer, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld } from '../helpers.js';
import { addPayoutAccount, completedRequest, paymentOf } from './escrow-world.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
let requestId: string;
beforeEach(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await db.insertInto('users').values({ id: 'admin1', display_name: 'Admin', staff_role: 'admin' }).execute();
  await addCustomer(db, 'sales1');
  await db.updateTable('users').set({ staff_role: 'sales' }).where('id', '=', 'sales1').execute();
  requestId = await completedRequest(app, w, db, 'c1', 'p1');
  await addPayoutAccount(db, 'p1');
  w.clock.advance(24 * 60 * 60_000);
  await releaseDueEscrow(w.deps);
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

describe('manual payout run (spec main §3g.4, plan I6)', () => {
  it('export: admin only; pending → processing; CSV without the full account number', async () => {
    await expect(exportPendingPayouts(db, 'sales1', w.clock.now())).rejects.toThrow();
    const r = await exportPendingPayouts(db, 'admin1', w.clock.now());
    expect([r.payouts, r.totalVnd]).toEqual([1, 480_000]);
    const [header, row] = r.csv.trim().split('\n');
    expect(header).toBe(PAYOUT_CSV_HEADER.join(','));
    expect(row).toContain(',p1,NGUYEN VAN P1,VCB,6789,480000,1,');
    expect(r.csv).not.toContain('test-only');
    expect(await db.selectFrom('payouts').select(['status', 'approved_by']).executeTakeFirstOrThrow()).toEqual({ status: 'processing', approved_by: 'admin1' });
    expect((await exportPendingPayouts(db, 'admin1', w.clock.now())).payouts).toBe(0);
  });

  it('paid: ledger payout_paid, payments paid_out, nothing left to pay', async () => {
    await exportPendingPayouts(db, 'admin1', w.clock.now());
    const payout = await db.selectFrom('payouts').select('id').executeTakeFirstOrThrow();
    await markPayoutPaid(db, payout.id, 'VCB-20261002-001', 'admin1', w.clock.now());
    expect(await db.selectFrom('payouts').select(['status', 'reference']).executeTakeFirstOrThrow()).toEqual({ status: 'paid', reference: 'VCB-20261002-001' });
    expect((await paymentOf(db, requestId)).escrow_status).toBe('paid_out');
    expect(await db.selectFrom('ledger_entries').select(['amount', 'account_owner_id']).where('type', '=', 'payout_paid').execute()).toEqual([{ amount: -480_000, account_owner_id: 'p1' }]);
    expect(await payableVnd(db, 'p1')).toBe(0);
    await expect(markPayoutPaid(db, payout.id, 'again', 'admin1', w.clock.now())).rejects.toThrow();
  });

  it('failed: the payment is batched again into a new pending payout', async () => {
    await exportPendingPayouts(db, 'admin1', w.clock.now());
    const payout = await db.selectFrom('payouts').select('id').executeTakeFirstOrThrow();
    await markPayoutFailed(db, payout.id, 'sai tên chủ tài khoản', 'admin1');
    expect((await releaseDueEscrow(w.deps)).batched).toBe(1);
    expect(await db.selectFrom('payouts').select(['status', 'amount']).orderBy('created_at').execute()).toEqual([
      { status: 'failed', amount: 480_000 },
      { status: 'pending', amount: 480_000 },
    ]);
    expect(await payableVnd(db, 'p1')).toBe(480_000);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/payments/payouts.test.ts`
Expected: FAIL, `Failed to load url ../../src/payments/payouts.js`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/payments/payouts.ts
import { sql } from 'kysely';

import type { Db } from '../db/database.js';
import { DispatchError } from '../domain/core.js';
import { newId } from '../ids.js';

/** Ops actions are taken in the name of a staff admin (users.staff_role, phase 2). */
export async function requireAdmin(db: Db, uid: string): Promise<void> {
  const u = await db.selectFrom('users').select('staff_role').where('id', '=', uid).where('deleted_at', 'is', null).executeTakeFirst();
  if (u?.staff_role !== 'admin') throw new DispatchError('permission_denied', { reason: 'admin only' });
}

const csvCell = (v: string | number | null): string => {
  const s = v === null ? '' : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

export const PAYOUT_CSV_HEADER = ['payout_id', 'payee_id', 'holder_name', 'bank_code', 'account_last4', 'amount_vnd', 'items', 'created_at'] as const;

/**
 * Manual payout run (spec main §3g.4 "admin duyệt từng lô và chuyển khoản thủ công"): every
 * `pending` payout becomes `processing` (approved_by, scheduled_at) and is returned as CSV for the
 * bank transfer. The full account number is not exported (payout_accounts.account_number_enc is
 * decrypted only by the S44/KMS tooling; open question in plan I6).
 */
export async function exportPendingPayouts(db: Db, by: string, now: Date): Promise<{ csv: string; payouts: number; totalVnd: number }> {
  await requireAdmin(db, by);
  return db.transaction().execute(async (trx) => {
    const rows = await trx
      .selectFrom('payouts as o')
      .innerJoin('payout_accounts as a', 'a.id', 'o.account_id')
      .select([
        'o.id', 'o.payee_id', 'o.amount', 'o.created_at', 'a.holder_name', 'a.bank_code', 'a.account_last4',
        (eb) => eb.selectFrom('payout_items as i').select(sql<string>`count(*)`.as('n')).whereRef('i.payout_id', '=', 'o.id').as('items'),
      ])
      .where('o.status', '=', 'pending')
      .orderBy('o.created_at')
      .forUpdate('o')
      .execute();
    if (rows.length > 0) {
      await trx
        .updateTable('payouts')
        .set({ status: 'processing', approved_by: by, scheduled_at: now })
        .where('id', 'in', rows.map((r) => r.id))
        .execute();
    }
    const lines = [PAYOUT_CSV_HEADER.join(',')];
    for (const r of rows) {
      lines.push([r.id, r.payee_id, r.holder_name, r.bank_code, r.account_last4, r.amount, Number(r.items ?? 0), r.created_at.toISOString()].map(csvCell).join(','));
    }
    return { csv: `${lines.join('\n')}\n`, payouts: rows.length, totalVnd: rows.reduce((s, r) => s + r.amount, 0) };
  });
}

/** The bank confirmed the transfer: payout paid, ledger payout_paid, its payments paid_out. */
export async function markPayoutPaid(db: Db, payoutId: string, reference: string, by: string, now: Date): Promise<void> {
  await requireAdmin(db, by);
  await db.transaction().execute(async (trx) => {
    const o = await trx.selectFrom('payouts').select(['id', 'payee_id', 'amount', 'status']).where('id', '=', payoutId).forUpdate().executeTakeFirst();
    if (!o) throw new DispatchError('not_found');
    if (o.status !== 'processing') throw new DispatchError('conflict', { reason: `payout is ${o.status}` });
    await trx.updateTable('payouts').set({ status: 'paid', reference, paid_at: now }).where('id', '=', payoutId).execute();
    await trx
      .insertInto('ledger_entries')
      .values({ id: newId(now.getTime()), type: 'payout_paid', payout_id: payoutId, account_owner_id: o.payee_id, amount: -o.amount, note: `bank ${reference}`.slice(0, 200), at: now })
      .execute();
    await trx
      .updateTable('payments')
      .set({ escrow_status: 'paid_out' })
      .where('id', 'in', (eb) => eb.selectFrom('payout_items').select('payment_id').where('payout_id', '=', payoutId))
      .execute();
  });
}

/** The transfer failed: payout failed; its payments stay `released` and are batched again by the next escrow tick. */
export async function markPayoutFailed(db: Db, payoutId: string, reason: string, by: string): Promise<void> {
  await requireAdmin(db, by);
  const r = await db
    .updateTable('payouts')
    .set({ status: 'failed', failure_reason: reason.slice(0, 200) })
    .where('id', '=', payoutId)
    .where('status', 'in', ['processing', 'on_hold'])
    .executeTakeFirst();
  if (Number(r.numUpdatedRows) === 0) throw new DispatchError('conflict', { reason: 'payout is not processing' });
}

/** Payee balance "sắp nhận" (released, not paid out): Σ of their escrow_released + payout_paid entries. */
export async function payableVnd(db: Db, payeeId: string): Promise<number> {
  const r = await db
    .selectFrom('ledger_entries')
    .select(sql<string>`coalesce(sum(amount), 0)`.as('vnd'))
    .where('account_owner_id', '=', payeeId)
    .where('type', 'in', ['escrow_released', 'payout_paid'])
    .executeTakeFirstOrThrow();
  return Number(r.vnd);
}
```

```ts
// services/dispatch/src/tools/ops.ts
// Money operations for staff admins until the ops dashboard exists (spec main §3g.6, open question 18).
// Runs with the service's environment (same DATABASE_URL, REDIS_URL, provider keys):
//   npm run ops -- refunds                                   manual refund queue (pending/failed, manual)
//   npm run ops -- refund-done <refundId> <bankRef> --by <adminUid>
//   npm run ops -- attention [days]                          amount mismatches, unknown payments, errors (default 7 days)
//   npm run ops -- disputes                                  open disputes
//   npm run ops -- resolve-dispute <requestId> release --by <adminUid> [--note "…"]
//   npm run ops -- resolve-dispute <requestId> refund <vnd> --by <adminUid> [--note "…"]
//   npm run ops -- payouts-export <file.csv> --by <adminUid>  pending payouts → processing + CSV for the bank
//   npm run ops -- payout-paid <payoutId> <bankRef> --by <adminUid>
//   npm run ops -- payout-failed <payoutId> <reason> --by <adminUid>
import { writeFileSync } from 'node:fs';

import { loadConfig } from '../config.js';
import { resolveDispute } from '../payments/disputes.js';
import { exportPendingPayouts, markPayoutFailed, markPayoutPaid, requireAdmin } from '../payments/payouts.js';
import { wire } from '../wiring.js';

const args = process.argv.slice(2);
const flag = (name: string): string | null => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? (args[i + 1] ?? null) : null;
};
const by = flag('by');
const needBy = (): string => {
  if (!by) {
    console.error('--by <adminUid> is required');
    process.exit(2);
  }
  return by;
};

const w = await wire(loadConfig());
const { db } = w.deps;
const now = w.deps.clock.now();
try {
  switch (args[0]) {
    case 'refunds': {
      const rows = await db
        .selectFrom('refunds as f')
        .innerJoin('payments as p', 'p.id', 'f.payment_id')
        .select(['f.id', 'p.provider', 'p.subject_id', 'f.amount', 'f.status', 'f.provider_status', 'f.attempts', 'f.created_at'])
        .where('f.manual', '=', true)
        .where('f.resolved_reference', 'is', null)
        .where('f.status', 'in', ['pending', 'failed'])
        .orderBy('f.created_at')
        .execute();
      console.table(rows);
      break;
    }
    case 'refund-done': {
      const [, refundId, reference] = args;
      if (!refundId || !reference) throw new Error('usage: refund-done <refundId> <bankRef> --by <adminUid>');
      await requireAdmin(db, needBy());
      const r = await db
        .updateTable('refunds')
        .set({ status: 'done', resolved_by: by, resolved_reference: reference, provider_status: 'done:manual', updated_at: now })
        .where('id', '=', refundId)
        .where('manual', '=', true)
        .where('status', 'in', ['pending', 'failed'])
        .executeTakeFirst();
      console.log(Number(r.numUpdatedRows) === 1 ? `refund ${refundId} marked done` : 'no manual open refund with that id');
      break;
    }
    case 'attention': {
      const days = Number(args[1] ?? 7);
      const rows = await db
        .selectFrom('payment_notifications')
        .select(['received_at', 'provider', 'source', 'outcome', 'payment_id', 'amount', 'provider_ref'])
        .where('outcome', 'in', ['amount_mismatch', 'unknown_payment', 'error'])
        .where('received_at', '>=', new Date(now.getTime() - days * 86_400_000))
        .orderBy('received_at', 'desc')
        .execute();
      console.table(rows);
      break;
    }
    case 'disputes': {
      console.table(await db.selectFrom('disputes').select(['subject_id', 'payment_id', 'opened_by', 'reason', 'opened_at']).where('status', '=', 'open').orderBy('opened_at').execute());
      break;
    }
    case 'resolve-dispute': {
      const [, requestId, outcome, vnd] = args;
      if (!requestId || (outcome !== 'release' && outcome !== 'refund')) throw new Error('usage: resolve-dispute <requestId> release|refund <vnd> --by <adminUid>');
      await requireAdmin(db, needBy());
      const decision = outcome === 'release' ? ({ outcome } as const) : ({ outcome, refundVnd: Number(vnd) } as const);
      const r = await resolveDispute(w.deps, requestId, decision, needBy(), flag('note'));
      console.log(r.refundId ? `refund ${r.refundId} queued` : 'released');
      break;
    }
    case 'payouts-export': {
      const file = args[1];
      if (!file || file.startsWith('--')) throw new Error('usage: payouts-export <file.csv> --by <adminUid>');
      const r = await exportPendingPayouts(db, needBy(), now);
      writeFileSync(file, r.csv, { mode: 0o600 });
      console.log(`${r.payouts} payouts, ${r.totalVnd} VND → ${file} (now processing)`);
      break;
    }
    case 'payout-paid': {
      const [, payoutId, reference] = args;
      if (!payoutId || !reference) throw new Error('usage: payout-paid <payoutId> <bankRef> --by <adminUid>');
      await markPayoutPaid(db, payoutId, reference, needBy(), now);
      console.log(`payout ${payoutId} paid`);
      break;
    }
    case 'payout-failed': {
      const [, payoutId, reason] = args;
      if (!payoutId || !reason) throw new Error('usage: payout-failed <payoutId> <reason> --by <adminUid>');
      await markPayoutFailed(db, payoutId, reason, needBy());
      console.log(`payout ${payoutId} failed; its payments are batched again on the next escrow tick`);
      break;
    }
    default:
      console.error('usage: ops refunds | refund-done | attention | disputes | resolve-dispute | payouts-export | payout-paid | payout-failed');
      process.exitCode = 2;
  }
} catch (err) {
  console.error((err as Error).message);
  process.exitCode = 1;
} finally {
  await w.close();
}
```

In `services/dispatch/package.json` add the script

```json
    "ops": "node --import tsx src/tools/ops.ts",
```

and add `src/tools/ops.ts` to the `build` script's entry points (after `src/db/migrate-cli.ts`), so the image has `node dist/tools/ops.js`.

Append to `services/dispatch/README.md`:

````markdown
## Tiền: thao tác của admin (kế hoạch I6)

Chạy với cùng biến môi trường của dịch vụ (trong container: `node dist/tools/ops.js …`); `--by` là uid có `staff_role = 'admin'`.

| Việc | Lệnh |
|---|---|
| Hàng đợi hoàn tay | `npm run ops -- refunds`, rồi chuyển khoản tay và `npm run ops -- refund-done <refundId> <mã CK> --by <uid>` |
| Sai số tiền, giao dịch lạ, lỗi IPN (7 ngày) | `npm run ops -- attention` |
| Khiếu nại đang mở | `npm run ops -- disputes`; xử lý `npm run ops -- resolve-dispute <requestId> release --by <uid>` hoặc `… refund <số tiền> --by <uid> --note "…"` |
| Chi trả | `npm run ops -- payouts-export payouts.csv --by <uid>` (các lô chuyển `processing`), chuyển khoản ở ngân hàng, rồi `payout-paid <payoutId> <mã CK>` hoặc `payout-failed <payoutId> <lý do>` |

Tệp CSV không chứa số tài khoản đầy đủ (mã hoá ở `payout_accounts`); giữ tệp ở máy của admin, quyền 600, xoá sau khi đối soát.
````

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test -- test/payments/payouts.test.ts && npm run build`
Expected: clean; `payouts` 3 passed; `dist/tools/ops.js` built.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): ops CLI for the manual refund queue, attention list, disputes and the manual payout export

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Return page and App Link files on the dispatch host

**Files:**
- Create: `services/dispatch/src/routes/app-links.ts`, `services/dispatch/test/app-links.test.ts`
- Modify: `services/dispatch/src/app.ts`, `services/dispatch/src/server.ts`

**Interfaces:**
- Consumes: `AppLinksConfig`, `appLinkBaseUrl` (Task 5), `ULID_PATTERN` (I3).
- Produces: `registerAppLinkRoutes(app, links)`: `GET /instant/:requestId` (public, `no-store`, CSP `default-src 'none'`, a button to `photobooking://instant/<id>`, identical whatever the query says; 404 for a non-ULID), `GET /.well-known/assetlinks.json` (when `androidCertSha256` is set), `GET /.well-known/apple-app-site-association` (when `appleAppId` is set; `/instant/*`). `AppOptions.appLinks?: AppLinksConfig | null`. Boot warnings in `server.ts` for live-without-provider and sandbox-in-production.

`APP_LINK_BASE_URL` must be the origin that serves these two files (the dispatch host itself is simplest). Android verifies `assetlinks.json` at install; iOS fetches the association file through Apple's CDN.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/app-links.test.ts
import { afterAll, describe, expect, it } from 'vitest';

import { buildApp } from '../src/app.js';
import { EmulatorVerifier } from '../src/auth/identity.js';
import { PROJECT_ID, testDb, testRedis, testWorld } from './helpers.js';

const db = testDb();
const redis = testRedis();
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const FP = Array.from({ length: 32 }, (_, i) => i.toString(16).padStart(2, '0').toUpperCase()).join(':');
const ID = '01M3V7ME00REQ0000000000001';

describe('payment return page and App Link files (plan I6)', () => {
  it('the return page links back to the app and ignores the provider result in the query', async () => {
    const app = await buildApp({ deps: testWorld(db, redis).deps, verifier: new EmulatorVerifier({ projectId: PROJECT_ID }), appLinks: null });
    const plain = await app.inject({ method: 'GET', url: `/instant/${ID}` });
    expect(plain.statusCode).toBe(200);
    expect(plain.headers['content-type']).toContain('text/html');
    expect(plain.body).toContain(`href="photobooking://instant/${ID}"`);
    const withResult = await app.inject({ method: 'GET', url: `/instant/${ID}?vnp_ResponseCode=00&vnp_TxnRef=X&resultCode=0` });
    expect(withResult.body).toBe(plain.body);
    expect((await app.inject({ method: 'GET', url: '/instant/not-an-id' })).statusCode).toBe(404);
    expect((await app.inject({ method: 'GET', url: '/.well-known/assetlinks.json' })).statusCode).toBe(404);
    await app.close();
  });

  it('serves assetlinks.json and apple-app-site-association when configured', async () => {
    const app = await buildApp({
      deps: testWorld(db, redis).deps, verifier: new EmulatorVerifier({ projectId: PROJECT_ID }),
      appLinks: { androidPackage: 'com.thanhbk.photobooking', androidCertSha256: [FP], appleAppId: 'ABCDE12345.com.thanhbk.photobooking' },
    });
    const android = await app.inject({ method: 'GET', url: '/.well-known/assetlinks.json' });
    expect(android.json()).toEqual([
      { relation: ['delegate_permission/common.handle_all_urls'], target: { namespace: 'android_app', package_name: 'com.thanhbk.photobooking', sha256_cert_fingerprints: [FP] } },
    ]);
    const apple = await app.inject({ method: 'GET', url: '/.well-known/apple-app-site-association' });
    expect(apple.headers['content-type']).toContain('application/json');
    expect(apple.json()).toMatchObject({ applinks: { details: [{ appIDs: ['ABCDE12345.com.thanhbk.photobooking'], components: [{ '/': '/instant/*' }] }] } });
    await app.close();
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/app-links.test.ts`
Expected: FAIL, `expected 404 to be 200` (no `/instant/:requestId` route).

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/routes/app-links.ts
import type { FastifyInstance } from 'fastify';

import type { AppLinksConfig } from '../config.js';
import { ULID_PATTERN } from '../ids.js';

/**
 * Where MoMo/VNPay send the customer after paying (`returnUrlFor`): https://<host>/instant/<id>.
 * With the App Link (Android, autoVerify) or Universal Link (iOS) verified, the OS opens the app
 * directly and this page is never shown; otherwise it offers a button to the app. It never reads
 * the provider's query parameters (vnp_ResponseCode, resultCode …): the app learns the result only
 * from the mirror, after the verified webhook (spec §4 "không tin redirect").
 * Outside /v1 and outside the contract, like /internal/metrics.
 */
export function registerAppLinkRoutes(app: FastifyInstance, links: AppLinksConfig | null): void {
  app.get<{ Params: { requestId: string } }>('/instant/:requestId', { config: { public: true } }, async (req, reply) => {
    const id = req.params.requestId;
    if (!ULID_PATTERN.test(id)) return reply.status(404).type('text/plain; charset=utf-8').send('Không tìm thấy');
    const deep = `photobooking://instant/${id}`;
    return reply
      .header('cache-control', 'no-store')
      .header('content-security-policy', "default-src 'none'; style-src 'unsafe-inline'")
      .header('referrer-policy', 'no-referrer')
      .type('text/html; charset=utf-8')
      .send(`<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quay lại ứng dụng</title>
<style>body{font-family:system-ui,sans-serif;margin:0;padding:32px 20px;background:#0b0b12;color:#f5f5f7;text-align:center}
a{display:inline-block;margin-top:24px;padding:14px 28px;border-radius:999px;background:#7c5cff;color:#fff;text-decoration:none;font-weight:600}
p{color:#c9c9d1;line-height:1.5}</style></head>
<body><h1>Đã xong bước thanh toán</h1>
<p>Quay lại ứng dụng Nhiếp ảnh gia để xem kết quả. Ứng dụng tự cập nhật khi cổng thanh toán xác nhận.</p>
<a href="${deep}">Mở ứng dụng</a></body></html>`);
  });
  if (!links) return;
  if (links.androidCertSha256.length > 0) {
    app.get('/.well-known/assetlinks.json', { config: { public: true } }, async (_req, reply) =>
      reply.type('application/json').send([
        {
          relation: ['delegate_permission/common.handle_all_urls'],
          target: { namespace: 'android_app', package_name: links.androidPackage, sha256_cert_fingerprints: links.androidCertSha256 },
        },
      ]),
    );
  }
  if (links.appleAppId) {
    const appleAppId = links.appleAppId;
    app.get('/.well-known/apple-app-site-association', { config: { public: true } }, async (_req, reply) =>
      reply.type('application/json').send({ applinks: { details: [{ appIDs: [appleAppId], components: [{ '/': '/instant/*', comment: 'Chụp ngay: quay lại sau thanh toán' }] }] } }),
    );
  }
}
```

In `services/dispatch/src/app.ts` add the imports `import type { AppLinksConfig } from './config.js';` and `import { registerAppLinkRoutes } from './routes/app-links.js';`, add to `AppOptions`

```ts
  /** Return page and App Link files (plan I6); the page is always served, the files only when configured. */
  appLinks?: AppLinksConfig | null;
```

and below `  registerDisputeRoutes(app, deps);`

```ts
  registerAppLinkRoutes(app, o.appLinks ?? null);
```

In `services/dispatch/src/server.ts`, pass `appLinks: config.appLinks` to `buildApp({ … })`, and directly above `if (worker) {` add

```ts
if (config.payments === 'live' && w.deps.gateways.enabled().length === 0) {
  w.deps.log.warn('PAYMENTS=live but no MOMO_* / VNPAY_* configured: "Chụp ngay" cannot take payments');
}
if (config.payments === 'live' && config.paymentEnv === 'sandbox' && config.nodeEnv === 'production') {
  w.deps.log.warn('PAYMENT_ENV=sandbox with NODE_ENV=production: staging only, no real money moves');
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test -- test/app-links.test.ts test/contract.test.ts`
Expected: clean; `app-links` 2 passed; the contract suite still passes (the new routes are outside `/v1`).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(payments): payment return page, assetlinks.json and apple-app-site-association on the dispatch host

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Sandbox cross-check before going live

The vectors of Task 2 are ours. This task proves MoMo and VNPay agree, on their sandboxes, before any production key exists. Nothing here changes behaviour; the tool only calls the gateways of Tasks 3–4 with the sandbox configuration.

**Files:**
- Create: `services/dispatch/src/tools/sandbox-check.ts`
- Modify: `services/dispatch/package.json` (script `sandbox:check`, build entry), `services/dispatch/README.md`

**Interfaces:**
- Consumes: `loadConfig`, `MomoGateway`, `VnpayGateway`, `newId`.
- Produces: `npm run sandbox:check -- momo-create | momo-query <orderId> | momo-refund <orderId> <transId> <amount> | momo-ipn '<json>' | vnpay-url | vnpay-ipn '<query>' | vnpay-query <txnRef> | vnpay-refund <txnRef> <transactionNo> <amount> <paymentAmount>` (refuses to run unless `PAYMENT_ENV=sandbox`; prints provider codes, never keys or signatures).

- [ ] **Step 1: Add the tool**

```ts
// services/dispatch/src/tools/sandbox-check.ts
// Cross-check of the self-written signatures against the real MoMo / VNPay sandboxes (plan I6 Task 13).
// Needs PAYMENTS=live, PAYMENT_ENV=sandbox and the sandbox MOMO_* / VNPAY_* / PUBLIC_BASE_URL in the environment.
//   npm run sandbox:check -- momo-create            creates a 10.000₫ order; prints the payUrl (resultCode 0 = signature accepted)
//   npm run sandbox:check -- momo-query <orderId>
//   npm run sandbox:check -- momo-refund <orderId> <transId> <amount>
//   npm run sandbox:check -- momo-ipn '<json>'      verifies an IPN body copied from the MoMo test portal
//   npm run sandbox:check -- vnpay-url              prints a 10.000₫ payment URL (the page must not say "Sai chữ ký")
//   npm run sandbox:check -- vnpay-ipn '<query>'    verifies an IPN query string copied from the VNPay sandbox portal
//   npm run sandbox:check -- vnpay-query <txnRef>
//   npm run sandbox:check -- vnpay-refund <txnRef> <transactionNo> <amount> <paymentAmount>
// Prints provider codes only; never prints keys or signatures.
import { loadConfig } from '../config.js';
import { newId } from '../ids.js';
import { MomoGateway } from '../payments/momo.js';
import { VnpayGateway } from '../payments/vnpay.js';

const config = loadConfig();
if (config.paymentEnv !== 'sandbox') {
  console.error('sandbox-check runs only with PAYMENT_ENV=sandbox');
  process.exit(2);
}
const [cmd, a, b, c, d] = process.argv.slice(2);
const log = (msg: string, extra?: Record<string, unknown>) => console.error(msg, extra ?? '');
const momo = config.momo ? new MomoGateway(config.momo, { log }) : null;
const vnpay = config.vnpay ? new VnpayGateway(config.vnpay, { log }) : null;
const order = () => {
  const paymentId = newId();
  const requestId = newId();
  return {
    paymentId, idempotencyKey: `instant:${requestId}`, subject: { type: 'instant_request' as const, id: requestId }, amountVnd: 10_000,
    description: `Chụp ngay sandbox - ${requestId}`, returnUrl: `${config.appLinkBaseUrl ?? 'https://example.invalid'}/instant/${requestId}`,
    expiresAt: new Date(Date.now() + 15 * 60_000),
  };
};
const need = <T>(g: T | null, name: string): T => {
  if (!g) {
    console.error(`${name} is not configured`);
    process.exit(2);
  }
  return g;
};

switch (cmd) {
  case 'momo-create': {
    const o = order();
    const r = await need(momo, 'MoMo').createPayment(o);
    console.log({ orderId: o.paymentId, payUrl: r.paymentUrl, raw: r.raw });
    break;
  }
  case 'momo-query':
    console.log(await need(momo, 'MoMo').queryPayment({ paymentId: a ?? '', providerRef: null, amountVnd: 0 }));
    break;
  case 'momo-refund':
    console.log(await need(momo, 'MoMo').refund({ refundId: newId(), idempotencyKey: 'sandbox', paymentId: a ?? '', providerRef: b ?? null, amountVnd: Number(c), paymentAmountVnd: Number(c), reason: 'sandbox refund' }));
    break;
  case 'momo-ipn': {
    const v = await need(momo, 'MoMo').verifyWebhook({ provider: 'momo', method: 'POST', headers: {}, query: {}, rawBody: a ?? '' });
    console.log(v.ok ? { ok: true, kind: v.event.kind, amountVnd: v.event.kind === 'paid' ? v.event.amountVnd : null } : v);
    break;
  }
  case 'vnpay-url': {
    const o = order();
    console.log({ txnRef: o.paymentId, url: (await need(vnpay, 'VNPay').createPayment(o)).paymentUrl });
    break;
  }
  case 'vnpay-ipn': {
    const query = Object.fromEntries(new URLSearchParams((a ?? '').replace(/^\?/, '')));
    const v = await need(vnpay, 'VNPay').verifyWebhook({ provider: 'vnpay', method: 'GET', headers: {}, query, rawBody: '' });
    console.log(v.ok ? { ok: true, kind: v.event.kind } : v);
    break;
  }
  case 'vnpay-query':
    console.log(await need(vnpay, 'VNPay').queryPayment({ paymentId: a ?? '', providerRef: null, amountVnd: 0 }));
    break;
  case 'vnpay-refund':
    console.log(await need(vnpay, 'VNPay').refund({ refundId: newId(), idempotencyKey: 'sandbox', paymentId: a ?? '', providerRef: b ?? null, amountVnd: Number(c), paymentAmountVnd: Number(d), reason: 'sandbox refund' }));
    break;
  default:
    console.error('usage: sandbox-check momo-create | momo-query | momo-refund | momo-ipn | vnpay-url | vnpay-ipn | vnpay-query | vnpay-refund');
    process.exit(2);
}
```

In `services/dispatch/package.json` add the script `"sandbox:check": "node --import tsx src/tools/sandbox-check.ts",` and add `src/tools/sandbox-check.ts` to the `build` entry points.

Run: `npm run typecheck && npm run build`
Expected: clean; `dist/tools/sandbox-check.js` built.

- [ ] **Step 2: [người dùng] Staging with sandbox keys**

Deploy the service to staging (public https host, e.g. `https://dispatch-staging.<domain>`) with `NODE_ENV=production`, `PAYMENTS=live`, `PAYMENT_ENV=sandbox`, `PUBLIC_BASE_URL` and `APP_LINK_BASE_URL` = that host, and the sandbox `MOMO_*` (MoMo Business test merchant) and `VNPAY_*` (VNPay sandbox terminal) from the providers' portals, stored as secrets of the deployment (never in a file in git). In the VNPay sandbox merchant admin set the IPN URL to `https://<staging host>/v1/payments/webhook/vnpay`. MoMo takes the IPN URL from each request (`ipnUrl`). Open `/v1/health` on the host: `{"ok":true,…}`.

- [ ] **Step 3: MoMo**

From a shell with the same environment:

1. `npm run sandbox:check -- momo-create` → prints `raw.resultCode: 0` and a `payUrl` on `test-payment.momo.vn`. A `resultCode` other than 0 means our create signature or a field is refused: if it complains about `orderExpireTime`, delete that field from `MomoGateway.createPayment` and from the expected body in `momo-gateway.test.ts`, and run again.
2. Pay the order with the MoMo test app and a test wallet. On staging, `select outcome, kind, source from payment_notifications order by received_at desc limit 1` → `processed | paid | webhook`. If it is `invalid_signature`, copy the IPN body from the MoMo test portal and run `npm run sandbox:check -- momo-ipn '<body>'`; compare MoMo's fields with `MOMO_IPN_FIELDS` and fix the order there (and the vector) until it prints `{ ok: true, kind: 'paid' }`.
3. `momo-query <orderId>` → `state: 'paid'`; `momo-refund <orderId> <transId> 1000` → `status: 'done'` or `'pending'`; `momo-query` again lists the refund in `refundTrans` (the refund poller reads it there).
4. Decline one payment in the test app: the request shows `payment_failed` and the notification `processed | failed`.

- [ ] **Step 4: VNPay**

1. `npm run sandbox:check -- vnpay-url` → open the URL: the sandbox shows the payment method page, not "Sai chữ ký" / code 70 or 97.
2. Pay with the NCB test card from VNPay's sandbox documentation. The sandbox merchant admin's IPN log shows our answer `{"RspCode":"00"}`; the notification row is `processed | paid | webhook`.
3. Start another payment and press "Huỷ" on the VNPay page: IPN `vnp_ResponseCode=24` arrives with empty `vnp_BankTranNo`/`vnp_CardType`; the notification is `processed | failed` (confirms the empty-value rule of decision 8). If it is `invalid_signature`, copy the query string from the IPN log and run `vnpay-ipn '<query>'`, then include empty values in `vnpSignData` instead (and update the cancelled-IPN vector).
4. `vnpay-query <txnRef>` → `state: 'paid'`; `vnpay-refund <txnRef> <transactionNo> 5000 10000` (partial, `03`) → `status: 'done'` or `'pending'`; `vnpay-query` later shows the refund status. Record the `vnp_TransactionStatus` values VNPay returns for a refund in progress and done; if they differ from `05`/`06`, change `VnpayGateway.queryRefund` and its test.
5. Ask VNPay (merchant support) whether `vnp_IpAddr` may be the server's IP (decision 6) and record the answer in the PR.

- [ ] **Step 5: Return links on devices**

With the app of Tasks 14–16 built with `--dart-define=APP_LINK_HOST=<staging host>` (Android `app.linkHost` in `android/local.properties`, iOS `APP_LINK_HOST` in `Secrets.xcconfig`) and the host serving `assetlinks.json` / `apple-app-site-association` (Task 12, `ANDROID_CERT_SHA256` and `APPLE_APP_ID` set):

- Android: `adb shell pm get-app-links com.thanhbk.photobooking` lists the host as `verified`; after a sandbox payment the browser returns straight into the app on S48.
- iOS: after a sandbox payment, Safari's return opens the app (or the return page's "Mở ứng dụng" does); `swcutil dl -d <host>` (macOS) or the device's Associated Domains diagnostics show the domain.

- [ ] **Step 6: Record and commit**

Append to `services/dispatch/README.md`:

````markdown
## Thanh toán thật: kiểm tra trước khi chạy tiền thật (kế hoạch I6 Task 13)

`PAYMENT_ENV=production` chỉ được đặt sau khi bảng dưới đã đủ ở môi trường staging với khoá sandbox (ghi ngày và người kiểm vào PR).

| Kiểm tra | Lệnh / nơi xem | Kết quả |
|---|---|---|
| MoMo tạo đơn | `npm run sandbox:check -- momo-create` | `resultCode 0` |
| MoMo IPN đúng chữ ký | `payment_notifications` | `processed` |
| MoMo hoàn, truy vấn | `momo-refund`, `momo-query` | `done` / `refundTrans` |
| VNPay URL đúng chữ ký | `vnpay-url` | trang chọn phương thức |
| VNPay IPN trả tiền, huỷ (24) | nhật ký IPN của VNPay, `payment_notifications` | `RspCode 00`, `processed` |
| VNPay hoàn 03, querydr | `vnpay-refund`, `vnpay-query` | `done`/`pending`, mã trạng thái hoàn ghi lại |
| `vnp_IpAddr` | VNPay xác nhận | ghi lại |
| App Link / Universal Link | thiết bị thật | mở thẳng S48 |
````

```bash
git add services/dispatch
git commit -m "chore(payments): sandbox cross-check tool and go-live checklist for MoMo and VNPay

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: App: mirror payment fields, `PaymentConfig`, the real `PaymentLauncher`

**Files:**
- Create: `app_flutter/lib/data/instant/payment_config.dart`, `app_flutter/lib/data/instant/gateway_payment_launcher.dart`, `app_flutter/test/data/instant/payment_config_test.dart`, `app_flutter/test/data/instant/instant_payment_fields_test.dart`
- Modify: `app_flutter/lib/data/instant/instant_models.dart`, `app_flutter/lib/data/instant/instant_wire.dart`, `app_flutter/lib/data/instant/instant_providers.dart`

**Interfaces:**
- Consumes: `PaymentLauncher`, `PaymentStart`, `DevFakePaymentLauncher`, `UnavailablePaymentLauncher`, `paymentLauncherProvider` (I5 Task 2); `ExternalLauncher`, `FakeExternalLauncher`, `externalLauncherProvider` (plan 2b); `PaymentProvider`, `CreatedRequest`, `InstantRequestView`, `requestViewFromMap`, `dispatchApiClientProvider` (I4); `MockApi` (phase 2).
- Produces:
  - `InstantRequestView.paymentProvider` (`PaymentProvider?`), `.paymentExpiresAt` (`DateTime?`), read by `requestViewFromMap`.
  - `class PaymentConfig { const PaymentConfig(List<PaymentProvider>); factory PaymentConfig.parse(String, {bool release}); factory PaymentConfig.fromEnvironment(); providers; usesFake; gateways; static allowedHosts }` (`--dart-define=PAYMENT_PROVIDERS=momo,vnpay`).
  - `PaymentChoice` / `paymentChoiceProvider` (`NotifierProvider<PaymentChoice, PaymentProvider?>`, session state).
  - `GatewayPaymentLauncher({required ExternalLauncher launcher, required List<PaymentProvider> enabled, required PaymentProvider? Function() selected})`: `provider` = choice or first gateway; `available` = any gateway; `open` → `openedExternally` for an https URL on a known MoMo/VNPay host, else `failed`.
  - `paymentConfigProvider`; `paymentLauncherProvider` body replaced (I5 said "Plan I6 replaces only this provider's body"): no dispatch or no provider → `UnavailablePaymentLauncher`; fake → `DevFakePaymentLauncher`; else `GatewayPaymentLauncher`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/instant/payment_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/instant/gateway_payment_launcher.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/payment_config.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';

CreatedRequest _req(String url) => CreatedRequest(requestId: 'RQ1', amountVnd: 690000, paymentUrl: Uri.parse(url));

void main() {
  group('PaymentConfig', () {
    test('debug without the define uses the fake gateway; release never does', () {
      expect(PaymentConfig.parse('', release: false).providers, [PaymentProvider.fake]);
      expect(PaymentConfig.parse('', release: true).providers, isEmpty);
      expect(PaymentConfig.parse('fake,momo', release: true).providers, [PaymentProvider.momo]);
    });

    test('keeps the listed order, drops duplicates and unknown codes', () {
      final c = PaymentConfig.parse(' vnpay , momo,momo,x', release: true);
      expect(c.providers, [PaymentProvider.vnpay, PaymentProvider.momo]);
      expect(c.gateways, [PaymentProvider.vnpay, PaymentProvider.momo]);
      expect(c.usesFake, isFalse);
    });
  });

  group('GatewayPaymentLauncher', () {
    late FakeExternalLauncher external;
    PaymentProvider? choice;
    GatewayPaymentLauncher make() => GatewayPaymentLauncher(launcher: external, enabled: const [PaymentProvider.momo, PaymentProvider.vnpay], selected: () => choice);
    setUp(() {
      external = FakeExternalLauncher();
      choice = null;
    });

    test('the provider is the customer\'s choice, else the first gateway', () {
      expect(make().provider, PaymentProvider.momo);
      choice = PaymentProvider.vnpay;
      expect(make().provider, PaymentProvider.vnpay);
      choice = PaymentProvider.fake;
      expect(make().provider, PaymentProvider.momo);
    });

    test('opens a MoMo or VNPay https page outside the app', () async {
      expect(await make().open(_req('https://test-payment.momo.vn/v2/gateway/pay?t=abc')), PaymentStart.openedExternally);
      expect(await make().open(_req('https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_Amount=1')), PaymentStart.openedExternally);
      expect(external.opened.map((u) => u.host), ['test-payment.momo.vn', 'sandbox.vnpayment.vn']);
    });

    test('refuses any other URL, http, and a launcher failure', () async {
      expect(await make().open(_req('https://evil.example/pay')), PaymentStart.failed);
      expect(await make().open(_req('http://payment.momo.vn/pay')), PaymentStart.failed);
      expect(await make().open(_req('fake://pay/RQ1')), PaymentStart.failed);
      expect(external.opened, isEmpty);
      external = FakeExternalLauncher(failOpen: true);
      expect(await make().open(_req('https://payment.momo.vn/pay')), PaymentStart.failed);
    });
  });
}
```

```dart
// test/data/instant/instant_payment_fields_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/instant/gateway_payment_launcher.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/instant_wire.dart';
import 'package:photobooking/data/instant/payment_config.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';

import '../http/mock_api.dart';

const _doc = <String, Object?>{
  'status': 'pending_payment',
  'customerId': 'c1',
  'packageCode': 'p60',
  'genre': 'portrait',
  'amountVnd': 690000,
  'expand': false,
  'round': 1,
  'requestedAt': '2026-10-01T08:00:00.000Z',
  'updatedAt': '2026-10-01T08:00:00.000Z',
};

void main() {
  test('the mirror\'s payment fields are read (plan I6)', () {
    final v = requestViewFromMap({..._doc, 'paymentProvider': 'vnpay', 'paymentExpiresAt': '2026-10-01T08:15:00.000Z'}, id: 'RQ1');
    expect(v.paymentProvider, PaymentProvider.vnpay);
    expect(v.paymentExpiresAt, DateTime.utc(2026, 10, 1, 8, 15));
  });

  test('missing or unknown values are null (older documents, a future provider)', () {
    expect(requestViewFromMap(_doc).paymentProvider, isNull);
    expect(requestViewFromMap({..._doc, 'paymentProvider': 'zalopay'}).paymentProvider, isNull);
    expect(requestViewFromMap(_doc).paymentExpiresAt, isNull);
  });

  test('paymentLauncherProvider: the build\'s gateways, the customer\'s choice', () {
    final c = ProviderContainer(
      overrides: [
        paymentConfigProvider.overrideWithValue(const PaymentConfig([PaymentProvider.momo, PaymentProvider.vnpay])),
        dispatchApiClientProvider.overrideWithValue(MockApi().api()),
        externalLauncherProvider.overrideWithValue(FakeExternalLauncher()),
      ],
    );
    addTearDown(c.dispose);
    final launcher = c.read(paymentLauncherProvider);
    expect(launcher, isA<GatewayPaymentLauncher>());
    expect((launcher.available, launcher.provider), (true, PaymentProvider.momo));
    c.read(paymentChoiceProvider.notifier).choose(PaymentProvider.vnpay);
    expect(launcher.provider, PaymentProvider.vnpay);
  });

  test('no gateway configured, or no dispatch service: unavailable; debug fake: the dev launcher', () {
    ProviderContainer make(PaymentConfig config, {bool api = true}) {
      final c = ProviderContainer(
        overrides: [
          paymentConfigProvider.overrideWithValue(config),
          dispatchApiClientProvider.overrideWithValue(api ? MockApi().api() : null),
          externalLauncherProvider.overrideWithValue(FakeExternalLauncher()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    expect(make(const PaymentConfig([])).read(paymentLauncherProvider), isA<UnavailablePaymentLauncher>());
    expect(make(const PaymentConfig([PaymentProvider.momo]), api: false).read(paymentLauncherProvider), isA<UnavailablePaymentLauncher>());
    expect(make(const PaymentConfig([PaymentProvider.fake])).read(paymentLauncherProvider), isA<DevFakePaymentLauncher>());
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/instant/payment_config_test.dart test/data/instant/instant_payment_fields_test.dart`
Expected: FAIL to compile (`payment_config.dart`, `gateway_payment_launcher.dart` missing; `paymentProvider` is not a field of `InstantRequestView`).

- [ ] **Step 3: Implement**

```dart
// lib/data/instant/payment_config.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/instant/instant_models.dart';

/// Which gateways this build offers: `--dart-define=PAYMENT_PROVIDERS=momo,vnpay`.
/// A debug build without the define uses the dispatch service's fake gateway
/// (`PAYMENTS=fake`, plan I3); a release build never does.
class PaymentConfig {
  const PaymentConfig(this.providers);

  factory PaymentConfig.parse(String raw, {bool release = kReleaseMode}) {
    final out = <PaymentProvider>[];
    for (final code in raw.split(',').map((s) => s.trim())) {
      for (final p in PaymentProvider.values) {
        if (p.code == code && !out.contains(p) && !(release && p == PaymentProvider.fake)) {
          out.add(p);
        }
      }
    }
    if (out.isEmpty && !release && raw.trim().isEmpty) {
      return const PaymentConfig([PaymentProvider.fake]);
    }
    return PaymentConfig(List.unmodifiable(out));
  }

  factory PaymentConfig.fromEnvironment() =>
      PaymentConfig.parse(const String.fromEnvironment('PAYMENT_PROVIDERS'));

  final List<PaymentProvider> providers;

  bool get usesFake => providers.contains(PaymentProvider.fake);

  /// The real gateways, in the order the build lists them (the first is the default choice).
  List<PaymentProvider> get gateways => [
    for (final p in providers)
      if (p != PaymentProvider.fake) p,
  ];

  /// The only hosts a payment URL may point at: a misconfigured or compromised
  /// service cannot send the customer to another page.
  static const allowedHosts = <PaymentProvider, Set<String>>{
    PaymentProvider.momo: {'test-payment.momo.vn', 'payment.momo.vn'},
    PaymentProvider.vnpay: {'sandbox.vnpayment.vn', 'pay.vnpay.vn'},
  };
}
```

```dart
// lib/data/instant/gateway_payment_launcher.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/payment_config.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';

/// The gateway the customer picked on S47 (null = the build's first gateway).
/// Kept for the session, like the draft (S33 and S51 come back to it).
class PaymentChoice extends Notifier<PaymentProvider?> {
  @override
  PaymentProvider? build() => null;

  void choose(PaymentProvider p) => state = p;
}

final paymentChoiceProvider = NotifierProvider<PaymentChoice, PaymentProvider?>(PaymentChoice.new);

/// MoMo / VNPay (plan I6): opens the provider's https payment page outside the
/// app (browser, or the MoMo app when it claims the link). The result is
/// never read from here or from the redirect: the mirror moves to `searching`
/// once the verified IPN arrives, or `payment_failed` (spec §4).
class GatewayPaymentLauncher implements PaymentLauncher {
  GatewayPaymentLauncher({
    required ExternalLauncher launcher,
    required List<PaymentProvider> enabled,
    required PaymentProvider? Function() selected,
  }) : _launcher = launcher,
       _enabled = enabled,
       _selected = selected;

  final ExternalLauncher _launcher;
  final List<PaymentProvider> _enabled;
  final PaymentProvider? Function() _selected;

  List<PaymentProvider> get enabled => _enabled;

  @override
  PaymentProvider get provider {
    final s = _selected();
    return s != null && _enabled.contains(s) ? s : _enabled.first;
  }

  @override
  bool get available => _enabled.isNotEmpty;

  @override
  Future<PaymentStart> open(CreatedRequest request) async {
    final url = request.paymentUrl;
    final known = _enabled.any((p) => PaymentConfig.allowedHosts[p]?.contains(url.host) ?? false);
    if (url.scheme != 'https' || !known) {
      return PaymentStart.failed;
    }
    try {
      return await _launcher.open(url) ? PaymentStart.openedExternally : PaymentStart.failed;
    } on Object {
      return PaymentStart.failed;
    }
  }
}
```

In `lib/data/instant/instant_models.dart`, `InstantRequestView`: below `    this.refundVnd,` (constructor) add

```dart
    this.paymentProvider,
    this.paymentExpiresAt,
```

and below `  final int? refundVnd;` add

```dart
  /// Mirror `paymentProvider` (plan I6): the gateway of this request.
  final PaymentProvider? paymentProvider;

  /// Mirror `paymentExpiresAt`: only while `pending_payment`.
  final DateTime? paymentExpiresAt;
```

In `lib/data/instant/instant_wire.dart`, in `requestViewFromMap` below `  refundVnd: _intOrNull(m, 'refundVnd'),` add

```dart
  paymentProvider: _paymentProviderOrNull(m['paymentProvider']),
  paymentExpiresAt: _instantOrNull(m['paymentExpiresAt']),
```

and append to the file

```dart
PaymentProvider? _paymentProviderOrNull(Object? v) {
  for (final p in PaymentProvider.values) {
    if (p.code == v) {
      return p;
    }
  }
  return null;
}
```

In `lib/data/instant/instant_providers.dart` add the imports

```dart
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/instant/gateway_payment_launcher.dart';
import 'package:photobooking/data/instant/payment_config.dart';
```

add

```dart
final paymentConfigProvider = Provider<PaymentConfig>((ref) => PaymentConfig.fromEnvironment());
```

and replace the whole `paymentLauncherProvider` (and its comment) with

```dart
/// Plan I6: the gateways of this build (`--dart-define=PAYMENT_PROVIDERS=momo,vnpay`).
/// Debug without the define: the dispatch service's fake gateway. Nothing
/// configured, or no dispatch service: unavailable (the entry points stay hidden).
final paymentLauncherProvider = Provider<PaymentLauncher>((ref) {
  final api = ref.watch(dispatchApiClientProvider);
  final config = ref.watch(paymentConfigProvider);
  if (api == null || config.providers.isEmpty) {
    return const UnavailablePaymentLauncher();
  }
  if (config.usesFake) {
    return DevFakePaymentLauncher(api: api);
  }
  return GatewayPaymentLauncher(
    launcher: ref.watch(externalLauncherProvider),
    enabled: config.gateways,
    selected: () => ref.read(paymentChoiceProvider),
  );
});
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/instant && flutter analyze`
Expected: PASS (9 new tests; I5's `payment_launcher_test.dart` and I4's contract test still pass: `paymentProvider` and `paymentExpiresAt` are optional contract properties).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant test/data/instant
git commit -m "feat(instant): real MoMo/VNPay payment launcher, build gateway config and the mirror's payment fields

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: App: payment return links (App Link, Universal Link, URL scheme)

**Files:**
- Create: `app_flutter/lib/data/instant/return_links.dart`, `app_flutter/lib/features/instant/instant_return_links.dart`, `app_flutter/test/data/instant/return_links_test.dart`, `app_flutter/test/features/instant/instant_return_links_test.dart`, `app_flutter/test/platform/instant_payment_links_test.dart`
- Modify: `app_flutter/pubspec.yaml`, `pubspec.lock`, `app_flutter/lib/app/router.dart`, `app_flutter/android/app/src/main/AndroidManifest.xml`, `app_flutter/android/app/build.gradle.kts`, `app_flutter/ios/Runner/Info.plist`, `app_flutter/ios/Runner/Runner.entitlements`, `app_flutter/ios/Flutter/Debug.xcconfig`, `app_flutter/ios/Flutter/Release.xcconfig`, `app_flutter/ios/Flutter/Secrets.xcconfig.example`, `app_flutter/test/app/router_test.dart` (and any test that reads `routerProvider`)

**Interfaces:**
- Consumes: `routerProvider` with `wireInstantNavigation` (I4), route `/instant/:id` (I5), `app_links` 6.
- Produces: `abstract class ReturnLinkSource { Future<Uri?> initial(); Stream<Uri> get links; }`, `AppLinksReturnLinkSource`, `FakeReturnLinkSource({Uri? initialLink})` (`emit`, `listeners`), `AppLinkConfig(host)` (`--dart-define=APP_LINK_HOST`), `appLinkConfigProvider`, `returnLinkSourceProvider`, `String? instantReturnTarget(Uri, {required String appLinkHost})`; `void wireInstantReturnLinks(Ref ref, GoRouter router)` (one subscription, `router.go('/instant/<id>')`, query ignored); platform: Android verified App Link `https://${appLinkHost}/instant/…` (`android/local.properties` `app.linkHost`, default `links.photobooking.invalid`) and `photobooking://instant/<id>`, iOS `applinks:$(APP_LINK_HOST)` and URL scheme `photobooking`; Flutter's built-in deep linking off on both (the link is routed once, by this code).

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/instant/return_links_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/return_links.dart';

const _id = '01M3V7ME00REQ0000000000001';

void main() {
  const host = 'links.example.test';
  String? t(String s, {String h = host}) => instantReturnTarget(Uri.parse(s), appLinkHost: h);

  test('the custom scheme and the verified https link both open /instant/<id>', () {
    expect(t('photobooking://instant/$_id'), '/instant/$_id');
    expect(t('https://$host/instant/$_id'), '/instant/$_id');
  });

  test('the provider result in the query is ignored, never trusted', () {
    expect(t('https://$host/instant/$_id?vnp_ResponseCode=00&vnp_TransactionStatus=00'), '/instant/$_id');
    expect(t('photobooking://instant/$_id?resultCode=0'), '/instant/$_id');
  });

  test('anything else is not a return link', () {
    expect(t('https://evil.example/instant/$_id'), isNull);
    expect(t('https://$host/instant/$_id', h: ''), isNull);
    expect(t('photobooking://instant/RQ1'), isNull);
    expect(t('photobooking://instant/$_id/cancel'), isNull);
    expect(t('photobooking://work/$_id'), isNull);
    expect(t('http://$host/instant/$_id'), isNull);
  });
}
```

```dart
// test/features/instant/instant_return_links_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/instant/return_links.dart';
import 'package:photobooking/features/instant/instant_return_links.dart';

const _id = '01M3V7ME00REQ0000000000001';

final _routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(path: '/instant/:id', builder: (_, s) => Text('request ${s.pathParameters['id']}')),
    ],
  );
  wireInstantReturnLinks(ref, router);
  return router;
});

class _App extends ConsumerWidget {
  const _App();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(routerConfig: ref.watch(_routerProvider));
}

void main() {
  late FakeReturnLinkSource links;
  setUp(() => links = FakeReturnLinkSource());

  Widget app() => ProviderScope(
    overrides: [
      returnLinkSourceProvider.overrideWithValue(links),
      appLinkConfigProvider.overrideWithValue(const AppLinkConfig('links.example.test')),
    ],
    child: const _App(),
  );

  testWidgets('a return link while the app runs opens the request screen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    links.emit(Uri.parse('https://links.example.test/instant/$_id?vnp_ResponseCode=00'));
    await tester.pumpAndSettle();
    expect(find.text('request $_id'), findsOneWidget);
    expect(links.listeners, 1);
  });

  testWidgets('the link that launched the app is followed', (tester) async {
    links.initialLink = Uri.parse('photobooking://instant/$_id');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('request $_id'), findsOneWidget);
  });

  testWidgets('foreign links do nothing; the subscription ends with the app', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    links.emit(Uri.parse('https://evil.example/instant/$_id'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(links.listeners, 0);
  });
}
```

```dart
// test/platform/instant_payment_links_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final entitlements = File('ios/Runner/Runner.entitlements').readAsStringSync();

  test('Android: verified https App Link on /instant/ and the photobooking://instant scheme; Flutter deep linking off', () {
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains(r'android:host="${appLinkHost}"'));
    expect(manifest, contains('android:pathPrefix="/instant/"'));
    expect(manifest, contains('android:scheme="photobooking"'));
    expect(manifest, contains('android:host="instant"'));
    expect(RegExp(r'flutter_deeplinking_enabled"\s+android:value="false"').hasMatch(manifest), isTrue);
    expect(gradle, contains('manifestPlaceholders["appLinkHost"]'));
  });

  test('iOS: Universal Link domain, URL scheme, Flutter deep linking off', () {
    expect(entitlements, contains('<key>com.apple.developer.associated-domains</key>'));
    expect(entitlements, contains(r'<string>applinks:$(APP_LINK_HOST)</string>'));
    final urlTypes = RegExp(r'<key>CFBundleURLTypes</key>\s*<array>([\s\S]*?)</array>\s*<key>').firstMatch(plist)?.group(1);
    expect(urlTypes, contains('<string>photobooking</string>'));
    expect(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>').hasMatch(plist), isTrue);
    for (final f in ['ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig']) {
      expect(File(f).readAsStringSync(), contains('APP_LINK_HOST = '), reason: f);
    }
  });

  test('no payment gateway app is queried (the https page hands over to the MoMo app itself)', () {
    expect(plist.contains('<string>momo</string>'), isFalse);
    expect(manifest.contains('android:scheme="momo"'), isFalse);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/instant/return_links_test.dart test/features/instant/instant_return_links_test.dart test/platform/instant_payment_links_test.dart`
Expected: FAIL to compile (`return_links.dart`, `instant_return_links.dart` missing); the platform test fails on `android:autoVerify="true"`.

- [ ] **Step 3: Implement**

```bash
flutter pub add app_links:^6.4.0
```

```dart
// lib/data/instant/return_links.dart
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Links that open the app: the payment return (`https://<APP_LINK_HOST>/instant/<id>`
/// App Link / Universal Link, or `photobooking://instant/<id>`).
abstract class ReturnLinkSource {
  /// The link that launched the app, if any.
  Future<Uri?> initial();

  /// Links received while the app runs.
  Stream<Uri> get links;
}

class AppLinksReturnLinkSource implements ReturnLinkSource {
  AppLinksReturnLinkSource([AppLinks? links]) : _links = links ?? AppLinks();
  final AppLinks _links;

  @override
  Future<Uri?> initial() => _links.getInitialLink();

  @override
  Stream<Uri> get links => _links.uriLinkStream;
}

class FakeReturnLinkSource implements ReturnLinkSource {
  FakeReturnLinkSource({this.initialLink});

  Uri? initialLink;
  final _controller = StreamController<Uri>.broadcast();
  int _listeners = 0;

  /// Open subscriptions (tests prove the app keeps exactly one).
  int get listeners => _listeners;

  void emit(Uri uri) => _controller.add(uri);

  @override
  Future<Uri?> initial() async => initialLink;

  @override
  Stream<Uri> get links => Stream<Uri>.multi((c) {
    _listeners++;
    final sub = _controller.stream.listen(c.add);
    c.onCancel = () {
      _listeners--;
      return sub.cancel();
    };
  });
}

/// `--dart-define=APP_LINK_HOST=…`: the host of the verified App Link; empty = only the custom scheme.
class AppLinkConfig {
  const AppLinkConfig(this.host);
  factory AppLinkConfig.fromEnvironment() => const AppLinkConfig(String.fromEnvironment('APP_LINK_HOST'));
  final String host;
}

final appLinkConfigProvider = Provider<AppLinkConfig>((ref) => AppLinkConfig.fromEnvironment());
final returnLinkSourceProvider = Provider<ReturnLinkSource>((ref) => AppLinksReturnLinkSource());

final _requestId = RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$');

/// `/instant/<id>` for a payment return link, null for anything else. The
/// query (vnp_ResponseCode, resultCode …) is ignored on purpose: whether the
/// money arrived is read from the mirror only (spec §4).
String? instantReturnTarget(Uri uri, {required String appLinkHost}) {
  final String? id;
  if (uri.scheme == 'photobooking' && uri.host == 'instant' && uri.pathSegments.length == 1) {
    id = uri.pathSegments.single;
  } else if (uri.scheme == 'https' &&
      appLinkHost.isNotEmpty &&
      uri.host == appLinkHost &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'instant') {
    id = uri.pathSegments[1];
  } else {
    id = null;
  }
  return id != null && _requestId.hasMatch(id) ? '/instant/$id' : null;
}
```

```dart
// lib/features/instant/instant_return_links.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/instant/return_links.dart';

/// After paying, MoMo / VNPay send the customer to `returnUrlFor(requestId)`;
/// the OS hands that link to the app and this opens `/instant/<id>`, which shows
/// whatever the mirror says (still "Đang chờ xác nhận thanh toán" until the IPN).
/// One subscription for the app's lifetime. Called by `routerProvider`.
void wireInstantReturnLinks(Ref ref, GoRouter router) {
  final host = ref.read(appLinkConfigProvider).host;
  void open(Uri uri) {
    final target = instantReturnTarget(uri, appLinkHost: host);
    if (target == null) {
      return;
    }
    if (router.routerDelegate.currentConfiguration.uri.path != target) {
      router.go(target);
    }
  }

  final source = ref.read(returnLinkSourceProvider);
  final StreamSubscription<Uri> sub = source.links.listen(open, onError: (Object _) {});
  ref.onDispose(sub.cancel);
  () async {
    try {
      final first = await source.initial();
      if (first != null) {
        open(first);
      }
    } on Object {
      // No link plugin (tests, desktop): nothing launched the app.
    }
  }();
}
```

`lib/app/router.dart`: add `import 'package:photobooking/features/instant/instant_return_links.dart';` and below `  wireInstantNavigation(ref, router);` add `  wireInstantReturnLinks(ref, router);`. In `test/app/router_test.dart` (and every other test that builds `routerProvider`, e.g. `test/app/discovery_routes_test.dart`) add `returnLinkSourceProvider.overrideWithValue(FakeReturnLinkSource())` next to I4's notifier overrides (the real plugin's event channel does not exist in tests).

Platform files:

1. `android/app/src/main/AndroidManifest.xml`, inside the `.MainActivity` `<activity>`, directly after its `LAUNCHER` `<intent-filter>`:

```xml
            <!-- Plan I6: payment return. Flutter's own deep linking is off: wireInstantReturnLinks routes the link once. -->
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="${appLinkHost}" android:pathPrefix="/instant/" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="photobooking" android:host="instant" />
            </intent-filter>
```

2. `android/app/build.gradle.kts`: directly above `android {` add

```kotlin
// Plan I6: host of the payment return App Link (android/local.properties `app.linkHost=…`, gitignored).
val appLinkHost: String = java.util.Properties().run {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
    getProperty("app.linkHost") ?: "links.photobooking.invalid"
}
```

and inside `defaultConfig { … }` add `manifestPlaceholders["appLinkHost"] = appLinkHost`.

3. `ios/Runner/Info.plist`: add this `<dict>` as the last element of the `CFBundleURLTypes` array (create the key with this one dict if the iOS enablement plan has not run):

```xml
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>com.thanhbk.photobooking.instant</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>photobooking</string>
			</array>
		</dict>
```

and, before the closing `</dict>` of the plist,

```xml
	<key>FlutterDeepLinkingEnabled</key>
	<false/>
```

4. `ios/Runner/Runner.entitlements` (plan I4): before the closing `</dict>` add

```xml
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:$(APP_LINK_HOST)</string>
	</array>
```

5. `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig`: directly above `#include? "Secrets.xcconfig"` add `APP_LINK_HOST = links.photobooking.invalid` (a later definition in `Secrets.xcconfig` wins). `ios/Flutter/Secrets.xcconfig.example`: add

```
// Host of the payment return Universal Link (plan I6); must serve /.well-known/apple-app-site-association.
APP_LINK_HOST = links.photobooking.invalid
```

**[người dùng]** Apple Developer → Identifiers → `com.thanhbk.photobooking` → enable Associated Domains (the provisioning profile must include it); Play Console → App integrity → copy the App signing SHA-256 into `ANDROID_CERT_SHA256` of the service.

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/instant test/features/instant/instant_return_links_test.dart test/platform test/app && flutter analyze && plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements`
Expected: PASS (3 + 3 + 3 new tests; `ios_config_test.dart` still passes: the URL types keep the Google and Facebook schemes); `plutil` prints `OK` twice.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add pubspec.yaml pubspec.lock lib test android/app/src/main/AndroidManifest.xml android/app/build.gradle.kts ios/Runner/Info.plist ios/Runner/Runner.entitlements ios/Flutter
git commit -m "feat(instant): payment return through a verified App Link, a Universal Link or photobooking://instant

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: App: S47 gateway choice, S48 payment wait, mirror closed behind the payment app

**Files:**
- Create: `app_flutter/lib/features/instant/payment_method_picker.dart`, `app_flutter/lib/features/instant/instant_foreground.dart`, `app_flutter/test/support/instant_payment_support.dart`, `app_flutter/test/features/instant/instant_payment_wait_test.dart`
- Modify: `app_flutter/lib/features/instant/views/instant_searching_view.dart`, `app_flutter/lib/features/instant/instant_request_screen.dart`, `app_flutter/lib/features/instant/instant_draft.dart`, `app_flutter/lib/features/instant/instant_book_controller.dart`, `app_flutter/lib/features/instant/instant_book_screen.dart`, `app_flutter/lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: Task 14 (`paymentConfigProvider`, `paymentChoiceProvider`, `paymentLauncherProvider`), I5 (`InstantDraft`, `InstantRequestScreen`, `InstantCustomerActions`, views), I4 (`instantRequestProvider`, `TickingBuilder`, `ApertureLoader`, `AppButton.danger`), 3a1 (`AppChip`, `showAppSheet`), 3a2 (`formatMoney`).
- Produces:
  - `String paymentProviderLabel(PaymentProvider, AppLocalizations)`, `const PaymentMethodPicker()` (keys `instant-provider`, `instant-provider-<code>`, `instant-provider-single`) on S47 above the escrow line.
  - `appForegroundProvider` (`NotifierProvider<AppForeground, bool>`: visible = resumed or inactive), `ForegroundInstantRequest` / `foregroundInstantRequestProvider` (`NotifierProvider.autoDispose.family<…, AsyncValue<InstantRequestView?>, String>`, `retry()`).
  - `InstantPaymentPendingView({required InstantRequestView view})` (keys `payment-pending-body`, `payment-deadline`, `payment-reopen`, `payment-cancel`, `payment-cancel-confirm`, `payment-cancel-keep`); `InstantPaymentFailedView` with the late-refund text.
  - `InstantDraft.lastPaymentUrl`, `InstantDraftController.setLastPaymentUrl(Uri)`.
  - Test support `withPayment(view, {provider, expiresAt, refundVnd})`, `goBackground(tester)`, `goForeground(tester)`.
  - l10n keys below.

Layout (mock S48 "Đang chờ xác nhận thanh toán", as on S08): the aperture wait; "Đang chờ xác nhận thanh toán"; "Cổng MoMo chưa báo về. Thường mất dưới một phút. Nếu bạn đã trả, đừng trả lại: kết quả tự hiện ở đây."; "Hạn thanh toán 15:15" (a fixed clock time, no countdown); outline "Mở lại trang thanh toán" (only when this session opened it; same order, cannot be paid twice); red text "Huỷ yêu cầu" → sheet "Huỷ yêu cầu này?" / "Chưa có khoản nào bị trừ. Nếu bạn đã trả xong, tiền sẽ được hoàn đủ tự động." / red "Huỷ yêu cầu" / outline "Tiếp tục chờ". No primary button (one-primary rule: S48 has none).

- [ ] **Step 1: Write the failing tests**

```dart
// test/support/instant_payment_support.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// [v] with the payment fields of the mirror (plan I6) set.
InstantRequestView withPayment(InstantRequestView v, {PaymentProvider? provider, DateTime? expiresAt, int? refundVnd}) => InstantRequestView(
  id: v.id,
  status: v.status,
  customerId: v.customerId,
  packageCode: v.packageCode,
  genre: v.genre,
  amountVnd: v.amountVnd,
  expand: v.expand,
  round: v.round,
  requestedAt: v.requestedAt,
  updatedAt: v.updatedAt,
  photographerId: v.photographerId,
  photographer: v.photographer,
  radiusKm: v.radiusKm,
  searchEndsAt: v.searchEndsAt,
  etaMinutes: v.etaMinutes,
  etaEstimated: v.etaEstimated,
  graceEndsAt: v.graceEndsAt,
  meetPoint: v.meetPoint,
  assignedAt: v.assignedAt,
  arrivedAt: v.arrivedAt,
  startedAt: v.startedAt,
  finishedAt: v.finishedAt,
  refundVnd: refundVnd ?? v.refundVnd,
  paymentProvider: provider ?? v.paymentProvider,
  paymentExpiresAt: expiresAt ?? v.paymentExpiresAt,
);

/// The OS sending the app behind the payment app, state by state.
Future<void> goBackground(WidgetTester tester) async {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

/// … and bringing it back.
Future<void> goForeground(WidgetTester tester) async {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}
```

```dart
// test/features/instant/instant_payment_wait_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/gateway_payment_launcher.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/payment_config.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/instant_request_screen.dart';
import 'package:photobooking/features/instant/payment_method_picker.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/instant_customer_screens.dart';
import '../../support/instant_customer_world.dart';
import '../../support/instant_payment_support.dart';

final _expires = DateTime.utc(2026, 10, 1, 8, 15);

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> open(WidgetTester tester, {double width = 390, double scale = 1, Brightness b = Brightness.dark}) async {
    tester.view.physicalSize = Size(width * 3, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant/RQ1', brightness: b, textScale: scale));
    await tester.pump();
    await tester.pump();
  }

  void pending({PaymentProvider provider = PaymentProvider.momo}) =>
      w.mirror.setRequest('RQ1', withPayment(w.request(InstantStatus.pendingPayment), provider: provider, expiresAt: _expires));

  testWidgets('S48 · payment: the gateway, a fixed deadline, no ticking clock', (tester) async {
    pending();
    await open(tester);
    expect(find.text('Đang chờ xác nhận thanh toán'), findsWidgets);
    expect(find.textContaining('MoMo chưa báo về'), findsOneWidget);
    expect(find.byKey(const Key('payment-deadline')), findsOneWidget);
    expect(TickingBuilder.debugActiveCount, 0);
    expect(find.byKey(const Key('payment-reopen')), findsNothing); // no URL for this request in the draft
  });

  testWidgets('"Mở lại trang thanh toán" reopens the same payment page', (tester) async {
    pending();
    await open(tester);
    ProviderScope.containerOf(tester.element(find.byType(InstantRequestScreen))).read(instantDraftProvider.notifier)
      ..setLastRequest('RQ1')
      ..setLastPaymentUrl(Uri.parse('https://test-payment.momo.vn/v2/gateway/pay?t=abc'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('payment-reopen')));
    await tester.pump();
    expect(w.payment.opened.single.paymentUrl.toString(), 'https://test-payment.momo.vn/v2/gateway/pay?t=abc');
  });

  testWidgets('"Huỷ yêu cầu": says nothing was taken (or will be refunded), cancels, back to S47', (tester) async {
    pending();
    await open(tester);
    await tester.tap(find.byKey(const Key('payment-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có khoản nào bị trừ. Nếu bạn đã trả xong, tiền sẽ được hoàn đủ tự động.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('payment-cancel-confirm')));
    await tester.pumpAndSettle();
    expect(w.booking.cancelCalls, ['cancel RQ1']);
    expect(find.text('Chụp ngay'), findsWidgets);
  });

  testWidgets('payment_failed with a late payment refunded says so', (tester) async {
    w.mirror.setRequest('RQ1', withPayment(w.request(InstantStatus.paymentFailed), refundVnd: 690000));
    await open(tester);
    expect(find.textContaining('đã được hoàn 690.000₫'), findsOneWidget);
  });

  testWidgets('VNPay is named; 320dp at 1.3× text, light and dark: no overflow', (tester) async {
    pending(provider: PaymentProvider.vnpay);
    for (final b in Brightness.values) {
      await open(tester, width: 320, scale: 1.3, b: b);
      expect(find.textContaining('VNPay chưa báo về'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  group('PaymentMethodPicker (S47)', () {
    Future<ProviderContainer> host(WidgetTester tester, PaymentConfig config) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [paymentConfigProvider.overrideWithValue(config)],
          child: MaterialApp(
            theme: buildDarkTheme(),
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: PaymentMethodPicker()),
          ),
        ),
      );
      return ProviderScope.containerOf(tester.element(find.byType(PaymentMethodPicker)));
    }

    testWidgets('two gateways: chips, MoMo first, the choice is kept', (tester) async {
      final c = await host(tester, const PaymentConfig([PaymentProvider.momo, PaymentProvider.vnpay]));
      expect(find.text('MoMo'), findsOneWidget);
      expect(find.text('VNPay'), findsOneWidget);
      await tester.tap(find.byKey(const Key('instant-provider-vnpay')));
      await tester.pump();
      expect(c.read(paymentChoiceProvider), PaymentProvider.vnpay);
    });

    testWidgets('one gateway is a line of text; the fake gateway shows nothing', (tester) async {
      await host(tester, const PaymentConfig([PaymentProvider.vnpay]));
      expect(find.text('Thanh toán qua VNPay'), findsOneWidget);
      await host(tester, const PaymentConfig([PaymentProvider.fake]));
      expect(find.byKey(const Key('instant-provider')), findsNothing);
      expect(find.byKey(const Key('instant-provider-single')), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/instant/instant_payment_wait_test.dart`
Expected: FAIL to compile (`payment_method_picker.dart`, `setLastPaymentUrl`, `instantPaymentPendingBody` missing).

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`:

```json
  "paymentProviderMomo": "MoMo",
  "paymentProviderVnpay": "VNPay",
  "instantPaymentGateway": "thanh toán",
  "instantPayWith": "Thanh toán qua",
  "instantPayVia": "Thanh toán qua {provider}",
  "@instantPayVia": { "placeholders": { "provider": { "type": "String" } } },
  "instantPaymentPendingBody": "Cổng {provider} chưa báo về. Thường mất dưới một phút. Nếu bạn đã trả, đừng trả lại: kết quả tự hiện ở đây.",
  "@instantPaymentPendingBody": { "placeholders": { "provider": { "type": "String" } } },
  "instantPaymentDeadline": "Hạn thanh toán {time}",
  "@instantPaymentDeadline": { "placeholders": { "time": { "type": "String" } } },
  "instantPaymentReopen": "Mở lại trang thanh toán",
  "instantPaymentCancel": "Huỷ yêu cầu",
  "instantPaymentCancelTitle": "Huỷ yêu cầu này?",
  "instantPaymentCancelBody": "Chưa có khoản nào bị trừ. Nếu bạn đã trả xong, tiền sẽ được hoàn đủ tự động.",
  "instantPaymentCancelConfirm": "Huỷ yêu cầu",
  "instantPaymentCancelKeep": "Tiếp tục chờ",
  "instantPaymentOpenFailed": "Không mở được trang thanh toán. Thử lại nhé.",
  "instantPaymentLateRefunded": "Tiền đến sau khi yêu cầu đã đóng nên đã được hoàn {amount}. Lựa chọn của bạn vẫn còn, thử lại nhé.",
  "@instantPaymentLateRefunded": { "placeholders": { "amount": { "type": "String" } } },
```

Then `flutter gen-l10n`.

```dart
// lib/features/instant/payment_method_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/gateway_payment_launcher.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/l10n/app_localizations.dart';

String paymentProviderLabel(PaymentProvider p, AppLocalizations l) => switch (p) {
  PaymentProvider.momo => l.paymentProviderMomo,
  PaymentProvider.vnpay => l.paymentProviderVnpay,
  PaymentProvider.fake => l.instantPaymentGateway,
};

/// S47: "Thanh toán qua [MoMo] [VNPay]" (mock S47, as on S07). One gateway →
/// a line of text; the debug fake gateway → nothing.
class PaymentMethodPicker extends ConsumerWidget {
  const PaymentMethodPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final config = ref.watch(paymentConfigProvider);
    final gateways = config.gateways;
    if (config.usesFake || gateways.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    if (gateways.length == 1) {
      return Text(l.instantPayVia(paymentProviderLabel(gateways.single, l)), key: const Key('instant-provider-single'), style: theme.textTheme.bodySmall);
    }
    final chosen = ref.watch(paymentChoiceProvider) ?? gateways.first;
    return Row(
      key: const Key('instant-provider'),
      children: [
        Text(l.instantPayWith, style: theme.textTheme.bodySmall),
        const SizedBox(width: AppSpace.s2),
        for (final p in gateways) ...[
          AppChip(
            key: Key('instant-provider-${p.code}'),
            label: paymentProviderLabel(p, l),
            selected: p == chosen,
            onChanged: (_) => ref.read(paymentChoiceProvider.notifier).choose(p),
          ),
          const SizedBox(width: AppSpace.s2),
        ],
      ],
    );
  }
}
```

```dart
// lib/features/instant/instant_foreground.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';

bool _visible(AppLifecycleState? s) =>
    s == null || s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;

/// True while the app is on screen. `inactive` counts as visible (a system
/// sheet over the app); `hidden` / `paused` (the MoMo app or the browser in
/// front) do not.
class AppForeground extends Notifier<bool> {
  @override
  bool build() {
    final listener = AppLifecycleListener(onStateChange: (s) => state = _visible(s));
    ref.onDispose(listener.dispose);
    return _visible(WidgetsBinding.instance.lifecycleState);
  }
}

final appForegroundProvider = NotifierProvider<AppForeground, bool>(AppForeground.new);

/// `instantRequestProvider` for `/instant/:id`, closed while the app is in the
/// background (the customer is paying in another app) and reopened on resume:
/// Firestore then delivers the current document at once, so nothing is missed
/// and no listener stays open behind the payment app. The last value is kept
/// on screen while the new listener starts.
class ForegroundInstantRequest extends Notifier<AsyncValue<InstantRequestView?>> {
  ForegroundInstantRequest(this.requestId);
  final String requestId;
  ProviderSubscription<AsyncValue<InstantRequestView?>>? _sub;

  @override
  AsyncValue<InstantRequestView?> build() {
    ref.onDispose(_close);
    ref.listen<bool>(appForegroundProvider, (_, visible) => visible ? _open() : _close());
    if (!ref.read(appForegroundProvider)) {
      return const AsyncLoading();
    }
    _open();
    return _sub!.read();
  }

  void _open() {
    _sub ??= ref.listen<AsyncValue<InstantRequestView?>>(instantRequestProvider(requestId), (_, next) {
      if (next.isLoading && state.hasValue) {
        return;
      }
      state = next;
    });
  }

  void _close() {
    _sub?.close();
    _sub = null;
  }

  /// "Thử lại" after a mirror error.
  void retry() {
    _close();
    ref.invalidate(instantRequestProvider(requestId));
    _open();
    state = _sub!.read();
  }
}

final foregroundInstantRequestProvider = NotifierProvider.autoDispose
    .family<ForegroundInstantRequest, AsyncValue<InstantRequestView?>, String>(ForegroundInstantRequest.new);
```

In `lib/features/instant/views/instant_searching_view.dart`, replace the classes `InstantPaymentPendingView` and `InstantPaymentFailedView` (I5 Task 7) with the code below, and make sure the file imports `package:flutter_riverpod/flutter_riverpod.dart`, `package:go_router/go_router.dart`, `package:photobooking/core/core.dart`, `package:photobooking/data/instant/instant_models.dart`, `package:photobooking/data/instant/instant_providers.dart`, `package:photobooking/data/instant/payment_launcher.dart`, `package:photobooking/features/instant/instant_customer_actions.dart`, `package:photobooking/features/instant/instant_draft.dart` and `package:photobooking/features/instant/payment_method_picker.dart`:

```dart
/// Waiting for the gateway (spec §4, §10; plan I6). No timer and no polling:
/// the deadline is a fixed clock time, the status arrives through the mirror.
/// "Mở lại trang thanh toán" reopens the same payment page (same order, so
/// it can never be paid twice); "Huỷ yêu cầu" closes it, and a payment that
/// still arrives is refunded in full by the service.
class InstantPaymentPendingView extends ConsumerWidget {
  const InstantPaymentPendingView({super.key, required this.view});
  final InstantRequestView view;

  Future<void> _reopen(BuildContext context, WidgetRef ref, Uri url) async {
    final started = await ref
        .read(paymentLauncherProvider)
        .open(CreatedRequest(requestId: view.id, amountVnd: view.amountVnd, paymentUrl: url));
    if (started == PaymentStart.failed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.instantPaymentOpenFailed)));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final yes = await showAppSheet<bool>(
      context,
      builder: (c) {
        final l = c.l10n;
        return Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.instantPaymentCancelTitle, style: Theme.of(c).textTheme.titleMedium),
              const SizedBox(height: AppSpace.s2),
              Text(l.instantPaymentCancelBody, key: const Key('payment-cancel-body')),
              const SizedBox(height: AppSpace.s4),
              AppButton.danger(l.instantPaymentCancelConfirm, key: const Key('payment-cancel-confirm'), onPressed: () => Navigator.of(c).pop(true)),
              const SizedBox(height: AppSpace.s2),
              AppButton.outline(l.instantPaymentCancelKeep, key: const Key('payment-cancel-keep'), onPressed: () => Navigator.of(c).pop(false)),
            ],
          ),
        );
      },
    );
    if (yes != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(instantCustomerActionsProvider).cancel(view.id);
      if (context.mounted) {
        context.go('/instant');
      }
    } on DispatchException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.instantActionError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final draft = ref.watch(instantDraftProvider);
    final url = draft.lastRequestId == view.id ? draft.lastPaymentUrl : null;
    final provider = view.paymentProvider;
    final gateway = provider == null ? l.instantPaymentGateway : paymentProviderLabel(provider, l);
    final expires = view.paymentExpiresAt;
    return ScreenCode(
      ScreenCodes.instantSearching,
      label: 'payment',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ApertureLoader(semanticsLabel: l.instantWaitingPayment),
                  const SizedBox(height: AppSpace.s3),
                  Text(l.instantWaitingPayment, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    l.instantPaymentPendingBody(gateway),
                    key: const Key('payment-pending-body'),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (expires != null) ...[
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      l.instantPaymentDeadline(
                        MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(expires.toLocal()), alwaysUse24HourFormat: true),
                      ),
                      key: const Key('payment-deadline'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (url != null) ...[
                    const SizedBox(height: AppSpace.s4),
                    AppButton.outline(l.instantPaymentReopen, key: const Key('payment-reopen'), onPressed: () => _reopen(context, ref, url)),
                  ],
                  const SizedBox(height: AppSpace.s2),
                  AppButton.text(
                    l.instantPaymentCancel,
                    key: const Key('payment-cancel'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
                    onPressed: () => _cancel(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gateway refused or was cancelled (spec §10): back to S47, choices kept.
/// Money that arrived after the request closed is refunded in full and said so.
class InstantPaymentFailedView extends StatelessWidget {
  const InstantPaymentFailedView({super.key, required this.view});
  final InstantRequestView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final refunded = view.refundVnd ?? 0;
    return ScreenCode(
      ScreenCodes.instantRequest,
      label: 'payment_failed',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: EmptyState(
          key: const Key('payment-failed'),
          title: l.instantPaymentFailedTitle,
          body: refunded > 0 ? l.instantPaymentLateRefunded(formatMoney(refunded)) : l.instantPaymentFailedBody,
          actionLabel: l.instantTryAgain,
          onAction: () => context.go('/instant'),
        ),
      ),
    );
  }
}
```

In `lib/features/instant/instant_request_screen.dart`, add `import 'package:photobooking/features/instant/instant_foreground.dart';`, replace `    final async = ref.watch(instantRequestProvider(widget.requestId));` with

```dart
    // Plan I6: closed while the customer is in the payment app, reopened on resume.
    final async = ref.watch(foregroundInstantRequestProvider(widget.requestId));
```

and replace `onRetry: async.hasError ? () => ref.invalidate(instantRequestProvider(widget.requestId)) : null,` with

```dart
            onRetry: async.hasError ? () => ref.read(foregroundInstantRequestProvider(widget.requestId).notifier).retry() : null,
```

In `lib/features/instant/instant_draft.dart`: add `this.lastPaymentUrl,` below `this.lastQuote,` in the constructor; add `final Uri? lastPaymentUrl;` below `final PackagesQuote? lastQuote;`; in `copyWith` add the parameter `Object? lastPaymentUrl = _keep,` and the argument `lastPaymentUrl: identical(lastPaymentUrl, _keep) ? this.lastPaymentUrl : lastPaymentUrl as Uri?,`; in `InstantDraftController` add

```dart
  void setLastPaymentUrl(Uri url) => state = state.copyWith(lastPaymentUrl: url);
```

In `lib/features/instant/instant_book_controller.dart`, below `      _draft.setLastRequest(created.requestId);` add `      _draft.setLastPaymentUrl(created.paymentUrl);`.

In `lib/features/instant/instant_book_screen.dart`, add `import 'package:photobooking/features/instant/payment_method_picker.dart';` and directly above the `Row(` whose key is `const Key('instant-escrow')` (after the `SizedBox` that follows the note field) insert

```dart
            const PaymentMethodPicker(),
            const SizedBox(height: AppSpace.s2),
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant && flutter analyze`
Expected: PASS (7 new tests; I5's request screen tests still pass: the pending text "Đang chờ xác nhận thanh toán" and "Thanh toán chưa thành công" / "Thử lại" are kept, and with the default debug config the picker draws nothing on S47).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(instant): MoMo/VNPay choice on S47, payment wait on S48 without timers, mirror closed behind the payment app

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: Align the mock, the specs and the guides

**Files:**
- Modify: `docs/design/ui-mock.html`, `docs/superpowers/specs/2026-10-01-instant-booking-design.md`, `docs/superpowers/specs/2026-10-01-remaining-screens.md`, `docs/testing/battery-and-performance.md`

No new screen code: the payment wait is a state of S48 (`ScreenCode` label `payment`, as in plan I5).

- [ ] **Step 1: Mock S47**

In `docs/design/ui-mock.html`, inside `data-code="S47"`, directly above `<div class="esc"><svg><use href="#i-lock"/></svg><span>Tiền được giữ an toàn và hoàn 100% nếu không có người nhận. Thường có người nhận trong khoảng 4 phút.</span></div>` insert

```html
        <div class="chips"><span class="meta x" style="align-self:center">Thanh toán qua</span><span class="chip on">MoMo</span><span class="chip">VNPay</span></div>
```

and in the S47 caption replace `"Mở rộng tìm kiếm" tắt sẵn: bật thì sau vòng ưu tiên mời cả nhiếp ảnh gia khác ở gần.</span>` with `"Mở rộng tìm kiếm" tắt sẵn: bật thì sau vòng ưu tiên mời cả nhiếp ảnh gia khác ở gần. Chọn MoMo hoặc VNPay; trang thanh toán mở ngoài ứng dụng, kết quả chỉ lấy từ xác nhận (IPN) của cổng.</span>`. In the S48 caption, before `Huỷ là chữ đỏ mở S55.` add `Trước khi cổng xác nhận: "Đang chờ xác nhận thanh toán", hạn thanh toán, "Mở lại trang thanh toán", "Huỷ yêu cầu" (chưa trừ tiền; tiền đến muộn được hoàn đủ). `. Open the mock with `#S47` and `#S48` and check both captions and the chip row.

- [ ] **Step 2: `2026-10-01-instant-booking-design.md`**

1. §2.1 step 4: replace `(dùng chung luồng thanh toán của bước 4; trước khi bước 4 xong dùng cổng giả như kế hoạch sự kiện)` with `(kế hoạch I6: trang thanh toán của cổng mở ngoài ứng dụng; cổng đưa khách về `https://<APP_LINK_HOST>/instant/{id}` (App Link / Universal Link) hoặc `photobooking://instant/{id}`; trạng thái chỉ đổi khi IPN đã xác thực, không tin redirect)`.
2. §6 table: below the `PUT /v1/instant-settings` row add `` | `POST /v1/requests/{id}/dispute` | khách | `{reason}`; trong 24 giờ sau `completed`; giữ tiền của nhiếp ảnh gia tới khi admin xử lý (kế hoạch I6) | ``.
3. §10 table: below the `price_changed` row add

```
| Cổng không tạo được thanh toán (lỗi, hết giờ chờ) | Yêu cầu `payment_failed` ngay (không chờ 15 phút); S47 giữ lựa chọn, khách chọn cổng khác |
| Không có IPN | Dịch vụ hỏi cổng sau 5 phút rồi giãn dần (10, 20, 40, 80 phút); quá 2 giờ thì đóng thanh toán |
| Tiền về sau khi yêu cầu đã đóng (hết hạn, huỷ, cổng báo lỗi trước đó) | Ghi nhận rồi hoàn 100% tự động qua cổng gốc |
| Sai số tiền trong IPN | Không đổi trạng thái; ghi `payment_notifications` để admin xử lý |
| Hoàn tiền qua cổng lỗi | Thử lại 8 lần, gửi lại sau 2 giờ; quá 24 giờ chưa xác nhận thì vào hàng đợi hoàn tay |
```

- [ ] **Step 3: `2026-10-01-remaining-screens.md` §3g.2**

Below the row `` | Vé sự kiện (host `platform`) | Sau `completed` | Giữ ở nền tảng (doanh thu), không chi trả | `` add

```
| Chụp ngay (trả đủ, kế hoạch I6) | `completed` (khách xác nhận hoặc tự động 2 giờ sau "Hoàn thành") và hết 24 giờ khiếu nại; phần phí đi lại / không đến (20% / 50%) sau 24 giờ kể từ lúc huỷ | Nhiếp ảnh gia nhận phần `payoutRate`; phí nền tảng giữ lại (`fee_charged`) |
```

- [ ] **Step 4: `docs/testing/battery-and-performance.md`**

Append:

````markdown
## Chụp ngay: thanh toán (kế hoạch I6)

- Trong lúc khách ở ứng dụng MoMo hoặc trình duyệt VNPay: app không có `Timer`, không gọi mạng, không giữ listener Firestore (`foregroundInstantRequestProvider` đóng khi `hidden`/`paused`, mở lại khi quay về). Test tự động: `test/battery/instant_payment_battery_test.dart`.
- Đo tay (Android và iOS): 10 phút gồm 3 lần trả bằng MoMo test (chuyển app) và 1 lần huỷ ở VNPay. Ngưỡng: không wake lock của app; mạng của app chỉ bật lúc mở trang thanh toán và lúc quay lại; S48 đổi sang "Đang tìm" ≤ 2 giây sau khi IPN tới (xem `payment_notifications.received_at`).
- Phía dịch vụ: webhook p95 < 100 ms (trong tiến trình, `webhook_ms`); một lượt đối soát tối đa 24 lời gọi, 4 song song, < 48 giây kể cả khi mọi lời gọi hết hạn 8 giây; lượt rỗng không gọi cổng.
````

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "docs(instant): gateway choice in the mock, live payment edge cases, Chụp ngay release rule, payment battery checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: Performance and battery check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-instant-i6-payments.md"). Nothing to do here.
