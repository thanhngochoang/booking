import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/features/events/register_sheet.dart';

import '../../support/event_world.dart';

const _size = Size(390, 900);

EventDetail _free({int capacity = 20, int registered = 5}) =>
    detailOf('ev1', priceVnd: 0, capacity: capacity, registered: registered);

Future<EventsWorld> _open(
  WidgetTester tester, {
  EventDetail? event,
  bool hasPhone = true,
  double textScale = 1,
  Size size = _size,
  List<Override> extra = const [],
}) async {
  final w = EventsWorld(events: [event ?? _free()]);
  w.repo.hasPhone = hasPhone;
  await w.pump(
    tester,
    path: '/e/ev1',
    size: size,
    textScale: textScale,
    extra: extra,
  );
  await tester.tap(find.byKey(const Key('event-join')));
  await settle(tester);
  return w;
}

Future<void> _plus(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(const Key('register-plus')));
    await tester.pump();
  }
}

/// A paid event: 250.000₫ a ticket.
EventDetail _paid({int registered = 5}) =>
    detailOf('ev1', priceVnd: 250000, registered: registered);

String _quantity(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('register-quantity'))).data!;

void main() {
  testWidgets('the sheet shows the title, event name and seats hint', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Đăng ký tham gia'), findsWidgets);
    expect(find.text('Số vé'), findsOneWidget);
    expect(find.text('Tối đa 4 vé, còn 15 chỗ'), findsOneWidget);
    expect(find.byKey(const Key('register-phone')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('register-phone'))).data,
      '0903 123 456',
    );
  });

  testWidgets('stepper stops at 4', (tester) async {
    await _open(tester);
    await _plus(tester, 6);
    expect(_quantity(tester), '4');
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('register-plus')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('register-minus')));
    await tester.pump();
    expect(_quantity(tester), '3');
  });

  testWidgets('stepper stops at the seats left', (tester) async {
    await _open(tester, event: _free(registered: 17));
    expect(find.text('Tối đa 4 vé, còn 3 chỗ'), findsOneWidget);
    await _plus(tester, 5);
    expect(_quantity(tester), '3');
  });

  testWidgets('name is prefilled and required', (tester) async {
    await _open(tester);
    final field = find.byKey(const Key('register-name'));
    expect(tester.widget<TextField>(field).controller!.text, 'Lan Anh');
    await tester.enterText(field, '   ');
    await tester.pump();
    expect(find.text('Nhập họ tên, tối đa 60 ký tự'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('register-submit')))
          .onPressed,
      isNull,
    );
    await tester.enterText(field, 'Lan');
    await tester.pump();
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('register-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('free sheet has no gateway and says Xác nhận đăng ký', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Xác nhận đăng ký'), findsOneWidget);
    expect(find.text('MoMo'), findsNothing);
    expect(find.text('VNPay'), findsNothing);
    expect(find.textContaining('Thanh toán'), findsNothing);
    expect(find.textContaining('0₫'), findsNothing);
    expect(find.byType(EscrowNotice), findsNothing);
  });

  testWidgets('submitting registers with quantity and name', (tester) async {
    final w = await _open(tester);
    await _plus(tester, 1);
    await tester.enterText(find.byKey(const Key('register-name')), 'Lan Anh B');
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    final r = w.repo.registrations.single;
    expect(r.quantity, 2);
    expect(r.userName, 'Lan Anh B');
    expect(r.status, RegistrationStatus.paid);
    expect(r.amount, 0);
  });

  testWidgets('success opens the tickets tab with the ticket highlighted', (
    tester,
  ) async {
    final w = await _open(tester);
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    final id = w.repo.registrations.single.id;
    expect(w.location, '/bookings?tab=events&highlight=$id');
    expect(find.text('Đã đăng ký'), findsOneWidget);
    expect(find.byKey(const Key('register-submit')), findsNothing);
  });

  testWidgets('success offers Vào nhóm chat on the SnackBar', (tester) async {
    final w = await _open(tester);
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    expect(
      find.widgetWithText(SnackBarAction, 'Vào nhóm chat'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(SnackBarAction, 'Vào nhóm chat'));
    await settle(tester);
    expect(w.location, '/e/ev1/chat');
  });

  testWidgets('sold_out closes the sheet and says Hết chỗ', (tester) async {
    final w = await _open(tester);
    w.repo.failWith = const EventError('sold_out');
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    expect(find.byKey(const Key('register-submit')), findsNothing);
    expect(find.text('Hết chỗ'), findsWidgets);
    expect(w.location, '/e/ev1');
  });

  testWidgets('deadline_passed says Đã đóng đăng ký inline', (tester) async {
    final w = await _open(tester);
    w.repo.failWith = const EventError('deadline_passed');
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    expect(find.byKey(const Key('register-error')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('register-error'))).data,
      'Đã đóng đăng ký',
    );
  });

  testWidgets('a network error is shown inline and can be retried', (
    tester,
  ) async {
    final w = await _open(tester);
    w.repo
      ..failWith = const EventError('network')
      ..failOnce = true;
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    expect(find.byKey(const Key('register-error')), findsOneWidget);
    expect(w.repo.registrations, isEmpty);
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    expect(w.repo.registrations, hasLength(1));
  });

  testWidgets('phone_required opens S04.05 with returnTo', (tester) async {
    final w = await _open(tester, hasPhone: false);
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);
    expect(
      w.location,
      '/profile/phone?returnTo=${Uri.encodeComponent('/e/ev1/join')}',
    );
    expect(find.byKey(const Key('register-submit')), findsNothing);
  });

  testWidgets('Đổi opens S04.05 with returnTo', (tester) async {
    final w = await _open(tester);
    await tester.tap(find.byKey(const Key('register-change-phone')));
    await settle(tester);
    expect(
      w.location,
      '/profile/phone?returnTo=${Uri.encodeComponent('/e/ev1/join')}',
    );
  });

  testWidgets('coming back from S04.05 reopens the sheet', (tester) async {
    final w = EventsWorld(events: [_free()]);
    await w.pump(tester, path: '/e/ev1/join', size: _size);
    expect(find.byKey(const Key('register-submit')), findsOneWidget);
  });

  group('paid (S11.03)', () {
    testWidgets('paid sheet shows the money table, escrow notice and policy', (
      tester,
    ) async {
      await _open(tester, event: _paid());
      await _plus(tester, 1);
      expect(find.text('2 vé × 250.000₫'), findsOneWidget);
      expect(find.text('Tổng thanh toán'), findsOneWidget);
      expect(find.text('500.000₫'), findsNWidgets(2));
      expect(
        find.text(
          'Tiền vé được giữ an toàn trên ứng dụng cho tới khi sự kiện kết thúc.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Huỷ trước 48 giờ hoàn 100%. Vé được giữ 10 phút trong lúc thanh toán.',
        ),
        findsOneWidget,
      );
      expect(find.text('Chuyển khoản QR'), findsOneWidget);
      expect(find.text('MoMo'), findsOneWidget);
      expect(find.text('ZaloPay'), findsOneWidget);
      expect(find.text('Thanh toán 500.000₫'), findsOneWidget);
      expect(find.text('Xác nhận đăng ký'), findsNothing);
      // Section order follows the mock: money, escrow, policy, method, button.
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(
        y(find.text('Tổng thanh toán')),
        lessThan(y(find.byType(EscrowNotice))),
      );
      expect(
        y(find.byType(EscrowNotice)),
        lessThan(y(find.byKey(const Key('register-policy')))),
      );
      expect(
        y(find.byKey(const Key('register-policy'))),
        lessThan(y(find.text('MoMo'))),
      );
      expect(
        y(find.text('MoMo')),
        lessThan(y(find.byKey(const Key('register-submit')))),
      );
    });

    testWidgets('the method maps onto the payment methods', (tester) async {
      final w = await _open(tester, event: _paid());
      await tester.tap(find.byKey(const Key('pay-method-momo')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('register-submit')));
      await settle(tester);
      expect(w.repo.registerMethods.last, PayMethod.momo);
    });

    testWidgets(
      'Thanh toán registers with the chosen method code, closes the sheet and opens /e/{id}/pay/{regId} with the instructions',
      (tester) async {
        final w = await _open(tester, event: _paid());
        await tester.tap(find.byKey(const Key('register-submit')));
        await settle(tester);
        final r = w.repo.registrations.single;
        expect(r.status, RegistrationStatus.held);
        expect(r.amount, 250000);
        expect(w.repo.registerMethods.single, PayMethod.bankQr);
        expect(find.byType(RegisterSheet), findsNothing);
        expect(w.location, '/e/ev1/pay/${r.id}');
      },
    );

    testWidgets('a wallet with real payments opens payUrl then S04.04', (
      tester,
    ) async {
      final w = await _open(
        tester,
        event: _paid(),
        extra: [realPaymentsProvider.overrideWithValue(true)],
      );
      await tester.tap(find.byKey(const Key('pay-method-momo')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('register-submit')));
      await settle(tester);
      final r = w.repo.registrations.single;
      expect(w.launcher.opened.map((u) => u.toString()), [
        'https://pay.test/${r.id}',
      ]);
      expect(find.byType(RegisterSheet), findsNothing);
      expect(w.location, '/e/ev1/pay/${r.id}');
    });

    testWidgets('a gateway error can be retried', (tester) async {
      final w = await _open(tester, event: _paid());
      w.repo
        ..failWith = const EventError('internal')
        ..failOnce = true;
      await tester.tap(find.byKey(const Key('register-submit')));
      await settle(tester);
      expect(find.byKey(const Key('register-error')), findsOneWidget);
      expect(find.text('Thanh toán 250.000₫'), findsWidgets);
      await tester.tap(find.byKey(const Key('register-submit')));
      await settle(tester);
      expect(w.repo.registrations.single.status, RegistrationStatus.held);
    });

    testWidgets('sold_out goes back to S11.02', (tester) async {
      final w = await _open(tester, event: _paid());
      w.repo.failWith = const EventError('sold_out');
      await tester.tap(find.byKey(const Key('register-submit')));
      await settle(tester);
      expect(find.byType(RegisterSheet), findsNothing);
      expect(w.location, '/e/ev1');
    });

    testWidgets('paid sheet fits 320dp at 1.3 text scale', (tester) async {
      await _open(
        tester,
        event: _paid(),
        textScale: 1.3,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('register-submit')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('fits 320dp at 1.3 text scale', (tester) async {
    await _open(tester, textScale: 1.3, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('register-submit')), findsOneWidget);
  });

  group('S11.03 venue variants', () {
    testWidgets(
      'the total is price × quantity: the venue fee is inside the price (Decision 16)',
      (tester) async {
        await _open(
          tester,
          event: detailOf(
            'ev1',
            priceVnd: 400000,
            venue: const EventVenue(
              kind: VenueKind.managedSpot,
              spotId: 'bd',
              termsVersion: organizerTermsVersion,
            ),
            venueConsent: HostConsent.accepted,
            venueFeePerGuest: 50000,
          ),
        );
        await _plus(tester, 1);
        expect(find.text('Thanh toán 800.000₫'), findsOneWidget);
        expect(find.text('gồm phí quản lý địa điểm 100.000₫'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RegisterSheet),
            matching: find.text('Đã gồm vé vào cửa'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a paid place not included: the gate fee line', (tester) async {
      await _open(
        tester,
        event: detailOf(
          'ev1',
          priceVnd: 250000,
          venue: const EventVenue(
            kind: VenueKind.paidPlace,
            entryFeeIncluded: false,
            entryFeeVnd: 20000,
            termsVersion: organizerTermsVersion,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(RegisterSheet),
          matching: find.text('Chưa gồm vé vào cửa ≈ 20.000₫ · trả tại cổng'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('gồm phí quản lý'), findsNothing);
      expect(find.text('Thanh toán 250.000₫'), findsOneWidget);
    });

    testWidgets('a free event at a paid place keeps the line', (tester) async {
      await _open(
        tester,
        event: detailOf(
          'ev1',
          priceVnd: 0,
          venue: const EventVenue(
            kind: VenueKind.paidPlace,
            entryFeeIncluded: false,
            entryFeeVnd: 20000,
            termsVersion: organizerTermsVersion,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(RegisterSheet),
          matching: find.text('Chưa gồm vé vào cửa ≈ 20.000₫ · trả tại cổng'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('fits 320 dp at 1.3× text with the venue lines', (
      tester,
    ) async {
      await _open(
        tester,
        size: const Size(320, 700),
        textScale: 1.3,
        event: detailOf(
          'ev1',
          priceVnd: 400000,
          venue: const EventVenue(
            kind: VenueKind.managedSpot,
            spotId: 'bd',
            termsVersion: organizerTermsVersion,
          ),
          venueConsent: HostConsent.accepted,
          venueFeePerGuest: 50000,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
