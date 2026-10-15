import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/onboarding/splash_screen.dart';

import '../../support/screen_host.dart';

void main() {
  testWidgets('waits with the brand aperture, labelled for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(screenApp(home: const SplashScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SignatureLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);
  });
}
