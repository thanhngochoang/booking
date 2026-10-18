import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/features/delivery/revision_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_delivery_repository.dart';

void main() {
  late FakeDeliveryRepository fakeRepo;

  final testBooking = makeTestBooking(
    id: 'b-rev-1',
    status: BookingStatus.delivered,
    photographerId: 'p1',
    customerId: 'c1',
  ).copyWith(
    deliveryRound: 1,
    revisionsIncluded: 2,
  );

  final testSamples = [
    const DeliverySampleRef(
      fileId: 'f1',
      path: 'deliveries/b-rev-1/f1.jpg',
      thumbPath: 'deliveries/b-rev-1/f1_t.jpg',
      width: 1600,
      height: 1200,
    ),
    const DeliverySampleRef(
      fileId: 'f2',
      path: 'deliveries/b-rev-1/f2.jpg',
      thumbPath: 'deliveries/b-rev-1/f2_t.jpg',
      width: 1600,
      height: 1200,
    ),
    const DeliverySampleRef(
      fileId: 'f3',
      path: 'deliveries/b-rev-1/f3.jpg',
      thumbPath: 'deliveries/b-rev-1/f3_t.jpg',
      width: 1600,
      height: 1200,
    ),
  ];

  final testRound = DeliveryRound(
    bookingId: 'b-rev-1',
    round: 1,
    samples: testSamples,
    photoCount: 50,
    linkHost: 'drive.google.com',
    submittedAt: DateTime.utc(2026, 10, 14, 10, 0),
    submittedBy: 'p1',
  );

  setUp(() {
    fakeRepo = FakeDeliveryRepository();
  });

  Widget buildApp(Widget child) {
    return ProviderScope(
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('selecting tiles numbers them in order and the count reads "3 ảnh"', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showRevisionSheet(
              ctx,
              booking: testBooking,
              round: testRound,
              providerName: 'Minh Trí',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu chỉnh sửa'), findsOneWidget);
    expect(find.text('Vòng sửa 1/2 (miễn phí)'), findsOneWidget);

    // Tap first tile (f1) -> opens note dialog
    await tester.tap(find.byKey(const ValueKey('revision-tile-0')));
    await tester.pumpAndSettle();

    // Dialog opens with "Ghi chú cho ảnh 1"
    expect(find.text('Ghi chú cho ảnh 1'), findsWidgets);
    // Tap chip "Da sáng hơn"
    await tester.tap(find.text('Da sáng hơn'));
    await tester.pumpAndSettle();
    // Tap "Xong"
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    expect(find.text('1 ảnh'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Da sáng hơn'), findsOneWidget);

    // Tap second tile (f2)
    await tester.tap(find.byKey(const ValueKey('revision-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá vật thể'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    expect(find.text('2 ảnh'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tap third tile (f3)
    await tester.tap(find.byKey(const ValueKey('revision-tile-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    expect(find.text('3 ảnh'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Enter general note and submit
    await tester.enterText(find.byType(TextField).first, 'Sửa lại các ảnh đã chọn');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Gửi yêu cầu'));
    await tester.pumpAndSettle();

    expect(fakeRepo.revisionCalls.length, 1);
    expect(fakeRepo.revisionCalls.first.bookingId, 'b-rev-1');
    expect(fakeRepo.revisionCalls.first.note, 'Sửa lại các ảnh đã chọn');
    expect(fakeRepo.revisionCalls.first.photoNotes.length, 3);
    expect(fakeRepo.revisionCalls.first.photoNotes[0].sampleIndex, 0);
    expect(fakeRepo.revisionCalls.first.photoNotes[0].note, 'Da sáng hơn');
    expect(fakeRepo.revisionCalls.first.photoNotes[1].sampleIndex, 1);
    expect(fakeRepo.revisionCalls.first.photoNotes[1].note, 'Xoá vật thể');
    expect(fakeRepo.revisionCalls.first.photoNotes[2].sampleIndex, 2);
    expect(fakeRepo.revisionCalls.first.photoNotes[2].note, '');
  });

  testWidgets('send is disabled with "Chọn ảnh hoặc ghi chú điều cần sửa" when empty', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showRevisionSheet(
              ctx,
              booking: testBooking,
              round: testRound,
              providerName: 'Minh Trí',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn ảnh hoặc ghi chú điều cần sửa'), findsOneWidget);
    final sendBtnFinder = find.widgetWithText(AppButton, 'Gửi yêu cầu');
    expect(tester.widget<AppButton>(sendBtnFinder).onPressed, isNull);

    // Typing a general note enables submit
    await tester.enterText(find.byType(TextField).first, 'Chỉnh màu ấm hơn');
    await tester.pumpAndSettle();

    expect(find.text('Chọn ảnh hoặc ghi chú điều cần sửa'), findsNothing);
    expect(tester.widget<AppButton>(sendBtnFinder).onPressed, isNotNull);

    await tester.tap(sendBtnFinder);
    await tester.pumpAndSettle();

    expect(fakeRepo.revisionCalls.length, 1);
    expect(fakeRepo.revisionCalls.first.bookingId, 'b-rev-1');
    expect(fakeRepo.revisionCalls.first.note, 'Chỉnh màu ấm hơn');
    expect(fakeRepo.revisionCalls.first.extra, isFalse);
  });

  testWidgets('extra mode calls requestRevision(extra: true) with "Gửi đề nghị"', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showRevisionSheet(
              ctx,
              booking: testBooking,
              round: testRound,
              providerName: 'Minh Trí',
              extra: true,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Xin thêm 1 vòng'), findsOneWidget);
    expect(find.textContaining('Hết lượt sửa miễn phí. Minh Trí có thể cho thêm hoặc không.'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Gửi đề nghị'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Cho mình xin thêm 1 vòng nhé');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Gửi đề nghị'));
    await tester.pumpAndSettle();

    expect(fakeRepo.revisionCalls.length, 1);
    expect(fakeRepo.revisionCalls.first.extra, isTrue);
    expect(fakeRepo.revisionCalls.first.note, 'Cho mình xin thêm 1 vòng nhé');
  });

  testWidgets('ScreenCode is S05.07', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showRevisionSheet(
              ctx,
              booking: testBooking,
              round: testRound,
              providerName: 'Minh Trí',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is ScreenCode && w.code == ScreenCodes.requestRevision,
      ),
      findsOneWidget,
    );
  });
}
