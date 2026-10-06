import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/provider_providers.dart';
import 'package:photobooking/data/photographer/provider_repository.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/content_fixtures.dart';
import '../../support/idle.dart';

class _H {
  _H(this.auth, this.repo, this.provider, this.widget);
  final FakeProviderRepository provider;
  final FakeAuthRepository auth;
  final FakePhotographerContactRepository repo;
  final Widget widget;
  String get uid => auth.currentUser!.uid;
}

Future<_H> _harness({
  bool failSave = false,
  bool failType = false,
  ProviderType type = ProviderType.individual,
  bool popOnDone = false,
}) async {
  final auth = FakeAuthRepository();
  await auth.registerWithEmail('p@b.vn', 'password1', 'Thư');
  final repo = FakePhotographerContactRepository(failSave: failSave);
  final provider = FakeProviderRepository(type: type);
  final profiles = FakePublicProfileRepository([
    PhotographerProfile(
      summary: fixturePhotographer(auth.currentUser!.uid, providerType: type),
    ),
  ]);
  if (failType) {
    profiles.failWith = StateError('offline');
  }
  final router = GoRouter(
    initialLocation: popOnDone ? '/settings' : '/setup/4',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (c, _) => TextButton(
          onPressed: () => c.push('/setup/4?from=settings'),
          child: const Text('settings'),
        ),
      ),
      GoRoute(
        path: '/setup/4',
        builder: (_, s) => ContactSetupScreen(
          popOnDone: s.uri.queryParameters['from'] == 'settings',
        ),
      ),
      GoRoute(path: '/bookings', builder: (_, _) => const Text('work')),
      GoRoute(path: '/profile', builder: (_, _) => const Text('profile')),
    ],
  );
  return _H(
    auth,
    repo,
    provider,
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        photographerContactRepositoryProvider.overrideWithValue(repo),
        providerRepositoryProvider.overrideWithValue(provider),
        publicProfileRepositoryProvider.overrideWithValue(profiles),
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

Future<_H> _open(
  WidgetTester tester, {
  bool failSave = false,
  bool failType = false,
  ProviderType type = ProviderType.individual,
  bool popOnDone = false,
}) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await _harness(
    failSave: failSave,
    failType: failType,
    type: type,
    popOnDone: popOnDone,
  );
  await tester.pumpWidget(h.widget);
  await tester.pumpAndSettle();
  return h;
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

bool _switchOn(WidgetTester tester, String key) =>
    tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

void main() {
  testWidgets(
    'Zalo and WhatsApp cards use the brand glyphs, not Material icons',
    (tester) async {
      await _open(tester);
      for (final k in ['channel-zalo', 'channel-whatsapp']) {
        expect(
          find.descendant(
            of: find.byKey(Key(k)),
            matching: find.byType(SvgPicture),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: find.byKey(Key(k)), matching: find.byType(Icon)),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'flow title and "4 / 4" in the app bar, step heading in the body',
    (tester) async {
      await _open(tester);
      final bar = find.byType(AppBar);
      expect(
        find.descendant(of: bar, matching: find.text('Hồ sơ nhiếp ảnh gia')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('4 / 4')),
        findsOneWidget,
      );
      expect(find.text('4 / 4'), findsOneWidget, reason: 'count shown twice');
      final heading = find.text('Khu vực và liên hệ');
      expect(heading, findsOneWidget);
      expect(find.descendant(of: bar, matching: heading), findsNothing);
      expect(
        tester.getSemantics(heading),
        matchesSemantics(label: 'Khu vực và liên hệ', isHeader: true),
      );
      // The progress bar sits between the app bar and the scrolling body.
      final segment = find.byKey(const Key('step-segment')).first;
      expect(
        find.ancestor(of: segment, matching: find.byType(Scrollable)),
        findsNothing,
      );
      expect(
        find.text('Chọn kênh khách được dùng để liên hệ bạn.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('back and finish sit in a sticky footer, back at 36%', (
    tester,
  ) async {
    await _open(tester);
    for (final k in ['setup-back', 'setup-finish']) {
      expect(
        find.ancestor(
          of: find.byKey(Key(k)),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
        reason: '$k scrolls with the form',
      );
    }
    final back = tester.getSize(find.byKey(const Key('setup-back'))).width;
    final finish = tester.getSize(find.byKey(const Key('setup-finish'))).width;
    expect(back / (back + finish + 8), closeTo(0.36, 0.02));
  });

  testWidgets('fields and channel cards sit on the page, not in a card', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(GlassCard), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    final chip = tester.widget<AppChip>(find.byKey(const Key('radius-20')));
    expect(chip.kind, AppChipKind.context);
    final icon = find.byKey(const Key('channel-icon-call'));
    expect(tester.getSize(icon), const Size(36, 36));
  });

  testWidgets('channel hints read as in the mock', (tester) async {
    await _open(tester);
    expect(find.text('Dùng số trên'), findsNWidgets(2));
    expect(find.text('Nhập số riêng nếu khác'), findsOneWidget);
  });

  testWidgets(
    '"Hoàn tất" on an empty form shows the three problems and saves nothing',
    (tester) async {
      final h = await _open(tester);
      await _tap(tester, 'setup-finish');
      expect(find.text('Nhập thành phố bạn nhận việc'), findsOneWidget);
      expect(find.text('Nhập số điện thoại'), findsOneWidget);
      expect(
        find.text(
          'Bật ít nhất một kênh, hoặc chọn "Chỉ nhận tin nhắn trong app".',
        ),
        findsOneWidget,
      );
      expect(h.repo.completed, isEmpty);
      expect(find.text('work'), findsNothing);
    },
  );

  testWidgets('errors clear as the fields are fixed', (tester) async {
    await _open(tester);
    await _tap(tester, 'setup-finish');
    await _type(tester, 'setup-city', 'Hà Nội');
    expect(find.text('Nhập thành phố bạn nhận việc'), findsNothing);
    await _tap(tester, 'channel-call');
    expect(
      find.text(
        'Bật ít nhất một kênh, hoặc chọn "Chỉ nhận tin nhắn trong app".',
      ),
      findsNothing,
    );
  });

  testWidgets(
    'a complete form is saved in one go and the photographer lands on Công việc',
    (tester) async {
      final h = await _open(tester);
      await _type(tester, 'setup-city', 'Hà Nội');
      await _tap(tester, 'radius-30');
      await _type(tester, 'setup-phone', '0903123456');
      await _tap(tester, 'channel-zalo');
      await _tap(tester, 'setup-finish');
      expect(
        h.repo.areaOf(h.uid),
        const ServiceArea(city: 'Hà Nội', radiusKm: 30),
      );
      expect(h.repo.channelsOf(h.uid), const ContactChannels(zalo: true));
      expect(
        h.repo.numbersOf(h.uid),
        const ContactNumbers(phone: '+84903123456'),
      );
      expect(h.repo.completed, {h.uid});
      expect(find.text('work'), findsOneWidget);
    },
  );

  testWidgets('own Zalo and WhatsApp numbers are saved when given', (
    tester,
  ) async {
    final h = await _open(tester);
    await _type(tester, 'setup-city', 'Đà Nẵng');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-zalo');
    await _tap(tester, 'channel-whatsapp');
    await _type(tester, 'zalo-own', '0912345678');
    await _type(tester, 'whatsapp-own', '+1 415 555 2671');
    await _tap(tester, 'setup-finish');
    expect(
      h.repo.numbersOf(h.uid),
      const ContactNumbers(
        phone: '+84903123456',
        zaloPhone: '+84912345678',
        whatsappPhone: '+14155552671',
      ),
    );
    expect(
      h.repo.channelsOf(h.uid),
      const ContactChannels(zalo: true, whatsapp: true),
    );
  });

  testWidgets('WhatsApp on and left empty uses the main number', (
    tester,
  ) async {
    final h = await _open(tester);
    await _type(tester, 'setup-city', 'Hà Nội');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-whatsapp');
    await _tap(tester, 'setup-finish');
    expect(h.repo.channelsOf(h.uid)!.whatsapp, isTrue);
    expect(h.repo.numbersOf(h.uid)!.whatsappPhone, isNull);
  });

  testWidgets(
    'a WhatsApp number without a country code is refused under its field',
    (tester) async {
      final h = await _open(tester);
      await _type(tester, 'setup-city', 'Hà Nội');
      await _type(tester, 'setup-phone', '0903123456');
      await _tap(tester, 'channel-whatsapp');
      await _type(tester, 'whatsapp-own', '4155552671');
      await _tap(tester, 'setup-finish');
      expect(
        find.text('Nhập số có mã quốc gia, ví dụ: +1 415 555 2671'),
        findsOneWidget,
      );
      expect(h.repo.completed, isEmpty);
    },
  );

  testWidgets(
    '"Chỉ nhận tin nhắn trong app" is a valid choice and switches the other three off',
    (tester) async {
      final h = await _open(tester);
      await _type(tester, 'setup-city', 'Hà Nội');
      await _type(tester, 'setup-phone', '0903123456');
      await _tap(tester, 'channel-call');
      await _tap(tester, 'channel-inapp');
      expect(_switchOn(tester, 'channel-inapp'), isTrue);
      expect(_switchOn(tester, 'channel-call'), isFalse);
      await _tap(tester, 'setup-finish');
      expect(h.repo.channelsOf(h.uid), const ContactChannels());
      expect(
        h.repo.numbersOf(h.uid),
        const ContactNumbers(phone: '+84903123456'),
      );
      expect(h.repo.completed, {h.uid});
    },
  );

  testWidgets('switching an outside channel on turns "only in-app" off', (
    tester,
  ) async {
    await _open(tester);
    await _tap(tester, 'channel-inapp');
    await _tap(tester, 'channel-zalo');
    expect(_switchOn(tester, 'channel-zalo'), isTrue);
    expect(_switchOn(tester, 'channel-inapp'), isFalse);
  });

  testWidgets('an earlier setup is shown again for editing', (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _harness();
    h.repo.seed(
      h.uid,
      area: const ServiceArea(city: 'Huế', radiusKm: 50),
      channels: const ContactChannels(zalo: true),
      numbers: const ContactNumbers(
        phone: '+84903123456',
        zaloPhone: '+84912345678',
      ),
    );
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(find.text('Huế'), findsOneWidget);
    // Read the controllers: the fields' hint text is also "903 123 456".
    expect(_fieldText(tester, 'setup-phone'), '903 123 456');
    expect(_fieldText(tester, 'zalo-own'), '912 345 678');
    expect(_switchOn(tester, 'channel-zalo'), isTrue);
    expect(_switchOn(tester, 'channel-call'), isFalse);
    expect(
      tester.widget<AppChip>(find.byKey(const Key('radius-50'))).selected,
      isTrue,
    );
  });

  testWidgets('a failed save shows a message and keeps the form', (
    tester,
  ) async {
    final h = await _open(tester, failSave: true);
    await _type(tester, 'setup-city', 'Hà Nội');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-call');
    await _tap(tester, 'setup-finish');
    expect(
      find.text('Không lưu được thiết lập. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(h.repo.completed, isEmpty);
    expect(find.text('work'), findsNothing);
  });

  testWidgets(
    '"Quay lại" leaves for the profile when there is nothing to pop',
    (tester) async {
      await _open(tester);
      await _tap(tester, 'setup-back');
      expect(find.text('profile'), findsOneWidget);
    },
  );

  testWidgets('fits 320dp at 1.3x with every channel open', (tester) async {
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
    for (final k in ['channel-call', 'channel-zalo', 'channel-whatsapp']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('S08.05 is idle at rest and keeps blur passes within budget', (
    tester,
  ) async {
    await _open(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
    expect(find.byType(BackdropFilter).evaluate().length, lessThanOrEqualTo(4));
  });

  testWidgets('privacy line is plain text, as in the mock', (tester) async {
    await _open(tester);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
  });

  testWidgets('the footer reaches the bottom edge over the gesture bar', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    await _open(tester);
    final footer = tester.getRect(find.byType(AppFooterBar));
    expect(footer.bottom, tester.view.physicalSize.height);
  });

  testWidgets('keyboard up at 320x568: footer and phone field reachable', (
    tester,
  ) async {
    final h = await _harness();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('setup-finish')).hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('setup-phone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setup-phone')).hitTestable(), findsWidgets);
  });

  group('studio address', () {
    Future<void> fillContact(WidgetTester tester) async {
      await _type(tester, 'setup-phone', '0903123456');
      await _tap(tester, 'channel-zalo');
    }

    testWidgets('opened from Settings, finishing goes back there', (
      tester,
    ) async {
      final h = await _open(tester, type: ProviderType.studio, popOnDone: true);
      await tester.tap(find.text('settings'));
      await tester.pumpAndSettle();
      await _type(tester, 'setup-city', 'Hà Nội');
      await fillContact(tester);
      await _type(tester, 'studio-line', '12 Tràng Tiền');
      await _type(tester, 'studio-district', 'Hoàn Kiếm');
      await _type(tester, 'studio-city', 'Hà Nội');
      await _tap(tester, 'setup-finish');
      expect(h.repo.completed, {h.uid});
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('work'), findsNothing);
    });

    testWidgets('an individual finishes without the address block', (
      tester,
    ) async {
      final h = await _open(tester);
      expect(find.byKey(const Key('studio-line')), findsNothing);
      await _type(tester, 'setup-city', 'Hà Nội');
      await fillContact(tester);
      await _tap(tester, 'setup-finish');
      expect(h.repo.completed, {h.uid});
      expect(h.provider.address, isNull);
    });

    testWidgets('studio needs an address to finish', (tester) async {
      final h = await _open(tester, type: ProviderType.studio);
      expect(find.text('Địa chỉ cơ sở'), findsOneWidget);
      await _type(tester, 'setup-city', 'Hà Nội');
      await fillContact(tester);
      await _tap(tester, 'setup-finish');
      expect(
        find.text('Nhập số nhà, đường (ít nhất 5 ký tự).'),
        findsOneWidget,
      );
      expect(find.text('Nhập quận / huyện.'), findsOneWidget);
      expect(h.repo.completed, isEmpty);
      expect(h.provider.address, isNull);
      expect(find.text('work'), findsNothing);
    });

    testWidgets('a studio saves the address before finishing', (tester) async {
      final h = await _open(tester, type: ProviderType.studio);
      await _type(tester, 'setup-city', 'Hà Nội');
      await fillContact(tester);
      await _type(tester, 'studio-line', ' 12 Tràng Tiền ');
      await _type(tester, 'studio-district', 'Hoàn Kiếm');
      await _type(tester, 'studio-city', 'Hà Nội');
      await _tap(tester, 'setup-finish');
      final a = h.provider.address!;
      expect(
        (a.line, a.ward, a.district, a.city),
        ('12 Tràng Tiền', null, 'Hoàn Kiếm', 'Hà Nội'),
      );
      expect(h.repo.completed, {h.uid});
      expect(find.text('work'), findsOneWidget);
    });

    testWidgets('a refused address keeps the form and says so', (tester) async {
      final h = await _open(tester, type: ProviderType.studio);
      h.provider.failWith = const ProviderError('not_eligible');
      await _type(tester, 'setup-city', 'Hà Nội');
      await fillContact(tester);
      await _type(tester, 'studio-line', '12 Tràng Tiền');
      await _type(tester, 'studio-district', 'Hoàn Kiếm');
      await _type(tester, 'studio-city', 'Hà Nội');
      await _tap(tester, 'setup-finish');
      expect(h.repo.completed, isEmpty);
      expect(find.textContaining('Không lưu được thiết lập'), findsOneWidget);
    });

    testWidgets('shows retry when the type cannot be read', (tester) async {
      final h = await _open(tester, type: ProviderType.studio, failType: true);
      expect(find.byKey(const Key('error-retry')), findsOneWidget);
      expect(find.byKey(const Key('studio-line')), findsNothing);
      expect(find.byKey(const Key('setup-finish')), findsNothing);
      expect(h.repo.completed, isEmpty);
    });
  });
}
