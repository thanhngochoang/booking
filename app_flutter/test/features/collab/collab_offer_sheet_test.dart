// S27.07 "Nhận việc cộng tác" (#151 Task 9).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';
import 'package:photobooking/features/collab/collab_offer_sheet.dart';

import '../../support/collab_world.dart';
import '../../support/recruit_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Finder _code(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

/// Cúc's offer to Dũng, 3 h 52 min left at [recruitNow] (10:00 in Vietnam).
CollabJob _offer({Duration left = const Duration(hours: 3, minutes: 52)}) =>
    makeCollabJob(
      bookingId: 'b2',
      serviceName: 'Cưới 4 giờ',
      day: '2026-10-24',
      start: '15:30',
      end: '19:30',
      placeName: 'Quận 3',
      agreedFee: 800000,
      offerStatus: OfferStatus.pending,
      offerExpiresAt: recruitNow.add(left),
    );

Future<RecruitWorld> _open(
  WidgetTester tester,
  CollabJob job, {
  Size size = const Size(390, 900),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = RecruitWorld(uid: 'dung');
  w.collabs.seedJob(job);
  await tester.pumpWidget(
    w.app(
      '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCollabOfferSheet(context, job),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
      textScale: textScale,
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await CollabWorld.settle(tester);
  return w;
}

void main() {
  testWidgets('shows shoot, studio, fee, deadline with remaining time from '
      'the fake clock', (tester) async {
    await _open(tester, _offer());
    expect(_code('S27.07'), findsOneWidget);
    expect(find.text('Nhận việc cộng tác'), findsOneWidget);
    expect(
      find.text('Cưới 4 giờ T7 24/10 · 15:30–19:30 · Quận 3'),
      findsOneWidget,
    );
    expect(find.text('Studio Cúc'), findsOneWidget);
    expect(
      find.text('Studio chịu trách nhiệm với khách và lo bàn giao ảnh'),
      findsOneWidget,
    );
    expect(find.text('800.000₫'), findsOneWidget);
    expect(
      find.text('Thù lao · studio trả trực tiếp cho bạn sau buổi chụp'),
      findsOneWidget,
    );
    expect(
      find.text('Trả lời trước 13:52 hôm nay (còn 3 giờ 52 phút)'),
      findsOneWidget,
    );
    expect(find.text('Không trả lời coi như từ chối'), findsOneWidget);
    expect(
      find.text(
        'Nhận việc thì khung giờ này bị khoá trên lịch của bạn và bạn vào '
        'hội thoại với khách.',
      ),
      findsOneWidget,
    );
    // One gradient button: "Nhận việc"; "Từ chối" is outline.
    expect(find.byType(CtaSurface), findsOneWidget);
    expect(
      find.descendant(
        of: _key('collab-offer-accept'),
        matching: find.byType(CtaSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    '"Nhận việc" → respondOffer(accept: true), toast "Đã nhận việc"',
    (tester) async {
      final w = await _open(tester, _offer());
      await tester.tap(_key('collab-offer-accept'));
      await CollabWorld.settle(tester);
      expectCall(w.collabs.calls.single, 'respondCollabOffer', {
        'bookingId': 'b2',
        'accept': true,
      });
      expect(find.text('Đã nhận việc'), findsOneWidget);
      expect(_code('S27.07'), findsNothing);
    },
  );

  testWidgets('"Từ chối" asks first (red "Từ chối" in a confirm sheet) → '
      'toast "Đã từ chối, studio được báo"', (tester) async {
    final w = await _open(tester, _offer());
    await tester.tap(_key('collab-offer-decline'));
    await CollabWorld.settle(tester);
    expect(w.collabs.calls, isEmpty);
    expect(find.text('Từ chối việc này?'), findsOneWidget);
    final red = find.widgetWithText(FilledButton, 'Từ chối');
    expect(
      tester
          .widget<FilledButton>(red)
          .style
          ?.backgroundColor
          ?.resolve(const {}),
      AppColors.error,
    );
    await tester.tap(red);
    await CollabWorld.settle(tester);
    expectCall(w.collabs.calls.single, 'respondCollabOffer', {
      'bookingId': 'b2',
      'accept': false,
    });
    expect(find.text('Đã từ chối, studio được báo'), findsOneWidget);
    expect(_code('S27.07'), findsNothing);
  });

  testWidgets('"Quay lại" in the decline confirm does nothing', (tester) async {
    final w = await _open(tester, _offer());
    await tester.tap(_key('collab-offer-decline'));
    await CollabWorld.settle(tester);
    await tester.tap(find.text('Quay lại'));
    await CollabWorld.settle(tester);
    expect(w.collabs.calls, isEmpty);
    expect(_code('S27.07'), findsOneWidget);
    expect(_key('collab-offer-accept'), findsOneWidget);
  });

  for (final (status, line) in [
    (OfferStatus.accepted, 'Bạn đã nhận việc này.'),
    (OfferStatus.declined, 'Việc này không còn chờ bạn nhận.'),
    (OfferStatus.replaced, 'Việc này không còn chờ bạn nhận.'),
  ]) {
    testWidgets('a ${status.code} offer says "$line", no answer buttons', (
      tester,
    ) async {
      final job = _offer();
      await _open(tester, job.copyWith(offerStatus: status));
      expect(find.text(line), findsOneWidget);
      expect(find.text('Việc này đã hết hạn trả lời'), findsNothing);
      expect(_key('collab-offer-accept'), findsNothing);
      expect(_key('collab-offer-decline'), findsNothing);
    });
  }

  testWidgets('deadline_passed shows "Việc này đã hết hạn trả lời"', (
    tester,
  ) async {
    final w = await _open(tester, _offer());
    w.collabs.failWith = const RecruitError(RecruitErrorCode.deadlinePassed);
    await tester.tap(_key('collab-offer-accept'));
    await CollabWorld.settle(tester);
    expect(find.text('Việc này đã hết hạn trả lời'), findsOneWidget);
    expect(_code('S27.07'), findsOneWidget);
  });

  testWidgets('an offer already past its expiry shows the line and no '
      'answer buttons', (tester) async {
    await _open(tester, _offer(left: const Duration(minutes: -5)));
    expect(find.text('Việc này đã hết hạn trả lời'), findsOneWidget);
    expect(_key('collab-offer-accept'), findsNothing);
    expect(_key('collab-offer-decline'), findsNothing);
  });

  testWidgets('day_taken shows collabErrorDayTaken', (tester) async {
    final w = await _open(tester, _offer());
    w.collabs.failWith = const RecruitError(RecruitErrorCode.dayTaken);
    await tester.tap(_key('collab-offer-accept'));
    await CollabWorld.settle(tester);
    expect(find.text('Bạn đã có lịch trong ngày này.'), findsOneWidget);
  });

  testWidgets('the sheet shows no customer phone or contact action', (
    tester,
  ) async {
    await _open(tester, _offer());
    expect(find.byType(ContactDial), findsNothing);
    expect(find.byIcon(AppIcons.phone), findsNothing);
    expect(find.textContaining('+84'), findsNothing);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(tester, _offer(), size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
