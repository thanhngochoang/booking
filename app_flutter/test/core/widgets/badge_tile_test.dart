import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

const _earnedBadge = BadgeView(
  code: 'top_rated',
  name: 'Đánh giá cao',
  condition: 'Đạt điểm trung bình 4.9 sao',
  earned: true,
);

const _notEarnedBadge = BadgeView(
  code: 'shoots_10',
  name: '10 buổi chụp',
  condition: 'Hoàn thành 10 buổi chụp',
  earned: false,
);

const _unknownBadge = BadgeView(
  code: 'mystery_super_badge',
  name: 'Bí ẩn',
  condition: 'Điều kiện đặc biệt',
  earned: true,
);

void main() {
  group('BadgeTile', () {
    testWidgets('earned uses the gradient disc', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeTile(badge: _earnedBadge)));
      await tester.pumpAndSettle();

      // CtaSurface is used for the gradient disc
      expect(find.byType(CtaSurface), findsOneWidget);
      expect(find.text('Chưa đạt'), findsNothing);
    });

    testWidgets("not earned is grey with 'Chưa đạt' and, with progress, a CapacityBar and '3 / 5'", (tester) async {
      await tester.pumpWidget(_wrap(
        const BadgeTile(
          badge: _notEarnedBadge,
          progress: BadgeProgress(current: 3, total: 5),
        ),
      ));
      await tester.pumpAndSettle();

      // Not earned disc does NOT use CtaSurface
      expect(find.byType(CtaSurface), findsNothing);
      expect(find.text('Chưa đạt'), findsOneWidget);
      expect(find.byType(CapacityBar), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);
    });

    testWidgets("isNew shows the 'Mới' dot with a label", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const BadgeTile(
          badge: _earnedBadge,
          isNew: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mới'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('unknown code uses the fallback icon', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeTile(badge: _unknownBadge)));
      await tester.pumpAndSettle();

      // Fallback icon is Icons.military_tech
      final iconFinder = find.byIcon(Icons.military_tech);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('grid of 2 columns at 320 dp and 1.3x text scale has no overflow', (tester) async {
      await tester.pumpWidget(_wrap(
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: const [
            BadgeTile(
              badge: _notEarnedBadge,
              progress: BadgeProgress(current: 3, total: 5),
              isNew: true,
            ),
            BadgeTile(
              badge: _earnedBadge,
            ),
          ],
        ),
        width: 320,
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('skeleton matches size at 390 and 320 dp', (tester) async {
      for (final width in [390.0, 320.0]) {
        await tester.pumpWidget(_wrap(
          const BadgeTile(badge: _earnedBadge),
          width: width,
        ));
        await tester.pump();
        final realSize = tester.getSize(find.byType(BadgeTile));

        await tester.pumpWidget(_wrap(
          AppSkeletonScope(child: BadgeTile.skeleton()),
          width: width,
        ));
        await tester.pump();
        final skeletonSize = tester.getSize(find.byKey(const ValueKey('badge_tile_skeleton')));

        expect(skeletonSize.height, closeTo(realSize.height, 2.0), reason: 'height at $width');
        expect(skeletonSize.width, realSize.width, reason: 'width at $width');
      }
    });
  });
}
