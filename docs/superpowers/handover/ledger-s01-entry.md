# SDD ledger — plan: docs/superpowers/plans/2026-10-07-s01-entry.md
Spec: docs/superpowers/specs/2026-10-01-remaining-screens.md (§2 status cells S01.03–S01.05 updated)
Issue: #149 · branch plan/149-s01-entry

## Decisions
1. S01.03 keeps the sign-up link; the mock was stale. Cost if wrong: one row to delete from the `#S01.03` frame; no app change. Mock row "Chưa có tài khoản? Đăng ký" added (266fc63).
2. S01.03 field icons and the show/hide eye stay. The spec lists `showPassword`/`hidePassword`; the mock is a static picture. Caption of `#S01.03` updated to name them. Cost if wrong: the eye and icons would need removing from the app.
3. S01.04 drops the AppBar (mock wins). Back works via the system back gesture and the "Đăng nhập" link under the card; the link does `canPop` → `pop`, else `go('/login')` so a direct `/register` open works. Cost if wrong: one AppBar widget to restore.
4. S01.04 "Đăng ký" button has no icon (mock `btn pri`); S01.03 "Đăng nhập" keeps its arrow. Cost if wrong: one `icon:` argument.
5. S01.05 icon tile: 36 dp circle (`.ic`). Selected → `primarySubtle` fill with `primary` icon; unselected → field fill with normal foreground icon (commit 3d9977d).
   Overridden by ruling (Task 2, 5103048): the unselected role card fill is now the glass token (`AppColors.glass` / `AppColorsDark.glass`), as the mock's `.opt` uses `var(--glass)`. Reason: in the light theme card and tile were both `colorScheme.secondary`, so the tile was invisible. Dark theme unchanged (same 0x14FFFFFF value). Cost if wrong: light-theme unselected card is white glass instead of beige; one line to revert.
6. S01.01 Splash and S01.02 Lỗi phiên are not touched, so no mock frame is added for them. They stay "Chưa có mock" (caller ruling: add frames only when the plan touches the screen).

## Mock edits
- `docs/design/ui-mock.html` (266fc63): `#S01.03` gained the row "Chưa có tài khoản? Đăng ký" after the card; captions of `#S01.03` and `#S01.04` updated.

## Review follow-ups (deferred minors)
- Register test "content starts below the top inset" passes even without the change.
- The 320×568 register test only asserts no exception.
- The role card's minHeight 48 has no test.

## Deferred
- Mock frames for S01.01 Splash and S01.02 Lỗi phiên: not touched by this plan (caller ruling); add them when one of those screens changes.
- Phone verification at sign-up: never (product rule: the phone is asked only when booking, S04.05/S21.01).
- Apple sign-in and the iOS enablement plan: outside S01 mock parity.

## Scope
No rules/functions touched, no emulator suite skipped.
