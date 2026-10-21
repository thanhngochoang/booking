import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/studio/change_request_sheet.dart';

import '../../support/screen_host.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _minh = PhotographerProfile(
  summary: PhotographerSummary(
    id: 'minh',
    displayName: 'Minh Trí',
    verified: true,
    reviewCount: 30,
    tomatoCount: 29,
    brickCount: 1,
    tomatoPct: 97,
  ),
  intro: PhotographerIntro(onboardingComplete: true),
);

class _Host {
  _Host(this.world);
  final StudioWorld world;
  bool? result;
}

/// Opens S26.05 for the customer of `sb1`, assigned to Minh Trí.
Future<_Host> _open(
  WidgetTester tester, {
  double width = 390,
  double height = 900,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = StudioWorld(uid: 'c1');
  final booking = makeStudioBooking(assigneeId: 'minh');
  w.bookings.seedBooking(booking);
  final host = _Host(w);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  host.result = await showChangeRequestSheet(context, booking),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: [
        ...w.overrides,
        photographerProfileProvider('minh')
            .overrideWithValue(const AsyncData(_minh)),
      ],
      textScale: textScale,
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await _settle(tester);
  return host;
}

void main() {
  testWidgets('shows the current member, optional reason, the two notes and '
      'the once line', (tester) async {
    await _open(tester);

    expect(find.byType(ScreenCode), findsWidgets);
    expect(find.text('Xin đổi thợ chụp'), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.textContaining('Thợ hiện tại'), findsOneWidget);
    expect(find.textContaining('97%'), findsOneWidget);
    expect(find.text('Lý do (tuỳ chọn)'), findsOneWidget);
    expect(
      find.text(
        'Studio trả lời trong 6 giờ.\n'
        'Nếu studio từ chối hoặc không trả lời, bạn được huỷ và hoàn 100%.',
      ),
      findsOneWidget,
    );
    expect(find.text('Bạn chỉ xin đổi được 1 lần.'), findsOneWidget);
    // The reason is optional: the button works from the start.
    final send = tester.widget<AppButton>(_key('change-send'));
    expect(send.label, 'Gửi yêu cầu đổi');
    expect(send.onPressed, isNotNull);
  });

  testWidgets('Gửi yêu cầu đổi sends the note and closes with changeSent', (
    tester,
  ) async {
    final h = await _open(tester);

    await tester.enterText(
      _key('change-reason'),
      '  Mình muốn thợ nữ cho bộ ảnh cưới  ',
    );
    await tester.tap(_key('change-send'));
    await _settle(tester);

    final call = h.world.bookings.studioCalls.single;
    expect(call.$1, 'requestAssigneeChange');
    expect(call.$2, {
      'bookingId': 'sb1',
      'note': 'Mình muốn thợ nữ cho bộ ảnh cưới',
    });
    expect(h.result, isTrue);
    expect(find.text('Xin đổi thợ chụp'), findsNothing);
    expect(find.text('Đã gửi yêu cầu đổi thợ'), findsOneWidget);
  });

  testWidgets('an empty reason sends no note', (tester) async {
    final h = await _open(tester);

    await tester.tap(_key('change-send'));
    await _settle(tester);

    expect(h.world.bookings.studioCalls.single.$2, {'bookingId': 'sb1'});
  });

  testWidgets('conflict shows studioErr_conflict', (tester) async {
    final h = await _open(tester);
    h.world.bookings.nextError = BookingErrorCode.conflict;

    await tester.tap(_key('change-send'));
    await _settle(tester);

    expect(find.text('Yêu cầu đã được xử lý trước đó.'), findsOneWidget);
    // The sheet stays open, the button usable again.
    expect(find.text('Xin đổi thợ chụp'), findsOneWidget);
    expect(tester.widget<AppButton>(_key('change-send')).onPressed, isNotNull);
    expect(h.result, isNull);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(tester, width: 320, height: 700, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
