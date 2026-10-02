import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/app.dart';

void main() {
  testWidgets('MyApp renders the route given by the router', (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const Text('ok'))],
    );
    await tester.pumpWidget(MyApp(router: router));
    await tester.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
  });
}
