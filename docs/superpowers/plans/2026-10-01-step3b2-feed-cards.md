# Step 3b2: Feed Cards (NetworkPhoto, AppAvatar, ReasonChips, PhotoCard, PhotographerCard) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The widgets the Home, Photo detail and Find screens are made of: `NetworkPhoto` (cached, decoded at display size, retry on failure), `AppAvatar`, `ReasonChips`, `PhotoCard` and `PhotographerCard`, plus the day, money-free formatters they need.

**Architecture:** All in `lib/core/widgets/`, themed only through `Theme`, `AppColors`/`AppColorsDark`, `AppSpace`, `AppRadius`. They take plain read models (`PhotographerSummary`, `Reason`) from `lib/data/content/` or primitives, never providers. Images go through one widget, `NetworkPhoto`, which asks an inherited `PhotoImageScope` for the actual image widget; production uses `cached_network_image`, tests install a flat-colour builder so no widget test touches the network or a plugin. No card uses `BackdropFilter`: list items and grid cards use a translucent fill (blur budget).

**Tech Stack:** Flutter, `cached_network_image`, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/components/shared-components.md` (AppAvatar, PhotoCard, PhotographerCard, ReasonChips, VerifiedMark), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §4, §3d.1, §3e.9, §7; `docs/superpowers/specs/screens/discovery.md` (S01, S02, S04 layouts); mock `docs/design/ui-mock.html` (`data-code="S01"`, `S04`).

**Prerequisite:** plans `step3a1-location-foundations` (formatters `format.dart`, `AppChip`), `step3a2-explore-screens` (`formatMoney`, `specialtyLabel`, `test/support/screen_host.dart`) and `step3b1-feed-data` (`PhotographerSummary`, `Reason`, fixtures) are done; the core-display-widgets plan is done (`VerifiedName`, `hostWidget`).

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; widgets in `core/` import each other directly; `core/` may import `package:photobooking/data/content/...` read models only where a signature needs them (`PhotographerSummary`, `Reason`).
- No hard-coded UI text: Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`. Colours, spacing and radii from tokens; text over photos is white on a bottom gradient.
- **Blur budget:** at most 4 `BackdropFilter`s per screen and none nested; cards and list items never use `BackdropFilter` (a feed of 10 cards adds 0).
- **Images:** every network image is shown through `NetworkPhoto`, which decodes at display size (`memCacheWidth` = layout width x device pixel ratio, rounded up to 50 px) and never asks for the original size.
- Every interactive control has a 48dp touch target; meaning never rests on colour alone; layouts are tested at width 320 and text scale 1.3; no deprecated Flutter API.
- iOS: this plan adds no platform configuration (`cached_network_image` needs none beyond what `flutter pub get` wires); iOS cannot be built on this machine yet (separate "iOS enablement" plan).
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/widgets/network_photo.dart` (create) | `PhotoImageBuilder`, `PhotoImageScope`, `NetworkPhoto`, `cachedPhotoBuilder` |
| `lib/core/widgets/app_avatar.dart` (create) | `AppAvatarSize`, `AppAvatar`, `avatarInitial` |
| `lib/core/format.dart` (modify) | `weekdayLabel`, `formatDay`, `formatDayMonth`, `formatRating` |
| `lib/core/widgets/reason_chips.dart` (create) | `ReasonChips` |
| `lib/core/widgets/photo_card.dart` (create) | `PhotoCard`, `PhotoPill` |
| `lib/core/widgets/photographer_card.dart` (create) | `PhotographerCard` |
| `lib/core/core.dart` (modify) | export the new files |
| `pubspec.yaml` (modify) | `cached_network_image` |
| `lib/l10n/app_vi.arb` (modify) | strings listed per task |
| `test/support/photo_scope.dart` (create) | flat-colour `PhotoImageScope` for tests |
| `test/support/screen_host.dart` (modify) | screens are hosted under that scope |
| tests | one file per widget, plus `test/battery/feed_cards_battery_test.dart` |

---

### Task 1: `NetworkPhoto`, `PhotoImageScope` and the test scope

**Files:**
- Create: `lib/core/widgets/network_photo.dart`, `test/support/photo_scope.dart`, `test/core/widgets/network_photo_test.dart`
- Modify: `lib/core/core.dart`, `test/support/screen_host.dart`, `pubspec.yaml`

**Interfaces:**
- Produces:
  - `typedef PhotoImageBuilder = Widget Function(BuildContext context, String url, BoxFit fit, int? cacheWidth, bool retry);`
  - `class PhotoImageScope extends InheritedWidget { const PhotoImageScope({super.key, required PhotoImageBuilder builder, required super.child}); static PhotoImageBuilder of(BuildContext context); }` — `of` returns `cachedPhotoBuilder` when no scope is above.
  - `Widget cachedPhotoBuilder(BuildContext context, String url, BoxFit fit, int? cacheWidth, bool retry)` — `CachedNetworkImage` with `memCacheWidth: cacheWidth`, a flat placeholder, and, when `retry` is true, an error tile with a "Thử lại" icon button that evicts the cached failure and reloads. With `retry: false` placeholder and error are empty so a widget underneath (initials) shows.
  - `const NetworkPhoto({super.key, required String url, BoxFit fit = BoxFit.cover, String? semanticLabel, bool retry = true})` — measures its width, asks the scope for the image with `cacheWidth` = `ceil(width * devicePixelRatio / 50) * 50` (null when the width is unbounded); a `semanticLabel` makes it an image node, otherwise it is excluded from semantics.
  - Test helper: `class PhotoRequest { final String url; final BoxFit fit; final int? cacheWidth; final bool retry; }`, `Widget testPhotoScope({required Widget child, List<PhotoRequest>? log})` — builds `ColoredBox(key: ValueKey('photo:$url'))`.

- [ ] **Step 1: Add the dependency and write the failing tests**

```bash
flutter pub add cached_network_image
flutter pub deps --style=compact | grep -E "^- cached_network_image "
```

Expected: a line like `- cached_network_image 3.4.x` (version 3.3 or newer; `memCacheWidth`, `fadeInDuration` and the static `evictFromCache` exist in all of them).

```dart
// test/support/photo_scope.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';

class PhotoRequest {
  const PhotoRequest(this.url, this.fit, this.cacheWidth, this.retry);
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final bool retry;
}

/// Hosts photos as flat grey boxes, so widget tests need no network and no
/// image plugin. Every request is appended to [log] when given.
Widget testPhotoScope({required Widget child, List<PhotoRequest>? log}) {
  return PhotoImageScope(
    builder: (context, url, fit, cacheWidth, retry) {
      log?.add(PhotoRequest(url, fit, cacheWidth, retry));
      return ColoredBox(
        key: ValueKey('photo:$url'),
        color: const Color(0xFF888888),
      );
    },
    child: child,
  );
}
```

```dart
// test/core/widgets/network_photo_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

void main() {
  testWidgets('asks the scope for the url, fit and a display-size decode width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const SizedBox(
            height: 100,
            child: NetworkPhoto(url: 'https://img.test/a.jpg', fit: BoxFit.contain),
          ),
        ),
        width: 150,
      ),
    );
    expect(find.byKey(const ValueKey('photo:https://img.test/a.jpg')), findsOneWidget);
    expect(log.last.url, 'https://img.test/a.jpg');
    expect(log.last.fit, BoxFit.contain);
    expect(log.last.cacheWidth, 300, reason: '150 dp x 2 = 300 px');
    expect(log.last.retry, isTrue);
  });

  testWidgets('the decode width is rounded up to 50 px', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const SizedBox(height: 100, child: NetworkPhoto(url: 'u')),
        ),
        width: 120,
      ),
    );
    expect(log.last.cacheWidth, 400, reason: '120 dp x 3 = 360 px, rounded up to 400');
  });

  testWidgets('an unbounded width gives no decode width', (tester) async {
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(height: 50, child: NetworkPhoto(url: 'u')),
          ),
        ),
      ),
    );
    expect(log.last.cacheWidth, isNull);
  });

  testWidgets('retry: false is passed through (avatars show initials instead)', (
    tester,
  ) async {
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const SizedBox(height: 50, child: NetworkPhoto(url: 'u', retry: false)),
        ),
      ),
    );
    expect(log.last.retry, isFalse);
  });

  testWidgets('with a label it is an image node, without one it is silent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          child: const SizedBox(
            height: 50,
            child: NetworkPhoto(url: 'u', semanticLabel: 'Ảnh chân dung'),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Ảnh chân dung'), findsOneWidget);
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(child: const SizedBox(height: 50, child: NetworkPhoto(url: 'u'))),
      ),
    );
    expect(find.bySemanticsLabel('Ảnh chân dung'), findsNothing);
    handle.dispose();
  });

  testWidgets('without a scope the production builder is used', (tester) async {
    PhotoImageBuilder? found;
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) {
            found = PhotoImageScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, cachedPhotoBuilder);
  });
}
```

Update `test/support/screen_host.dart` (plan 3a2) so every hosted screen uses the test photo scope: add `import 'photo_scope.dart';` and, in both `screenApp` and `screenRouterApp`, change the `builder` to wrap the child:

```dart
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: testPhotoScope(child: child!),
      ),
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/network_photo_test.dart`
Expected: FAIL, `NetworkPhoto` / `PhotoImageScope` / `cachedPhotoBuilder` are undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/network_photo.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';

/// Builds the actual image widget. [cacheWidth] is the decode width in pixels
/// (null when unknown); [retry] says whether a failed load may show a retry
/// button.
typedef PhotoImageBuilder =
    Widget Function(
      BuildContext context,
      String url,
      BoxFit fit,
      int? cacheWidth,
      bool retry,
    );

/// Lets tests (and previews) replace how photos are loaded. Without a scope,
/// photos come from [cachedPhotoBuilder].
class PhotoImageScope extends InheritedWidget {
  const PhotoImageScope({
    super.key,
    required this.builder,
    required super.child,
  });

  final PhotoImageBuilder builder;

  static PhotoImageBuilder of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoImageScope>()?.builder ??
      cachedPhotoBuilder;

  @override
  bool updateShouldNotify(PhotoImageScope old) => builder != old.builder;
}

/// A network photo, decoded at the size it is shown (never the original) and
/// cached on disk.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.retry = true,
  });

  final String url;
  final BoxFit fit;
  final String? semanticLabel;
  final bool retry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth;
        final cacheWidth = (width.isFinite && width > 0)
            ? ((width * ratio) / 50).ceil() * 50
            : null;
        final image = PhotoImageScope.of(
          context,
        )(context, url, fit, cacheWidth, retry);
        return semanticLabel == null
            ? ExcludeSemantics(child: image)
            : Semantics(
                image: true,
                label: semanticLabel,
                child: ExcludeSemantics(child: image),
              );
      },
    );
  }
}

/// Production image: disk cache, decode at [cacheWidth], flat placeholder, and
/// an error tile that can retry. No automatic retry loop (that would burn
/// battery on a dead link).
Widget cachedPhotoBuilder(
  BuildContext context,
  String url,
  BoxFit fit,
  int? cacheWidth,
  bool retry,
) => _CachedPhoto(url: url, fit: fit, cacheWidth: cacheWidth, retry: retry);

class _CachedPhoto extends StatefulWidget {
  const _CachedPhoto({
    required this.url,
    required this.fit,
    required this.cacheWidth,
    required this.retry,
  });

  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final bool retry;

  @override
  State<_CachedPhoto> createState() => _CachedPhotoState();
}

class _CachedPhotoState extends State<_CachedPhoto> {
  int _attempt = 0;

  Future<void> _reload() async {
    await CachedNetworkImage.evictFromCache(widget.url);
    if (mounted) {
      setState(() => _attempt++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.secondary;
    return CachedNetworkImage(
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      fit: widget.fit,
      memCacheWidth: widget.cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) =>
          widget.retry ? ColoredBox(color: fill) : const SizedBox.shrink(),
      errorWidget: (context, _, _) => widget.retry
          ? ColoredBox(
              color: fill,
              child: Center(
                child: IconButton(
                  tooltip: context.l10n.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _reload,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
```

Export `network_photo.dart` from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/network_photo_test.dart && flutter analyze && flutter test test/features`
Expected: PASS (6 tests); analyze clean; the existing screen tests still pass with the photo scope added to `screenApp`.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core test/core/widgets/network_photo_test.dart test/support
git commit -m "feat(core): NetworkPhoto with display-size decoding and a test photo scope

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `AppAvatar`

**Files:**
- Create: `lib/core/widgets/app_avatar.dart`, `test/core/widgets/app_avatar_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `NetworkPhoto`, `testPhotoScope`, `hostWidget`.
- Produces: `enum AppAvatarSize { xs, sm, md, lg, xl }` with `double get dimension` (32, 40, 48, 64, 96); `String avatarInitial(String name)` — upper-case first letter of the last word (the given name in Vietnamese), `?` for an empty name; `const AppAvatar({super.key, String? url, required String name, AppAvatarSize size = AppAvatarSize.md, Widget? badge})` — a circle with a 2dp ring in the page colour; initials on a soft brand gradient underneath, the photo on top (loaded with `retry: false`); `Semantics(label: name)` (image excluded).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/app_avatar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

void main() {
  test('the initial is the first letter of the given name', () {
    expect(avatarInitial('Minh Trí'), 'T');
    expect(avatarInitial('  nguyễn thị phương '), 'P');
    expect(avatarInitial('Lan'), 'L');
    expect(avatarInitial('đức'), 'Đ');
    expect(avatarInitial(''), '?');
    expect(avatarInitial('   '), '?');
  });

  test('sizes follow the spec', () {
    expect(AppAvatarSize.values.map((s) => s.dimension), [32, 40, 48, 64, 96]);
  });

  testWidgets('without a photo it shows the initial at the requested size', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const AppAvatar(name: 'Minh Trí', size: AppAvatarSize.lg)),
    );
    expect(find.text('T'), findsOneWidget);
    expect(tester.getSize(find.byType(AppAvatar)), const Size(64, 64));
    expect(find.byType(NetworkPhoto), findsNothing);
  });

  testWidgets('with a photo the image is requested without a retry button', (
    tester,
  ) async {
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const AppAvatar(url: 'https://img.test/a.jpg', name: 'Minh Trí'),
        ),
      ),
    );
    expect(log.single.url, 'https://img.test/a.jpg');
    expect(log.single.retry, isFalse);
    expect(find.text('T'), findsOneWidget, reason: 'initials stay underneath');
  });

  testWidgets('a badge sits at the bottom right', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const AppAvatar(
          name: 'Minh Trí',
          badge: Icon(Icons.circle, key: Key('badge'), size: 12),
        ),
      ),
    );
    final avatar = tester.getRect(find.byType(AppAvatar));
    final badge = tester.getRect(find.byKey(const Key('badge')));
    expect(badge.center.dx, greaterThan(avatar.center.dx));
    expect(badge.center.dy, greaterThan(avatar.center.dy));
  });

  testWidgets('screen readers hear the name once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const AppAvatar(name: 'Minh Trí')));
    expect(find.bySemanticsLabel('Minh Trí'), findsOneWidget);
    handle.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('renders on ${b.name} without overflow', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          const Row(
            children: [
              AppAvatar(name: 'A', size: AppAvatarSize.xs),
              AppAvatar(name: 'B', size: AppAvatarSize.xl),
            ],
          ),
          brightness: b,
          width: 320,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/app_avatar_test.dart`
Expected: FAIL, `AppAvatar` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/app_avatar.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

enum AppAvatarSize {
  xs(32),
  sm(40),
  md(48),
  lg(64),
  xl(96);

  const AppAvatarSize(this.dimension);
  final double dimension;
}

/// Upper-case first letter of the last word of [name] (the given name in
/// Vietnamese), or `?` when there is none.
String avatarInitial(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) {
    return '?';
  }
  return words.last.characters.first.toUpperCase();
}

/// A round profile picture. A failed or missing photo leaves the initial on a
/// soft gradient; the photo itself never shows a retry button here.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = AppAvatarSize.md,
    this.badge,
  });

  final String? url;
  final String name;
  final AppAvatarSize size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = size.dimension;
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: d,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.ctaStart.withValues(alpha: 0.35),
                              AppColors.ctaEnd.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            avatarInitial(name),
                            style: TextStyle(
                              fontSize: d * 0.4,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (url != null) NetworkPhoto(url: url!, retry: false),
                    ],
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(right: -2, bottom: -2, child: badge!),
          ],
        ),
      ),
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/app_avatar_test.dart && flutter analyze`
Expected: PASS (8 tests); analyze clean. `characters` comes from `package:characters`, re-exported by `package:flutter/material.dart`.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/widgets/app_avatar_test.dart
git commit -m "feat(core): AppAvatar with initials fallback

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Day and rating formatters

**Files:**
- Modify: `lib/core/format.dart`, `test/core/format_test.dart`

**Interfaces:**
- Produces: `String weekdayLabel(int weekday)` (`DateTime.monday` to `DateTime.sunday` → `T2` … `T7`, `CN`); `String formatDay(DateTime day)` → `T7 12/10` from the calendar fields of [day] (pass a Vietnamese calendar date, for example `parseDayKey(...)` or `toVn(instant)`); `String formatDayMonth(DateTime day)` → `12/10`; `String formatRating(double rating)` → `4,9`.

- [ ] **Step 1: Write the failing test**

Append inside `main()` of `test/core/format_test.dart`:

```dart
  test('weekday labels run T2 to T7 then CN', () {
    expect(
      [for (var d = DateTime.monday; d <= DateTime.sunday; d++) weekdayLabel(d)],
      ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
    );
  });

  test('formatDay and formatDayMonth read the calendar fields', () {
    final saturday = DateTime.utc(2026, 10, 3); // a Saturday
    expect(formatDay(saturday), 'T7 03/10');
    expect(formatDayMonth(saturday), '03/10');
    expect(formatDay(DateTime.utc(2026, 10, 4)), 'CN 04/10');
    expect(formatDay(DateTime.utc(2026, 12, 25)), 'T6 25/12');
  });

  test('formatRating has one decimal and a comma', () {
    expect(formatRating(4.9), '4,9');
    expect(formatRating(5), '5,0');
    expect(formatRating(4.56), '4,6');
    expect(formatRating(4.54), '4,5');
    expect(formatRating(0), '0,0');
  });
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/format_test.dart`
Expected: FAIL, the three functions are undefined.

- [ ] **Step 3: Implement**

Append to `lib/core/format.dart`:

```dart
/// `T2`..`T7`, `CN` for [DateTime.monday]..[DateTime.sunday].
String weekdayLabel(int weekday) =>
    weekday == DateTime.sunday ? 'CN' : 'T${weekday + 1}';

String _two(int n) => n.toString().padLeft(2, '0');

/// `12/10`.
String formatDayMonth(DateTime day) => '${_two(day.day)}/${_two(day.month)}';

/// `T7 12/10`. [day] is a Vietnamese calendar date; only its calendar fields
/// are read, so no time zone conversion happens here.
String formatDay(DateTime day) =>
    '${weekdayLabel(day.weekday)} ${formatDayMonth(day)}';

/// `4,9`.
String formatRating(double rating) =>
    ((rating * 10).round() / 10).toStringAsFixed(1).replaceAll('.', ',');
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/format_test.dart && flutter analyze`
Expected: PASS; analyze clean. (the rule is "nearest tenth".)

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/format_test.dart
git commit -m "feat(core): day and rating formatters

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `ReasonChips`

**Files:**
- Create: `lib/core/widgets/reason_chips.dart`, `test/core/widgets/reason_chips_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `Reason` (3b1), `hostWidget`.
- Produces: `const ReasonChips({super.key, required List<Reason> reasons, int max = 2})` — up to [max] small chips (translucent fill, hairline, 10.5 text, one line each); extra reasons are dropped, not scrolled; an empty list renders nothing; one semantics node "Gợi ý vì: a, b" (only the shown reasons). l10n `reasonsSemantics(reasons)` = "Gợi ý vì: {reasons}".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/reason_chips_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/reason.dart';

import 'widget_host.dart';

const _a = Reason(code: ReasonCode.skillMatch, text: 'Chuyên chân dung');
const _b = Reason(code: ReasonCode.near, text: '1,2 km');
const _c = Reason(code: ReasonCode.freeOnDate, text: 'Rảnh T7 12/10');

void main() {
  testWidgets('shows at most two reasons by default, in order', (tester) async {
    await tester.pumpWidget(hostWidget(const ReasonChips(reasons: [_a, _b, _c])));
    expect(find.text('Chuyên chân dung'), findsOneWidget);
    expect(find.text('1,2 km'), findsOneWidget);
    expect(find.text('Rảnh T7 12/10'), findsNothing);
  });

  testWidgets('max can raise the limit', (tester) async {
    await tester.pumpWidget(
      hostWidget(const ReasonChips(reasons: [_a, _b, _c], max: 3)),
    );
    expect(find.text('Rảnh T7 12/10'), findsOneWidget);
  });

  testWidgets('an empty list renders nothing', (tester) async {
    await tester.pumpWidget(hostWidget(const ReasonChips(reasons: [])));
    expect(tester.getSize(find.byType(ReasonChips)).height, 0);
  });

  testWidgets('one semantics node lists the shown reasons', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const ReasonChips(reasons: [_a, _b, _c])));
    expect(
      find.bySemanticsLabel('Gợi ý vì: Chuyên chân dung, 1,2 km'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a long reason is cut to one line inside a narrow card', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const ReasonChips(
          reasons: [
            Reason(
              code: ReasonCode.topRated,
              text: 'Được đánh giá cao bởi rất nhiều khách hàng đã chụp cùng',
            ),
            _b,
          ],
        ),
        width: 120,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ReasonChips)).width, lessThanOrEqualTo(120));
  });

  for (final b in Brightness.values) {
    testWidgets('has no blur on ${b.name}', (tester) async {
      await tester.pumpWidget(
        hostWidget(const ReasonChips(reasons: [_a, _b]), brightness: b),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/reason_chips_test.dart`
Expected: FAIL, `ReasonChips` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry) and run `flutter gen-l10n`:

```json
  "reasonsSemantics": "Gợi ý vì: {reasons}",
  "@reasonsSemantics": {
    "placeholders": {
      "reasons": {"type": "String"}
    }
  }
```

```dart
// lib/core/widgets/reason_chips.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/data/content/reason.dart';

/// Why this photographer is recommended: up to [max] short chips. Dropped
/// reasons are not scrolled to; the card stays calm.
class ReasonChips extends StatelessWidget {
  const ReasonChips({super.key, required this.reasons, this.max = 2});

  final List<Reason> reasons;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = reasons.take(max).toList();
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.reasonsSemantics(shown.map((r) => r.text).join(', ')),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: AppSpace.s1,
          runSpacing: AppSpace.s1,
          children: [
            for (final r in shown)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical: AppSpace.s1,
                    ),
                    child: Text(
                      r.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/core/widgets/reason_chips_test.dart && flutter analyze`
Expected: PASS (7 tests); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets/reason_chips_test.dart
git commit -m "feat(core): ReasonChips

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `PhotoCard` and `PhotoPill`

**Files:**
- Create: `lib/core/widgets/photo_card.dart`, `test/core/widgets/photo_card_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `NetworkPhoto`, `testPhotoScope`, `hostWidget`.
- Produces:
  - `const PhotoCard({super.key, required String imageUrl, String? blurHash, required double aspect, String? title, String? subtitle, Widget? leadingPill, Widget? trailingPill, Widget? action, VoidCallback? onTap})` — an `AspectRatio` card (radius 20, no border, no shadow, no blur); text, if any, sits over a black gradient at the bottom (white text; smaller below 200dp width), pills at the top corners, `action` at the right of the bottom row; the whole card is the tap target; one merged semantics node. `blurHash` is accepted and stored for the later blurhash placeholder; the current placeholder is the flat theme colour.
  - `const PhotoPill({super.key, required String label, bool dot = false})` — small dark translucent pill with white text and an optional green dot (availability).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/photo_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

Widget _card({
  double aspect = 4 / 5,
  String? title = 'Minh Trí',
  String? subtitle = 'Quận 3 · ★ 4,9 (58) · 112 buổi',
  Widget? leading,
  Widget? trailing,
  Widget? action,
  VoidCallback? onTap,
  double width = 300,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  List<PhotoRequest>? log,
}) => hostWidget(
  testPhotoScope(
    log: log,
    child: PhotoCard(
      imageUrl: 'https://img.test/a.jpg',
      blurHash: 'LEHV6nWB2yk8',
      aspect: aspect,
      title: title,
      subtitle: subtitle,
      leadingPill: leading,
      trailingPill: trailing,
      action: action,
      onTap: onTap,
    ),
  ),
  width: width,
  textScale: textScale,
  brightness: brightness,
);

void main() {
  testWidgets('shows the photo, title, subtitle, pills and action', (tester) async {
    await tester.pumpWidget(
      _card(
        leading: const PhotoPill(label: 'Rảnh T7 này', dot: true),
        trailing: const PhotoPill(label: 'Chân dung · từ 1,5M'),
        action: const Icon(Icons.bookmark_border, key: Key('save')),
      ),
    );
    expect(find.byKey(const ValueKey('photo:https://img.test/a.jpg')), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Quận 3 · ★ 4,9 (58) · 112 buổi'), findsOneWidget);
    expect(find.text('Rảnh T7 này'), findsOneWidget);
    expect(find.text('Chân dung · từ 1,5M'), findsOneWidget);
    expect(find.byKey(const Key('save')), findsOneWidget);
  });

  testWidgets('pills sit at the top corners, the action at the bottom right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        leading: const PhotoPill(label: 'L'),
        trailing: const PhotoPill(label: 'R'),
        action: const SizedBox(key: Key('act'), width: 30, height: 30),
      ),
    );
    final card = tester.getRect(find.byType(PhotoCard));
    final l = tester.getRect(find.text('L'));
    final r = tester.getRect(find.text('R'));
    final act = tester.getRect(find.byKey(const Key('act')));
    expect(l.top, lessThan(card.top + 40));
    expect(l.left, lessThan(card.left + 40));
    expect(r.right, greaterThan(card.right - 40));
    expect(act.bottom, greaterThan(card.bottom - 40));
    expect(act.right, greaterThan(card.right - 40));
  });

  testWidgets('keeps the aspect ratio (4:5 and 3:4)', (tester) async {
    await tester.pumpWidget(_card(aspect: 4 / 5));
    var s = tester.getSize(find.byType(PhotoCard));
    expect(s.width / s.height, closeTo(0.8, 0.001));
    await tester.pumpWidget(_card(aspect: 3 / 4));
    s = tester.getSize(find.byType(PhotoCard));
    expect(s.width / s.height, closeTo(0.75, 0.001));
  });

  testWidgets('a card without text has no gradient overlay', (tester) async {
    await tester.pumpWidget(_card(title: null, subtitle: null));
    expect(find.byKey(const Key('photo-card-scrim')), findsNothing);
    await tester.pumpWidget(_card());
    expect(find.byKey(const Key('photo-card-scrim')), findsOneWidget);
  });

  testWidgets('tapping the card calls onTap; without onTap it is not a button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_card(onTap: () => taps++));
    await tester.tap(find.byType(PhotoCard));
    expect(taps, 1);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(PhotoCard)).label,
      contains('Minh Trí'),
    );
    handle.dispose();
  });

  testWidgets('the photo is decoded at card size, not original size', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(_card(width: 120, log: log));
    expect(log.single.cacheWidth, 400, reason: '120 dp x 3 = 360 px rounded up to 400');
  });

  testWidgets('an action inside the card gets its own tap; the rest opens the card', (
    tester,
  ) async {
    var taps = 0, acts = 0;
    await tester.pumpWidget(
      _card(
        onTap: () => taps++,
        action: IconButton(
          key: const Key('act'),
          onPressed: () => acts++,
          icon: const Icon(Icons.bookmark_border),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('act')));
    expect((taps, acts), (0, 1));
    await tester.tap(find.text('Minh Trí'));
    expect((taps, acts), (1, 1), reason: 'tapping the title opens the card');
  });

  testWidgets('has no BackdropFilter', (tester) async {
    await tester.pumpWidget(_card());
    expect(find.byType(BackdropFilter), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('a 120dp-wide card with long text fits at 1.3x on ${b.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          aspect: 3 / 4,
          title: 'Nguyễn Thị Phương Anh',
          subtitle: 'Gia đình · từ 1,2M',
          width: 120,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/photo_card_test.dart`
Expected: FAIL, `PhotoCard` / `PhotoPill` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/photo_card.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

/// A photo with optional text on a bottom gradient (S01, S13, S21, S03). No
/// border, no shadow, and no blur: a feed of these must stay cheap.
class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.imageUrl,
    this.blurHash,
    required this.aspect,
    this.title,
    this.subtitle,
    this.leadingPill,
    this.trailingPill,
    this.action,
    this.onTap,
  });

  final String imageUrl;

  /// Kept for the blurhash placeholder (a later enhancement); the placeholder
  /// today is the flat theme colour.
  final String? blurHash;

  /// Width divided by height: 4/5 for the large card, 3/4 for small ones.
  final double aspect;
  final String? title;
  final String? subtitle;
  final Widget? leadingPill;
  final Widget? trailingPill;

  /// Shown at the right of the text row, for example a save button.
  final Widget? action;
  final VoidCallback? onTap;

  static const _radius = AppRadius.lg + 8;

  @override
  Widget build(BuildContext context) {
    final hasText = title != null || subtitle != null;
    final label = [title, subtitle].whereType<String>().join(', ');
    return AspectRatio(
      aspectRatio: aspect,
      child: Semantics(
        container: true,
        button: onTap != null,
        image: true,
        label: label.isEmpty ? null : label,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final small = constraints.maxWidth < 200;
              return Stack(
                fit: StackFit.expand,
                children: [
                  NetworkPhoto(url: imageUrl),
                  if (hasText)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: Key('photo-card-scrim'),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xB3000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // The tap layer sits under the labels and the action, so an
                  // action button receives its own taps and the rest of the
                  // card opens it.
                  if (onTap != null)
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(onTap: onTap),
                      ),
                    ),
                  if (leadingPill != null)
                    Positioned(
                      left: AppSpace.s2,
                      top: AppSpace.s2,
                      child: IgnorePointer(child: leadingPill!),
                    ),
                  if (trailingPill != null)
                    Positioned(
                      right: AppSpace.s2,
                      top: AppSpace.s2,
                      child: IgnorePointer(child: trailingPill!),
                    ),
                  if (hasText || action != null)
                    Positioned(
                      left: AppSpace.s3,
                      right: AppSpace.s3,
                      bottom: AppSpace.s3,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: IgnorePointer(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (title != null)
                                    Text(
                                      title!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: small ? AppText.sm : AppText.base,
                                      ),
                                    ),
                                  if (subtitle != null)
                                    Text(
                                      subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: small ? 10.5 : AppText.sm,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (action != null) action!,
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A small dark pill over a photo: availability ("Rảnh T7 này"), package and
/// price. White text on a 55% black fill keeps 4.5:1 on any photo.
class PhotoPill extends StatelessWidget {
  const PhotoPill({super.key, required this.label, this.dot = false});

  final String label;

  /// A green dot before the label, meaning "free".
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 6),
              ),
              const SizedBox(width: AppSpace.s1),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/photo_card_test.dart && flutter analyze`
Expected: PASS (10 tests); analyze clean. The scrim colours are the only literals and are black with alpha, not theme colours.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/widgets/photo_card_test.dart
git commit -m "feat(core): PhotoCard and PhotoPill

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `PhotographerCard`

**Files:**
- Create: `lib/core/widgets/photographer_card.dart`, `test/core/widgets/photographer_card_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `PhotographerSummary`, `Reason`, `NetworkPhoto`, `AppAvatar`, `ReasonChips`, `PhotoPill`, `VerifiedName`, `AppButton`, `formatDistance`, `formatMoney`, `formatRating`, `specialtyLabel` (3a2).
- Produces: `const PhotographerCard({super.key, required PhotographerSummary data, List<Reason> reasons = const [], double? distanceKm, String? availabilityLabel, required VoidCallback onProfile, VoidCallback? onBook, String? bookLabel})`.
  - Layout: hero 16:9 (`heroUrl`, flat colour when null) with the availability pill (green dot) at the top left; a row with `AppAvatar` (md), the name (`VerifiedName` when verified), a meta line `Chân dung · 1,2 km · ★ 4,9 · 112 buổi` (only the parts that exist) and, at the right, "từ" over the short price (`—` when unknown); `ReasonChips` (at most 2); a button row `Hồ sơ` (outline, key `card-profile-<id>`) and, when [onBook] is given, `bookLabel ?? "Đặt lịch"` (outline in the primary colour, key `card-book-<id>`). Under large text (scaled 16sp above 18.4) the two buttons stack. Tapping the hero or the header row calls [onProfile]. No blur.
  - l10n: `photographerSessions(n)` "{n} buổi", `priceFrom` "từ", `photographerCardProfile` "Hồ sơ", `photographerCardBook` "Đặt lịch".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/photographer_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/reason.dart';

import '../../support/content_fixtures.dart';
import '../../support/photo_scope.dart';
import 'widget_host.dart';

Widget _card({
  bool verified = true,
  List<Reason> reasons = const [],
  double? distanceKm = 1.2,
  String? availability = 'Rảnh 12/10',
  VoidCallback? onProfile,
  VoidCallback? onBook,
  String? bookLabel = 'Đặt T7',
  String name = 'Minh Trí',
  int? price = 1500000,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  List<PhotoRequest>? log,
}) => hostWidget(
  testPhotoScope(
    log: log,
    child: PhotographerCard(
      data: fixturePhotographer('p1', name: name, verified: verified, startingPrice: price),
      reasons: reasons,
      distanceKm: distanceKm,
      availabilityLabel: availability,
      onProfile: onProfile ?? () {},
      onBook: onBook,
      bookLabel: bookLabel,
    ),
  ),
  width: width,
  textScale: textScale,
  brightness: brightness,
);

void main() {
  testWidgets('shows name, meta line, price and availability', (tester) async {
    await tester.pumpWidget(_card());
    expect(find.textContaining('Minh Trí', findRichText: true), findsOneWidget);
    expect(find.text('Chân dung · 1,2 km · ★ 4,9 · 112 buổi'), findsOneWidget);
    expect(find.text('1,5M'), findsOneWidget);
    expect(find.text('từ'), findsOneWidget);
    expect(find.text('Rảnh 12/10'), findsOneWidget);
  });

  testWidgets('the verified tick only appears for verified photographers', (
    tester,
  ) async {
    await tester.pumpWidget(_card(verified: true));
    expect(find.byType(VerifiedMark), findsOneWidget);
    await tester.pumpWidget(_card(verified: false));
    expect(find.byType(VerifiedMark), findsNothing);
  });

  testWidgets('missing data leaves parts out instead of showing blanks', (
    tester,
  ) async {
    await tester.pumpWidget(_card(distanceKm: null, price: null, availability: null));
    expect(find.text('Chân dung · ★ 4,9 · 112 buổi'), findsOneWidget);
    expect(find.text('—'), findsOneWidget, reason: 'unknown price');
    expect(find.byType(PhotoPill), findsNothing);
  });

  testWidgets('shows at most two reasons', (tester) async {
    await tester.pumpWidget(
      _card(
        reasons: const [
          Reason(code: ReasonCode.skillMatch, text: 'Chuyên chân dung'),
          Reason(code: ReasonCode.near, text: '1,2 km'),
          Reason(code: ReasonCode.freeOnDate, text: 'Rảnh T7'),
        ],
      ),
    );
    expect(find.text('Chuyên chân dung'), findsOneWidget);
    expect(find.text('Rảnh T7'), findsNothing);
  });

  testWidgets('profile and book buttons call their handlers; book is optional', (
    tester,
  ) async {
    var profile = 0, book = 0;
    await tester.pumpWidget(_card(onProfile: () => profile++, onBook: () => book++));
    await tester.tap(find.byKey(const Key('card-profile-p1')));
    await tester.tap(find.byKey(const Key('card-book-p1')));
    expect((profile, book), (1, 1));
    expect(find.text('Đặt T7'), findsOneWidget);

    await tester.pumpWidget(_card());
    expect(find.byKey(const Key('card-book-p1')), findsNothing);
  });

  testWidgets('tapping the hero or the name row opens the profile', (tester) async {
    var profile = 0;
    await tester.pumpWidget(_card(onProfile: () => profile++));
    await tester.tap(find.byKey(const ValueKey('photo:https://img.test/avatar-p1.jpg')).first);
    expect(profile, 1);
  });

  testWidgets('the hero is decoded at card width', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(_card(log: log, width: 300));
    expect(log.any((r) => r.cacheWidth == 600 && r.retry), isTrue, reason: 'hero: 300 dp x 2');
  });

  testWidgets('has no BackdropFilter', (tester) async {
    await tester.pumpWidget(_card(reasons: const [Reason(code: ReasonCode.near, text: 'x')]));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x on ${b.name}; buttons stack and stay 52dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          name: 'Nguyễn Thị Phương Anh Nhiếp Ảnh Gia',
          onBook: () {},
          bookLabel: 'Đặt T7 12/10',
          reasons: const [Reason(code: ReasonCode.skillMatch, text: 'Chuyên sâu chân dung')],
          width: 320,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
      final profile = tester.getRect(find.byKey(const Key('card-profile-p1')));
      final book = tester.getRect(find.byKey(const Key('card-book-p1')));
      expect(profile.height, 52);
      expect(book.height, 52);
      expect(book.top, greaterThan(profile.bottom - 1), reason: 'stacked under large text');
    });
  }

  testWidgets('side by side at normal text size', (tester) async {
    await tester.pumpWidget(_card(onBook: () {}));
    final profile = tester.getRect(find.byKey(const Key('card-profile-p1')));
    final book = tester.getRect(find.byKey(const Key('card-book-p1')));
    expect(book.top, profile.top);
    expect(book.left, greaterThan(profile.right));
  });
}
```

The tap test finds the first photo with the avatar url, which is the avatar in the header row (the hero uses `heroUrl`, which falls back to the same avatar url here, so `.first` is the hero); both are inside the tappable area.

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/photographer_card_test.dart`
Expected: FAIL, `PhotographerCard` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "photographerSessions": "{n} buổi",
  "@photographerSessions": {
    "placeholders": {
      "n": {"type": "int"}
    }
  },
  "priceFrom": "từ",
  "photographerCardProfile": "Hồ sơ",
  "photographerCardBook": "Đặt lịch"
```

```dart
// lib/core/widgets/photographer_card.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/network_photo.dart';
import 'package:photobooking/core/widgets/photo_card.dart';
import 'package:photobooking/core/widgets/reason_chips.dart';
import 'package:photobooking/core/widgets/verified_mark.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/reason.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// A photographer to compare (S01 "Rảnh tuần này" long form, S04): hero photo,
/// name with the verified tick, meta, price from, why recommended, and two
/// actions. No blur: a list of these must stay cheap.
class PhotographerCard extends StatelessWidget {
  const PhotographerCard({
    super.key,
    required this.data,
    this.reasons = const [],
    this.distanceKm,
    this.availabilityLabel,
    required this.onProfile,
    this.onBook,
    this.bookLabel,
  });

  final PhotographerSummary data;
  final List<Reason> reasons;
  final double? distanceKm;

  /// Text of the green pill on the hero, for example "Rảnh 12/10".
  final String? availabilityLabel;
  final VoidCallback onProfile;
  final VoidCallback? onBook;

  /// Label of the second button; defaults to "Đặt lịch".
  final String? bookLabel;

  String _meta(BuildContext context) {
    final l = context.l10n;
    return [
      if (data.specialtyIds.isNotEmpty) specialtyLabel(data.specialtyIds.first),
      if (distanceKm != null) formatDistance(distanceKm!),
      if (data.hasRating) '★ ${formatRating(data.ratingAvg)}',
      if (data.completedCount > 0) l.photographerSessions(data.completedCount),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final stack = MediaQuery.textScalerOf(context).scale(16) > 18.4;
    final hero = data.heroUrl;

    final profileButton = AppButton.outline(
      l.photographerCardProfile,
      key: Key('card-profile-${data.id}'),
      onPressed: onProfile,
    );
    final bookButton = onBook == null
        ? null
        : AppButton.outline(
            bookLabel ?? l.photographerCardBook,
            key: Key('card-book-${data.id}'),
            onPressed: onBook,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              backgroundColor: scheme.secondary,
              side: BorderSide(color: scheme.primary),
            ),
          );

    return Material(
      color: scheme.secondary,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg + 8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hero != null)
                        NetworkPhoto(url: hero)
                      else
                        ColoredBox(color: scheme.secondary),
                      if (availabilityLabel != null)
                        Positioned(
                          left: AppSpace.s2,
                          top: AppSpace.s2,
                          child: PhotoPill(label: availabilityLabel!, dot: true),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.s3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAvatar(url: data.avatarUrl, name: data.displayName),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            data.verified
                                ? VerifiedName(
                                    data.displayName,
                                    style: theme.textTheme.titleMedium,
                                  )
                                : Text(
                                    data.displayName,
                                    style: theme.textTheme.titleMedium,
                                  ),
                            if (_meta(context).isNotEmpty)
                              Text(_meta(context), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            data.startingPriceVnd == null
                                ? '—'
                                : formatMoney(data.startingPriceVnd!, short: true),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            l.priceFrom,
                            style: TextStyle(fontSize: 10.5, color: secondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s3,
                0,
                AppSpace.s3,
                AppSpace.s3,
              ),
              child: ReasonChips(reasons: reasons),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s3,
              0,
              AppSpace.s3,
              AppSpace.s3,
            ),
            child: stack || bookButton == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      profileButton,
                      if (bookButton != null) ...[
                        const SizedBox(height: AppSpace.s2),
                        bookButton,
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: profileButton),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(child: bookButton),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/core/widgets/photographer_card_test.dart && flutter analyze && flutter test`
Expected: PASS (11 tests); analyze clean; whole suite green. The name is found with `textContaining(..., findRichText: true)` because `VerifiedName` is a `Text.rich` whose plain text ends with a placeholder character.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets/photographer_card_test.dart
git commit -m "feat(core): PhotographerCard

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/feed_cards_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: every widget of this plan, `testPhotoScope`, `expectIdle`, `expectBlurBudget`.
- Produces: no production code.

What is checked: nothing animates at rest; a feed of ten cards adds no blur; every photo is requested at display size; the production image widget has no retry timer and does not decode originals; lists of cards in this plan's callers will be lazy (3b4).

- [ ] **Step 1: Write the tests**

Create `test/support/idle.dart` and `test/support/blur.dart` if they are missing, with exactly the code given in plan 3a1 Task 7 (`expectIdle`, `expectBlurBudget`).

```dart
// test/battery/feed_cards_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/reason.dart';

import '../core/widgets/widget_host.dart';
import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/idle.dart';
import '../support/photo_scope.dart';

Widget _feed(List<PhotoRequest> log) => hostWidget(
  testPhotoScope(
    log: log,
    child: SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < 5; i++)
            SizedBox(
              width: 300,
              child: PhotoCard(
                imageUrl: 'https://img.test/post$i.jpg',
                aspect: 4 / 5,
                title: 'Minh Trí',
                subtitle: 'Quận 3',
                leadingPill: const PhotoPill(label: 'Rảnh T7 này', dot: true),
                action: const Icon(Icons.bookmark_border),
                onTap: () {},
              ),
            ),
          for (var i = 0; i < 5; i++)
            PhotographerCard(
              data: fixturePhotographer('p$i', verified: i.isEven),
              reasons: const [Reason(code: ReasonCode.near, text: '1,2 km')],
              distanceKm: 1.2,
              availabilityLabel: 'Rảnh 12/10',
              onProfile: () {},
              onBook: () {},
            ),
          const AppAvatar(name: 'Minh Trí', url: 'https://img.test/a.jpg'),
        ],
      ),
    ),
  ),
  width: 390,
);

void main() {
  testWidgets('a settled feed of cards keeps no frame scheduled and adds no blur', (
    tester,
  ) async {
    await tester.pumpWidget(_feed([]));
    await expectIdle(tester);
    expectBlurBudget(max: 0);
  });

  testWidgets('every photo is requested with a decode width, and avatars never retry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(_feed(log));
    expect(log, isNotEmpty);
    for (final r in log) {
      expect(r.cacheWidth, isNotNull, reason: r.url);
      expect(r.cacheWidth! % 50, 0, reason: 'rounded to 50 px buckets');
    }
    final avatar = log.firstWhere((r) => r.url == 'https://img.test/a.jpg');
    expect(avatar.retry, isFalse);
    expect(avatar.cacheWidth, lessThanOrEqualTo(200), reason: '48 dp x 3 = 144 px, never the original');
  });

  group('the production image widget', () {
    final src = File('lib/core/widgets/network_photo.dart').readAsStringSync();

    test('decodes at display size and caches on disk', () {
      expect(src, contains('memCacheWidth: widget.cacheWidth'));
      expect(src, contains('CachedNetworkImage('));
      expect(src, isNot(contains('Image.network')));
      expect(src, isNot(contains('NetworkImage(')));
    });

    test('has no retry loop, timer or ticker of its own', () {
      for (final banned in ['Timer', 'Ticker', 'AnimationController', 'Stream.periodic']) {
        expect(src, isNot(contains(banned)), reason: banned);
      }
      // The only animation is the 150 ms fade-in, which ends by itself.
      expect(src, contains('fadeInDuration: const Duration(milliseconds: 150)'));
    });
  });

  test('no card widget uses BackdropFilter or a repeating animation', () {
    for (final name in [
      'app_avatar.dart',
      'reason_chips.dart',
      'photo_card.dart',
      'photographer_card.dart',
      'network_photo.dart',
    ]) {
      final s = File('lib/core/widgets/$name').readAsStringSync();
      expect(s, isNot(contains('BackdropFilter')), reason: name);
      expect(s, isNot(contains('AnimationController')), reason: name);
      expect(s, isNot(contains('.repeat(')), reason: name);
    }
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/feed_cards_battery_test.dart`
Expected: PASS (5 tests). A failure names the culprit; fix the widget, not the test.

- [ ] **Step 3: Fix anything the run found**

For example a decode width of `null` means a card puts `NetworkPhoto` in an unbounded-width parent; give it a bounded width. Re-run Step 2.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it) once plan 3b4 puts the cards on Home and Find: (1) scroll a 100-post feed fast on a mid-range device and read raster time and the image cache size in DevTools Memory (no growth after 100 cards beyond the cache limit); (2) leave Home idle for 5 minutes; (3) turn the network off and check that failed photos show the retry tile and do not retry on their own.

- Android: mid-range device, `flutter run --profile`, DevTools Performance and Memory, `adb shell dumpsys batterystats`.
- iOS: Xcode Instruments (Time Profiler, Allocations and Energy Log) on a real iPhone, or the Simulator's Debug Navigator CPU and Memory gauges; Energy Impact must read "Low" at rest. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
git add test/support test/battery
git commit -m "test: idle, blur and image-size checks for the feed cards

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** `PhotoCard` (aspect 4:5 / 3:4, pills left and right, bottom overlay, no border or shadow, `cached_network_image` with a retry affordance; blurhash accepted but placeholder is flat until a later step), `PhotographerCard` (hero 16:9 + pill, avatar, name + `VerifiedMark`, meta, price from, `ReasonChips` max 2, "Hồ sơ" + "Đặt {ngày}" buttons, stacked under large text), `ReasonChips` (max 2, one line, "Gợi ý vì: …" semantics), `AppAvatar` (xs 32 … xl 96, 2dp ring, initials fallback), `VerifiedMark` use per §3d.1; mock details (S01 meta line, S04 card) reproduced.
- **Deviations (flagged):** (1) blurhash decoding is not implemented; `blurHash` is carried through the models and `PhotoCard` for the later enhancement (needs a decoder package). (2) the glass button of the spec ("kính") is an outline button with the primary colour and a translucent fill, because `AppButton` has no glass variant and blur is not allowed on list items. (3) `PhotoCard` text shrinks below 200dp and wraps to two lines with an ellipsis; the spec's "không ellipsis cho nội dung chính" is kept for names in `PhotographerCard` (no ellipsis there).
- **Placeholders:** none. **Type consistency:** `NetworkPhoto(url, fit, semanticLabel, retry)`, `PhotoImageScope`/`PhotoImageBuilder`, `testPhotoScope`/`PhotoRequest`, `AppAvatar(url, name, size, badge)`, `avatarInitial`, `formatDay/formatDayMonth/weekdayLabel/formatRating`, `ReasonChips(reasons, max)`, `PhotoCard(...)`/`PhotoPill(label, dot)`, `PhotographerCard(data, reasons, distanceKm, availabilityLabel, onProfile, onBook, bookLabel)` and the keys `card-profile-<id>`, `card-book-<id>` are the names plan 3b4 uses.
- **Battery and performance (Task 7):** idle test for the card feed, blur budget 0 for cards, decode width on every image and no original-size decode, no timers or tickers in the image widget, manual Android and iOS profiling table per `docs/testing/battery-and-performance.md`.
- **Risks:** `cached_network_image` is not exercised by widget tests (they use the scope); its production builder is covered by source checks and the manual profiling step only. Rows of cards use plain `Row`/`Column` (not `IntrinsicHeight`) because `LayoutBuilder` inside `NetworkPhoto` does not support intrinsic sizing.
