// test/app/verify_routes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/features/verification/verify_business_screen.dart';
import 'package:photobooking/features/verification/verify_identity_screen.dart';

/// Builds the page widget the app's real router gives [location].
Widget _screenAt(GoRouter router, BuildContext context, String location) {
  final match = router.configuration.findMatch(Uri.parse(location));
  expect(match.isError, isFalse, reason: location);
  final last = match.matches.last;
  final route = last.route as GoRoute;
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
  testWidgets('the app router opens S21.03 (VNeID and chip) and S21.04', (
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

    final vneid = _screenAt(router, context, '/verify/identity');
    expect(vneid, isA<VerifyIdentityScreen>());
    expect((vneid as VerifyIdentityScreen).method, IdentityMethod.vneid);

    final nfc = _screenAt(router, context, '/verify/identity?method=nfc');
    expect(nfc, isA<VerifyIdentityScreen>());
    expect((nfc as VerifyIdentityScreen).method, IdentityMethod.nfc);

    final unknown = _screenAt(router, context, '/verify/identity?method=x');
    expect((unknown as VerifyIdentityScreen).method, IdentityMethod.vneid);

    expect(
      _screenAt(router, context, '/verify/business'),
      isA<VerifyBusinessScreen>(),
    );
  });
}
