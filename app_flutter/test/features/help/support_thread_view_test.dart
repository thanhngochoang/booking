import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/data/support/support_thread.dart';
import 'package:photobooking/features/help/support_thread_view.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_support_repository.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      // Signed in as u1, the owner of the help thread.
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(initialUser: const AuthUser(uid: 'u1')),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    'SupportThreadView labels staff messages Hỗ trợ and leaves mine unlabelled',
    (tester) async {
      final fakeRepo = FakeSupportRepository(
        initialThread: const SupportThread(
          id: 'help_u1',
          kind: SupportThreadKind.help,
          ownerId: 'u1',
          participants: ['u1'],
          status: 'open',
          awaitingStaff: false,
        ),
        initialMessages: [
          SupportMessage(
            id: 'm1',
            threadId: 'help_u1',
            senderId: 'staff_1',
            senderRole: SupportSenderRole.staff,
            senderName: 'Hỗ trợ',
            body: 'Chào bạn, hỗ trợ có thể giúp gì?',
            createdAt: DateTime.now(),
          ),
          SupportMessage(
            id: 'm2',
            threadId: 'help_u1',
            senderId: 'u1',
            senderRole: SupportSenderRole.user,
            senderName: 'Me',
            body: 'Tôi muốn hỏi về thanh toán',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          SupportThreadView(
            threadId: 'help_u1',
            enabled: true,
            hint: 'Nhắn cho hỗ trợ…',
            senderLabel: (m) =>
                m.senderRole == SupportSenderRole.staff ? 'Hỗ trợ' : '',
          ),
          overrides: [supportRepositoryProvider.overrideWithValue(fakeRepo)],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hỗ trợ'), findsOneWidget);
      expect(find.text('Chào bạn, hỗ trợ có thể giúp gì?'), findsOneWidget);
      expect(find.text('Tôi muốn hỏi về thanh toán'), findsOneWidget);
    },
  );

  testWidgets(
    'sending shows the bubble at once and keeps it with a retry when the call fails',
    (tester) async {
      final fakeRepo = FakeSupportRepository(
        initialThread: const SupportThread(
          id: 'help_u1',
          kind: SupportThreadKind.help,
          ownerId: 'u1',
          participants: ['u1'],
          status: 'open',
          awaitingStaff: false,
        ),
        initialMessages: [],
      );
      fakeRepo.sendError = Exception('Network error');

      await tester.pumpWidget(
        _wrap(
          SupportThreadView(
            threadId: 'help_u1',
            enabled: true,
            hint: 'Nhắn cho hỗ trợ…',
            senderLabel: (_) => '',
          ),
          overrides: [supportRepositoryProvider.overrideWithValue(fakeRepo)],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message failure');
      await tester.pump(); // the send button enables on the next frame
      await tester.tap(find.bySemanticsLabel('Gửi tin nhắn'));
      await tester.pump();

      // Optimistically added message bubble is visible
      expect(find.text('Test message failure'), findsOneWidget);

      await tester.pumpAndSettle();

      // Shows retry button when failed
      expect(find.text('Gửi lại'), findsOneWidget);
    },
  );

  testWidgets('disabled shows disabledReason and no composer', (tester) async {
    final fakeRepo = FakeSupportRepository();

    await tester.pumpWidget(
      _wrap(
        SupportThreadView(
          threadId: 'help_u1',
          enabled: false,
          disabledReason: 'Cuộc trò chuyện đã đóng',
          hint: 'Nhắn cho hỗ trợ…',
          senderLabel: (_) => '',
        ),
        overrides: [supportRepositoryProvider.overrideWithValue(fakeRepo)],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cuộc trò chuyện đã đóng'), findsOneWidget);
    expect(find.byKey(const Key('support-composer')), findsNothing);
  });
}
