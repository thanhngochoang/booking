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
| `admin.staff@seed.test` | `seed-staff-admin` | staff | custom claim `staffRole: 'admin'`: may call `reviewAward` and is the `--actor` of `npm run awards` |

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
| `seed-booking-disputed` | Lan ↔ An | completed 10 hours before seeding; payment `disputed`, reason "Ảnh giao thiếu so với gói" |
| `earnings/{uid}` + `items/*` | An, Bình | the projection, computed with the same pure functions as the triggers (An: held 3 × 1 500 000, soon 1 500 000, received 1 500 000; the paid row carries its tax and net) |
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
| An, Cúc, Dũng | `approved` records from before the fee (match `verified: true`, `steps.fee` null) | Cúc (studio) has a full fake identity: in S21.04 her household tax code is her fake id number `001461723292` (`fakeIdNumberOf('seed-photographer-cuc')`) and is approved at once; any other 10-digit code is a company (needs a photo, goes to staff); codes ending `0000` are inactive |
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

Cúc is a verified studio (`providerType: studio`, `memberCount: 1`) with package `seed-service-studio-family`
(Gia đình tại studio 2 giờ, 2 500 000 ₫). Relation ids are `{studioId}_{memberId}_{createdAtMs}`; every seeded
photographer carries `nameKey` (the S26.02 search key).

| Data | Who | Notes |
|---|---|---|
| `studio_members/seed-photographer-cuc_seed-photographer-an_…` | Cúc ↔ An | `active`, joined 30 days before seeding; `photographers/seed-photographer-an.studioId` is Cúc |
| `studio_members/seed-photographer-cuc_seed-photographer-binh_…` | Cúc → Bình | `invited`, expires 5 days after seeding (sign in as Bình to answer in S26.03) |
| `studio_members/seed-photographer-cuc_seed-photographer-dung_…` | Dũng → Cúc | `requested` (join request; sign in as Cúc to approve in S26.01) |
| `seed-booking-studio-assigned` | Lan ↔ Cúc | accepted, assigned to An, 3 days ahead (the next day An is free); An's day is `booked`; Cúc's day is `full` (its one member is taken) |
| `seed-booking-studio-unassigned` | Lan ↔ Cúc | accepted, unassigned, starts about 20 h after seeding: its assign deadline has passed, so the first `npm run clock -- bookings` marks it overdue (`assign_overdue`, Lan may cancel with 100% back) |

`studio_day_load/seed-photographer-cuc_{day}` holds both bookings' days (server only). Studio bookings never write
the studio's own day as `booked`/`pending`; Cúc's `availability/{day}` only shows the derived `full`.

## Discovery stats (S02)

| Photographer | `startingPrice` | `stats.nextFreeDate` | `stats.completedCount` | Notes |
|---|---|---|---|---|
| An | 1 500 000 ₫ | computed from today & booked days | 3 | completed bookings: `recent`, `old`, `disputed` |
| Bình | 1 200 000 ₫ | computed from today | 0 | unverified, `acceptingOrders: false` |
| Cúc | 2 500 000 ₫ | computed from today and its `full` days | 0 | studio package `seed-service-studio-family` (S26) |
| Dũng | `null` | computed from today | 0 | no services seeded |

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
`npm run clock -- bookings` runs the booking clock once (sweeps, shoot reminders and the studio sweeps). The tool
refuses unless `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` point at a local host;
push is only logged.

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=<project>
npm run clock -- events
# eventClock: closed=0 completed=0 consentExpired=0 refunded=0 soonEvents=1 soonSent=1
# Lan's inbox now has "Chụp phố đêm bắt đầu ngày mai" (or "sau 2 ngày"); a second run sends nothing.
```

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


