// test/core/widgets/contact_dial_screen_code_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Future<void> _pump(WidgetTester tester, {required bool visible}) =>
    tester.pumpWidget(
      ScreenCodeScope(
        visible: visible,
        child: hostWidget(
          Padding(
            padding: const EdgeInsets.only(top: 300, left: 290),
            child: ContactDial(
              access: ContactAccess.unlocked,
              channels: const [
                ContactChannel.call,
                ContactChannel.zalo,
                ContactChannel.whatsapp,
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the open tray is tagged S05.04, the closed dial is not', (
    tester,
  ) async {
    await _pump(tester, visible: true);
    expect(find.text(ScreenCodes.contactAfterBooking), findsNothing);

    await tester.tap(find.byKey(const Key('contact-dial-button')));
    await tester.pumpAndSettle();
    expect(find.text(ScreenCodes.contactAfterBooking), findsOneWidget);
  });

  testWidgets('no tag while screen codes are switched off', (tester) async {
    await _pump(tester, visible: false);
    await tester.tap(find.byKey(const Key('contact-dial-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-tray')), findsOneWidget);
    expect(find.text(ScreenCodes.contactAfterBooking), findsNothing);
  });
}
