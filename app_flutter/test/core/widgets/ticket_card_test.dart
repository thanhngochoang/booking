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
    typeLabel: 'Workshop',
    startsAt: DateTime(2026, 10, 12, 14, 30),
    quantity: quantity,
    state: state,
    placeName: placeName,
  );
}

void main() {
  testWidgets(
    'upcoming shows QR encoding the ticket code and the selectable code',
    (tester) async {
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
    },
  );

  testWidgets(
    'upcoming matches mock S11.04: tag pill, one meta line, QR row with hint and code, two buttons, cancel under the card',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(),
            onDirections: () {},
            onAddToCalendar: () {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();

      // The type is a pill with words, not a #hashtag.
      expect(
        find.descendant(
          of: find.byKey(const Key('ticket-type')),
          matching: find.text('Workshop'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('#'), findsNothing);
      // One meta line: weekday dd/MM · HH:mm · n vé; no place line.
      expect(find.text('T2 12/10 · 14:30 · 2 vé'), findsOneWidget);
      expect(find.text('Hồ Gươm, Hà Nội'), findsNothing);
      // QR on the left, hint and code on its right in one row.
      final qr = tester.getRect(find.byType(QrImageView));
      final hint = tester.getRect(
        find.text('Đưa mã này cho chủ sự kiện khi đến điểm hẹn.'),
      );
      final code = tester.getRect(find.byType(SelectableText));
      expect(hint.left, greaterThan(qr.right));
      expect(code.left, greaterThan(qr.right));
      expect(code.top, greaterThan(hint.bottom));
      // "Chỉ đường" outline and "Thêm vào lịch" secondary, side by side.
      final directions = tester.getRect(
        find.byKey(const Key('ticket-directions')),
      );
      final calendar = tester.getRect(find.byKey(const Key('ticket-calendar')));
      expect(directions.top, calendar.top);
      expect(calendar.left, greaterThan(directions.right));
      final sec = tester.widget<AppButton>(
        find.byKey(const Key('ticket-calendar')),
      );
      expect(sec.style?.backgroundColor?.resolve({}), isNotNull);
      // The cancel sits below the card, outside it.
      final card = tester.getRect(find.byType(GlassCard));
      final cancel = tester.getRect(find.byKey(const Key('ticket-cancel')));
      expect(cancel.top, greaterThanOrEqualTo(card.bottom));
    },
  );

  testWidgets("QR semantics reads 'Mã vé {code}'", (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(code: 'TCK-999'))),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Mã vé TCK-999'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('past and cancelled are dimmed and have no QR', (tester) async {
    // Past
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(state: TicketState.past))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    final pastOpacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(pastOpacity.opacity, 0.55);

    // Cancelled
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(state: TicketState.cancelled))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    final cancelledOpacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(cancelledOpacity.opacity, 0.55);
  });

  testWidgets(
    'pending payment shows Chờ thanh toán and the pay button, no QR',
    (tester) async {
      var paid = false;
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(state: TicketState.pendingPayment),
            onPay: () => paid = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('CHỜ THANH TOÁN'), findsOneWidget);

      final payButton = find.widgetWithText(AppButton, 'Thanh toán');
      expect(payButton, findsOneWidget);
      await tester.tap(payButton);
      expect(paid, isTrue);
    },
  );

  testWidgets(
    'cancel is a danger text button that calls onCancel (no confirmation inside widget)',
    (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(state: TicketState.upcoming),
            onCancel: () => cancelled = true,
          ),
        ),
      );
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
    },
  );

  testWidgets('320 dp and 1.3x text scale wraps without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('skeleton size equal to real widget at 390 and 320 dp', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(title: 'Workshop'),
            onDirections: () {},
            onAddToCalendar: () {},
            onCancel: () {},
          ),
          width: width,
        ),
      );
      await tester.pump();
      final realSize = tester.getSize(find.byType(TicketCard));

      await tester.pumpWidget(
        _wrap(AppSkeletonScope(child: TicketCard.skeleton()), width: width),
      );
      await tester.pump();
      final skeletonSize = tester.getSize(
        find.byKey(const ValueKey('ticket_card_skeleton')),
      );

      expect(skeletonSize.width, realSize.width, reason: 'width at $width');
      expect(
        skeletonSize.height,
        closeTo(realSize.height, 2.0),
        reason: 'height at $width',
      );
    }
  });

  testWidgets('attended state is muted, says Đã tham gia and has no QR', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(state: TicketState.attended))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('ĐÃ THAM GIA'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.55);
  });

  testWidgets('statusLabel overrides the badge', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TicketCard(
          ticket: _testTicket(state: TicketState.cancelled),
          statusLabel: 'Đã hoàn tiền',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ĐÃ HOÀN TIỀN'), findsOneWidget);
    expect(find.text('ĐÃ HUỶ'), findsNothing);
  });

  testWidgets('cancelLabel replaces Huỷ vé', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TicketCard(
          ticket: _testTicket(),
          cancelLabel: 'Huỷ vé · hoàn 100%',
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Huỷ vé · hoàn 100%'), findsOneWidget);
    expect(find.text('Huỷ vé'), findsNothing);
  });

  testWidgets('onOpenChat adds Vào nhóm chat; none without it', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(), onOpenChat: () => opened = true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vào nhóm chat'));
    expect(opened, isTrue);

    await tester.pumpWidget(_wrap(TicketCard(ticket: _testTicket())));
    await tester.pumpAndSettle();
    expect(find.text('Vào nhóm chat'), findsNothing);
  });

  testWidgets('highlighted: false drops the bright border; QR stays', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(), highlighted: false)),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<GlassCard>(find.byType(GlassCard)).highlight, isFalse);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('the QR is tappable only with onQrTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(), onQrTap: () => taps++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ticket-qr')));
    expect(taps, 1);
    await tester.pumpWidget(_wrap(TicketCard(ticket: _testTicket())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-qr')), findsNothing);
  });

  testWidgets('pending payment shows no pay button without onPay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(TicketCard(ticket: _testTicket(state: TicketState.pendingPayment))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán'), findsNothing);
  });

  group('compact (mock S11.04 rows)', () {
    testWidgets('date block, title, n vé · place and the badge; no QR', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(
              state: TicketState.pendingPayment,
              quantity: 1,
              placeName: 'Công viên Bạch Đằng',
            ),
            compact: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('ticket-compact')), findsOneWidget);
      expect(find.byType(DateBlock), findsOneWidget);
      // 14:30 in Vietnam on 12/10: the block reads 12 / T10.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('T10'), findsOneWidget);
      expect(find.text('Workshop Chân dung Mùa thu'), findsOneWidget);
      expect(find.text('1 vé · Công viên Bạch Đằng'), findsOneWidget);
      expect(find.text('CHỜ THANH TOÁN'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byKey(const Key('ticket-pay')), findsNothing);
    });

    testWidgets('a pending row offers a small pay action', (tester) async {
      var paid = 0;
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(state: TicketState.pendingPayment),
            compact: true,
            onPay: () => paid++,
            payLabel: 'Thanh toán tiếp',
          ),
        ),
      );
      await tester.pump();
      final pay = find.byKey(const Key('ticket-pay'));
      expect(tester.widget<AppButton>(pay).size, AppButtonSize.small);
      expect(tester.getSize(pay).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Thanh toán tiếp'));
      expect(paid, 1);
    });

    testWidgets('compact row shows "Báo vấn đề" only with onReportProblem', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(state: TicketState.past),
            compact: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Báo vấn đề'), findsNothing);

      var reported = 0;
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(state: TicketState.past),
            compact: true,
            onReportProblem: () => reported++,
          ),
        ),
      );
      await tester.pump();
      final report = find.byKey(const Key('ticket-report-problem'));
      expect(find.text('Báo vấn đề'), findsOneWidget);
      // A red text button, not dimmed with the past row.
      expect(
        find.ancestor(of: report, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(tester.getSize(report).height, greaterThanOrEqualTo(48));
      await tester.tap(report);
      expect(reported, 1);

      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(state: TicketState.attended),
            compact: true,
            onReportProblem: () {},
            reportProblemLabel: 'Báo vấn đề · còn 5 giờ',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Báo vấn đề · còn 5 giờ'), findsOneWidget);
    });

    testWidgets('fits 320dp at 1.3 text scale with a long badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TicketCard(
            ticket: _testTicket(
              state: TicketState.cancelled,
              title: 'Photo walk phố cổ buổi sớm cùng nhiếp ảnh gia',
            ),
            compact: true,
            statusLabel: 'Đã huỷ · đang hoàn tiền',
          ),
          width: 320,
          textScale: 1.3,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ĐÃ HUỶ · ĐANG HOÀN TIỀN'), findsOneWidget);
    });
  });
}
