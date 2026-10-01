// test/features/contact/add_phone_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/contact/add_phone_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class _Harness {
  _Harness(this.auth, this.contacts, this.widget);
  final FakeAuthRepository auth;
  final FakeUserContactRepository contacts;
  final Widget widget;
}

Future<_Harness> _harness({
  String location = '/profile/phone?returnTo=%2Fafter',
  bool failSave = false,
}) async {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final contacts = FakeUserContactRepository(failSave: failSave);
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/profile/phone',
        builder: (_, s) =>
            AddPhoneScreen(returnTo: s.uri.queryParameters['returnTo']),
      ),
      GoRoute(path: '/after', builder: (_, _) => const Text('after')),
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
    ],
  );
  return _Harness(
    auth,
    contacts,
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        userContactRepositoryProvider.overrideWithValue(contacts),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

void main() {
  testWidgets('save stays disabled until the number is valid', (tester) async {
    final h = await _harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    bool enabled() =>
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const Key('phone-save')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed !=
        null;
    expect(enabled(), isFalse);
    await tester.enterText(find.byType(TextFormField), '90312345');
    await tester.pump();
    expect(enabled(), isFalse);
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.pump();
    expect(enabled(), isTrue);
  });

  testWidgets('saves E.164 with the default toggles and returns to returnTo', (
    tester,
  ) async {
    final h = await _harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '+84 903 123 456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    expect(
      h.contacts.stored(h.auth.currentUser!.uid),
      const UserContact(
        phone: '+84903123456',
        allowZalo: true,
        allowWhatsApp: false,
      ),
    );
    expect(find.text('after'), findsOneWidget);
  });

  testWidgets('toggles are saved as chosen', (tester) async {
    final h = await _harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.tap(find.byKey(const Key('allow-zalo')));
    await tester.tap(find.byKey(const Key('allow-whatsapp')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    final c = h.contacts.stored(h.auth.currentUser!.uid)!;
    expect((c.allowZalo, c.allowWhatsApp), (false, true));
  });

  testWidgets('an unsafe returnTo is ignored and the app goes home', (
    tester,
  ) async {
    final h = await _harness(
      location: '/profile/phone?returnTo=%2F%2Fevil.com',
    );
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a failed save shows a message and keeps the screen', (
    tester,
  ) async {
    final h = await _harness(failSave: true);
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Không lưu được số điện thoại. Thử lại nhé.'),
      findsOneWidget,
    );
    expect(find.byType(AddPhoneScreen), findsOneWidget);
    expect(find.text('after'), findsNothing);
  });

  testWidgets('shows the privacy note and fits 320dp at 1.3x', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _harness();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: h.widget,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
