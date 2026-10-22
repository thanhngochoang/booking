import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/instant_request_controller.dart';

import '../../support/instant_customer_world.dart';

/// The open screen's listener on the controller.
late ProviderSubscription<AsyncValue<InstantRequestView>> _screen;

Future<(ProviderContainer, InstantRequestController)> _open(
  InstantCustomerWorld w,
) async {
  final c = ProviderContainer(overrides: w.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  _screen = c.listen(instantRequestControllerProvider, (_, _) {});
  await c.read(instantRequestControllerProvider.future);
  return (c, c.read(instantRequestControllerProvider.notifier));
}

void _fill(ProviderContainer c) {
  c.read(instantDraftProvider.notifier)
    ..setPackage('p30')
    ..setGenre(InstantGenre.event)
    ..setMeetPointName('Hồ Con Rùa')
    ..setNote('Sinh nhật nhỏ');
}

void main() {
  test('draft is reset after a successful create', () async {
    final w = InstantCustomerWorld();
    final (c, ctl) = await _open(w);
    _fill(c);
    final r = await ctl.submit();
    expect(r, isA<InstantSubmitCreated>());
    expect((r! as InstantSubmitCreated).requestId, 'req_new');
    final d = c.read(instantDraftProvider);
    expect(d.packageCode, isNull);
    expect(d.genre, InstantGenre.portrait);
    expect(d.meetPointName, '');
    expect(d.note, '');
    // Stays busy until the screen has left.
    expect(c.read(instantRequestControllerProvider).value!.busy, isTrue);
  });

  test('leaving S13.01 while creating still resets the draft', () async {
    final w = InstantCustomerWorld();
    final (c, ctl) = await _open(w);
    _fill(c);
    final gate = Completer<void>();
    w.repo.gate = gate;
    final pending = ctl.submit();
    await pumpEventQueue();
    expect(w.repo.callsOf('createRequest'), hasLength(1));
    // The customer leaves: the screen stops listening to the controller.
    _screen.close();
    await c.pump();
    gate.complete();
    final r = await pending;
    expect(r, isA<InstantSubmitCreated>());
    expect(c.read(instantDraftProvider).meetPointName, '');
  });

  test('the draft outlives the screen (keep-alive)', () async {
    final w = InstantCustomerWorld();
    final (c, _) = await _open(w);
    _fill(c);
    // S13.01 closes for the phone detour: no listener is left.
    _screen.close();
    await c.pump();
    await pumpEventQueue();
    expect(c.read(instantDraftProvider).meetPointName, 'Hồ Con Rùa');
    expect(c.read(instantDraftProvider).packageCode, 'p30');
  });

  test('another account signing in empties the draft', () async {
    final w = InstantCustomerWorld();
    final (c, _) = await _open(w);
    c.listen(instantDraftProvider, (_, _) {});
    _fill(c);
    w.signInAs('cus1');
    await pumpEventQueue();
    expect(c.read(instantDraftProvider).meetPointName, 'Hồ Con Rùa');
    w.signInAs('cus2');
    await pumpEventQueue();
    expect(c.read(instantDraftProvider).meetPointName, '');
    expect(c.read(instantDraftProvider).packageCode, isNull);
    _fill(c);
    w.signInAs(null);
    await pumpEventQueue();
    expect(c.read(instantDraftProvider).meetPointName, '', reason: 'sign-out');
  });

  test('conflict makes the Home card read the open request again', () async {
    final w = InstantCustomerWorld()..repo.activeRequestId = 'req_open';
    final (c, ctl) = await _open(w);
    c.listen(instantActiveRequestIdProvider, (_, _) {});
    await c.read(instantActiveRequestIdProvider.future);
    _fill(c);
    w.repo.failNext('createRequest', 'conflict');
    final r = await ctl.submit();
    expect((r! as InstantSubmitHasActive).requestId, 'req_open');
    expect(await c.read(instantActiveRequestIdProvider.future), 'req_open');
    // Home's read, the conflict's read, Home's read again.
    expect(w.repo.callsOf('myActiveRequestId'), hasLength(3));
  });

  test('a create makes the Home card read the open request again', () async {
    final w = InstantCustomerWorld();
    final (c, ctl) = await _open(w);
    c.listen(instantActiveRequestIdProvider, (_, _) {});
    expect(await c.read(instantActiveRequestIdProvider.future), isNull);
    _fill(c);
    w.repo.activeRequestId = 'req_new';
    await ctl.submit();
    expect(await c.read(instantActiveRequestIdProvider.future), 'req_new');
    expect(w.repo.callsOf('myActiveRequestId'), hasLength(2));
  });

  test('the draft is kept when the create fails or needs a phone', () async {
    final w = InstantCustomerWorld(contact: null);
    final (c, ctl) = await _open(w);
    _fill(c);
    expect(await ctl.submit(), isA<InstantSubmitNeedsPhone>());
    expect(c.read(instantDraftProvider).meetPointName, 'Hồ Con Rùa');

    w.setContact(customerPhone);
    // The contact provider is autoDispose: let the old one go.
    await Future<void>.delayed(Duration.zero);
    w.repo.failNext('createRequest', 'network');
    expect(await ctl.submit(), isA<InstantSubmitFailed>());
    expect(c.read(instantDraftProvider).note, 'Sinh nhật nhỏ');
    expect(c.read(instantRequestControllerProvider).value!.busy, isFalse);
  });

  test('a price list without a 1-hour package defaults to the middle one', () {
    const list = [
      InstantPackage(code: 'a', durationMin: 30, photos: 1, priceVnd: 1),
      InstantPackage(code: 'b', durationMin: 90, photos: 1, priceVnd: 2),
      InstantPackage(code: 'c', durationMin: 120, photos: 1, priceVnd: 3),
    ];
    expect(const InstantDraft().packageOf(list)?.code, 'b');
    expect(const InstantDraft(packageCode: 'gone').packageOf(list)?.code, 'b');
    expect(const InstantDraft(packageCode: 'c').packageOf(list)?.code, 'c');
    expect(const InstantDraft().packageOf(const []), isNull);
  });

  testWidgets('an empty price list shows the error state, not the form', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.configValue = const InstantConfig(
      enabled: true,
      priceListVersion: 2,
    );
    await pumpInstantCustomer(tester, w);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byKey(const Key('instant-see-matches')), findsNothing);
  });

  testWidgets('config error shows AsyncView error with retry', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('config', 'network');
    await pumpInstantCustomer(tester, w);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byType(MapPreview), findsNothing);

    await tester.tap(find.byKey(const Key('error-retry')));
    await settleInstant(tester);
    expect(w.repo.callsOf('config'), hasLength(2));
    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(MapPreview), findsOneWidget);
  });
}
