import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/reason.dart';

import '../../support/content_fixtures.dart';
import 'widget_host.dart';

void main() {
  test('no hue in blocks or sweep (r == g == b): white in dark, light grey in light', () {
    for (final brightness in Brightness.values) {
      final (base, shine) = AppSkeleton.colorsFor(brightness);
      final br = (base.r * 255).round();
      final bg = (base.g * 255).round();
      final bb = (base.b * 255).round();
      expect(br, equals(bg), reason: '$brightness base r==g');
      expect(bg, equals(bb), reason: '$brightness base g==b');

      final sr = (shine.r * 255).round();
      final sg = (shine.g * 255).round();
      final sb = (shine.b * 255).round();
      expect(sr, equals(sg), reason: '$brightness shine r==g');
      expect(sg, equals(sb), reason: '$brightness shine g==b');

      if (brightness == Brightness.dark) {
        // Dark: white base 8%, white shine 14%
        expect(br, 255);
        expect(sr, 255);
      } else {
        // Light: light grey base #E2E2E2, white shine 85%
        expect(br, 226);
        expect(sr, 255);
      }
    }
  });

  testWidgets('box, line and card have the requested sizes', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        Column(
          children: [
            AppSkeleton.box(key: const Key('box'), width: 80, height: 40),
            AppSkeleton.line(key: const Key('line'), width: 120),
            AppSkeleton.card(key: const Key('card'), height: 90),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('box'))), const Size(80, 40));
    expect(tester.getSize(find.byKey(const Key('line'))), const Size(120, 12));
    expect(tester.getSize(find.byKey(const Key('card'))).height, 90);
  });

  testWidgets('the sweep is one controller for many blocks under a scope', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AppSkeletonScope(
          child: Column(
            children: [
              AppSkeleton.box(width: 40, height: 20),
              AppSkeleton.line(width: 80),
              AppSkeleton.card(height: 60),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byType(AppSkeletonScope), findsOneWidget);
  });

  testWidgets('reduced motion: still blocks, no ticker', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: AppSkeletonScope(
              child: Column(
                children: [
                  AppSkeleton.box(height: 20, width: 20),
                  AppSkeleton.line(width: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a group reads "Đang tải" once and hides block semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AppSkeleton.group(
          child: Column(
            children: [
              AppSkeleton.box(width: 40, height: 20),
              AppSkeleton.line(width: 80),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);
    handle.dispose();
  });

  group('data widgets skeleton size parity at 390 and 320 dp', () {
    for (final width in [390.0, 320.0]) {
      testWidgets('PhotoCard matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            PhotoCard(
              key: realKey,
              imageUrl: '',
              aspect: 4 / 5,
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            PhotoCard.skeleton(
              key: skelKey,
              aspect: 4 / 5,
            ),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });

      testWidgets('PhotographerCard matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            PhotographerCard(
              key: realKey,
              data: fixturePhotographer('p1'),
              onProfile: () {},
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            PhotographerCard.skeleton(key: skelKey),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });

      testWidgets('StatTile matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            StatTile(
              key: realKey,
              value: '12',
              label: 'Bài viết',
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            StatTile.skeleton(key: skelKey),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });

      testWidgets('AppAvatar matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            AppAvatar(
              key: realKey,
              name: 'Minh',
              size: AppAvatarSize.md,
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            AppAvatar.skeleton(key: skelKey, size: AppAvatarSize.md),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });

      testWidgets('ReasonChips matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            ReasonChips(
              key: realKey,
              reasons: const [
                Reason(code: ReasonCode.skillMatch, text: 'Chuyên chân dung'),
                Reason(code: ReasonCode.near, text: '1,2 km'),
              ],
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            ReasonChips.skeleton(key: skelKey, count: 2),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize.height, equals(realSize.height));
      });

      testWidgets('AvailabilityCalendar matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            AvailabilityCalendar(
              key: realKey,
              month: DateTime.utc(2026, 10),
              states: const {},
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            AvailabilityCalendar.skeleton(key: skelKey),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });

      testWidgets('CapacityBar matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            CapacityBar(
              key: realKey,
              used: 5,
              total: 10,
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            CapacityBar.skeleton(key: skelKey),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });

      testWidgets('CompletenessMeter matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            CompletenessMeter(
              key: realKey,
              percent: 72,
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            CompletenessMeter.skeleton(key: skelKey),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });

      testWidgets('AppOptionTile matches skeleton at $width dp', (tester) async {
        final realKey = UniqueKey();
        final skelKey = UniqueKey();

        await tester.pumpWidget(
          hostWidget(
            AppOptionTile(
              key: realKey,
              label: 'Lựa chọn',
              selected: false,
              onTap: () {},
            ),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byKey(realKey));

        await tester.pumpWidget(
          hostWidget(
            AppOptionTile.skeleton(key: skelKey),
            width: width,
          ),
        );
        final skelSize = tester.getSize(find.byKey(skelKey));
        expect(skelSize, equals(realSize));
      });
    }
  });
}
