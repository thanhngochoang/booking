import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _host(int count) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: TabBadge(count: count, child: const Icon(Icons.explore_outlined)),
  ),
);

void main() {
  testWidgets('no badge at zero', (tester) async {
    await tester.pumpWidget(_host(0));
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('shows the count, and 9+ above nine', (tester) async {
    await tester.pumpWidget(_host(3));
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(_host(12));
    expect(find.text('9+'), findsOneWidget);
  });
}
