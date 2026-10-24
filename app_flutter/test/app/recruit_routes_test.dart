// test/app/recruit_routes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/recruit/recruit_detail_screen.dart';
import 'package:photobooking/features/recruit/recruit_list_screen.dart';

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
  testWidgets('the app router opens S27.01 (with a studio filter) and S27.02', (
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

    final list = _screenAt(router, context, '/recruit');
    expect(list, isA<RecruitListScreen>());
    expect((list as RecruitListScreen).studioId, isNull);

    final studio = _screenAt(router, context, '/recruit?studioId=cuc');
    expect((studio as RecruitListScreen).studioId, 'cuc');

    final detail = _screenAt(router, context, '/recruit/p1');
    expect(detail, isA<RecruitDetailScreen>());
    expect((detail as RecruitDetailScreen).postId, 'p1');
  });
}
