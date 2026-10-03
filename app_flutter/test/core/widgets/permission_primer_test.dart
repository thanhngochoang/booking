import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 390,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('PermissionPrimer', () {
    testWidgets("one primary button 'Bật thông báo', 'Để sau' calls onLater", (tester) async {
      var enableCalled = false;
      var laterCalled = false;

      await tester.pumpWidget(_wrap(
        PermissionPrimer(
          title: 'Nhận thông báo lịch chụp',
          benefit: 'Biết ngay khi thợ ảnh nhận lời hoặc có cập nhật về buổi chụp.',
          onEnable: () => enableCalled = true,
          onLater: () => laterCalled = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Renders title and benefit text
      expect(find.text('Nhận thông báo lịch chụp'), findsOneWidget);
      expect(find.text('Biết ngay khi thợ ảnh nhận lời hoặc có cập nhật về buổi chụp.'), findsOneWidget);

      // Bell icon is present
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);

      // One primary button 'Bật thông báo'
      expect(find.widgetWithText(AppButton, 'Bật thông báo'), findsOneWidget);
      // Text button 'Để sau'
      expect(find.text('Để sau'), findsOneWidget);

      // Tap 'Để sau'
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(laterCalled, isTrue);

      // Tap 'Bật thông báo'
      await tester.tap(find.text('Bật thông báo'));
      await tester.pumpAndSettle();
      expect(enableCalled, isTrue);
    });

    testWidgets('layout accommodates 320 dp and text scale 1.3 without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: PermissionPrimer(
                title: 'Nhận thông báo lịch chụp',
                benefit: 'Biết ngay khi thợ ảnh nhận lời hoặc có cập nhật về buổi chụp.',
                onEnable: () {},
                onLater: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
