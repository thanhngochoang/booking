import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

TicketCardData _testTicket({
  TicketState state = TicketState.upcoming,
  String code = 'TCK-2026-X1',
  String title = 'Workshop Chân dung Mùa thu',
  int quantity = 2,
  String? placeName = 'Hồ Gươm, Hà Nội',
}) {
  return TicketCardData(
    ticketCode: code,
    eventTitle: title,
    typeTag: 'workshop',
    startsAt: DateTime(2026, 10, 12, 14, 30),
    quantity: quantity,
    state: state,
    placeName: placeName,
  );
}

void main() {
  testWidgets('upcoming shows QR encoding the ticket code and the selectable code', (tester) async {
    await tester.pumpWidget(_wrap(TicketCard(ticket: _testTicket())));
    await tester.pumpAndSettle();

    final qrFinder = find.byType(QrImageView);
    expect(qrFinder, findsOneWidget);
    final qr = tester.widget<QrImageView>(qrFinder);
    expect(qr.semanticsLabel, contains('TCK-2026-X1'));

    final selectableFinder = find.byType(SelectableText);
    expect(selectableFinder, findsOneWidget);
    final selectable = tester.widget<SelectableText>(selectableFinder);
    expect(selectable.data, 'TCK-2026-X1');
  });

  testWidgets("QR semantics reads 'Mã vé {code}'", (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(TicketCard(ticket: _testTicket(code: 'TCK-999'))));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Mã vé TCK-999'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('past and cancelled are dimmed and have no QR', (tester) async {
    // Past
    await tester.pumpWidget(_wrap(TicketCard(ticket: _testTicket(state: TicketState.past))));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    final pastOpacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(pastOpacity.opacity, 0.55);

    // Cancelled
    await tester.pumpWidget(_wrap(TicketCard(ticket: _testTicket(state: TicketState.cancelled))));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    final cancelledOpacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(cancelledOpacity.opacity, 0.55);
  });

  testWidgets('pending payment shows Chờ thanh toán and the pay button, no QR', (tester) async {
    var paid = false;
    await tester.pumpWidget(_wrap(
      TicketCard(
        ticket: _testTicket(state: TicketState.pendingPayment),
        onPay: () => paid = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('CHỜ THANH TOÁN'), findsOneWidget);

    final payButton = find.widgetWithText(AppButton, 'Thanh toán');
    expect(payButton, findsOneWidget);
    await tester.tap(payButton);
    expect(paid, isTrue);
  });

  testWidgets('cancel is a danger text button that calls onCancel (no confirmation inside widget)', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(_wrap(
      TicketCard(
        ticket: _testTicket(state: TicketState.upcoming),
        onCancel: () => cancelled = true,
      ),
    ));
    await tester.pumpAndSettle();

    final cancelFinder = find.widgetWithText(TextButton, 'Huỷ vé');
    expect(cancelFinder, findsOneWidget);

    final textButton = tester.widget<TextButton>(cancelFinder);
    final fgColor = textButton.style?.foregroundColor?.resolve({});
    expect(fgColor, AppColors.error);

    await tester.tap(cancelFinder);
    expect(cancelled, isTrue);

    // No dialog or bottom sheet opened by the card itself
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('320 dp and 1.3x text scale wraps without overflow', (tester) async {
    await tester.pumpWidget(_wrap(
      TicketCard(
        ticket: _testTicket(
          title: 'Workshop chụp chân dung ngoại cảnh mùa thu tại phố cổ Hà Nội rất dài',
          placeName: 'Địa điểm tổ chức sự kiện đặc biệt dài tại số 1 Tràng Tiền Hoàn Kiếm Hà Nội',
        ),
        onDirections: () {},
        onAddToCalendar: () {},
        onCancel: () {},
      ),
      width: 320,
      textScale: 1.3,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('skeleton size equal to real widget at 390 and 320 dp', (tester) async {
    for (final width in [390.0, 320.0]) {
      await tester.pumpWidget(_wrap(
        TicketCard(
          ticket: _testTicket(title: 'Workshop'),
          onDirections: () {},
          onAddToCalendar: () {},
          onCancel: () {},
        ),
        width: width,
      ));
      await tester.pump();
      final realSize = tester.getSize(find.byType(TicketCard));

      await tester.pumpWidget(_wrap(
        AppSkeletonScope(child: TicketCard.skeleton()),
        width: width,
      ));
      await tester.pump();
      final skeletonSize = tester.getSize(find.byKey(const ValueKey('ticket_card_skeleton')));

      expect(skeletonSize.width, realSize.width, reason: 'width at $width');
      expect(skeletonSize.height, closeTo(realSize.height, 2.0), reason: 'height at $width');
    }
  });
}
