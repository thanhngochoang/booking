# Ledger · #339 Flutter 3.50.1 and material_ui

Plan: in issue #339 (plan-in-issue). Branch `plan/339-ha-tang-nang-flutter-len-ban-stable-moi`.

## Rulings

1. **Version file.** Flutter 3.47+ has no `.flutter/version`; `scripts/install-flutter.sh` reads
   `frameworkVersion` from `.flutter/bin/cache/flutter.version.json` (falls back to `version`).
2. **SDK during the work.** The unit's worktree used its own `.flutter` so other worktrees on the machine
   stayed on 3.47.6 until the merge. After the final review the script follows a worktree's `.flutter` link
   and updates the main checkout's SDK, which is what `env.sh` and `scripts/bin/flutter` use.
3. **No tree-wide `dart format`.** The 3.14 formatter rewrites hundreds of unrelated files; CI has no
   format check, so only hand-written lines were formatted.
4. **Localization delegates.** `flutter gen-l10n` on 3.50.1 still emits the legacy `flutter_localizations`
   list on `AppLocalizations.localizationsDelegates`, which gives the vi locale no material_ui strings.
   The app and the tests use `appLocalizationsDelegates` (`lib/core/l10n_delegates.dart`, exported by
   `core/core.dart`): `AppLocalizations.delegate` plus material_ui's `GlobalMaterialLocalizations.delegates`
   (Material, Cupertino and Widgets). Revisit when gen-l10n emits material_ui delegates.
5. **Generated macOS registrant.** `GeneratedPluginRegistrant.swift` is committed as 3.50.1 writes it,
   so `pub get` leaves the tree clean.
6. **Android Gradle Plugin 9.1.1.** Flutter 3.50 refuses 9.1.0; a debug APK builds with 9.1.1.
7. **Album undo test.** The route change takes longer than 400 ms on 3.50, and both pages show the snack
   bar until it ends; the test pumps 400 + 600 ms (well inside the snack bar's 5 s). Test-only.
8. **No `MaterialUiCompatibilityBridge`.** The final review checked qr_flutter, mobile_scanner,
   cached_network_image/octo_image, flutter_riverpod, google_sign_in and go_router: none reads the legacy
   Theme or MaterialLocalizations at our call sites.

## Deferred

- The version check re-downloads the SDK when `.flutter/bin/cache` was deleted (harmless, 1 GB).
- Not run on a device (none attached); the debug APK builds.
