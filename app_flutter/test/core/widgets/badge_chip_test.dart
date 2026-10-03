import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _wrap(Widget child, {double width = 390}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: child,
        ),
      ),
    ),
  );
}

const _b1 = BadgeView(
  code: 'top_rated',
  name: 'Đánh giá cao',
  condition: 'Đạt điểm trung bình 4.9 sao',
  earned: true,
);

const _b2 = BadgeView(
  code: 'fast_reply',
  name: 'Phản hồi nhanh',
  condition: 'Trả lời trong 15 phút',
  earned: true,
);

const _b3 = BadgeView(
  code: 'verified',
  name: 'Đã xác minh',
  condition: 'Xác minh danh tính',
  earned: true,
);

const _b4 = BadgeView(
  code: 'shoots_10',
  name: '10 buổi chụp',
  condition: 'Hoàn thành 10 buổi chụp',
  earned: false,
);

void main() {
  group('BadgeChip', () {
    testWidgets("reads 'Huy hiệu {tên}'", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const BadgeChip(badge: _b1)));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Huy hiệu Đánh giá cao'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(BadgeChip(badge: _b1, onTap: () => tapped = true)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BadgeChip));
      expect(tapped, isTrue);
    });

    testWidgets('skeleton matches size at 390 and 320 dp', (tester) async {
      for (final width in [390.0, 320.0]) {
        await tester.pumpWidget(_wrap(const BadgeChip(badge: _b1), width: width));
        await tester.pump();
        final realSize = tester.getSize(find.byType(BadgeChip));

        await tester.pumpWidget(_wrap(AppSkeletonScope(child: BadgeChip.skeleton()), width: width));
        await tester.pump();
        final skeletonSize = tester.getSize(find.byKey(const ValueKey('badge_chip_skeleton')));

        expect(skeletonSize.height, realSize.height, reason: 'height at $width');
      }
    });
  });

  group('BadgeRow', () {
    testWidgets("shows at most max chips and 'Tất cả' only with onSeeAll", (tester) async {
      // 4 badges, max 3, no onSeeAll -> exactly 3 chips, no 'Tất cả'
      await tester.pumpWidget(_wrap(
        const BadgeRow(
          badges: [_b1, _b2, _b3, _b4],
          max: 3,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BadgeChip), findsNWidgets(3));
      expect(find.text('Tất cả'), findsNothing);

      // 4 badges, max 3, with onSeeAll -> 3 chips + 'Tất cả' button
      var seeAllTapped = false;
      await tester.pumpWidget(_wrap(
        BadgeRow(
          badges: const [_b1, _b2, _b3, _b4],
          max: 3,
          onSeeAll: () => seeAllTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BadgeChip), findsNWidgets(3));
      expect(find.text('Tất cả'), findsOneWidget);

      await tester.tap(find.text('Tất cả'));
      expect(seeAllTapped, isTrue);

      // 2 badges, max 3, with onSeeAll -> all 2 chips, no 'Tất cả' (all visible)
      await tester.pumpWidget(_wrap(
        BadgeRow(
          badges: const [_b1, _b2],
          max: 3,
          onSeeAll: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BadgeChip), findsNWidgets(2));
      expect(find.text('Tất cả'), findsNothing);
    });

    testWidgets('skeleton matches size for count at 390 and 320 dp', (tester) async {
      const s1 = BadgeView(code: 'top_rated', name: 'A', condition: '', earned: true);
      const s2 = BadgeView(code: 'fast_reply', name: 'B', condition: '', earned: true);
      const s3 = BadgeView(code: 'verified', name: 'C', condition: '', earned: true);
      for (final width in [390.0, 320.0]) {
        await tester.pumpWidget(_wrap(
          const BadgeRow(badges: [s1, s2, s3], max: 3),
          width: width,
        ));
        await tester.pump();
        final realSize = tester.getSize(find.byType(BadgeRow));

        await tester.pumpWidget(_wrap(
          AppSkeletonScope(child: BadgeRow.skeleton(count: 3)),
          width: width,
        ));
        await tester.pump();
        final skeletonSize = tester.getSize(find.byKey(const ValueKey('badge_row_skeleton')));

        expect(skeletonSize.height, realSize.height, reason: 'height at $width');
        expect(skeletonSize.width, realSize.width, reason: 'width at $width');
      }
    });
  });
}
