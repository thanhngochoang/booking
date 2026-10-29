// test/app/organizer_routes_test.dart
//
// The app router opens the S30 organizer screens (Task 8) and S06.06 for an
// organizer (Task 1b) without the photographer-only redirect.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/earnings/payout_account_screen.dart';
import 'package:photobooking/features/organizer/entry_tickets_edit_screen.dart';
import 'package:photobooking/features/organizer/gate_staff_screen.dart';
import 'package:photobooking/features/organizer/managed_spot_screen.dart';
import 'package:photobooking/features/organizer/organizer_apply_screen.dart';
import 'package:photobooking/features/organizer/organizer_routes.dart';
import 'package:photobooking/features/organizer/spot_claim_screen.dart';

Widget _screenAt(GoRouter router, BuildContext context, String location) {
  final match = router.configuration.findMatch(Uri.parse(location));
  expect(match.isError, isFalse, reason: location);
  final last = match.matches.last;
  final route = last.route as GoRoute;
  expect(route.redirect, isNull, reason: location);
  return route.builder!(
    context,
    last.buildState(
      router.configuration,
      match,
      metadata: const <String, dynamic>{},
    ),
  );
}

void main() {
  testWidgets('the app router opens S30.01–S30.04, S30.06 and S06.06', (
    tester,
  ) async {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    addTearDown(c.dispose);
    final router = c.read(routerProvider);
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (ctx) {
          context = ctx;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(
      _screenAt(router, context, organizerApplyPath),
      isA<OrganizerApplyScreen>(),
    );
    expect(_screenAt(router, context, spotClaimPath), isA<SpotClaimScreen>());
    final spot = _screenAt(router, context, managedSpotPath('bd'));
    expect((spot as ManagedSpotScreen).spotId, 'bd');
    final create = _screenAt(router, context, entryNewPath('bd'));
    expect((create as EntryTicketsEditScreen).spotId, 'bd');
    expect(create.eventId, isNull);
    final edit = _screenAt(router, context, entryEditPath('ent1'));
    expect((edit as EntryTicketsEditScreen).eventId, 'ent1');
    expect(_screenAt(router, context, gateStaffPath), isA<GateStaffScreen>());
    expect(
      _screenAt(router, context, organizerPayoutPath),
      isA<PayoutAccountScreen>(),
    );
  });

  test('the route constants', () {
    expect(organizerApplyPath, '/organizer/apply');
    expect(spotClaimPath, '/organizer/spots/claim');
    expect(managedSpotPath('bd'), '/organizer/spots/bd');
    expect(entryNewPath('bd'), '/organizer/entry/new?spot=bd');
    expect(entryEditPath('e1'), '/organizer/entry/e1/edit');
    expect(gateStaffPath, '/organizer/gate-staff');
    expect(organizerPayoutPath, '/organizer/payout-account');
    expect(scanPath, '/scan');
  });
}
