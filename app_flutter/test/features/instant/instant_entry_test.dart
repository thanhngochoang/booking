import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/instant/instant_entry_card.dart';
import 'package:photobooking/features/instant/instant_find_button.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_customer_world.dart';

final _card = find.byKey(const Key('instant-entry-card'));
final _button = find.byKey(const Key('instant-find-button'));

String _location(GoRouter router) => router.state.uri.toString();

/// Home (`/home`) with the card, Find (`/action`) with the button.
Future<GoRouter> _pump(
  WidgetTester tester,
  InstantCustomerWorld w, {
  String initial = '/home',
}) => pumpInstantCustomer(
  tester,
  w,
  push: null,
  router: instantCustomerRouter(
    w,
    initial: initial,
    home: const InstantEntryCard(),
    action: const InstantFindButton(),
  ),
);

void main() {
  testWidgets('Home card shows "Chụp ngay" and opens /instant', (tester) async {
    final w = InstantCustomerWorld();
    final router = await _pump(tester, w);
    expect(_card, findsOneWidget);
    expect(find.text('Chụp ngay'), findsOneWidget);
    expect(
      find.text('Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút'),
      findsOneWidget,
    );
    await tester.tap(_card);
    await settleInstant(tester);
    expect(_location(router), '/instant');
  });

  testWidgets('Home card resumes "Yêu cầu chụp ngay đang mở" → /instant/{id}', (
    tester,
  ) async {
    final w = InstantCustomerWorld(
      repo: FakeInstantRepository(activeRequestId: 'req_open'),
    );
    final router = await _pump(tester, w);
    expect(find.text('Yêu cầu chụp ngay đang mở'), findsOneWidget);
    expect(find.text('Chạm để xem tiếp'), findsOneWidget);
    expect(find.text('Chụp ngay'), findsNothing);
    await tester.tap(_card);
    await settleInstant(tester);
    expect(_location(router), '/instant/req_open');
  });

  testWidgets('a failed read still shows the plain entry', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('myActiveRequestId', 'network');
    await _pump(tester, w);
    expect(find.text('Chụp ngay'), findsOneWidget);
  });

  testWidgets('Find button opens /instant', (tester) async {
    final w = InstantCustomerWorld();
    final router = await _pump(tester, w, initial: '/action');
    expect(find.text('Chụp ngay · tới trong 30–90 phút'), findsOneWidget);
    // Read on tap only, not when Find opens.
    expect(w.repo.callsOf('myActiveRequestId'), isEmpty);
    await tester.tap(_button);
    await settleInstant(tester);
    expect(w.repo.callsOf('myActiveRequestId'), hasLength(1));
    expect(_location(router), '/instant');
  });

  testWidgets('Find button opens the open request when there is one', (
    tester,
  ) async {
    final w = InstantCustomerWorld(
      repo: FakeInstantRepository(activeRequestId: 'req_open'),
    );
    final router = await _pump(tester, w, initial: '/action');
    await tester.tap(_button);
    await settleInstant(tester);
    expect(_location(router), '/instant/req_open');
  });

  for (final (name, world) in [
    ('the flag is off', () => InstantCustomerWorld(flag: false)),
    (
      'the user is a photographer',
      () => InstantCustomerWorld(role: UserRole.photographer),
    ),
  ]) {
    testWidgets('nothing when $name', (tester) async {
      final w = world();
      await _pump(tester, w);
      expect(_card, findsNothing);
      expect(find.text('Chụp ngay'), findsNothing);
      await _pump(tester, w, initial: '/action');
      expect(_button, findsNothing);
      expect(w.repo.calls, isEmpty, reason: 'nothing is read while hidden');
    });
  }

  testWidgets(
    'Home reads myActiveRequestId once per build of the card (not a stream)',
    (tester) async {
      final w = InstantCustomerWorld();
      final router = await _pump(tester, w);
      expect(w.repo.callsOf('myActiveRequestId'), hasLength(1));
      // Rebuilds and a page pushed on top do not read again.
      router.push('/instant/x');
      await settleInstant(tester);
      router.pop();
      await settleInstant(tester);
      expect(_card, findsOneWidget);
      expect(w.repo.callsOf('myActiveRequestId'), hasLength(1));
      // A new open of Home reads again.
      router.go('/action');
      await settleInstant(tester);
      router.go('/home');
      await settleInstant(tester);
      expect(w.repo.callsOf('myActiveRequestId'), hasLength(2));
    },
  );
}
