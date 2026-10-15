# Handover ledger — unit 10a (S17 notifications, S03.02 badges)

Plan: `docs/superpowers/plans/2026-10-06-10a-notifications-badges.md`. Built on the stack branch `plan/stack-2026-10` (not yet in develop).

## Built
- Domain: notification types, prefs, quiet hours (UTC+7), server-rendered copy, `notify` with dedupe/grouping, markAllRead, unread recount with timestamp guard, booking notices and reminders, nightly prune; badge catalogue (12), evaluator, reconcile, `punctualMentions`.
- Functions: notify adapters, FCM sender (dead-token cleanup), unread compare-and-write on `users/{uid}/private/inbox`, triggers (notifications, chat, devices, users, services, booking/review/post/award notices), schedules `reconcileBadges` 03:30 and `pruneNotifications` 03:45; rules, indexes, seed.
- App: notifications/prefs/badges repositories, push + permission ports (`firebase_messaging`, `permission_handler`), S17.01 inbox, S17.02 settings, S17.03 primer, Hồ sơ tab unread badge, S09.01 rows, push deep links (closed allowlist), S03.02 badges `/u/:uid/badges`, badge rows on S03.01/S09.01.

## Rulings
- R1 unread count lives in the private `users/{uid}/private/inbox` `{unreadCount, unreadCountAt}`, owner-read only (privacy over the spec's public placement).
- R2 read inbox rows older than 90 days are pruned nightly. R3 S17.02 jobs/instant rows behind flags. R4 notification copy in one domain table.
- A read grouped row restarts its count and actors (the brief's snippet carried them).
- The unread recount refuses only a strictly older `at` (ties: last writer wins).
- Primer: 7-day snooze after an OS refusal; in-flight flag expires after 10 minutes.
- Inbox paging is tie-safe (createdAt + id) with a fake-compatible over-fetch.
- Sign-out also deletes the FCM token (best effort).
- Seed gives seed-photographer-an real `stats` so the evaluator keeps `top_rated`.

## Deferred
- Push/badge notice lost if the process dies between commit and send (retry sees duplicate).
- Grouped chat row dedupes only the latest event; a stale unread chat row can remain after a race (clears on next visit).
- No APNs config (iOS deferred). `devices.lastSeenAt` not type-checked in rules.
- Badge catalogue exists only after the first nightly run: add a one-shot `syncCatalog` to the deploy job or an admin CLI.
- Push-open skips `targetExists` for `/b/` and `/chat/` (destinations show their own not-found).
- Primer uses `DateTime.now()`; `notification_primer_later` analytics also fires on OS refusal.
- `test/support/fake_push.dart` detects overrides via dynamic origin. Magic numbers in a few new widgets.
- An's seeded `badgeProgress` lacks the five extra entries the evaluator writes (overwritten on first trigger).
- Device-clock `seenAt` vs server `awardedAt` for the "Mới" dot.
