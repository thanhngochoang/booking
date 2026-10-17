import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/features/help/support_chat_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_support_repository.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets(
    'SupportChatScreen renders title, privacy lock note, and empty text when no messages',
    (tester) async {
      const user = AuthUser(uid: 'user_123', email: 'test@example.com');
      final authRepo = FakeAuthRepository(initialUser: user);
      final fakeRepo = FakeSupportRepository();

      await tester.pumpWidget(
        _wrap(
          const SupportChatScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            authRepositoryProvider.overrideWithValue(authRepo),
            supportRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hỗ trợ'), findsWidgets);
      expect(
        find.text(
          'Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Bạn cần giúp gì? Nhắn cho đội hỗ trợ, chúng tôi trả lời tại đây và báo cho bạn khi có tin mới.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SupportChatScreen sending message posts via repository without explicit threadId',
    (tester) async {
      const user = AuthUser(uid: 'user_123', email: 'test@example.com');
      final authRepo = FakeAuthRepository(initialUser: user);
      final fakeRepo = FakeSupportRepository();

      await tester.pumpWidget(
        _wrap(
          const SupportChatScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            authRepositoryProvider.overrideWithValue(authRepo),
            supportRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Xin chào hỗ trợ');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.forward));
      await tester.pumpAndSettle();

      expect(fakeRepo.sentBodies, contains('Xin chào hỗ trợ'));
      expect(fakeRepo.sentCalls.single.threadId, isNull);
    },
  );
}
