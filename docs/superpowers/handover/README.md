# Handover (2026-10-02)

State of the Flutter rewrite (`app_flutter/`, branch `flutter-rewrite`) when this session stopped. Read `docs/superpowers/plans/RUN-ORDER.md` first: it lists the plans in the order to run, which ones are done, and the standing rules from the user. Per-screen status is the "Trạng thái" column in the code table of `docs/superpowers/specs/2026-10-01-remaining-screens.md`.

## Where to continue

1. **Plan `2026-10-02-mock-parity-1.md`** (make built screens match `docs/design/ui-mock.html`).
   - Done: Tasks 1–5 (AppButton sizes 48/38/30 and tokens; tab bar; chips, FreeTag, StatTile, PhotoPill; PhotographerCard small buttons; PhoneField two boxes).
   - Task 6 (S33 as a bottom sheet): code from a parallel session is committed (`showAddPhoneSheet`, `AddPhoneContent`, tests) but it has not been reviewed against the plan or the mock yet. Review it, then finish the task (callers opening the sheet, deep-link fallback).
   - Still to do: Tasks 7–11. Task 11 must **not** change the mock (the user does not want the agreed UI changed); only the app follows the mock. Items carried to Task 11 are listed in `ledger-mock-parity-1.md`.
   - Deviations per screen with file:line: `mock-parity-audit.md` (here).
2. **Plan `2026-10-01-step2c-skills.md`**: Tasks 1–6 done (catalogue, model, validation, completeness, repository, Firestore rules; emulator 55/55). Continue at Task 7. Rulings and carried items: `ledger-step2c-skills.md`.
3. Then the rest of `RUN-ORDER.md`.

## User decisions to keep

- The UI follows the committed mock; specs decide behaviour (also in `CLAUDE.md`).
- `PhotographerCard` has a small gradient "Đặt" button on every card; `PhoneField` is two boxes ("Mã +84" + number).
- No battery/performance steps or device builds inside feature plans: all in `2026-10-02-final-battery-performance.md`, run last.
- iOS work runs last: feature plans skip iOS-only steps and append them under "Deferred iOS steps" in `2026-10-01-ios-enablement.md`.
- Screen codes show on every screen in debug builds (default on; switch in Settings).
- Open question for the user: should Splash and the session-error screen get codes (S66, S67)? The spec says they need none.

## Things not to forget

- The Genymotion device has an old `com.thanhbk.photobooking` signed with another key: installing the new APK needs an uninstall first (wipes its data; ask the user).
- Commit `5c8f55e` (already on `origin/flutter-rewrite`) once contained `app_flutter/firebase/.certs/truststore.jks` and `local.properties`; they are untracked and ignored now, but remain in the remote history. If that truststore holds anything sensitive, rotate it; rewriting shared history is the user's call.
- Firestore rules for `photographers/{uid}` are close to the 1000-expression limit (~880 for the largest skills profile). New validators on that document must run only when their own field changes (`photographerFieldsOk`).
- Rules tests: `cd app_flutter/firebase/rules-test && npm test` (emulator; needs to run outside the sandbox).
- Ledgers of the finished plans 3a1, 3a2, 3b1, 3b2 are here for their rulings and parked findings.
