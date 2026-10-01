# Core Display Widgets (Build step 1, part A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the small, dependency-free display widgets that several screens share: `VerifiedMark` (+ `VerifiedName`), `FreeTag` / `FreeBanner`, `StatTile` (+ `StatTileRow`), `CapacityBar`, `StepProgress`.

**Architecture:** Plain `StatelessWidget`s in `lib/core/widgets/`, themed only through `Theme`, `AppColors`/`AppColorsDark`, `AppSpace` and `ctaGradientFor`. Text comes from `app_vi.arb`. Each widget has a widget test that also covers dark and light themes, a 320dp width and a 1.3x system text scale where layout can break.

**Tech Stack:** Flutter, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/components/shared-components.md` (entries VerifiedMark, FreeTag/FreeBanner, StatTile, CapacityBar, StepProgress) and `docs/superpowers/specs/2026-10-01-remaining-screens.md` sections 3d.1, 4 and 7.

**Follows:** `docs/superpowers/plans/2026-10-01-screen-codes.md` (independent; the two can run in either order, but both edit `core.dart` and `app_vi.arb`, so run them one after the other).

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Imports are `package:photobooking/...` only; files inside `core/` import each other directly; features import `core/core.dart`.
- No hard-coded UI text; Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`.
- No raw hex or magic numbers in widgets except values the spec fixes (sizes such as 6dp bar height, 10.5 label). Colours come from `AppColors` / `AppColorsDark` / `Theme`.
- Secondary text is `AppColorsDark.foregroundSecondary` on dark and `AppColors.foregroundSecondary` on light (contrast at least 4.5:1). `ColorScheme.onSurfaceVariant` is not set by our theme, so do not use it.
- Meaning never rests on colour alone: every widget carries text or a `Semantics` label.
- Free events show the tag "Không thu phí", never "0₫".
- Verified is a small blue check (`ctaStart`, `#3D63FF`), no text, raised slightly above the name's baseline; it is only for `photographers.verified` and is not used for badges.
- Sibling boxes in one `Row` share a height via `IntrinsicHeight` + `Expanded`; labels do not wrap at 1.3x text scale (`FittedBox(scaleDown)`).
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/core/widgets/verified_mark.dart` | `VerifiedMark`, `VerifiedName` |
| `lib/core/widgets/free_tag.dart` | `FreeTag`, `FreeBanner` |
| `lib/core/widgets/stat_tile.dart` | `StatTile`, `StatTileRow` |
| `lib/core/widgets/capacity_bar.dart` | `CapacityBar` |
| `lib/core/widgets/step_progress.dart` | `StepProgress` |
| `lib/core/core.dart` | export the five files |
| `lib/l10n/app_vi.arb` | new strings (listed per task) |
| `test/core/widgets/*_test.dart` | one test file per widget |
| `test/core/widgets/widget_host.dart` | shared test harness (Task 1) |

---

### Task 1: Test harness and `VerifiedMark` / `VerifiedName`

**Files:**
- Create: `test/core/widgets/widget_host.dart`, `lib/core/widgets/verified_mark.dart`, `test/core/widgets/verified_mark_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Produces (test helper):
  `Widget hostWidget(Widget child, {Brightness brightness = Brightness.dark, double width = 390, double textScale = 1.0})` — a `MaterialApp` with the app theme, Vietnamese locale and localisations, a `Scaffold`, the child inside a `SizedBox(width: width)` aligned top-left, and `MediaQuery` text scaler.
- Produces (widgets):
  `const VerifiedMark({super.key, double size = 14})`;
  `const VerifiedName(String name, {super.key, TextStyle? style})` — name followed by a raised mark, as one `Text.rich`.
- Produces (l10n): `verifiedLabel` = "Đã xác minh".

- [ ] **Step 1: Write the harness and the failing test**

```dart
// test/core/widgets/widget_host.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Hosts [child] the way the app does: app theme, Vietnamese strings, and a
/// fixed logical width so layout limits can be tested (320 = narrowest phone).
Widget hostWidget(
  Widget child, {
  Brightness brightness = Brightness.dark,
  double width = 390,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: c!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        // Loose inside the fixed width, so small widgets keep their own size.
        child: SizedBox(
          width: width,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}
```

```dart
// test/core/widgets/verified_mark_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('mark is a small blue disc with an accessible name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const VerifiedMark()));
    expect(find.bySemanticsLabel('Đã xác minh'), findsOneWidget);
    final disc = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(VerifiedMark),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((disc.decoration as BoxDecoration).color, AppColors.ctaStart);
    expect(tester.getSize(find.byType(VerifiedMark)), const Size(14, 14));
    handle.dispose();
  });

  testWidgets('long press shows the tooltip', (tester) async {
    await tester.pumpWidget(hostWidget(const VerifiedMark()));
    await tester.longPress(find.byType(VerifiedMark));
    await tester.pumpAndSettle();
    expect(find.text('Đã xác minh'), findsOneWidget);
  });

  testWidgets('beside a name the mark sits higher than the text centre', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(const VerifiedName('Minh Thư')));
    final mark = tester.getRect(find.byType(VerifiedMark));
    final line = tester.getRect(find.byType(Text).first);
    expect(mark.center.dy, lessThan(line.center.dy));
    expect(mark.left, greaterThan(line.left));
  });

  testWidgets('name plus mark wrap instead of overflowing at 320dp, 1.3x', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const VerifiedName('Nguyễn Thị Phương Anh Nhiếp Ảnh Gia Chân Dung'),
        width: 120,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/verified_mark_test.dart`
Expected: FAIL, `VerifiedMark` / `VerifiedName` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`: `"verifiedLabel": "Đã xác minh",` then run `flutter gen-l10n`.

```dart
// lib/core/widgets/verified_mark.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Verified photographer: a small blue disc with a white check, no text.
/// Not used for badges (those are purple); see spec 3d.1.
class VerifiedMark extends StatelessWidget {
  const VerifiedMark({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.verifiedLabel;
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.ctaStart,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: size * 0.72,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A name followed by [VerifiedMark], raised about 3dp above the baseline so
/// it reads as a superscript to the name rather than sitting mid-line.
class VerifiedName extends StatelessWidget {
  const VerifiedName(this.name, {super.key, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: name,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.aboveBaseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Transform.translate(
                offset: const Offset(0, -3),
                child: const VerifiedMark(),
              ),
            ),
          ),
        ],
      ),
      style: style,
    );
  }
}
```

Add `export 'package:photobooking/core/widgets/verified_mark.dart';` to `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/verified_mark_test.dart && flutter analyze`
Expected: PASS, 4 tests; analyze clean. If the "sits higher" assertion fails by a pixel, increase the translate offset in `VerifiedName` (it must stay at least 3dp), not the test.

- [ ] **Step 5: Commit**

```bash
git add test/core/widgets lib/core lib/l10n
git commit -m "feat(core): VerifiedMark and VerifiedName

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `FreeTag` and `FreeBanner`

**Files:**
- Create: `lib/core/widgets/free_tag.dart`, `test/core/widgets/free_tag_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `hostWidget` (Task 1).
- Produces: `const FreeTag({super.key})`; `const FreeBanner({super.key, String? body})`; l10n `freeTag` = "Không thu phí", `freeBannerBody` = "Đăng ký để giữ chỗ, không cần thanh toán".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/free_tag_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('tag says "Không thu phí" and never "0₫"', (tester) async {
    await tester.pumpWidget(hostWidget(const FreeTag()));
    expect(find.text('Không thu phí'), findsOneWidget);
    expect(find.textContaining('0₫'), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('tag text keeps 4.5:1 contrast on ${b.name}', (tester) async {
      await tester.pumpWidget(hostWidget(const FreeTag(), brightness: b));
      final fill =
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(FreeTag),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      final page = b == Brightness.dark
          ? AppColorsDark.background
          : AppColors.background;
      final text = tester.widget<Text>(find.text('Không thu phí')).style!.color!;
      expect(_contrast(text, Color.alphaBlend(fill, page)), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('banner shows title and the default hint', (tester) async {
    await tester.pumpWidget(hostWidget(const FreeBanner(), width: 320, textScale: 1.3));
    expect(find.text('Không thu phí'), findsOneWidget);
    expect(find.text('Đăng ký để giữ chỗ, không cần thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner accepts a custom hint', (tester) async {
    await tester.pumpWidget(hostWidget(const FreeBanner(body: 'Vào cửa tự do')));
    expect(find.text('Vào cửa tự do'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/free_tag_test.dart`
Expected: FAIL, `FreeTag` undefined.

- [ ] **Step 3: Implement**

Add to `app_vi.arb`: `"freeTag": "Không thu phí",` and `"freeBannerBody": "Đăng ký để giữ chỗ, không cần thanh toán",`; run `flutter gen-l10n`.

```dart
// lib/core/widgets/free_tag.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

({Color fill, Color text}) _freeColors(Brightness b) => b == Brightness.dark
    ? (
        // Green at 20% over the dark canvas, with a lightened green for text.
        fill: AppColors.success.withValues(alpha: 0.2),
        text: Color.alphaBlend(
          Colors.white.withValues(alpha: 0.45),
          AppColors.success,
        ),
      )
    : (
        fill: AppColors.successSubtle,
        // Success green darkened until it reads at 4.5:1 on the pale fill.
        text: Color.alphaBlend(
          Colors.black.withValues(alpha: 0.45),
          AppColors.success,
        ),
      );

/// Where a free event would show "0₫" it shows this tag instead.
class FreeTag extends StatelessWidget {
  const FreeTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _freeColors(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          context.l10n.freeTag,
          style: TextStyle(
            fontSize: AppText.sm,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
      ),
    );
  }
}

/// Full-width strip under an event cover (S16) for events with `price == 0`.
class FreeBanner extends StatelessWidget {
  const FreeBanner({super.key, this.body});

  /// Second line; defaults to the standard "no payment needed" hint.
  final String? body;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _freeColors(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.fill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3,
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: c.text),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.freeTag,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  Text(
                    body ?? l.freeBannerBody,
                    style: TextStyle(fontSize: AppText.sm, color: c.text),
                  ),
                ],
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

Run: `flutter test test/core/widgets/free_tag_test.dart && flutter analyze`
Expected: PASS, 5 tests. If a contrast assertion fails, darken or lighten the `alpha` of the text blend until it passes; do not lower the 4.5 threshold.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets/free_tag_test.dart
git commit -m "feat(core): FreeTag and FreeBanner for free events

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `StatTile` and `StatTileRow`

**Files:**
- Create: `lib/core/widgets/stat_tile.dart`, `test/core/widgets/stat_tile_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `hostWidget`, `GlassCard` (`highlight: false`), `AppFonts.display`.
- Produces: `const StatTile({super.key, required String value, required String label})`; `const StatTileRow({super.key, required List<StatTile> tiles})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/stat_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _tiles = [
  StatTile(value: '12,4M', label: 'Đang giữ'),
  StatTile(value: '3,2M', label: 'Sắp nhận'),
  StatTile(value: '5', label: 'Đã nhận trong tháng'),
];

void main() {
  testWidgets('three tiles share one row and one height at 320dp, 1.3x', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const StatTileRow(tiles: _tiles), width: 320, textScale: 1.3),
    );
    expect(tester.takeException(), isNull);
    final rects = [
      for (final t in _tiles)
        tester.getRect(find.widgetWithText(StatTile, t.label)),
    ];
    expect(rects.map((r) => r.top).toSet().length, 1, reason: 'same row');
    expect(rects.map((r) => r.height).toSet().length, 1, reason: 'same height');
  });

  testWidgets('a long label scales down to one line instead of wrapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const StatTileRow(tiles: _tiles), width: 320, textScale: 1.3),
    );
    final label = tester.getSize(find.text('Đã nhận trong tháng'));
    final short = tester.getSize(find.text('Đang giữ'));
    expect(label.height, closeTo(short.height, 1));
  });

  testWidgets('the number uses tabular figures', (tester) async {
    await tester.pumpWidget(hostWidget(const StatTile(value: '12,4M', label: 'x')));
    final style = tester.widget<Text>(find.text('12,4M')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontFamily, AppFonts.display);
  });

  testWidgets('screen readers read value then label as one item', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const StatTile(value: '5', label: 'Đã nhận')));
    expect(find.bySemanticsLabel('5, Đã nhận'), findsOneWidget);
    handle.dispose();
  });
}
```

(`FontFeature` needs `import 'dart:ui';` — add it at the top of the test file.)

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/stat_tile_test.dart`
Expected: FAIL, `StatTile` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/stat_tile.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/glass_card.dart';

/// A big number over a one-line label. Put two or three in a [StatTileRow].
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Semantics(
      label: '$value, $label',
      child: ExcludeSemantics(
        child: GlassCard(
          highlight: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s2,
              vertical: AppSpace.s3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(fontSize: 10.5, color: secondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiles side by side, equal width and equal height.
class StatTileRow extends StatelessWidget {
  const StatTileRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s2),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/stat_tile_test.dart && flutter analyze`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/widgets/stat_tile_test.dart
git commit -m "feat(core): StatTile and StatTileRow

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `CapacityBar`

**Files:**
- Create: `lib/core/widgets/capacity_bar.dart`, `test/core/widgets/capacity_bar_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `hostWidget`, `ctaGradientFor(Brightness)` from `cta_surface.dart`.
- Produces: `const CapacityBar({super.key, required int used, required int total, String? label})`; l10n `capacityUsed(used, total)` = "{used} / {total} đã đăng ký". `label` replaces the default text (badge progress uses "3 / 5").

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/capacity_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

double _fillFraction(WidgetTester tester) {
  final bar = tester.getSize(find.byKey(const Key('capacity-track'))).width;
  final fill = tester.getSize(find.byKey(const Key('capacity-fill'))).width;
  return fill / bar;
}

void main() {
  testWidgets('shows the text next to the bar', (tester) async {
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 14, total: 20)));
    expect(find.text('14 / 20 đã đăng ký'), findsOneWidget);
    expect(_fillFraction(tester), closeTo(0.7, 0.001));
  });

  testWidgets('a custom label replaces the default text', (tester) async {
    await tester.pumpWidget(
      hostWidget(const CapacityBar(used: 3, total: 5, label: '3 / 5')),
    );
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.textContaining('đã đăng ký'), findsNothing);
  });

  testWidgets('over-full and empty totals stay inside the track', (tester) async {
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 25, total: 20)));
    expect(_fillFraction(tester), 1.0);
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 0, total: 0)));
    expect(find.byKey(const Key('capacity-fill')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the value is available to screen readers as text', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 14, total: 20)));
    expect(find.bySemanticsLabel('14 / 20 đã đăng ký'), findsOneWidget);
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/capacity_bar_test.dart`
Expected: FAIL, `CapacityBar` undefined.

- [ ] **Step 3: Implement**

Add to `app_vi.arb`:

```json
  "capacityUsed": "{used} / {total} đã đăng ký",
  "@capacityUsed": {
    "placeholders": {
      "used": {"type": "int"},
      "total": {"type": "int"}
    }
  },
```

Run `flutter gen-l10n`.

```dart
// lib/core/widgets/capacity_bar.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// Filled share of a limited resource (event seats, badge progress), always
/// with text so the meaning does not rest on the bar alone.
class CapacityBar extends StatelessWidget {
  const CapacityBar({
    super.key,
    required this.used,
    required this.total,
    this.label,
  });

  final int used;
  final int total;

  /// Replaces "{used} / {total} đã đăng ký".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = label ?? context.l10n.capacityUsed(used, total);
    final fraction = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                key: const Key('capacity-track'),
                height: 6,
                width: double.infinity,
                child: ColoredBox(
                  color: theme.colorScheme.secondary,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: fraction == 0
                        ? null
                        : FractionallySizedBox(
                            widthFactor: fraction,
                            child: DecoratedBox(
                              key: const Key('capacity-fill'),
                              decoration: BoxDecoration(
                                gradient: ctaGradientFor(theme.brightness),
                              ),
                              child: const SizedBox(height: 6),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            Text(text, style: const TextStyle(fontSize: AppText.sm)),
          ],
        ),
      ),
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/capacity_bar_test.dart && flutter analyze`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets/capacity_bar_test.dart
git commit -m "feat(core): CapacityBar

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `StepProgress`

**Files:**
- Create: `lib/core/widgets/step_progress.dart`, `test/core/widgets/step_progress_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `hostWidget`, `ctaGradientFor`.
- Produces: `const StepProgress({super.key, required int current, required int total, String? label})`; l10n `stepProgressCount(current, total)` = "{current} / {total}", `stepProgressSemantics(current, total)` = "Bước {current} trên {total}".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/step_progress_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

int _filled(WidgetTester tester) => find
    .byKey(const Key('step-filled'))
    .evaluate()
    .length;

void main() {
  testWidgets('fills the segments up to the current step', (tester) async {
    await tester.pumpWidget(hostWidget(const StepProgress(current: 2, total: 4)));
    expect(find.byKey(const Key('step-segment')), findsNWidgets(4));
    expect(_filled(tester), 2);
    expect(find.text('2 / 4'), findsOneWidget);
  });

  testWidgets('an optional label is shown with the count', (tester) async {
    await tester.pumpWidget(
      hostWidget(const StepProgress(current: 1, total: 3, label: 'Gói')),
    );
    expect(find.text('Gói'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('out-of-range values are clamped', (tester) async {
    await tester.pumpWidget(hostWidget(const StepProgress(current: 9, total: 4)));
    expect(_filled(tester), 4);
    await tester.pumpWidget(hostWidget(const StepProgress(current: -1, total: 4)));
    expect(_filled(tester), 0);
  });

  testWidgets('screen readers hear the step in words', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const StepProgress(current: 2, total: 4)));
    expect(find.bySemanticsLabel('Bước 2 trên 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const StepProgress(current: 3, total: 4, label: 'Xem lại và đặt cọc'),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/step_progress_test.dart`
Expected: FAIL, `StepProgress` undefined.

- [ ] **Step 3: Implement**

Add to `app_vi.arb`:

```json
  "stepProgressCount": "{current} / {total}",
  "@stepProgressCount": {
    "placeholders": {
      "current": {"type": "int"},
      "total": {"type": "int"}
    }
  },
  "stepProgressSemantics": "Bước {current} trên {total}",
  "@stepProgressSemantics": {
    "placeholders": {
      "current": {"type": "int"},
      "total": {"type": "int"}
    }
  },
```

Run `flutter gen-l10n`.

```dart
// lib/core/widgets/step_progress.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// "n / N" with one bar segment per step; segments up to [current] are filled
/// with the theme gradient. Used by booking, event creation and profile setup.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.current,
    required this.total,
    this.label,
  });

  final int current;
  final int total;

  /// Name of the current step, shown before the count.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final filled = current.clamp(0, total);
    return Semantics(
      label: l.stepProgressSemantics(filled, total),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  l.stepProgressCount(filled, total),
                  style: const TextStyle(
                    fontSize: AppText.sm,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.s1),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: SizedBox(
                        key: const Key('step-segment'),
                        height: 4,
                        child: i < filled
                            ? DecoratedBox(
                                key: const Key('step-filled'),
                                decoration: BoxDecoration(
                                  gradient: ctaGradientFor(theme.brightness),
                                ),
                              )
                            : ColoredBox(color: theme.colorScheme.secondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Add `import 'dart:ui' show FontFeature;` at the top of the file. Export from `core.dart`.

- [ ] **Step 4: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets/step_progress_test.dart
git commit -m "feat(core): StepProgress

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Battery and performance check

**Files:**
- Create: `test/core/widgets/display_widgets_idle_test.dart`; `test/support/idle.dart` if it does not exist yet (the screen-codes plan creates it)
- Modify: `lib/core/widgets/stat_tile.dart`

**Interfaces:**
- Consumes: `expectIdle` (code below), `hostWidget`, the five widgets of Tasks 1–5.
- Changes: `StatTile` no longer uses `GlassCard` (which has a `BackdropFilter`). Three tiles in a row would add three blur passes, and tiles usually sit inside a card that is already blurred. The tile gets a translucent fill and hairline instead; its public API is unchanged.

- [ ] **Step 1: Write the failing test**

If `test/support/idle.dart` is missing, create it:

```dart
// test/support/idle.dart
import 'package:flutter_test/flutter_test.dart';

/// Fails when something keeps scheduling frames at rest (a running
/// animation, ticker or repeating timer drains battery).
Future<void> expectIdle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  expect(tester.binding.transientCallbackCount, 0,
      reason: 'an animation or ticker keeps running at rest');
  expect(tester.binding.hasScheduledFrame, isFalse,
      reason: 'a frame is scheduled while nothing changes');
}
```

```dart
// test/core/widgets/display_widgets_idle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

void main() {
  final cases = <String, Widget>{
    'VerifiedName': const VerifiedName('Minh Thư'),
    'FreeTag': const FreeTag(),
    'FreeBanner': const FreeBanner(),
    'StatTileRow': const StatTileRow(
      tiles: [
        StatTile(value: '12,4M', label: 'Đang giữ'),
        StatTile(value: '3,2M', label: 'Sắp nhận'),
        StatTile(value: '5', label: 'Đã nhận'),
      ],
    ),
    'CapacityBar': const CapacityBar(used: 14, total: 20),
    'StepProgress': const StepProgress(current: 2, total: 4),
  };
  for (final MapEntry(:key, :value) in cases.entries) {
    for (final b in Brightness.values) {
      testWidgets('$key is idle at rest (${b.name})', (tester) async {
        await tester.pumpWidget(hostWidget(value, brightness: b));
        await expectIdle(tester);
      });
    }
  }

  testWidgets('a row of stat tiles adds no blur pass', (tester) async {
    await tester.pumpWidget(hostWidget(cases['StatTileRow']!));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a long list of verified names builds lazily', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        SizedBox(
          height: 400,
          child: ListView.builder(
            itemCount: 1000,
            itemBuilder: (_, i) => VerifiedName('Nhiếp ảnh gia $i'),
          ),
        ),
      ),
    );
    expect(find.byType(VerifiedMark).evaluate().length, lessThan(60));
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/display_widgets_idle_test.dart`
Expected: the idle tests PASS (none of the widgets animates); "a row of stat tiles adds no blur pass" FAILS with "Found 3 widgets with type BackdropFilter".

- [ ] **Step 3: Implement**

In `lib/core/widgets/stat_tile.dart` remove the `glass_card.dart` import and replace the `GlassCard(highlight: false, child: Padding(...))` inside `StatTile.build` with:

```dart
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Translucent fill, no blur: tiles sit on cards that already blur.
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s2,
              vertical: AppSpace.s3,
            ),
            child: Column(/* unchanged: value + label */),
          ),
        ),
```

(Keep the `Column` and its children exactly as written in Task 3; only the wrapper changes.) Update the StatTile entry in `docs/superpowers/specs/components/shared-components.md`: "nền kính, viền mảnh" becomes "nền trong mờ `surfaceMuted`, viền mảnh, không mờ nền (ô nằm trong thẻ đã mờ)".

- [ ] **Step 4: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass, including the StatTile tests of Task 3 (same height, same row, one-line label).

- [ ] **Step 5: Manual profiling on a real Android device**

Follow `docs/testing/battery-and-performance.md` for the screens listed below (Genymotion is fine for the frame checks, but battery numbers need a real phone). Record the filled-in result table from that document in the PR description. Any value over a threshold blocks the merge: fix it in this plan's code, add a test that would have caught it, and re-measure.

Screens: there is no screen yet that uses these widgets, so profile a throwaway debug page: temporarily put the six widgets of the test above into the Settings `ListView` on your machine, run the frame and CPU checks (guide steps 1–3), record them, and discard that change (do not commit it). Battery and memory steps are not needed for this plan.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/stat_tile.dart test/core/widgets/display_widgets_idle_test.dart test/support ../docs/superpowers/specs/components/shared-components.md
git commit -m "perf(core): idle guards for display widgets; StatTile without blur

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** `VerifiedMark` (blue disc, label, tooltip, raised by `VerifiedName`), `FreeTag`/`FreeBanner` (text, 4.5:1 both themes, no "0₫"), `StatTile` (Fraunces tabular 22, label 10.5 one line, `IntrinsicHeight` + `Expanded`, 320dp at 1.3x test), `CapacityBar` (6dp gradient bar, text always), `StepProgress` (segments, "n / N", semantics) — each matches `shared-components.md`. `FreeTag` appearing on `EventCard` and `VerifiedName` on the cards happens in the plans that build those cards.
- **Not in this plan (next plans in build order step 1/2):** `AppBottomSheet`, `AppChip`/`SegmentedTabs`, `AppAvatar`, `AppSkeleton`, `ErrorState`/`OfflineBanner`, `SectionHeader` (plan "core layout widgets"); `PhoneField` + phone normalisation, `ContactLauncher`, `ContactDial` (plan "contact"); `BadgeChip`/`BadgeTile` (needs the badge model, plan with step 6); the cards (`PhotoCard`, `PhotographerCard`, `BookingCard`, `EventCard`) after the data models.
- **Placeholders:** none. **Type consistency:** `hostWidget` signature, `VerifiedMark`/`VerifiedName`, `FreeTag`/`FreeBanner(body:)`, `StatTile(value, label)`/`StatTileRow(tiles)`, `CapacityBar(used,total,label)`, `StepProgress(current,total,label)` are used identically in tests and implementations.
- **Test-harness assumption:** finders by `Key` (`capacity-track`, `capacity-fill`, `step-segment`, `step-filled`) are part of each widget's code above; the harness wraps in `Scaffold`, which also provides the `Overlay` the `Tooltip` needs.
- **Battery and performance:** Task 6 adds idle tests (both themes) for every widget, a lazy-list check, and removes the per-tile `BackdropFilter` from `StatTile` (three tiles were three blur passes).
