import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';

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
}) async {
  final w = EventsWorld(events: [event ?? _free()]);
  w.repo.hasPhone = hasPhone;
  await w.pump(tester, path: '/e/ev1', size: size, textScale: textScale);
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

  testWidgets('fits 320dp at 1.3 text scale', (tester) async {
    await _open(tester, textScale: 1.3, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('register-submit')), findsOneWidget);
  });
}
