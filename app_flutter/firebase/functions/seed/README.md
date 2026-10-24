# Seed data (local emulators only)

`scripts/backend-local.sh` loads this seed on the first start (or with `--fresh` / `--seed`).
Source: `fixtures.ts`. **Test values only**: these accounts and numbers exist only in the
local Auth and Firestore emulators; the seed refuses to run unless `FIRESTORE_EMULATOR_HOST`
and `FIREBASE_AUTH_EMULATOR_HOST` point at a local host.

Password for every account: `seed-password-1`

| Account (email) | uid | Role | Notes |
|---|---|---|---|
| `lan.customer@seed.test` | `seed-customer-lan` | customer | private phone `+84903000001` (Zalo allowed) |
| `minh.nophone@seed.test` | `seed-customer-minh` | customer | no phone: server answers `phone_required` |
| `an.verified@seed.test` | `seed-photographer-an` | photographer | verified, Hà Nội; Gọi + Zalo + WhatsApp; `+84912000001`, Zalo `+84912000002`, WhatsApp `+14155550101` |
| `binh.unverified@seed.test` | `seed-photographer-binh` | photographer | not verified, Đà Nẵng; Gọi only; `+84987000001`; shows the S03.01 "Chưa nhận đơn" variant and cannot be booked (`acceptingOrders: false`) |
| `cuc.studio@seed.test` | `seed-photographer-cuc` | photographer | studio (`providerType: studio`), TP.HCM; private studio address, public district Quận 1; Gọi only; `+84938000001` |
| `dung.artist@seed.test` | `seed-photographer-dung` | photographer | artist (NAG tier, `providerType: artist`, `approvedAwardCount: 3`), Huế; Gọi only; `+84905000001` |
| `giang.pending@seed.test` | `seed-photographer-giang` | photographer | not verified, Cần Thơ; Gọi only; `+84976000001` (also her Auth phone); S21 verification submitted, waiting for staff (see "Verification (S21)") |
| `hoa.ctv@seed.test` | `seed-photographer-hoa` | photographer | verified individual, TP.HCM (cưới, gia đình), in no studio; Gọi only; `+84909000001`; S27 applicant Cúc can accept (see "Studio recruiting (S27)") |
| `admin.staff@seed.test` | `seed-staff-admin` | staff | custom claim `staffRole: 'admin'`: may call `reviewAward` and `resolveDispute`, and is the `--actor` of `npm run awards` |

| Booking | Customer ↔ photographer | Status | `getContactLink` |
|---|---|---|---|
| `seed-booking-accepted` | Lan ↔ An | accepted | unlocked (all three channels) |
| `seed-booking-upcoming` | Lan ↔ An | upcoming | unlocked |
| `seed-booking-shot` | Lan ↔ An | shot | unlocked |
| `seed-booking-delivered` | Lan ↔ An | delivered (round 1, 3 ready samples) | unlocked |
| `seed-booking-revision` | Lan ↔ An | revision_requested (round 1) | unlocked |
| `seed-booking-approved` | Lan ↔ An | approved (checkUntil in 47 h, link unlocked) | unlocked |
| `seed-booking-requested-binh` | Lan ↔ Bình | requested | `call` only; `zalo`/`whatsapp` → `not_found` |
| `seed-booking-cancelled` | Lan ↔ An | cancelled | `contact_locked` |
| `seed-booking-completed-recent` | Lan ↔ An | completed 3 days before seeding | unlocked |
| `seed-booking-completed-old` | Lan ↔ An | completed 40 days before seeding | `contact_locked` |
| `seed-booking-completed-window` | Lan ↔ An | completed 2 hours before seeding, payment still `held` (no milestones, `releaseAfter` = completion + 24 h): sign in as Lan to open S18.01 ("Báo vấn đề · còn 22 giờ") | unlocked |

### Delivery (two-layer)

The seed includes two-layer delivery bookings (`shot`, `delivered`, `revision_requested`, `approved`) with milestone payments (shoot milestone released on delivered/revision/approved; delivery milestone released on approved). For local testing of delivery uploads and sample watermarks, the seed needs the Storage emulator (`FIREBASE_STORAGE_EMULATOR_HOST`).


| Post / album | Owner | Notes |
|---|---|---|
| `seed-post-an-1`, `-2` | An | `work` posts in album `seed-album-an-family` ("Gia đình", position 1; 5 photos) |
| `seed-post-an-3` | An | `work` post in album `seed-album-an-street` ("Đường phố", position 2; 1 photo) |
| `seed-post-an-4`, `-5` | An | `work` posts on the timeline only (no album) |

| Award | Owner | Status |
|---|---|---|
| `seed-award-dung-1`, `-2`, `-3` | Dũng | approved (gold, silver, bronze; make Dũng an artist) |
| `seed-award-binh-1` | Bình | pending (in the review queue: `npm run awards -- list`) |

Booking payments are paid by bank QR (`method: bank_qr`, `transferCode` "PB" + 6 characters
derived from the payment id) and include an encrypted payer account (`VCB`, `•••• 3456`, `KHACH THU NGHIEM`).
The cancelled booking `seed-booking-cancelled` has a refund `seed-refund-seed-booking-cancelled`
with `status: done`, `method: bank_transfer`, destination to the seed payer. The fake payment webhook
(`paymentWebhook?provider=fake`, and `confirmFakePayment`, which signs and runs it in-process) checks its
`x-pb-signature` with `FAKE_PAYMENT_WEBHOOK_SECRET` from `.env.local` (emulator) and `.env.booking-c1922` (dev project):
a self-made test value; the real secret comes with the payment intermediary unit.

## Reviews (tomato/brick)

| Photographer | Card / profile | `stats` | Seeded `reviews/*` |
|---|---|---|---|
| An | 97% from 58 reviews (keeps `top_rated`: "97% cà chua từ 58 đánh giá") | 56 tomato, 2 brick, `signedSum` 54.62, `score` 0.942, `punctualMentions` 3 | `seed-review-an-1` tomato ×10, `-2` brick ×3 (Đến trễ, Giao ảnh chậm), `-3` tomato ×6 (the newest three of the 58; texts of the mock) |
| Cúc | "Mới · 3 đánh giá" (under 5, no %) | 3 tomato, folded with `addVerdict` | `seed-review-cuc-1..3`, all tomato |
| Dũng | 50%, with bricks | 3 tomato, 3 brick, folded with `addVerdict` | `seed-review-dung-1..6`; every brick has its reasons |
| Bình | nothing shown (0 reviews) | none | none |

Reviews sit on synthetic booking ids (no booking docs), customers Lan and Minh, and are seeded already
counted (`countedAt` set), so `onReviewWrite` neither recounts them nor sends a notice.
`seed-booking-completed-recent` stays unreviewed: sign in as Lan to try S05.05.

Run `scripts/backend-local.sh --fresh` once: star reviews in saved emulator data are not converted.

## Earnings and payouts (plan 10b)

| Data | Owner | Notes |
|---|---|---|
| `payoutAccounts/{uid}` + `accounts/seed-account-an-1` | An | VCB, `0123456789` (stored encrypted with the emulator key in `.secret.local`; the owner view shows `•••• 6789`), holder `NGUYEN VAN AN`; `nameStatus: matched`, active from the seed start (`SEED_CREATED_AT`) |
| `users/{uid}/private/identity` | An | identity legalName (An): `Nguyễn Văn An`, `method`/`provider` `fake` (test value; the doc's full shape is #135's) |
| Payout `seed-payout-an-1` | An | `paid`, the first payout to the account (approved by `seed-staff-admin`); 1 500 000 gross, tax 7% 105 000, net 1 395 000; its payment (`seed-payment-seed-booking-completed-old`) is `paid_out`, with `payout_paid` −1 395 000 and `tax_withheld` −105 000 ledger entries |
| `seed-booking-disputed` | Lan ↔ An | completed 10 hours before seeding; payment `disputed` by `seed-dispute-lan-an` (see Disputes) |
| `earnings/{uid}` + `items/*` | An, Bình | the projection, computed with the same pure functions as the triggers (An: held 4 × 1 500 000 among the legacy bookings plus Lan's 250 000 ticket of the past workshop, soon 1 500 000, received 1 500 000; the paid row carries its tax and net) |
| Payout account | Bình | none (the S06.05 add-account card) |

## Chats (S07)

Three 1-1 conversations, built by `directChatDocuments` in `fixtures.ts` (chat fields folded from the messages with the domain's `afterMessage`; `bookingStatus` is read from the seeded booking, not typed in):

| Chat (`chats/{customer}_{photographer}`) | Kind | Messages | What it shows on S07.02 |
|---|---|---|---|
| `seed-customer-lan_seed-photographer-an` | `booking` (`seed-booking-upcoming`, `bookingStatus` = its status) | 3 text, the last from An | "Sắp tới" badge; Lan has 2 unread (matches her grouped inbox row) |
| `seed-customer-lan_seed-photographer-cuc` | `inquiry`, `lastMessageAt` = seed time − 20 days | 2 text (Lan, Cúc) | preview "đã đóng"; Lan's next message reopens it unless Cúc turns inquiries off |
| `seed-customer-minh_seed-photographer-dung` | `inquiry`, open | 1 text from Minh | Dũng has 1 unread (as Dũng: unread 1) |

Each chat has `members/{uid}` docs with `unreadCount` for both sides (0 where nothing is unread).

Each member who received a message also has the grouped inbox row `g_chat_{chatId}` that `onChatMessageCreated` would have left (same last and recent message ids; unread with the member's unread count, read otherwise). The seed writes the messages with the Admin SDK, so that trigger still runs for each one after seeding; with the rows in place every run is a duplicate and writes nothing.

## Notifications and badges

| Data | Owner | Notes |
|---|---|---|
| Inbox rows (`users/{uid}/notifications/*`) | Lan | 6 rows: booking accepted (unread), 24 h reminder (read), refund (read), declined (read, 12 days old), grouped chat with An, 2 messages (unread), chat with Cúc (read, 20 days old) |
| Inbox rows | An | booking request (unread), a sample `review_tomato` notice "Bạn nhận 🍅 ×7 từ buổi chụp CN 27/9" (read), chat with Lan (read) |
| Inbox rows | Cúc, Dũng | chat with Lan (read); chat with Minh (unread) |
| `users/{uid}/private/inbox` | Lan, An, Cúc, Dũng | `unreadCount` 2, 1, 0 and 1, matching the unread rows |
| Earned badges | An | `top_rated`, `shoots_10`, `complete_profile`; progress `punctual` 3/5, `shoots_50` 12/50 |
| Earned badges | Lan | `loyal_customer`; progress `sharer` 0/5, `detailed_reviewer` 3/5 |
| `badges/{id}` | all | the 12-badge catalogue |
| `users/{uid}/private/notification_prefs` | none | no doc, so the defaults apply |

Push goes through the Functions emulator's `LoggingPushSender` (type and channel logged, nothing sent).

Try a call while the emulators run (from `app_flutter/firebase/functions`, with the project id
`scripts/backend-local.sh` printed). The script refuses to run unless the three emulator hosts
point at a local host, so export them first:

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 GCLOUD_PROJECT=<project>
npm run try:contact -- lan.customer@seed.test seed-booking-accepted zalo
# 200 {"result":{"url":"https://zalo.me/84912000002"}}
```

## Staff CLI for awards

`tools/awards.ts` is the staff review of award proofs until the web dashboard (S23.07, #83) exists:
`list` (pending awards, oldest first, with how long each has waited), `show <awardId>` (the award,
its proof links and files) and the decisions `approve`, `needs-info`, `reject`, `revoke`. A decision
calls the same `reviewAward` use case as the callable, so the same rules, notification and tier
recompute (`onAwardWrite`) apply; `--actor` must be a user with the admin claim.
`npm run awards -- --help` lists the commands. `list` shows calendar time waiting, while S25.02
promises a review in 3 business days: count weekends and holidays by eye.

### Local (emulators running via `scripts/backend-local.sh`)

`scripts/awards-local.sh` points the CLI at the local emulators (Firestore, Auth and Storage on
127.0.0.1), unsets `GOOGLE_APPLICATION_CREDENTIALS` and refuses a half-set or non-local emulator
environment. `show` downloads the proof files to `$TMPDIR/awards/<awardId>/` (named
`<index>-<file name>`) and prints the paths; links are printed as they are.

```bash
scripts/awards-local.sh list
scripts/awards-local.sh show seed-award-binh-1
scripts/awards-local.sh approve seed-award-binh-1 --actor seed-staff-admin
scripts/awards-local.sh needs-info <awardId> "Thiếu ảnh giấy chứng nhận" --actor seed-staff-admin
```

Check: sign in as `binh.unverified@seed.test`, open Cài đặt → Giải thưởng: the award reads
"Đã duyệt"; a notification `award_reviewed` is in Bình's inbox; the tier card says "Còn 2 giải đã
duyệt nữa để nhận tích vàng". An award created in the app (with proof photos) shows its files with
`show`; the seeded one has a link only.

### Real project

Run the CLI directly, with `GOOGLE_APPLICATION_CREDENTIALS` (a service account key) and
`STORAGE_BUCKET` (or `FIREBASE_STORAGE_BUCKET`), and no emulator host set:
`npm run awards -- list`. `show` prints signed URLs that expire in 15 minutes, so the credentials
must be able to sign. `--actor` is the uid of a user with the admin claim. The dev project
`booking-c1922` is on Spark, so reviews there are not run; this is for the production project.

## Verification (S21)

Four steps (#203): phone, the verification fee (99 000 ₫ for an individual or artist, 299 000 ₫ for
a studio; paid to the platform, never earnings or payouts), identity, rules; identity opens only
once the fee is paid. The fee is a `payments` doc with `subjectType: 'verification_fee'` and payee
`platform` on the fake gateway: `startVerificationFee {method}` opens the QR (S04.04), the shared
`confirmFakePayment {paymentId, kind?}` pays it (emulator and dev project only), `checkVerificationFee`
is "Kiểm tra". A second fee for an attempt whose fee is already recorded is refunded in full
(`duplicate_verification_fee`). Records approved before #203 keep `steps.fee` null. Identity uses the fake verifier on the emulator (and the dev project): it reads the override
`fake_identities/{uid}` if one exists (fields `legalName`, `dob`, `gender`, `idNumber`, `passed`;
edit it in the Emulator UI), else the legal name is the display name without accents in capitals,
`dob` 1995-01-01 and the id number is derived from the uid. Identity docs store only the dev-vault
hash and ciphertext of that number (`identity_hashes/{hash}` guards duplicates).

| Who / what | State | Try |
|---|---|---|
| Giang (`seed-photographer-giang`) | `verifications/{uid}` `submitted` 26 h before seeding (phone, fee paid by bank QR 30 min before that: `payments/seed-payment-vfee-giang`, 99 000 ₫, `released`, with `payment_received` and `fee_charged` ledger entries; fake identity `NGUYỄN T** G**`, rules done); `verified: false`, `acceptingOrders: false` | `list` shows her with `!` (over 24 h); `approve` → verified, accepting orders, push `verification_approved`; or `reject <uid> fake_avatar` → S21.02 rejected with one free resubmit |
| Bình (`seed-photographer-binh`) | no verification record, no `fake_identities` override | sign in and walk S21.01 → fee (pay with the fake confirmation) → S21.03 → rules → submit; then `approve` with the CLI |
| An, Cúc, Dũng, Hòa | `approved` records from before the fee (match `verified: true`, `steps.fee` null) | Cúc (studio) has a full fake identity: in S21.04 her household tax code is her fake id number `001461723292` (`fakeIdNumberOf('seed-photographer-cuc')`) and is approved at once; any other 10-digit code is a company (needs a photo, goes to staff); codes ending `0000` are inactive |
| Minh (`seed-customer-minh`) | `fake_identities` override `{dob: '2010-05-01'}` | the underage example (`underage`) if Minh switches to a photographer role |
| Staff CLI (`tools/verifications.ts`, actor `seed-staff-admin`) | `scripts/verifications-local.sh list` · `show <uid>` · `approve <uid>` · `reject <uid> <reason> ["note"]` · `revoke <uid> "note"` · `business-approve <uid>` · `business-reject <uid> <reason> ["note"]`, each decision with `--actor seed-staff-admin` | decisions go through the same `reviewVerification` use case and notifications as the callable; reasons: `fake_avatar`, `stolen_portfolio`, `identity_mismatch`, `duplicate_account`, `underage`, `other` (business: `inactive`, `representative_mismatch`, `doc_unreadable`, `other`); `other` and `revoke` need a 5-500 character note |

`scripts/verifications-local.sh` uses the same local environment and guards as
`scripts/awards-local.sh`; `show` downloads a business photo to `$TMPDIR/verifications/<uid>/`. On a
real project run `npm run verifications -- …` with the environment of `npm run awards`. The 24-hour
reminder (`verification_reminder`) runs inside `bookingClock`: `npm run clock -- bookings`.

## Staff CLI for payouts

`npm run payouts -- --help` lists the commands: `due` (payees with released money and open
payouts, `needs_approval` included), `show <payoutId>` (the account is printed masked, `•••• 6789`), and
`create <payeeId>`, `approve <payoutId>`, `execute <payoutId>`, `hold <payoutId> "<reason>"`,
`resume <payoutId>`, `run-daily`, each with `--actor <uid>` of an admin (`seed-staff-admin` locally). Against the emulators set
`FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST`; the key comes from `.secret.local`.
Against a real project set `GOOGLE_APPLICATION_CREDENTIALS` and `PAYOUT_ACCOUNT_KEY`. `execute`
and `run-daily` work only with the fake gateway (emulators or `PAYOUTS_MODE=fake`): no real bank
adapter exists.

Daily payouts on the emulator: `npm run payouts -- run-daily --actor seed-staff-admin` does what the
daily `createPayouts` job (10:00 Vietnam time) does and prints its report; approve a first payout
with `npm run payouts -- approve <id> --actor seed-staff-admin`, then run it again to send it.

```bash
npm run payouts -- due
npm run payouts -- create seed-photographer-an --actor seed-staff-admin   # batches An's released payment (completed-recent)
npm run payouts -- run-daily --actor seed-staff-admin
npm run payouts -- approve <payoutId> --actor seed-staff-admin
```

## Photo events (plan 10c)

| Data | Owner | Notes |
|---|---|---|
| `seed-event-an-free-photowalk` | An | open, free ("Không thu phí"), starts in 8 days, capacity 20, 1 seat taken; group chat `event_seed-event-an-free-photowalk` (An, Lan) |
| `seed-event-an-paid-workshop` | An | open, 250 000 VND per ticket, starts in 15 days, capacity 12. Registering holds the seats for 10 minutes and opens a payment; on the emulator and the dev project the fake gateway pays it ("Thanh toán" in the S11.03 sheet, `confirmFakeTicketPayment`), elsewhere the fake-payment gate refuses until #129 brings the real gateway |
| `seed-registration-lan-free-walk` | Lan | free registration to the walk: `paid`, `contactEligible: false`, ticket `VE-LANA-0000`, no `private/contact` snapshot (the host never gets Lan's phone) |
| Timeline of the walk | Lan, Minh | `seed-post-lan-share` (`event_share`, visible) and `seed-post-minh-share` (pending: Minh holds no ticket, so it shows only in the managers' "Chờ duyệt" tab); `postCount` 1 |
| Group chat of the walk | An, Lan | member docs (names only), a join line for Lan, An's announcement `seed-msg-announcement` pinned |
| `seed-event-an-night-walk` | An | "Chụp phố đêm", open, free, starts **36 hours after seeding** (meeting point Nhà hát Thành phố), `soonNoticeAt` null: the next event clock run sends the S17 `event_soon` reminder; group chat with An and Lan |
| `seed-registration-lan-night-walk` | Lan | free registration to the night walk: `paid`, ticket `VE-LANB-0000` |
| `seed-event-an-past-workshop` | An | "Workshop chân dung ngoài trời", 250 000 VND, started 5 hours and **ended 3 hours before seeding**, `completed`; group chat with An and Lan |
| `seed-registration-lan-past-paid` | Lan | paid ticket `VE-LANC-0000` of the past workshop, `contactEligible: true` with its `private/contact` snapshot; payment `seed-payment-ticket-lan-past` `held` until the end + 24 h: sign in as Lan to report a problem from S11.04 (21 hours left) |

Each event also has its hashtag guard (`event_hashtags/*`), the booked day in An's availability
(unless a seed booking already holds that day), and each registration its `ticket_codes/*` entry.

## Follows and saved items (S19)

| Follow | Follower | Followee | Notes |
|---|---|---|---|
| Lan → An | Lan (`seed-customer-lan`) | An (`seed-photographer-an`) | An's `followerCount`: 2 |
| Minh → An | Minh (`seed-customer-minh`) | An (`seed-photographer-an`) | |
| Lan → Dũng | Lan (`seed-customer-lan`) | Dũng (`seed-photographer-dung`) | Dũng's `followerCount`: 1 |

| Saved item | User | Target | Notes |
|---|---|---|---|
| Saved post | Lan | `seed-post-an-1`, `seed-post-an-2` | in `saves/{userId}_{postId}` |
| Saved photographer | Lan | Cúc (`seed-photographer-cuc`) | in `savedPhotographers/{userId}_{photographerId}` |

## Service add-ons (S04, S08.06)

| Add-on | Owner | Kind · unit · price | Applies to |
|---|---|---|---|
| `seed-addon-makeup` | An | makeup · per_person (max 4) · 800 000 ₫ | all packages |
| `seed-addon-retouch` | An | retouch · per_item (max 10) · 20 000 ₫ | all packages |
| `seed-addon-car` | An | transport · per_booking · 300 000 ₫ | `seed-service-portrait` only |
| `seed-addon-outfit` | Cúc (studio) | outfit · per_item (max 4) · 250 000 ₫ | all packages |

`photographers/{uid}/private/addons` holds `activeCount` (An 3, Cúc 1), the lock of `saveAddon`/`deleteAddon`.
Đặt An · Chân dung 2 giờ để thử khối Thêm dịch vụ (S04.01) và điểm đón (S04.06).

## Studio (S26)

Cúc is a verified studio (`providerType: studio`, `memberCount: 1`, `assignableMembers: 1`) with package `seed-service-studio-family`
(Gia đình tại studio 2 giờ, 2 500 000 ₫). Relation ids are `{studioId}_{memberId}_{createdAtMs}`; every seeded
photographer carries `nameKey` (the S26.02 search key).

| Data | Who | Notes |
|---|---|---|
| `studio_members/seed-photographer-cuc_seed-photographer-an_…` | Cúc ↔ An | `active`, joined 30 days before seeding; `photographers/seed-photographer-an.studioId` is Cúc |
| `studio_members/seed-photographer-cuc_seed-photographer-binh_…` | Cúc → Bình | `invited`, expires 5 days after seeding (sign in as Bình to answer in S26.03) |
| `studio_members/seed-photographer-cuc_seed-photographer-dung_…` | Dũng → Cúc | `requested` (join request; sign in as Cúc to answer in S26.01: approving is refused `membership_conflict` while Dũng is Cúc's active collaborator (S27), declining works) |
| `seed-booking-studio-assigned` | Lan ↔ Cúc | accepted, assigned to An, 3 days ahead (the next day An is free); An's day is `booked`; Cúc's day is `full` (its one member is taken) |
| `seed-booking-studio-unassigned` | Lan ↔ Cúc | accepted, unassigned, starts about 20 h after seeding: its assign deadline has passed, so the first `npm run clock -- bookings` marks it overdue (`assign_overdue`, Lan may cancel with 100% back) |

`studio_day_load/seed-photographer-cuc_{day}` holds both bookings' days (server only). Studio bookings never write
the studio's own day as `booked`/`pending`; Cúc's `availability/{day}` only shows the derived `full`.

## Studio recruiting (S27)

Written with the domain's helpers (`recruitMatchKeys`, `recruitFilterKeys`) and the Functions mapping.

| Document | Who | State |
|---|---|---|
| `recruitPosts/seed-recruit-cuc-ctv` | Cúc | open collaborator post "Tuyển CTV chụp cưới cuối tuần", Q1 + Q3 (TP.HCM), cưới + gia đình, 800 000 ₫/buổi, posted 2 days before seeding, 2 applications |
| `recruitApplications/seed-recruit-cuc-ctv_seed-photographer-hoa` | Hòa → Cúc | `applied` (terms accepted). Hòa is verified and in no studio, so Cúc can accept her in S27.05 as a collaborator (the post's kind decides; the accept path) |
| `recruitApplications/seed-recruit-cuc-ctv_seed-photographer-an` | An → Cúc | `applied` (terms accepted). An is also Cúc's S26 member, so Cúc can only decline it in S27.05 (accepting is `membership_conflict`; the refusal case) |
| `studio_collaborations/seed-photographer-cuc_seed-photographer-dung` | Cúc ↔ Dũng | `active` collaborator since 10 days, default fee 600 000 ₫ (S27.06 on both sides; Cúc can offer a studio booking to Dũng in S26.04) |
| `photographers/{uid}/private/recruit` | Cúc, Dũng, An, Hòa | Cúc `openPostCount` 1 and `activeCollabCount` 1; Dũng `activeCollabCount` 1; An and Hòa `openApplicationCount` 1 |
| `photographers/{uid}.recruitMatchKeys` | every photographer | what `onPhotographerWrite` keeps: An (Hà Nội), Bình (Đà Nẵng), Dũng (Huế), Hòa (every TP.HCM area), Giang (Cần Thơ, no area → none); Cúc (studio) none |

Who sees what: Lan and Minh (customers) see no "Tuyển thợ" tab and no "Đang tuyển" line on Cúc's profile (the rules
refuse them `recruitPosts`); Bình (unverified) sees the post and "Xác minh để ứng tuyển" instead of "Ứng tuyển"; An and Hòa see
the post with "Đã ứng tuyển"; Cúc sees it in "Tin tuyển của studio" (S27.05) with Hòa and An as applicants. Hòa is the
only seeded provider serving TP.HCM, so a new HCM post by Cúc notifies Hòa (up to 3 notices per VN day).

## Discovery stats (S02)

| Photographer | `startingPrice` | `stats.nextFreeDate` | `stats.completedCount` | Notes |
|---|---|---|---|---|
| An | 1 500 000 ₫ | computed from today & booked days | 4 | completed bookings: `recent`, `old`, `disputed`, `completed-window` |
| Bình | 1 200 000 ₫ | computed from today | 0 | unverified, `acceptingOrders: false` |
| Cúc | 2 500 000 ₫ | computed from today and its `full` days | 0 | studio package `seed-service-studio-family` (S26) |
| Dũng | `null` | computed from today | 0 | no services seeded |
| Hòa | `null` | computed from today | 0 | no services seeded |

| Item | Key / Path | Value | Notes |
|---|---|---|---|
| Post likes | `posts/seed-post-an-1` | `likeCount: 2` | Lan, Minh in `likes/{userId}_{postId}` |
| Post saves | `posts/seed-post-an-1` | `saveCount: 1` | Lan in `saves/{userId}_{postId}` |
| Explore catalog | `catalog/explore` | `portrait: 1`, `family: 1` | active services with category count |

To recompute all discovery stats across the emulator database:
```bash
npm run stats -- recompute
```

## Running a clock on the emulators

The emulators never fire scheduled functions. `npm run clock -- events` runs the event clock once
(close, complete, refunds, then the 48-hour `event_soon` reminders) and prints the counts;
`npm run clock -- bookings` runs the booking clock once (sweeps, shoot reminders, the studio sweeps and the
Chụp ngay timers, step `instantSweep`). The tool
refuses unless `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` point at a local host;
push is only logged.

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=<project>
npm run clock -- events
# eventClock: closed=0 completed=0 consentExpired=0 refunded=0 soonEvents=1 soonSent=1
# Lan's inbox now has "Chụp phố đêm bắt đầu ngày mai" (or "sau 2 ngày"); a second run sends nothing.
```

## Disputes (S18, #142)

| Data | Parties | Notes |
|---|---|---|
| `disputes/seed-dispute-lan-an` | Lan ↔ An | `open`, reason `photos_missing`, opened 1 hour after `seed-booking-disputed` completed, built with the domain's dispute rules (window, whole-payment freeze: the payment has no milestones, so `dispute.prevEscrowStatus: held`); the booking carries `disputeId`, the payment `dispute.disputeId` |
| `support_threads/dispute_seed-dispute-lan-an` + `messages/*` | Lan, An, staff | system line, Lan's description, a staff question (`seed-staff-admin`), An's answer: `awaitingStaff: true`, so it is listed by `npm run support -- list` |

To try the other side of S18.01: `seed-booking-completed-window` (booking) and `seed-registration-lan-past-paid` (ticket) are inside their windows with the money held.

### Staff CLI for disputes

`resolveDispute` is callable by `seed-staff-admin` (claim `staffRole: 'admin'`). Until the S23.01
dashboard exists, `tools/disputes.ts` is the staff side: `list [open|resolved]` (oldest first: id,
opened at, subject, amount held, status), `show <id>` (the dispute, its evidence paths and the last 30
thread messages) and `resolve`, which runs the same `resolveDispute` use case as the callable and then
sends the refund through the live gateway, the fake rails until a licensed intermediary is wired
(`dispatchDisputeRefund`). `--actor` must be a user with the
admin claim; the note (5–500 characters) is shown to both parties. Staff answer in the dispute thread
with `npm run support -- reply dispute_<id> "<text>" --actor seed-staff-admin`.

The environment rules are those of `npm run awards`. Locally, `FIRESTORE_EMULATOR_HOST` and
`FIREBASE_AUTH_EMULATOR_HOST` must both point at a local host and `GOOGLE_APPLICATION_CREDENTIALS`
must be unset (a mixed environment is refused); `PAYOUT_ACCOUNT_KEY` defaults to the emulator key of
`.secret.local`. On a real project (no emulator host) set `GOOGLE_APPLICATION_CREDENTIALS`,
`GCLOUD_PROJECT` and `PAYOUT_ACCOUNT_KEY` (required there); the refund goes through the same live
gateway as the callable. `npm run disputes -- --help` lists the commands; `list` shows at most 50 and
says so when there are more.

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=<project>
npm run disputes -- list
npm run disputes -- show seed-dispute-lan-an
npm run disputes -- resolve seed-dispute-lan-an split 40 "Thiếu một phần ảnh so với gói" --actor seed-staff-admin
# seed-dispute-lan-an -> resolved split: refund 600.000₫, release 900.000₫
# refund 01J…: done
npm run disputes -- resolve <id> release "Ảnh đã giao đủ theo gói" --actor seed-staff-admin
npm run disputes -- resolve <id> refund "Thợ không đến buổi chụp" --actor seed-staff-admin
```

Check: Lan and An each get "Khiếu nại đã có kết quả" (`onDisputeWrite`); the dispute thread is closed
with the outcome line; the booking's `depositRefunded` grows by the refund.

## Staff CLI for support

The staff CLI allows administrators and sales staff to view and reply to support threads:

```bash
npm run support -- list
npm run support -- show <threadId>
npm run support -- reply <threadId> "<text>" --actor <uid>
```

`--actor` must have the custom claim `staffRole: 'admin'` or `'sales'`.

## Safety (S20 · Báo cáo & chặn)

- Minh và Bình đã chặn nhau (`blocks/seed-customer-minh_seed-photographer-binh`): Minh không thấy bài của Bình, Bình không mở được hồ sơ của Minh.
- Lan có 1 báo cáo mở đối với bài viết `seed-post-an-5` của An (`reports/seed-customer-lan_post_seed-post-an-5`).

### Staff CLI for reports

```bash
npm run reports -- list [open|dismissed|actioned]
npm run reports -- show <reportId>
npm run reports -- dismiss <reportId> "<note>" --actor <uid>
npm run reports -- takedown <reportId> "<note>" --actor <uid>
```

`--actor` must have the custom claim `staffRole: 'admin'`.

## Account Deletion & Data Export (S22 · #205)

- To test deletion and blockers: call `getAccountDeletionBlockers` or `requestAccountDeletion` with Lan or An. Lan has open bookings (`seed-booking-upcoming`), so `requestAccountDeletion` will refuse with `conflict` (blockers listed).
- To test 30-day restore: call `requestAccountDeletion` for an account with no blockers (e.g. `seed-customer-minh`), then call `restoreAccount` within 30 days to re-activate.
- To test the purge: set `restoreUntil` of the `account_deletions/{uid}` document to a past date in the emulator UI, then run `pruneNotifications` from the Functions shell:
  ```bash
  # Inside functions directory
  node -e "const { handleStartDueAccountPurges } = require('./lib/scheduled/start_account_purges.js'); handleStartDueAccountPurges();"
  ```
  The `onAccountDeletionUpdated` trigger will purge the account and tombstone `users/{uid}`.
- To test data export: call `requestDataExport` to generate an export JSON under `exports/{uid}/{exportId}.json` in Storage.

## Payment history (S22.01 · #141)

`users/{uid}/payments/{paymentId}` (one row per payment that received money) and
`users/{uid}/private/paymentTotals` (`held`, `refunding`), computed with the same pure functions as
the `onPaymentWritten` / `onRefundWritten` triggers, so they exist before any trigger runs:

| Payer | Rows |
|---|---|
| Lan | held (`seed-booking-accepted`, `-upcoming`, `-requested-binh`, the studio bookings; `-delivered` and `-revision` hold only the delivery milestone, 750 000), disputed (`seed-booking-disputed`), released (`seed-booking-completed-recent`, `-completed-old`, `-approved`), refunded to Vietcombank •••• 3456 (`seed-booking-cancelled`), her 250 000 ticket of the past workshop (held), and **`seed-payment-instant-lan-fixture`**: "Chụp ngay · Quận 1, TP.HCM", 690 000 by MoMo, held, "đang tìm thợ" |
| Giang | her S21 fee, "Phí xác minh", released to the platform ("Đã thanh toán") |

The Chụp ngay row is a **fixture row only**: no `payments/` or `instant_requests/` document is
behind it (a seeded `searching` request would start the live matching clock), so opening it finds
no request. A real one appears after paying a Chụp ngay request on the emulators (S13).

## Điểm chụp (S29)

| Điểm chụp | Khu vực | Mùa đẹp | Thợ nhận chụp | Gói chia suất |
|---|---|---|---|---|
| `seed-spot-cau-dat` (Đồi chè Cầu Đất) | Đà Lạt (`da-lat`) | Tháng 10–12 | — | — |
| `seed-spot-hoi-an` (Phố cổ Hội An) | Hội An (`hoi-an`) | Quanh năm | — | — |
| `seed-spot-ho-tay` (Hồ Tây) | Hà Nội (`hn`) | Quanh năm (ghim) | An (2 cuối tuần tới, 06:00–11:00) | "Bình minh Hồ Tây 30 phút" (490.000₫ · 30/10) |
| `seed-spot-cau-vang` (Cầu Vàng) | Đà Nẵng (`dn`) | Quanh năm | — (Bình chưa nhận đơn) | — |
| `seed-spot-mu-cang-chai` (Mù Cang Chải) | Yên Bái (`yen-bai`) | Tháng 9–10 | — | — |

Đăng nhập Lan, Trang chủ → Điểm chụp đang hot → Hồ Tây để thử S29.02 và đặt suất (S29.06).
Chạy `scripts/spots-local.sh rank` sau khi đổi dữ liệu để cập nhật bảng xếp hạng trên emulator.

## Chụp ngay (S13–S14, #140)

| Document | Value (test values) |
|---|---|
| `instant_config/current` | `enabled: true`, price list `priceListVersion: 1`, `platformFeeBp: 0` (everything to the photographer), `instantArrivedCancelPhotographerPercent: 50`; packages `p30` 30 phút · 15 ảnh · 390.000₫, `p60` 60 phút · 30 ảnh · 690.000₫, `p120` 120 phút · 60 ảnh · 1.190.000₫; cities `hcm` TP.HCM, `hn` Hà Nội, `dn` Đà Nẵng (bounding boxes, surge ×1.0); the twelve built-in areas of `lib/data/location/area.dart` for the offer's area label |

#140 moves no money: invites send the offers at once, only on a `demo-*` emulator or the dev project
(`inviteInstant` answers `not_eligible` anywhere else). Nobody is online at seeding: a photographer
turns Live Shutter on in S14.01 (Cúc in TP.HCM has a phone; accept the price list first).
The app keeps Chụp ngay hidden (`kInstantEnabled = false` in `lib/core/feature_flags.dart`; #202 flips it
once payment is in): to try S14.01–S14.03 on a device, set it to `true` locally and do not commit it
(the S06.01 card, the heartbeat and the offer listener only run with it on). Before `enabled` is used in a
real project, `instant_config/current` must exist there (the seed writes it only on the emulators).

Dev CLI (emulators only; refuses unless `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST`
point at a local host; push is only logged): `offer` creates a request for the customer 500 m north of
an online photographer (meet point "Điểm hẹn thử (CLI)") and sends them the offer, so S14.02/S14.03
can be tried before the customer app exists; `status` prints the request and its offer rows.

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=<project>
npm run instant -- offer --photographer seed-photographer-cuc [--customer seed-customer-lan] [--package p60] [--genre portrait]
# request 01J…
# offer 01J…
npm run instant -- status <requestId>
npm run clock -- bookings   # settles requests whose timers ran out (offers, search window, auto-complete)
```
