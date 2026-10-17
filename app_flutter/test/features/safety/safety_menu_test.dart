import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/features/safety/safety_menu.dart';

import '../../support/fake_safety_repository.dart';
import '../../support/screen_host.dart';

void main() {
  late FakeSafetyRepository repo;

  setUp(() {
    repo = FakeSafetyRepository();
  });

  Widget host(Widget child, {String myUid = 'u_me'}) {
    return screenApp(
      overrides: [
        safetyRepositoryProvider.overrideWithValue(repo),
        blockIndexProvider.overrideWith((ref) => repo.watchIndex()),
        authStateProvider.overrideWith(
          (ref) => Stream.value(AuthUser(uid: myUid)),
        ),
      ],
      home: Scaffold(body: child),
    );
  }

  group('SafetyMenu', () {
    testWidgets(
      'profile menu shows Chia sẻ hồ sơ, Báo cáo, Chặn Minh Trí',
      (tester) async {
        var shared = false;
        await tester.pumpWidget(
          host(
            Consumer(
              builder: (ctx, ref, _) => ElevatedButton(
                onPressed: () => showSafetyMenu(
                  ctx,
                  ref,
                  target: ReportTarget.user(uid: 'u_target', name: 'Minh Trí'),
                  blockUserId: 'u_target',
                  blockName: 'Minh Trí',
                  onShare: () => shared = true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('safety-menu-share')), findsOneWidget);
        expect(find.text('Chia sẻ hồ sơ'), findsOneWidget);
        expect(find.byKey(const Key('safety-menu-report')), findsOneWidget);
        expect(find.text('Báo cáo'), findsOneWidget);
        expect(find.byKey(const Key('safety-menu-block')), findsOneWidget);
        expect(find.text('Chặn Minh Trí'), findsOneWidget);

        await tester.tap(find.byKey(const Key('safety-menu-share')));
        await tester.pumpAndSettle();
        expect(shared, isTrue);
      },
    );

    testWidgets('when blocked, row reads "Bỏ chặn Minh Trí"', (tester) async {
      repo.emitIndex(const BlockIndex(blockedIds: {'u_target'}));

      await tester.pumpWidget(
        host(
          Consumer(
            builder: (ctx, ref, _) => ElevatedButton(
              onPressed: () => showSafetyMenu(
                ctx,
                ref,
                target: ReportTarget.user(uid: 'u_target', name: 'Minh Trí'),
                blockUserId: 'u_target',
                blockName: 'Minh Trí',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('safety-menu-unblock')), findsOneWidget);
      expect(find.text('Bỏ chặn Minh Trí'), findsOneWidget);
      expect(find.byKey(const Key('safety-menu-block')), findsNothing);
    });

    testWidgets('Chặn opens confirm sheet and calls block on confirm', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Consumer(
            builder: (ctx, ref, _) => ElevatedButton(
              onPressed: () => showSafetyMenu(
                ctx,
                ref,
                target: ReportTarget.user(uid: 'u_target', name: 'Minh Trí'),
                blockUserId: 'u_target',
                blockName: 'Minh Trí',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('safety-menu-block')));
      await tester.pumpAndSettle();

      expect(find.text('Chặn Minh Trí?'), findsOneWidget);
      expect(find.text('Chặn'), findsOneWidget);

      await tester.tap(find.text('Chặn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.blockCalls, ['u_target']);
      expect(find.text('Đã chặn Minh Trí'), findsOneWidget);
    });
  });
}
