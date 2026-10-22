import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/choose_controller.dart';

import '../../support/instant_customer_world.dart';

/// A container with `req1` in the listener and the controller held alive.
Future<(ProviderContainer, ChooseController)> _setUp(
  InstantCustomerWorld w, {
  InstantRequest? request,
}) async {
  w.repo.emitRequest('req1', request ?? customerRequestOf());
  final c = ProviderContainer(overrides: w.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  c.listen(instantRequestProvider('req1'), (_, _) {});
  c.listen(chooseControllerProvider('req1'), (_, _) {});
  await c.read(instantRequestProvider('req1').future);
  // The fake's broadcast stream is subscribed once the first value is out.
  await pumpEventQueue();
  return (c, c.read(chooseControllerProvider('req1').notifier));
}

ChooseState _state(ProviderContainer c) =>
    c.read(chooseControllerProvider('req1'));

void main() {
  test('like, skip and undo keep the counts and the order', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..skip(instantCandidates[1])
      ..like(instantCandidates[2]);
    expect(_state(c).liked, ['p1', 'p3']);
    expect(_state(c).skipped, ['p2']);
    expect(_state(c).index, 3);

    controller.undo();
    expect(_state(c).liked, ['p1']);
    expect(_state(c).index, 2);
    controller.undo();
    expect(_state(c).skipped, isEmpty);
    expect(_state(c).index, 1);

    controller.done();
    expect(_state(c).summary, isTrue);
    controller.unpick('p1');
    expect(_state(c).liked, isEmpty);
  });

  test('double tap sends one invite', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..like(instantCandidates[1])
      ..done();
    w.repo.gate = Completer<void>();
    final first = controller.send();
    final second = await controller.send();
    expect(second, isNull);
    w.repo.gate!.complete();
    expect(await first, isA<InstantInvited>());
    expect(w.repo.callsOf('invite'), hasLength(1));
  });

  test('invite sends no payMethod', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..skip(instantCandidates[1])
      ..like(instantCandidates[2])
      ..done();
    await controller.send();
    final call = w.repo.callsOf('invite').single;
    expect(call.args, {
      'requestId': 'req1',
      'photographerIds': ['p1', 'p3'],
      'skipped': ['p2'],
      'expectedAmountVnd': 690000,
      'payMethod': null,
    });
  });

  test('an invited result asks the primer once', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(w);
    var asked = 0;
    Future<void> primer() async => asked++;
    controller
      ..like(instantCandidates[0])
      ..done();
    w.repo.inviteResult = const InstantInvited(
      invited: ['p1'],
      unavailable: [],
    );

    // A refusal is not a success: no primer.
    w.repo.failNext('invite', 'network');
    await controller.send(askPrimer: primer);
    expect(asked, 0);

    await controller.send(askPrimer: primer);
    expect(asked, 1);
    await controller.send(askPrimer: primer);
    expect(asked, 1);
  });

  test('every chosen person unavailable is not a success: no primer', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    var asked = 0;
    Future<void> primer() async => asked++;
    controller
      ..like(instantCandidates[0])
      ..like(instantCandidates[1])
      ..done();
    w.repo.inviteResult = const InstantInvited(
      invited: [],
      unavailable: ['p1', 'p2'],
    );
    expect(await controller.send(askPrimer: primer), isA<InstantInvited>());
    expect(asked, 0);
    expect(_state(c).sending, isFalse);

    // The server marked the request committed, but nobody was invited yet:
    // the next real invite is the first one.
    w.repo.emitRequest('req1', customerRequestOf(committed: true));
    await pumpEventQueue();
    w.repo.inviteResult = const InstantInvited(
      invited: ['p1'],
      unavailable: [],
    );
    await controller.send(askPrimer: primer);
    expect(asked, 1);
  });

  test('a request with invites sent before asks no primer', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(
      w,
      request: customerRequestOf(
        committed: true,
        round: 2,
      ).copyWith(invitedTotal: 3, roundsWithInvites: 1),
    );
    var asked = 0;
    controller
      ..like(instantCandidates[0])
      ..done();
    await controller.send(askPrimer: () async => asked++);
    expect(asked, 0);
  });

  test('price changed: the new amount is kept and sent next', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..done();
    w.repo.inviteResult = const InstantPriceChanged(amountVnd: 720000);
    final result = await controller.send();
    expect(result, isA<InstantPriceChanged>());
    expect(_state(c).summary, isTrue);
    expect(_state(c).sending, isFalse);
    expect(_state(c).amountVnd, 720000);

    w.repo.inviteResult = const InstantInvited(
      invited: ['p1'],
      unavailable: [],
    );
    await controller.send();
    expect(w.repo.callsOf('invite').last.args['expectedAmountVnd'], 720000);
  });

  test('a failed invite keeps the choice and records the error', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..done();
    w.repo.failNext('invite', 'network');
    expect(await controller.send(), isNull);
    expect(_state(c).sending, isFalse);
    expect(_state(c).liked, ['p1']);
    expect(_state(c).error, const InstantError('network'));
  });

  test('more() asks for the next round without the skipped people', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..skip(instantCandidates[0])
      ..skip(instantCandidates[1]);
    await controller.more();
    expect(w.repo.callsOf('nextCandidates').single.args, {
      'requestId': 'req1',
      'skipped': ['p1', 'p2'],
    });
    expect(_state(c).fetching, isFalse);
  });

  test('a new round starts a fresh choice', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..skip(instantCandidates[1])
      ..done();
    w.repo.emitRequest('req1', customerRequestOf(round: 2));
    await pumpEventQueue();
    expect(_state(c).liked, isEmpty);
    expect(_state(c).skipped, isEmpty);
    expect(_state(c).index, 0);
    expect(_state(c).summary, isFalse);
  });

  test('nothing chosen sends nothing', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(w);
    expect(await controller.send(), isNull);
    expect(w.repo.callsOf('invite'), isEmpty);
  });
}
