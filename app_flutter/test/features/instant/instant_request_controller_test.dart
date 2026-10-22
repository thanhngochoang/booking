import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/instant_request_controller.dart';

import '../../support/instant_customer_world.dart';

Future<(ProviderContainer, InstantRequestController)> _open(
  InstantCustomerWorld w,
) async {
  final c = ProviderContainer(overrides: w.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  c.listen(instantRequestControllerProvider, (_, _) {});
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
