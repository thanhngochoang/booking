import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/features/help/help_faq.dart';
import 'package:photobooking/features/help/help_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class _FakeExternalLauncher implements ExternalLauncher {
  Uri? lastOpened;
  @override
  Future<bool> canOpen(Uri uri) async => true;
  @override
  Future<bool> open(Uri uri) async {
    lastOpened = uri;
    return true;
  }
}

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
  testWidgets('help without disputes shows no "Khiếu nại của bạn" section', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const HelpScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Khiếu nại của bạn'), findsNothing);
    expect(find.text('Câu hỏi thường gặp'), findsOneWidget);
  });

  testWidgets(
    'topic chips switch the questions; the first topic is Thanh toán',
    (tester) async {
      await tester.pumpWidget(_wrap(const HelpScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vì sao phải trả trước 100%?'), findsOneWidget);

      // Switch to Huỷ & hoàn tiền
      await tester.tap(find.byKey(const Key('topic-chip-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Huỷ buổi chụp được hoàn bao nhiêu?'), findsOneWidget);
      expect(find.text('Vì sao phải trả trước 100%?'), findsNothing);
    },
  );

  testWidgets('a question expands to its exact answer and collapses again', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const HelpScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền không đến tay thợ ngay'), findsNothing);

    // Tap the question to expand
    await tester.tap(find.text('Vì sao phải trả trước 100%?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền không đến tay thợ ngay'), findsOneWidget);

    // Tap again to collapse
    await tester.tap(find.text('Vì sao phải trả trước 100%?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền không đến tay thợ ngay'), findsNothing);
  });

  testWidgets('every FAQ key has a non-empty question and answer', (
    tester,
  ) async {
    late AppLocalizations localizations;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            localizations = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topics = faqTopics(localizations);
    expect(topics.isNotEmpty, isTrue);

    for (final topic in topics) {
      expect(topic.id.isNotEmpty, isTrue);
      expect(topic.label.isNotEmpty, isTrue);
      expect(topic.items.isNotEmpty, isTrue);
      for (final item in topic.items) {
        expect(item.question.trim().isNotEmpty, isTrue);
        expect(item.answer.trim().isNotEmpty, isTrue);
      }
    }
  });

  testWidgets(
    'the email line is hidden when supportEmail is null and opens mailto when set',
    (tester) async {
      // 1. When supportEmail is null -> line is hidden
      await tester.pumpWidget(
        _wrap(
          const HelpScreen(),
          overrides: [supportEmailProvider.overrideWithValue(null)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('help-support-email')), findsNothing);

      // 2. When supportEmail is set -> line is shown and opens mailto
      // A new scope: Riverpod refuses a changed number of overrides.
      await tester.pumpWidget(const SizedBox());
      final fakeLauncher = _FakeExternalLauncher();
      await tester.pumpWidget(
        _wrap(
          const HelpScreen(),
          overrides: [
            supportEmailProvider.overrideWithValue('support@example.com'),
            externalLauncherProvider.overrideWithValue(fakeLauncher),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('help-support-email')), findsOneWidget);
      expect(find.text('Email hỗ trợ: support@example.com'), findsOneWidget);

      await tester.tap(find.byKey(const Key('help-support-email')));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastOpened?.scheme, 'mailto');
      expect(fakeLauncher.lastOpened?.path, 'support@example.com');
    },
  );

  testWidgets('help fits 320dp at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: HelpScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
