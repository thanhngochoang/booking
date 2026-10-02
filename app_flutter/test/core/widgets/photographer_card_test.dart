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
      data: fixturePhotographer(
        'p1',
        name: name,
        verified: verified,
        startingPrice: price,
      ),
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
    await tester.pumpWidget(
      _card(distanceKm: null, price: null, availability: null),
    );
    expect(find.text('Chân dung · ★ 4,9 · 112 buổi'), findsOneWidget);
    expect(find.text('—'), findsOneWidget, reason: 'unknown price');
    expect(find.text('từ'), findsNothing);
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

  testWidgets(
    'profile and book buttons call their handlers; book is optional',
    (tester) async {
      var profile = 0, book = 0;
      await tester.pumpWidget(
        _card(onProfile: () => profile++, onBook: () => book++),
      );
      await tester.tap(find.byKey(const Key('card-profile-p1')));
      await tester.tap(find.byKey(const Key('card-book-p1')));
      expect((profile, book), (1, 1));
      expect(find.text('Đặt T7'), findsOneWidget);

      await tester.pumpWidget(_card());
      expect(find.byKey(const Key('card-book-p1')), findsNothing);
    },
  );

  testWidgets('tapping the hero or the name row opens the profile', (
    tester,
  ) async {
    var profile = 0;
    await tester.pumpWidget(_card(onProfile: () => profile++));
    await tester.tap(
      find.byKey(const ValueKey('photo:https://img.test/avatar-p1.jpg')).first,
    );
    expect(profile, 1);
  });

  testWidgets('the hero is decoded at card width', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(_card(log: log, width: 300));
    expect(
      log.any((r) => r.cacheWidth == 600 && !r.retry),
      isTrue,
      reason: 'hero: 300 dp x 2, no retry under the card-wide tap layer',
    );
  });

  testWidgets('has no BackdropFilter', (tester) async {
    await tester.pumpWidget(
      _card(
        reasons: const [Reason(code: ReasonCode.near, text: 'x')],
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets(
      'fits 320dp at 1.3x on ${b.name}; buttons stack and stay 48dp',
      (tester) async {
        // The default 800x600 test view is shorter than the stacked card.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 1600);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _card(
            name: 'Nguyễn Thị Phương Anh Nhiếp Ảnh Gia',
            onBook: () {},
            bookLabel: 'Đặt T7 12/10',
            reasons: const [
              Reason(code: ReasonCode.skillMatch, text: 'Chuyên sâu chân dung'),
            ],
            width: 320,
            textScale: 1.3,
            brightness: b,
          ),
        );
        expect(tester.takeException(), isNull);
        final profile = tester.getRect(
          find.byKey(const Key('card-profile-p1')),
        );
        final book = tester.getRect(find.byKey(const Key('card-book-p1')));
        expect(profile.height, 48);
        expect(book.height, 48);
        expect(
          book.top,
          greaterThan(profile.bottom - 1),
          reason: 'stacked under large text',
        );
      },
    );
  }

  testWidgets('side by side at normal text size', (tester) async {
    await tester.pumpWidget(_card(onBook: () {}));
    final profile = tester.getRect(find.byKey(const Key('card-profile-p1')));
    final book = tester.getRect(find.byKey(const Key('card-book-p1')));
    expect(book.top, profile.top);
    expect(book.left, greaterThan(profile.right));
  });

  testWidgets('a price of 0 is treated as unknown', (tester) async {
    await tester.pumpWidget(_card(price: 0));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('từ'), findsNothing);
    expect(find.text('0₫'), findsNothing);
  });

  testWidgets('the header semantics label lists name, meta, price, slot', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_card());
    expect(
      find.bySemanticsLabel(
        'Minh Trí, Đã xác minh, Chân dung · 1,2 km · ★ 4,9 · 112 buổi, '
        'từ 1,5M, Rảnh 12/10',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('header semantics omit an unknown price', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_card(price: null));
    expect(find.bySemanticsLabel(RegExp(r'từ|—')), findsNothing);
    handle.dispose();
  });

  testWidgets('no rating leaves it out of the meta line', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        PhotographerCard(
          data: fixturePhotographer('p1', reviews: 0),
          onProfile: () {},
        ),
      ),
    );
    expect(find.textContaining('★'), findsNothing);
  });

  testWidgets('Hồ sơ is a small outline, Đặt a small gradient primary, 38dp', (
    tester,
  ) async {
    await tester.pumpWidget(_card(onBook: () {}));
    final profile = tester.widget<AppButton>(
      find.byKey(const Key('card-profile-p1')),
    );
    final book = tester.widget<AppButton>(
      find.byKey(const Key('card-book-p1')),
    );
    expect(profile.size, AppButtonSize.small);
    expect(book.size, AppButtonSize.small);
    final outline = find.descendant(
      of: find.byKey(const Key('card-profile-p1')),
      matching: find.byType(OutlinedButton),
    );
    final filled = find.descendant(
      of: find.byKey(const Key('card-book-p1')),
      matching: find.byType(FilledButton),
    );
    expect(outline, findsOneWidget);
    expect(filled, findsOneWidget);
    expect(tester.getSize(outline).height, 38);
    expect(tester.getSize(filled).height, 38);
    expect(
      tester.getSize(find.byKey(const Key('card-book-p1'))).height,
      48,
      reason: 'hit area',
    );
  });

  testWidgets('the avatar is 40dp', (tester) async {
    await tester.pumpWidget(_card());
    final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
    expect(avatar.size, AppAvatarSize.sm);
    expect(avatar.size.dimension, 40);
  });

  testWidgets('one outer button node plus two button nodes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_card(onBook: () {}));
    expect(
      find.semantics.byPredicate((n) => n.flagsCollection.isButton),
      findsNWidgets(3),
    );
    handle.dispose();
  });

  testWidgets('button row matches the mock: info row, 38 visual, 10 below', (
    tester,
  ) async {
    await tester.pumpWidget(_card(onBook: () {}, availability: null));
    final info = tester.getRect(
      find
          .ancestor(of: find.byType(AppAvatar), matching: find.byType(Padding))
          .first,
    );
    final box = tester.getRect(find.byKey(const Key('card-profile-p1')));
    final visual = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('card-profile-p1')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      visual.top,
      info.bottom,
      reason: 'row padding 10 is in the info row',
    );
    expect(box.bottom, info.bottom + 38 + 10, reason: 'card ends 10 below');
    expect(info.height, greaterThanOrEqualTo(40 + 20));
    final avatar = tester.getRect(find.byType(AppAvatar));
    expect(avatar.top - info.top, 10, reason: 'info row padding 10');
  });

  testWidgets('glass fill, and stacked buttons keep the mock gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        onBook: () {},
        textScale: 1.3,
        width: 320,
        brightness: Brightness.light,
      ),
    );
    await tester.pump();
    final card = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PhotographerCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(card.color, AppColors.glass);
    final profile = tester.getRect(find.widgetWithText(AppButton, 'Hồ sơ'));
    final book = tester.getRect(find.widgetWithText(AppButton, 'Đặt T7'));
    // 48dp tap boxes, visuals on top: 10dp between the visuals, as in the mock.
    expect(book.top - profile.bottom, 0);
  });
}
