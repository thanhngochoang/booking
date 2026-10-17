import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/features/safety/blocked_users_screen.dart';

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
      home: child,
    );
  }

  group('BlockedUsersScreen', () {
    testWidgets('shows empty state when no users blocked', (tester) async {
      await tester.pumpWidget(host(const BlockedUsersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa chặn ai'), findsOneWidget);
      expect(
        find.text(
          'Chặn từ menu … trên hồ sơ, bài viết hoặc tin nhắn.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'lists blocked people newest first with "Chặn {d/M}" and unblocks',
      (tester) async {
        repo.seedBlocked([
          BlockedUser(
            userId: 'u_1',
            displayName: 'Minh Trí',
            avatarUrl: 'https://example.com/1.jpg',
            blockedAt: DateTime(2026, 10, 7),
          ),
          BlockedUser(
            userId: 'u_2',
            displayName: 'Lan Hương',
            blockedAt: DateTime(2026, 9, 15),
          ),
        ]);
        repo.emitIndex(const BlockIndex(blockedIds: {'u_1', 'u_2'}));

        await tester.pumpWidget(host(const BlockedUsersScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Minh Trí'), findsOneWidget);
        expect(find.text('Lan Hương'), findsOneWidget);
        expect(find.text('Chặn 7/10'), findsOneWidget);
        expect(find.text('Chặn 15/9'), findsOneWidget);

        // Tap "Bỏ chặn" on Minh Trí
        final unblockButtons = find.widgetWithText(AppButton, 'Bỏ chặn');
        expect(unblockButtons, findsNWidgets(2));
        await tester.tap(unblockButtons.first);
        await tester.pumpAndSettle();

        // Confirm sheet appears
        expect(find.text('Bỏ chặn Minh Trí?'), findsOneWidget);
        // The confirm sheet has another AppButton with 'Bỏ chặn'
        final confirmBtn = find.widgetWithText(AppButton, 'Bỏ chặn').last;
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.unblockCalls, ['u_1']);
        expect(find.text('Đã bỏ chặn Minh Trí'), findsOneWidget);
        expect(find.text('Minh Trí'), findsNothing);
        expect(find.text('Lan Hương'), findsOneWidget);
      },
    );
  });
}
