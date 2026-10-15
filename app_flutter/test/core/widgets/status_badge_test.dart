import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/status_badge.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/l10n/app_localizations.dart';

void main() {
  testWidgets('badge shows Vietnamese label and status color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StatusBadge(BookingStatus.accepted)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ĐÃ NHẬN'), findsOneWidget);
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((box.decoration as BoxDecoration).color, AppColors.bookingAccepted);
  });
  test('every status has a color', () {
    for (final s in BookingStatus.values) {
      expect(s.color, isA<Color>());
    }
  });
}
